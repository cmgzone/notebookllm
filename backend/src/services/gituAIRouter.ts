/**
 * Gitu AI Router Service
 * Routes AI requests to appropriate models based on user preferences, task requirements, and cost optimization.
 * 
 * Requirements: US-0.1 (API Key Management), US-0.2 (AI Model Selection), TR-6 (AI Model Support)
 * Design: Section 4 (AI Router)
 */

import pool from '../config/database.js';
import { generateWithGemini, generateWithOpenRouter, generateEmbedding } from './aiService.js';
import { gituSystemPromptBuilder } from './gituSystemPromptBuilder.js';

// ==================== INTERFACES ====================

/**
 * Task types that determine model selection
 */
export type TaskType = 'chat' | 'research' | 'coding' | 'analysis' | 'summarization' | 'creative';

/**
 * AI model information
 */
export interface AIModel {
  provider: 'openrouter' | 'gemini' | 'openai' | 'anthropic';
  modelId: string;
  contextWindow: number;
  costPer1kTokens: number;
}

/**
 * User's model preferences from NotebookLLM app settings
 */
export interface ModelPreferences {
  defaultModel: string;  // From NotebookLLM app settings
  taskSpecificModels: Record<TaskType, string>;
  apiKeySource: 'platform' | 'personal';
  personalKeys?: {
    openrouter?: string;
    gemini?: string;
    openai?: string;
    anthropic?: string;
  };
}

/**
 * AI request parameters
 */
export interface AIRequest {
  userId: string;
  sessionId?: string; // Optional, can be inferred or created
  prompt?: string;    // Optional if content is provided
  content?: string;   // Alternative to prompt
  context?: string[]; // Optional, defaults to empty array
  taskType?: TaskType; // Optional, defaults to chat
  maxTokens?: number;
  temperature?: number;
  preferredModel?: string;
  platform?: string;       // Source platform (whatsapp, telegram, etc)
  platformUserId?: string; // User ID on source platform
  metadata?: Record<string, any>; // Extra metadata
  useRetrieval?: boolean; // Enable RAG context injection
  includeSystemPrompt?: boolean; // Include Gitu identity/context (default: true)
  includeTools?: boolean; // Include tool definitions (default: true for chat)
}

/**
 * AI response with metadata
 */
export interface AIResponse {
  content: string;
  model: string;
  tokensUsed: number;
  cost: number;
  finishReason: 'stop' | 'length' | 'error';
}

/**
 * Cost estimate for a request
 */
export interface CostEstimate {
  estimatedTokens: number;
  estimatedCostUSD: number;
  confidence: number;  // 0-1
  alternatives: { model: string; estimatedCost: number }[];
}

// ==================== MODEL DEFINITIONS ====================

/**
 * Database model interface (from ai_models table)
 */
interface DBModel {
  id: string;
  name: string;
  model_id: string;
  provider: string;
  context_window: number;
  cost_input: number | string | null;
  cost_output: number | string | null;
  is_active: boolean;
}

/**
 * Cache for loaded models (refreshed periodically)
 */
let modelsCache: Record<string, AIModel> = {};
let modelsCacheTimestamp: number = 0;
const MODELS_CACHE_TTL = 5 * 60 * 1000; // 5 minutes

/**
 * Default model recommendations by task type.
 * These are preferred model patterns - actual model will be selected from available database models.
 * Format: provider preference, then any available model.
 */
const DEFAULT_TASK_PROVIDER_HINTS: Record<TaskType, string[]> = {
  chat: ['gemini', 'openrouter'],           // Fast models preferred
  research: ['gemini', 'openrouter'],       // Large context preferred
  coding: ['anthropic', 'openrouter', 'gemini'],  // Claude preferred for code
  analysis: ['gemini', 'openrouter'],       // Large context preferred
  summarization: ['gemini', 'openrouter'],  // Fast models preferred
  creative: ['anthropic', 'openrouter', 'gemini'], // Creative models preferred
};

/**
 * Map database provider names to AIModel provider types
 */
function mapProviderName(dbProvider: string): 'openrouter' | 'gemini' | 'openai' | 'anthropic' {
  const normalized = dbProvider.toLowerCase();
  if (normalized === 'google' || normalized === 'gemini') return 'gemini';
  if (normalized === 'openrouter') return 'openrouter';
  if (normalized === 'openai') return 'openai';
  if (normalized === 'anthropic') return 'anthropic';
  // Default to openrouter for unknown providers
  return 'openrouter';
}

