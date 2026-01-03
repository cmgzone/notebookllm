/**
 * GitHub Service
 * Handles GitHub OAuth, API calls, and repository management
 */

import { Octokit } from '@octokit/rest';
import crypto from 'crypto';
import pool from '../config/database.js';

// Encryption key from environment
const ENCRYPTION_KEY = process.env.GITHUB_ENCRYPTION_KEY || process.env.JWT_SECRET || 'default-key-change-me';

interface GitHubConnection {
  id: string;
  userId: string;
  githubUserId: string;
  githubUsername: string;
  githubEmail?: string;
  githubAvatarUrl?: string;
  scopes: string[];
  isActive: boolean;
  lastUsedAt?: Date;
  createdAt: Date;
  updatedAt: Date;
}

interface GitHubRepo {
  id: string;
  connectionId: string;
  githubRepoId: number;
  fullName: string;
  name: string;
  owner: string;
  description?: string;
  defaultBranch: string;
  isPrivate: boolean;
  isFork: boolean;
  language?: string;
  starsCount: number;
  forksCount: number;
  sizeKb: number;
  htmlUrl: string;
  cloneUrl: string;
  lastSyncedAt?: Date;
}

interface FileContent {
  name: string;
  path: string;
  sha: string;
  size: number;
  type: 'file' | 'dir';
  content?: string;
  encoding?: string;
  downloadUrl?: string;
}

interface TreeItem {
  path: string;
  type: 'blob' | 'tree';
  sha: string;
  size?: number;
}

class GitHubService {
  private clientId: string;
  private clientSecret: string;
  private redirectUri: string;

  constructor() {
    this.clientId = process.env.GITHUB_CLIENT_ID || '';
    this.clientSecret = process.env.GITHUB_CLIENT_SECRET || '';
    this.redirectUri = process.env.GITHUB_REDIRECT_URI || 'http://localhost:3000/api/github/callback';
  }

  // ==================== ENCRYPTION ====================

  private encrypt(text: string): string {
    const iv = crypto.randomBytes(16);
    const key = crypto.scryptSync(ENCRYPTION_KEY, 'salt', 32);
    const cipher = crypto.createCipheriv('aes-256-cbc', key, iv);
    let encrypted = cipher.update(text, 'utf8', 'hex');
    encrypted += cipher.final('hex');
    return iv.toString('hex') + ':' + encrypted;
  }

  private decrypt(encryptedText: string): string {
    const [ivHex, encrypted] = encryptedText.split(':');
    const iv = Buffer.from(ivHex, 'hex');
    const key = crypto.scryptSync(ENCRYPTION_KEY, 'salt', 32);
    const decipher = crypto.createDecipheriv('aes-256-cbc', key, iv);
    let decrypted = decipher.update(encrypted, 'hex', 'utf8');
    decrypted += decipher.final('utf8');
    return decrypted;
  }

  // ==================== OAUTH ====================

  /**
   * Generate OAuth authorization URL
   */
  getAuthUrl(state: string): string {
    const scopes = ['repo', 'read:user', 'user:email'];
    const params = new URLSearchParams({
      client_id: this.clientId,
      redirect_uri: this.redirectUri,
      scope: scopes.join(' '),
      state,
      allow_signup: 'true',
    });
    return `https://github.com/login/oauth/authorize?${params.toString()}`;
  }

  /**
   * Exchange OAuth code for access token
   */
  async exchangeCodeForToken(code: string): Promise<{
    accessToken: string;
    tokenType: string;
    scope: string;
  }> {
    const response = await fetch('https://github.com/login/oauth/access_token', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: JSON.stringify({
        client_id: this.clientId,
        client_secret: this.clientSecret,
        code,
        redirect_uri: this.redirectUri,
      }),
    });

    const data = await response.json() as {
      access_token?: string;
      token_type?: string;
      scope?: string;
      error?: string;
      error_description?: string;
    };
    
    if (data.error) {
      throw new Error(`GitHub OAuth error: ${data.error_description || data.error}`);
    }

