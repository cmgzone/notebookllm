import axios, { AxiosInstance } from 'axios';
import { ConfigManager } from './config.js';

export class ApiClient {
  private client!: AxiosInstance;
  private config: ConfigManager;

  constructor(config: ConfigManager) {
    this.config = config;
    this.reinitialize();
  }

  reinitialize() {
    let apiUrl = this.config.get('apiUrl') || 'https://notebookllm-ufj7.onrender.com/api/';
    if (!apiUrl.endsWith('/')) apiUrl += '/';

    const apiToken = this.config.get('apiToken');

    this.client = axios.create({
      baseURL: apiUrl,
      headers: {
        'Content-Type': 'application/json',
        ...(apiToken && { 'Authorization': `Bearer ${apiToken}` })
      },
      timeout: 30000
    });
  }

  async get(path: string, params?: any) {
    const cleanPath = path.startsWith('/') ? path.substring(1) : path;
    const response = await this.client.get(cleanPath, { params });
    return response.data;
  }

  async post(path: string, data?: any) {
    const cleanPath = path.startsWith('/') ? path.substring(1) : path;
    const response = await this.client.post(cleanPath, data);
    return response.data;
  }

  async put(path: string, data?: any) {
    const cleanPath = path.startsWith('/') ? path.substring(1) : path;
    const response = await this.client.put(cleanPath, data);
    return response.data;
  }

  async delete(path: string) {
    const cleanPath = path.startsWith('/') ? path.substring(1) : path;
    const response = await this.client.delete(cleanPath);
    return response.data;
  }

  // Gitu-specific endpoints
  async linkTerminal(token: string, deviceId: string, deviceName?: string) {
    return this.post('gitu/terminal/link', { token, deviceId, deviceName: deviceName || 'Gitu CLI' });
  }

  async generateQR() {
    return this.post('gitu/qr/generate');
  }

  async listSessions() {
    return this.get('gitu/sessions');
  }

  async getSession(sessionId: string) {
    return this.get(`gitu/sessions/${sessionId}`);
  }

  async revokeSession(sessionId: string) {
    return this.delete(`gitu/sessions/${sessionId}`);
  }

  async listDevices() {
    return this.get('gitu/devices');
  }

  async getDevice(deviceId: string) {
    return this.get(`gitu/devices/${deviceId}`);
  }

  async removeDevice(deviceId: string) {
    return this.delete(`gitu/devices/${deviceId}`);
  }

  async health() {
    return this.get('health');
  }

  async whoami() {
    return this.get('auth/me');
  }

  // Agent endpoints
  async listAgents() {
    return this.get('gitu/agents');
  }

  async spawnAgent(task: string) {
    return this.post('gitu/agents', { task });
  }

  async getAgent(agentId: string) {
    return this.get(`gitu/agents/${agentId}`);
  }

  async sendMessage(message: string, context?: string[]) {
    return this.post('gitu/message', { message, context });
  }

  async executeShell(command: string) {
    return this.post('gitu/shell/execute', { command });
  }

  async listNotebooks() {
    return this.get('notebooks');
  }

  async queryNotebook(notebookId: string, query: string) {
    return this.post(`notebooks/${notebookId}/query`, { query });
  }
}
