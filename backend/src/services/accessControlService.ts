/**
 * Access Control Service
 * Handles repository access validation and agent session verification
 * 
 * Requirements: 7.1, 7.2
 * - 7.1: Only access repositories that the user has explicitly granted access to
 * - 7.2: Verify agent session belongs to requesting user
 */

import pool from '../config/database.js';
import { githubService } from './githubService.js';
import { agentSessionService } from './agentSessionService.js';

// ==================== INTERFACES ====================

export interface AccessCheckResult {
  hasAccess: boolean;
  error?: {
    code: string;
    message: string;
  };
}

export interface AgentSessionValidationResult {
  valid: boolean;
  session?: {
    id: string;
    userId: string;
    agentName: string;
    status: string;
  };
  error?: {
    code: string;
    message: string;
  };
}

/**
 * Error codes for access control operations
 */
export const ACCESS_CONTROL_ERROR_CODES = {
  REPOSITORY_ACCESS_DENIED: 'REPOSITORY_ACCESS_DENIED',
  INVALID_AGENT_SESSION: 'INVALID_AGENT_SESSION',
  SESSION_USER_MISMATCH: 'SESSION_USER_MISMATCH',
  SESSION_EXPIRED: 'SESSION_EXPIRED',
  SESSION_NOT_FOUND: 'SESSION_NOT_FOUND',
} as const;

// ==================== SERVICE CLASS ====================

class AccessControlService {
  /**
   * Verify that a user has access to a specific repository.
   * 
   * This checks if the repository is in the user's accessible repositories list
   * by querying the GitHub API through the user's connection.
   * 
   * Requirements: 7.1 - Only access repositories that the user has explicitly granted access to
   * 
   * @param userId - The user's ID
   * @param owner - Repository owner
   * @param repo - Repository name
   * @returns AccessCheckResult indicating if user has access
   */
  async verifyRepositoryAccess(
    userId: string,
    owner: string,
    repo: string
  ): Promise<AccessCheckResult> {
    try {
      // First check if user has GitHub connected
      const connection = await githubService.getConnection(userId);
      if (!connection) {
        return {
          hasAccess: false,
          error: {
            code: 'GITHUB_NOT_CONNECTED',
            message: 'GitHub account not connected. Please connect your GitHub account in Settings.',
          },
        };
      }

      // Check if the repository is in the cached repos for this user
      const cachedRepo = await this.getCachedRepository(connection.id, owner, repo);
      if (cachedRepo) {
        return { hasAccess: true };
      }

      // If not in cache, try to fetch the repository directly
      // This will throw if user doesn't have access
      try {
        const repos = await githubService.listRepos(userId, { type: 'all', perPage: 100 });
        const hasRepo = repos.some(r => 
          r.owner.toLowerCase() === owner.toLowerCase() && 
          r.name.toLowerCase() === repo.toLowerCase()
        );

        if (hasRepo) {
          return { hasAccess: true };
        }

        // Repository not found in user's accessible repos
        return {
          hasAccess: false,
          error: {
            code: ACCESS_CONTROL_ERROR_CODES.REPOSITORY_ACCESS_DENIED,
            message: `Access denied to repository ${owner}/${repo}. You may not have permission to access this repository.`,
          },
        };
      } catch (error: any) {
        // If we get a 404 or 403, the user doesn't have access
        if (error.status === 404 || error.status === 403) {
          return {
            hasAccess: false,
            error: {
              code: ACCESS_CONTROL_ERROR_CODES.REPOSITORY_ACCESS_DENIED,
              message: `Access denied to repository ${owner}/${repo}. You may not have permission to access this repository.`,
            },
          };
        }
        throw error;
      }
    } catch (error: any) {
      console.error('Repository access check error:', error);
      return {
        hasAccess: false,
        error: {
          code: ACCESS_CONTROL_ERROR_CODES.REPOSITORY_ACCESS_DENIED,
          message: error.message || 'Failed to verify repository access',
        },
      };
    }
  }

