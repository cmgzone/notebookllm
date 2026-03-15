/**
 * GitHub Source Service
 * Manages GitHub files as notebook sources with caching and freshness tracking
 * 
 * Requirements: 1.1, 1.2, 1.3, 1.4, 1.5
 */

import { v4 as uuidv4 } from 'uuid';
import pool from '../config/database.js';
import { githubService } from './githubService.js';
import crypto from 'crypto';
import { codeAnalysisService, CodeAnalysisResult } from './codeAnalysisService.js';
import { mcpUserSettingsService } from './mcpUserSettingsService.js';

// ==================== INTERFACES ====================

export interface GitHubSourceMetadata {
  type: 'github';
  owner: string;
  repo: string;
  path: string;
  branch: string;
  commitSha: string;
  language: string;
  size: number;
  lastFetchedAt: string;
  githubUrl: string;
  agentSessionId?: string;
  agentName?: string;
}

export interface CreateGitHubSourceParams {
  notebookId: string;
  owner: string;
  repo: string;
  path: string;
  branch?: string;
  userId: string;
  agentSessionId?: string;
  agentName?: string;
}

export interface CreateGitHubRepoSourcesParams {
  notebookId: string;
  owner: string;
  repo: string;
  branch?: string;
  userId: string;
  agentSessionId?: string;
  agentName?: string;
  maxFiles?: number;
  maxFileSizeBytes?: number;
  includeExtensions?: string[];
  excludeExtensions?: string[];
}

export interface RepoSourcesImportResult {
  addedCount: number;
  skippedCount: number;
  skippedByReason: Record<string, number>;
  totalFiles: number;
  candidateFiles: number;
  limited: boolean;
  maxFilesApplied: number;
  maxFileSizeBytesApplied: number;
  branch: string;
}

export interface GitHubSource {
  id: string;
  notebookId: string;
  userId: string;
  type: string;
  title: string;
  content: string;
  metadata: GitHubSourceMetadata;
  createdAt: Date;
  updatedAt: Date;
}

export interface SourceWithContent extends GitHubSource {
  hasUpdates: boolean;
  newSha?: string;
}

export interface UpdateCheckResult {
  hasUpdates: boolean;
  newSha?: string;
  currentSha: string;
}

// ==================== LANGUAGE DETECTION ====================

/**
 * Language extension mapping for syntax highlighting
 * Maps file extensions to language identifiers
 */
export const LANGUAGE_MAP: Record<string, string> = {
  // JavaScript/TypeScript
  'js': 'javascript',
  'jsx': 'javascript',
  'mjs': 'javascript',
  'cjs': 'javascript',
  'ts': 'typescript',
  'tsx': 'typescript',
  'mts': 'typescript',
  'cts': 'typescript',
  
  // Python
  'py': 'python',
  'pyw': 'python',
  'pyi': 'python',
  'pyx': 'python',
  
  // Mobile
  'dart': 'dart',
  'swift': 'swift',
  'kt': 'kotlin',
  'kts': 'kotlin',
  
  // JVM
  'java': 'java',
  'scala': 'scala',
  'groovy': 'groovy',
  'gradle': 'groovy',
  
  // Systems
  'go': 'go',
  'rs': 'rust',
  'c': 'c',
  'h': 'c',
  'cpp': 'cpp',
  'cc': 'cpp',
  'cxx': 'cpp',
  'hpp': 'cpp',
  'hxx': 'cpp',
  
  // .NET
  'cs': 'csharp',
  'fs': 'fsharp',
  'vb': 'vb',
  
  // Scripting
  'rb': 'ruby',
  'php': 'php',
  'pl': 'perl',
  'pm': 'perl',
  'lua': 'lua',
  'r': 'r',
  'R': 'r',
  
  // Shell
  'sh': 'bash',
  'bash': 'bash',
  'zsh': 'bash',
  'fish': 'bash',
  'ps1': 'powershell',
  'psm1': 'powershell',
  'bat': 'batch',
  'cmd': 'batch',
  
  // Web
  'html': 'html',
  'htm': 'html',
  'xhtml': 'html',
  'css': 'css',
  'scss': 'scss',
  'sass': 'sass',
  'less': 'less',
  
  // Data/Config
  'json': 'json',
  'jsonc': 'json',
  'json5': 'json',
  'yaml': 'yaml',
  'yml': 'yaml',
  'xml': 'xml',
  'toml': 'toml',
  'ini': 'ini',
  'cfg': 'ini',
  'conf': 'ini',
  'env': 'dotenv',
  
  // Database
  'sql': 'sql',
  'pgsql': 'sql',
  'mysql': 'sql',
  
  // Documentation
  'md': 'markdown',
  'markdown': 'markdown',
  'mdx': 'markdown',
  'rst': 'restructuredtext',
  'txt': 'text',
  
  // Other
  'dockerfile': 'dockerfile',
  'makefile': 'makefile',
  'cmake': 'cmake',
  'graphql': 'graphql',
  'gql': 'graphql',
  'proto': 'protobuf',
  'tf': 'terraform',
  'hcl': 'hcl',
  'vue': 'vue',
  'svelte': 'svelte',
};

