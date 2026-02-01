import pool from '../config/database.js';
import { gituMCPHub, MCPTool, MCPContext } from './gituMCPHub.js';
import { codeVerificationService } from './codeVerificationService.js';
import { codeReviewService } from './codeReviewService.js';

/**
 * Tool: List Notebooks
 */
const listNotebooksTool: MCPTool = {
  name: 'list_notebooks',
  description: 'List all notebooks accessible to the user',
  schema: {
    type: 'object',
    properties: {
      limit: { type: 'number', description: 'Max number of notebooks to return', default: 20 },
      offset: { type: 'number', description: 'Pagination offset', default: 0 }
    }
  },
  handler: async (args: any, context: MCPContext) => {
    const limit = Math.min(args.limit || 20, 50);
    const offset = args.offset || 0;

    console.log(`[NotebookMCP] list_notebooks called for user: ${context.userId}`);

    const result = await pool.query(
      `SELECT id, title, description, is_agent_notebook, created_at, updated_at,
              (SELECT COUNT(*) FROM sources WHERE notebook_id = notebooks.id) as source_count
       FROM notebooks
       WHERE user_id = $1
       ORDER BY updated_at DESC
       LIMIT $2 OFFSET $3`,
      [context.userId, limit, offset]
    );

    console.log(`[NotebookMCP] Found ${result.rows.length} notebooks for user ${context.userId}`);

    return {
      notebooks: result.rows
    };
  }
};

/**
 * Tool: Get Source
 */
const getSourceTool: MCPTool = {
  name: 'get_source',
  description: 'Get a specific source by ID',
  schema: {
    type: 'object',
    properties: {
      sourceId: { type: 'string', description: 'The ID of the source to retrieve' }
    },
    required: ['sourceId']
  },
  handler: async (args: any, context: MCPContext) => {
    const result = await pool.query(
      `SELECT s.*, n.title as notebook_title
       FROM sources s
       JOIN notebooks n ON s.notebook_id = n.id
       WHERE s.id = $1 AND n.user_id = $2`,
      [args.sourceId, context.userId]
    );

    if (result.rows.length === 0) {
      throw new Error('Source not found or access denied');
    }

    return {
      source: result.rows[0]
    };
  }
};

/**
 * Tool: Search Sources
 */
const searchSourcesTool: MCPTool = {
  name: 'search_sources',
  description: 'Search for sources across all notebooks',
  schema: {
    type: 'object',
    properties: {
      query: { type: 'string', description: 'Search query' },
      limit: { type: 'number', description: 'Max results', default: 10 },
      notebookId: { type: 'string', description: 'Filter by notebook ID' }
    },
    required: ['query']
  },
  handler: async (args: any, context: MCPContext) => {
    const { query, limit = 10, notebookId } = args;
    const params: any[] = [context.userId, `%${query}%`, limit];
    let querySql = `
      SELECT s.id, s.title, s.type, s.notebook_id, n.title as notebook_title,
             substring(s.content from 1 for 200) as snippet
      FROM sources s
      JOIN notebooks n ON s.notebook_id = n.id
      WHERE n.user_id = $1 AND (s.title ILIKE $2 OR s.content ILIKE $2 OR n.title ILIKE $2)
    `;

    if (notebookId) {
      querySql += ` AND s.notebook_id = $4`;
      params.push(notebookId);
    }

    querySql += ` ORDER BY s.updated_at DESC LIMIT $3`;

    const result = await pool.query(querySql, params);

    return {
      matches: result.rows
    };
  }
};

/**
 * Tool: List Sources (in a specific notebook)
 */
