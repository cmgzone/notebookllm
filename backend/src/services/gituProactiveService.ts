/**
 * Gitu Proactive Service
 * Aggregates data from connected platforms and generates smart, proactive insights.
 * 
 * Requirements: Enhanced User Experience through AI-driven suggestions
 * Design: Proactive notifications, smart summaries, context-aware suggestions
 */

import pool from '../config/database.js';
import { gituGmailManager } from './gituGmailManager.js';
import * as gituGmailOperations from './gituGmailOperations.js';
import { gituTaskScheduler, type ScheduledTask } from './gituTaskScheduler.js';
import { gituMemoryService, type Memory } from './gituMemoryService.js';
import { gituMissionControl, type Mission } from './gituMissionControl.js';
import { gituAgentOrchestrator } from './gituAgentOrchestrator.js';

// ==================== INTERFACES ====================

export interface GmailSummary {
    connected: boolean;
    email?: string;
    unreadCount: number;
    importantUnread: number;
    recentEmails: Array<{
        id: string;
        from: string;
        subject: string;
        snippet: string;
        date: string;
        isImportant: boolean;
    }>;
    lastSyncAt?: Date;
}

export interface WhatsAppSummary {
    connected: boolean;
    phoneNumber?: string;
    unreadChats: number;
    pendingMessages: number;
    lastMessageAt?: Date;
}

export interface TasksSummary {
    totalEnabled: number;
    pendingCount: number;
    nextDueTask?: {
        id: string;
        name: string;
        nextRunAt: Date;
    };
    recentExecutions: Array<{
        taskName: string;
        success: boolean;
        executedAt: Date;
    }>;
    failedTasksCount: number;
}

export interface Suggestion {
    id: string;
    type: 'email' | 'task' | 'automation' | 'reminder' | 'tip' | 'mission';
    priority: 'high' | 'medium' | 'low';
    title: string;
    description: string;
    action?: {
        type: string;
        params?: Record<string, any>;
    };
    createdAt: Date;
    expiresAt?: Date;
}

export interface PatternInsight {
    id: string;
    type: 'usage' | 'behavior' | 'opportunity';
    title: string;
    description: string;
    confidence: number;
    dataPoints: number;
    suggestedAction?: string;
    createdAt: Date;
}

export interface ProactiveInsights {
    userId: string;
    gmailSummary: GmailSummary;
    whatsappSummary: WhatsAppSummary;
    tasksSummary: TasksSummary;
    activeMissions: Mission[];
    suggestions: Suggestion[];
    patterns: PatternInsight[];
    lastUpdated: Date;
}

export interface UserActivityPattern {
    userId: string;
    hourlyActivity: number[]; // 24 hours
    mostActiveHour: number;
    averageSessionLength: number;
    preferredFeatures: string[];
    lastAnalyzed: Date;
}

// ==================== SERVICE CLASS ====================

class GituProactiveService {
    private readonly CACHE_TTL_MS = 60000; // 1 minute cache
    private cache: Map<string, { data: ProactiveInsights; timestamp: number }> = new Map();

    /**
     * Get aggregated proactive insights for a user.
     */
    async getProactiveInsights(userId: string, useCache: boolean = true): Promise<ProactiveInsights> {
        // Check cache
        if (useCache) {
            const cached = this.cache.get(userId);
            if (cached && Date.now() - cached.timestamp < this.CACHE_TTL_MS) {
                return cached.data;
            }
        }

        // Fetch all data in parallel
        const [gmailSummary, whatsappSummary, tasksSummary, activeMissions, suggestions, patterns] = await Promise.all([
            this.getGmailSummary(userId),
            this.getWhatsAppSummary(userId),
            this.getTasksSummary(userId),
            gituMissionControl.listActiveMissions(userId),
            this.generateSuggestions(userId),
            this.analyzePatterns(userId),
        ]);

        const insights: ProactiveInsights = {
            userId,
            gmailSummary,
            whatsappSummary,
            tasksSummary,
            activeMissions,
            suggestions,
            patterns,
            lastUpdated: new Date(),
        };

        // Update cache
        this.cache.set(userId, { data: insights, timestamp: Date.now() });

        return insights;
    }

