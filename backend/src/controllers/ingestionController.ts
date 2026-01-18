import type { Request, Response } from 'express';
import pool from '../config/database.js';
import axios from 'axios';

interface IngestionRequest {
    sourceId: string;
}

/**
 * Process a source for RAG ingestion
 * This splits the content into chunks, generates embeddings, and stores them.
 */
export const processSource = async (req: Request, res: Response) => {
    try {
        const { sourceId } = req.body as IngestionRequest;

        if (!sourceId) {
            return res.status(400).json({ success: false, error: 'Source ID is required' });
        }

        // 1. Fetch source content
        const sourceResult = await pool.query(
            `SELECT title, content, type FROM sources WHERE id = $1`,
            [sourceId]
        );

        if (sourceResult.rows.length === 0) {
            return res.status(404).json({ success: false, error: 'Source not found' });
        }

        const source = sourceResult.rows[0];

        // 2. Chunk content (Simple recursive character text splitter logic)
        const chunks = splitText(source.content, 1000, 100); // 1000 chars, 100 overlap

        // 3. Call embedding service to store chunks
        // We call our own internal embedding controller logic or endpoint
        // Since we are inside the backend, we can just import the logic or call the endpoint
        // calling localhost endpoint is safer for decoupling

        const response = await axios.post(
            `http://localhost:${process.env.PORT || 3000}/api/embeddings/store`,
            {
                chunks: chunks.map(text => ({
                    sourceId,
                    content: text,
                    metadata: { title: source.title, type: source.type }
                }))
            },
            {
                headers: {
                    'Authorization': req.headers.authorization, // Pass through auth
                    'Content-Type': 'application/json'
                }
            }
        );

        return res.json({
            success: true,
            chunksProcessed: chunks.length,
            chunksStored: response.data.count
        });

    } catch (error: any) {
        console.error('Ingestion error:', error);
        return res.status(500).json({ success: false, error: error.message });
    }
};

/**
 * Split text into chunks with overlap
 */
function splitText(text: string, chunkSize: number = 1000, overlap: number = 100): string[] {
    if (!text) return [];

    const chunks: string[] = [];
    let start = 0;

    while (start < text.length) {
        let end = start + chunkSize;

        // If not at the end, try to break at a newline or space
        if (end < text.length) {
            // Look for last newline in the chunk
            let breakPoint = text.lastIndexOf('\n', end);
            if (breakPoint === -1 || breakPoint < start) {
                // Look for last space
                breakPoint = text.lastIndexOf(' ', end);
            }

            if (breakPoint !== -1 && breakPoint > start) {
                end = breakPoint;
            }
        } else {
            end = text.length;
        }

        chunks.push(text.substring(start, end).trim());

        // Move start pointer for overlap
        start = end > text.length ? text.length : end - overlap;
        // Prevent infinite loop if overlap >= chunksize (shouldn't happen with defaults)
        if (start >= end) start = end;
    }

    return chunks.filter(c => c.length > 0);
}
