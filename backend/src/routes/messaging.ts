import { Router, type Response } from 'express';
import { authenticateToken, type AuthRequest } from '../middleware/auth.js';
import { messagingService } from '../services/messagingService.js';
import { ValidationError } from '../types/errors.js';

const router = Router();

router.use(authenticateToken);

const handleError = (error: any, res: Response) => {
  console.error('Messaging API error:', error.message);
  
  if (error instanceof ValidationError) {
    return res.status(400).json({ error: error.message, code: 'VALIDATION_ERROR' });
  }
  
  res.status(500).json({ error: 'An error occurred', code: 'INTERNAL_ERROR' });
};

const validateUserId = (req: AuthRequest, res: Response): string | null => {
  if (!req.userId) {
    res.status(401).json({ error: 'Unauthorized', code: 'UNAUTHORIZED' });
    return null;
  }
  return req.userId;
};

router.get('/conversations', async (req: AuthRequest, res: Response) => {
  try {
    const userId = validateUserId(req, res);
    if (!userId) return;
    
    const conversations = await messagingService.getConversations(userId);
    res.json({ conversations });
  } catch (error: any) {
    handleError(error, res);
  }
});

router.get('/direct/:userId', async (req: AuthRequest, res: Response) => {
  try {
    const userId = validateUserId(req, res);
    if (!userId) return;
    
    const { userId: otherUserId } = req.params;
    const { limit, before } = req.query;
    
    if (!otherUserId) {
      return res.status(400).json({ error: 'User ID required', code: 'VALIDATION_ERROR' });
    }
    
    const messages = await messagingService.getDirectMessages(userId, otherUserId, {
      limit: limit ? parseInt(limit as string) : undefined,
      before: before as string
    });
    res.json({ messages });
  } catch (error: any) {
    handleError(error, res);
  }
});

router.post('/direct/:userId', async (req: AuthRequest, res: Response) => {
  try {
    const userId = validateUserId(req, res);
    if (!userId) return;
    
    const { userId: recipientId } = req.params;
    const { content, messageType, metadata } = req.body;
    
    if (!recipientId) {
      return res.status(400).json({ error: 'Recipient ID required', code: 'VALIDATION_ERROR' });
    }
    if (!content || typeof content !== 'string') {
      return res.status(400).json({ error: 'Message content required', code: 'VALIDATION_ERROR' });
    }
    
    const message = await messagingService.sendDirectMessage(
      userId, recipientId, content, messageType, metadata
    );
    res.json({ message });
  } catch (error: any) {
    handleError(error, res);
  }
});

router.post('/direct/:userId/read', async (req: AuthRequest, res: Response) => {
  try {
    const userId = validateUserId(req, res);
    if (!userId) return;
    
    const { userId: otherUserId } = req.params;
    
    if (!otherUserId) {
      return res.status(400).json({ error: 'User ID required', code: 'VALIDATION_ERROR' });
    }
    
    await messagingService.markConversationRead(userId, otherUserId);
    res.json({ success: true });
  } catch (error: any) {
    handleError(error, res);
  }
});

router.get('/groups/:groupId', async (req: AuthRequest, res: Response) => {
  try {
    const userId = validateUserId(req, res);
    if (!userId) return;
    
    const { groupId } = req.params;
    const { limit, before } = req.query;
    
    if (!groupId) {
      return res.status(400).json({ error: 'Group ID required', code: 'VALIDATION_ERROR' });
    }
    
    const messages = await messagingService.getGroupMessages(groupId, userId, {
      limit: limit ? parseInt(limit as string) : undefined,
      before: before as string
    });
    res.json({ messages });
  } catch (error: any) {
    handleError(error, res);
  }
});

router.post('/groups/:groupId', async (req: AuthRequest, res: Response) => {
  try {
    const userId = validateUserId(req, res);
    if (!userId) return;
    
    const { groupId } = req.params;
    const { content, messageType, metadata, replyToId } = req.body;
    
    if (!groupId) {
      return res.status(400).json({ error: 'Group ID required', code: 'VALIDATION_ERROR' });
    }
    if (!content || typeof content !== 'string') {
      return res.status(400).json({ error: 'Message content required', code: 'VALIDATION_ERROR' });
    }
    
    const message = await messagingService.sendGroupMessage(
      groupId, userId, content, messageType, metadata, replyToId
    );
    res.json({ message });
  } catch (error: any) {
    handleError(error, res);
  }
});

router.post('/groups/:groupId/read', async (req: AuthRequest, res: Response) => {
  try {
    const userId = validateUserId(req, res);
    if (!userId) return;
    
    const { groupId } = req.params;
    const { lastMessageId } = req.body;
    
    if (!groupId) {
      return res.status(400).json({ error: 'Group ID required', code: 'VALIDATION_ERROR' });
    }
    if (!lastMessageId) {
      return res.status(400).json({ error: 'Last message ID required', code: 'VALIDATION_ERROR' });
    }
    
    await messagingService.markGroupMessagesRead(groupId, userId, lastMessageId);
    res.json({ success: true });
  } catch (error: any) {
    handleError(error, res);
  }
});

router.get('/groups/:groupId/unread', async (req: AuthRequest, res: Response) => {
  try {
    const userId = validateUserId(req, res);
    if (!userId) return;
    
    const { groupId } = req.params;
    
    if (!groupId) {
      return res.status(400).json({ error: 'Group ID required', code: 'VALIDATION_ERROR' });
    }
    
    const count = await messagingService.getGroupUnreadCount(groupId, userId);
    res.json({ unreadCount: count });
  } catch (error: any) {
    handleError(error, res);
  }
});

router.get('/unread', async (req: AuthRequest, res: Response) => {
  try {
    const userId = validateUserId(req, res);
    if (!userId) return;
    
    const counts = await messagingService.getTotalUnreadCount(userId);
    res.json(counts);
  } catch (error: any) {
    handleError(error, res);
  }
});

export default router;