// ==================== SERVICE CLASS ====================

class GituAIRouter {
  private readonly verboseLogs =
    process.env.GITU_LOG_LEVEL === 'debug' || process.env.GITU_LOG_VERBOSE === 'true';
  /**
   * Load models from database and cache them
   */
  private async loadModelsFromDatabase(): Promise<Record<string, AIModel>> {
    try {
      const result = await pool.query(
        `SELECT id, name, model_id, provider, context_window, 
                cost_input, cost_output, is_active
         FROM ai_models 
         WHERE is_active = true
         ORDER BY provider, name`
      );

      const models: Record<string, AIModel> = {};

      for (const row of result.rows) {
        const dbModel = row as DBModel;

        const inputCostPer1k = Number(dbModel.cost_input ?? 0) || 0;
        const outputCostPer1k = Number(dbModel.cost_output ?? 0) || 0;
        const avgCostPer1kTokens = (inputCostPer1k + outputCostPer1k) / 2;
        const contextWindow = typeof dbModel.context_window === 'number' && dbModel.context_window > 0 ? dbModel.context_window : 128000;

        models[dbModel.model_id] = {
          provider: mapProviderName(dbModel.provider),
          modelId: dbModel.model_id,
          contextWindow,
          costPer1kTokens: avgCostPer1kTokens,
        };
      }

      console.log(`[Gitu AI Router] Loaded ${Object.keys(models).length} models from database`);
      return models;
    } catch (error) {
      console.error('[Gitu AI Router] Error loading models from database:', error);
      // Return empty object on error - will cause fallback behavior
      return {};
    }
  }

  /**
   * Get models with cache management
   */
  private async getModels(): Promise<Record<string, AIModel>> {
    const now = Date.now();

    // Check if cache is valid
    if (Object.keys(modelsCache).length > 0 && (now - modelsCacheTimestamp) < MODELS_CACHE_TTL) {
      return modelsCache;
    }

    // Refresh cache
    modelsCache = await this.loadModelsFromDatabase();
    modelsCacheTimestamp = now;

    return modelsCache;
  }

  /**
   * Fetch recent chat history for a session or user.
   */
  async getChatHistory(userId: string, sessionId?: string, limit: number = 10): Promise<Array<{ role: 'user' | 'assistant' | 'system'; content: string }>> {
    try {
      let query: string;
      let params: any[];

      if (sessionId) {
        query = `SELECT role, content FROM gitu_messages WHERE session_id = $1 ORDER BY timestamp ASC LIMIT $2`;
        params = [sessionId, limit];
      } else {
        query = `SELECT role, content FROM gitu_messages WHERE user_id = $1 AND session_id IS NULL AND timestamp > NOW() - INTERVAL '2 hours' ORDER BY timestamp ASC LIMIT $2`;
        params = [userId, limit];
      }

      const result = await pool.query(query, params);
      return result.rows.map(row => ({
        role: row.role as 'user' | 'assistant' | 'system',
        content: this.toChatContentString(row.content)
      }));
    } catch (error) {
      console.error('[Gitu AI Router] Error fetching chat history:', error);
      return [];
    }
  }

  private toChatContentString(content: unknown): string {
    if (content === null || content === undefined) return '';
    if (typeof content === 'string') return content;
    if (typeof content === 'object') {
      const asRecord = content as Record<string, unknown>;
      const text = asRecord.text;
      if (typeof text === 'string') return text;
      const message = asRecord.message;
      if (typeof message === 'string') return message;
      const value = asRecord.value;
      if (typeof value === 'string') return value;
      const innerContent = asRecord.content;
      if (typeof innerContent === 'string') return innerContent;
    }
    try {
      return JSON.stringify(content);
    } catch {
      return String(content);
    }
  }

  /**
   * Save a message to history.
   */
  async saveMessage(userId: string, role: string, content: string, platform: string, sessionId?: string, platformUserId?: string): Promise<void> {
    try {
      await pool.query(
        `INSERT INTO gitu_messages (user_id, role, content, platform, session_id, platform_user_id)
         VALUES ($1, $2, $3, $4, $5, $6)`,
        [userId, role, { text: content }, platform, sessionId, platformUserId]
      );
    } catch (error) {
      console.error('[Gitu AI Router] Error saving message:', error);
    }
  }