/**
 * Detect language from file path
 * Handles edge cases: no extension, unknown extension, special filenames
 * 
 * @param filePath - The file path to analyze
 * @returns The detected language identifier
 */
export function detectLanguage(filePath: string): string {
  if (!filePath) return 'text';
  
  const fileName = filePath.split('/').pop() || filePath;
  const lowerFileName = fileName.toLowerCase();
  
  // Handle special filenames without extensions
  const specialFiles: Record<string, string> = {
    'dockerfile': 'dockerfile',
    'makefile': 'makefile',
    'gnumakefile': 'makefile',
    'cmakelists.txt': 'cmake',
    'gemfile': 'ruby',
    'rakefile': 'ruby',
    'vagrantfile': 'ruby',
    'podfile': 'ruby',
    'fastfile': 'ruby',
    'appfile': 'ruby',
    'brewfile': 'ruby',
    'guardfile': 'ruby',
    'procfile': 'yaml',
    '.gitignore': 'gitignore',
    '.gitattributes': 'gitattributes',
    '.editorconfig': 'ini',
    '.env': 'dotenv',
    '.env.local': 'dotenv',
    '.env.example': 'dotenv',
    '.prettierrc': 'json',
    '.eslintrc': 'json',
    '.babelrc': 'json',
    'package.json': 'json',
    'tsconfig.json': 'json',
    'composer.json': 'json',
    'cargo.toml': 'toml',
    'go.mod': 'go',
    'go.sum': 'text',
    'requirements.txt': 'text',
    'pipfile': 'toml',
    'pubspec.yaml': 'yaml',
    'build.gradle': 'groovy',
    'settings.gradle': 'groovy',
    'pom.xml': 'xml',
  };
  
  if (Object.prototype.hasOwnProperty.call(specialFiles, lowerFileName)) {
    return specialFiles[lowerFileName];
  }
  
  // Extract extension
  const lastDotIndex = fileName.lastIndexOf('.');
  if (lastDotIndex === -1 || lastDotIndex === 0) {
    // No extension or hidden file without extension
    return 'text';
  }
  
  const extension = fileName.substring(lastDotIndex + 1).toLowerCase();
  
  return Object.prototype.hasOwnProperty.call(LANGUAGE_MAP, extension) ? LANGUAGE_MAP[extension] : 'text';
}

// ==================== BULK IMPORT FILTERS ====================

const DEFAULT_MAX_FILES = 200;
const DEFAULT_MAX_FILE_SIZE_BYTES = 200 * 1024; // 200 KB
const HARD_MAX_FILES = 5000;
const HARD_MAX_FILE_SIZE_BYTES = 1_000_000; // GitHub content API limit is ~1MB

const BINARY_EXTENSIONS = new Set([
  'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp', 'ico',
  'pdf',
  'zip', 'rar', '7z', 'tar', 'gz', 'bz2', 'xz', 'tar.gz', 'tar.bz2', 'tar.xz', 'tgz', 'tbz2', 'txz',
  'mp3', 'wav', 'flac', 'ogg', 'm4a',
  'mp4', 'mov', 'avi', 'mkv', 'webm',
  'exe', 'dll', 'so', 'dylib',
  'jar', 'war', 'class', 'apk', 'ipa',
  'dmg', 'pkg', 'msi',
  'ttf', 'otf', 'woff', 'woff2', 'eot',
  'psd', 'ai',
]);

