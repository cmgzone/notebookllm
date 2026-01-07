import pool from '../config/database.js';
import { generateWithGemini, generateWithOpenRouter, ChatMessage } from './aiService.js';
import { mcpUserSettingsService } from './mcpUserSettingsService.js';
import { GoogleGenerativeAI } from '@google/generative-ai';
import axios from 'axios';

// Initialize Gemini
const genAI = process.env.GEMINI_API_KEY
  ? new GoogleGenerativeAI(process.env.GEMINI_API_KEY)
  : null;

const openRouterApiKey = process.env.OPENROUTER_API_KEY || null;

export interface AIModel {
  id: string;
  name: string;
  model_id: string;
  provider: 'gemini' | 'openrouter';
  description: string;
  is_active: boolean;
  is_premium: boolean;
}

export interface CodeReviewIssue {
  id: string;
  severity: 'error' | 'warning' | 'info';
  category: 'security' | 'performance' | 'style' | 'logic' | 'best-practice';
  message: string;
  line?: number;
  column?: number;
  suggestion?: string;
  codeExample?: string;
}

export interface CodeReview {
  id: string;
  userId: string;
  code: string;
  language: string;
  reviewType: string;
  score: number;
  summary: string;
  issues: CodeReviewIssue[];
  suggestions: string[];
  context?: string;
  createdAt: Date;
}

export interface ReviewComparisonResult {
  originalScore: number;
  updatedScore: number;
  improvement: number;
  resolvedIssues: CodeReviewIssue[];
  newIssues: CodeReviewIssue[];
  summary: string;
}

class CodeReviewService {
  /**
   * Get a specific model by ID from the database
   */
  private async getModel(modelId: string): Promise<AIModel | null> {
    try {
      const result = await pool.query(
        `SELECT id, name, model_id, provider, description, is_active, is_premium 
         FROM ai_models 
         WHERE model_id = $1 AND is_active = true`,
        [modelId]
      );
      return result.rows[0] || null;
    } catch (error) {
      console.error('Error fetching model:', error);
      return null;
    }
  }

  /**
   * Get the default model for code review (first active model, prefer Gemini)
   */
  private async getDefaultModel(): Promise<AIModel | null> {
    try {
      const result = await pool.query(
        `SELECT id, name, model_id, provider, description, is_active, is_premium 
         FROM ai_models 
         WHERE is_active = true 
         ORDER BY 
           CASE WHEN provider = 'gemini' THEN 0 ELSE 1 END,
           name
         LIMIT 1`
      );
      return result.rows[0] || null;
    } catch (error) {
      console.error('Error fetching default model:', error);
      return null;
    }
  }

  /**
   * Generate content using the specified model or fallback
   */
  private async generateWithModel(
    prompt: string,
    modelId?: string
  ): Promise<{ text: string; provider: 'gemini' | 'openrouter'; modelName?: string }> {
    // If a specific model is requested, try to use it
    if (modelId) {
      const model = await this.getModel(modelId);
      if (model) {
        try {
          if (model.provider === 'gemini' && genAI) {
            const genModel = genAI.getGenerativeModel({ model: model.model_id });
            const result = await genModel.generateContent(prompt);
            return { text: result.response.text(), provider: 'gemini', modelName: model.name };
          } else if (model.provider === 'openrouter' && openRouterApiKey) {
            const response = await axios.post(
              'https://openrouter.ai/api/v1/chat/completions',
              {
                model: model.model_id,
                messages: [{ role: 'user', content: prompt }],
                max_tokens: 4096,
              },
              {
                timeout: 120000,
                headers: {
                  'Authorization': `Bearer ${openRouterApiKey}`,
                  'Content-Type': 'application/json',
                  'HTTP-Referer': 'https://notebookllm.app',
                  'X-Title': 'Notebook LLM Code Review'
                }
              }
            );
            return { text: response.data.choices[0].message.content, provider: 'openrouter', modelName: model.name };
          }
        } catch (error: any) {
          console.log(`[Code Review] Selected model ${model.name} failed, falling back:`, error.message);
        }
      }
    }

    // Try Gemini first (default fallback)
    if (genAI) {
      try {
        const messages: ChatMessage[] = [{ role: 'user', content: prompt }];
        const text = await generateWithGemini(messages, 'gemini-2.0-flash');
        return { text, provider: 'gemini', modelName: 'Gemini 2.0 Flash' };
      } catch (error: any) {
        console.log('[Code Review] Gemini failed, trying OpenRouter:', error.message);
      }
    }

    // Fallback to OpenRouter
    if (openRouterApiKey) {
      try {
        const messages: ChatMessage[] = [{ role: 'user', content: prompt }];
        const text = await generateWithOpenRouter(messages, 'meta-llama/llama-3.3-70b-instruct', 4096);
        return { text, provider: 'openrouter', modelName: 'Llama 3.3 70B' };
      } catch (error: any) {
        console.log('[Code Review] OpenRouter also failed:', error.message);
        throw error;
      }
    }

    throw new Error('No AI provider available for code review');
  }

