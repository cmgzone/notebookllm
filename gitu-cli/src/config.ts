import Conf from 'conf';
import { homedir } from 'os';
import { join } from 'path';

export interface GituConfig {
  apiToken?: string;
  apiUrl?: string;
  userId?: string;
  deviceId?: string;
  defaultFormat?: string;
}

export class ConfigManager {
  private config: Conf<GituConfig>;

  constructor() {
    this.config = new Conf<GituConfig>({
      projectName: 'gitu',
      cwd: join(homedir(), '.gitu'),
      defaults: {
        apiUrl: 'https://notebookllm-ufj7.onrender.com/api',
        defaultFormat: 'terminal'
      }
    });
  }

  get(key: keyof GituConfig): any {
    return this.config.get(key);
  }

  set(key: keyof GituConfig, value: any): void {
    this.config.set(key, value);
  }

  getAll(): GituConfig {
    return this.config.store;
  }

  reset(): void {
    this.config.clear();
  }

  has(key: keyof GituConfig): boolean {
    return this.config.has(key);
  }
}
