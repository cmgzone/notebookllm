import { describe, it, expect } from '@jest/globals';
import { GituAgentManager } from '../services/gituAgentManager.js';

describe('GituAgentManager swarm parsing', () => {
  const manager: any = new GituAgentManager();

  it('parses JSON envelope with toolCall', () => {
    const content = [
      '```json',
      JSON.stringify({
        status: 'continue',
        message: 'Running a tool',
        toolCall: { tool: 'deploy_swarm', args: { objective: 'x' } }
      }),
      '```',
    ].join('\n');

    const parsed = manager.tryParseAgentEnvelope(content);
    expect(parsed).toEqual({
      status: 'continue',
      message: 'Running a tool',
      toolCall: { tool: 'deploy_swarm', args: { objective: 'x' } }
    });
  });

  it('does not treat inline DONE as completion', () => {
    expect(manager.detectLegacyCompletionStatus('I am DONE with this soon')).toBeNull();
    expect(manager.detectLegacyCompletionStatus('  DONE\nsummary')).toBe('done');
  });

  it('parses legacy tool block', () => {
    const content = [
      '```tool',
      JSON.stringify({ tool: 'deploy_swarm', args: { objective: 'y' } }),
      '```',
    ].join('\n');

    expect(manager.tryParseLegacyToolCall(content)).toEqual({
      tool: 'deploy_swarm',
      args: { objective: 'y' }
    });
  });
});

