import type { Response } from 'express';
import axios from 'axios';
import pool from '../config/database.js';
import { generateResponse, ChatMessage } from '../services/aiService.js';
import type { AuthRequest } from '../middleware/auth.js';

interface DeepResearchRequest {
    query: string;
    notebookId?: string;
    maxResults?: number;
    includeImages?: boolean;
    provider?: 'gemini' | 'openrouter';
    model?: string;
}

interface ResearchStep {
    step: number;
    type: 'search' | 'analyze' | 'summarize' | 'complete';
    message: string;
    data?: any;
    timestamp: string;
}

/**
 * Deep Research Service - Backend powered
 * Performs multi-step autonomous research with streaming updates
 */
export const performDeepResearch = async (req: AuthRequest, res: Response) => {
    const { query, notebookId, maxResults = 10, includeImages = true, provider = 'gemini', model } = req.body as DeepResearchRequest;
    const userId = req.userId;

    if (!userId) {
        return res.status(401).json({ success: false, error: 'Unauthorized' });
    }

    if (!query) {
        return res.status(400).json({ success: false, error: 'Query is required' });
    }

    // Set up SSE (Server-Sent Events) for streaming
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');
    res.flushHeaders();

    const sendStep = (step: ResearchStep) => {
        res.write(`data: ${JSON.stringify(step)}\n\n`);
    };

    try {
        // Create research session in database
        const sessionResult = await pool.query(
            `INSERT INTO research_sessions (user_id, notebook_id, query, status, created_at)
       VALUES ($1, $2, $3, 'in_progress', NOW())
       RETURNING id`,
            [userId, notebookId || null, query]
        );
        const sessionId = sessionResult.rows[0].id;

        sendStep({
            step: 1,
            type: 'search',
            message: 'Starting deep research...',
            data: { sessionId },
            timestamp: new Date().toISOString()
        });

        // Step 1: Initial web search
        sendStep({
            step: 2,
            type: 'search',
            message: 'Searching the web for relevant information...',
            timestamp: new Date().toISOString()
        });

        const searchResults = await performWebSearch(query, maxResults);

        sendStep({
            step: 3,
            type: 'search',
            message: `Found ${searchResults.length} relevant sources`,
            data: { resultCount: searchResults.length },
            timestamp: new Date().toISOString()
        });

        // Step 2: Extract content from top results
        sendStep({
            step: 4,
            type: 'analyze',
            message: 'Extracting content from sources...',
            timestamp: new Date().toISOString()
        });

        const extractedContent = await extractContentFromResults(searchResults.slice(0, 5));

        // Save sources to database
        for (const content of extractedContent) {
            await pool.query(
                `INSERT INTO research_sources (session_id, url, title, content, created_at)
         VALUES ($1, $2, $3, $4, NOW())`,
                [sessionId, content.url, content.title, content.content]
            );
        }

        sendStep({
            step: 5,
            type: 'analyze',
            message: 'Analyzing extracted content...',
            data: { sourcesExtracted: extractedContent.length },
            timestamp: new Date().toISOString()
        });

        // Step 3: Generate comprehensive summary
        sendStep({
            step: 6,
            type: 'summarize',
            message: 'Generating comprehensive research summary...',
            timestamp: new Date().toISOString()
        });

        const summary = await generateResearchSummary(query, extractedContent, provider, model);

        // Step 4: Extract key insights
        const insights = await extractKeyInsights(summary, extractedContent, provider, model);

        // Update session with results
        await pool.query(
            `UPDATE research_sessions 
       SET status = 'completed', 
           summary = $1, 
           insights = $2,
           source_count = $3,
           completed_at = NOW()
       WHERE id = $4`,
            [summary, JSON.stringify(insights), extractedContent.length, sessionId]
        );

        sendStep({
            step: 7,
            type: 'complete',
            message: 'Research complete!',
            data: {
                sessionId,
                summary,
                insights,
                sources: extractedContent.map(c => ({
                    title: c.title,
                    url: c.url,
                    snippet: c.content.substring(0, 200) + '...'
                })),
                totalSources: extractedContent.length
            },
            timestamp: new Date().toISOString()
        });

        res.write('data: [DONE]\n\n');
        res.end();

    } catch (error: any) {
        console.error('Deep research error:', error);

        sendStep({
            step: -1,
            type: 'search',
            message: `Error: ${error.message}`,
            timestamp: new Date().toISOString()
        });

        res.write('data: [ERROR]\n\n');
        res.end();
    }
};

/**
 * Get research history for user
 */
export const getResearchHistory = async (req: AuthRequest, res: Response) => {
    try {
        const userId = req.userId;
        const { notebookId, limit = 50, offset = 0 } = req.query;

        if (!userId) {
            return res.status(401).json({ success: false, error: 'Unauthorized' });
        }

        let query = `
      SELECT 
        id, query, status, summary, insights, source_count,
        created_at, completed_at
      FROM research_sessions
      WHERE user_id = $1
    `;

        const params: any[] = [userId];

        if (notebookId) {
            query += ` AND notebook_id = $2`;
            params.push(notebookId);
        }

        query += ` ORDER BY created_at DESC LIMIT $${params.length + 1} OFFSET $${params.length + 2}`;
        params.push(limit, offset);

        const result = await pool.query(query, params);

        return res.json({
            success: true,
            sessions: result.rows
        });

    } catch (error: any) {
        console.error('Get research history error:', error);
        return res.status(500).json({ success: false, error: error.message });
    }
};

