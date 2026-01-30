/**
 * Terminal CLI Adapter for Gitu
 * Handles terminal/CLI integration for the Gitu universal AI assistant.
 * Provides a REPL (Read-Eval-Print Loop) interface for command-line interaction.
 * 
 * Requirements: US-1 (Multi-Platform Access), Task 1.3.3 (Terminal CLI Adapter)
 * Design: Section 1 (Message Gateway - Terminal Adapter)
 */

import readline from 'readline';
import chalk from 'chalk';
import ora, { Ora } from 'ora';
import os from 'os';
import crypto from 'crypto';
import fs from 'fs/promises';
import path from 'path';
import WebSocket from 'ws';
import qrcode from 'qrcode-terminal';
import { gituMessageGateway, IncomingMessage, RawMessage } from '../services/gituMessageGateway.js';
import { gituSessionService } from '../services/gituSessionService.js';
import { gituTerminalService } from '../services/gituTerminalService.js';
import { gituAIRouter } from '../services/gituAIRouter.js';
import { gituShellManager } from '../services/gituShellManager.js';
import pool from '../config/database.js';

// ==================== INTERFACES ====================

/**
 * Terminal adapter configuration
 */
export interface TerminalAdapterConfig {
  userId?: string;  // Optional - can be set via auth
  prompt?: string;
  historySize?: number;
  colorOutput?: boolean;
}

/**
 * Credentials stored locally
 */
interface StoredCredentials {
  authToken: string;
  userId: string;
  deviceId: string;
  deviceName: string;
  expiresAt: string;
}

/**
 * Command result
 */
export interface CommandResult {
  success: boolean;
  output?: string;
  error?: string;
}

/**
 * Progress indicator
 */
export interface ProgressIndicator {
  task: string;
  progress: number;  // 0-100
  status: 'running' | 'completed' | 'failed';
}

// ==================== ADAPTER CLASS ====================

class TerminalAdapter {
  private rl: readline.Interface | null = null;
  private initialized: boolean = false;
  private config: TerminalAdapterConfig | null = null;
  private spinner: Ora | null = null;
  private commandHistory: string[] = [];
  private messageHandlers: ((message: IncomingMessage) => void | Promise<void>)[] = [];
  private credentials: StoredCredentials | null = null;
  private deviceId: string;
  private credentialsPath: string;

  constructor() {
    // Generate or load device ID
    this.deviceId = this.generateDeviceId();
    this.credentialsPath = path.join(os.homedir(), '.gitu', 'credentials.json');
  }

