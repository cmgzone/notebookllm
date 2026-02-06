import { v4 as uuidv4 } from 'uuid';
import pool from '../config/database.js';
import { gituMCPHub, MCPTool, MCPContext } from './gituMCPHub.js';
import { gituMissionControl } from './gituMissionControl.js';

const DOCUMENT_FORMATS = ['text', 'markdown', 'html'] as const;
type DocumentFormat = typeof DOCUMENT_FORMATS[number];

async function resolveMissionId(context: MCPContext): Promise<string | undefined> {
  if (!context.sessionId) return undefined;
  const result = await pool.query(
    `SELECT memory->>'missionId' AS mission_id FROM gitu_agents WHERE id = $1`,
    [context.sessionId]
  );
  const missionId = result.rows[0]?.mission_id;
  return typeof missionId === 'string' && missionId.trim().length > 0 ? missionId : undefined;
}

const writeDocumentTool: MCPTool = {
  name: 'write_document',
  description: 'Create a document artifact for a mission (title + content).',
  schema: {
    type: 'object',
    properties: {
      title: { type: 'string', description: 'Document title' },
      content: { type: 'string', description: 'Document content' },
      format: {
        type: 'string',
        description: 'Document format',
        enum: [...DOCUMENT_FORMATS]
      },
      tags: { type: 'array', items: { type: 'string' }, description: 'Optional tags' }
    },
    required: ['title', 'content']
  },
  handler: async (args: any, context: MCPContext) => {
    const title = typeof args?.title === 'string' ? args.title.trim() : '';
    const content = typeof args?.content === 'string' ? args.content.trim() : '';
    if (!title || !content) {
      throw new Error('title and content are required');
    }

    const format = DOCUMENT_FORMATS.includes(args?.format) ? (args.format as DocumentFormat) : 'markdown';
    const tags = Array.isArray(args?.tags) ? args.tags.filter((t: any) => typeof t === 'string') : [];

    const documentId = uuidv4();
    const document = {
      id: documentId,
      title,
      content,
      format,
      tags,
      createdAt: new Date().toISOString(),
      authorSessionId: context.sessionId || null
    };

    const missionId = await resolveMissionId(context);
    if (missionId) {
      const mission = await gituMissionControl.getMission(missionId);
      if (mission) {
        const existingDocs = Array.isArray(mission.artifacts?.documents) ? mission.artifacts.documents : [];
        await gituMissionControl.updateMissionState(missionId, {
          artifacts: { documents: [...existingDocs, document] }
        });
      }
    }

    return {
      success: true,
      document: {
        id: documentId,
        title,
        format,
        tags
      },
      stored: Boolean(missionId)
    };
  }
};

const reviewDocumentTool: MCPTool = {
  name: 'review_document',
  description: 'Attach a review artifact to a mission document.',
  schema: {
    type: 'object',
    properties: {
      documentId: { type: 'string', description: 'Document ID to review' },
      summary: { type: 'string', description: 'Short review summary' },
      issues: { type: 'array', items: { type: 'string' }, description: 'Issues or concerns' },
      rating: { type: 'number', description: 'Rating from 0.0 to 1.0' }
    },
    required: ['documentId', 'summary']
  },
  handler: async (args: any, context: MCPContext) => {
    const documentId = typeof args?.documentId === 'string' ? args.documentId.trim() : '';
    const summary = typeof args?.summary === 'string' ? args.summary.trim() : '';
    if (!documentId || !summary) {
      throw new Error('documentId and summary are required');
    }

    const issues = Array.isArray(args?.issues) ? args.issues.filter((t: any) => typeof t === 'string') : [];
    const rating = typeof args?.rating === 'number' ? Math.max(0, Math.min(1, args.rating)) : undefined;

    const reviewId = uuidv4();
    const review = {
      id: reviewId,
      documentId,
      summary,
      issues,
      rating,
      createdAt: new Date().toISOString(),
      reviewerSessionId: context.sessionId || null
    };

    const missionId = await resolveMissionId(context);
    if (missionId) {
      const mission = await gituMissionControl.getMission(missionId);
      if (mission) {
        const existingReviews = Array.isArray(mission.artifacts?.reviews) ? mission.artifacts.reviews : [];
        await gituMissionControl.updateMissionState(missionId, {
          artifacts: { reviews: [...existingReviews, review] }
        });
      }
    }

    return {
      success: true,
      review: {
        id: reviewId,
        documentId,
        rating,
        issuesCount: issues.length
      },
      stored: Boolean(missionId)
    };
  }
};

export function registerDocumentTools() {
  gituMCPHub.registerTool(writeDocumentTool);
  gituMCPHub.registerTool(reviewDocumentTool);
  console.log('[DocumentMCPTools] Registered document write/review tools');
}