  /**
   * Retrieve relevant context from chunks using vector similarity.
   */
  async retrieveContext(query: string, userId: string, limit: number = 5): Promise<string[]> {
    try {
      const embedding = await generateEmbedding(query);
      const vectorStr = `[${embedding.join(',')}]`;

      const result = await pool.query(
        `SELECT content_text 
         FROM chunks 
         JOIN sources ON chunks.source_id = sources.id
         JOIN notebooks ON sources.notebook_id = notebooks.id
         WHERE notebooks.user_id = $1
         ORDER BY embedding <=> $2
         LIMIT $3`,
        [userId, vectorStr, limit]
      );

      return result.rows.map(row => row.content_text);
    } catch (error) {
      console.error('[Gitu AI Router] Retrieval error:', error);
      return [];
    }
  }

  /**
   * Route an AI request to the appropriate model and generate a response.
   * 
   * @param request - The AI request parameters
   * @returns The AI response with metadata
   */
  async route(request: AIRequest): Promise<AIResponse> {
    // Normalize request
    const prompt = request.prompt || request.content || '';
    if (!prompt) {
      throw new Error('Prompt or content is required');
    }

    const taskType = request.taskType || 'chat';
    const context = request.context || [];
    const includeSystemPrompt = request.includeSystemPrompt !== false; // Default true
    const includeTools = request.includeTools !== false && taskType === 'chat'; // Default true for chat

    // Retrieval (RAG)
    if (request.useRetrieval) {
      const retrieved = await this.retrieveContext(prompt, request.userId);
      if (retrieved.length > 0) {
        if (this.verboseLogs) {
          console.log(`[Gitu AI Router] Injected ${retrieved.length} chunks of context.`);
        }
        context.push(...retrieved);
      }
    }

    // Build system prompt with Gitu identity, user context, and tools
    let systemPrompt = '';
    if (includeSystemPrompt) {
      try {
        const promptResult = await gituSystemPromptBuilder.buildSystemPrompt({
          userId: request.userId,
          platform: request.platform || 'web',
          sessionId: request.sessionId,
          includeTools,
          includeMemories: true,
        });
        systemPrompt = promptResult.systemPrompt;
        if (this.verboseLogs) {
          console.log(`[Gitu AI Router] Built system prompt with ${promptResult.toolDefinitions?.length || 0} tools`);
        }
      } catch (error) {
        console.warn('[Gitu AI Router] Failed to build system prompt, using minimal:', error);
        systemPrompt = await gituSystemPromptBuilder.buildMinimalPrompt(request.userId);
      }
    }

    // Get user's model preferences
    const preferences = await this.getUserPreferences(request.userId);

    // Select the best model for this request, considering explicit preference override
    const model = await this.selectModel(
      taskType,
      preferences,
      context,
      request.preferredModel
    );

    // Estimate cost before execution
    const estimate = await this.estimateCost(prompt, context, model);

    // Generate response using the selected model
    const startTime = Date.now();
    let content: string;
    let tokensUsed: number;

    // Build messages array with system prompt
    const messages: Array<{ role: 'user' | 'assistant' | 'system'; content: string }> = [];

    // Add system prompt if available
    if (systemPrompt) {
      messages.push({ role: 'system', content: systemPrompt });
    }

    // Load and add chat history
    const history = await this.getChatHistory(request.userId, request.sessionId);
    if (history.length > 0) {
      if (this.verboseLogs) {
        console.log(`[Gitu AI Router] Injected ${history.length} messages of history.`);
      }
      messages.push(...history);
    }

    // Add context as user messages (simplified injection)
    for (const ctx of context) {
      messages.push({ role: 'user', content: `Source Context: ${ctx}` });
    }

    // Add the user's prompt
    messages.push({ role: 'user', content: prompt });

    try {
      if (model.provider === 'gemini') {
        content = await generateWithGemini(messages, model.modelId);
      } else if (model.provider === 'openrouter') {
        content = await generateWithOpenRouter(messages, model.modelId, request.maxTokens);
      } else {
        throw new Error(`Unsupported provider: ${model.provider}`);
      }

      // Estimate tokens used (rough approximation: 1 token ≈ 4 characters)
      tokensUsed = Math.ceil((prompt.length + content.length) / 4);

      const cost = (tokensUsed / 1000) * model.costPer1kTokens;

      // Save exchange to history
      await this.saveMessage(
        request.userId,
        'user',
        prompt,
        request.platform || 'web',
        request.sessionId,
        request.platformUserId
      );

      await this.saveMessage(
        request.userId,
        'assistant',
        content,
        request.platform || 'web',
        request.sessionId,
        request.platformUserId
      );

      return {
        content,
        model: model.modelId,
        tokensUsed,
        cost,
        finishReason: 'stop',
      };
    } catch (error: any) {
      console.error(`AI Router error with model ${model.modelId}:`, error);

      // Improved Error Handling
      if (error.message.includes('429') || error.message.includes('Quota exceeded')) {
        throw new Error('AI Provider Rate Limit Exceeded. Please try again later.');
      }
      if (error.message.includes('401') || error.message.includes('API key')) {
        throw new Error('AI Provider Authentication Failed. Check API Keys.');
      }

      // Try fallback model
      const fallbackModel = await this.fallback(model, error);
      if (fallbackModel) {
        console.log(`Falling back to model: ${fallbackModel.modelId}`);
        // Recursive call with fallback model (update request to use fallback)
        return this.route({
          ...request,
          taskType: 'chat',  // Use generic task type for fallback
        });
      }

      throw error;
    }
  }