const listSourcesTool: MCPTool = {
  name: 'list_sources',
  description: 'List all sources inside a notebook. Use this to see what files or links are in a notebook.',
  schema: {
    type: 'object',
    properties: {
      notebookName: { type: 'string', description: 'The name of the notebook to find sources from' },
      notebookId: { type: 'string', description: 'The specific ID of the notebook (if known)' },
      limit: { type: 'number', default: 20 }
    }
  },
  handler: async (args: any, context: MCPContext) => {
    const { notebookName, notebookId, limit = 20 } = args;
    let targetNotebookId = notebookId;

    // Resolve notebook ID from name if necessary
    if (!targetNotebookId && notebookName) {
      // 1. Try exact match
      const exactMatch = await pool.query(
        `SELECT id FROM notebooks WHERE user_id = $1 AND title ILIKE $2 LIMIT 1`,
        [context.userId, notebookName]
      );

      if (exactMatch.rows.length > 0) {
        targetNotebookId = exactMatch.rows[0].id;
      } else {
        // 2. Try partial match
        let partialMatch = await pool.query(
          `SELECT id, title FROM notebooks WHERE user_id = $1 AND title ILIKE $2 ORDER BY updated_at DESC LIMIT 1`,
          [context.userId, `%${notebookName}%`]
        );

        // 3. Try super-fuzzy match (handle "WHATS APP" -> "WhatsApp")
        if (partialMatch.rows.length === 0 && notebookName.includes(' ')) {
          const fuzzyName = `%${notebookName.split(' ').join('%')}%`;
          partialMatch = await pool.query(
            `SELECT id, title FROM notebooks WHERE user_id = $1 AND title ILIKE $2 ORDER BY updated_at DESC LIMIT 1`,
            [context.userId, fuzzyName]
          );
        }

        if (partialMatch.rows.length > 0) {
          targetNotebookId = partialMatch.rows[0].id;
          console.log(`[ListSources] Resolved "${notebookName}" to notebook "${partialMatch.rows[0].title}" (${targetNotebookId})`);
        }
      }
    }

    if (!targetNotebookId) {
      return {
        error: `Could not find a notebook matching "${notebookName}". Please try listing your notebooks first.`
      };
    }

    // Now list sources for this notebook
    const result = await pool.query(
      `SELECT id, title, type, created_at,
              substring(content from 1 for 100) as snippet
       FROM sources
       WHERE notebook_id = $1
       ORDER BY created_at DESC
       LIMIT $2`,
      [targetNotebookId, limit]
    );

    return {
      notebookId: targetNotebookId,
      sources: result.rows
    };
  }
};

/**
 * Tool: Verify Code
 */
const verifyCodeTool: MCPTool = {
  name: 'verify_code',
  description: 'Verify code for correctness, security, and best practices',
  schema: {
    type: 'object',
    properties: {
      code: { type: 'string', description: 'The code to verify' },
      language: { type: 'string', description: 'Programming language' },
      context: { type: 'string', description: 'Optional context about the code' },
      strictMode: { type: 'boolean', description: 'Enable strict verification', default: false }
    },
    required: ['code', 'language']
  },
  handler: async (args: any, context: MCPContext) => {
    return await codeVerificationService.verifyCode({
      code: args.code,
      language: args.language,
      context: args.context,
      strictMode: args.strictMode
    });
  }
};

/**
 * Tool: Review Code
 */
const reviewCodeTool: MCPTool = {
  name: 'review_code',
  description: 'Perform a comprehensive AI code review',
  requiresPremium: true, // Assuming review is a premium feature
  schema: {
    type: 'object',
    properties: {
      code: { type: 'string', description: 'The code to review' },
      language: { type: 'string', description: 'Programming language' },
      reviewType: {
        type: 'string',
        enum: ['comprehensive', 'security', 'performance', 'readability'],
        default: 'comprehensive'
      },
      context: { type: 'string', description: 'Optional context' }
    },
    required: ['code', 'language']
  },
  handler: async (args: any, context: MCPContext) => {
    return await codeReviewService.reviewCode(
      context.userId,
      args.code,
      args.language,
      args.reviewType,
      args.context,
      false // Don't save review to DB for ephemeral tool calls by default, or maybe true?
      // Let's set to false to avoid cluttering history unless explicitly asked, 
      // but `codeReviewService` returns a saved review object usually.
      // The service saves if `saveReview` is true. 
      // Let's keep it false for now as this is likely an interactive session.
    );
  }
};

/**
 * Tool: Schedule Reminder
 */
