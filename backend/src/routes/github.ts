/**
 * GitHub Routes
 * API endpoints for GitHub integration
 * 
 * All GitHub API interactions are logged for audit purposes (Requirements 7.3)
 */

import { Router, Request, Response } from 'express';
import { v4 as uuidv4 } from 'uuid';
import { authenticateToken } from '../middleware/auth.js';
import { githubService } from '../services/githubService.js';
import { githubSourceService } from '../services/githubSourceService.js';
import { tokenRevocationService } from '../services/tokenRevocationService.js';
import { auditLoggerService } from '../services/auditLoggerService.js';
import { accessControlService, ACCESS_CONTROL_ERROR_CODES } from '../services/accessControlService.js';

/**
 * Error codes for GitHub operations
 */
const GITHUB_ERROR_CODES = {
  NOT_CONNECTED: 'GITHUB_NOT_CONNECTED',
  RATE_LIMITED: 'GITHUB_RATE_LIMITED',
  ACCESS_DENIED: 'GITHUB_ACCESS_DENIED',
  NOT_FOUND: 'GITHUB_NOT_FOUND',
  INVALID_REQUEST: 'GITHUB_INVALID_REQUEST',
  REPOSITORY_ACCESS_DENIED: 'REPOSITORY_ACCESS_DENIED',
  INVALID_AGENT_SESSION: 'INVALID_AGENT_SESSION',
} as const;

/**
 * Parse rate limit info from GitHub API error
 */
function parseRateLimitError(error: any): { isRateLimited: boolean; resetTime?: Date; remaining?: number } {
  if (error?.response?.status === 403 || error?.response?.status === 429) {
    const headers = error.response?.headers || {};
    const remaining = parseInt(headers['x-ratelimit-remaining'] || '0', 10);
    const resetTimestamp = parseInt(headers['x-ratelimit-reset'] || '0', 10);
    
    if (remaining === 0 || error.message?.includes('rate limit')) {
      return {
        isRateLimited: true,
        resetTime: resetTimestamp ? new Date(resetTimestamp * 1000) : undefined,
        remaining: 0,
      };
    }
  }
  return { isRateLimited: false };
}

/**
 * Format rate limit error message for user
 */
function formatRateLimitMessage(resetTime?: Date): string {
  if (resetTime) {
    const now = new Date();
    const diffMs = resetTime.getTime() - now.getTime();
    const diffMins = Math.ceil(diffMs / 60000);
    
    if (diffMins <= 0) {
      return 'GitHub API rate limit exceeded. Please try again in a moment.';
    } else if (diffMins === 1) {
      return 'GitHub API rate limit exceeded. Please try again in 1 minute.';
    } else if (diffMins < 60) {
      return `GitHub API rate limit exceeded. Please try again in ${diffMins} minutes.`;
    } else {
      const hours = Math.ceil(diffMins / 60);
      return `GitHub API rate limit exceeded. Please try again in ${hours} hour${hours > 1 ? 's' : ''}.`;
    }
  }
  return 'GitHub API rate limit exceeded. Please try again later.';
}

/**
 * Check if user has GitHub connected and return appropriate error if not
 */
async function requireGitHubConnection(userId: string): Promise<{ connected: boolean; error?: { code: string; message: string } }> {
  const connection = await githubService.getConnection(userId);
  if (!connection) {
    return {
      connected: false,
      error: {
        code: GITHUB_ERROR_CODES.NOT_CONNECTED,
        message: 'GitHub account not connected. Please connect your GitHub account in Settings.',
      },
    };
  }
  return { connected: true };
}

/**
 * Helper to extract agent session ID from request headers or body
 */
function getAgentSessionId(req: Request): string | undefined {
  return (req.headers['x-agent-session-id'] as string) || 
         (req.body?.agentSessionId as string) || 
         undefined;
}

/**
 * Validate agent session belongs to requesting user
 * Requirements: 7.2 - Verify agent session belongs to requesting user
 * 
 * @param agentSessionId - The agent session ID from request
 * @param userId - The requesting user's ID
 * @returns Validation result with error details if invalid
 */
async function validateAgentSessionForRequest(
  agentSessionId: string | undefined,
  userId: string
): Promise<{ valid: boolean; statusCode?: number; errorResponse?: any }> {
  if (!agentSessionId) {
    return { valid: true }; // No session to validate
  }
  
  return accessControlService.checkAgentSessionForRoute(agentSessionId, userId);
}

/**
 * Verify repository access for user
 * Requirements: 7.1 - Only access repositories that the user has explicitly granted access to
 * 
 * @param userId - The user's ID
 * @param owner - Repository owner
 * @param repo - Repository name
 * @returns Access check result with error details if denied
 */
async function verifyRepoAccess(
  userId: string,
  owner: string,
  repo: string
): Promise<{ hasAccess: boolean; statusCode?: number; errorResponse?: any }> {
  return accessControlService.checkRepositoryAccessForRoute(userId, owner, repo);
}

const router = Router();

// Store OAuth states temporarily (in production, use Redis)
const oauthStates = new Map<string, { userId: string; expiresAt: number }>();

/**
 * GET /api/github/status
 * Check if user has GitHub connected
 */
