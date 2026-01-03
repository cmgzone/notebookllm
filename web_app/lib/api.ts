// API URL configuration
// Uses environment variable or defaults to production Render backend
const PRODUCTION_API_URL = 'https://notebookllm-ufj7.onrender.com/api';

const getApiBase = () => {
    // Check for environment variable first
    if (process.env.NEXT_PUBLIC_API_URL) {
        return process.env.NEXT_PUBLIC_API_URL;
    }
    
    // In browser, check if we're on localhost for development
    if (typeof window !== 'undefined') {
        const hostname = window.location.hostname;
        if (hostname === 'localhost' || hostname === '127.0.0.1') {
            // Local development - try local backend first
            return 'http://localhost:3005/api';
        }
    }
    
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
}

export const api = new ApiService();
export default api;