const scheduleReminderTool: MCPTool = {
  name: 'schedule_reminder',
  description: 'Schedule a reminder to be sent to the user at a specific time',
  schema: {
    type: 'object',
    properties: {
      message: { type: 'string', description: 'The reminder message to send' },
      datetime: { type: 'string', description: 'When to send the reminder (ISO format or natural language like "tomorrow at 9am"). Required for one-time events.' },
      recurring: { type: 'boolean', description: 'Should this reminder repeat?', default: false },
      interval: { type: 'string', description: 'Simple recurrence: daily, weekly, monthly' },
      cron: { type: 'string', description: 'CRON expression for complex schedules (e.g. "*/2 * * * *" for every 2 minutes). precise usage.' }
    },
    required: ['message']
  },
  handler: async (args: any, context: MCPContext) => {
    const { message, datetime, recurring, interval, cron: explicitCron } = args;

    // Logic:
    // 1. If explicit CRON is provided, use it.
    // 2. If valid datetime is provided, use it (and optionally build simple cron from interval).
    // 3. Fallback/Error if neither.

    let cron: string | null = explicitCron || null;
    let scheduledTime: Date | null = datetime ? parseDatetime(datetime) : null;

    if (cron) {
      // Validation check for cron could go here
    } else if (scheduledTime) {
      // Standard datetime based scheduling
      if (recurring && interval) {
        const hour = scheduledTime.getHours();
        const minute = scheduledTime.getMinutes();
        switch (interval) {
          case 'daily':
            cron = `${minute} ${hour} * * *`;
            break;
          case 'weekly':
            cron = `${minute} ${hour} * * ${scheduledTime.getDay()}`;
            break;
          case 'monthly':
            cron = `${minute} ${hour} ${scheduledTime.getDate()} * *`;
            break;
        }
      } else {
        cron = `${scheduledTime.getMinutes()} ${scheduledTime.getHours()} ${scheduledTime.getDate()} ${scheduledTime.getMonth() + 1} *`;
      }
    } else {
      // If no cron and no valid datetime, we can't schedule
      throw new Error('Please provide either a valid datetime (e.g., "tomorrow at 9am") or a CRON expression for the schedule.');
    }

    // Insert into scheduled tasks
    const result = await pool.query(
      `INSERT INTO gitu_scheduled_tasks 
       (user_id, name, action, cron, enabled, max_retries, retry_count, created_at, updated_at)
       VALUES ($1, $2, $3, $4, true, 1, 0, NOW(), NOW())
       RETURNING id`,
      [
        context.userId,
        `Reminder: ${message.substring(0, 50)}`,
        'notification.send',
        cron
      ]
    );

    return {
      success: true,
      reminderId: result.rows[0].id,
      scheduledFor: scheduledTime ? scheduledTime.toISOString() : 'Custom Schedule',
      message: `I'll remind you: "${message}"`,
      recurring: (recurring || !!explicitCron) ? (interval || explicitCron || 'Custom Recurrence') : 'One-time reminder'
    };
  }
};

/**
 * Tool: List Reminders
 */
const listRemindersTool: MCPTool = {
  name: 'list_reminders',
  description: 'List all scheduled reminders for the user',
  schema: {
    type: 'object',
    properties: {
      includeCompleted: { type: 'boolean', description: 'Include completed/disabled reminders', default: false }
    }
  },
  handler: async (args: any, context: MCPContext) => {
    const { includeCompleted } = args;

    const query = includeCompleted
      ? `SELECT * FROM gitu_scheduled_tasks WHERE user_id = $1 AND action = 'notification.send' ORDER BY created_at DESC`
      : `SELECT * FROM gitu_scheduled_tasks WHERE user_id = $1 AND action = 'notification.send' AND enabled = true ORDER BY created_at DESC`;

    const result = await pool.query(query, [context.userId]);

    return {
      reminders: result.rows.map(r => ({
        id: r.id,
        name: r.name,
        schedule: r.cron,
        enabled: r.enabled,
        lastRun: r.last_run_at,
        createdAt: r.created_at
      }))
    };
  }
};

/**
 * Tool: Cancel Reminder
 */
