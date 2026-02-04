/**
 * Gitu Task Parser Service
 * Parses natural language into scheduled task definitions.
 * 
 * Supports patterns like:
 * - "remind me tomorrow at 3pm to call John"
 * - "every Monday at 9am send me a summary"
 * - "in 30 minutes remind me about the meeting"
 */

import { TaskTrigger, TaskAction } from './gituTaskScheduler.js';
import * as chrono from 'chrono-node';

export interface ParsedTask {
  name: string;
  trigger: TaskTrigger;
  action: TaskAction;
  description?: string;
}

export interface ParseResult {
  success: boolean;
  task?: ParsedTask;
  error?: string;
  confidence: number;  // 0-1
}

class GituTaskParser {
  /**
   * Parse natural language into a scheduled task.
   */
  parse(input: string, userId: string): ParseResult {
    const normalized = input.toLowerCase().trim();

    // Try different parsing strategies
    const strategies = [
      () => this.parseReminder(normalized),
      () => this.parseRecurring(normalized),
      () => this.parseInterval(normalized),
      () => this.parseSchedule(normalized),
    ];

    for (const strategy of strategies) {
      const result = strategy();
      if (result.success) {
        return result;
      }
    }

    return {
      success: false,
      error: 'Could not understand the task. Try: "remind me tomorrow at 3pm to call John" or "every Monday at 9am send summary"',
      confidence: 0,
    };
  }

  /**
   * Parse reminder patterns:
   * - "remind me tomorrow at 3pm to call John"
   * - "remind me in 30 minutes about the meeting"
   */
  private parseReminder(input: string): ParseResult {
    const remindPattern = /remind me (.+?) (?:to|about) (.+)/i;
    const match = input.match(remindPattern);

    if (!match) {
      return { success: false, confidence: 0 };
    }

    const timeStr = match[1];
    const what = match[2];

    // Parse time using chrono
    const parsed = chrono.parseDate(timeStr);
    if (!parsed) {
      return {
        success: false,
        error: `Could not understand time: "${timeStr}"`,
        confidence: 0.3,
      };
    }

    // Ensure time is in the future
    if (parsed <= new Date()) {
      parsed.setDate(parsed.getDate() + 1);
    }

    return {
      success: true,
      confidence: 0.9,
      task: {
        name: `Reminder: ${what}`,
        description: `Reminder created from: "${input}"`,
        trigger: {
          type: 'once',
          timestamp: parsed.toISOString(),
        },
        action: {
          type: 'send_message',
          message: `⏰ Reminder: ${what}`,
        },
      },
    };
  }

  /**
   * Parse recurring patterns:
   * - "every Monday at 9am send me a summary"
   * - "every day at 8pm remind me to exercise"
   * - "every week on Friday at 5pm"
   */
  private parseRecurring(input: string): ParseResult {
    const patterns = [
      // "every Monday at 9am do X"
      /every (monday|tuesday|wednesday|thursday|friday|saturday|sunday) at (\d{1,2}(?::\d{2})?\s*(?:am|pm)?) (.+)/i,
      // "every day at 9am do X"
      /every day at (\d{1,2}(?::\d{2})?\s*(?:am|pm)?) (.+)/i,
      // "daily at 9am do X"
      /daily at (\d{1,2}(?::\d{2})?\s*(?:am|pm)?) (.+)/i,
    ];

    for (const pattern of patterns) {
      const match = input.match(pattern);
      if (!match) continue;

      let dayOfWeek: number | undefined;
      let timeStr: string;
      let what: string;

      if (match.length === 4) {
        // Day-specific pattern
        const day = match[1].toLowerCase();
        dayOfWeek = this.dayToNumber(day);
        timeStr = match[2];
        what = match[3];
      } else {
        // Daily pattern
        timeStr = match[1];
        what = match[2];
      }

      const time = this.parseTime(timeStr);
      if (!time) {
        return {
          success: false,
          error: `Could not understand time: "${timeStr}"`,
          confidence: 0.3,
        };
      }

      // Build cron expression
      const cron = dayOfWeek !== undefined
        ? `${time.minute} ${time.hour} * * ${dayOfWeek}`  // Specific day
        : `${time.minute} ${time.hour} * * *`;  // Every day

      // Determine action type
      const action = this.inferAction(what);

      return {
        success: true,
        confidence: 0.95,
        task: {
          name: `Recurring: ${what}`,
          description: `Recurring task created from: "${input}"`,
          trigger: {
            type: 'cron',
            cron,
          },
          action,
        },
      };
    }

    return { success: false, confidence: 0 };
  }

