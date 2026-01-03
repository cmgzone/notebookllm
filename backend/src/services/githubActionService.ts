/**
 * GitHub Action Service
 * 
 * Handles GitHub actions from chat suggestions including issue creation,
 * parsing AI suggestions, and generating code diffs.
 * 
 * Implements Requirements 6.4 from the GitHub-MCP Integration spec.
 * 
 * Feature: github-mcp-integration
 */

import githubService from './githubService.js';
import auditLoggerService from './auditLoggerService.js';

/**
 * Parameters for creating a GitHub issue
 */
export interface CreateIssueParams {
  userId: string;
  owner: string;
  repo: string;
  title: string;
  body: string;
  labels?: string[];
  sourceId?: string;
  agentSessionId?: string;
}

/**
 * Result of creating a GitHub issue
 */
export interface CreatedIssue {
  number: number;
  htmlUrl: string;
  title: string;
  body: string;
  labels: string[];
  owner: string;
  repo: string;
  createdAt: Date;
}

/**
 * Issue suggestion extracted from AI response
 */
export interface IssueSuggestion {
  title: string;
  body: string;
  labels?: string[];
}

/**
 * Code suggestion extracted from AI response
 */
export interface CodeSuggestion {
  original?: string;
  suggested: string;
  description: string;
  lineRange?: { start: number; end: number };
  language?: string;
}

/**
 * Diff line representation
 */
interface DiffLine {
  type: 'add' | 'remove' | 'context';
  content: string;
  oldLineNumber?: number;
  newLineNumber?: number;
}

/**
 * Diff hunk representation
 */
interface DiffHunk {
  oldStart: number;
  oldCount: number;
  newStart: number;
  newCount: number;
  lines: DiffLine[];
}

/**
 * GitHub Action Service
 * 
 * Provides methods to create issues, parse AI suggestions, and generate diffs.
 */
class GitHubActionService {
  /**
   * Create a GitHub issue with audit logging
   * 
   * @param params - Issue creation parameters
   * @returns The created issue details
   */
  async createIssue(params: CreateIssueParams): Promise<CreatedIssue> {
    const { userId, owner, repo, title, body, labels = [], sourceId, agentSessionId } = params;

    try {
      // Create the issue via GitHub API
      const result = await githubService.createIssue(userId, owner, repo, title, body, labels);

      // Log successful creation
      await auditLoggerService.log({
        userId,
        action: 'create_issue',
        owner,
        repo,
        agentSessionId,
        success: true,
        requestMetadata: {
          issueNumber: result.number,
          title,
          labels,
          sourceId,
        },
      });

      return {
        number: result.number,
        htmlUrl: result.htmlUrl,
        title,
        body,
        labels,
        owner,
        repo,
        createdAt: new Date(),
      };
    } catch (error) {
      // Log failed creation
      const errorMessage = error instanceof Error ? error.message : 'Unknown error';
      
      await auditLoggerService.log({
        userId,
        action: 'create_issue',
        owner,
        repo,
        agentSessionId,
        success: false,
        errorMessage,
        requestMetadata: {
          title,
          labels,
          sourceId,
        },
      });

      throw error;
    }
  }

