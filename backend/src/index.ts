import express from 'express';
import cors from 'cors';
import compression from 'compression';
import dotenv from 'dotenv';
import { createServer } from 'http';
import { parse } from 'url';

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
import socialRoutes from './routes/social.js';
import socialSharingRoutes from './routes/socialSharing.js';
import messagingRoutes from './routes/messaging.js';
import notificationsRoutes from './routes/notifications.js';
import googleDriveRoutes from './routes/googleDrive.js';
import contentRoutes from './routes/content.js';
import deepResearchRoutes from './routes/deepResearch.js';
import ragRoutes from './routes/rag.js';
import agentSkillsRoutes from './routes/agentSkills.js';
import gituRoutes from './routes/gitu.js';
import { flutterAdapter } from './adapters/flutterAdapter.js';
import { gituWebSocketService } from './services/gituWebSocketService.js';
import { gituRemoteTerminalService } from './services/gituRemoteTerminalService.js';
import { gituShellWebSocketService } from './services/gituShellWebSocketService.js';
import { registerNotebookTools } from './services/notebookMCPTools.js';
import { registerResearchTools } from './services/researchMCPTools.js';
import { registerGmailTools } from './services/gmailMCPTools.js';
import { registerShellTools } from './services/shellMCPTools.js';
import { registerMessagingTools } from './services/messagingMCPTools.js';
import { registerGoogleDriveTools } from './services/googleDriveMCPTools.js';
import { registerShopifyTools } from './services/shopifyMCPTools.js';
import { registerLanguageTools } from './services/languageMCPTools.js';
import { registerBrowserTools } from './services/browserMCPTools.js';
import { registerPluginMCPTools } from './services/pluginMCPTools.js';
import { whatsappAdapter } from './adapters/whatsappAdapter.js';
import { whatsappHealthMonitor } from './services/whatsappHealthMonitor.js';
import { telegramAdapter } from './adapters/telegramAdapter.js';

// Import services
import bunnyService from './services/bunnyService.js';
import codeVerificationService from './services/codeVerificationService.js';
import codeAnalysisService from './services/codeAnalysisService.js';
import { agentWebSocketService } from './services/agentWebSocketService.js';
import { planningWebSocketService } from './services/planningWebSocketService.js';
import { gituQRAuthWebSocketService } from './services/gituQRAuthWebSocketService.js';
import { connectRedis, disconnectRedis } from './config/redis.js';
import { gituScheduler } from './services/gituScheduler.js';
import { ensureGituSchema } from './config/gituSchema.js';

// Load environment variables
dotenv.config();

ensureGituSchema()
    .then(() => console.log('✅ Gitu schema ensured'))
    .catch(err => console.error('❌ Failed to ensure Gitu schema:', err));

// Initialize Redis
connectRedis().catch(err => {
    console.error('Redis initialization failed:', err);
    console.log('⚠️  Continuing without Redis caching');
});

// Initialize services
bunnyService.initialize();
codeVerificationService.initialize();
codeAnalysisService.initialize();
registerNotebookTools();
registerResearchTools();
registerGmailTools();
registerShellTools();
registerMessagingTools();
registerGoogleDriveTools();
registerShopifyTools();
registerLanguageTools();
registerBrowserTools();
registerPluginMCPTools();
gituScheduler.start();

// Initialize WhatsApp
whatsappAdapter.initialize({ printQRInTerminal: false }).then(() => {
    console.log('📱 WhatsApp Adapter initialized');
    whatsappHealthMonitor.start();
}).catch(err => {
    console.error('❌ Failed to initialize WhatsApp Adapter:', err);
});

// Initialize Telegram
const telegramBotToken = process.env.TELEGRAM_BOT_TOKEN;
if (telegramBotToken && telegramBotToken.trim().length > 0) {
    telegramAdapter.initialize(telegramBotToken.trim(), { polling: true }).then(async () => {
        console.log('✈️  Telegram Adapter initialized (polling)');
        try {
            await telegramAdapter.setCommands([
                { command: 'start', description: 'Start the bot' },
                { command: 'help', description: 'Show help message' },
                { command: 'id', description: 'Show your Chat ID for linking' },
                { command: 'status', description: 'Check your Gitu status' },
                { command: 'notebooks', description: 'List your notebooks' },
                { command: 'session', description: 'View current session info' },
                { command: 'clear', description: 'Clear conversation history' },
                { command: 'settings', description: 'View your settings' },
            ]);
        } catch (err) {
            console.error('❌ Failed to set Telegram bot commands:', err);
        }
    }).catch(err => {
        console.error('❌ Failed to initialize Telegram Adapter:', err);
    });
} else {
    console.log('ℹ️  Telegram Adapter disabled (TELEGRAM_BOT_TOKEN not set)');
}

// Graceful shutdown
process.on('SIGTERM', async () => {
    console.log('SIGTERM received, shutting down gracefully...');
    gituScheduler.stop();
    whatsappHealthMonitor.stop();
    try { await telegramAdapter.disconnect(); } catch { }
    await disconnectRedis();
    process.exit(0);
});

process.on('SIGINT', async () => {
    console.log('SIGINT received, shutting down gracefully...');
    gituScheduler.stop();
    whatsappHealthMonitor.stop();
    try { await telegramAdapter.disconnect(); } catch { }
    await disconnectRedis();
    process.exit(0);
});

const app = express();
const requestedPort = (() => {
    const raw = process.env.PORT;
    if (!raw) return 3000;
    const parsed = Number(raw);
    return Number.isFinite(parsed) && parsed > 0 ? parsed : 3000;
})();
const maxPortAttempts = 20;

