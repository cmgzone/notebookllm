import axios, { AxiosInstance } from 'axios';
import { ConfigManager } from './config.js';

export class ApiClient {
  private client: AxiosInstance;
  private config: ConfigManager;

  constructor(config: ConfigManager) {
    this.config = config;
    
    const apiUrl = config.get('apiUrl') || 'https://api.notebookllm.com';
    const apiToken = config.get('apiToken');

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
    const response = await this.client.get(path, { params });
    return response.data;
  }

  async post(path: string, data?: any) {
    const response = await this.client.post(path, data);
    return response.data;
  }

  async put(path: string, data?: any) {
    const response = await this.client.put(path, data);
    return response.data;
  }

  async delete(path: string) {
    const response = await this.client.delete(path);
    return response.data;
  }

  // Gitu-specific endpoints
  async generateQR() {
    return this.post('/api/gitu/qr/generate');
  }

  async listSessions() {
    return this.get('/api/gitu/sessions');
  }

  async getSession(sessionId: string) {
    return this.get(`/api/gitu/sessions/${sessionId}`);
  }

  async revokeSession(sessionId: string) {
    return this.delete(`/api/gitu/sessions/${sessionId}`);
  }

  async listDevices() {
    return this.get('/api/gitu/devices');
  }

  async getDevice(deviceId: string) {
    return this.get(`/api/gitu/devices/${deviceId}`);
  }

  async removeDevice(deviceId: string) {
    return this.delete(`/api/gitu/devices/${deviceId}`);
  }

  async health() {
    return this.get('/api/health');
  }

  async whoami() {
    return this.get('/api/auth/me');
  }

  // Agent endpoints
  async listAgents() {
    return this.get('/api/gitu/agents');
  }

  async spawnAgent(task: string) {
    return this.post('/api/gitu/agents', { task });
  }

  async getAgent(agentId: string) {
    return this.get(`/api/gitu/agents/${agentId}`);
  }

  // Chat endpoints
  async sendMessage(message: string, context?: string[]) {
    return this.post('/api/gitu/message', { message, context });
  }

  // Shell endpoints
  async executeShell(command: string) {
    return this.post('/api/gitu/shell/execute', { command });
  }

  // Notebook endpoints
  async listNotebooks() {
    return this.get('/api/notebooks');
  }

  async queryNotebook(notebookId: string, query: string) {
    return this.post(`/api/notebooks/${notebookId}/query`, { query });
  }
}