  /**
   * Parse an AI response to extract issue suggestion
   * 
   * Looks for common patterns in AI responses that suggest creating an issue:
   * - Markdown headers with "Issue:" or "Bug:" prefixes
   * - Structured suggestions with title and description
   * - Code blocks with issue templates
   * 
   * @param aiResponse - The AI response text to parse
   * @returns Extracted issue suggestion or null if none found
   */
  parseIssueSuggestion(aiResponse: string): IssueSuggestion | null {
    if (!aiResponse || typeof aiResponse !== 'string') {
      return null;
    }

    // Pattern 1: Explicit issue suggestion format
    // "**Issue Title:** <title>\n**Description:** <body>"
    const explicitPattern = /\*\*(?:Issue\s*Title|Title)\s*:\*\*\s*(.+?)(?:\n|\r\n)(?:\*\*(?:Description|Body)\s*:\*\*\s*)([\s\S]+?)(?=\n\*\*|$)/i;
    const explicitMatch = aiResponse.match(explicitPattern);
    if (explicitMatch) {
      return {
        title: explicitMatch[1].trim(),
        body: explicitMatch[2].trim(),
        labels: this.extractLabels(aiResponse),
      };
    }

    // Pattern 2: Markdown header format
    // "## Issue: <title>\n<body>"
    const headerPattern = /##\s*(?:Issue|Bug|Feature|Enhancement)\s*:\s*(.+?)(?:\n|\r\n)([\s\S]+?)(?=\n##|$)/i;
    const headerMatch = aiResponse.match(headerPattern);
    if (headerMatch) {
      return {
        title: headerMatch[1].trim(),
        body: headerMatch[2].trim(),
        labels: this.extractLabels(aiResponse),
      };
    }

    // Pattern 3: "Create an issue" suggestion format
    // "I suggest creating an issue titled '<title>' with the following description: <body>"
    const suggestPattern = /(?:create|open|file)\s+(?:an?\s+)?issue\s+(?:titled|called|named)\s+['""](.+?)['""][\s\S]*?(?:description|body|content)\s*:\s*([\s\S]+?)(?=\n\n|$)/i;
    const suggestMatch = aiResponse.match(suggestPattern);
    if (suggestMatch) {
      return {
        title: suggestMatch[1].trim(),
        body: suggestMatch[2].trim(),
        labels: this.extractLabels(aiResponse),
      };
    }

    // Pattern 4: Code block with issue template
    // ```issue\ntitle: <title>\nbody: <body>\n```
    const codeBlockPattern = /```(?:issue|github-issue)?\s*\n(?:title\s*:\s*(.+?)\n)?(?:body\s*:\s*)?([\s\S]+?)```/i;
    const codeBlockMatch = aiResponse.match(codeBlockPattern);
    if (codeBlockMatch && codeBlockMatch[1]) {
      return {
        title: codeBlockMatch[1].trim(),
        body: codeBlockMatch[2]?.trim() || '',
        labels: this.extractLabels(aiResponse),
      };
    }

    // Pattern 5: Simple "Issue:" prefix
    // "Issue: <title>\n<body>"
    const simplePattern = /^Issue\s*:\s*(.+?)(?:\n|\r\n)([\s\S]+)/im;
    const simpleMatch = aiResponse.match(simplePattern);
    if (simpleMatch) {
      return {
        title: simpleMatch[1].trim(),
        body: simpleMatch[2].trim(),
        labels: this.extractLabels(aiResponse),
      };
    }

    return null;
  }