    /**
     * Get Gmail summary for a user.
     */
    async getGmailSummary(userId: string): Promise<GmailSummary> {
        try {
            const connection = await gituGmailManager.getConnection(userId);

            if (!connection) {
                return {
                    connected: false,
                    unreadCount: 0,
                    importantUnread: 0,
                    recentEmails: [],
                };
            }

            // Fetch unread emails
            let unreadCount = 0;
            let importantUnread = 0;
            const recentEmails: GmailSummary['recentEmails'] = [];

            try {
                // Get unread messages
                const unreadResponse = await gituGmailOperations.listMessages(userId, 'is:unread', 50);
                unreadCount = unreadResponse.messages?.length || 0;

                // Get important unread
                const importantResponse = await gituGmailOperations.listMessages(userId, 'is:unread is:important', 10);
                importantUnread = importantResponse.messages?.length || 0;

                // Get recent emails with details
                if (unreadResponse.messages?.length > 0) {
                    const recentIds = unreadResponse.messages.slice(0, 5);
                    for (const msg of recentIds) {
                        try {
                            const fullMessage = await gituGmailOperations.getMessage(userId, msg.id);
                            const headers = fullMessage.payload?.headers || [];

                            const from = headers.find((h: any) => h.name === 'From')?.value || 'Unknown';
                            const subject = headers.find((h: any) => h.name === 'Subject')?.value || '(No Subject)';
                            const date = headers.find((h: any) => h.name === 'Date')?.value || '';
                            const isImportant = fullMessage.labelIds?.includes('IMPORTANT') || false;

                            recentEmails.push({
                                id: msg.id,
                                from,
                                subject,
                                snippet: fullMessage.snippet || '',
                                date,
                                isImportant,
                            });
                        } catch (err) {
                            // Skip individual message errors
                        }
                    }
                }
            } catch (err) {
                console.error('[Proactive Service] Error fetching Gmail data:', err);
            }

            return {
                connected: true,
                email: connection.email,
                unreadCount,
                importantUnread,
                recentEmails,
                lastSyncAt: new Date(connection.last_used_at || Date.now()),
            };
        } catch (err) {
            console.error('[Proactive Service] Error in getGmailSummary:', err);
            return {
                connected: false,
                unreadCount: 0,
                importantUnread: 0,
                recentEmails: [],
            };
        }
    }

    /**
     * Get WhatsApp summary for a user.
     */
    async getWhatsAppSummary(userId: string): Promise<WhatsAppSummary> {
        try {
            // Use gitu_linked_accounts which is the standard table
            const result = await pool.query(
                `SELECT * FROM gitu_linked_accounts 
                 WHERE user_id = $1 AND platform = 'whatsapp' AND status = 'active'`,
                [userId]
            );

            if (result.rows.length === 0) {
                return {
                    connected: false,
                    unreadChats: 0,
                    pendingMessages: 0,
                };
            }

            const connection = result.rows[0];

            // Get message stats from gitu_messages 
            // Note: We don't have a 'read' column in gitu_messages yet, 
            // so we'll count messages in the last 24h as 'unread' for the dashboard demonstration
            // or use metadata if available.
            const statsResult = await pool.query(
                `SELECT 
           COUNT(DISTINCT platform_user_id) as unread_chats,
           COUNT(*) as pending_messages,
           MAX(timestamp) as last_message_at
         FROM gitu_messages 
         WHERE user_id = $1 AND platform = 'whatsapp' AND timestamp > NOW() - INTERVAL '24 hours'`,
                [userId]
            );

            const stats = statsResult.rows[0] || {};

            return {
                connected: true,
                phoneNumber: connection.platform_user_id,
                unreadChats: parseInt(stats.unread_chats) || 0,
                pendingMessages: parseInt(stats.pending_messages) || 0,
                lastMessageAt: stats.last_message_at ? new Date(stats.last_message_at) : undefined,
            };
        } catch (err) {
            console.error('[Proactive Service] Error in getWhatsAppSummary:', err);
            return {
                connected: false,
                unreadChats: 0,
                pendingMessages: 0,
            };
        }
    }

