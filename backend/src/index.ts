import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import { createServer } from 'http';

// Import all routes
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
import voiceRoutes from './routes/voice.js';
import sportsRoutes from './routes/sports.js';
import codingAgentRoutes from './routes/codingAgent.js';
import mcpDownloadRoutes from './routes/mcpDownload.js';
import githubRoutes from './routes/github.js';
import planningRoutes from './routes/planning.js';

// Import services
import bunnyService from './services/bunnyService.js';
import codeVerificationService from './services/codeVerificationService.js';
import codeAnalysisService from './services/codeAnalysisService.js';
import { agentWebSocketService } from './services/agentWebSocketService.js';
import { planningWebSocketService } from './services/planningWebSocketService.js';

// Load environment variables
dotenv.config();

// Initialize services
bunnyService.initialize();
codeVerificationService.initialize();
codeAnalysisService.initialize();

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors({
    origin: true, // Allow all origins (reflects the request origin)
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
    credentials: true,
}));

// Handle preflight requests explicitly
app.options('*', cors());

app.use(express.json({ limit: '100mb' }));
app.use(express.urlencoded({ extended: true, limit: '100mb' }));



// Request logging middleware
app.use((req, res, next) => {
    console.log(`[${new Date().toISOString()}] ${req.method} ${req.path}`);
    next();
});

// Health check
app.get('/health', (req, res) => {
    res.json({
        status: 'ok',
        message: 'Backend is running',
        timestamp: new Date().toISOString(),
        version: '2.0.0'
    });
});

// API Routes
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
app.use('/api/voice', voiceRoutes);
app.use('/api/sports', sportsRoutes);
app.use('/api/coding-agent', codingAgentRoutes);
app.use('/api/mcp', mcpDownloadRoutes);
app.use('/api/github', githubRoutes);
app.use('/api/planning', planningRoutes);

// 404 handler
app.use((req, res) => {
    console.log(`[404] Route not found: ${req.method} ${req.path}`);
    res.status(404).json({ error: 'Route not found', path: req.path });
});

// Error handler
app.use((err: any, req: express.Request, res: express.Response, next: express.NextFunction) => {
    console.error('Error:', err);
    res.status(500).json({
        error: 'Internal server error',
        message: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
});

// Start server with WebSocket support
const server = createServer(app);

// Initialize WebSocket service for real-time agent communication
agentWebSocketService.initialize(server);

// Initialize WebSocket service for real-time planning updates
planningWebSocketService.initialize(server);

server.listen(PORT, () => {
    console.log(`🚀 Server is running on http://localhost:${PORT}`);
    console.log(`🔌 WebSocket available at ws://localhost:${PORT}/ws/agent`);
    console.log(`📋 Planning WebSocket available at ws://localhost:${PORT}/ws/planning`);
    console.log(`📊 Environment: ${process.env.NODE_ENV || 'development'}`);
    console.log(`📅 Started at: ${new Date().toISOString()}`);
});

export default app;