    return {
      accessToken: data.access_token || '',
      tokenType: data.token_type || '',
      scope: data.scope || '',
    };
  }

  /**
   * Connect GitHub account using Personal Access Token
   */
  async connectWithPAT(userId: string, token: string): Promise<GitHubConnection> {
    // Validate token by fetching user info
    const octokit = new Octokit({ auth: token });
    const { data: user } = await octokit.users.getAuthenticated();

    // Check if connection already exists
    const existing = await pool.query(
      'SELECT id FROM github_connections WHERE user_id = $1',
      [userId]
    );

    const encryptedToken = this.encrypt(token);
    const scopes = ['repo', 'read:user']; // Assumed scopes for PAT

    if (existing.rows.length > 0) {
      // Update existing connection
      const result = await pool.query(
        `UPDATE github_connections 
         SET github_user_id = $1, github_username = $2, github_email = $3, 
             github_avatar_url = $4, access_token_encrypted = $5, scopes = $6,
             is_active = true, updated_at = NOW()
         WHERE user_id = $7
         RETURNING *`,
        [
          user.id.toString(),
          user.login,
          user.email,
          user.avatar_url,
          encryptedToken,
          scopes,
          userId,
        ]
      );
      return this.mapConnection(result.rows[0]);
    }

    // Create new connection
    const result = await pool.query(
      `INSERT INTO github_connections 
       (user_id, github_user_id, github_username, github_email, github_avatar_url, 
        access_token_encrypted, scopes)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING *`,
      [
        userId,
        user.id.toString(),
        user.login,
        user.email,
        user.avatar_url,
        encryptedToken,
        scopes,
      ]
    );

    return this.mapConnection(result.rows[0]);
  }

  /**
   * Get user's GitHub connection
   */
  async getConnection(userId: string): Promise<GitHubConnection | null> {
    const result = await pool.query(
      'SELECT * FROM github_connections WHERE user_id = $1 AND is_active = true',
      [userId]
    );

    if (result.rows.length === 0) return null;
    return this.mapConnection(result.rows[0]);
  }

  /**
   * Disconnect GitHub account
   */
  async disconnect(userId: string): Promise<void> {
    await pool.query(
      'UPDATE github_connections SET is_active = false, updated_at = NOW() WHERE user_id = $1',
      [userId]
    );
  }

  /**
   * Get Octokit instance for user
   */
  private async getOctokit(userId: string): Promise<Octokit> {
    const result = await pool.query(
      'SELECT access_token_encrypted FROM github_connections WHERE user_id = $1 AND is_active = true',
      [userId]
    );

    if (result.rows.length === 0) {
      throw new Error('GitHub not connected');
    }

    const token = this.decrypt(result.rows[0].access_token_encrypted);
    
    // Update last used
    await pool.query(
      'UPDATE github_connections SET last_used_at = NOW() WHERE user_id = $1',
      [userId]
    );

    return new Octokit({ auth: token });
  }

  // ==================== REPOSITORIES ====================

  /**
   * List user's repositories
   */
  async listRepos(userId: string, options: {
    type?: 'all' | 'owner' | 'member';
    sort?: 'created' | 'updated' | 'pushed' | 'full_name';
    perPage?: number;
    page?: number;
  } = {}): Promise<GitHubRepo[]> {
    const octokit = await this.getOctokit(userId);
    const connection = await this.getConnection(userId);
    
    if (!connection) throw new Error('GitHub not connected');

    const { data: repos } = await octokit.repos.listForAuthenticatedUser({
      type: options.type || 'all',
      sort: options.sort || 'updated',
      per_page: options.perPage || 30,
      page: options.page || 1,
    });

    // Cache repos in database
    for (const repo of repos) {
      await pool.query(
        `INSERT INTO github_repos 
         (connection_id, github_repo_id, full_name, name, owner, description, 
          default_branch, is_private, is_fork, language, stars_count, forks_count,
          size_kb, html_url, clone_url, last_synced_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, NOW())
         ON CONFLICT (connection_id, github_repo_id) 
         DO UPDATE SET 
           full_name = EXCLUDED.full_name,
           description = EXCLUDED.description,
           default_branch = EXCLUDED.default_branch,
           is_private = EXCLUDED.is_private,
           language = EXCLUDED.language,
           stars_count = EXCLUDED.stars_count,
           forks_count = EXCLUDED.forks_count,
           size_kb = EXCLUDED.size_kb,
           last_synced_at = NOW()`,
        [
          connection.id,
          repo.id,
          repo.full_name,
          repo.name,
          repo.owner.login,
          repo.description,
          repo.default_branch || 'main',
          repo.private,
          repo.fork,
          repo.language,
          repo.stargazers_count,
          repo.forks_count,
          repo.size,
          repo.html_url,
          repo.clone_url,
        ]
      );
    }

    return repos.map(repo => ({
      id: '', // Will be set from DB
      connectionId: connection.id,
      githubRepoId: repo.id,
      fullName: repo.full_name,
      name: repo.name,
      owner: repo.owner.login,
      description: repo.description || undefined,
      defaultBranch: repo.default_branch || 'main',
      isPrivate: repo.private,
      isFork: repo.fork,
      language: repo.language || undefined,
      starsCount: repo.stargazers_count || 0,
      forksCount: repo.forks_count || 0,
      sizeKb: repo.size || 0,
      htmlUrl: repo.html_url,
      cloneUrl: repo.clone_url || '',
    }));
  }

  /**
   * Get repository file tree
   */
  async getRepoTree(userId: string, owner: string, repo: string, branch?: string): Promise<TreeItem[]> {
    const octokit = await this.getOctokit(userId);

    // Get default branch if not specified
    if (!branch) {
      const { data: repoData } = await octokit.repos.get({ owner, repo });
      branch = repoData.default_branch;
    }

    const { data: tree } = await octokit.git.getTree({
      owner,
      repo,
      tree_sha: branch!,
      recursive: 'true',
    });

    return tree.tree.map(item => ({
      path: item.path || '',
      type: item.type as 'blob' | 'tree',
      sha: item.sha || '',
      size: item.size,
    }));
  }

  /**
   * Get file contents
   */
  async getFileContent(
    userId: string, 
    owner: string, 
    repo: string, 
    path: string,
    branch?: string
  ): Promise<FileContent> {
    const octokit = await this.getOctokit(userId);

    const { data } = await octokit.repos.getContent({
      owner,
      repo,
      path,
      ref: branch,
    });

    // Type guard: data can be an array (directory) or single item
    if (Array.isArray(data)) {
      throw new Error('Path is a directory, not a file');
    }

    // Type assertion for file content response
    const fileData = data as {
      type: string;
      name: string;
      path: string;
      sha: string;
      size: number;
      content?: string;
      encoding?: string;
      download_url?: string | null;
    };

    if (fileData.type !== 'file') {
      throw new Error(`Expected file, got ${fileData.type}`);
    }

    // Decode base64 content
    let content: string | undefined;
    if (fileData.content) {
      content = Buffer.from(fileData.content, 'base64').toString('utf-8');
    }

    return {
      name: fileData.name,
      path: fileData.path,
      sha: fileData.sha,
      size: fileData.size,
      type: 'file',
      content,
      encoding: fileData.encoding,
      downloadUrl: fileData.download_url || undefined,
    };
  }

  /**
   * Search code in repositories
   */
  async searchCode(
    userId: string,
    query: string,
    options: {
      repo?: string;
      language?: string;
      path?: string;
      perPage?: number;
    } = {}
  ): Promise<Array<{
    name: string;
    path: string;
    sha: string;
    repository: string;
    htmlUrl: string;
    textMatches?: string[];
  }>> {
    const octokit = await this.getOctokit(userId);

    // Build search query
    let searchQuery = query;
    if (options.repo) searchQuery += ` repo:${options.repo}`;
    if (options.language) searchQuery += ` language:${options.language}`;
    if (options.path) searchQuery += ` path:${options.path}`;

    const { data } = await octokit.search.code({
      q: searchQuery,
      per_page: options.perPage || 20,
    });

    return data.items.map(item => ({
      name: item.name,
      path: item.path,
      sha: item.sha,
      repository: item.repository.full_name,
      htmlUrl: item.html_url,
      textMatches: item.text_matches?.map(m => m.fragment).filter((f): f is string => f !== undefined),
    }));
  }

  /**
   * Get repository README
   */
  async getReadme(userId: string, owner: string, repo: string): Promise<string | null> {
    try {
      const octokit = await this.getOctokit(userId);
      const { data } = await octokit.repos.getReadme({ owner, repo });
      
      if ('content' in data && data.content) {
        return Buffer.from(data.content, 'base64').toString('utf-8');
      }
      return null;
    } catch {
      return null;
    }
  }

  // ==================== ISSUES & PRs ====================

  /**
   * Create an issue
   */
  async createIssue(
    userId: string,
    owner: string,
    repo: string,
    title: string,
    body?: string,
    labels?: string[]
  ): Promise<{ number: number; htmlUrl: string }> {
    const octokit = await this.getOctokit(userId);

    const { data } = await octokit.issues.create({
      owner,
      repo,
      title,
      body,
      labels,
    });

    return {
      number: data.number,
      htmlUrl: data.html_url,
    };
  }

  /**
   * Add comment to issue/PR
   */
  async addComment(
    userId: string,
    owner: string,
    repo: string,
    issueNumber: number,
    body: string
  ): Promise<{ id: number; htmlUrl: string }> {
    const octokit = await this.getOctokit(userId);

    const { data } = await octokit.issues.createComment({
      owner,
      repo,
      issue_number: issueNumber,
      body,
    });

    return {
      id: data.id,
      htmlUrl: data.html_url,
    };
  }

  // ==================== HELPERS ====================

  private mapConnection(row: any): GitHubConnection {
    return {
      id: row.id,
      userId: row.user_id,
      githubUserId: row.github_user_id,
      githubUsername: row.github_username,
      githubEmail: row.github_email,
      githubAvatarUrl: row.github_avatar_url,
      scopes: row.scopes || [],
      isActive: row.is_active,
      lastUsedAt: row.last_used_at,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    };
  }
}

export const githubService = new GitHubService();
export default githubService;