    /**
     * Get scheduled tasks summary for a user.
     */
    async getTasksSummary(userId: string): Promise<TasksSummary> {
        try {
            // Get all enabled tasks
            const tasks = await gituTaskScheduler.listUserTasks(userId, true);
            const enabledTasks = tasks.filter(t => t.enabled);
            const failedTasks = tasks.filter(t => t.failureCount > 0);

            // Find next due task
            const now = new Date();
            const pendingTasks = enabledTasks
                .filter(t => t.nextRunAt && t.nextRunAt > now)
                .sort((a, b) => (a.nextRunAt?.getTime() || 0) - (b.nextRunAt?.getTime() || 0));

            const nextDueTask = pendingTasks.length > 0 ? {
                id: pendingTasks[0].id,
                name: pendingTasks[0].name,
                nextRunAt: pendingTasks[0].nextRunAt!,
            } : undefined;

            // Get recent executions
            const recentExecResult = await pool.query(
                `SELECT te.*, t.name as task_name
         FROM gitu_task_executions te
         JOIN gitu_scheduled_tasks t ON te.task_id = t.id
         WHERE t.user_id = $1
         ORDER BY te.executed_at DESC
         LIMIT 5`,
                [userId]
            );

            const recentExecutions = recentExecResult.rows.map(row => ({
                taskName: row.task_name,
                success: row.success,
                executedAt: new Date(row.executed_at),
            }));

            return {
                totalEnabled: enabledTasks.length,
                pendingCount: pendingTasks.length,
                nextDueTask,
                recentExecutions,
                failedTasksCount: failedTasks.length,
            };
        } catch (err) {
            console.error('[Proactive Service] Error in getTasksSummary:', err);
            return {
                totalEnabled: 0,
                pendingCount: 0,
                recentExecutions: [],
                failedTasksCount: 0,
            };
        }
    }

    /**
     * Generate smart suggestions based on user's data and patterns.
     */
    async generateSuggestions(userId: string): Promise<Suggestion[]> {
        const suggestions: Suggestion[] = [];
        const now = new Date();

        try {
            // Check Gmail connection and suggest if not connected
            const gmailConnected = await gituGmailManager.isConnected(userId);
            if (!gmailConnected) {
                suggestions.push({
                    id: `suggestion-gmail-connect-${Date.now()}`,
                    type: 'tip',
                    priority: 'medium',
                    title: 'Connect Gmail',
                    description: 'Connect your Gmail account to let Gitu help manage your emails and provide smart email insights.',
                    action: {
                        type: 'navigate',
                        params: { route: '/gitu/gmail-connect' },
                    },
                    createdAt: now,
                });
            }

            // Check for tasks with repeated failures
            const tasks = await gituTaskScheduler.listUserTasks(userId, true);
            const failingTasks = tasks.filter(t => t.failureCount >= 3 && t.enabled);

            for (const task of failingTasks.slice(0, 2)) {
                suggestions.push({
                    id: `suggestion-task-failing-${task.id}`,
                    type: 'task',
                    priority: 'high',
                    title: `Task "${task.name}" is failing`,
                    description: `This task has failed ${task.failureCount} times. Consider reviewing its configuration.`,
                    action: {
                        type: 'navigate',
                        params: { route: `/gitu/tasks/${task.id}` },
                    },
                    createdAt: now,
                });
            }

            // Check if user has no scheduled tasks - suggest automation
            if (tasks.length === 0) {
                suggestions.push({
                    id: `suggestion-create-task-${Date.now()}`,
                    type: 'automation',
                    priority: 'low',
                    title: 'Set up automation',
                    description: 'Create your first scheduled task to automate repetitive actions like sending reports or checking emails.',
                    action: {
                        type: 'navigate',
                        params: { route: '/gitu/tasks/create' },
                    },
                    createdAt: now,
                });
            }

            // Check Gmail for important unread emails
            if (gmailConnected) {
                const gmailSummary = await this.getGmailSummary(userId);
                if (gmailSummary.importantUnread > 3) {
                    suggestions.push({
                        id: `suggestion-gmail-important-${Date.now()}`,
                        type: 'email',
                        priority: 'high',
                        title: `${gmailSummary.importantUnread} important emails need attention`,
                        description: 'You have several important unread emails. Would you like Gitu to summarize them?',
                        action: {
                            type: 'ai_summarize_emails',
                            params: { filter: 'is:unread is:important' },
                        },
                        createdAt: now,
                    });
                }
            }

            // Check user's memory count and suggest saving more context
            const memories = await gituMemoryService.listMemories(userId, { limit: 10 });
            if (memories.length < 3) {
                suggestions.push({
                    id: `suggestion-memories-${Date.now()}`,
                    type: 'tip',
                    priority: 'low',
                    title: 'Help Gitu remember your preferences',
                    description: 'Share some information about yourself so Gitu can provide more personalized assistance.',
                    action: {
                        type: 'navigate',
                        params: { route: '/gitu/memory' },
                    },
                    createdAt: now,
                });
            }

            // Context-aware suggestions based on time of day
            const hour = now.getHours();
            if (hour >= 9 && hour <= 10) {
                suggestions.push({
                    id: `suggestion-morning-${now.toDateString()}`,
                    type: 'reminder',
                    priority: 'low',
                    title: 'Good morning! Start your day organized',
                    description: 'Would you like a summary of your tasks and emails for today?',
                    action: {
                        type: 'ai_daily_summary',
                    },
                    createdAt: now,
                    expiresAt: new Date(now.getTime() + 2 * 60 * 60 * 1000), // Expires in 2 hours
                });
            }

        } catch (err) {
            console.error('[Proactive Service] Error generating suggestions:', err);
        }

        return suggestions.sort((a, b) => {
            const priorityOrder = { high: 0, medium: 1, low: 2 };
            return priorityOrder[a.priority] - priorityOrder[b.priority];
        });
    }

