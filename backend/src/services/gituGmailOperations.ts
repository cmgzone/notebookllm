import axios from 'axios';
import { gituGmailManager } from './gituGmailManager.js';

function base64UrlEncode(input: string): string {
  const b64 = Buffer.from(input, 'utf8').toString('base64');
  return b64.replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
}

export function buildRawEmail(to: string, subject: string, body: string, from?: string): string {
  const headers = [
    `To: ${to}`,
    from ? `From: ${from}` : '',
    `Subject: ${subject}`,
    'Content-Type: text/plain; charset=UTF-8',
    '',
    body,
  ]
    .filter(Boolean)
    .join('\r\n');
  return base64UrlEncode(headers);
}

async function getAccessToken(userId: string): Promise<string> {
  const conn = await gituGmailManager.getConnection(userId);
  if (!conn) throw new Error('GMAIL_NOT_CONNECTED');
  return conn.access_token;
}

export async function listMessages(userId: string, query?: string, maxResults: number = 20) {
  const token = await getAccessToken(userId);
  const url = `https://gmail.googleapis.com/gmail/v1/users/me/messages`;
  const res = await axios.get(url, {
    params: { q: query, maxResults },
    headers: { Authorization: `Bearer ${token}` },
    timeout: 30000,
  });
  return res.data;
}

export async function getMessage(userId: string, id: string) {
  const token = await getAccessToken(userId);
  const url = `https://gmail.googleapis.com/gmail/v1/users/me/messages/${id}`;
  const res = await axios.get(url, {
    params: { format: 'full' },
    headers: { Authorization: `Bearer ${token}` },
    timeout: 30000,
  });
  return res.data;
}

export async function sendEmail(userId: string, to: string, subject: string, body: string, from?: string) {
  const token = await getAccessToken(userId);
  const raw = buildRawEmail(to, subject, body, from);
  const url = `https://gmail.googleapis.com/gmail/v1/users/me/messages/send`;
  const res = await axios.post(
    url,
    { raw },
    { headers: { Authorization: `Bearer ${token}` }, timeout: 30000 }
  );
  return res.data;
}

export async function listLabels(userId: string) {
  const token = await getAccessToken(userId);
  const url = `https://gmail.googleapis.com/gmail/v1/users/me/labels`;
  const res = await axios.get(url, {
    headers: { Authorization: `Bearer ${token}` },
    timeout: 30000,
  });
  return res.data;
}

export async function modifyMessageLabels(
  userId: string,
  id: string,
  addLabelIds?: string[],
  removeLabelIds?: string[]
) {
  const token = await getAccessToken(userId);
  const url = `https://gmail.googleapis.com/gmail/v1/users/me/messages/${id}/modify`;
  const res = await axios.post(
    url,
    { addLabelIds: addLabelIds || [], removeLabelIds: removeLabelIds || [] },
    { headers: { Authorization: `Bearer ${token}` }, timeout: 30000 }
  );
  return res.data;
}
