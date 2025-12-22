import express, { type Response } from 'express';
import axios from 'axios';
import { authenticateToken, type AuthRequest } from '../middleware/auth.js';

const router = express.Router();
router.use(authenticateToken);

// Search proxy for Serper API
router.post('/proxy', async (req: AuthRequest, res: Response) => {
    try {
        const { query, type = 'search', num = 10, page = 1 } = req.body;

        if (!query) {
            return res.status(400).json({ error: 'Query is required' });
        }

        const apiKey = process.env.SERPER_API_KEY;
        if (!apiKey) {
            return res.status(500).json({ error: 'Search service not configured on server' });
        }

        const response = await axios.post(
            `https://google.serper.dev/${type}`,
            {
                q: query,
                num,
                page
            },
            {
                headers: {
                    'X-API-KEY': apiKey,
                    'Content-Type': 'application/json'
                },
                timeout: 30000
            }
        );

        res.json(response.data);
    } catch (error: any) {
        console.error('Search proxy error:', error.response?.data || error.message);
        res.status(error.response?.status || 500).json({
            error: 'Failed to perform search',
            details: error.response?.data || error.message
        });
    }
});

// News search
router.post('/news', async (req: AuthRequest, res: Response) => {
    try {
        const { query, num = 10 } = req.body;

        const apiKey = process.env.SERPER_API_KEY;
        if (!apiKey) {
            return res.status(500).json({ error: 'Search service not configured' });
        }

        const response = await axios.post(
            'https://google.serper.dev/news',
            { q: query, num },
            {
                headers: {
                    'X-API-KEY': apiKey,
                    'Content-Type': 'application/json'
                }
            }
        );

        res.json(response.data);
    } catch (error: any) {
        console.error('News search error:', error.response?.data || error.message);
        res.status(500).json({ error: 'Failed to search news' });
    }
});

// Image search
router.post('/images', async (req: AuthRequest, res: Response) => {
    try {
        const { query, num = 10 } = req.body;

        const apiKey = process.env.SERPER_API_KEY;
        if (!apiKey) {
            return res.status(500).json({ error: 'Search service not configured' });
        }

        const response = await axios.post(
            'https://google.serper.dev/images',
            { q: query, num },
            {
                headers: {
                    'X-API-KEY': apiKey,
                    'Content-Type': 'application/json'
                }
            }
        );

        res.json(response.data);
    } catch (error: any) {
        console.error('Image search error:', error.response?.data || error.message);
        res.status(500).json({ error: 'Failed to search images' });
    }
});

export default router;