function normalizeExtensions(list?: string[]): Set<string> {
  if (!list || list.length === 0) return new Set<string>();
  return new Set(
    list
      .map((ext) => ext.trim().toLowerCase())
      .filter((ext) => ext.length > 0)
      .map((ext) => (ext.startsWith('.') ? ext.slice(1) : ext))
  );
}

function getFileExtension(path: string): string {
  const fileName = path.split('/').pop() || path;
  const lowerName = fileName.toLowerCase();

  if (lowerName.endsWith('.tar.gz')) return 'tar.gz';
  if (lowerName.endsWith('.tar.bz2')) return 'tar.bz2';
  if (lowerName.endsWith('.tar.xz')) return 'tar.xz';
  if (lowerName.endsWith('.tgz')) return 'tgz';
  if (lowerName.endsWith('.tbz2')) return 'tbz2';
  if (lowerName.endsWith('.txz')) return 'txz';

  const lastDotIndex = lowerName.lastIndexOf('.');
  if (lastDotIndex <= 0) return '';
  return lowerName.substring(lastDotIndex + 1);
}

function isRateLimitError(error: any): boolean {
  const status = error?.response?.status;
  if (status !== 403 && status !== 429) return false;
  const headers = error?.response?.headers || {};
  const remaining = parseInt(headers['x-ratelimit-remaining'] || '0', 10);
  return remaining === 0 || error?.message?.includes('rate limit');
}

// ==================== CACHE FRESHNESS ====================

/**
 * Cache freshness threshold in milliseconds (1 hour)
 */
export const CACHE_FRESHNESS_THRESHOLD_MS = 60 * 60 * 1000; // 1 hour

/**
 * Check if cached content is still fresh
 * 
 * @param lastFetchedAt - ISO timestamp of last fetch
 * @returns true if cache is fresh (less than 1 hour old)
 */
export function isCacheFresh(lastFetchedAt: string | Date): boolean {
  const fetchTime = typeof lastFetchedAt === 'string' 
    ? new Date(lastFetchedAt).getTime() 
    : lastFetchedAt.getTime();
  
  const now = Date.now();
  const age = now - fetchTime;
  
  return age < CACHE_FRESHNESS_THRESHOLD_MS;
}

/**
 * Generate content hash for change detection
 */
function generateContentHash(content: string): string {
  return crypto.createHash('sha256').update(content).digest('hex');
}

// ==================== SERVICE CLASS ====================

class GitHubSourceService {
  /**
   * Create a GitHub source in a notebook
   * Fetches file content and stores with full metadata
   * 
   * Requirements: 1.1, 1.2
   */
  async createSource(params: CreateGitHubSourceParams): Promise<GitHubSource> {
    const { notebookId, owner, repo, path, branch, userId, agentSessionId, agentName } = params;
    
    // Verify notebook exists and belongs to user
    const notebookResult = await pool.query(
      'SELECT id FROM notebooks WHERE id = $1 AND user_id = $2',
      [notebookId, userId]
    );
    
    if (notebookResult.rows.length === 0) {
      throw new Error('Notebook not found or access denied');
    }
    
    // Fetch file content from GitHub
    const file = await githubService.getFileContent(userId, owner, repo, path, branch);
    
    // Get the actual branch (default if not specified)
    const actualBranch = branch || 'main';
    
    // Detect language from file path
    const language = detectLanguage(path);
    
    // Build GitHub URL
    const githubUrl = `https://github.com/${owner}/${repo}/blob/${actualBranch}/${path}`;
    
    // Build metadata
    const metadata: GitHubSourceMetadata = {
      type: 'github',
      owner,
      repo,
      path,
      branch: actualBranch,
      commitSha: file.sha,
      language,
      size: file.size,
      lastFetchedAt: new Date().toISOString(),
      githubUrl,
      ...(agentSessionId && { agentSessionId }),
      ...(agentName && { agentName }),
    };
    
    // Create source
    const sourceId = uuidv4();
    const title = `${repo}/${path}`;
    const content = file.content || '';
    
    const result = await pool.query(
      `INSERT INTO sources (id, notebook_id, user_id, type, title, content, metadata, created_at, updated_at)
       VALUES ($1, $2, $3, 'github', $4, $5, $6, NOW(), NOW())
       RETURNING *`,
      [sourceId, notebookId, userId, title, content, JSON.stringify(metadata)]
    );
    
    // Create cache entry
    const contentHash = generateContentHash(content);
    await pool.query(
      `INSERT INTO github_source_cache (source_id, owner, repo, path, branch, commit_sha, content_hash, last_checked_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())
       ON CONFLICT (owner, repo, path, branch) 
       DO UPDATE SET source_id = $1, commit_sha = $6, content_hash = $7, last_checked_at = NOW()`,
      [sourceId, owner, repo, path, actualBranch, file.sha, contentHash]
    );
    
    // Update notebook's updated_at
    await pool.query(
      'UPDATE notebooks SET updated_at = NOW() WHERE id = $1',
      [notebookId]
    );
    
    // Perform code analysis asynchronously (don't block source creation)
    this.analyzeSourceAsync(sourceId, content, language, path, { owner, repo, branch: actualBranch }, userId);
    
    return this.mapSource(result.rows[0]);
  }