  /**
   * Parse interval patterns:
   * - "every 30 minutes remind me to drink water"
   * - "every hour check my emails"
   */
  private parseInterval(input: string): ParseResult {
    // Pattern 1: "every N minutes/hours do X"
    let pattern = /every (\d+) (minute|minutes|hour|hours) (.+)/i;
    let match = input.match(pattern);

    if (!match) {
      // Pattern 2: "every hour/minute do X" (without number, implies 1)
      pattern = /every (hour|minute) (.+)/i;
      match = input.match(pattern);
      
      if (!match) {
        return { success: false, confidence: 0 };
      }

      const unit = match[1].toLowerCase();
      const what = match[2];
      const minutes = unit === 'hour' ? 60 : 1;

      const action = this.inferAction(what);

      return {
        success: true,
        confidence: 0.9,
        task: {
          name: `Every ${unit}: ${what}`,
          description: `Interval task created from: "${input}"`,
          trigger: {
            type: 'interval',
            intervalMinutes: minutes,
          },
          action,
        },
      };
    }

    const amount = parseInt(match[1]);
    const unit = match[2].toLowerCase();
    const what = match[3];

    const minutes = unit.startsWith('hour') ? amount * 60 : amount;

    const action = this.inferAction(what);

    return {
      success: true,
      confidence: 0.9,
      task: {
        name: `Every ${amount} ${unit}: ${what}`,
        description: `Interval task created from: "${input}"`,
        trigger: {
          type: 'interval',
          intervalMinutes: minutes,
        },
        action,
      },
    };
  }

  /**
   * Parse schedule patterns:
   * - "schedule a meeting reminder for tomorrow at 2pm"
   * - "schedule email summary for next Monday"
   */
  private parseSchedule(input: string): ParseResult {
    const pattern = /schedule (.+?) for (.+)/i;
    const match = input.match(pattern);

    if (!match) {
      return { success: false, confidence: 0 };
    }

    const what = match[1];
    const timeStr = match[2];

    const parsed = chrono.parseDate(timeStr);
    if (!parsed) {
      return {
        success: false,
        error: `Could not understand time: "${timeStr}"`,
        confidence: 0.3,
      };
    }

    // Ensure time is in the future
    if (parsed <= new Date()) {
      parsed.setDate(parsed.getDate() + 1);
    }

    const action = this.inferAction(what);

    return {
      success: true,
      confidence: 0.85,
      task: {
        name: `Scheduled: ${what}`,
        description: `Scheduled task created from: "${input}"`,
        trigger: {
          type: 'once',
          timestamp: parsed.toISOString(),
        },
        action,
      },
    };
  }

  /**
   * Infer action type from the task description.
   */
  private inferAction(what: string): TaskAction {
    const lower = what.toLowerCase();

    // Check for AI request keywords
    if (lower.includes('summary') || lower.includes('summarize')) {
      return {
        type: 'ai_request',
        prompt: `Generate a summary: ${what}`,
        metadata: { sendToUser: true },
      };
    }

    // Check for message keywords
    if (lower.includes('remind') || lower.includes('notify') || lower.includes('tell')) {
      return {
        type: 'send_message',
        message: what,
      };
    }

    // Default to message
    return {
      type: 'send_message',
      message: what,
    };
  }

  /**
   * Parse time string like "9am", "3:30pm", "14:00"
   */
  private parseTime(timeStr: string): { hour: number; minute: number } | null {
    const normalized = timeStr.toLowerCase().trim();

    // Try 12-hour format with am/pm
    const match12 = normalized.match(/(\d{1,2})(?::(\d{2}))?\s*(am|pm)/);
    if (match12) {
      let hour = parseInt(match12[1]);
      const minute = match12[2] ? parseInt(match12[2]) : 0;
      const period = match12[3];

      if (period === 'pm' && hour !== 12) hour += 12;
      if (period === 'am' && hour === 12) hour = 0;

      return { hour, minute };
    }

    // Try 24-hour format
    const match24 = normalized.match(/(\d{1,2}):(\d{2})/);
    if (match24) {
      return {
        hour: parseInt(match24[1]),
        minute: parseInt(match24[2]),
      };
    }

    return null;
  }

  /**
   * Convert day name to cron day number (0 = Sunday, 6 = Saturday)
   */
  private dayToNumber(day: string): number {
    const days: Record<string, number> = {
      sunday: 0,
      monday: 1,
      tuesday: 2,
      wednesday: 3,
      thursday: 4,
      friday: 5,
      saturday: 6,
    };
    return days[day.toLowerCase()] ?? 1;
  }

  /**
   * Get examples of supported patterns.
   */
  getExamples(): string[] {
    return [
      'remind me tomorrow at 3pm to call John',
      'remind me in 30 minutes about the meeting',
      'every Monday at 9am send me a summary',
      'every day at 8pm remind me to exercise',
      'every 30 minutes remind me to drink water',
      'every hour check my emails',
      'schedule a meeting reminder for tomorrow at 2pm',
      'schedule email summary for next Monday at 10am',
    ];
  }
}

// Export singleton instance
export const gituTaskParser = new GituTaskParser();
export default gituTaskParser;
