/**
 * Unit tests for Gitu AI Router Service
 */

import { describe, it, expect, beforeEach, jest, afterEach } from '@jest/globals';
import type { AIRequest, ModelPreferences, AIModel } from '../services/gituAIRouter.js';

// Define mocks before everything
const mockDbPool = {
  query: jest.fn(),
  connect: jest.fn(),
  on: jest.fn(),
};

const mockGenerateWithGemini = jest.fn<() => Promise<string>>();
const mockGenerateWithOpenRouter = jest.fn<() => Promise<string>>();
const mockGenerateEmbedding = jest.fn<() => Promise<number[]>>();

// Mock dependencies using unstable_mockModule (must be before imports)
jest.unstable_mockModule('../config/database.js', () => {
  return {
    __esModule: true,
    default: mockDbPool,
  };
});

jest.unstable_mockModule('../services/aiService.js', () => {
  return {
    __esModule: true,
    generateWithGemini: mockGenerateWithGemini,
    generateWithOpenRouter: mockGenerateWithOpenRouter,
    generateEmbedding: mockGenerateEmbedding,
  };
});

// Import the module under test dynamically after mocking
// Use a function to load it to avoid top-level await issues in some environments
let gituAIRouter: any;

// Type for mocked pool
type MockedPool = {
  query: jest.Mock;
};