// Middleware
app.use(compression());
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
const healthHandler = (req: express.Request, res: express.Response) => {
    res.json({
        status: 'ok',
        message: 'Backend is running',
        timestamp: new Date().toISOString(),
        version: '2.0.0'
    });
};

app.get('/health', healthHandler);
app.get('/api/health', healthHandler);

// API Routes
app.use('/api/auth', authRoutes);
app.use('/api/notebooks', notebooksRoutes);
app.use('/api/sources', sourcesRoutes);
app.use('/api/chunks', chunksRoutes);
app.use('/api/tags', tagsRoutes);
app.use('/api/ai', aiRoutes);
app.use('/api/subscriptions', subscriptionsRoutes);
app.use('/api/rag', ragRoutes); // Moved up and given specific prefix
app.use('/api/agent-skills', agentSkillsRoutes); // Moved up
app.use('/api/admin', adminRoutes);
app.use('/api/analytics', analyticsRoutes);
app.use('/api/media', mediaRoutes);
app.use('/api/sharing', sharingRoutes);
app.use('/api/recommendations', recommendationsRoutes);
app.use('/api/gamification', gamificationRoutes);
app.use('/api/study', studyRoutes);
app.use('/api/ebooks', ebookRoutes);
app.use('/api/research/deep', deepResearchRoutes); // Specific subpath
app.use('/api/research', researchRoutes);
app.use('/api/search', searchRoutes);
app.use('/api/features', featuresRoutes);
app.use('/api/voice', voiceRoutes);
app.use('/api/sports', sportsRoutes);
app.use('/api/coding-agent', codingAgentRoutes);
app.use('/api/mcp', mcpDownloadRoutes);
app.use('/api/github', githubRoutes);
app.use('/api/planning', planningRoutes);
app.use('/api/social', socialRoutes);
app.use('/api/social-sharing', socialSharingRoutes);
app.use('/api/messaging', messagingRoutes);
app.use('/api/notifications', notificationsRoutes);
app.use('/api/google-drive', googleDriveRoutes);
app.use('/api/content', contentRoutes);
app.use('/api/gitu', gituRoutes);

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

// Initialize WebSocket service for QR code authentication
gituQRAuthWebSocketService.initialize(server);

// Initialize WebSocket service for Flutter Gitu adapter
flutterAdapter.initialize(server);

// Initialize WebSocket service for Web Gitu adapter
gituWebSocketService.initialize(server);

gituShellWebSocketService.initialize(server);
gituRemoteTerminalService.initialize(server);

let activePort = requestedPort;
let portAttempts = 0;
let isStartingServer = false;

const startListening = () => {
    if (isStartingServer || server.listening) {
        return;
    }

    isStartingServer = true;

    // Add debugging for WebSocket upgrades
    server.on('upgrade', (req, socket, head) => {
        const url = parse(req.url || '').pathname || '';
        console.log(`[WS UPGRADE] Request for ${url}`);

        // Manual routing for Flutter Gitu WebSocket
        if (url === '/ws/gitu' || url === '/ws/gitu/') {
            console.log(`[WS UPGRADE] Routing to Flutter Adapter`);
            flutterAdapter.handleUpgrade(req, socket, head);
            return;
        }

        // Manual routing for Web Gitu WebSocket
        if (url === '/ws/gitu-web' || url === '/ws/gitu-web/') {
            console.log(`[WS UPGRADE] Routing to Web Service`);
            gituWebSocketService.handleUpgrade(req, socket, head);
            return;
        }

        if (url === '/ws/remote-terminal' || url === '/ws/remote-terminal/') {
            console.log(`[WS UPGRADE] Routing to Remote Terminal Service`);
            // The service handles its own upgrade in .initialize but we can also do it here manually for consistency
            return;
        }

        if (url.startsWith('/ws/')) {
            // Let the other specialized handlers deal with it if they are still using auto-attach
            // Note: We should eventually migrate all to manual for consistency
            return;
        }

        console.log(`[WS UPGRADE] Unhandled path: ${url}`);
    });

    server.listen(activePort, () => {
        isStartingServer = false;
        console.log(`🚀 Server is running on http://localhost:${activePort}`);
        console.log(`🔌 WebSocket available at ws://localhost:${activePort}/ws/agent`);
        console.log(`📋 Planning WebSocket available at ws://localhost:${activePort}/ws/planning`);
        console.log(`🔐 Gitu QR Auth WebSocket available at ws://localhost:${activePort}/api/gitu/terminal/qr-auth`);
        console.log(`📱 Gitu Flutter WebSocket available at ws://localhost:${activePort}/ws/gitu`);
        console.log(`🌐 Gitu Web WebSocket available at ws://localhost:${activePort}/ws/gitu-web`);
        console.log(`🖥️  Shell WebSocket available at ws://localhost:${activePort}/ws/shell`);
        console.log(`📊 Environment: ${process.env.NODE_ENV || 'development'}`);
        console.log(`📅 Started at: ${new Date().toISOString()}`);
    });
};

server.on('error', (err: any) => {
    isStartingServer = false;
    if (err?.code === 'EADDRINUSE' && portAttempts < maxPortAttempts) {
        const currentPort = activePort;
        activePort = currentPort + 1;
        portAttempts += 1;
        console.error(`Port ${currentPort} is already in use. Trying ${activePort}...`);
        setTimeout(() => startListening(), 250);
        return;
    }

    console.error('Server failed to start:', err);
    process.exit(1);
});

startListening();

export default app;
