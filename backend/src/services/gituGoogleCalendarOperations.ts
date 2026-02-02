import axios from 'axios';
import { gituGoogleCalendarManager } from './gituGoogleCalendarManager.js';

async function getAccessToken(userId: string): Promise<string> {
  const conn = await gituGoogleCalendarManager.getConnection(userId);
  if (!conn) throw new Error('GOOGLE_CALENDAR_NOT_CONNECTED');
  return conn.access_token;
}

function normalizeCalendarId(calendarId: string | undefined) {
  const id = (calendarId || 'primary').trim();
  return id.length > 0 ? id : 'primary';
}

export async function listCalendars(userId: string) {
  const token = await getAccessToken(userId);
  const url = `https://www.googleapis.com/calendar/v3/users/me/calendarList`;
  const res = await axios.get(url, {
    headers: { Authorization: `Bearer ${token}` },
    timeout: 30000,
  });
  return res.data;
}

export async function listEvents(userId: string, params: {
  calendarId?: string;
  timeMin?: string;
  timeMax?: string;
  q?: string;
  maxResults?: number;
}) {
  const token = await getAccessToken(userId);
  const calendarId = normalizeCalendarId(params.calendarId);
  const url = `https://www.googleapis.com/calendar/v3/calendars/${encodeURIComponent(calendarId)}/events`;

  const now = new Date();
  const defaultMin = now.toISOString();
  const defaultMax = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000).toISOString();

  const res = await axios.get(url, {
    headers: { Authorization: `Bearer ${token}` },
    timeout: 30000,
    params: {
      timeMin: params.timeMin || defaultMin,
      timeMax: params.timeMax || defaultMax,
      q: params.q,
      singleEvents: true,
      orderBy: 'startTime',
      maxResults: typeof params.maxResults === 'number' ? Math.min(Math.max(params.maxResults, 1), 250) : 50,
    },
  });
  return res.data;
}

export async function createEvent(userId: string, input: {
  calendarId?: string;
  summary: string;
  description?: string;
  location?: string;
  start: string;
  end: string;
  timeZone?: string;
  attendees?: Array<{ email: string }>;
}) {
  const token = await getAccessToken(userId);
  const calendarId = normalizeCalendarId(input.calendarId);
  const url = `https://www.googleapis.com/calendar/v3/calendars/${encodeURIComponent(calendarId)}/events`;

  const payload: any = {
    summary: input.summary,
    description: input.description,
    location: input.location,
    start: { dateTime: input.start, timeZone: input.timeZone },
    end: { dateTime: input.end, timeZone: input.timeZone },
  };
  if (Array.isArray(input.attendees) && input.attendees.length > 0) {
    payload.attendees = input.attendees;
  }

  const res = await axios.post(url, payload, {
    headers: { Authorization: `Bearer ${token}` },
    timeout: 30000,
  });
  return res.data;
}

export async function deleteEvent(userId: string, params: { calendarId?: string; eventId: string }) {
  const token = await getAccessToken(userId);
  const calendarId = normalizeCalendarId(params.calendarId);
  const url = `https://www.googleapis.com/calendar/v3/calendars/${encodeURIComponent(calendarId)}/events/${encodeURIComponent(params.eventId)}`;
  const res = await axios.delete(url, {
    headers: { Authorization: `Bearer ${token}` },
    timeout: 30000,
  });
  return { success: true, status: res.status };
}