  /**
   * Validate that an agent session belongs to the requesting user.
   * 
   * Requirements: 7.2 - Verify agent session belongs to requesting user
   * 
   * @param sessionId - The agent session ID
   * @param userId - The requesting user's ID
   * @returns AgentSessionValidationResult indicating if session is valid for user
   */
  async validateAgentSession(
    sessionId: string,
    userId: string
  ): Promise<AgentSessionValidationResult> {
    try {
      // Get the session
      const session = await agentSessionService.getSession(sessionId);

      if (!session) {
        return {
          valid: false,
          error: {
            code: ACCESS_CONTROL_ERROR_CODES.SESSION_NOT_FOUND,
            message: 'Agent session not found',
          },
        };
      }

      // Check if session belongs to the requesting user
      if (session.userId !== userId) {
        return {
          valid: false,
          error: {
            code: ACCESS_CONTROL_ERROR_CODES.SESSION_USER_MISMATCH,
            message: 'Agent session does not belong to the requesting user',
          },
        };
      }

      // Check if session is active
      if (session.status !== 'active') {
        return {
          valid: false,
          error: {
            code: ACCESS_CONTROL_ERROR_CODES.SESSION_EXPIRED,
            message: `Agent session is ${session.status}. Please reconnect the agent.`,
          },
        };
      }

      return {
        valid: true,
        session: {
          id: session.id,
          userId: session.userId,
          agentName: session.agentName,
          status: session.status,
        },
      };
    } catch (error: any) {
      console.error('Agent session validation error:', error);
      return {
        valid: false,
        error: {
          code: ACCESS_CONTROL_ERROR_CODES.INVALID_AGENT_SESSION,
          message: error.message || 'Failed to validate agent session',
        },
      };
    }
  }

  /**
   * Validate agent session from request headers.
   * Returns null if no session ID is provided (optional validation).
   * 
   * @param agentSessionId - The agent session ID from headers
   * @param userId - The requesting user's ID
   * @returns AgentSessionValidationResult or null if no session ID
   */
  async validateAgentSessionFromRequest(
    agentSessionId: string | undefined,
    userId: string
  ): Promise<AgentSessionValidationResult | null> {
    if (!agentSessionId) {
      return null; // No session to validate
    }

    return this.validateAgentSession(agentSessionId, userId);
  }

  /**
   * Check if a repository is in the cached repos for a connection.
   * 
   * @param connectionId - The GitHub connection ID
   * @param owner - Repository owner
   * @param repo - Repository name
   * @returns The cached repository or null
   */
  private async getCachedRepository(
    connectionId: string,
    owner: string,
    repo: string
  ): Promise<any | null> {
    try {
      const result = await pool.query(
        `SELECT * FROM github_repos 
         WHERE connection_id = $1 
         AND LOWER(owner) = LOWER($2) 
         AND LOWER(name) = LOWER($3)`,
        [connectionId, owner, repo]
      );

      return result.rows.length > 0 ? result.rows[0] : null;
    } catch (error) {
      // Table might not exist or other error, return null
      return null;
    }
  }

  /**
   * Verify repository access and return 403 error details if denied.
   * Convenience method for route handlers.
   * 
   * @param userId - The user's ID
   * @param owner - Repository owner
   * @param repo - Repository name
   * @returns Object with hasAccess and optional error response
   */
  async checkRepositoryAccessForRoute(
    userId: string,
    owner: string,
    repo: string
  ): Promise<{
    hasAccess: boolean;
    statusCode?: number;
    errorResponse?: {
      success: false;
      error: string;
      message: string;
    };
  }> {
    const result = await this.verifyRepositoryAccess(userId, owner, repo);

    if (!result.hasAccess) {
      return {
        hasAccess: false,
        statusCode: result.error?.code === 'GITHUB_NOT_CONNECTED' ? 401 : 403,
        errorResponse: {
          success: false,
          error: result.error?.code || ACCESS_CONTROL_ERROR_CODES.REPOSITORY_ACCESS_DENIED,
          message: result.error?.message || 'Access denied',
        },
      };
    }

    return { hasAccess: true };
  }

  /**
   * Validate agent session and return error details if invalid.
   * Convenience method for route handlers.
   * 
   * @param agentSessionId - The agent session ID
   * @param userId - The requesting user's ID
   * @returns Object with valid flag and optional error response
   */
  async checkAgentSessionForRoute(
    agentSessionId: string | undefined,
    userId: string
  ): Promise<{
    valid: boolean;
    statusCode?: number;
    errorResponse?: {
      success: false;
      error: string;
      message: string;
    };
  }> {
    // If no session ID provided, consider it valid (session is optional)
    if (!agentSessionId) {
      return { valid: true };
    }

    const result = await this.validateAgentSession(agentSessionId, userId);

    if (!result.valid) {
      return {
        valid: false,
        statusCode: 401,
        errorResponse: {
          success: false,
          error: result.error?.code || ACCESS_CONTROL_ERROR_CODES.INVALID_AGENT_SESSION,
          message: result.error?.message || 'Invalid agent session',
        },
      };
    }

    return { valid: true };
  }
}

// Export singleton instance
export const accessControlService = new AccessControlService();
export default accessControlService;