const cancelReminderTool: MCPTool = {
  name: 'cancel_reminder',
  description: 'Cancel a scheduled reminder by ID or by searching for its name/message.',
  schema: {
    type: 'object',
    properties: {
      reminderId: { type: 'string', description: 'The ID of the reminder to cancel (if known)' },
      name: { type: 'string', description: 'Search for and cancel a reminder by name or message content (partial match is OK)' },
      cancelAll: { type: 'boolean', description: 'If true, cancel all reminders matching the name', default: false }
    }
  },
  handler: async (args: any, context: MCPContext) => {
    const { reminderId, name, cancelAll } = args;

    if (!reminderId && !name) {
      throw new Error('Please provide either a reminderId or a name to search for.');
    }

    let result;

    if (reminderId) {
      // Cancel by specific ID
      result = await pool.query(
        `UPDATE gitu_scheduled_tasks SET enabled = false, updated_at = NOW()
         WHERE id = $1 AND user_id = $2 AND action = 'notification.send'
         RETURNING id, name`,
        [reminderId, context.userId]
      );
    } else if (name) {
      // Cancel by name match
      if (cancelAll) {
        result = await pool.query(
          `UPDATE gitu_scheduled_tasks SET enabled = false, updated_at = NOW()
           WHERE user_id = $1 AND action = 'notification.send' AND enabled = true AND name ILIKE $2
           RETURNING id, name`,
          [context.userId, `%${name}%`]
        );
      } else {
        // Cancel only the first matching one
        result = await pool.query(
          `UPDATE gitu_scheduled_tasks SET enabled = false, updated_at = NOW()
           WHERE id = (
             SELECT id FROM gitu_scheduled_tasks 
             WHERE user_id = $1 AND action = 'notification.send' AND enabled = true AND name ILIKE $2
             ORDER BY created_at DESC LIMIT 1
           )
           RETURNING id, name`,
          [context.userId, `%${name}%`]
        );
      }
    }

    if (!result || result.rows.length === 0) {
      throw new Error('No matching reminder found or already cancelled.');
    }

    const cancelled = result.rows.map((r: any) => r.name).join(', ');
    return {
      success: true,
      cancelledCount: result.rows.length,
      message: `Cancelled: ${cancelled}`
    };
  }
};

/**
 * Tool: Remember Fact
 */
const rememberFactTool: MCPTool = {
  name: 'remember_fact',
  description: 'Store a fact about the user for future reference',
  schema: {
    type: 'object',
    properties: {
      fact: { type: 'string', description: 'The fact to remember about the user' },
      category: {
        type: 'string',
        description: 'Category of the fact',
        enum: ['personal', 'work', 'preference', 'fact', 'context'],
        default: 'fact'
      }
    },
    required: ['fact']
  },
  handler: async (args: any, context: MCPContext) => {
    const { gituMemoryService } = await import('./gituMemoryService.js');

    const memory = await gituMemoryService.createMemory(context.userId, {
      content: args.fact,
      category: args.category || 'fact',
      source: 'user-request',
      tags: ['explicit', 'user-provided'],
      confidence: 1.0
    });

    return {
      success: true,
      memoryId: memory.id,
      message: `I'll remember that: "${args.fact}"`
    };
  }
};

/**
 * Tool: Recall Facts
 */
const recallFactsTool: MCPTool = {
  name: 'recall_facts',
  description: 'Recall stored facts about the user',
  schema: {
    type: 'object',
    properties: {
      query: { type: 'string', description: 'Optional search query to filter facts' },
      category: { type: 'string', description: 'Filter by category' },
      limit: { type: 'number', description: 'Max facts to return', default: 10 }
    }
  },
  handler: async (args: any, context: MCPContext) => {
    const { gituMemoryService } = await import('./gituMemoryService.js');

    if (args.query) {
      const results = await gituMemoryService.searchMemories(context.userId, args.query, args.limit || 10);
      return { facts: results };
    } else {
      const results = await gituMemoryService.listMemories(context.userId, {
        limit: args.limit || 10,
        category: args.category
      });
      return { facts: results };
    }
  }
};

/**
 * Parse natural language datetime
 */
