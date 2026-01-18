// API URL configuration
// Uses environment variable or defaults
const PRODUCTION_API_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3000/api';

const getApiBase = () => {
    // Check for environment variable first
    if (process.env.NEXT_PUBLIC_API_URL) {
        return process.env.NEXT_PUBLIC_API_URL;
    }

    // In browser, check if we're on localhost for development
    if (typeof window !== 'undefined') {
        const hostname = window.location.hostname;
        console.log('[API] Hostname:', hostname);
        if (hostname === 'localhost' || hostname === '127.0.0.1') {
            console.log('[API] Using local backend');
            // Local development - try local backend first
            return 'http://localhost:3005/api';
        }
    }
    console.log('[API] Using production backend:', PRODUCTION_API_URL);
    // Default to production backend
    return PRODUCTION_API_URL;
};

const API_BASE = getApiBase();

export interface User {
    id: string;
    email: string;
    displayName: string;
    emailVerified: boolean;
    twoFactorEnabled: boolean;
    avatarUrl: string | null;
    role: string;
    createdAt?: string;
}

export interface Subscription {
    id: string;
    user_id: string;
    plan_id: string;
    plan_name: string;
    credits_per_month: number;
    plan_price: string;
    is_free_plan: boolean;
    current_credits: number;
    credits_consumed_this_month: number;
    last_renewal_date: string;
    next_renewal_date: string;
}

export interface CreditTransaction {
    id: string;
    user_id: string;
    amount: number;
    transaction_type: string;
    description: string;
    balance_after: number;
    created_at: string;
}

// Research Interfaces
export interface ResearchConfig {
    depth: 'quick' | 'standard' | 'deep';
    template: 'general' | 'academic' | 'productComparison' | 'marketAnalysis' | 'howToGuide' | 'prosAndCons';
    notebookId?: string;
}

export interface ResearchSource {
    title: string;
    url: string;
    content: string;
    snippet?: string;
    credibility: string;
    credibilityScore: number;
}

export interface ResearchProgress {
    status: string;
    progress: number;
    sources?: ResearchSource[];
    images?: string[];
    videos?: string[];
    result?: string;
    isComplete: boolean;
}

export interface ApiToken {
    id: string;
    name: string;
    tokenPrefix: string;
    tokenSuffix: string;
    expiresAt: string | null;
    lastUsedAt: string | null;
    createdAt: string;
    revokedAt: string | null;
    isActive: boolean;
}

export interface TokenUsageLog {
    id: string;
    endpoint: string;
    ipAddress: string | null;
    userAgent: string | null;
    createdAt: string;
}

export interface McpStats {
    totalTokens: number;
    activeTokens: number;
    totalUsage: number;
    recentUsage: number;
    verifiedSources: number;
    agentSessions: number;
}

export interface McpUsageEntry {
    id: string;
    endpoint: string;
    ipAddress: string | null;
    userAgent: string | null;
    createdAt: string;
    tokenName: string;
    tokenPrefix: string;
}

export interface VerifiedSource {
    id: string;
    notebook_id: string;
    title: string;
    content: string;
    type: string;
    metadata: {
        language: string;
        verification: any;
        isVerified: boolean;
        verifiedAt: string;
        agentName?: string;
    };
    created_at: string;
}

export interface AgentNotebook {
    id: string;
    title: string;
    description: string;
    isAgentNotebook: boolean;
    agentSessionId: string | null;
    createdAt: string;
    session?: {
        id: string;
        agentName: string;
        agentIdentifier: string;
        status: string;
        lastActivity: string;
    };
}

export interface McpQuota {
    sourcesLimit: number;
    sourcesUsed: number;
    sourcesRemaining: number;
    tokensLimit: number;
    tokensUsed: number;
    tokensRemaining: number;
    apiCallsLimit: number;
    apiCallsUsed: number;
    apiCallsRemaining: number;
    isPremium: boolean;
    isMcpEnabled: boolean;
}

