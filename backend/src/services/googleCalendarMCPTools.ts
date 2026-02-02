import { gituMCPHub, MCPTool, MCPContext } from './gituMCPHub.js';
import { createEvent, deleteEvent, listCalendars, listEvents } from './gituGoogleCalendarOperations.js';

const listCalendarsTool: MCPTool = {
    name: 'google_calendar_list_calendars',
    description: 'List Google Calendar calendars for the connected user.',
    schema: {
        type: 'object',
        properties: {}
    },
    handler: async (_args: any, context: MCPContext) => {
        return await listCalendars(context.userId);
    }
};

const listEventsTool: MCPTool = {
    name: 'google_calendar_list_events',
    description: 'List events from a Google Calendar in a time range.',
    schema: {
        type: 'object',
        properties: {
            calendarId: { type: 'string', description: 'Calendar ID (default: primary)' },
            timeMin: { type: 'string', description: 'ISO datetime (default: now)' },
            timeMax: { type: 'string', description: 'ISO datetime (default: now + 30 days)' },
            q: { type: 'string', description: 'Free-text search query (optional)' },
            maxResults: { type: 'number', description: 'Max results (default: 50, max: 250)' }
        }
    },
    handler: async (args: any, context: MCPContext) => {
        const { calendarId, timeMin, timeMax, q, maxResults } = args || {};
        return await listEvents(context.userId, { calendarId, timeMin, timeMax, q, maxResults });
    }
};

const createEventTool: MCPTool = {
    name: 'google_calendar_create_event',
    description: 'Create an event in Google Calendar.',
    schema: {
        type: 'object',
        properties: {
            calendarId: { type: 'string', description: 'Calendar ID (default: primary)' },
            summary: { type: 'string', description: 'Event title/summary' },
            description: { type: 'string', description: 'Event description (optional)' },
            location: { type: 'string', description: 'Event location (optional)' },
            start: { type: 'string', description: 'Start time ISO datetime' },
            end: { type: 'string', description: 'End time ISO datetime' },
            timeZone: { type: 'string', description: 'IANA timezone (optional, e.g. America/New_York)' },
            attendees: {
                type: 'array',
                description: 'Attendees (optional)',
                items: {
                    type: 'object',
                    properties: {
                        email: { type: 'string', description: 'Attendee email' }
                    },
                    required: ['email']
                }
            }
        },
        required: ['summary', 'start', 'end']
    },
    handler: async (args: any, context: MCPContext) => {
        return await createEvent(context.userId, args);
    }
};

const deleteEventTool: MCPTool = {
    name: 'google_calendar_delete_event',
    description: 'Delete an event from Google Calendar.',
    schema: {
        type: 'object',
        properties: {
            calendarId: { type: 'string', description: 'Calendar ID (default: primary)' },
            eventId: { type: 'string', description: 'Event ID' }
        },
        required: ['eventId']
    },
    handler: async (args: any, context: MCPContext) => {
        const { calendarId, eventId } = args || {};
        return await deleteEvent(context.userId, { calendarId, eventId });
    }
};

export function registerGoogleCalendarTools() {
    gituMCPHub.registerTool(listCalendarsTool);
    gituMCPHub.registerTool(listEventsTool);
    gituMCPHub.registerTool(createEventTool);
    gituMCPHub.registerTool(deleteEventTool);
    console.log('[GoogleCalendarMCPTools] Registered Google Calendar tools');
}

