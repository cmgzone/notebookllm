import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import authRoutes from './routes/auth.js';
import notebooksRoutes from './routes/notebooks.js';
import sourcesRoutes from './routes/sources.js';
import chunksRoutes from './routes/chunks.js';
import tagsRoutes from './routes/tags.js';
import aiRoutes from './routes/ai.js';
import subscriptionsRoutes from './routes/subscriptions.js';
import adminRoutes from './routes/admin.js';
import analyticsRoutes from './routes/analytics.js';
import mediaRoutes from './routes/media.js';
import sharingRoutes from './routes/sharing.js';
import recommendationsRoutes from './routes/recommendations.js';
import gamificationRoutes from './routes/gamification.js';
import studyRoutes from './routes/study.js';
import ebookRoutes from './routes/ebooks.js';
import researchRoutes from './routes/research.js';
import searchRoutes from './routes/search.js';
import featuresRoutes from './routes/features.js';

// Load environment variables
dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

// Health check
app.get('/health', (req, res) => {
    res.json({ status: 'ok', message: 'Backend is running' });
});

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/notebooks', notebooksRoutes);
app.use('/api/sources', sourcesRoutes);
app.use('/api/chunks', chunksRoutes);
app.use('/api/tags', tagsRoutes);
app.use('/api/ai', aiRoutes);
app.use('/api/subscriptions', subscriptionsRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/analytics', analyticsRoutes);
app.use('/api/media', mediaRoutes);
app.use('/api/sharing', sharingRoutes);
app.use('/api/recommendations', recommendationsRoutes);
app.use('/api/gamification', gamificationRoutes);
app.use('/api/study', studyRoutes);
app.use('/api/ebooks', ebookRoutes);
app.use('/api/research', researchRoutes);
app.use('/api/search', searchRoutes);
app.use('/api/features', featuresRoutes);

// 404 handler
app.use((req, res) => {
    res.status(404).json({ error: 'Route not found' });
});

// Error handler
app.use((err: any, req: express.Request, res: express.Response, next: express.NextFunction) => {
    console.error('Error:', err);
    res.status(500).json({ error: 'Internal server error' });
});

// Start server
app.listen(PORT, () => {
    console.log(`🚀 Server is running on http://localhost:${PORT}`);
    console.log(`📊 Environment: ${process.env.NODE_ENV || 'development'}`);
});

export default app;