  /**
   * Create GitHub sources for an entire repository
   * Applies filtering, size limits, and duplicate detection
   */
  async createRepoSources(
    params: CreateGitHubRepoSourcesParams
  ): Promise<RepoSourcesImportResult> {
    const {
      notebookId,
      owner,
      repo,
      branch,
      userId,
      agentSessionId,
      agentName,
      maxFiles,
      maxFileSizeBytes,
      includeExtensions,
      excludeExtensions,
    } = params;

    // Verify notebook exists and belongs to user (once)
    const notebookResult = await pool.query(
      'SELECT id FROM notebooks WHERE id = $1 AND user_id = $2',
      [notebookId, userId]
    );

    if (notebookResult.rows.length === 0) {
      throw new Error('Notebook not found or access denied');
    }

    // Determine effective limits
    const requestedMaxFiles = typeof maxFiles === 'number' ? maxFiles : DEFAULT_MAX_FILES;
    const appliedMaxFiles =
      requestedMaxFiles <= 0 ? HARD_MAX_FILES : Math.min(requestedMaxFiles, HARD_MAX_FILES);

    const requestedMaxSize =
      typeof maxFileSizeBytes === 'number' ? maxFileSizeBytes : DEFAULT_MAX_FILE_SIZE_BYTES;
    const appliedMaxSize =
      requestedMaxSize <= 0
        ? HARD_MAX_FILE_SIZE_BYTES
        : Math.min(requestedMaxSize, HARD_MAX_FILE_SIZE_BYTES);

    // Build extension filters
    const includeSet = normalizeExtensions(includeExtensions);
    const excludeSet = normalizeExtensions(excludeExtensions);

    // Resolve branch (use default if not provided)
    const resolvedBranch =
      branch && branch.trim().length > 0
        ? branch
        : await githubService.getRepoDefaultBranch(userId, owner, repo);

    // Get existing GitHub sources for this repo/branch in this notebook to avoid duplicates
    const existingResult = await pool.query(
      `SELECT metadata->>'path' as path
       FROM sources
       WHERE notebook_id = $1
         AND type = 'github'
         AND metadata->>'owner' = $2
         AND metadata->>'repo' = $3
         AND COALESCE(metadata->>'branch', '') = $4`,
      [notebookId, owner, repo, resolvedBranch]
    );

    const existingPaths = new Set<string>(
      existingResult.rows.map((row) => row.path).filter((p) => typeof p === 'string')
    );

    // Fetch repo tree
    const tree = await githubService.getRepoTree(userId, owner, repo, resolvedBranch);
    const files = tree.filter((item) => item.type === 'blob' && item.path);

    const skippedByReason: Record<string, number> = {
      duplicate: 0,
      binary: 0,
      tooLarge: 0,
      filtered: 0,
      error: 0,
      limit: 0,
    };

    // Build candidate list after applying filters
    const candidates: string[] = [];
    for (const item of files) {
      const path = item.path;
      if (!path) continue;

      if (existingPaths.has(path)) {
        skippedByReason.duplicate += 1;
        continue;
      }

      const extension = getFileExtension(path);

      if (includeSet.size > 0 && !includeSet.has(extension)) {
        skippedByReason.filtered += 1;
        continue;
      }

      if (includeSet.size === 0 && excludeSet.size > 0 && excludeSet.has(extension)) {
        skippedByReason.filtered += 1;
        continue;
      }

      if (includeSet.size === 0 && excludeSet.size === 0 && BINARY_EXTENSIONS.has(extension)) {
        skippedByReason.binary += 1;
        continue;
      }

      if (item.size && appliedMaxSize > 0 && item.size > appliedMaxSize) {
        skippedByReason.tooLarge += 1;
        continue;
      }

      if (item.size && item.size > HARD_MAX_FILE_SIZE_BYTES) {
        skippedByReason.tooLarge += 1;
        continue;
      }

      candidates.push(path);
    }

    // Apply max files limit
    let limited = false;
    let importList = candidates;
    if (candidates.length > appliedMaxFiles) {
      limited = true;
      skippedByReason.limit = candidates.length - appliedMaxFiles;
      importList = candidates.slice(0, appliedMaxFiles);
    }

    // Import files sequentially to avoid rate limit spikes
    let addedCount = 0;
    for (const path of importList) {
      try {
        await this.createSource({
          notebookId,
          owner,
          repo,
          path,
          branch: resolvedBranch,
          userId,
          agentSessionId,
          agentName,
        });
        addedCount += 1;
        existingPaths.add(path);
      } catch (error) {
        if (isRateLimitError(error)) {
          throw error;
        }
        skippedByReason.error += 1;
      }
    }

    const skippedCount = Object.values(skippedByReason).reduce(
      (sum, value) => sum + value,
      0
    );

    return {
      addedCount,
      skippedCount,
      skippedByReason,
      totalFiles: files.length,
      candidateFiles: candidates.length,
      limited,
      maxFilesApplied: appliedMaxFiles,
      maxFileSizeBytesApplied: appliedMaxSize,
      branch: resolvedBranch,
    };
  }

