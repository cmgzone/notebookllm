// Lightweight AI helpers for Gmail features with test-friendly heuristics
// In production, these can be wired to OpenRouter/Gemini providers when keys exist.

function normalize(text: string): string {
  return text.replace(/\s+/g, ' ').trim();
}

export function summarizeEmail(text: string) {
  const t = normalize(text);
  const sentences = t.split(/(?<=[.!?])\s+/).filter(s => s.length > 0);
  const keyPoints = sentences.slice(0, 3);
  const urgency =
    /\b(urgent|asap|immediately|deadline|today|tomorrow)\b/i.test(t) ? 'high' : 'normal';
  const subjectGuess =
    (t.match(/subject:\s*([^\n]+)/i)?.[1] ||
      t.slice(0, 80)).trim();
  return {
    subject: subjectGuess,
    urgency,
    keyPoints,
  };
}

export function suggestReplies(text: string) {
  const t = normalize(text).toLowerCase();
  const replies: string[] = [];
  if (/\b(thank|appreciate)\b/.test(t)) {
    replies.push('Thanks for the update! Much appreciated.');
  }
  if (/\bmeeting|schedule|call\b/.test(t)) {
    replies.push('Happy to schedule a meeting. Does tomorrow 10am work?');
  }
  if (/\bquestion|clarify|details|more info\b/.test(t)) {
    replies.push('Could you share more details on the requirements and timeline?');
  }
  if (replies.length === 0) {
    replies.push('Received. I will get back to you shortly.');
  }
  return replies.slice(0, 3);
}

export function extractActionItems(text: string) {
  const lines = text.split(/\n+/).map(l => l.trim()).filter(Boolean);
  const actions = lines
    .filter(l => /^[\-\*\d\)]\s*/.test(l) || /^[A-Z][a-z].*(?: by | before | on )/i.test(l))
    .map(l => l.replace(/^[\-\*\d\)\s]+/, ''))
    .slice(0, 5);
  // Fallback: pick imperative sentences
  if (actions.length === 0) {
    const sentences = text.split(/(?<=[.!?])\s+/);
    sentences.forEach(s => {
      if (/^(please|kindly|\breview\b|\bsend\b|\bprovide\b|\bupdate\b)/i.test(s)) {
        actions.push(s.trim());
      }
    });
  }
  return actions;
}

export function analyzeSentiment(text: string) {
  const t = normalize(text).toLowerCase();
  const positiveWords = ['great', 'good', 'thanks', 'appreciate', 'happy', 'pleased'];
  const negativeWords = ['bad', 'problem', 'issue', 'unfortunately', 'concern', 'delay'];
  const pos = positiveWords.reduce((acc, w) => acc + (t.includes(w) ? 1 : 0), 0);
  const neg = negativeWords.reduce((acc, w) => acc + (t.includes(w) ? 1 : 0), 0);
  const score = pos - neg;
  const label = score > 0 ? 'positive' : score < 0 ? 'negative' : 'neutral';
  return { score, label };
}