function parseDatetime(input: string): Date | null {
  // Try ISO format first
  const isoDate = new Date(input);
  if (!isNaN(isoDate.getTime())) {
    return isoDate;
  }

  const now = new Date();
  const lower = input.toLowerCase();

  // Handle "tomorrow"
  if (lower.includes('tomorrow')) {
    const tomorrow = new Date(now);
    tomorrow.setDate(tomorrow.getDate() + 1);

    // Parse time if present
    const timeMatch = lower.match(/(\d{1,2})(?::(\d{2}))?\s*(am|pm)?/i);
    if (timeMatch) {
      let hour = parseInt(timeMatch[1]);
      const minute = parseInt(timeMatch[2] || '0');
      const isPM = timeMatch[3]?.toLowerCase() === 'pm';

      if (isPM && hour < 12) hour += 12;
      if (!isPM && hour === 12) hour = 0;

      tomorrow.setHours(hour, minute, 0, 0);
    } else {
      tomorrow.setHours(9, 0, 0, 0); // Default to 9am
    }

    return tomorrow;
  }

  // Handle "in X minutes/hours/days"
  const inMatch = lower.match(/in\s+(\d+)\s+(minute|hour|day|week)s?/);
  if (inMatch) {
    const amount = parseInt(inMatch[1]);
    const unit = inMatch[2];
    const result = new Date(now);

    switch (unit) {
      case 'minute':
        result.setMinutes(result.getMinutes() + amount);
        break;
      case 'hour':
        result.setHours(result.getHours() + amount);
        break;
      case 'day':
        result.setDate(result.getDate() + amount);
        break;
      case 'week':
        result.setDate(result.getDate() + (amount * 7));
        break;
    }

    return result;
  }

  // Handle day names
  const days = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
  for (let i = 0; i < days.length; i++) {
    if (lower.includes(days[i])) {
      const result = new Date(now);
      const currentDay = now.getDay();
      let daysUntil = i - currentDay;
      if (daysUntil <= 0) daysUntil += 7;
      result.setDate(result.getDate() + daysUntil);

      // Parse time
      const timeMatch = lower.match(/(\d{1,2})(?::(\d{2}))?\s*(am|pm)?/i);
      if (timeMatch) {
        let hour = parseInt(timeMatch[1]);
        const minute = parseInt(timeMatch[2] || '0');
        const isPM = timeMatch[3]?.toLowerCase() === 'pm';

        if (isPM && hour < 12) hour += 12;
        if (!isPM && hour === 12) hour = 0;

        result.setHours(hour, minute, 0, 0);
      } else {
        result.setHours(9, 0, 0, 0);
      }

      return result;
    }
  }

  return null;
}

/**
 * Tool: Spawn Agent
 */
const spawnAgentTool: MCPTool = {
  name: 'spawn_agent',
  description: 'Spawn an autonomous background agent to complete a complex task',
  schema: {
    type: 'object',
    properties: {
      task: { type: 'string', description: 'Description of the task for the agent to complete' },
      background: { type: 'boolean', description: 'Run in background (returns immediately) or wait for result', default: true }
    },
    required: ['task']
  },
  handler: async (args: any, context: MCPContext) => {
    const { gituAgentManager } = await import('./gituAgentManager.js');

    // Create the agent
    // Create the agent
    const agent = await gituAgentManager.spawnAgent(
      context.userId,
      args.task,
      {
        role: 'autonomous_agent',
        focus: 'general',
        initialMemory: {
          source: 'mcp_tool',
          original_context: context
        }
      }
    );

    if (args.background) {
      return {
        success: true,
        agentId: agent.id,
        message: `Agent spawned to handle: "${args.task}". I'll notify you when it's done.`
      };
    } else {
      // For now, we only support background spawning via this tool to avoid timeouts
      return {
        success: true,
        agentId: agent.id,
        message: `Agent started for: "${args.task}". Check back later for results.`
      };
    }
  }
};


// Register all tools
export function registerNotebookTools() {
  gituMCPHub.registerTool(listNotebooksTool);
  gituMCPHub.registerTool(getSourceTool);
  gituMCPHub.registerTool(searchSourcesTool);
  gituMCPHub.registerTool(listSourcesTool);
  gituMCPHub.registerTool(verifyCodeTool);
  gituMCPHub.registerTool(reviewCodeTool);
  gituMCPHub.registerTool(scheduleReminderTool);
  gituMCPHub.registerTool(listRemindersTool);
  gituMCPHub.registerTool(cancelReminderTool);
  gituMCPHub.registerTool(rememberFactTool);
  gituMCPHub.registerTool(recallFactsTool);
  gituMCPHub.registerTool(spawnAgentTool);
  console.log('[NotebookMCPTools] Registered notebook, scheduling, and agent tools');
}