  /**
   * Refresh a GitHub source with latest content from GitHub
   * 
   * Requirements: 1.3
   */
  async refreshSource(sourceId: string, userId: string): Promise<GitHubSource> {
    // Get existing source
    const sourceResult = await pool.query(
      `SELECT s.* FROM sources s
       INNER JOIN notebooks n ON s.notebook_id = n.id
       WHERE s.id = $1 AND n.user_id = $2 AND s.type = 'github'`,
      [sourceId, userId]
    );
    
    if (sourceResult.rows.length === 0) {
      throw new Error('GitHub source not found or access denied');
    }
    
    const source = sourceResult.rows[0];
    const metadata = source.metadata as GitHubSourceMetadata;
    
    // Fetch latest content from GitHub
    const file = await githubService.getFileContent(
      userId, 
      metadata.owner, 
      metadata.repo, 
      metadata.path, 
      metadata.branch
    );
    
    // Update metadata
    const updatedMetadata: GitHubSourceMetadata = {
      ...metadata,
      commitSha: file.sha,
      size: file.size,
      lastFetchedAt: new Date().toISOString(),
    };
    
    const content = file.content || '';
    
    // Update source
    const result = await pool.query(
      `UPDATE sources 
       SET content = $1, metadata = $2, updated_at = NOW()
       WHERE id = $3
       RETURNING *`,
      [content, JSON.stringify(updatedMetadata), sourceId]
    );
    
    // Update cache
    const contentHash = generateContentHash(content);
    await pool.query(
      `UPDATE github_source_cache 
       SET commit_sha = $1, content_hash = $2, last_checked_at = NOW(), last_modified_at = NOW()
       WHERE source_id = $3`,
      [file.sha, contentHash, sourceId]
    );
    
    return this.mapSource(result.rows[0]);
  }

  /**
   * Check if a GitHub source has updates (commit SHA differs)
   * 
   * Requirements: 1.4
   */
  async checkForUpdates(sourceId: string, userId: string): Promise<UpdateCheckResult> {
    // Get existing source
    const sourceResult = await pool.query(
      `SELECT s.* FROM sources s
       INNER JOIN notebooks n ON s.notebook_id = n.id
       WHERE s.id = $1 AND n.user_id = $2 AND s.type = 'github'`,
      [sourceId, userId]
    );
    
    if (sourceResult.rows.length === 0) {
      throw new Error('GitHub source not found or access denied');
    }
    
    const source = sourceResult.rows[0];
    const metadata = source.metadata as GitHubSourceMetadata;
    const currentSha = metadata.commitSha;
    
    // Fetch latest file info from GitHub (just metadata, not full content)
    const file = await githubService.getFileContent(
      userId, 
      metadata.owner, 
      metadata.repo, 
      metadata.path, 
      metadata.branch
    );
    
    const hasUpdates = file.sha !== currentSha;
    
    // Update last_checked_at in cache
    await pool.query(
      `UPDATE github_source_cache SET last_checked_at = NOW() WHERE source_id = $1`,
      [sourceId]
    );
    
    return {
      hasUpdates,
      currentSha,
      ...(hasUpdates && { newSha: file.sha }),
    };
  }

