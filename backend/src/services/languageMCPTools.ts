import { gituMCPHub, MCPTool, MCPContext } from './gituMCPHub.js';
import { gituAIRouter } from './gituAIRouter.js';

/**
 * Tool: Translate Text
 * Uses the capabilities of the configured AI model to translate text.
 */
const translateTextTool: MCPTool = {
    name: 'translate_text',
    description: 'Translate text from one language to another.',
    schema: {
        type: 'object',
        properties: {
            text: { type: 'string', description: 'The text to translate' },
            targetLanguage: { type: 'string', description: 'The target language (e.g., "Spanish", "French", "Japanese")' },
            sourceLanguage: { type: 'string', description: 'Optional source language (if known)', default: 'auto-detect' }
        },
        required: ['text', 'targetLanguage']
    },
    handler: async (args: any, context: MCPContext) => {
        const { text, targetLanguage, sourceLanguage = 'auto-detect' } = args;

        const prompt = `Translate the following text from ${sourceLanguage} to ${targetLanguage}. Return ONLY the translated text, preserving original tone and formatting.
    
    Text: "${text}"`;

        const response = await gituAIRouter.route({
            userId: context.userId,
            prompt: prompt,
            taskType: 'chat', // Use chat model for translation
            includeSystemPrompt: false, // Pure translation task
            includeTools: false
        });

        return {
            success: true,
            original: text,
            translated: response.content.trim(),
            sourceLanguage,
            targetLanguage
        };
    }
};

/**
 * Tool: Detect Language
 */
const detectLanguageTool: MCPTool = {
    name: 'detect_language',
    description: 'Detect the language of a given text.',
    schema: {
        type: 'object',
        properties: {
            text: { type: 'string', description: 'The text to analyze' }
        },
        required: ['text']
    },
    handler: async (args: any, context: MCPContext) => {
        const { text } = args;

        const prompt = `Analyze the following text and determine its language. Return ONLY a JSON object with keys: "language" (name), "isoCode" (2 letter code), and "confidence" (0-1).
    
    Text: "${text}"`;

        const response = await gituAIRouter.route({
            userId: context.userId,
            prompt: prompt,
            taskType: 'analysis',
            includeSystemPrompt: false,
            includeTools: false
        });

        // Extract JSON from response if wrapped in markdown
        const jsonMatch = response.content.match(/\{[\s\S]*\}/);
        const jsonStr = jsonMatch ? jsonMatch[0] : response.content;

        try {
            const result = JSON.parse(jsonStr);
            return {
                success: true,
                ...result
            };
        } catch {
            // Fallback if model returned plain text
            return {
                success: true,
                rawOutput: response.content
            };
        }
    }
};

/**
 * Register Language Tools
 */
export function registerLanguageTools() {
    gituMCPHub.registerTool(translateTextTool);
    gituMCPHub.registerTool(detectLanguageTool);
    console.log('[LanguageMCPTools] Registered translate_text and detect_language tools');
}
