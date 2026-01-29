/**
 * WhatsApp Health Monitor
 * Monitors the health of the WhatsApp connection and handles auto-reconnection and notifications.
 * 
 * Requirements: Task 2.1.3
 */

import { whatsappAdapter } from '../adapters/whatsappAdapter.js';
import { notificationService } from './notificationService.js';
import { telegramAdapter } from '../adapters/telegramAdapter.js';
import pino from 'pino';
import pool from '../config/database.js';

class WhatsAppHealthMonitor {
    private logger = pino({ level: 'info' });
    private checkInterval: NodeJS.Timeout | null = null;
    private failureCount = 0;
    private readonly MAX_FAILURES = 3;
    private readonly CHECK_INTERVAL_MS = 60000; // 1 minute

    /**
     * Start the health monitor.
     */
    start(): void {
        if (this.checkInterval) {
            this.logger.info('WhatsApp Health Monitor already running');
            return;
        }

        this.logger.info('Starting WhatsApp Health Monitor...');
        this.checkInterval = setInterval(() => this.checkHealth(), this.CHECK_INTERVAL_MS);
    }

    async checkNow(): Promise<void> {
        const state = whatsappAdapter.getConnectionState();
        this.logger.info(`WhatsApp Connection State: ${state}`);

        if (state === 'disconnected') {
            this.failureCount++;
            this.logger.warn(`WhatsApp disconnected. Failure count: ${this.failureCount}`);

            if (this.failureCount <= this.MAX_FAILURES) {
                try {
                    this.logger.info('Attempting to reconnect WhatsApp...');
                    await whatsappAdapter.reconnect();
                } catch (error) {
                    this.logger.error({ err: error }, 'Reconnect attempt failed');
                }
            } else {
                this.logger.error('Max WhatsApp connection failures reached.');
                await this.handleOutage();
            }
        } else {
            if (this.failureCount > 0) {
                this.logger.info('WhatsApp connection recovered.');
                this.failureCount = 0;
            }
        }
    }

    /**
     * Stop the health monitor.
     */
    stop(): void {
        if (this.checkInterval) {
            clearInterval(this.checkInterval);
            this.checkInterval = null;
            this.logger.info('Stopped WhatsApp Health Monitor');
        }
    }

    /**
     * Check connection health.
     */
    private async checkHealth(): Promise<void> {
        const state = whatsappAdapter.getConnectionState();
        this.logger.info(`WhatsApp Connection State: ${state}`);

        if (state === 'disconnected') {
            this.failureCount++;
            this.logger.warn(`WhatsApp disconnected. Failure count: ${this.failureCount}`);

            if (this.failureCount <= this.MAX_FAILURES) {
                // Try to reconnect
                try {
                    this.logger.info('Attempting to reconnect WhatsApp...');
                    await whatsappAdapter.reconnect();
                    // If reconnect doesn't throw, we assume it's attempting. 
                    // The next check will confirm if it succeeded.
                } catch (error) {
                    this.logger.error({ err: error }, 'Reconnect attempt failed');
                }
            } else {
                // Max failures reached
                this.logger.error('Max WhatsApp connection failures reached.');
                await this.handleOutage();
            }
        } else {
            // Reset failure count if connected
            if (this.failureCount > 0) {
                this.logger.info('WhatsApp connection recovered.');
                this.failureCount = 0;
            }
        }
    }

    /**
     * Handle extended outage.
     * Notify users or admins via Telegram/App notifications.
     */
    private async handleOutage(): Promise<void> {
        if (this.failureCount % 10 !== 0 && this.failureCount !== this.MAX_FAILURES + 1) {
            return; 
        }
        try {
            await notificationService.sendBroadcastNotification(
                'WhatsApp Integration Outage',
                'WhatsApp is disconnected and auto-reconnect failed.',
                '/settings/integrations',
                { service: 'whatsapp', severity: 'warning' }
            );
        } catch (error) {
            this.logger.error({ err: error }, 'Failed to send outage notification');
        }
    }
}

export const whatsappHealthMonitor = new WhatsAppHealthMonitor();
export default whatsappHealthMonitor;
