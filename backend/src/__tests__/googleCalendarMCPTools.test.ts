import { describe, it, expect } from '@jest/globals';
import { gituMCPHub } from '../services/gituMCPHub.js';
import { registerGoogleCalendarTools } from '../services/googleCalendarMCPTools.js';

describe('Google Calendar MCP Tools', () => {
  it('registers Google Calendar tools', async () => {
    registerGoogleCalendarTools();
    const tools = await gituMCPHub.listTools('user-123');
    const names = new Set(tools.map(t => t.name));

    expect(names.has('google_calendar_list_calendars')).toBe(true);
    expect(names.has('google_calendar_list_events')).toBe(true);
    expect(names.has('google_calendar_create_event')).toBe(true);
    expect(names.has('google_calendar_delete_event')).toBe(true);
  });
});