  /**
   * Initialize the terminal REPL interface.
   * 
   * @param config - Terminal adapter configuration
   */
  async initialize(config: TerminalAdapterConfig): Promise<void> {
    if (this.initialized) {
      console.log(chalk.yellow('Terminal adapter already initialized'));
      return;
    }

    this.config = {
      prompt: config.prompt || chalk.cyan('Gitu> '),
      historySize: config.historySize || 100,
      colorOutput: config.colorOutput !== false,
      userId: config.userId,
    };

    // Try to load stored credentials
    await this.loadCredentials();

    // If userId provided, verify user exists
    if (this.config.userId) {
      await this.verifyUser(this.config.userId);
    } else if (this.credentials) {
      // Use userId from credentials
      this.config.userId = this.credentials.userId;
      await this.verifyUser(this.config.userId);
    }

    // Create readline interface
    this.rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout,
      prompt: this.config.prompt,
      historySize: this.config.historySize,
    });

    // Set up event handlers
    this.setupEventHandlers();

    this.initialized = true;
    
    // Display welcome message
    this.displayWelcome();
  }

  /**
   * Verify that the user exists in the database.
   */
  private async verifyUser(userId: string): Promise<void> {
    const result = await pool.query(
      'SELECT id FROM users WHERE id = $1',
      [userId]
    );

    if (result.rows.length === 0) {
      throw new Error(`User not found: ${userId}`);
    }
  }

  /**
   * Set up readline event handlers.
   */
  private setupEventHandlers(): void {
    if (!this.rl) {
      throw new Error('Readline interface not initialized');
    }

    // Handle line input
    this.rl.on('line', async (line: string) => {
      const input = line.trim();

      if (!input) {
        this.rl?.prompt();
        return;
      }

      // Add to history
      this.commandHistory.push(input);
      if (this.commandHistory.length > (this.config?.historySize || 100)) {
        this.commandHistory.shift();
      }

      // Handle built-in commands
      if (await this.handleBuiltInCommand(input)) {
        this.rl?.prompt();
        return;
      }

      // Process as Gitu message
      await this.handleUserInput(input);
      
      this.rl?.prompt();
    });

    // Handle CTRL+C
    this.rl.on('SIGINT', () => {
      this.rl?.question(chalk.yellow('\nAre you sure you want to exit? (y/n) '), (answer) => {
        if (answer.toLowerCase() === 'y' || answer.toLowerCase() === 'yes') {
          this.shutdown();
        } else {
          this.rl?.prompt();
        }
      });
    });

    // Handle close
    this.rl.on('close', () => {
      this.shutdown();
    });
  }

  /**
   * Display welcome message.
   */
  private displayWelcome(): void {
    if (!this.config?.colorOutput) {
      console.log('\n=== Gitu Terminal CLI ===');
      console.log('Type "help" for available commands, "exit" to quit.\n');
      
      if (!this.credentials) {
        console.log('⚠️  Not authenticated. Run "gitu auth <token>" to link this terminal.\n');
      }
      return;
    }

    console.log(chalk.bold.cyan('\n╔════════════════════════════════════════╗'));
    console.log(chalk.bold.cyan('║     🤖 Gitu Terminal CLI v1.0         ║'));
    console.log(chalk.bold.cyan('╚════════════════════════════════════════╝\n'));
    console.log(chalk.gray('Your universal AI assistant in the terminal.'));
    console.log(chalk.gray('Type'), chalk.yellow('help'), chalk.gray('for commands,'), chalk.yellow('exit'), chalk.gray('to quit.\n'));
    
    if (!this.credentials) {
      console.log(chalk.yellow('⚠️  Not authenticated. Run'), chalk.cyan('gitu auth <token>'), chalk.yellow('to link this terminal.\n'));
    } else {
      console.log(chalk.green('✅ Authenticated as user:'), this.credentials.userId);
      console.log(chalk.gray('Device:'), this.credentials.deviceName, '\n');
    }
  }

  /**
   * Generate or load device ID
   */
  private generateDeviceId(): string {
    const hostname = os.hostname();
    const username = os.userInfo().username;
    const platform = os.platform();
    
    // Create a stable device ID based on machine characteristics
    const hash = crypto.createHash('sha256');
    hash.update(`${hostname}-${username}-${platform}`);
    return hash.digest('hex').substring(0, 16);
  }

  /**
   * Load stored credentials from disk
   */
  private async loadCredentials(): Promise<void> {
    try {
      const data = await fs.readFile(this.credentialsPath, 'utf-8');
      this.credentials = JSON.parse(data);
      
      // Validate token is not expired
      if (this.credentials && new Date(this.credentials.expiresAt) < new Date()) {
        console.log(chalk.yellow('⚠️  Auth token expired. Please re-authenticate.\n'));
        this.credentials = null;
        await this.deleteCredentials();
      }
    } catch (error) {
      // No credentials file or invalid JSON - that's okay
      this.credentials = null;
    }
  }

  /**
   * Save credentials to disk
   */
  private async saveCredentials(credentials: StoredCredentials): Promise<void> {
    try {
      // Ensure .gitu directory exists
      const dir = path.dirname(this.credentialsPath);
      await fs.mkdir(dir, { recursive: true });
      
      // Write credentials
      await fs.writeFile(this.credentialsPath, JSON.stringify(credentials, null, 2), 'utf-8');
      
      // Set restrictive permissions (owner read/write only)
      await fs.chmod(this.credentialsPath, 0o600);
      
      this.credentials = credentials;
    } catch (error) {
      throw new Error(`Failed to save credentials: ${(error as Error).message}`);
    }
  }

  /**
   * Delete stored credentials
   */
  private async deleteCredentials(): Promise<void> {
    try {
      await fs.unlink(this.credentialsPath);
      this.credentials = null;
    } catch (error) {
      // File doesn't exist - that's okay
    }
  }

  /**
   * Handle auth commands
   */
  private async handleAuthCommand(args: string[]): Promise<boolean> {
    if (args.length === 0) {
      console.log(chalk.yellow('\nUsage:'));
      console.log(chalk.cyan('  gitu auth <token>'), chalk.gray('- Link terminal with pairing token'));
      console.log(chalk.cyan('  gitu auth --qr'), chalk.gray('- Link terminal with QR code'));
      console.log(chalk.cyan('  gitu auth status'), chalk.gray('- Check authentication status'));
      console.log(chalk.cyan('  gitu auth logout'), chalk.gray('- Unlink terminal'));
      console.log(chalk.cyan('  gitu auth refresh'), chalk.gray('- Refresh auth token\n'));
      return true;
    }

    const subcommand = args[0].toLowerCase();

    switch (subcommand) {
      case '--qr':
      case '-qr':
      case 'qr':
      case '-q':  // Alias
      case '--q': // Alias
        await this.handleAuthQR();
        return true;

      case 'status':
        await this.handleAuthStatus();
        return true;

      case 'logout':
        await this.handleAuthLogout();
        return true;

      case 'refresh':
        await this.handleAuthRefresh();
        return true;

      default:
        // If it starts with a dash, it's likely a mistyped flag
        if (subcommand.startsWith('-')) {
             console.log(chalk.red(`\n❌ Unknown flag: ${subcommand}`));
             console.log(chalk.yellow('Did you mean --qr?'));
             console.log(chalk.gray('Usage:'), chalk.cyan('gitu auth <token>'), chalk.gray('or'), chalk.cyan('gitu auth --qr\n'));
             return true;
        }

        // Assume it's a pairing token
        await this.handleAuthLink(args[0]);
        return true;
    }
  }

  /**
   * Handle: gitu auth <token>
   */
  private async handleAuthLink(token: string): Promise<void> {
    try {
      this.startSpinner('Linking terminal...');

      const deviceName = `${os.hostname()} (${os.platform()})`;
      
      const result = await gituTerminalService.linkTerminal(
        token,
        this.deviceId,
        deviceName
      );

      this.stopSpinner(true);

      // Save credentials
      await this.saveCredentials({
        authToken: result.authToken,
        userId: result.userId,
        deviceId: this.deviceId,
        deviceName,
        expiresAt: result.expiresAt.toISOString()
      });

      // Update config
      if (this.config) {
        this.config.userId = result.userId;
      }

      console.log(chalk.green('\n✅ Terminal linked successfully!'));
      console.log(chalk.gray('User ID:'), result.userId);
      console.log(chalk.gray('Device:'), deviceName);
      console.log(chalk.gray('Token expires:'), result.expiresAt.toLocaleString());
      console.log(chalk.gray('Valid for:'), result.expiresInDays, 'days\n');
    } catch (error) {
      this.stopSpinner(false);
      console.log(chalk.red('\n❌ Failed to link terminal:', (error as Error).message));
      console.log(chalk.yellow('Make sure you have a valid pairing token from the Gitu app.\n'));
    }
  }

  /**
   * Handle: gitu auth --qr
   * Authenticate using QR code scanning
   */
  private async handleAuthQR(): Promise<void> {
    console.log(chalk.cyan('\n🔐 QR Code Authentication\n'));
    console.log(chalk.gray('Connecting to authentication service...'));

    const deviceName = `${os.hostname()} (${os.platform()})`;
    
    // Determine WebSocket URL based on environment
    const backendUrl = process.env.BACKEND_URL || 'http://localhost:3000';
    const wsProtocol = backendUrl.startsWith('https') || backendUrl.startsWith('wss') || process.env.NODE_ENV === 'production' ? 'wss' : 'ws';
    const wsHost = backendUrl.replace(/^(https?|wss?):\/\//, '').replace(/\/$/, '');
    const wsUrl = `${wsProtocol}://${wsHost}/api/gitu/terminal/qr-auth?deviceId=${encodeURIComponent(this.deviceId)}&deviceName=${encodeURIComponent(deviceName)}`;

    let ws: WebSocket | null = null;
    let authCompleted = false;

    try {
      // Connect to WebSocket
      ws = new WebSocket(wsUrl);

      // Handle connection open
      ws.on('open', () => {
        console.log(chalk.green('✓ Connected to authentication service\n'));
      });

      // Handle incoming messages
      ws.on('message', async (data: Buffer) => {
        try {
          const message = JSON.parse(data.toString());

          switch (message.type) {
            case 'qr_data':
              // Display QR code
              console.log(chalk.cyan('📱 Scan this QR code in the NotebookLLM app:\n'));
              
              // Generate and display QR code in terminal
              qrcode.generate(message.payload.qrData, { small: true });
              
              console.log(chalk.gray('\nSession ID:'), message.payload.sessionId);
              console.log(chalk.gray('Expires in:'), message.payload.expiresInSeconds, 'seconds');
              console.log(chalk.yellow('\n⏳ Waiting for you to scan the QR code...\n'));
              break;

            case 'status_update':
              if (message.payload.status === 'scanned') {
                console.log(chalk.green('✓ QR code scanned!'));
                console.log(chalk.gray(message.payload.message));
              } else if (message.payload.status === 'expired') {
                console.log(chalk.red('\n❌ QR code expired'));
                console.log(chalk.yellow('Please try again with'), chalk.cyan('gitu auth --qr\n'));
                console.log(chalk.gray('If QR keeps failing, generate a pairing token in the app and run'), chalk.cyan('gitu auth <token>\n'));
                authCompleted = true;
                ws?.close();
              } else if (message.payload.status === 'rejected') {
                console.log(chalk.red('\n❌ Authentication rejected'));
                console.log(chalk.gray(message.payload.message, '\n'));
                authCompleted = true;
                ws?.close();
              }
              break;

            case 'auth_token':
              // Save credentials
              await this.saveCredentials({
                authToken: message.payload.authToken,
                userId: message.payload.userId,
                deviceId: this.deviceId,
                deviceName,
                expiresAt: message.payload.expiresAt
              });

              // Update config
              if (this.config) {
                this.config.userId = message.payload.userId;
              }

              console.log(chalk.green('\n✅ Authentication successful!'));
              console.log(chalk.gray('User ID:'), message.payload.userId);
              console.log(chalk.gray('Device:'), deviceName);
              console.log(chalk.gray('Token expires:'), new Date(message.payload.expiresAt).toLocaleString());
              console.log(chalk.gray('Valid for:'), message.payload.expiresInDays, 'days\n');
              
              authCompleted = true;
              break;

            case 'error':
              console.log(chalk.red('\n❌ Error:'), message.payload.error, '\n');
              authCompleted = true;
              ws?.close();
              break;

            case 'pong':
              // Heartbeat response, ignore
              break;

            default:
              console.log(chalk.yellow('Unknown message type:'), message.type);
          }
        } catch (error) {
          console.error(chalk.red('Error processing message:'), error);
        }
      });

      // Handle connection close
      ws.on('close', (code: number, reason: Buffer) => {
        if (!authCompleted) {
          console.log(chalk.yellow('\n⚠️  Connection closed'));
          if (reason.length > 0) {
            console.log(chalk.gray('Reason:'), reason.toString());
          }
          console.log(chalk.gray('If QR auth fails, you can always use a pairing token from the app with'), chalk.cyan('gitu auth <token>'));
          console.log();
        }
      });

      // Handle errors
      ws.on('error', (error: Error) => {
        console.log(chalk.red('\n❌ WebSocket error:'), error.message);
        console.log(chalk.yellow('Make sure the backend server is running.\n'));
        console.log(chalk.gray('Fallback: open NotebookLLM app → Terminal Connections → Generate Token, then run'), chalk.cyan('gitu auth <token>\n'));
      });

      // Send periodic pings to keep connection alive
      const pingInterval = setInterval(() => {
        if (ws?.readyState === WebSocket.OPEN) {
          ws.send(JSON.stringify({ type: 'ping' }));
        } else {
          clearInterval(pingInterval);
        }
      }, 30000); // Ping every 30 seconds

      // Wait for authentication to complete or timeout
      await new Promise<void>((resolve) => {
        const checkInterval = setInterval(() => {
          if (authCompleted || ws?.readyState === WebSocket.CLOSED) {
            clearInterval(checkInterval);
            clearInterval(pingInterval);
            resolve();
          }
        }, 500);

        // Timeout after 3 minutes
        setTimeout(() => {
          if (!authCompleted) {
            console.log(chalk.yellow('\n⏱️  Authentication timeout'));
            console.log(chalk.gray('Please try again.\n'));
            console.log(chalk.gray('Fallback: generate a pairing token in the app and run'), chalk.cyan('gitu auth <token>\n'));
            clearInterval(checkInterval);
            clearInterval(pingInterval);
            ws?.close();
            resolve();
          }
        }, 3 * 60 * 1000);
      });

    } catch (error) {
      console.log(chalk.red('\n❌ Failed to connect:'), (error as Error).message);
      console.log(chalk.yellow('Make sure the backend server is running and accessible.\n'));
    } finally {
      if (ws && ws.readyState === WebSocket.OPEN) {
        ws.close();
      }
    }
  }

  /**
   * Handle: gitu auth status
   */
  private async handleAuthStatus(): Promise<void> {
    if (!this.credentials) {
      console.log(chalk.yellow('\n⚠️  Not authenticated'));
      console.log(chalk.gray('Run'), chalk.cyan('gitu auth <token>'), chalk.gray('to link this terminal.\n'));
      return;
    }

    try {
      this.startSpinner('Checking authentication status...');

      const validation = await gituTerminalService.validateAuthToken(this.credentials.authToken);

      this.stopSpinner(true);

      if (validation.valid) {
        const expiresAt = new Date(this.credentials.expiresAt);
        const daysUntilExpiry = Math.ceil((expiresAt.getTime() - Date.now()) / (1000 * 60 * 60 * 24));

        console.log(chalk.green('\n✅ Authenticated'));
        console.log(chalk.gray('User ID:'), validation.userId);
        console.log(chalk.gray('Device ID:'), validation.deviceId);
        console.log(chalk.gray('Device Name:'), this.credentials.deviceName);
        console.log(chalk.gray('Token expires:'), expiresAt.toLocaleString());
        console.log(chalk.gray('Days remaining:'), daysUntilExpiry);
        
        if (daysUntilExpiry < 7) {
          console.log(chalk.yellow('\n⚠️  Token expires soon. Run'), chalk.cyan('gitu auth refresh'), chalk.yellow('to renew.'));
        }
        console.log();
      } else {
        console.log(chalk.red('\n❌ Authentication invalid:', validation.error));
        console.log(chalk.yellow('Run'), chalk.cyan('gitu auth <token>'), chalk.yellow('to re-authenticate.\n'));
        await this.deleteCredentials();
      }
    } catch (error) {
      this.stopSpinner(false);
      console.log(chalk.red('\n❌ Error checking status:', (error as Error).message, '\n'));
    }
  }

  /**
   * Handle: gitu auth logout
   */
  private async handleAuthLogout(): Promise<void> {
    if (!this.credentials) {
      console.log(chalk.yellow('\n⚠️  Not authenticated\n'));
      return;
    }

    try {
      this.startSpinner('Unlinking terminal...');

      await gituTerminalService.unlinkTerminal(this.credentials.userId, this.deviceId);
      await this.deleteCredentials();

      this.stopSpinner(true);

      console.log(chalk.green('\n✅ Terminal unlinked successfully'));
      console.log(chalk.gray('You can re-authenticate anytime with'), chalk.cyan('gitu auth <token>\n'));

      // Clear userId from config
      if (this.config) {
        this.config.userId = undefined;
      }
    } catch (error) {
      this.stopSpinner(false);
      console.log(chalk.red('\n❌ Failed to unlink:', (error as Error).message, '\n'));
    }
  }

  /**
   * Handle: gitu auth refresh
   */
  private async handleAuthRefresh(): Promise<void> {
    if (!this.credentials) {
      console.log(chalk.yellow('\n⚠️  Not authenticated'));
      console.log(chalk.gray('Run'), chalk.cyan('gitu auth <token>'), chalk.gray('to link this terminal.\n'));
      return;
    }

    try {
      this.startSpinner('Refreshing auth token...');

      const result = await gituTerminalService.refreshAuthToken(this.credentials.authToken);

      this.stopSpinner(true);

      // Update credentials
      await this.saveCredentials({
        ...this.credentials,
        authToken: result.authToken,
        expiresAt: result.expiresAt.toISOString()
      });

      console.log(chalk.green('\n✅ Auth token refreshed successfully!'));
      console.log(chalk.gray('New expiry:'), result.expiresAt.toLocaleString());
      console.log(chalk.gray('Valid for:'), result.expiresInDays, 'days\n');
    } catch (error) {
      this.stopSpinner(false);
      console.log(chalk.red('\n❌ Failed to refresh token:', (error as Error).message));
      console.log(chalk.yellow('You may need to re-authenticate with'), chalk.cyan('gitu auth <token>\n'));
    }
  }

  /**
   * Handle built-in commands (help, exit, clear, etc.).
   * 
   * @param input - User input
   * @returns true if command was handled, false otherwise
   */
  private async handleBuiltInCommand(input: string): Promise<boolean> {
    const parts = input.trim().split(/\s+/);
    const command = parts[0].toLowerCase();
    const args = parts.slice(1);

    // Handle 'gitu auth' commands
    if (command === 'gitu' && args.length > 0 && args[0].toLowerCase() === 'auth') {
      return await this.handleAuthCommand(args.slice(1));
    }

    switch (command) {
      case 'help':
      case '?':
        this.displayHelp();
        return true;

      case 'exit':
      case 'quit':
      case 'q':
        this.shutdown();
        return true;

      case 'clear':
      case 'cls':
        console.clear();
        this.displayWelcome();
        return true;

      case 'history':
        this.displayHistory();
        return true;

      case 'status':
        await this.displayStatus();
        return true;

      case 'session':
        await this.displaySession();
        return true;

      case 'clear-session':
        await this.clearSession();
        return true;

      case 'model':
        await this.handleModelCommand(args);
        return true;

      case 'run':
        await this.handleRunCommand(args);
        return true;

      default:
        return false;
    }
  }

  private parseRunArgs(args: string[]) {
    const stopIndex = args.indexOf('--');
    const before = stopIndex >= 0 ? args.slice(0, stopIndex) : args;
    const after = stopIndex >= 0 ? args.slice(stopIndex + 1) : [];

    let sandboxed = true;
    let cwd: string | undefined;
    let timeoutMs: number | undefined;
    let dryRun = false;
    let json = false;

    const commandTokens: string[] = [];

    const consumeKnownFlags = (tokens: string[]) => {
      for (let i = 0; i < tokens.length; i++) {
        const t = tokens[i];
        if (!t.startsWith('--')) {
          commandTokens.push(t, ...tokens.slice(i + 1));
          return;
        }

        if (t === '--no-sandbox') {
          sandboxed = false;
          continue;
        }

        if (t === '--sandbox') {
          sandboxed = true;
          continue;
        }

        if (t === '--dry-run') {
          dryRun = true;
          continue;
        }

        if (t === '--json') {
          json = true;
          continue;
        }

        if (t === '--cwd') {
          const v = tokens[i + 1];
          if (typeof v === 'string' && v.trim().length > 0) {
            cwd = v.trim();
            i++;
            continue;
          }
        }

        if (t === '--timeout') {
          const v = tokens[i + 1];
          const n = Number(v);
          if (Number.isFinite(n) && n > 0) {
            timeoutMs = n;
            i++;
            continue;
          }
        }
      }
    };

    consumeKnownFlags(before);

    if (after.length > 0) {
      commandTokens.push(...after);
    }

    if (commandTokens.length === 0) {
      return { ok: false as const, sandboxed, cwd, timeoutMs, dryRun, json };
    }

    return {
      ok: true as const,
      sandboxed,
      cwd,
      timeoutMs,
      dryRun,
      json,
      command: commandTokens[0],
      args: commandTokens.slice(1),
    };
  }

  private async handleRunCommand(args: string[]): Promise<void> {
    if (!this.credentials) {
      console.log(chalk.yellow('\n⚠️  Not authenticated'));
      console.log(chalk.gray('Run'), chalk.cyan('gitu auth <token>'), chalk.gray('to link this terminal.\n'));
      return;
    }

    const parsed = this.parseRunArgs(args);
    if (!parsed.ok) {
      console.log(chalk.red('\n❌ Missing command'));
      console.log(
        chalk.gray('Usage:'),
        chalk.cyan('run [--sandbox|--no-sandbox] [--cwd <path>] [--timeout <ms>] [--dry-run] [--json] -- <command> [args...]'),
        '\n'
      );
      return;
    }

    try {
      this.startSpinner('Running command...');
      const result = await gituShellManager.execute(this.credentials.userId, {
        command: parsed.command,
        args: parsed.args,
        cwd: parsed.cwd,
        timeoutMs: parsed.timeoutMs,
        sandboxed: parsed.sandboxed,
        dryRun: parsed.dryRun,
      });
      this.stopSpinner(result.success);

      if (parsed.json) {
        process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
        return;
      }

      if (!result.success) {
        console.log(chalk.red('\n❌ Command blocked or failed'));
        console.log(chalk.gray('Error:'), result.error);
        if (result.auditLogId) console.log(chalk.gray('Audit Log ID:'), result.auditLogId);
        console.log();
        return;
      }

      console.log(chalk.green('\n✅ Command completed'));
      console.log(chalk.gray('Mode:'), result.mode);
      console.log(chalk.gray('Exit Code:'), result.exitCode);
      console.log(chalk.gray('Duration:'), `${result.durationMs}ms`);
      if (result.auditLogId) console.log(chalk.gray('Audit Log ID:'), result.auditLogId);

      if (result.stdout && result.stdout.trim().length > 0) {
        console.log(chalk.bold.cyan('\n--- stdout ---'));
        process.stdout.write(result.stdout.endsWith('\n') ? result.stdout : `${result.stdout}\n`);
      }

      if (result.stderr && result.stderr.trim().length > 0) {
        console.log(chalk.bold.yellow('\n--- stderr ---'));
        process.stderr.write(result.stderr.endsWith('\n') ? result.stderr : `${result.stderr}\n`);
      }

      if (result.stdoutTruncated || result.stderrTruncated) {
        console.log(chalk.yellow('\n⚠️  Output truncated (limits exceeded)'));
      }

      if (result.timedOut) {
        console.log(chalk.yellow('\n⚠️  Timed out'));
      }

      console.log();
    } catch (error) {
      this.stopSpinner(false);
      console.log(chalk.red('\n❌ Failed to run command:'), (error as Error).message, '\n');
    }
  }

  /**
   * Display help message.
   */
  private displayHelp(): void {
    const helpText = `
${chalk.bold.cyan('Available Commands:')}

${chalk.bold.yellow('Authentication:')}
${chalk.yellow('gitu auth <token>')}  - Link terminal with pairing token
${chalk.yellow('gitu auth --qr')}     - Link terminal with QR code
${chalk.yellow('gitu auth status')}   - Check authentication status
${chalk.yellow('gitu auth logout')}   - Unlink terminal
${chalk.yellow('gitu auth refresh')}  - Refresh auth token

${chalk.bold.yellow('Shell:')}
${chalk.yellow('run -- <command>')}   - Run a command (default sandbox)
${chalk.yellow('run --no-sandbox -- <command>')} - Run unsandboxed (requires permission)
${chalk.yellow('run --json -- <command>')} - Print JSON result only

${chalk.bold.yellow('General:')}
${chalk.yellow('help, ?')}            - Show this help message
${chalk.yellow('exit, quit, q')}      - Exit the terminal
${chalk.yellow('clear, cls')}         - Clear the screen
${chalk.yellow('history')}            - Show command history
${chalk.yellow('status')}             - Show Gitu status
${chalk.yellow('session')}            - Show current session info
${chalk.yellow('clear-session')}      - Clear conversation history

${chalk.bold.cyan('Usage:')}
Just type your message or question, and Gitu will respond.

${chalk.bold.cyan('Examples:')}
${chalk.gray('>')} List my notebooks
${chalk.gray('>')} Summarize my emails from today
${chalk.gray('>')} What's the weather like?
${chalk.gray('>')} Help me write a function to sort an array
    `.trim();

    console.log(helpText);
  }

  /**
   * Display command history.
   */
  private displayHistory(): void {
    if (this.commandHistory.length === 0) {
      console.log(chalk.gray('No command history yet.'));
      return;
    }

    console.log(chalk.bold.cyan('\nCommand History:'));
    this.commandHistory.forEach((cmd, index) => {
      console.log(chalk.gray(`${index + 1}.`), cmd);
    });
    console.log();
  }

  /**
   * Display Gitu status.
   */
  private async displayStatus(): Promise<void> {
    if (!this.config) return;

    // Check authentication first
    if (!this.credentials) {
      console.log(chalk.yellow('\n⚠️  Not authenticated'));
      console.log(chalk.gray('Run'), chalk.cyan('gitu auth <token>'), chalk.gray('to link this terminal.\n'));
      return;
    }

    try {
      const session = await gituSessionService.getActiveSession(this.credentials.userId, 'terminal');
      
      if (session) {
        const stats = await gituSessionService.getSessionStats(this.credentials.userId);
        
        console.log(chalk.bold.cyan('\n✅ Gitu Status:'));
        console.log(chalk.gray('Status:'), chalk.green('Active'));
        console.log(chalk.gray('User ID:'), this.credentials.userId);
        console.log(chalk.gray('Device:'), this.credentials.deviceName);
        console.log(chalk.gray('Total Messages:'), stats.messageCount);
        console.log(chalk.gray('Active Sessions:'), stats.activeSessions);
        console.log(chalk.gray('Active Notebooks:'), session.context.activeNotebooks.length);
        console.log(chalk.gray('Active Integrations:'), session.context.activeIntegrations.length);
        console.log(chalk.gray('Last Activity:'), session.lastActivityAt.toLocaleString());
        console.log();
      } else {
        console.log(chalk.yellow('\n⚠️  No active session. Send a message to start!\n'));
      }
    } catch (error) {
      console.log(chalk.red('\n❌ Error fetching status:', (error as Error).message, '\n'));
    }
  }

  /**
   * Display current session information.
   */
  private async displaySession(): Promise<void> {
    if (!this.config) return;

    // Check authentication first
    if (!this.credentials) {
      console.log(chalk.yellow('\n⚠️  Not authenticated'));
      console.log(chalk.gray('Run'), chalk.cyan('gitu auth <token>'), chalk.gray('to link this terminal.\n'));
      return;
    }

    try {
      const session = await gituSessionService.getActiveSession(this.credentials.userId, 'terminal');
      
      if (!session) {
        console.log(chalk.yellow('\n⚠️  No active session.\n'));
        return;
      }

      console.log(chalk.bold.cyan('\n📊 Session Information:'));
      console.log(chalk.gray('Session ID:'), session.id);
      console.log(chalk.gray('Platform:'), session.platform);
      console.log(chalk.gray('Status:'), session.status);
      console.log(chalk.gray('Started:'), session.startedAt.toLocaleString());
      console.log(chalk.gray('Last Activity:'), session.lastActivityAt.toLocaleString());
      console.log(chalk.gray('Messages:'), session.context.conversationHistory.length);
      
      if (session.context.activeNotebooks.length > 0) {
        console.log(chalk.gray('Active Notebooks:'), session.context.activeNotebooks.join(', '));
      }
      
      if (session.context.activeIntegrations.length > 0) {
        console.log(chalk.gray('Active Integrations:'), session.context.activeIntegrations.join(', '));
      }
      
      console.log();
    } catch (error) {
      console.log(chalk.red('\n❌ Error fetching session:', (error as Error).message, '\n'));
    }
  }

  /**
   * Clear conversation history.
   */
  private async clearSession(): Promise<void> {
    if (!this.config) return;

    // Check authentication first
    if (!this.credentials) {
      console.log(chalk.yellow('\n⚠️  Not authenticated'));
      console.log(chalk.gray('Run'), chalk.cyan('gitu auth <token>'), chalk.gray('to link this terminal.\n'));
      return;
    }

    try {
      const session = await gituSessionService.getActiveSession(this.credentials.userId, 'terminal');
      
      if (session) {
        session.context.conversationHistory = [];
        await gituSessionService.updateSession(session.id, { context: session.context });
        console.log(chalk.green('\n✅ Conversation history cleared!\n'));
      } else {
        console.log(chalk.yellow('\n⚠️  No active session to clear.\n'));
      }
    } catch (error) {
      console.log(chalk.red('\n❌ Error clearing session:', (error as Error).message, '\n'));
    }
  }

  /**
   * Handle: gitu model <command>
   */
  private async handleModelCommand(args: string[]): Promise<void> {
    if (!this.credentials) {
      console.log(chalk.yellow('\n⚠️  Not authenticated. Run'), chalk.cyan('gitu auth <token>'), chalk.yellow('to link this terminal.\n'));
      return;
    }

    const sub = args[0]?.toLowerCase();
    
    if (sub === 'list') {
        await this.listModels();
    } else if (sub === 'set' && args[1]) {
        await this.setModel(args[1]);
    } else if (sub === 'get') {
        await this.getModel();
    } else {
        console.log(chalk.yellow('\nUsage:'));
        console.log(chalk.cyan('  gitu model list'), chalk.gray('- List available models'));
        console.log(chalk.cyan('  gitu model set <model_id>'), chalk.gray('- Set preferred model'));
        console.log(chalk.cyan('  gitu model get'), chalk.gray('- Get current model\n'));
    }
  }

  /**
   * List available models
   */
  private async listModels(): Promise<void> {
      try {
          // In a real implementation, we'd fetch this from the backend via gituAIRouter or similar
          // For now, we'll query the admin_ai_models table if accessible, or just hardcode/mock
          // Since we are in the backend code, we can use pool directly
          const result = await pool.query('SELECT model_id, name, provider FROM admin_ai_models WHERE is_active = true ORDER BY provider, name');
          
          if (result.rows.length === 0) {
              console.log(chalk.yellow('\nNo active models found.\n'));
              return;
          }

          console.log(chalk.bold.cyan('\nAvailable Models:'));
          result.rows.forEach(row => {
              console.log(`${chalk.green(row.model_id)} ${chalk.gray(`(${row.provider} - ${row.name})`)}`);
          });
          console.log();
      } catch (error) {
          console.log(chalk.red('\n❌ Error fetching models:', (error as Error).message, '\n'));
      }
  }

  /**
   * Get current model
   */
  private async getModel(): Promise<void> {
      try {
          const settings = await gituTerminalService.getDeviceSettings(this.credentials!.userId, this.deviceId);
          const currentModel = settings.preferredModel || 'default';
          console.log(chalk.bold.cyan('\nCurrent Model:'), chalk.green(currentModel), '\n');
      } catch (error) {
          console.log(chalk.red('\n❌ Error getting model:', (error as Error).message, '\n'));
      }
  }

  /**
   * Set preferred model
   */
  private async setModel(modelId: string): Promise<void> {
      try {
          // Verify model exists
          const check = await pool.query('SELECT 1 FROM admin_ai_models WHERE model_id = $1 AND is_active = true', [modelId]);
          if (check.rows.length === 0 && modelId !== 'default') {
               console.log(chalk.red(`\n❌ Model '${modelId}' not found or inactive.\n`));
               return;
          }

          await gituTerminalService.updateDeviceSettings(this.credentials!.userId, this.deviceId, { preferredModel: modelId });
          console.log(chalk.green(`\n✅ Preferred model set to '${modelId}'\n`));
      } catch (error) {
          console.log(chalk.red('\n❌ Error setting model:', (error as Error).message, '\n'));
      }
  }

  /**
   * Handle user input and process through message gateway.
   */
  private async handleUserInput(input: string): Promise<void> {
    if (!this.config) return;

    // Check authentication
    if (!this.credentials) {
      console.log(chalk.yellow('\n⚠️  Not authenticated. Run'), chalk.cyan('gitu auth <token>'), chalk.yellow('to link this terminal.\n'));
      return;
    }

    // Validate token before processing
    const validation = await gituTerminalService.validateAuthToken(this.credentials.authToken);
    if (!validation.valid) {
      console.log(chalk.red('\n❌ Authentication invalid:', validation.error));
      console.log(chalk.yellow('Run'), chalk.cyan('gitu auth <token>'), chalk.yellow('to re-authenticate.\n'));
      await this.deleteCredentials();
      return;
    }

    try {
      // Build raw message
      const rawMessage: RawMessage = {
        platform: 'terminal',
        platformUserId: this.credentials.userId,
        content: { text: input },
        timestamp: new Date(),
        metadata: {
          terminal: true,
          deviceId: this.deviceId,
          deviceName: this.credentials.deviceName,
          commandHistory: this.commandHistory.length,
        },
      };

      // Show processing indicator
      this.startSpinner('Processing...');

      // Process through message gateway
      const normalizedMessage = await gituMessageGateway.processMessage(rawMessage);

      // Notify handlers
      for (const handler of this.messageHandlers) {
        await handler(normalizedMessage);
      }

      const session = await gituSessionService.getOrCreateSession(this.credentials.userId, 'universal');
      
      // Check for preferred model
      const settings = await gituTerminalService.getDeviceSettings(this.credentials.userId, this.deviceId);
      const preferredModel = settings.preferredModel;
      
      const userText = normalizedMessage.content.text || '[attachment]';

      session.context.conversationHistory.push({
        role: 'user',
        content: userText,
        timestamp: new Date(),
        platform: 'terminal',
      });

      const context = session.context.conversationHistory
        .slice(-101, -1)
        .map(m => `${m.role}: ${m.content}`);

      const aiResponse = await gituAIRouter.route({
        userId: this.credentials.userId,
        sessionId: session.id,
        prompt: userText,
        context,
        taskType: 'chat',
        preferredModel: preferredModel, // Pass preferred model to router
      });

      session.context.conversationHistory.push({
        role: 'assistant',
        content: aiResponse.content,
        timestamp: new Date(),
        platform: 'terminal',
      });

      await gituSessionService.updateSession(session.id, { context: session.context });

      this.stopSpinner(true);
      this.sendResponse(aiResponse.content);
    } catch (error) {
      this.stopSpinner(false);
      console.log(chalk.red('\n❌ Error:', (error as Error).message, '\n'));
    }
  }

  /**
   * Start the REPL (Read-Eval-Print Loop).
   */
  startREPL(): void {
    if (!this.initialized || !this.rl) {
      throw new Error('Terminal adapter not initialized');
    }

    this.rl.prompt();
  }

  /**
   * Send a response to the terminal.
   * 
   * @param message - The message to display
   */
  sendResponse(message: string): void {
    if (!this.config?.colorOutput) {
      console.log(`\n${message}\n`);
      return;
    }

    console.log(chalk.green('\n🤖 Gitu:'), message, '\n');
  }

  /**
   * Register a message handler.
   * 
   * @param handler - The handler function
   */
  onCommand(handler: (message: IncomingMessage) => void | Promise<void>): void {
    this.messageHandlers.push(handler);
  }

  /**
   * Display a progress indicator.
   * 
   * @param task - Task description
   * @param progress - Progress percentage (0-100)
   */
  displayProgress(task: string, progress: number): void {
    if (!this.config?.colorOutput) {
      console.log(`[${progress}%] ${task}`);
      return;
    }

    // Update or create spinner
    if (this.spinner) {
      this.spinner.text = `${task} (${progress}%)`;
      
      if (progress >= 100) {
        this.spinner.succeed(chalk.green(`✓ ${task}`));
        this.spinner = null;
      }
    } else {
      this.startSpinner(`${task} (${progress}%)`);
    }
  }

  /**
   * Start a spinner with a message.
   * 
   * @param message - Spinner message
   */
  private startSpinner(message: string): void {
    if (!this.config?.colorOutput) {
      console.log(message);
      return;
    }

    if (this.spinner) {
      this.spinner.stop();
    }

    this.spinner = ora({
      text: message,
      color: 'cyan',
    }).start();
  }

  /**
   * Stop the current spinner.
   * 
   * @param success - Whether to show success or failure
   * @param message - Optional final message
   */
  private stopSpinner(success: boolean = true, message?: string): void {
    if (!this.spinner) return;

    if (success) {
      this.spinner.succeed(message);
    } else {
      this.spinner.fail(message);
    }

    this.spinner = null;
  }

  /**
   * Shutdown the terminal adapter.
   */
  private shutdown(): void {
    if (this.spinner) {
      this.spinner.stop();
    }

    if (this.config?.colorOutput) {
      console.log(chalk.cyan('\n👋 Goodbye!\n'));
    } else {
      console.log('\nGoodbye!\n');
    }

    if (this.rl) {
      this.rl.close();
    }

    this.initialized = false;
    process.exit(0);
  }

  /**
   * Get connection state.
   */
  getConnectionState(): 'connected' | 'disconnected' | 'error' {
    if (!this.rl || !this.initialized) {
      return 'disconnected';
    }
    return 'connected';
  }

  /**
   * Check if adapter is initialized.
   */
  isInitialized(): boolean {
    return this.initialized;
  }
}

// Export singleton instance
export const terminalAdapter = new TerminalAdapter();
export default terminalAdapter;