export interface McpUserSettings {
    codeAnalysisModelId: string | null;
    codeAnalysisEnabled: boolean;
    updatedAt: string;
}

export interface AIModelOption {
    id: string;
    name: string;
    modelId: string;
    provider: string;
    description: string;
    isPremium: boolean;
}

export interface Notebook {
    id: string;
    userId: string;
    title: string;
    description: string | null;
    coverImage: string | null;
    category: string | null;
    createdAt: string;
    updatedAt: string;
    sourceCount?: number;
    isShared?: boolean;
}

export interface Source {
    id: string;
    notebookId: string;
    type: 'pdf' | 'url' | 'youtube' | 'text' | 'image';
    title: string;
    content?: string;
    url?: string;
    imageUrl?: string;
    createdAt: string;
    credibility?: string;
    credibilityScore?: number;
}

class ApiService {
    private token: string | null = null;

    constructor() {
        if (typeof window !== 'undefined') {
            this.token = localStorage.getItem('auth_token');
        }
    }

    setToken(token: string) {
        this.token = token;
        if (typeof window !== 'undefined') {
            localStorage.setItem('auth_token', token);
        }
    }

    clearToken() {
        this.token = null;
        if (typeof window !== 'undefined') {
            localStorage.removeItem('auth_token');
        }
    }

    getToken(): string | null {
        return this.token;
    }

    private async fetch<T>(endpoint: string, options: RequestInit = {}): Promise<T> {
        const headers: HeadersInit = {
            'Content-Type': 'application/json',
            ...(this.token && { 'Authorization': `Bearer ${this.token}` }),
            ...options.headers,
        };

        const response = await fetch(`${API_BASE}${endpoint}`, {
            ...options,
            headers,
        });

        if (!response.ok) {
            const error = await response.json().catch(() => ({ error: 'Request failed' }));
            throw new Error(error.error || 'Request failed');
        }

        return response.json();
    }

    // Auth
    async login(email: string, password: string, rememberMe = false): Promise<{ token: string; user: User }> {
        const data = await this.fetch<{ token: string; user: User }>('/auth/login', {
            method: 'POST',
            body: JSON.stringify({ email, password, rememberMe }),
        });
        this.setToken(data.token);
        return data;
    }

    async signup(email: string, password: string, displayName?: string): Promise<{ token: string; user: User }> {
        const data = await this.fetch<{ token: string; user: User }>('/auth/signup', {
            method: 'POST',
            body: JSON.stringify({ email, password, displayName }),
        });
        this.setToken(data.token);
        return data;
    }

    async getCurrentUser(): Promise<User> {
        const data = await this.fetch<{ user: User }>('/auth/me');
        return data.user;
    }

    logout() {
        this.clearToken();
    }

    // Notebooks
    async getNotebooks(): Promise<Notebook[]> {
        const data = await this.fetch<{ notebooks: Notebook[] }>('/notebooks');
        return data.notebooks || [];
    }

    async getNotebook(id: string): Promise<Notebook> {
        const data = await this.fetch<{ notebook: Notebook }>(`/notebooks/${id}`);
        return data.notebook;
    }

    async createNotebook(data: { title: string; description?: string; coverImage?: string; category?: string }): Promise<Notebook> {
        const response = await this.fetch<{ notebook: Notebook }>('/notebooks', {
            method: 'POST',
            body: JSON.stringify(data),
        });
        return response.notebook;
    }

    async updateNotebook(id: string, data: { title?: string; description?: string; coverImage?: string; category?: string }): Promise<Notebook> {
        const response = await this.fetch<{ notebook: Notebook }>(`/notebooks/${id}`, {
            method: 'PUT',
            body: JSON.stringify(data),
        });
        return response.notebook;
    }

    async deleteNotebook(id: string): Promise<void> {
        await this.fetch(`/notebooks/${id}`, {
            method: 'DELETE',
        });
    }

    // Sources
    async getSources(notebookId: string): Promise<Source[]> {
        const data = await this.fetch<{ sources: Source[] }>(`/sources/notebook/${notebookId}`);
        return data.sources || [];
    }