    /**
     * Analyze user patterns and generate insights.
     * This is the AI-driven pattern analysis for future enhancements.
     */
    async analyzePatterns(userId: string): Promise<PatternInsight[]> {
        const patterns: PatternInsight[] = [];
        const now = new Date();

        try {
            // Analyze task execution patterns
            const taskExecResult = await pool.query(
                `SELECT 
           EXTRACT(HOUR FROM executed_at) as hour,
           COUNT(*) as count,
           AVG(CASE WHEN success THEN 1 ELSE 0 END) * 100 as success_rate
         FROM gitu_task_executions te
         JOIN gitu_scheduled_tasks t ON te.task_id = t.id
         WHERE t.user_id = $1 AND te.executed_at > NOW() - INTERVAL '30 days'
         GROUP BY EXTRACT(HOUR FROM executed_at)
         ORDER BY count DESC
         LIMIT 5`,
                [userId]
            );

            if (taskExecResult.rows.length >= 3) {
                const topHour = taskExecResult.rows[0];
                patterns.push({
                    id: `pattern-task-timing-${Date.now()}`,
                    type: 'usage',
                    title: 'Peak automation activity detected',
                    description: `Most of your tasks run around ${topHour.hour}:00 with ${Math.round(topHour.success_rate)}% success rate.`,
                    confidence: 0.85,
                    dataPoints: taskExecResult.rows.reduce((sum: number, r: any) => sum + parseInt(r.count), 0),
                    suggestedAction: topHour.success_rate < 80 ? 'Consider reviewing tasks that fail during this time.' : undefined,
                    createdAt: now,
                });
            }

            // Analyze notification/activity patterns
            const activityResult = await pool.query(
                `SELECT 
           EXTRACT(HOUR FROM created_at) as hour,
           COUNT(*) as count
         FROM notifications
         WHERE user_id = $1 AND created_at > NOW() - INTERVAL '14 days'
         GROUP BY EXTRACT(HOUR FROM created_at)
         ORDER BY count DESC
         LIMIT 3`,
                [userId]
            );

            if (activityResult.rows.length >= 2) {
                const peakHours = activityResult.rows.map((r: any) => r.hour);
                patterns.push({
                    id: `pattern-activity-${Date.now()}`,
                    type: 'behavior',
                    title: 'Your most active hours',
                    description: `You're typically most active around ${peakHours.slice(0, 2).join(':00 and ')}:00.`,
                    confidence: 0.75,
                    dataPoints: activityResult.rows.reduce((sum: number, r: any) => sum + parseInt(r.count), 0),
                    suggestedAction: 'Schedule important tasks during your peak hours for better attention.',
                    createdAt: now,
                });
            }

            // Check for automation opportunities
            const frequentActionsResult = await pool.query(
                `SELECT 
           CASE 
             WHEN jsonb_typeof(action) = 'object' THEN action ->> 'type' 
             ELSE action::text 
           END as action_type,
           COUNT(*) as count
         FROM gitu_scheduled_tasks
         WHERE user_id = $1 AND enabled = true
         GROUP BY 
           CASE 
             WHEN jsonb_typeof(action) = 'object' THEN action ->> 'type' 
             ELSE action::text 
           END
         ORDER BY count DESC
         LIMIT 3`,
                [userId]
            );

            if (frequentActionsResult.rows.length > 0) {
                const topAction = frequentActionsResult.rows[0];
                if (topAction.action_type && parseInt(topAction.count) >= 3) {
                    patterns.push({
                        id: `pattern-automation-${Date.now()}`,
                        type: 'opportunity',
                        title: 'Automation opportunity detected',
                        description: `You frequently use ${topAction.action_type} actions. Consider creating a template for faster setup.`,
                        confidence: 0.7,
                        dataPoints: parseInt(topAction.count),
                        createdAt: now,
                    });
                }
            }

        } catch (err) {
            console.error('[Proactive Service] Error analyzing patterns:', err);
        }

        return patterns.sort((a, b) => b.confidence - a.confidence);
    }

