import { GoogleGenerativeAI } from '@google/generative-ai';
import axios from 'axios';
import dotenv from 'dotenv';

dotenv.config();

// Initialize Gemini
const genAI = process.env.GEMINI_API_KEY
    ? new GoogleGenerativeAI(process.env.GEMINI_API_KEY)
    : null;

export interface ChatMessage {
    role: 'user' | 'assistant' | 'system';
    content: string;
}

/**
 * Generate AI response using Gemini
 */
export async function generateWithGemini(
    messages: ChatMessage[],
    model: string = 'gemini-1.5-flash'
): Promise<string> {
    if (!genAI) {
        throw new Error('Gemini API key not configured');
    }

    try {
        const geminiModel = genAI.getGenerativeModel({ model });

        // Convert messages to Gemini format
        const prompt = messages
            .map(msg => `${msg.role}: ${msg.content}`)
            .join('\n\n');

        const result = await geminiModel.generateContent(prompt);
        const response = result.response;
        return response.text();
    } catch (error: any) {
        console.error('Gemini error:', error);
        throw new Error(`Gemini API error: ${error.message}`);
    }
}

/**
 * Generate AI response using OpenRouter
 */
export async function generateWithOpenRouter(
    messages: ChatMessage[],
    model: string = 'meta-llama/llama-3.3-70b-instruct'
): Promise<string> {
    const apiKey = process.env.OPENROUTER_API_KEY;

    if (!apiKey) {
        throw new Error('OpenRouter API key not configured');
    }

    try {
        const response = await axios.post(
            'https://openrouter.ai/api/v1/chat/completions',
            {
                model,
                messages: messages.map(msg => ({
                    role: msg.role,
                    content: msg.content
                }))
            },
            {
                headers: {
                    'Authorization': `Bearer ${apiKey}`,
                    'Content-Type': 'application/json',
                    'HTTP-Referer': 'https://notebookllm.app',
                    'X-Title': 'Notebook LLM'
                }
            }
        );

        return response.data.choices[0].message.content;
    } catch (error: any) {
        console.error('OpenRouter error:', error.response?.data || error);
        throw new Error(`OpenRouter API error: ${error.response?.data?.error?.message || error.message}`);
    }
}

/**
 * Generate embeddings using OpenAI-compatible endpoint
 */
export async function generateEmbeddings(text: string): Promise<number[]> {
    const apiKey = process.env.OPENROUTER_API_KEY;

    if (!apiKey) {
        throw new Error('OpenRouter API key not configured');
    }

    try {
        const response = await axios.post(
            'https://openrouter.ai/api/v1/embeddings',
            {
                model: 'text-embedding-ada-002',
                input: text
            },
            {
                headers: {
                    'Authorization': `Bearer ${apiKey}`,
                    'Content-Type': 'application/json'
                }
            }
        );

        return response.data.data[0].embedding;
    } catch (error: any) {
        console.error('Embeddings error:', error.response?.data || error);
        throw new Error(`Embeddings API error: ${error.response?.data?.error?.message || error.message}`);
    }
}

/**
 * Generate content summary using AI
 */
export async function generateSummary(content: string, provider: 'gemini' | 'openrouter' = 'gemini'): Promise<string> {
    const messages: ChatMessage[] = [
        {
            role: 'system',
            content: 'You are a helpful assistant that creates concise summaries of content.'
        },
        {
            role: 'user',
            content: `Please create a concise summary of the following content:\n\n${content}`
        }
    ];

    if (provider === 'gemini') {
        return generateWithGemini(messages);
    } else {
        return generateWithOpenRouter(messages);
    }
}

/**
 * Generate question suggestions based on content
 */
export async function generateQuestions(content: string, count: number = 5): Promise<string[]> {
    const messages: ChatMessage[] = [
        {
            role: 'system',
            content: 'You are a helpful assistant that generates relevant questions about content.'
        },
        {
            role: 'user',
            content: `Generate ${count} insightful questions that could be asked about the following content. Return only the questions, one per line:\n\n${content}`
        }
    ];

    const response = await generateWithGemini(messages);
    return response.split('\n').filter(q => q.trim().length > 0).slice(0, count);
}