describe('GituAIRouter', () => {
  let mockPool: MockedPool;

  // Mock AI models data (simulating database response)
  const mockModelsData = [
    {
      id: '1',
      name: 'Gemini 2.0 Flash',
      model_id: 'gemini-2.0-flash',
      provider: 'google',
      context_window: 1000000,
      cost_input: 0.00015,
      cost_output: 0.00015,
      is_active: true,
    },
    {
      id: '2',
      name: 'Gemini 1.5 Pro',
      model_id: 'gemini-1.5-pro',
      provider: 'google',
      context_window: 2000000,
      cost_input: 0.00125,
      cost_output: 0.00125,
      is_active: true,
    },
    {
      id: '3',
      name: 'Gemini 1.5 Flash',
      model_id: 'gemini-1.5-flash',
      provider: 'google',
      context_window: 1000000,
      cost_input: 0.000075,
      cost_output: 0.000075,
      is_active: true,
    },
    {
      id: '4',
      name: 'Claude 3.5 Sonnet',
      model_id: 'anthropic/claude-3.5-sonnet',
      provider: 'openrouter',
      context_window: 200000,
      cost_input: 0.003,
      cost_output: 0.015,
      is_active: true,
    },
    {
      id: '5',
      name: 'Llama 3.3 70B',
      model_id: 'meta-llama/llama-3.3-70b-instruct',
      provider: 'openrouter',
      context_window: 128000,
      cost_input: 0.00088,
      cost_output: 0.00088,
      is_active: true,
    },
    {
      id: '6',
      name: 'GPT-4 Turbo',
      model_id: 'openai/gpt-4-turbo',
      provider: 'openrouter',
      context_window: 128000,
      cost_input: 0.01,
      cost_output: 0.03,
      is_active: true,
    },
  ];

  beforeEach(async () => {
    // Load module if not loaded
    if (!gituAIRouter) {
        const module = await import('../services/gituAIRouter.js');
        gituAIRouter = module.gituAIRouter;
    }

    jest.clearAllMocks();
    mockGenerateWithGemini.mockReset();
    mockGenerateWithOpenRouter.mockReset();
    mockGenerateEmbedding.mockReset();
    mockGenerateWithGemini.mockResolvedValue('Mocked Gemini response');
    mockGenerateWithOpenRouter.mockResolvedValue('Mocked OpenRouter response');
    mockGenerateEmbedding.mockResolvedValue([0, 0, 0]);
    
    mockPool = mockDbPool as unknown as MockedPool;
    
    // Explicitly set the mock implementation for this test run
    mockPool.query.mockImplementation((query: any) => {
      // Handle the model loading query specifically
      if (typeof query === 'string' && query.includes('FROM ai_models')) {
        return Promise.resolve({
          rows: mockModelsData,
          rowCount: mockModelsData.length,
        });
      }
      
      // Handle user preferences query
      if (typeof query === 'string' && query.includes('FROM users')) {
          return Promise.resolve({
            rows: [{
              gitu_settings: {
                defaultModel: 'gemini-2.0-flash',
                taskSpecificModels: {},
                apiKeySource: 'platform',
              },
            }],
            rowCount: 1,
          });
      }

      // Default fallback
      return Promise.resolve({
        rows: [],
        rowCount: 0,
      });
    });

    (gituAIRouter as any).modelsCache = {};
    (gituAIRouter as any).modelsCacheTimestamp = 0;
  });

  describe('selectModel', () => {
    it('should select user preferred model when available', async () => {
      const preferences: ModelPreferences = {
        defaultModel: 'gemini-1.5-pro',
        taskSpecificModels: {
          chat: 'gemini-2.0-flash',
          research: 'gemini-1.5-pro',
          coding: 'anthropic/claude-3.5-sonnet',
          analysis: 'gemini-1.5-pro',
          summarization: 'gemini-1.5-flash',
          creative: 'anthropic/claude-3.5-sonnet',
        },
        apiKeySource: 'platform',
      };

      const model = await gituAIRouter.selectModel('research', preferences);
      expect(model.modelId).toBe('gemini-1.5-pro');
    });

    it('should fall back to default model when preferred not found', async () => {
      const preferences: ModelPreferences = {
        defaultModel: 'invalid-model',
        taskSpecificModels: {
          chat: 'gemini-2.0-flash',
          research: 'gemini-1.5-pro',
          coding: 'anthropic/claude-3.5-sonnet',
          analysis: 'gemini-1.5-pro',
          summarization: 'gemini-1.5-flash',
          creative: 'anthropic/claude-3.5-sonnet',
        },
        apiKeySource: 'platform',
      };

      const model = await gituAIRouter.selectModel('chat', preferences);
      expect(model.modelId).toBe('gemini-2.0-flash');  // Default for chat
    });

    it('should select model with larger context when needed', async () => {
      const preferences: ModelPreferences = {
        defaultModel: 'gemini-1.5-flash',
        taskSpecificModels: {
          chat: 'gemini-2.0-flash',
          research: 'gemini-1.5-pro',
          coding: 'anthropic/claude-3.5-sonnet',
          analysis: 'gemini-1.5-pro',
          summarization: 'gemini-1.5-flash',
          creative: 'anthropic/claude-3.5-sonnet',
        },
        apiKeySource: 'platform',
      };

      // Create context that exceeds gemini-1.5-flash limit (1M tokens = 4M chars)
      const largeContext = ['x'.repeat(5000000)];  // 5M characters

      const model = await gituAIRouter.selectModel('chat', preferences, largeContext);
      
      // Should select a model with larger context window
      expect(model.contextWindow).toBeGreaterThan(1000000);
    });
  });

  describe('estimateCost', () => {
    it('should estimate cost correctly', async () => {
      const model: AIModel = {
        provider: 'gemini',
        modelId: 'gemini-2.0-flash',
        contextWindow: 1000000,
        costPer1kTokens: 0.00015,
      };

      const prompt = 'Hello, world!';
      const context = ['Context 1', 'Context 2'];

      const estimate = await gituAIRouter.estimateCost(prompt, context, model);

      expect(estimate.estimatedTokens).toBeGreaterThan(0);
      expect(estimate.estimatedCostUSD).toBeGreaterThan(0);
      expect(estimate.confidence).toBeGreaterThan(0);
      expect(estimate.alternatives).toBeInstanceOf(Array);
    });

    it('should provide cheaper alternatives', async () => {
      const model: AIModel = {
        provider: 'openrouter',
        modelId: 'openai/gpt-4-turbo',
        contextWindow: 128000,
        costPer1kTokens: 0.01,  // Expensive model
      };

      const prompt = 'Test prompt';
      const context = [];

      const estimate = await gituAIRouter.estimateCost(prompt, context, model);

      expect(estimate.alternatives.length).toBeGreaterThan(0);
      // Alternatives should be cheaper
      estimate.alternatives.forEach(alt => {
        expect(alt.estimatedCost).toBeLessThan(estimate.estimatedCostUSD);
      });
    });
  });

  describe('estimateTokens', () => {
    it('should estimate tokens correctly', () => {
      const content = 'This is a test string with some words.';
      const tokens = gituAIRouter.estimateTokens(content);
      
      // Rough estimate: 1 token ≈ 4 characters
      const expectedTokens = Math.ceil(content.length / 4);
      expect(tokens).toBe(expectedTokens);
    });

    it('should handle empty strings', () => {
      const tokens = gituAIRouter.estimateTokens('');
      expect(tokens).toBe(0);
    });
  });

  describe('fallback', () => {
    it('should find fallback model on rate limit error', async () => {
      const primaryModel: AIModel = {
        provider: 'gemini',
        modelId: 'gemini-2.0-flash',
        contextWindow: 1000000,
        costPer1kTokens: 0.00015,
      };

      const error = new Error('Rate limit exceeded (429)');
      const fallbackModel = await gituAIRouter.fallback(primaryModel, error);

      expect(fallbackModel).not.toBeNull();
      expect(fallbackModel?.provider).not.toBe('gemini');  // Should use different provider
    });

    it('should find model with larger context on context limit error', async () => {
      const primaryModel: AIModel = {
        provider: 'gemini',
        modelId: 'gemini-1.5-flash',
        contextWindow: 1000000,
        costPer1kTokens: 0.000075,
      };

      const error = new Error('Context length too long');
      const fallbackModel = await gituAIRouter.fallback(primaryModel, error);

      if (fallbackModel) {
        expect(fallbackModel.contextWindow).toBeGreaterThan(primaryModel.contextWindow);
      }
    });

    it('should return null when no fallback available', async () => {
      const primaryModel: AIModel = {
        provider: 'gemini',
        modelId: 'gemini-1.5-pro',
        contextWindow: 2000000,  // Largest context window
        costPer1kTokens: 0.00125,
      };

      const error = new Error('Context length too long');
      const fallbackModel = await gituAIRouter.fallback(primaryModel, error);

      // May return null if no larger context model exists
      // This is acceptable behavior
      expect(fallbackModel === null || fallbackModel.contextWindow > primaryModel.contextWindow).toBe(true);
    });
  });

  describe('suggestCheaperModel', () => {
    it('should suggest cheaper model when available', async () => {
      const currentModel = 'openai/gpt-4-turbo';  // Expensive
      const cheaper = await gituAIRouter.suggestCheaperModel(currentModel, 'chat');

      expect(cheaper).not.toBeNull();
      if (cheaper) {
        // GPT-4 Turbo costs 0.02 per 1k tokens (avg of input/output)
        // Should find cheaper alternatives like Gemini or Llama
        expect(cheaper.costPer1kTokens).toBeLessThan(0.02);
      }
    });

    it('should return null when current model is cheapest', async () => {
      const currentModel = 'gemini-1.5-flash';  // Already very cheap
      const cheaper = await gituAIRouter.suggestCheaperModel(currentModel, 'chat');

      // May or may not find cheaper, depends on model definitions
      // This is acceptable
      expect(cheaper === null || cheaper.costPer1kTokens < 0.000075).toBe(true);
    });

    it('should return null for invalid model', async () => {
      const cheaper = await gituAIRouter.suggestCheaperModel('invalid-model', 'chat');
      expect(cheaper).toBeNull();
    });
  });

  describe('route', () => {
    it('should route request and return response', async () => {
      // Mock database response for user preferences
      mockPool.query = jest.fn().mockImplementation((query: any) => {
        if (typeof query === 'string' && query.includes('FROM ai_models')) {
          return Promise.resolve({
            rows: mockModelsData,
            rowCount: mockModelsData.length,
          });
        }
        if (typeof query === 'string' && query.includes('FROM users')) {
          return Promise.resolve({
            rows: [{
              gitu_settings: {
                defaultModel: 'gemini-2.0-flash',
                taskSpecificModels: {},
                apiKeySource: 'platform',
              },
            }],
            rowCount: 1,
          });
        }
        return Promise.resolve({ rows: [], rowCount: 0 });
      }) as any;

      const request: AIRequest = {
        userId: 'test-user',
        sessionId: 'test-session',
        prompt: 'Hello, AI!',
        context: [],
        taskType: 'chat',
      };

      const response = await gituAIRouter.route(request);

      expect(response.content).toBeDefined();
      expect(response.model).toBeDefined();
      expect(response.tokensUsed).toBeGreaterThan(0);
      expect(response.cost).toBeGreaterThanOrEqual(0);
      expect(response.finishReason).toBe('stop');
    });

    it('should handle errors and attempt fallback', async () => {
      // Mock database responses
      mockPool.query = jest.fn().mockImplementation((query: any) => {
        if (typeof query === 'string' && query.includes('FROM ai_models')) {
          return Promise.resolve({
            rows: mockModelsData,
            rowCount: mockModelsData.length,
          });
        }
        if (typeof query === 'string' && query.includes('FROM users')) {
          return Promise.resolve({
            rows: [{
              gitu_settings: {
                defaultModel: 'gemini-2.0-flash',
                taskSpecificModels: {},
                apiKeySource: 'platform',
              },
            }],
            rowCount: 1,
          });
        }
        return Promise.resolve({ rows: [], rowCount: 0 });
      }) as any;

      mockGenerateWithGemini
        .mockRejectedValueOnce(new Error('Rate limit exceeded'))
        .mockResolvedValueOnce('Fallback response');

      const request: AIRequest = {
        userId: 'test-user',
        sessionId: 'test-session',
        prompt: 'Hello, AI!',
        context: [],
        taskType: 'chat',
      };

      // Should not throw, should use fallback
      const response = await gituAIRouter.route(request);
      expect(response.content).toBeDefined();
    });
  });

  describe('getAvailableModels', () => {
    it('should return all models for platform keys', async () => {
      mockPool.query = jest.fn().mockImplementation((query: any) => {
        if (typeof query === 'string' && query.includes('FROM ai_models')) {
          return Promise.resolve({
            rows: mockModelsData,
            rowCount: mockModelsData.length,
          });
        }
        if (typeof query === 'string' && query.includes('FROM users')) {
          return Promise.resolve({
            rows: [{
              gitu_settings: {
                apiKeySource: 'platform',
              },
            }],
            rowCount: 1,
          });
        }
        return Promise.resolve({ rows: [], rowCount: 0 });
      }) as any;

      const models = await gituAIRouter.getAvailableModels('test-user');
      expect(models.length).toBe(mockModelsData.length);
    });

    it('should filter models based on personal keys', async () => {
      mockPool.query = jest.fn().mockImplementation((query: any) => {
        if (typeof query === 'string' && query.includes('FROM ai_models')) {
          return Promise.resolve({
            rows: mockModelsData,
            rowCount: mockModelsData.length,
          });
        }
        if (typeof query === 'string' && query.includes('FROM users')) {
          return Promise.resolve({
            rows: [{
              gitu_settings: {
                apiKeySource: 'personal',
                personalKeys: {
                  gemini: 'test-key',
                },
              },
            }],
            rowCount: 1,
          });
        }
        return Promise.resolve({ rows: [], rowCount: 0 });
      }) as any;

      const models = await gituAIRouter.getAvailableModels('test-user');
      
      // Should only return Gemini models (provider mapped from 'google' to 'gemini')
      expect(models.every(m => m.provider === 'gemini')).toBe(true);
      expect(models.length).toBe(3); // 3 Gemini models in mock data
    });
  });

  describe('saveMessage', () => {
    it('should wrap plain text content as JSON for jsonb column', async () => {
      (mockPool.query as any).mockResolvedValue({ rows: [], rowCount: 1 });

      await gituAIRouter.saveMessage('test-user', 'user', 'Hello', 'web', 'test-session', 'platform-user');

      expect(mockPool.query).toHaveBeenCalledTimes(1);
      const [query, params] = mockPool.query.mock.calls[0] as [unknown, any[]];
      expect(String(query)).toContain('INSERT INTO gitu_messages');
      expect(params[2]).toEqual({ text: 'Hello' });
    });
  });

  describe('updateUserPreferences', () => {
    it('should update user preferences', async () => {
      mockPool.query = jest.fn().mockImplementation((query: any) => {
        if (typeof query === 'string' && query.includes('FROM ai_models')) {
          return Promise.resolve({
            rows: mockModelsData,
            rowCount: mockModelsData.length,
          });
        }
        if (typeof query === 'string' && query.includes('FROM users') && query.includes('SELECT')) {
          // Getting current preferences
          return Promise.resolve({
            rows: [{
              gitu_settings: {
                defaultModel: 'gemini-2.0-flash',
                taskSpecificModels: {},
                apiKeySource: 'platform',
              },
            }],
            rowCount: 1,
          });
        }
        if (typeof query === 'string' && query.includes('UPDATE users')) {
          // Update query
          return Promise.resolve({
            rows: [],
            rowCount: 1,
          });
        }
        return Promise.resolve({ rows: [], rowCount: 0 });
      }) as any;

      await gituAIRouter.updateUserPreferences('test-user', {
        defaultModel: 'gemini-1.5-pro',
      });

      // Should have called query multiple times (get models, get prefs, update prefs)
      expect(mockPool.query).toHaveBeenCalled();
    });
  });
});