  async reviewCode(
    userId: string,
    code: string,
    language: string,
    reviewType: string = 'comprehensive',
    context?: string,
    saveReview: boolean = true
  ): Promise<CodeReview> {
    // Get user's preferred AI model for code analysis
    let modelId: string | null = null;
    try {
      modelId = await mcpUserSettingsService.getCodeAnalysisModelId(userId);
      if (modelId) {
        console.log(`[Code Review] Using user's preferred model: ${modelId}`);
      }
    } catch (error) {
      console.log('[Code Review] Could not get user model preference, using default');
    }

    // Generate AI review with user's preferred model
    const reviewResult = await this.generateAIReview(code, language, reviewType, context, modelId || undefined);
    
    if (saveReview) {
      // Save to database
      const result = await pool.query(
        `INSERT INTO code_reviews (user_id, code, language, review_type, score, summary, issues, suggestions, context)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
         RETURNING *`,
        [userId, code, language, reviewType, reviewResult.score, reviewResult.summary, 
         JSON.stringify(reviewResult.issues), JSON.stringify(reviewResult.suggestions), context]
      );
      
      return this.mapRowToReview(result.rows[0]);
    }
    
    return {
      id: 'temp-' + Date.now(),
      userId,
      code,
      language,
      reviewType,
      ...reviewResult,
      createdAt: new Date(),
    };
  }

  private async generateAIReview(
    code: string,
    language: string,
    reviewType: string,
    context?: string,
    modelId?: string
  ): Promise<{ score: number; summary: string; issues: CodeReviewIssue[]; suggestions: string[]; modelUsed?: string }> {
    const focusAreas = {
      comprehensive: 'security, performance, readability, best practices, and potential bugs',
      security: 'security vulnerabilities, injection risks, authentication issues, and data exposure',
      performance: 'performance bottlenecks, memory leaks, inefficient algorithms, and optimization opportunities',
      readability: 'code clarity, naming conventions, documentation, and maintainability',
    };

    const prompt = `You are an expert code reviewer. Analyze the following ${language} code and provide a detailed review.

Focus on: ${focusAreas[reviewType as keyof typeof focusAreas] || focusAreas.comprehensive}
${context ? `Context: ${context}` : ''}

Code to review:
\`\`\`${language}
${code}
\`\`\`

Respond with a JSON object in this exact format:
{
  "score": <number 0-100>,
  "summary": "<brief overview of code quality>",
  "issues": [
    {
      "id": "<unique-id>",
      "severity": "error|warning|info",
      "category": "security|performance|style|logic|best-practice",
      "message": "<description of the issue>",
      "line": <line number if applicable>,
      "suggestion": "<how to fix>",
      "codeExample": "<corrected code snippet if applicable>"
    }
  ],
  "suggestions": ["<general improvement suggestion>"]
}

Be thorough but fair. Score guidelines:
- 90-100: Excellent, production-ready code
- 70-89: Good code with minor issues
- 50-69: Acceptable but needs improvement
- 30-49: Significant issues need addressing
- 0-29: Major problems, needs rewrite`;

    try {
      const { text: response, provider, modelName } = await this.generateWithModel(prompt, modelId);
      console.log(`[Code Review] Generated review using ${modelName || provider}`);

      // Parse JSON from response
      const jsonMatch = response.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        const parsed = JSON.parse(jsonMatch[0]);
        return {
          score: Math.min(100, Math.max(0, parsed.score || 50)),
          summary: parsed.summary || 'Review completed',
          issues: (parsed.issues || []).map((issue: any, idx: number) => ({
            id: issue.id || `issue-${idx}`,
            severity: issue.severity || 'info',
            category: issue.category || 'best-practice',
            message: issue.message || '',
            line: issue.line,
            column: issue.column,
            suggestion: issue.suggestion,
            codeExample: issue.codeExample,
          })),
          suggestions: parsed.suggestions || [],
          modelUsed: modelName || provider,
        };
      }
    } catch (error) {
      console.error('AI review generation failed:', error);
    }

