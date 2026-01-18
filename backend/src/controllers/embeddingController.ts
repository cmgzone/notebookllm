import type { Request, Response } from 'express';
import { GoogleGenerativeAI } from '@google/generative-ai';
import pool from '../config/database.js';

// Initialize Gemini API
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY || '');
const embeddingModel = genAI.getGenerativeModel({ model: 'text-embedding-004' });

interface GenerateEmbeddingRequest {
    text: string;
}

interface SearchRequest {
    query: string;
    notebookId?: string;
    limit?: number;
    threshold?: number;
}

/**
 * Generate embedding for a text string using Gemini
 */
export const generateEmbedding = async (req: Request, res: Response) => {
    try {
        const { text } = req.body as GenerateEmbeddingRequest;

        if (!text) {
            return res.status(400).json({ success: false, error: 'Text is required' });
        }

        const result = await embeddingModel.embedContent(text);
        const embedding = result.embedding.values;

        return res.json({
            success: true,
            embedding
        });

    } catch (error: any) {
        console.error('Embedding generation error:', error);
        return res.status(500).json({ success: false, error: error.message });
    }
};

/**
 * Semantic search using vector embeddings
 */
export const searchEmbeddings = async (req: Request, res: Response) => {
    try {
        const { query, notebookId, limit = 10, threshold = 0.5 } = req.body as SearchRequest;
        const userId = (req as any).user?.userId;

        if (!query) {
            return res.status(400).json({ success: false, error: 'Query is required' });
        }

        // 1. Generate embedding for the query
        const result = await embeddingModel.embedContent(query);
        const queryEmbedding = result.embedding.values;

        // Format embedding for SQL (pgvector format: [1,2,3])
        const embeddingString = `[${queryEmbedding.join(',')}]`;

        // 2. Perform vector similarity search
        // We join with sources and notebooks to enforce permissions
        let sqlQuery = `
      SELECT 
        c.id, c.content, c.metadata, c.source_id,
        s.title as source_title, s.type as source_type,
        1 - (c.embedding <=> $1) as similarity
      FROM chunks c
      JOIN sources s ON c.source_id = s.id
      JOIN notebooks n ON s.notebook_id = n.id
      WHERE n.user_id = $2
    `;

        const params: any[] = [embeddingString, userId];

        if (notebookId) {
            sqlQuery += ` AND n.id = $3`;
            params.push(notebookId);
        }

        sqlQuery += ` AND 1 - (c.embedding <=> $1) > ${threshold}`;
        sqlQuery += ` ORDER BY similarity DESC LIMIT ${limit}`;

        const searchResult = await pool.query(sqlQuery, params);

        return res.json({
            success: true,
            results: searchResult.rows
        });

    } catch (error: any) {
        console.error('Vector search error:', error);
        return res.status(500).json({ success: false, error: error.message });
    }
};

/**
 * Store embeddings for chunks (Internal/Batch usage)
 */
export const storeEmbeddings = async (req: Request, res: Response) => {
    const client = await pool.connect();
    try {
        const { chunks } = req.body; // Expects [{ sourceId, content, metadata }]

        if (!Array.isArray(chunks)) {
            return res.status(400).json({ success: false, error: 'Chunks array required' });
        }

        await client.query('BEGIN');

        const results: any[] = [];

        // Process in batches
        for (const chunk of chunks) {
            // Generate embedding
            try {
                const result = await embeddingModel.embedContent(chunk.content);
                const embedding = result.embedding.values;
                const embeddingString = `[${embedding.join(',')}]`;

                const insertResult = await client.query(
                    `INSERT INTO chunks (source_id, content, metadata, embedding)
           VALUES ($1, $2, $3, $4)
           RETURNING id`,
                    [chunk.sourceId, chunk.content, chunk.metadata || {}, embeddingString]
                );

                results.push(insertResult.rows[0].id);
            } catch (e) {
                console.warn('Failed to embed chunk:', e);
            }
        }

        await client.query('COMMIT');

        return res.json({
            success: true,
            count: results.length,
            chunkIds: results
        });

    } catch (error: any) {
        await client.query('ROLLBACK');
        console.error('Store embeddings error:', error);
        return res.status(500).json({ success: false, error: error.message });
    } finally {
        client.release();
    }
};