router.get('/status', authenticateToken, async (req: Request, res: Response) => {
  try {
    const userId = (req as any).userId;
    const connection = await githubService.getConnection(userId);

    res.json({
      success: true,
      connected: !!connection,
      connection: connection ? {
        username: connection.githubUsername,
        email: connection.githubEmail,
        avatarUrl: connection.githubAvatarUrl,
        scopes: connection.scopes,
        connectedAt: connection.createdAt,
        lastUsedAt: connection.lastUsedAt,
      } : null,
    });
  } catch (error: any) {
    console.error('GitHub status error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * GET /api/github/auth-url
 * Get OAuth authorization URL
 */
router.get('/auth-url', authenticateToken, async (req: Request, res: Response) => {
  try {
    const userId = (req as any).userId;
    const state = uuidv4();

    // Store state for verification (expires in 10 minutes)
    oauthStates.set(state, {
      userId,
      expiresAt: Date.now() + 10 * 60 * 1000,
    });

    const authUrl = githubService.getAuthUrl(state);

    res.json({
      success: true,
      authUrl,
      state,
    });
  } catch (error: any) {
    console.error('GitHub auth URL error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * GET /api/github/callback
 * OAuth callback handler
 */
router.get('/callback', async (req: Request, res: Response) => {
  try {
    const { code, state, error } = req.query;

    if (error) {
      return res.redirect(`/settings?github_error=${encodeURIComponent(error as string)}`);
    }

    if (!code || !state) {
      return res.redirect('/settings?github_error=missing_params');
    }

    // Verify state
    const stateData = oauthStates.get(state as string);
    if (!stateData || stateData.expiresAt < Date.now()) {
      oauthStates.delete(state as string);
      return res.redirect('/settings?github_error=invalid_state');
    }

    const userId = stateData.userId;
    oauthStates.delete(state as string);

    // Exchange code for token
    const tokenData = await githubService.exchangeCodeForToken(code as string);

    // Connect account
    await githubService.connectWithPAT(userId, tokenData.accessToken);

    // Redirect to success page
    res.redirect('/settings?github_connected=true');
  } catch (error: any) {
    console.error('GitHub callback error:', error);
    res.redirect(`/settings?github_error=${encodeURIComponent(error.message)}`);
  }
});

/**
 * POST /api/github/connect
 * Connect GitHub using Personal Access Token
 */
router.post('/connect', authenticateToken, async (req: Request, res: Response) => {
  try {
    const userId = (req as any).userId;
    const { token } = req.body;

    if (!token) {
      return res.status(400).json({ error: 'Missing token' });
    }

    const connection = await githubService.connectWithPAT(userId, token);

    res.json({
      success: true,
      connection: {
        username: connection.githubUsername,
        email: connection.githubEmail,
        avatarUrl: connection.githubAvatarUrl,
        scopes: connection.scopes,
      },
    });
  } catch (error: any) {
    console.error('GitHub connect error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * DELETE /api/github/disconnect
 * Disconnect GitHub account
 * Requirements: 7.5 - Token Revocation Cascade
 */
router.delete('/disconnect', authenticateToken, async (req: Request, res: Response) => {
  try {
    const userId = (req as any).userId;
    
    // First, handle the cascade effects (invalidate cache, notify agents)
    const revocationResult = await tokenRevocationService.handleDisconnect(userId);
    
    // Then disconnect the GitHub account
    await githubService.disconnect(userId);

    res.json({
      success: true,
      message: 'GitHub disconnected',
      details: {
        invalidatedCacheEntries: revocationResult.invalidatedCacheEntries,
        notifiedAgentSessions: revocationResult.notifiedAgentSessions,
      },
    });
  } catch (error: any) {
    console.error('GitHub disconnect error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * GET /api/github/repos
 * List user's repositories
 * Requirements: 3.1, 3.5, 7.1, 7.2
 */
router.get('/repos', authenticateToken, async (req: Request, res: Response) => {
  const userId = (req as any).userId;
  const agentSessionId = getAgentSessionId(req);
  
  try {
    // Check GitHub connection first (Requirements 3.5, 7.1, 7.2)
    const connectionCheck = await requireGitHubConnection(userId);
    if (!connectionCheck.connected) {
      await auditLoggerService.log({
        userId,
        action: 'list_repos',
        agentSessionId,
        success: false,
        errorMessage: connectionCheck.error!.message,
      });
      
      return res.status(401).json({
        success: false,
        error: connectionCheck.error!.code,
        message: connectionCheck.error!.message,
      });
    }

    // Validate agent session if provided (Requirements 7.2)
    const sessionValidation = await validateAgentSessionForRequest(agentSessionId, userId);
    if (!sessionValidation.valid) {
      await auditLoggerService.log({
        userId,
        action: 'list_repos',
        agentSessionId,
        success: false,
        errorMessage: sessionValidation.errorResponse?.message || 'Invalid agent session',
      });
      
      return res.status(sessionValidation.statusCode || 401).json(sessionValidation.errorResponse);
    }

    const { type, sort, page, perPage } = req.query;

    const repos = await githubService.listRepos(userId, {
      type: type as any,
      sort: sort as any,
      page: page ? parseInt(page as string) : undefined,
      perPage: perPage ? parseInt(perPage as string) : undefined,
    });

    // Log successful operation
    await auditLoggerService.log({
      userId,
      action: 'list_repos',
      agentSessionId,
      success: true,
      requestMetadata: { type, sort, page, perPage, count: repos.length },
    });

    res.json({
      success: true,
      repos,
      count: repos.length,
    });
  } catch (error: any) {
    console.error('GitHub repos error:', error);
    
    // Check for rate limit
    const rateLimitInfo = parseRateLimitError(error);
    if (rateLimitInfo.isRateLimited) {
      await auditLoggerService.log({
        userId,
        action: 'list_repos',
        agentSessionId,
        success: false,
        errorMessage: 'Rate limit exceeded',
        requestMetadata: { resetTime: rateLimitInfo.resetTime?.toISOString() },
      });
      
      return res.status(429).json({
        success: false,
        error: GITHUB_ERROR_CODES.RATE_LIMITED,
        message: formatRateLimitMessage(rateLimitInfo.resetTime),
        resetTime: rateLimitInfo.resetTime?.toISOString(),
      });
    }
    
    // Log failed operation
    await auditLoggerService.log({
      userId,
      action: 'list_repos',
      agentSessionId,
      success: false,
      errorMessage: error.message,
    });
    
    res.status(500).json({ 
      success: false,
      error: 'GITHUB_ERROR',
      message: error.message,
    });
  }
});

/**
 * GET /api/github/repos/:owner/:repo/tree
 * Get repository file tree
 * Requirements: 3.5, 7.1, 7.2, 7.4
 */
router.get('/repos/:owner/:repo/tree', authenticateToken, async (req: Request, res: Response) => {
  const userId = (req as any).userId;
  const { owner, repo } = req.params;
  const { branch } = req.query;
  const agentSessionId = getAgentSessionId(req);
  
  try {
    // Check GitHub connection first (Requirements 3.5, 7.1, 7.2)
    const connectionCheck = await requireGitHubConnection(userId);
    if (!connectionCheck.connected) {
      await auditLoggerService.log({
        userId,
        action: 'get_tree',
        owner,
        repo,
        agentSessionId,
        success: false,
        errorMessage: connectionCheck.error!.message,
      });
      
      return res.status(401).json({
        success: false,
        error: connectionCheck.error!.code,
        message: connectionCheck.error!.message,
      });
    }

    // Validate agent session if provided (Requirements 7.2)
    const sessionValidation = await validateAgentSessionForRequest(agentSessionId, userId);
    if (!sessionValidation.valid) {
      await auditLoggerService.log({
        userId,
        action: 'get_tree',
        owner,
        repo,
        agentSessionId,
        success: false,
        errorMessage: sessionValidation.errorResponse?.message || 'Invalid agent session',
      });
      
      return res.status(sessionValidation.statusCode || 401).json(sessionValidation.errorResponse);
    }

    // Verify repository access (Requirements 7.1)
    const accessCheck = await verifyRepoAccess(userId, owner, repo);
    if (!accessCheck.hasAccess) {
      await auditLoggerService.log({
        userId,
        action: 'get_tree',
        owner,
        repo,
        agentSessionId,
        success: false,
        errorMessage: accessCheck.errorResponse?.message || 'Repository access denied',
      });
      
      return res.status(accessCheck.statusCode || 403).json(accessCheck.errorResponse);
    }

    const tree = await githubService.getRepoTree(userId, owner, repo, branch as string);

    // Log successful operation
    await auditLoggerService.log({
      userId,
      action: 'get_tree',
      owner,
      repo,
      agentSessionId,
      success: true,
      requestMetadata: { branch, fileCount: tree.length },
    });

    res.json({
      success: true,
      tree,
      count: tree.length,
    });
  } catch (error: any) {
    console.error('GitHub tree error:', error);
    
    // Check for rate limit (Requirements 7.4)
    const rateLimitInfo = parseRateLimitError(error);
    if (rateLimitInfo.isRateLimited) {
      await auditLoggerService.log({
        userId,
        action: 'get_tree',
        owner,
        repo,
        agentSessionId,
        success: false,
        errorMessage: 'Rate limit exceeded',
        requestMetadata: { resetTime: rateLimitInfo.resetTime?.toISOString() },
      });
      
      return res.status(429).json({
        success: false,
        error: GITHUB_ERROR_CODES.RATE_LIMITED,
        message: formatRateLimitMessage(rateLimitInfo.resetTime),
        resetTime: rateLimitInfo.resetTime?.toISOString(),
      });
    }
    
    // Log failed operation
    await auditLoggerService.log({
      userId,
      action: 'get_tree',
      owner,
      repo,
      agentSessionId,
      success: false,
      errorMessage: error.message,
    });
    
    res.status(500).json({ 
      success: false,
      error: 'GITHUB_ERROR',
      message: error.message,
    });
  }
});

/**
 * GET /api/github/repos/:owner/:repo/contents/*
 * Get file contents
 * Requirements: 3.2, 3.5, 7.1, 7.2, 7.4
 */
router.get('/repos/:owner/:repo/contents/*', authenticateToken, async (req: Request, res: Response) => {
  const userId = (req as any).userId;
  const { owner, repo } = req.params;
  const path = req.params[0] || '';
  const { branch } = req.query;
  const agentSessionId = getAgentSessionId(req);
  
  try {
    // Check GitHub connection first (Requirements 3.5, 7.1, 7.2)
    const connectionCheck = await requireGitHubConnection(userId);
    if (!connectionCheck.connected) {
      await auditLoggerService.log({
        userId,
        action: 'get_file',
        owner,
        repo,
        path,
        agentSessionId,
        success: false,
        errorMessage: connectionCheck.error!.message,
      });
      
      return res.status(401).json({
        success: false,
        error: connectionCheck.error!.code,
        message: connectionCheck.error!.message,
      });
    }

    // Validate agent session if provided (Requirements 7.2)
    const sessionValidation = await validateAgentSessionForRequest(agentSessionId, userId);
    if (!sessionValidation.valid) {
      await auditLoggerService.log({
        userId,
        action: 'get_file',
        owner,
        repo,
        path,
        agentSessionId,
        success: false,
        errorMessage: sessionValidation.errorResponse?.message || 'Invalid agent session',
      });
      
      return res.status(sessionValidation.statusCode || 401).json(sessionValidation.errorResponse);
    }

    // Verify repository access (Requirements 7.1)
    const accessCheck = await verifyRepoAccess(userId, owner, repo);
    if (!accessCheck.hasAccess) {
      await auditLoggerService.log({
        userId,
        action: 'get_file',
        owner,
        repo,
        path,
        agentSessionId,
        success: false,
        errorMessage: accessCheck.errorResponse?.message || 'Repository access denied',
      });
      
      return res.status(accessCheck.statusCode || 403).json(accessCheck.errorResponse);
    }

    const content = await githubService.getFileContent(userId, owner, repo, path, branch as string);

    // Log successful operation
    await auditLoggerService.log({
      userId,
      action: 'get_file',
      owner,
      repo,
      path,
      agentSessionId,
      success: true,
      requestMetadata: { branch, fileSize: content.size },
    });

    res.json({
      success: true,
      file: content,
    });
  } catch (error: any) {
    console.error('GitHub content error:', error);
    
    // Check for rate limit (Requirements 7.4)
    const rateLimitInfo = parseRateLimitError(error);
    if (rateLimitInfo.isRateLimited) {
      await auditLoggerService.log({
        userId,
        action: 'get_file',
        owner,
        repo,
        path,
        agentSessionId,
        success: false,
        errorMessage: 'Rate limit exceeded',
        requestMetadata: { resetTime: rateLimitInfo.resetTime?.toISOString() },
      });
      
      return res.status(429).json({
        success: false,
        error: GITHUB_ERROR_CODES.RATE_LIMITED,
        message: formatRateLimitMessage(rateLimitInfo.resetTime),
        resetTime: rateLimitInfo.resetTime?.toISOString(),
      });
    }
    
    // Log failed operation
    await auditLoggerService.log({
      userId,
      action: 'get_file',
      owner,
      repo,
      path,
      agentSessionId,
      success: false,
      errorMessage: error.message,
    });
    
    res.status(500).json({ 
      success: false,
      error: 'GITHUB_ERROR',
      message: error.message,
    });
  }
});

/**
 * GET /api/github/repos/:owner/:repo/readme
 * Get repository README
 * Requirements: 3.5, 7.1, 7.2, 7.4
 */
router.get('/repos/:owner/:repo/readme', authenticateToken, async (req: Request, res: Response) => {
  const userId = (req as any).userId;
  const { owner, repo } = req.params;
  const agentSessionId = getAgentSessionId(req);
  
  try {
    // Check GitHub connection first (Requirements 3.5, 7.1, 7.2)
    const connectionCheck = await requireGitHubConnection(userId);
    if (!connectionCheck.connected) {
      return res.status(401).json({
        success: false,
        error: connectionCheck.error!.code,
        message: connectionCheck.error!.message,
      });
    }

    const readme = await githubService.getReadme(userId, owner, repo);

    res.json({
      success: true,
      readme,
    });
  } catch (error: any) {
    console.error('GitHub readme error:', error);
    
    // Check for rate limit (Requirements 7.4)
    const rateLimitInfo = parseRateLimitError(error);
    if (rateLimitInfo.isRateLimited) {
      return res.status(429).json({
        success: false,
        error: GITHUB_ERROR_CODES.RATE_LIMITED,
        message: formatRateLimitMessage(rateLimitInfo.resetTime),
        resetTime: rateLimitInfo.resetTime?.toISOString(),
      });
    }
    
    res.status(500).json({ 
      success: false,
      error: 'GITHUB_ERROR',
      message: error.message,
    });
  }
});

/**
 * GET /api/github/search
 * Search code across repositories
 * Requirements: 3.3, 3.5, 7.1, 7.2, 7.4
 */
router.get('/search', authenticateToken, async (req: Request, res: Response) => {
  const userId = (req as any).userId;
  const { q, repo, language, path, perPage } = req.query;
  const agentSessionId = getAgentSessionId(req);
  
  // Parse owner/repo from repo query param if provided
  let owner: string | undefined;
  let repoName: string | undefined;
  if (repo && typeof repo === 'string' && repo.includes('/')) {
    [owner, repoName] = repo.split('/');
  }
  
  try {
    // Check GitHub connection first (Requirements 3.5, 7.1, 7.2)
    const connectionCheck = await requireGitHubConnection(userId);
    if (!connectionCheck.connected) {
      await auditLoggerService.log({
        userId,
        action: 'search',
        owner,
        repo: repoName,
        agentSessionId,
        success: false,
        errorMessage: connectionCheck.error!.message,
      });
      
      return res.status(401).json({
        success: false,
        error: connectionCheck.error!.code,
        message: connectionCheck.error!.message,
      });
    }

    // Validate agent session if provided (Requirements 7.2)
    const sessionValidation = await validateAgentSessionForRequest(agentSessionId, userId);
    if (!sessionValidation.valid) {
      await auditLoggerService.log({
        userId,
        action: 'search',
        owner,
        repo: repoName,
        agentSessionId,
        success: false,
        errorMessage: sessionValidation.errorResponse?.message || 'Invalid agent session',
      });
      
      return res.status(sessionValidation.statusCode || 401).json(sessionValidation.errorResponse);
    }

    if (!q) {
      return res.status(400).json({ 
        success: false,
        error: GITHUB_ERROR_CODES.INVALID_REQUEST,
        message: 'Missing search query (q)',
      });
    }

    const results = await githubService.searchCode(userId, q as string, {
      repo: repo as string,
      language: language as string,
      path: path as string,
      perPage: perPage ? parseInt(perPage as string) : undefined,
    });

    // Log successful operation
    await auditLoggerService.log({
      userId,
      action: 'search',
      owner,
      repo: repoName,
      agentSessionId,
      success: true,
      requestMetadata: { query: q, language, path, resultCount: results.length },
    });

    res.json({
      success: true,
      results,
      count: results.length,
    });
  } catch (error: any) {
    console.error('GitHub search error:', error);
    
    // Check for rate limit (Requirements 7.4)
    const rateLimitInfo = parseRateLimitError(error);
    if (rateLimitInfo.isRateLimited) {
      await auditLoggerService.log({
        userId,
        action: 'search',
        owner,
        repo: repoName,
        agentSessionId,
        success: false,
        errorMessage: 'Rate limit exceeded',
        requestMetadata: { resetTime: rateLimitInfo.resetTime?.toISOString() },
      });
      
      return res.status(429).json({
        success: false,
        error: GITHUB_ERROR_CODES.RATE_LIMITED,
        message: formatRateLimitMessage(rateLimitInfo.resetTime),
        resetTime: rateLimitInfo.resetTime?.toISOString(),
      });
    }
    
    // Log failed operation
    await auditLoggerService.log({
      userId,
      action: 'search',
      owner,
      repo: repoName,
      agentSessionId,
      success: false,
      errorMessage: error.message,
      requestMetadata: { query: q },
    });
    
    res.status(500).json({ 
      success: false,
      error: 'GITHUB_ERROR',
      message: error.message,
    });
  }
});

/**
 * POST /api/github/repos/:owner/:repo/issues
 * Create an issue
 * Requirements: 3.5, 7.1, 7.2, 7.4
 */
router.post('/repos/:owner/:repo/issues', authenticateToken, async (req: Request, res: Response) => {
  const userId = (req as any).userId;
  const { owner, repo } = req.params;
  const { title, body, labels } = req.body;
  const agentSessionId = getAgentSessionId(req);
  
  try {
    // Check GitHub connection first (Requirements 3.5, 7.1, 7.2)
    const connectionCheck = await requireGitHubConnection(userId);
    if (!connectionCheck.connected) {
      await auditLoggerService.log({
        userId,
        action: 'create_issue',
        owner,
        repo,
        agentSessionId,
        success: false,
        errorMessage: connectionCheck.error!.message,
      });
      
      return res.status(401).json({
        success: false,
        error: connectionCheck.error!.code,
        message: connectionCheck.error!.message,
      });
    }

    // Validate agent session if provided (Requirements 7.2)
    const sessionValidation = await validateAgentSessionForRequest(agentSessionId, userId);
    if (!sessionValidation.valid) {
      await auditLoggerService.log({
        userId,
        action: 'create_issue',
        owner,
        repo,
        agentSessionId,
        success: false,
        errorMessage: sessionValidation.errorResponse?.message || 'Invalid agent session',
      });
      
      return res.status(sessionValidation.statusCode || 401).json(sessionValidation.errorResponse);
    }

    // Verify repository access (Requirements 7.1)
    const accessCheck = await verifyRepoAccess(userId, owner, repo);
    if (!accessCheck.hasAccess) {
      await auditLoggerService.log({
        userId,
        action: 'create_issue',
        owner,
        repo,
        agentSessionId,
        success: false,
        errorMessage: accessCheck.errorResponse?.message || 'Repository access denied',
      });
      
      return res.status(accessCheck.statusCode || 403).json(accessCheck.errorResponse);
    }

    if (!title) {
      return res.status(400).json({ 
        success: false,
        error: GITHUB_ERROR_CODES.INVALID_REQUEST,
        message: 'Missing title',
      });
    }

    const issue = await githubService.createIssue(userId, owner, repo, title, body, labels);

    // Log successful operation with issue details
    await auditLoggerService.log({
      userId,
      action: 'create_issue',
      owner,
      repo,
      agentSessionId,
      success: true,
      requestMetadata: { 
        issueTitle: title, 
        issueBody: body, 
        labels,
        issueNumber: issue.number,
        issueUrl: issue.htmlUrl,
      },
    });

    res.json({
      success: true,
      issue,
    });
  } catch (error: any) {
    console.error('GitHub create issue error:', error);
    
    // Check for rate limit (Requirements 7.4)
    const rateLimitInfo = parseRateLimitError(error);
    if (rateLimitInfo.isRateLimited) {
      await auditLoggerService.log({
        userId,
        action: 'create_issue',
        owner,
        repo,
        agentSessionId,
        success: false,
        errorMessage: 'Rate limit exceeded',
        requestMetadata: { resetTime: rateLimitInfo.resetTime?.toISOString() },
      });
      
      return res.status(429).json({
        success: false,
        error: GITHUB_ERROR_CODES.RATE_LIMITED,
        message: formatRateLimitMessage(rateLimitInfo.resetTime),
        resetTime: rateLimitInfo.resetTime?.toISOString(),
      });
    }
    
    // Log failed operation
    await auditLoggerService.log({
      userId,
      action: 'create_issue',
      owner,
      repo,
      agentSessionId,
      success: false,
      errorMessage: error.message,
      requestMetadata: { issueTitle: title, issueBody: body, labels },
    });
    
    res.status(500).json({ 
      success: false,
      error: 'GITHUB_ERROR',
      message: error.message,
    });
  }
});

/**
 * POST /api/github/repos/:owner/:repo/issues/:number/comments
 * Add comment to issue/PR
 * Requirements: 3.5, 7.1, 7.2, 7.4
 */
router.post('/repos/:owner/:repo/issues/:number/comments', authenticateToken, async (req: Request, res: Response) => {
  const userId = (req as any).userId;
  const { owner, repo, number } = req.params;
  const { body } = req.body;
  const agentSessionId = getAgentSessionId(req);
  
  try {
    // Check GitHub connection first (Requirements 3.5, 7.1, 7.2)
    const connectionCheck = await requireGitHubConnection(userId);
    if (!connectionCheck.connected) {
      return res.status(401).json({
        success: false,
        error: connectionCheck.error!.code,
        message: connectionCheck.error!.message,
      });
    }

    if (!body) {
      return res.status(400).json({ 
        success: false,
        error: GITHUB_ERROR_CODES.INVALID_REQUEST,
        message: 'Missing body',
      });
    }

    const comment = await githubService.addComment(
      userId, 
      owner, 
      repo, 
      parseInt(number), 
      body
    );

    res.json({
      success: true,
      comment,
    });
  } catch (error: any) {
    console.error('GitHub add comment error:', error);
    
    // Check for rate limit (Requirements 7.4)
    const rateLimitInfo = parseRateLimitError(error);
    if (rateLimitInfo.isRateLimited) {
      return res.status(429).json({
        success: false,
        error: GITHUB_ERROR_CODES.RATE_LIMITED,
        message: formatRateLimitMessage(rateLimitInfo.resetTime),
        resetTime: rateLimitInfo.resetTime?.toISOString(),
      });
    }
    
    res.status(500).json({ 
      success: false,
      error: 'GITHUB_ERROR',
      message: error.message,
    });
  }
});

/**
 * POST /api/github/add-source
 * Add a GitHub file as a source to a notebook
 * Uses GitHubSourceService for full metadata and caching (Requirements 3.4)
 */
router.post('/add-source', authenticateToken, async (req: Request, res: Response) => {
  const userId = (req as any).userId;
  const { notebookId, owner, repo, path, branch } = req.body;
  const agentSessionId = getAgentSessionId(req);
  const agentName = req.headers['x-agent-name'] as string | undefined;
  
  try {
    if (!notebookId || !owner || !repo || !path) {
      return res.status(400).json({ 
        success: false,
        error: GITHUB_ERROR_CODES.INVALID_REQUEST,
        message: 'Missing required fields: notebookId, owner, repo, path',
      });
    }

    // Check GitHub connection first
    const connectionCheck = await requireGitHubConnection(userId);
    if (!connectionCheck.connected) {
      // Log failed operation
      await auditLoggerService.log({
        userId,
        action: 'add_source',
        owner,
        repo,
        path,
        agentSessionId,
        success: false,
        errorMessage: connectionCheck.error!.message,
      });
      
      return res.status(401).json({
        success: false,
        error: connectionCheck.error!.code,
        message: connectionCheck.error!.message,
      });
    }

    // Validate agent session if provided (Requirements 7.2)
    const sessionValidation = await validateAgentSessionForRequest(agentSessionId, userId);
    if (!sessionValidation.valid) {
      await auditLoggerService.log({
        userId,
        action: 'add_source',
        owner,
        repo,
        path,
        agentSessionId,
        success: false,
        errorMessage: sessionValidation.errorResponse?.message || 'Invalid agent session',
      });
      
      return res.status(sessionValidation.statusCode || 401).json(sessionValidation.errorResponse);
    }

    // Verify repository access (Requirements 7.1)
    const accessCheck = await verifyRepoAccess(userId, owner, repo);
    if (!accessCheck.hasAccess) {
      await auditLoggerService.log({
        userId,
        action: 'add_source',
        owner,
        repo,
        path,
        agentSessionId,
        success: false,
        errorMessage: accessCheck.errorResponse?.message || 'Repository access denied',
      });
      
      return res.status(accessCheck.statusCode || 403).json(accessCheck.errorResponse);
    }

    // Use GitHubSourceService to create source with full metadata
    const source = await githubSourceService.createSource({
      notebookId,
      owner,
      repo,
      path,
      branch,
      userId,
      agentSessionId,
      agentName,
    });

    // Log successful operation
    await auditLoggerService.log({
      userId,
      action: 'add_source',
      owner,
      repo,
      path,
      agentSessionId,
      success: true,
      requestMetadata: { 
        notebookId, 
        sourceId: source.id, 
        branch: source.metadata.branch,
        language: source.metadata.language,
        fileSize: source.metadata.size,
        commitSha: source.metadata.commitSha,
      },
    });

    res.json({
      success: true,
      source: {
        id: source.id,
        notebookId: source.notebookId,
        type: source.type,
        title: source.title,
        content: source.content,
        metadata: source.metadata,
        createdAt: source.createdAt,
        updatedAt: source.updatedAt,
      },
    });
  } catch (error: any) {
    console.error('GitHub add source error:', error);
    
    // Check for rate limit
    const rateLimitInfo = parseRateLimitError(error);
    if (rateLimitInfo.isRateLimited) {
      await auditLoggerService.log({
        userId,
        action: 'add_source',
        owner,
        repo,
        path,
        agentSessionId,
        success: false,
        errorMessage: 'Rate limit exceeded',
        requestMetadata: { resetTime: rateLimitInfo.resetTime?.toISOString() },
      });
      
      return res.status(429).json({
        success: false,
        error: GITHUB_ERROR_CODES.RATE_LIMITED,
        message: formatRateLimitMessage(rateLimitInfo.resetTime),
        resetTime: rateLimitInfo.resetTime?.toISOString(),
      });
    }
    
    // Log failed operation
    await auditLoggerService.log({
      userId,
      action: 'add_source',
      owner,
      repo,
      path,
      agentSessionId,
      success: false,
      errorMessage: error.message,
      requestMetadata: { notebookId, branch },
    });
    
    // Check for specific error types
    if (error.message === 'GitHub not connected') {
      return res.status(401).json({
        success: false,
        error: GITHUB_ERROR_CODES.NOT_CONNECTED,
        message: 'GitHub account not connected. Please connect your GitHub account in Settings.',
      });
    }
    
    if (error.message?.includes('not found') || error.message?.includes('404')) {
      return res.status(404).json({
        success: false,
        error: GITHUB_ERROR_CODES.NOT_FOUND,
        message: `File not found: ${owner}/${repo}/${path}`,
      });
    }
    
    res.status(500).json({ 
      success: false,
      error: 'GITHUB_ERROR',
      message: error.message,
    });
  }
});


/**
 * POST /api/github/analyze
 * AI analysis of a GitHub repository
 * Requirements: 3.5, 7.1, 7.2, 7.4
 */
router.post('/analyze', authenticateToken, async (req: Request, res: Response) => {
  const userId = (req as any).userId;
  const { owner, repo, focus, includeFiles } = req.body;
  const agentSessionId = getAgentSessionId(req);
  
  try {
    // Check GitHub connection first (Requirements 3.5, 7.1, 7.2)
    const connectionCheck = await requireGitHubConnection(userId);
    if (!connectionCheck.connected) {
      await auditLoggerService.log({
        userId,
        action: 'analyze_repo',
        owner,
        repo,
        agentSessionId,
        success: false,
        errorMessage: connectionCheck.error!.message,
      });
      
      return res.status(401).json({
        success: false,
        error: connectionCheck.error!.code,
        message: connectionCheck.error!.message,
      });
    }

    // Validate agent session if provided (Requirements 7.2)
    const sessionValidation = await validateAgentSessionForRequest(agentSessionId, userId);
    if (!sessionValidation.valid) {
      await auditLoggerService.log({
        userId,
        action: 'analyze_repo',
        owner,
        repo,
        agentSessionId,
        success: false,
        errorMessage: sessionValidation.errorResponse?.message || 'Invalid agent session',
      });
      
      return res.status(sessionValidation.statusCode || 401).json(sessionValidation.errorResponse);
    }

    if (!owner || !repo) {
      return res.status(400).json({ 
        success: false,
        error: GITHUB_ERROR_CODES.INVALID_REQUEST,
        message: 'Missing required fields: owner, repo',
      });
    }

    // Verify repository access (Requirements 7.1)
    const accessCheck = await verifyRepoAccess(userId, owner, repo);
    if (!accessCheck.hasAccess) {
      await auditLoggerService.log({
        userId,
        action: 'analyze_repo',
        owner,
        repo,
        agentSessionId,
        success: false,
        errorMessage: accessCheck.errorResponse?.message || 'Repository access denied',
      });
      
      return res.status(accessCheck.statusCode || 403).json(accessCheck.errorResponse);
    }

    // Get repository info
    const repos = await githubService.listRepos(userId, { type: 'all' });
    const targetRepo = repos.find(r => r.fullName === `${owner}/${repo}`);

    // Get README
    const readme = await githubService.getReadme(userId, owner, repo);

    // Get file tree
    const tree = await githubService.getRepoTree(userId, owner, repo);

    // Get specific files if requested
    const fileContents: Array<{ path: string; content: string }> = [];
    if (includeFiles && includeFiles.length > 0) {
      for (const filePath of includeFiles.slice(0, 5)) { // Limit to 5 files
        try {
          const file = await githubService.getFileContent(userId, owner, repo, filePath);
          if (file.content) {
            fileContents.push({ path: filePath, content: file.content });
          }
        } catch (e) {
          // Skip files that can't be read
        }
      }
    }

    // Build analysis context
    const analysisContext = {
      repository: {
        fullName: `${owner}/${repo}`,
        description: targetRepo?.description || 'No description',
        language: targetRepo?.language || 'Unknown',
        isPrivate: targetRepo?.isPrivate || false,
        stars: targetRepo?.starsCount || 0,
        forks: targetRepo?.forksCount || 0,
      },
      structure: {
        totalFiles: tree.filter(t => t.type === 'blob').length,
        totalDirectories: tree.filter(t => t.type === 'tree').length,
        topLevelItems: tree.filter(t => !t.path.includes('/')).map(t => ({
          name: t.path,
          type: t.type === 'blob' ? 'file' : 'directory',
        })),
      },
      readme: readme ? readme.substring(0, 2000) : null,
      files: fileContents,
      focus: focus || 'general',
    };

    // Generate AI analysis using the AI service (with fallback)
    const { generateWithGemini, generateWithOpenRouter } = await import('../services/aiService.js');
    
    const prompt = `Analyze this GitHub repository and provide insights:

Repository: ${analysisContext.repository.fullName}
Description: ${analysisContext.repository.description}
Primary Language: ${analysisContext.repository.language}
Stars: ${analysisContext.repository.stars} | Forks: ${analysisContext.repository.forks}

Structure:
- ${analysisContext.structure.totalFiles} files
- ${analysisContext.structure.totalDirectories} directories
- Top-level: ${analysisContext.structure.topLevelItems.map(i => i.name).join(', ')}

${analysisContext.readme ? `README (excerpt):\n${analysisContext.readme}\n` : ''}

${fileContents.length > 0 ? `Key Files:\n${fileContents.map(f => `--- ${f.path} ---\n${f.content.substring(0, 1000)}`).join('\n\n')}` : ''}

Focus area: ${analysisContext.focus}

Please provide:
1. Repository Overview - What this project does
2. Architecture Analysis - How the code is organized
3. Technology Stack - Languages, frameworks, tools used
4. Code Quality Observations - Patterns, potential issues
5. Recommendations - Improvements or best practices
${focus ? `6. Specific ${focus} Analysis` : ''}`;

    // Try Gemini first, fallback to OpenRouter if Gemini fails
    let analysis: string;
    try {
      analysis = await generateWithGemini([{ role: 'user', content: prompt }]);
    } catch (geminiError: any) {
      console.log('Gemini failed, falling back to OpenRouter:', geminiError.message);
      try {
        analysis = await generateWithOpenRouter([{ role: 'user', content: prompt }]);
      } catch (openRouterError: any) {
        console.error('Both AI services failed:', { gemini: geminiError.message, openRouter: openRouterError.message });
        throw new Error('AI analysis unavailable. Please check that GEMINI_API_KEY or OPENROUTER_API_KEY is configured in the backend.');
      }
    }

    // Log successful operation
    await auditLoggerService.log({
      userId,
      action: 'analyze_repo',
      owner,
      repo,
      agentSessionId,
      success: true,
      requestMetadata: { 
        focus, 
        includeFilesCount: includeFiles?.length || 0,
        totalFiles: analysisContext.structure.totalFiles,
        language: analysisContext.repository.language,
      },
    });

    res.json({
      success: true,
      repository: analysisContext.repository,
      structure: analysisContext.structure,
      analysis,
      analyzedAt: new Date().toISOString(),
    });
  } catch (error: any) {
    console.error('GitHub analyze error:', error);
    
    // Check for rate limit (Requirements 7.4)
    const rateLimitInfo = parseRateLimitError(error);
    if (rateLimitInfo.isRateLimited) {
      await auditLoggerService.log({
        userId,
        action: 'analyze_repo',
        owner,
        repo,
        agentSessionId,
        success: false,
        errorMessage: 'Rate limit exceeded',
        requestMetadata: { resetTime: rateLimitInfo.resetTime?.toISOString() },
      });
      
      return res.status(429).json({
        success: false,
        error: GITHUB_ERROR_CODES.RATE_LIMITED,
        message: formatRateLimitMessage(rateLimitInfo.resetTime),
        resetTime: rateLimitInfo.resetTime?.toISOString(),
      });
    }
    
    // Log failed operation
    await auditLoggerService.log({
      userId,
      action: 'analyze_repo',
      owner,
      repo,
      agentSessionId,
      success: false,
      errorMessage: error.message,
      requestMetadata: { focus },
    });
    
    res.status(500).json({ 
      success: false,
      error: 'GITHUB_ERROR',
      message: error.message,
    });
  }
});

/**
 * POST /api/github/sources/:sourceId/refresh
 * Refresh a GitHub source with latest content from GitHub
 * Requirements: 1.3 - Fetch latest content if cached version is older than 1 hour
 */
router.post('/sources/:sourceId/refresh', authenticateToken, async (req: Request, res: Response) => {
  const userId = (req as any).userId;
  const { sourceId } = req.params;
  const agentSessionId = getAgentSessionId(req);
  
  try {
    // Check GitHub connection first
    const connectionCheck = await requireGitHubConnection(userId);
    if (!connectionCheck.connected) {
      await auditLoggerService.log({
        userId,
        action: 'refresh_source',
        agentSessionId,
        success: false,
        errorMessage: connectionCheck.error!.message,
        requestMetadata: { sourceId },
      });
      
      return res.status(401).json({
        success: false,
        error: connectionCheck.error!.code,
        message: connectionCheck.error!.message,
      });
    }

    // Get the source before refresh to compare SHA
    const beforeSource = await githubSourceService.getSourceWithContent(sourceId, userId);
    const beforeSha = beforeSource.metadata.commitSha;

    // Refresh the source
    const source = await githubSourceService.refreshSource(sourceId, userId);
    const hasUpdates = source.metadata.commitSha !== beforeSha;

    // Log successful operation
    await auditLoggerService.log({
      userId,
      action: 'refresh_source',
      owner: source.metadata.owner,
      repo: source.metadata.repo,
      path: source.metadata.path,
      agentSessionId,
      success: true,
      requestMetadata: { 
        sourceId, 
        hasUpdates,
        oldSha: beforeSha,
        newSha: source.metadata.commitSha,
      },
    });

    res.json({
      success: true,
      source: {
        id: source.id,
        notebookId: source.notebookId,
        type: source.type,
        title: source.title,
        content: source.content,
        metadata: source.metadata,
        createdAt: source.createdAt,
        updatedAt: source.updatedAt,
      },
      hasUpdates,
    });
  } catch (error: any) {
    console.error('GitHub refresh source error:', error);
    
    // Check for rate limit
    const rateLimitInfo = parseRateLimitError(error);
    if (rateLimitInfo.isRateLimited) {
      await auditLoggerService.log({
        userId,
        action: 'refresh_source',
        agentSessionId,
        success: false,
        errorMessage: 'Rate limit exceeded',
        requestMetadata: { sourceId, resetTime: rateLimitInfo.resetTime?.toISOString() },
      });
      
      return res.status(429).json({
        success: false,
        error: GITHUB_ERROR_CODES.RATE_LIMITED,
        message: formatRateLimitMessage(rateLimitInfo.resetTime),
        resetTime: rateLimitInfo.resetTime?.toISOString(),
      });
    }
    
    // Log failed operation
    await auditLoggerService.log({
      userId,
      action: 'refresh_source',
      agentSessionId,
      success: false,
      errorMessage: error.message,
      requestMetadata: { sourceId },
    });
    
    if (error.message?.includes('not found') || error.message?.includes('access denied')) {
      return res.status(404).json({
        success: false,
        error: GITHUB_ERROR_CODES.NOT_FOUND,
        message: 'GitHub source not found or access denied',
      });
    }
    
    res.status(500).json({ 
      success: false,
      error: 'GITHUB_ERROR',
      message: error.message,
    });
  }
});

/**
 * GET /api/github/sources/:sourceId/check-updates
 * Check if a GitHub source has updates (commit SHA differs)
 * Requirements: 1.4 - Display "File Updated" indicator if file has been modified
 */
router.get('/sources/:sourceId/check-updates', authenticateToken, async (req: Request, res: Response) => {
  const userId = (req as any).userId;
  const { sourceId } = req.params;
  const agentSessionId = getAgentSessionId(req);
  
  try {
    // Check GitHub connection first
    const connectionCheck = await requireGitHubConnection(userId);
    if (!connectionCheck.connected) {
      return res.status(401).json({
        success: false,
        error: connectionCheck.error!.code,
        message: connectionCheck.error!.message,
      });
    }

    // Check for updates
    const result = await githubSourceService.checkForUpdates(sourceId, userId);

    res.json({
      success: true,
      hasUpdates: result.hasUpdates,
      currentSha: result.currentSha,
      newSha: result.newSha,
    });
  } catch (error: any) {
    console.error('GitHub check updates error:', error);
    
    // Check for rate limit
    const rateLimitInfo = parseRateLimitError(error);
    if (rateLimitInfo.isRateLimited) {
      return res.status(429).json({
        success: false,
        error: GITHUB_ERROR_CODES.RATE_LIMITED,
        message: formatRateLimitMessage(rateLimitInfo.resetTime),
        resetTime: rateLimitInfo.resetTime?.toISOString(),
      });
    }
    
    if (error.message?.includes('not found') || error.message?.includes('access denied')) {
      return res.status(404).json({
        success: false,
        error: GITHUB_ERROR_CODES.NOT_FOUND,
        message: 'GitHub source not found or access denied',
      });
    }
    
    res.status(500).json({ 
      success: false,
      error: 'GITHUB_ERROR',
      message: error.message,
    });
  }
});

export default router;

// Export helper functions and error codes for use in other modules
export { 
  GITHUB_ERROR_CODES, 
  parseRateLimitError, 
  formatRateLimitMessage, 
  requireGitHubConnection,
  getAgentSessionId,
  validateAgentSessionForRequest,
  verifyRepoAccess,
};
