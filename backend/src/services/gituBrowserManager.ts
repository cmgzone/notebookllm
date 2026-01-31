import { chromium, Browser, Page, BrowserContext } from 'playwright';
import path from 'path';
import fs from 'fs';

/**
 * Gitu Browser Manager
 * Manages headless browser sessions for the AI agent.
 */
class GituBrowserManager {
    private browser: Browser | null = null;
    private userSessions: Map<string, { context: BrowserContext; page: Page; lastActive: number }> = new Map();
    private CLEANUP_INTERVAL = 5 * 60 * 1000; // 5 minutes

    constructor() {
        // Periodic cleanup of idle sessions
        setInterval(() => this.cleanupIdleSessions(), this.CLEANUP_INTERVAL);
    }

    /**
     * Get or launch the browser instance
     */
    private async getBrowser(): Promise<Browser> {
        if (!this.browser) {
            console.log('[BrowserManager] Launching Chromium...');
            this.browser = await chromium.launch({
                headless: true, // Visible for debugging? No, usually headless for server.
                args: ['--no-sandbox', '--disable-setuid-sandbox']
            });
        }
        return this.browser;
    }

    /**
     * Get existing page or create new session for user
     */
    async getPage(userId: string): Promise<Page> {
        const session = this.userSessions.get(userId);
        if (session) {
            // Validate if page is still open
            if (!session.page.isClosed()) {
                session.lastActive = Date.now();
                return session.page;
            }
        }

        // Create new session
        const browser = await this.getBrowser();
        const context = await browser.newContext({
            viewport: { width: 1280, height: 720 },
            userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36 GituAI/1.0'
        });
        const page = await context.newPage();

        // Store session
        this.userSessions.set(userId, { context, page, lastActive: Date.now() });

        return page;
    }

    /**
     * Close a user's session
     */
    async closeSession(userId: string) {
        const session = this.userSessions.get(userId);
        if (session) {
            await session.context.close();
            this.userSessions.delete(userId);
        }
    }

    /**
     * Cleanup sessions inactive for > 15 minutes
     */
    private async cleanupIdleSessions() {
        const now = Date.now();
        const IDLE_TIMEOUT = 15 * 60 * 1000;

        for (const [userId, session] of this.userSessions.entries()) {
            if (now - session.lastActive > IDLE_TIMEOUT) {
                console.log(`[BrowserManager] Closing idle session for ${userId}`);
                await session.context.close().catch(() => { });
                this.userSessions.delete(userId);
            }
        }

        // Close browser if no sessions left
        if (this.userSessions.size === 0 && this.browser) {
            // await this.browser.close(); 
            // Keep browser warm for now, or close? frequent restarts are heavy.
            // Let's keep it open unless explicit shutdown.
        }
    }
}

export const gituBrowserManager = new GituBrowserManager();