  /**
   * Select the best model for a task based on user preferences and requirements.
   * 
   * @param taskType - The type of task
   * @param preferences - User's model preferences
   * @param context - Context strings to check against model limits
   * @returns The selected AI model
   */
  async selectModel(
    taskType: TaskType,
    preferences: ModelPreferences,
    context: string[] = [],
    overrideModelId?: string
  ): Promise<AIModel> {
    // Get available models from database
    const models = await this.getModels();

    let model: AIModel | undefined;

    // Check for override model
    if (overrideModelId && overrideModelId !== 'default' && models[overrideModelId]) {
      model = models[overrideModelId];
    } else {
      // Check if user has a task-specific model preference
      const preferredModelId = preferences.taskSpecificModels[taskType] || preferences.defaultModel;
      model = models[preferredModelId];

      // If preferred model not found, try to find a model matching provider hints for task type
      if (!model) {
        const providerHints = DEFAULT_TASK_PROVIDER_HINTS[taskType] || ['gemini', 'openrouter'];
        for (const preferredProvider of providerHints) {
          const matchingModel = Object.values(models).find(m => m.provider === preferredProvider);
          if (matchingModel) {
            model = matchingModel;
            break;
          }
        }
      }
    }

    // If still no model found, use first available model
    if (!model) {
      const availableModels = Object.values(models);
      if (availableModels.length === 0) {
        throw new Error('No AI models available. Please configure models in admin panel.');
      }
      model = availableModels[0];
    }

    // Check if context fits within model's context window
    const totalContextLength = context.reduce((sum, ctx) => sum + ctx.length, 0);
    const estimatedTokens = Math.ceil(totalContextLength / 4);

    if (estimatedTokens > model.contextWindow) {
      // Context too large, find a model with larger context window
      console.warn(`Context (${estimatedTokens} tokens) exceeds model limit (${model.contextWindow}). Finding alternative...`);
      model = await this.findModelWithLargerContext(estimatedTokens);
    }

    return model;
  }

  /**
   * Find a model with a larger context window.
   * 
   * @param requiredTokens - Minimum required context window
   * @returns A model with sufficient context window
   */
  private async findModelWithLargerContext(requiredTokens: number): Promise<AIModel> {
    const models = await this.getModels();

    // Sort models by context window size
    const sortedModels = Object.values(models)
      .filter(m => m.contextWindow >= requiredTokens)
      .sort((a, b) => a.contextWindow - b.contextWindow);

    if (sortedModels.length === 0) {
      throw new Error(`No model found with context window >= ${requiredTokens} tokens`);
    }

    // Return the smallest model that fits (most cost-effective)
    return sortedModels[0];
  }