  /**
   * Parse an AI response to extract code suggestion
   * 
   * Looks for code blocks with suggested changes and descriptions.
   * 
   * @param aiResponse - The AI response text to parse
   * @returns Extracted code suggestion or null if none found
   */
  parseCodeSuggestion(aiResponse: string): CodeSuggestion | null {
    if (!aiResponse || typeof aiResponse !== 'string') {
      return null;
    }

    // Pattern 1: Explicit before/after format
    // "**Before:**\n```\n<original>\n```\n**After:**\n```\n<suggested>\n```"
    const beforeAfterPattern = /\*\*(?:Before|Original|Current)\s*:\*\*\s*```(\w*)\n([\s\S]*?)```[\s\S]*?\*\*(?:After|Suggested|New|Fixed)\s*:\*\*\s*```\w*\n([\s\S]*?)```/i;
    const beforeAfterMatch = aiResponse.match(beforeAfterPattern);
    if (beforeAfterMatch) {
      return {
        original: beforeAfterMatch[2].trim(),
        suggested: beforeAfterMatch[3].trim(),
        description: this.extractDescription(aiResponse),
        language: beforeAfterMatch[1] || undefined,
      };
    }

    // Pattern 2: "Replace X with Y" format
    const replacePattern = /(?:replace|change|update)\s+(?:this|the following)?\s*:?\s*```(\w*)\n([\s\S]*?)```\s*(?:with|to)\s*:?\s*```\w*\n([\s\S]*?)```/i;
    const replaceMatch = aiResponse.match(replacePattern);
    if (replaceMatch) {
      return {
        original: replaceMatch[2].trim(),
        suggested: replaceMatch[3].trim(),
        description: this.extractDescription(aiResponse),
        language: replaceMatch[1] || undefined,
      };
    }

    // Pattern 3: Single code block with description (suggested code only)
    const singleBlockPattern = /(?:(?:here'?s?|try|use|suggested?)\s+(?:the\s+)?(?:fix|solution|code|change|update)\s*:?\s*)?```(\w*)\n([\s\S]*?)```/i;
    const singleBlockMatch = aiResponse.match(singleBlockPattern);
    if (singleBlockMatch && singleBlockMatch[2].trim().length > 0) {
      // Check if there's a line range mentioned
      const lineRange = this.extractLineRange(aiResponse);
      
      return {
        suggested: singleBlockMatch[2].trim(),
        description: this.extractDescription(aiResponse),
        language: singleBlockMatch[1] || undefined,
        lineRange,
      };
    }

    return null;
  }

  /**
   * Generate a unified diff between original and suggested code
   * 
   * @param original - The original code
   * @param suggested - The suggested code
   * @returns Unified diff string
   */
  generateDiff(original: string, suggested: string): string {
    if (!original && !suggested) {
      return '';
    }

    if (!original) {
      // All additions
      const lines = suggested.split('\n');
      return lines.map(line => `+${line}`).join('\n');
    }

    if (!suggested) {
      // All deletions
      const lines = original.split('\n');
      return lines.map(line => `-${line}`).join('\n');
    }

    const originalLines = original.split('\n');
    const suggestedLines = suggested.split('\n');

    // Compute LCS-based diff
    const hunks = this.computeDiffHunks(originalLines, suggestedLines);
    
    return this.formatUnifiedDiff(hunks);
  }

  /**
   * Extract labels from AI response
   */
  private extractLabels(text: string): string[] {
    const labels: string[] = [];

    // Look for explicit labels
    const labelsPattern = /\*\*(?:Labels?)\s*:\*\*\s*(.+?)(?:\n|$)/i;
    const labelsMatch = text.match(labelsPattern);
    if (labelsMatch) {
      const labelText = labelsMatch[1];
      // Split by comma or space
      const extracted = labelText.split(/[,\s]+/).filter(l => l.trim().length > 0);
      labels.push(...extracted.map(l => l.trim().replace(/^['"`]|['"`]$/g, '')));
    }

    // Look for common label keywords in the text
    const commonLabels = ['bug', 'feature', 'enhancement', 'documentation', 'help wanted', 'good first issue'];
    for (const label of commonLabels) {
      if (text.toLowerCase().includes(label) && !labels.includes(label)) {
        // Only add if it seems intentional (near "label" keyword or in a list)
        const labelContext = new RegExp(`(?:label|tag|type)\\s*:?\\s*.*?${label}`, 'i');
        if (labelContext.test(text)) {
          labels.push(label);
        }
      }
    }

    return labels;
  }

  /**
   * Extract description from AI response
   */
  private extractDescription(text: string): string {
    // Look for explicit description
    const descPattern = /\*\*(?:Description|Explanation|Summary)\s*:\*\*\s*([\s\S]+?)(?=\n\*\*|```|$)/i;
    const descMatch = text.match(descPattern);
    if (descMatch) {
      return descMatch[1].trim();
    }

    // Look for text before code blocks
    const beforeCodePattern = /^([\s\S]+?)(?=```)/;
    const beforeMatch = text.match(beforeCodePattern);
    if (beforeMatch) {
      const desc = beforeMatch[1].trim();
      // Clean up and limit length
      if (desc.length > 10 && desc.length < 500) {
        return desc;
      }
    }

    return 'Code suggestion';
  }

  /**
   * Extract line range from AI response
   */
  private extractLineRange(text: string): { start: number; end: number } | undefined {
    // Look for line number references
    const linePattern = /(?:line|lines?)\s*(\d+)(?:\s*[-–to]+\s*(\d+))?/i;
    const lineMatch = text.match(linePattern);
    if (lineMatch) {
      const start = parseInt(lineMatch[1], 10);
      const end = lineMatch[2] ? parseInt(lineMatch[2], 10) : start;
      return { start, end };
    }

    return undefined;
  }

  /**
   * Compute diff hunks using LCS algorithm
   */
  private computeDiffHunks(originalLines: string[], suggestedLines: string[]): DiffHunk[] {
    // Compute LCS matrix
    const m = originalLines.length;
    const n = suggestedLines.length;
    const dp: number[][] = Array(m + 1).fill(null).map(() => Array(n + 1).fill(0));

    for (let i = 1; i <= m; i++) {
      for (let j = 1; j <= n; j++) {
        if (originalLines[i - 1] === suggestedLines[j - 1]) {
          dp[i][j] = dp[i - 1][j - 1] + 1;
        } else {
          dp[i][j] = Math.max(dp[i - 1][j], dp[i][j - 1]);
        }
      }
    }

    // Backtrack to find diff
    const diffLines: DiffLine[] = [];
    let i = m;
    let j = n;
    let oldLine = m;
    let newLine = n;

    while (i > 0 || j > 0) {
      if (i > 0 && j > 0 && originalLines[i - 1] === suggestedLines[j - 1]) {
        diffLines.unshift({
          type: 'context',
          content: originalLines[i - 1],
          oldLineNumber: oldLine,
          newLineNumber: newLine,
        });
        i--;
        j--;
        oldLine--;
        newLine--;
      } else if (j > 0 && (i === 0 || dp[i][j - 1] >= dp[i - 1][j])) {
        diffLines.unshift({
          type: 'add',
          content: suggestedLines[j - 1],
          newLineNumber: newLine,
        });
        j--;
        newLine--;
      } else if (i > 0) {
        diffLines.unshift({
          type: 'remove',
          content: originalLines[i - 1],
          oldLineNumber: oldLine,
        });
        i--;
        oldLine--;
      }
    }

    // Group into hunks
    return this.groupIntoHunks(diffLines);
  }

  /**
   * Group diff lines into hunks with context
   */
  private groupIntoHunks(diffLines: DiffLine[]): DiffHunk[] {
    const hunks: DiffHunk[] = [];
    const contextLines = 3;
    let currentHunk: DiffHunk | null = null;
    let lastChangeIndex = -contextLines - 1;

    for (let i = 0; i < diffLines.length; i++) {
      const line = diffLines[i];
      const isChange = line.type !== 'context';

      if (isChange) {
        if (!currentHunk || i - lastChangeIndex > contextLines * 2) {
          // Start new hunk
          if (currentHunk) {
            hunks.push(currentHunk);
          }
          
          // Include context before
          const startIndex = Math.max(0, i - contextLines);
          const contextBefore = diffLines.slice(startIndex, i);
          
          currentHunk = {
            oldStart: contextBefore.length > 0 ? (contextBefore[0].oldLineNumber || 1) : (line.oldLineNumber || 1),
            oldCount: 0,
            newStart: contextBefore.length > 0 ? (contextBefore[0].newLineNumber || 1) : (line.newLineNumber || 1),
            newCount: 0,
            lines: [...contextBefore],
          };
          
          // Update counts for context
          for (const ctx of contextBefore) {
            currentHunk.oldCount++;
            currentHunk.newCount++;
          }
        }
        
        lastChangeIndex = i;
      }

      if (currentHunk) {
        if (!currentHunk.lines.includes(line)) {
          currentHunk.lines.push(line);
        }
        
        if (line.type === 'remove' || line.type === 'context') {
          currentHunk.oldCount++;
        }
        if (line.type === 'add' || line.type === 'context') {
          currentHunk.newCount++;
        }
      }
    }

    if (currentHunk && currentHunk.lines.length > 0) {
      hunks.push(currentHunk);
    }

    return hunks;
  }

  /**
   * Format hunks as unified diff string
   */
  private formatUnifiedDiff(hunks: DiffHunk[]): string {
    if (hunks.length === 0) {
      return '';
    }

    const lines: string[] = [];

    for (const hunk of hunks) {
      // Hunk header
      lines.push(`@@ -${hunk.oldStart},${hunk.oldCount} +${hunk.newStart},${hunk.newCount} @@`);
      
      for (const line of hunk.lines) {
        switch (line.type) {
          case 'add':
            lines.push(`+${line.content}`);
            break;
          case 'remove':
            lines.push(`-${line.content}`);
            break;
          case 'context':
            lines.push(` ${line.content}`);
            break;
        }
      }
    }

    return lines.join('\n');
  }
}

export const githubActionService = new GitHubActionService();
export default githubActionService;