  /**
   * Get a source with content, optionally refreshing if stale
   * 
   * Requirements: 1.3
   */
  async getSourceWithContent(sourceId: string, userId: string): Promise<SourceWithContent> {
    // Get existing source
    const sourceResult = await pool.query(
      `SELECT s.* FROM sources s
       INNER JOIN notebooks n ON s.notebook_id = n.id
       WHERE s.id = $1 AND n.user_id = $2 AND s.type = 'github'`,
      [sourceId, userId]
    );
    
    if (sourceResult.rows.length === 0) {
      throw new Error('GitHub source not found or access denied');
    }
    
    const source = this.mapSource(sourceResult.rows[0]);
    const metadata = source.metadata;
    
    // Check if cache is fresh
    if (!isCacheFresh(metadata.lastFetchedAt)) {
      // Cache is stale, refresh from GitHub
      const refreshedSource = await this.refreshSource(sourceId, userId);
      
      // Check if content actually changed
      const hasUpdates = refreshedSource.metadata.commitSha !== metadata.commitSha;
      
      return {
        ...refreshedSource,
        hasUpdates,
        ...(hasUpdates && { newSha: refreshedSource.metadata.commitSha }),
      };
    }
    
    // Cache is fresh, return as-is
    return {
      ...source,
      hasUpdates: false,
    };
  }

  /**
   * Get all GitHub sources for a notebook
   */
  async getSourcesForNotebook(notebookId: string, userId: string): Promise<GitHubSource[]> {
    const result = await pool.query(
      `SELECT s.* FROM sources s
       INNER JOIN notebooks n ON s.notebook_id = n.id
       WHERE s.notebook_id = $1 AND n.user_id = $2 AND s.type = 'github'
       ORDER BY s.created_at DESC`,
      [notebookId, userId]
    );
    
    return result.rows.map(row => this.mapSource(row));
  }

  /**
   * Delete a GitHub source and its cache entry
   */
  async deleteSource(sourceId: string, userId: string): Promise<void> {
    // Verify ownership and delete
    const result = await pool.query(
      `DELETE FROM sources s
       USING notebooks n
       WHERE s.id = $1 AND s.notebook_id = n.id AND n.user_id = $2 AND s.type = 'github'
       RETURNING s.id`,
      [sourceId, userId]
    );
    
    if (result.rows.length === 0) {
      throw new Error('GitHub source not found or access denied');
    }
    
    // Cache entry will be deleted by CASCADE
  }

