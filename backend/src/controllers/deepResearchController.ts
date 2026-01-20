import type { Request, Response } from 'express';
import axios from 'axios';
import pool from '../config/database.js';

interface DeepResearchRequest {
    query: string;
    notebookId?: string;
    maxResults?: number;
    includeImages?: boolean;
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
export const performDeepResearch = async (req: Request, res: Response) => {
    const { query, notebookId, maxResults = 10, includeImages = true } = req.body as DeepResearchRequest;
    const userId = (req as any).user?.userId;

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

        const summary = await generateResearchSummary(query, extractedContent);

        // Step 4: Extract key insights
        const insights = await extractKeyInsights(summary, extractedContent);

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
export const getResearchHistory = async (req: Request, res: Response) => {
    try {
        const userId = (req as any).user?.userId;
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
export const getResearchSession = async (req: Request, res: Response) => {
    try {
        const userId = (req as any).user?.userId;
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
async function generateResearchSummary(query: string, sources: any[]): Promise<string> {
    const combinedContent = sources
        .map(s => `Source: ${s.title}\n${s.content}`)
        .join('\n\n---\n\n');

    const prompt = `As a research assistant, create a comprehensive summary based on the following sources about "${query}":

${combinedContent.substring(0, 15000)}

Provide a well-structured summary that:
1. Answers the research question
2. Synthesizes information from multiple sources
3. Highlights key findings
4. Is clear and concise`;

    // This would call your AI service - for now return a placeholder
    // You can integrate with Gemini/OpenRouter here
    return `Research summary for: ${query}\n\nBased on ${sources.length} sources, here are the key findings...\n\n[AI-generated summary would go here]`;
}

/**
 * Extract key insights from research
 */
async function extractKeyInsights(summary: string, sources: any[]): Promise<string[]> {
    // This would use AI to extract insights
    // For now, return example insights
    return [
        'Key insight 1 from the research',
        'Key insight 2 from the research',
        'Key insight 3 from the research'
    ];
}