  /**
   * Estimate the cost of a request before execution.
   * 
   * @param prompt - The user's prompt
   * @param context - Context strings
   * @param model - The model to use
   * @returns Cost estimate
   */
  async estimateCost(prompt: string, context: string[], model: AIModel): Promise<CostEstimate> {
    const models = await this.getModels();

    // Estimate tokens (rough: 1 token ≈ 4 characters)
    const totalLength = prompt.length + context.reduce((sum, ctx) => sum + ctx.length, 0);
    const estimatedTokens = Math.ceil(totalLength / 4);

    // Estimate response tokens (assume 2x input for safety)
    const totalEstimatedTokens = estimatedTokens * 3;

    const estimatedCostUSD = (totalEstimatedTokens / 1000) * model.costPer1kTokens;

    // Find cheaper alternatives
    const alternatives = Object.entries(models)
      .filter(([id, m]) => m.contextWindow >= estimatedTokens && id !== model.modelId)
      .map(([id, m]) => ({
        model: id,
        estimatedCost: (totalEstimatedTokens / 1000) * m.costPer1kTokens,
      }))
      .sort((a, b) => a.estimatedCost - b.estimatedCost)
      .slice(0, 3);

    return {
      estimatedTokens: totalEstimatedTokens,
      estimatedCostUSD,
      confidence: 0.7,  // Rough estimate
      alternatives,
    };
  }

  /**
   * Estimate tokens in a string.
   * 
   * @param content - The content to estimate
   * @returns Estimated token count
   */
  estimateTokens(content: string): number {
    // Rough approximation: 1 token ≈ 4 characters
    return Math.ceil(content.length / 4);
  }

  /**
   * Find a fallback model when the primary model fails.
   * 
   * @param primaryModel - The model that failed
   * @param error - The error that occurred
   * @returns A fallback model or null if none available
   */
  async fallback(primaryModel: AIModel, error: Error): Promise<AIModel | null> {
    console.log(`Finding fallback for ${primaryModel.modelId} due to: ${error.message}`);

    const models = await this.getModels();

    // Determine fallback strategy based on error
    const isContextLimit = error.message.includes('context') || error.message.includes('too long');

    if (isContextLimit) {
      // Need a model with larger context window
      const requiredTokens = primaryModel.contextWindow * 1.5;
      try {
        return await this.findModelWithLargerContext(requiredTokens);
      } catch {
        return null;
      }
    }

    // For rate limits or unavailability, try a different provider or model
    const allModels = Object.values(models);

    // 1. Try same provider, different model (especially for OpenRouter)
    if (primaryModel.provider === 'openrouter') {
        const sameProviderCandidates = allModels.filter(m => 
            m.provider === 'openrouter' && 
            m.modelId !== primaryModel.modelId
        );
        
        // Sort by cost similarity
        sameProviderCandidates.sort((a, b) => 
            Math.abs(a.costPer1kTokens - primaryModel.costPer1kTokens) - 
            Math.abs(b.costPer1kTokens - primaryModel.costPer1kTokens)
        );

        if (sameProviderCandidates.length > 0) {
            return sameProviderCandidates[0];
        }
    }

    // 2. Try different provider
    const alternativeProviders = ['gemini', 'openrouter', 'anthropic', 'openai'] as const;
    const currentProvider = primaryModel.provider;

    for (const provider of alternativeProviders) {
      if (provider !== currentProvider) {
        // Find a model from this provider
        const alternativeModel = allModels.find(m => m.provider === provider);
        if (alternativeModel) {
          return alternativeModel;
        }
      }
    }
    
    // 3. Last resort: Native Gemini if available (and not already tried)
    if (currentProvider !== 'gemini' && process.env.GEMINI_API_KEY) {
        // Try to find Gemini in DB first
        const geminiModel = allModels.find(m => m.provider === 'gemini');
        if (geminiModel) return geminiModel;
    }

    return null;
  }

  /**
   * Suggest a cheaper model for the same task.
   * 
   * @param currentModel - The current model ID
   * @param taskType - The task type
   * @returns A cheaper model or null if current is cheapest
   */
  async suggestCheaperModel(currentModel: string, taskType: TaskType): Promise<AIModel | null> {
    const models = await this.getModels();
    const current = models[currentModel];
    if (!current) return null;

    // Find cheaper models with similar capabilities
    const cheaperModels = Object.values(models)
      .filter(m =>
        m.costPer1kTokens < current.costPer1kTokens &&
        m.contextWindow >= current.contextWindow * 0.5  // At least 50% of context window
      )
      .sort((a, b) => a.costPer1kTokens - b.costPer1kTokens);

    return cheaperModels.length > 0 ? cheaperModels[0] : null;
  }