  /**
   * Analyze source code asynchronously and store results
   * This runs in the background to not block source creation
   */
  private async analyzeSourceAsync(
    sourceId: string,
    content: string,
    language: string,
    filePath: string,
    repoContext: { owner: string; repo: string; branch: string },
    userId?: string
  ): Promise<void> {
    try {
      // Skip analysis for non-code files or very large files
      const codeLanguages = [
        'javascript', 'typescript', 'python', 'dart', 'java', 'kotlin',
        'swift', 'go', 'rust', 'c', 'cpp', 'csharp', 'ruby', 'php',
        'scala', 'groovy', 'lua', 'r', 'bash', 'powershell'
      ];
      
      if (!codeLanguages.includes(language.toLowerCase())) {
        console.log(`⏭️ Skipping analysis for non-code file: ${filePath} (${language})`);
        return;
      }
      
      if (content.length > 100000) {
        console.log(`⏭️ Skipping analysis for large file: ${filePath} (${content.length} chars)`);
        return;
      }
      
      // Check if user has code analysis enabled and get their preferred model
      let modelId: string | undefined;
      if (userId) {
        const isEnabled = await mcpUserSettingsService.isCodeAnalysisEnabled(userId);
        if (!isEnabled) {
          console.log(`⏭️ Code analysis disabled for user: ${userId}`);
          return;
        }
        modelId = (await mcpUserSettingsService.getCodeAnalysisModelId(userId)) || undefined;
      }
      
      console.log(`🔍 Analyzing code: ${filePath}${modelId ? ` (model: ${modelId})` : ''}`);
      
      // Perform analysis
      const analysis = await codeAnalysisService.analyzeCode({
        code: content,
        language,
        filePath,
        repoContext,
        modelId,
        userId,
      });
      
      // Generate fact-check friendly summary
      const analysisSummary = await codeAnalysisService.generateFactCheckContext(analysis);
      
      // Store analysis results
      await pool.query(
        `UPDATE sources 
         SET code_analysis = $1, 
             analysis_summary = $2, 
             analysis_rating = $3, 
             analyzed_at = NOW(),
             updated_at = NOW()
         WHERE id = $4`,
        [
          JSON.stringify(analysis),
          analysisSummary,
          analysis.rating,
          sourceId
        ]
      );
      
      console.log(`✅ Analysis complete for ${filePath}: Rating ${analysis.rating}/10 (${analysis.analyzedBy})`);
    } catch (error) {
      console.error(`❌ Analysis failed for source ${sourceId}:`, error);
      // Don't throw - analysis failure shouldn't affect source creation
    }
  }

  /**
   * Get analysis for a source
   */
  async getSourceAnalysis(sourceId: string, userId: string): Promise<CodeAnalysisResult | null> {
    const result = await pool.query(
      `SELECT s.code_analysis FROM sources s
       INNER JOIN notebooks n ON s.notebook_id = n.id
       WHERE s.id = $1 AND n.user_id = $2`,
      [sourceId, userId]
    );
    
    if (result.rows.length === 0 || !result.rows[0].code_analysis) {
      return null;
    }
    
    return result.rows[0].code_analysis as CodeAnalysisResult;
  }

  /**
   * Re-analyze a source (useful after code updates)
   */
  async reanalyzeSource(sourceId: string, userId: string): Promise<CodeAnalysisResult | null> {
    const sourceResult = await pool.query(
      `SELECT s.* FROM sources s
       INNER JOIN notebooks n ON s.notebook_id = n.id
       WHERE s.id = $1 AND n.user_id = $2 AND s.type = 'github'`,
      [sourceId, userId]
    );
    
    if (sourceResult.rows.length === 0) {
      throw new Error('GitHub source not found or access denied');
    }
    
    const source = sourceResult.rows[0];
    const metadata = source.metadata as GitHubSourceMetadata;
    
    // Get user's preferred model
    let modelId: string | undefined;
    const isEnabled = await mcpUserSettingsService.isCodeAnalysisEnabled(userId);
    if (!isEnabled) {
      throw new Error('Code analysis is disabled in your settings');
    }
    modelId = (await mcpUserSettingsService.getCodeAnalysisModelId(userId)) || undefined;
    
    // Run analysis synchronously for re-analysis requests
    const analysis = await codeAnalysisService.analyzeCode({
      code: source.content,
      language: metadata.language,
      filePath: metadata.path,
      repoContext: {
        owner: metadata.owner,
        repo: metadata.repo,
        branch: metadata.branch,
      },
      modelId,
      userId,
    });
    
    const analysisSummary = await codeAnalysisService.generateFactCheckContext(analysis);
    
    await pool.query(
      `UPDATE sources 
       SET code_analysis = $1, 
           analysis_summary = $2, 
           analysis_rating = $3, 
           analyzed_at = NOW(),
           updated_at = NOW()
       WHERE id = $4`,
      [
        JSON.stringify(analysis),
        analysisSummary,
        analysis.rating,
        sourceId
      ]
    );
    
    return analysis;
  }

  /**
   * Map database row to GitHubSource interface
   */
  private mapSource(row: any): GitHubSource {
    return {
      id: row.id,
      notebookId: row.notebook_id,
      userId: row.user_id,
      type: row.type,
      title: row.title,
      content: row.content || '',
      metadata: typeof row.metadata === 'string' ? JSON.parse(row.metadata) : row.metadata,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    };
  }
}

export const githubSourceService = new GitHubSourceService();
export default githubSourceService;