    async createSource(data: { notebookId: string; type: string; title: string; content?: string; url?: string; imageUrl?: string }): Promise<Source> {
        const response = await this.fetch<{ source: Source }>('/sources', {
            method: 'POST',
            body: JSON.stringify(data),
        });
        return response.source;
    }

    async deleteSource(id: string): Promise<void> {
        await this.fetch(`/sources/${id}`, {
            method: 'DELETE',
        });
    }



    // AI Chat
    async chatWithAI(messages: { role: string; content: string }[], provider = 'gemini', model?: string): Promise<string> {
        const response = await this.fetch<{ response: string }>('/ai/chat', {
            method: 'POST',
            body: JSON.stringify({
                messages,
                provider,
                model
            }),
        });
        return response.response;
    }

    // Helper for streaming chat
    async chatWithAIStream(
        messages: { role: string; content: string }[],
        onChunk: (chunk: string) => void,
        provider = 'gemini',
        model?: string
    ): Promise<void> {
        if (!this.token) throw new Error("Not authenticated");

        const response = await fetch(`${API_BASE}/ai/chat/stream`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${this.token}`,
            },
            body: JSON.stringify({
                messages,
                provider,
                model
            }),
        });

        if (!response.body) throw new Error("ReadableStream not supported");

        const reader = response.body.getReader();
        const decoder = new TextDecoder();
        let buffer = "";

        while (true) {
            const { done, value } = await reader.read();
            if (done) break;

            const chunk = decoder.decode(value, { stream: true });
            buffer += chunk;

            const lines = buffer.split('\n\n');
            buffer = lines.pop() || ""; // Keep incomplete line in buffer

            for (const line of lines) {
                const trimmedLine = line.trim();
                if (trimmedLine.startsWith('data: ')) {
                    const dataStr = trimmedLine.substring(6);
                    if (dataStr === '[DONE]') continue;

                    try {
                        const data = JSON.parse(dataStr);
                        if (data.text) {
                            onChunk(data.text);
                        } else if (data.error) {
                            console.error('SSE Error:', data.error);
                            // Optionally handle error UI here
                        }
                    } catch (e) {
                        console.error('Error parsing SSE chat data:', e);
                    }
                }
            }
        }
    }

    // Research
    async performResearchStream(
        query: string,
        config: ResearchConfig,
        onProgress: (progress: ResearchProgress) => void
    ): Promise<void> {
        if (!this.token) throw new Error("Not authenticated");

        const response = await fetch(`${API_BASE}/research/stream`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${this.token}`,
            },
            body: JSON.stringify({ query, ...config }),
        });

        if (!response.body) throw new Error("ReadableStream not supported");

        const reader = response.body.getReader();
        const decoder = new TextDecoder();
        let buffer = "";

        while (true) {
            const { done, value } = await reader.read();
            if (done) break;

            const chunk = decoder.decode(value, { stream: true });
            buffer += chunk;

            const lines = buffer.split('\n\n');
            buffer = lines.pop() || ""; // Keep incomplete line in buffer

            for (const line of lines) {
                if (line.startsWith('data: ')) {
                    const jsonStr = line.substring(6);
                    try {
                        const data = JSON.parse(jsonStr);
                        onProgress(data);
                    } catch (e) {
                        console.error('Error parsing SSE data:', e);
                    }
                }
            }
        }
    }

    // Subscriptions
    async getSubscription(): Promise<Subscription> {
        const data = await this.fetch<{ subscription: Subscription }>('/subscriptions/me');
        return data.subscription;
    }

    async getCredits(): Promise<{ credits: number; consumed: number }> {
        return this.fetch('/subscriptions/credits');
    }

    async getTransactions(limit = 50): Promise<CreditTransaction[]> {
        const data = await this.fetch<{ transactions: CreditTransaction[] }>(`/subscriptions/transactions?limit=${limit}`);
        return data.transactions;
    }

    async getPlans(): Promise<any[]> {
        const data = await this.fetch<{ plans: any[] }>('/subscriptions/plans');
        return data.plans;
    }

    // Payment
    async getPaymentConfig(): Promise<any> {
        const data = await this.fetch<{ config: any }>('/subscriptions/payment-config');
        return data.config;
    }

    async createCheckoutSession(planId: string): Promise<{ sessionId: string; url: string }> {
        return this.fetch('/subscriptions/create-checkout-session', {
            method: 'POST',
            body: JSON.stringify({ planId }),
        });
    }

    async upgradePlan(planId: string, transactionId: string): Promise<{ success: boolean; newBalance: number }> {
        return this.fetch('/subscriptions/upgrade', {
            method: 'POST',
            body: JSON.stringify({ planId, transactionId }),
        });
    }

    // Analytics (if available)
    async getUsageAnalytics(): Promise<any> {
        try {
            return await this.fetch('/analytics/usage');
        } catch {
            return null;
        }
    }

    // MCP / API Tokens
    async getApiTokens(): Promise<ApiToken[]> {
        const data = await this.fetch<{ tokens: ApiToken[]; count: number; maxTokens: number }>('/auth/tokens');
        return data.tokens;
    }

    async createApiToken(name: string, expiresAt?: string): Promise<{ token: string; tokenRecord: ApiToken }> {
        return this.fetch('/auth/tokens', {
            method: 'POST',
            body: JSON.stringify({ name, expiresAt }),
        });
    }

    async revokeApiToken(tokenId: string): Promise<{ success: boolean }> {
        return this.fetch(`/auth/tokens/${tokenId}`, {
            method: 'DELETE',
        });
    }

    async getTokenUsage(tokenId: string, limit = 100): Promise<TokenUsageLog[]> {
        const data = await this.fetch<{ logs: TokenUsageLog[] }>(`/auth/tokens/${tokenId}/usage?limit=${limit}`);
        return data.logs;
    }

    async getMcpStats(): Promise<McpStats> {
        const data = await this.fetch<{ stats: McpStats }>('/auth/mcp/stats');
        return data.stats;
    }

    async getMcpUsage(limit = 50): Promise<McpUsageEntry[]> {
        const data = await this.fetch<{ usage: McpUsageEntry[] }>(`/auth/mcp/usage?limit=${limit}`);
        return data.usage;
    }

    async getVerifiedSources(notebookId?: string, language?: string): Promise<VerifiedSource[]> {
        let url = '/coding-agent/sources';
        const params = new URLSearchParams();
        if (notebookId) params.append('notebookId', notebookId);
        if (language) params.append('language', language);
        if (params.toString()) url += `?${params.toString()}`;

        const data = await this.fetch<{ sources: VerifiedSource[] }>(url);
        return data.sources;
    }

    async getAgentNotebooks(): Promise<AgentNotebook[]> {
        const data = await this.fetch<{ notebooks: AgentNotebook[] }>('/coding-agent/notebooks');
        return data.notebooks;
    }

    async getMcpQuota(): Promise<McpQuota> {
        const data = await this.fetch<{ quota: McpQuota }>('/coding-agent/quota');
        return data.quota;
    }

    // MCP User Settings
    async getMcpSettings(): Promise<McpUserSettings> {
        const data = await this.fetch<{ settings: McpUserSettings }>('/coding-agent/settings');
        return data.settings;
    }

    async updateMcpSettings(settings: { codeAnalysisModelId?: string | null; codeAnalysisEnabled?: boolean }): Promise<McpUserSettings> {
        const data = await this.fetch<{ settings: McpUserSettings }>('/coding-agent/settings', {
            method: 'PUT',
            body: JSON.stringify(settings),
        });
        return data.settings;
    }

    async getAIModels(): Promise<AIModelOption[]> {
        const data = await this.fetch<{ models: AIModelOption[] }>('/coding-agent/models');
        return data.models;
    }
}

export const api = new ApiService();
export default api;
