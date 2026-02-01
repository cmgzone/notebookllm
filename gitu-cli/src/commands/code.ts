import { ApiClient } from '../api.js';
import { ConfigManager } from '../config.js';
import { MissionCommand } from './mission.js';

export class CodeCommand {
  static async start(api: ApiClient, _config: ConfigManager, objective: string, options: any) {
    const enrichedObjective =
      `You are an autonomous coding agent working inside this repository. ` +
      `Goal: ${objective}\n` +
      `Rules: make minimal changes, keep code style, run tests/build, and report what changed. ` +
      `Use shell and file tools only if permissions allow.`;

    return MissionCommand.start(api, enrichedObjective, options);
  }
}

