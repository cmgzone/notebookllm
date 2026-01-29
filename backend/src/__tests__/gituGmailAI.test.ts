import { summarizeEmail, suggestReplies, extractActionItems, analyzeSentiment } from '../services/gituGmailAI.js';

const sample = `Subject: Project Update

Hi team,
- Please review the latest spec by Friday.
- Schedule a meeting next week.
Thanks!
`;

describe('GituGmailAI', () => {
  test('summarizeEmail returns subject, urgency and keyPoints', () => {
    const s = summarizeEmail(sample);
    expect(s.subject.toLowerCase()).toContain('project update');
    expect(['high', 'normal']).toContain(s.urgency);
    expect(s.keyPoints.length).toBeGreaterThan(0);
  });

  test('suggestReplies returns helpful replies', () => {
    const r = suggestReplies(sample);
    expect(Array.isArray(r)).toBe(true);
    expect(r.length).toBeGreaterThan(0);
  });

  test('extractActionItems finds bullet points', () => {
    const actions = extractActionItems(sample);
    expect(actions.some(a => a.toLowerCase().includes('review'))).toBe(true);
    expect(actions.some(a => a.toLowerCase().includes('schedule'))).toBe(true);
  });

  test('analyzeSentiment returns label', () => {
    const sent = analyzeSentiment(sample);
    expect(['positive', 'neutral', 'negative']).toContain(sent.label);
  });
});
