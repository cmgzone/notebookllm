/**
 * Unit tests for Gitu Message Gateway
 * Tests message normalization, platform detection, and routing
 */

import { describe, it, expect, beforeEach, jest } from '@jest/globals';
import { gituMessageGateway } from '../services/gituMessageGateway.js';
import type { RawMessage, IncomingMessage, Platform } from '../services/gituMessageGateway.js';
import pool from '../config/database.js';

// Mock the database
const mockQuery: any = jest.fn();
(pool as any).query = mockQuery;

describe('GituMessageGateway', () => {
  beforeEach(() => {
    mockQuery.mockClear();
  });

  describe('normalizeMessage', () => {
    it('should normalize a Flutter app message', async () => {
      // Mock database queries
      mockQuery
        .mockResolvedValueOnce({ rows: [{ user_id: 'user-123' }] } as any) // resolveUserId
        .mockResolvedValueOnce({ rows: [] } as any); // storeMessage

      const rawMessage: RawMessage = {
        platform: 'flutter',
        platformUserId: 'flutter-user-456',
        content: {
          text: 'Hello Gitu!',
          attachments: [],
        },
      };

      const normalized = await gituMessageGateway.normalizeMessage(rawMessage);

      expect(normalized.userId).toBe('user-123');
      expect(normalized.platform).toBe('flutter');
      expect(normalized.content.text).toBe('Hello Gitu!');
      expect(normalized.timestamp).toBeInstanceOf(Date);
      expect(normalized.id).toBeDefined();
    });

    it('should normalize a WhatsApp message with text', async () => {
      mockQuery
        .mockResolvedValueOnce({ rows: [{ user_id: 'user-123' }] } as any)
        .mockResolvedValueOnce({ rows: [] } as any);

      const rawMessage: RawMessage = {
        platform: 'whatsapp',
        platformUserId: '+1234567890',
        content: {
          message: {
            conversation: 'Hello from WhatsApp!',
          },
        },
      };

      const normalized = await gituMessageGateway.normalizeMessage(rawMessage);

      expect(normalized.userId).toBe('user-123');
      expect(normalized.platform).toBe('whatsapp');
      expect(normalized.content.text).toBe('Hello from WhatsApp!');
    });

    it('should normalize a WhatsApp message with image', async () => {
      mockQuery
        .mockResolvedValueOnce({ rows: [{ user_id: 'user-123' }] } as any)
        .mockResolvedValueOnce({ rows: [] } as any);

      const rawMessage: RawMessage = {
        platform: 'whatsapp',
        platformUserId: '+1234567890',
        content: {
          message: {
            imageMessage: {
              caption: 'Check this out!',
              jpegThumbnail: Buffer.from('fake-image-data'),
              mimetype: 'image/jpeg',
            },
          },
        },
      };

      const normalized = await gituMessageGateway.normalizeMessage(rawMessage);

      expect(normalized.content.text).toBe('Check this out!');
      expect(normalized.content.attachments).toHaveLength(1);
      expect(normalized.content.attachments![0].type).toBe('image');
      expect(normalized.content.attachments![0].mimetype).toBe('image/jpeg');
    });

    it('should normalize a Telegram message', async () => {
      mockQuery
        .mockResolvedValueOnce({ rows: [{ user_id: 'user-123' }] } as any)
        .mockResolvedValueOnce({ rows: [] } as any);

      const rawMessage: RawMessage = {
        platform: 'telegram',
        platformUserId: '123456789',
        content: {
          text: 'Hello from Telegram!',
          message_id: 42,
        },
      };

      const normalized = await gituMessageGateway.normalizeMessage(rawMessage);

      expect(normalized.userId).toBe('user-123');
      expect(normalized.platform).toBe('telegram');
      expect(normalized.content.text).toBe('Hello from Telegram!');
    });

    it('should normalize a Telegram message with photo', async () => {
      mockQuery
        .mockResolvedValueOnce({ rows: [{ user_id: 'user-123' }] } as any)
        .mockResolvedValueOnce({ rows: [] } as any);

      const rawMessage: RawMessage = {
        platform: 'telegram',
        platformUserId: '123456789',
        content: {
          caption: 'Nice photo',
          photo: [
            { file_id: 'small', width: 100, height: 100 },
            { file_id: 'large', width: 800, height: 600 },
          ],
        },
      };

      const normalized = await gituMessageGateway.normalizeMessage(rawMessage);

      expect(normalized.content.text).toBe('Nice photo');
      expect(normalized.content.attachments).toHaveLength(1);
      expect(normalized.content.attachments![0].type).toBe('image');
    });

    it('should normalize an email message', async () => {
      mockQuery
        .mockResolvedValueOnce({ rows: [{ user_id: 'user-123' }] } as any)
        .mockResolvedValueOnce({ rows: [] } as any);

      const rawMessage: RawMessage = {
        platform: 'email',
        platformUserId: 'user@example.com',
        content: {
          text: 'Email body text',
          subject: 'Test Email',
          attachments: [
            {
              filename: 'document.pdf',
              contentType: 'application/pdf',
              content: Buffer.from('fake-pdf-data'),
            },
          ],
        },
      };

      const normalized = await gituMessageGateway.normalizeMessage(rawMessage);

      expect(normalized.content.text).toBe('Email body text');
      expect(normalized.content.attachments).toHaveLength(1);
      expect(normalized.content.attachments![0].type).toBe('document');
      expect(normalized.content.attachments![0].filename).toBe('document.pdf');
    });

    it('should normalize a terminal message', async () => {
      mockQuery
        .mockResolvedValueOnce({ rows: [{ user_id: 'user-123' }] } as any)
        .mockResolvedValueOnce({ rows: [] } as any);

      const rawMessage: RawMessage = {
        platform: 'terminal',
        platformUserId: 'terminal-session-789',
        content: {
          command: 'gitu help',
        },
      };

      const normalized = await gituMessageGateway.normalizeMessage(rawMessage);

      expect(normalized.content.text).toBe('gitu help');
    });

    it('should throw error if platform account not linked', async () => {
      mockQuery.mockResolvedValueOnce({ rows: [] } as any); // No linked account

      const rawMessage: RawMessage = {
        platform: 'whatsapp',
        platformUserId: '+9999999999',
        content: { message: { conversation: 'Hello' } },
      };

      await expect(gituMessageGateway.normalizeMessage(rawMessage)).rejects.toThrow(
        'Platform account not linked'
      );
    });
  });

  describe('detectPlatform', () => {
    it('should detect WhatsApp from message structure', () => {
      const rawContent = {
        key: { remoteJid: '1234567890@s.whatsapp.net' },
        message: { conversation: 'Hello' },
      };

      const detection = gituMessageGateway.detectPlatform(rawContent);

      expect(detection.platform).toBe('whatsapp');
      expect(detection.confidence).toBeGreaterThan(0.9);
      expect(detection.indicators).toContain('WhatsApp message structure detected');
    });

    it('should detect Telegram from message structure', () => {
      const rawContent = {
        message_id: 123,
        chat: { id: 456, type: 'private' },
        text: 'Hello',
      };

      const detection = gituMessageGateway.detectPlatform(rawContent);

      expect(detection.platform).toBe('telegram');
      expect(detection.confidence).toBeGreaterThan(0.9);
      expect(detection.indicators).toContain('Telegram message structure detected');
    });

    it('should detect email from message structure', () => {
      const rawContent = {
        from: 'sender@example.com',
        subject: 'Test',
        messageId: '<abc123@example.com>',
      };

      const detection = gituMessageGateway.detectPlatform(rawContent);

      expect(detection.platform).toBe('email');
      expect(detection.confidence).toBeGreaterThan(0.9);
      expect(detection.indicators).toContain('Email message structure detected');
    });

    it('should detect terminal from metadata', () => {
      const rawContent = { command: 'gitu status' };
      const metadata = { source: 'cli' };

      const detection = gituMessageGateway.detectPlatform(rawContent, metadata);

      expect(detection.platform).toBe('terminal');
      expect(detection.confidence).toBeGreaterThan(0.8);
    });

    it('should use explicit platform from metadata', () => {
      const rawContent = { text: 'Hello' };
      const metadata = { platform: 'flutter' };

      const detection = gituMessageGateway.detectPlatform(rawContent, metadata);

      expect(detection.platform).toBe('flutter');
      expect(detection.confidence).toBe(1.0);
      expect(detection.indicators).toContain('explicit platform in metadata');
    });

    it('should default to flutter for generic messages', () => {
      const rawContent = { text: 'Hello' };

      const detection = gituMessageGateway.detectPlatform(rawContent);

      expect(detection.platform).toBe('flutter');
      expect(detection.confidence).toBeLessThan(0.8);
    });
  });

  describe('message routing', () => {
    it('should route message to platform-specific handlers', async () => {
      const handler = jest.fn<() => Promise<void>>();
      gituMessageGateway.onMessage('flutter', handler);

      const message: IncomingMessage = {
        id: 'msg-123',
        userId: 'user-123',
        platform: 'flutter',
        platformUserId: 'flutter-456',
        content: { text: 'Hello' },
        timestamp: new Date(),
        metadata: {},
      };

      await gituMessageGateway.routeMessage(message);

      expect(handler).toHaveBeenCalledWith(message);
    });

    it('should route message to global handlers', async () => {
      const globalHandler = jest.fn<() => Promise<void>>();
      gituMessageGateway.onAnyMessage(globalHandler);

      const message: IncomingMessage = {
        id: 'msg-123',
        userId: 'user-123',
        platform: 'telegram',
        platformUserId: 'tg-456',
        content: { text: 'Hello' },
        timestamp: new Date(),
        metadata: {},
      };

      await gituMessageGateway.routeMessage(message);

      expect(globalHandler).toHaveBeenCalledWith(message);
    });

    it('should handle errors in handlers gracefully', async () => {
      const errorHandler = jest.fn<() => Promise<void>>().mockRejectedValue(new Error('Handler error'));
      const consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation(() => {});

      gituMessageGateway.onMessage('whatsapp', errorHandler);

      const message: IncomingMessage = {
        id: 'msg-123',
        userId: 'user-123',
        platform: 'whatsapp',
        platformUserId: 'wa-456',
        content: { text: 'Hello' },
        timestamp: new Date(),
        metadata: {},
      };

      await gituMessageGateway.routeMessage(message);

      expect(errorHandler).toHaveBeenCalled();
      expect(consoleErrorSpy).toHaveBeenCalled();

      consoleErrorSpy.mockRestore();
    });
  });

  describe('processMessage', () => {
    it('should normalize and route a message', async () => {
      mockQuery
        .mockResolvedValueOnce({ rows: [{ user_id: 'user-123' }] } as any)
        .mockResolvedValueOnce({ rows: [] } as any);

      const handler = jest.fn<() => Promise<void>>();
      gituMessageGateway.onMessage('flutter', handler);

      const rawMessage: RawMessage = {
        platform: 'flutter',
        platformUserId: 'flutter-456',
        content: { text: 'Process me!' },
      };

      const result = await gituMessageGateway.processMessage(rawMessage);

      expect(result.content.text).toBe('Process me!');
      expect(handler).toHaveBeenCalledWith(expect.objectContaining({
        content: expect.objectContaining({ text: 'Process me!' }),
      }));
    });
  });

  describe('getMessageStats', () => {
    it('should return message statistics', async () => {
      mockQuery
        .mockResolvedValueOnce({ rows: [{ count: '100' }] } as any) // total
        .mockResolvedValueOnce({ rows: [
          { platform: 'flutter', count: '50' },
          { platform: 'whatsapp', count: '30' },
          { platform: 'telegram', count: '20' },
        ]} as any) // by platform
        .mockResolvedValueOnce({ rows: [{ count: '10' }] } as any) // last 24h
        .mockResolvedValueOnce({ rows: [{ count: '45' }] } as any) // last 7d
        .mockResolvedValueOnce({ rows: [{ first_message: new Date(Date.now() - 10 * 24 * 60 * 60 * 1000) }] } as any); // first message

      const stats = await gituMessageGateway.getMessageStats('user-123');

      expect(stats.totalMessages).toBe(100);
      expect(stats.messagesByPlatform.flutter).toBe(50);
      expect(stats.messagesByPlatform.whatsapp).toBe(30);
      expect(stats.messagesLast24h).toBe(10);
      expect(stats.messagesLast7d).toBe(45);
      expect(stats.averageMessagesPerDay).toBeGreaterThan(0);
    });
  });
});