    /**
     * Record user activity for pattern analysis.
     */
    async recordActivity(userId: string, activityType: string, metadata?: Record<string, any>): Promise<void> {
        try {
            // Check if table exists first or just use a more generic table if available
            // For now, we'll use gitu_mission_logs as a temporary place or skip if table missing
            // This prevents the whole service from failing if the activity table isn't migrated yet
            await pool.query(
                `INSERT INTO gitu_mission_logs (id, mission_id, message, metadata, created_at)
                 VALUES (gen_random_uuid(), 'INTERNAL_ACTIVITY', $1, $2, NOW())`,
                [`Activity: ${activityType}`, JSON.stringify(metadata || {})]
            ).catch(() => {
                // Silently ignore if even this fails
            });
        } catch (err) {
            // Silently fail - activity recording is non-critical
        }
    }

    /**
     * Create a proactive notification for the user.
     */
    async createProactiveNotification(
        userId: string,
        type: 'suggestion' | 'insight' | 'reminder',
        title: string,
        message: string,
        actionUrl?: string
    ): Promise<void> {
        try {
            await pool.query(
                `INSERT INTO notifications (user_id, type, title, message, action_url, created_at)
         VALUES ($1, $2, $3, $4, $5, NOW())`,
                [userId, type, title, message, actionUrl]
            );
        } catch (err) {
            console.error('[Proactive Service] Error creating notification:', err);
        }
    }

    /**
     * Run periodic proactive checks for all users.
     * This can be called by a scheduled task.
     */
    async runProactiveChecks(): Promise<void> {
        console.log('[Proactive Service] Running proactive checks...');

        try {
            // Get all users with Gitu enabled
            const usersResult = await pool.query(
                `SELECT id as user_id,
                        COALESCE((gitu_settings->'proactive'->>'highPriorityOnly')::boolean, false) as high_priority_only
                 FROM users
                 WHERE gitu_enabled = true
                   AND (gitu_settings->'proactive'->>'enabled' IS NULL
                        OR (gitu_settings->'proactive'->>'enabled')::boolean = true)`
            );

            for (const row of usersResult.rows) {
                try {
                    const insights = await this.getProactiveInsights(row.user_id, false);

                    const highPriorityOnly = row.high_priority_only === true;
                    const candidateSuggestions = highPriorityOnly
                        ? insights.suggestions.filter(s => s.priority === 'high')
                        : insights.suggestions;

                    for (const suggestion of candidateSuggestions.slice(0, 2)) {
                        await this.createProactiveNotification(
                            row.user_id,
                            'suggestion',
                            suggestion.title,
                            suggestion.description,
                            suggestion.action?.params?.route
                        );
                    }
                } catch (err) {
                    console.error(`[Proactive Service] Error processing user ${row.user_id}:`, err);
                }
            }

            console.log('[Proactive Service] Proactive checks completed');
        } catch (err) {
            console.error('[Proactive Service] Error in runProactiveChecks:', err);
        }
    }

    /**
     * Clear cache for a user (call after user makes changes).
     */
    clearCache(userId: string): void {
        this.cache.delete(userId);
    }

    /**
     * Start a new Swarm Mission.
     */
    async startMission(userId: string, objective: string): Promise<Mission> {
        // Clear cache so UI updates immediately
        this.clearCache(userId);
        return gituAgentOrchestrator.createMission(userId, objective);
    }
}

// Export singleton instance
export const gituProactiveService = new GituProactiveService();
export default gituProactiveService;