    // Fallback response
    return {
      score: 50,
      summary: 'Unable to generate detailed review. Please try again.',
      issues: [],
      suggestions: ['Consider running the review again for detailed analysis'],
    };
  }

  async getReviewHistory(
    userId: string,
    options: { language?: string; limit?: number; minScore?: number; maxScore?: number }
  ): Promise<CodeReview[]> {
    let query = `SELECT * FROM code_reviews WHERE user_id = $1`;
    const params: any[] = [userId];
    let paramIndex = 2;

    if (options.language) {
      query += ` AND language = $${paramIndex++}`;
      params.push(options.language);
    }
    if (options.minScore !== undefined) {
      query += ` AND score >= $${paramIndex++}`;
      params.push(options.minScore);
    }
    if (options.maxScore !== undefined) {
      query += ` AND score <= $${paramIndex++}`;
      params.push(options.maxScore);
    }

    query += ` ORDER BY created_at DESC LIMIT $${paramIndex}`;
    params.push(options.limit || 20);

    const result = await pool.query(query, params);
    return result.rows.map(this.mapRowToReview);
  }

  async getReviewById(reviewId: string, userId: string): Promise<CodeReview | null> {
    const result = await pool.query(
      `SELECT * FROM code_reviews WHERE id = $1 AND user_id = $2`,
      [reviewId, userId]
    );
    return result.rows[0] ? this.mapRowToReview(result.rows[0]) : null;
  }

  async compareCodeVersions(
    userId: string,
    originalCode: string,
    updatedCode: string,
    language: string,
    context?: string
  ): Promise<ReviewComparisonResult> {
    // Review both versions
    const [originalReview, updatedReview] = await Promise.all([
      this.reviewCode(userId, originalCode, language, 'comprehensive', context, false),
      this.reviewCode(userId, updatedCode, language, 'comprehensive', context, false),
    ]);

    // Find resolved and new issues
    const originalIssueMessages = new Set(originalReview.issues.map(i => i.message));
    const updatedIssueMessages = new Set(updatedReview.issues.map(i => i.message));

    const resolvedIssues = originalReview.issues.filter(i => !updatedIssueMessages.has(i.message));
    const newIssues = updatedReview.issues.filter(i => !originalIssueMessages.has(i.message));

    const improvement = updatedReview.score - originalReview.score;

    // Generate comparison summary
    let summary = '';
    if (improvement > 0) {
      summary = `Code quality improved by ${improvement} points. ${resolvedIssues.length} issues were resolved.`;
    } else if (improvement < 0) {
      summary = `Code quality decreased by ${Math.abs(improvement)} points. ${newIssues.length} new issues were introduced.`;
    } else {
      summary = `Code quality remained the same. ${resolvedIssues.length} issues resolved, ${newIssues.length} new issues.`;
    }

    // Save comparison
    await pool.query(
      `INSERT INTO code_review_comparisons 
       (user_id, original_code, updated_code, language, original_score, updated_score, improvement, resolved_issues, new_issues, summary)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
      [userId, originalCode, updatedCode, language, originalReview.score, updatedReview.score, 
       improvement, JSON.stringify(resolvedIssues), JSON.stringify(newIssues), summary]
    );

    return {
      originalScore: originalReview.score,
      updatedScore: updatedReview.score,
      improvement,
      resolvedIssues,
      newIssues,
      summary,
    };
  }

  private mapRowToReview(row: any): CodeReview {
    return {
      id: row.id,
      userId: row.user_id,
      code: row.code,
      language: row.language,
      reviewType: row.review_type,
      score: row.score,
      summary: row.summary,
      issues: typeof row.issues === 'string' ? JSON.parse(row.issues) : row.issues,
      suggestions: typeof row.suggestions === 'string' ? JSON.parse(row.suggestions) : row.suggestions,
      context: row.context,
      createdAt: row.created_at,
    };
  }
}

export const codeReviewService = new CodeReviewService();