/**
 * Get specific research session details
 */
export const getResearchSession = async (req: AuthRequest, res: Response) => {
    try {
        const userId = req.userId;
        const { sessionId } = req.params;

        if (!userId) {
            return res.status(401).json({ success: false, error: 'Unauthorized' });
        }

        // Get session
        const sessionResult = await pool.query(
            `SELECT * FROM research_sessions WHERE id = $1 AND user_id = $2`,
            [sessionId, userId]
        );

        if (sessionResult.rows.length === 0) {
            return res.status(404).json({ success: false, error: 'Session not found' });
        }

        // Get sources
        const sourcesResult = await pool.query(
            `SELECT url, title, content, created_at FROM research_sources WHERE session_id = $1`,
            [sessionId]
        );

        return res.json({
            success: true,
            session: sessionResult.rows[0],
            sources: sourcesResult.rows
        });

    } catch (error: any) {
        console.error('Get research session error:', error);
        return res.status(500).json({ success: false, error: error.message });
    }
};

/**
 * Perform web search using Serper API
 */
async function performWebSearch(query: string, maxResults: number): Promise<any[]> {
    try {
        const response = await axios.post(
            'https://google.serper.dev/search',
            {
                q: query,
                num: maxResults
            },
            {
                headers: {
                    'X-API-KEY': process.env.SERPER_API_KEY || '',
                    'Content-Type': 'application/json'
                }
            }
        );

        return response.data.organic || [];
    } catch (error) {
        console.error('Web search failed:', error);
        return [];
    }
}

/**
 * Extract content from search results
 */
async function extractContentFromResults(results: any[]): Promise<any[]> {
    const extracted: Array<{
        url: string;
        title: string;
        content: string;
        snippet: string;
    }> = [];

    for (const result of results) {
        try {
            // Use our own web content extraction
            const response = await axios.post(
                `http://localhost:${process.env.PORT || 3000}/api/content/extract-web`,
                { url: result.link },
                {
                    headers: {
                        'Authorization': `Bearer ${process.env.INTERNAL_API_KEY || 'internal'}`,
                        'Content-Type': 'application/json'
                    },
                    timeout: 15000
                }
            );

            if (response.data.success) {
                extracted.push({
                    url: result.link,
                    title: response.data.metadata?.title || result.title,
                    content: response.data.content,
                    snippet: result.snippet
                });
            }
        } catch (error) {
            console.warn(`Failed to extract content from ${result.link}:`, error);
            // Fallback to snippet
            extracted.push({
                url: result.link,
                title: result.title,
                content: result.snippet,
                snippet: result.snippet
            });
        }
    }

    return extracted;
}

/**
 * Generate research summary using AI
 */
async function generateResearchSummary(
    query: string,
    sources: any[],
    provider: 'gemini' | 'openrouter' = 'gemini',
    model?: string
): Promise<string> {
    const combinedContent = sources
        .map(s => `Source: ${s.title}\n${s.content}`)
        .join('\n\n---\n\n');

    const messages: ChatMessage[] = [
        {
            role: 'system',
            content: `You are an advanced research assistant. You have been tasked with answering a user query based on valid search results.
            
            Your goal is to synthesize the information from the provided sources into a comprehensive, coherent, and well-structured report.
            
            Guidelines:
            1. Focus on answering the user's specific query.
            2. Synthesize information from multiple sources; do not just list them.
            3. Highlight key findings, statistics, and expert opinions.
            4. Be objective and factual.
            5. Structure the report with clear headings and bullet points where appropriate.
            6. Use Markdown formatting.`
        },
        {
            role: 'user',
            content: `Research Query: "${query}"
            
            Sources:
            ${combinedContent.substring(0, 50000)}`
        }
    ];

    try {
        return await generateResponse(messages, provider, model);
    } catch (error) {
        console.error('Research summary generation failed:', error);
        return `Failed to generate AI summary. Found ${sources.length} sources but AI generation error occurred.`;
    }
}

/**
 * Extract key insights from research result
 */
async function extractKeyInsights(
    summary: string,
    sources: any[],
    provider: 'gemini' | 'openrouter' = 'gemini',
    model?: string
): Promise<string[]> {
    const messages: ChatMessage[] = [
        {
            role: 'system',
            content: 'You are an expert analyst. Extract the top 3-5 most important insights or takeaways from the provided research summary.'
        },
        {
            role: 'user',
            content: `Summary:
            ${summary.substring(0, 30000)}
            
            Extract 3-5 key insights as a simple JSON string array (e.g. ["insight 1", "insight 2"]). do not use markdown formatting for the json.`
        }
    ];

    try {
        const response = await generateResponse(messages, provider, model);
        // Attempt to parse JSON
        const match = response.match(/\[[\s\S]*\]/);
        if (match) {
            return JSON.parse(match[0]);
        }
        // Fallback: split by newlines if array parse fails
        return response.split('\n').filter(line => line.trim().startsWith('-') || line.trim().startsWith('*')).map(l => l.replace(/^[-*]\s*/, ''));
    } catch (error) {
        console.warn('Insight extraction failed:', error);
        return ['Analysis completed', 'Sources reviewed', 'Summary generated'];
    }
}