  /**
   * Get user's model preferences from database.
   * 
   * @param userId - The user's ID
   * @returns User's model preferences
   */
  async getUserPreferences(userId: string): Promise<ModelPreferences> {
    try {
      // Check if user has Gitu settings
      const result = await pool.query(
        `SELECT gitu_settings FROM users WHERE id = $1`,
        [userId]
      );

      if (result.rows.length === 0) {
        // User not found, return defaults
        return this.getDefaultPreferences();
      }

      const gituSettings = result.rows[0].gitu_settings || {};

      // Extract model preferences from settings (support both nested and flat for migration)
      const modelPrefs = gituSettings.modelPreferences || gituSettings;

      const preferences: ModelPreferences = {
        defaultModel: modelPrefs.defaultModel || 'default',
        taskSpecificModels: modelPrefs.taskSpecificModels || this.getDefaultPreferences().taskSpecificModels,
        apiKeySource: modelPrefs.apiKeySource || 'platform',
        personalKeys: modelPrefs.personalKeys || {},
      };

      return preferences;
    } catch (error) {
      console.error('Error fetching user preferences:', error);
      return this.getDefaultPreferences();
    }
  }

  /**
   * Get default model preferences.
   * Uses 'default' as a placeholder - actual model will be selected from database.
   * 
   * @returns Default preferences
   */
  private getDefaultPreferences(): ModelPreferences {
    // Use 'default' as placeholder - selectModel will pick first available from database
    return {
      defaultModel: 'default', // Will trigger database lookup
      taskSpecificModels: {
        chat: 'default',
        research: 'default',
        coding: 'default',
        analysis: 'default',
        summarization: 'default',
        creative: 'default',
      },
      apiKeySource: 'platform',
      personalKeys: {},
    };
  }

  /**
   * Update user's model preferences.
   * 
   * @param userId - The user's ID
   * @param preferences - New preferences (partial update)
   */
  async updateUserPreferences(userId: string, preferences: Partial<ModelPreferences>): Promise<void> {
    try {
      // Get current settings
      const current = await this.getUserPreferences(userId);

      // Merge with new preferences
      const updated = {
        ...current,
        ...preferences,
        taskSpecificModels: {
          ...current.taskSpecificModels,
          ...(preferences.taskSpecificModels || {}),
        },
        personalKeys: {
          ...current.personalKeys,
          ...(preferences.personalKeys || {}),
        },
      };

      // Update in database
      await pool.query(
        `UPDATE users 
         SET gitu_settings = jsonb_set(
           COALESCE(gitu_settings, '{}'::jsonb),
           '{modelPreferences}',
           $1::jsonb
         )
         WHERE id = $2`,
        [JSON.stringify(updated), userId]
      );
    } catch (error) {
      console.error('Error updating user preferences:', error);
      throw error;
    }
  }

  /**
   * Get available models for a user based on their API key configuration.
   * 
   * @param userId - The user's ID
   * @returns List of available models
   */
  async getAvailableModels(userId: string): Promise<AIModel[]> {
    const preferences = await this.getUserPreferences(userId);
    const models = await this.getModels();

    // If using platform keys, all models are available
    if (preferences.apiKeySource === 'platform') {
      return Object.values(models);
    }

    // If using personal keys, filter by available keys
    const availableModels: AIModel[] = [];

    if (preferences.personalKeys?.gemini) {
      availableModels.push(...Object.values(models).filter(m => m.provider === 'gemini'));
    }

    if (preferences.personalKeys?.openrouter) {
      availableModels.push(...Object.values(models).filter(m => m.provider === 'openrouter'));
    }

    if (preferences.personalKeys?.openai) {
      availableModels.push(...Object.values(models).filter(m => m.provider === 'openai'));
    }

    if (preferences.personalKeys?.anthropic) {
      availableModels.push(...Object.values(models).filter(m => m.provider === 'anthropic'));
    }

    return availableModels;
  }
}

// Export singleton instance
export const gituAIRouter = new GituAIRouter();
export default gituAIRouter;
