// Dynamically determine API URL based on current host
// Backend runs on port 3000, web app runs on 3000/3001
const BACKEND_PORT = 3000;

const getApiBase = () => {
    if (typeof window === 'undefined') {
        return process.env.NEXT_PUBLIC_API_URL || `http://localhost:${BACKEND_PORT}/api`;
    }
    // Use same hostname as the current page but with backend port
    const hostname = window.location.hostname;
    return `http://${hostname}:${BACKEND_PORT}/api`;
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
}

export const api = new ApiService();
export default api;
