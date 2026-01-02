"use client";

import React, { useEffect, useState } from "react";
import {
    BrainCircuit,
    Key,
    Activity,
    Code,
    Bot,
    Clock,
    Shield,
    Copy,
    Check,
    Trash2,
    Plus,
    RefreshCw,
    LogOut,
    Loader2,
    ArrowLeft,
    Eye,
    EyeOff,
} from "lucide-react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { motion } from "framer-motion";
import { useAuth } from "@/lib/auth-context";
import api, { ApiToken, McpStats, McpUsageEntry, VerifiedSource, AgentNotebook } from "@/lib/api";

export default function McpDashboardPage() {
    const { user, isLoading: authLoading, isAuthenticated, logout } = useAuth();
    const router = useRouter();
    const [stats, setStats] = useState<McpStats | null>(null);
    const [tokens, setTokens] = useState<ApiToken[]>([]);
    const [usage, setUsage] = useState<McpUsageEntry[]>([]);
    const [sources, setSources] = useState<VerifiedSource[]>([]);
    const [notebooks, setNotebooks] = useState<AgentNotebook[]>([]);
    const [isLoading, setIsLoading] = useState(true);
    const [activeTab, setActiveTab] = useState<"overview" | "tokens" | "usage" | "sources">("overview");

    useEffect(() => {
        if (!authLoading && !isAuthenticated) {
            router.push("/login");
            return;
        }
        if (isAuthenticated) {
            loadData();
        }
    }, [authLoading, isAuthenticated, router]);

    const loadData = async () => {
        setIsLoading(true);
        try {
            const [statsData, tokensData, usageData, sourcesData, notebooksData] = await Promise.all([
                api.getMcpStats().catch(() => null),
                api.getApiTokens().catch(() => []),
                api.getMcpUsage(20).catch(() => []),
                api.getVerifiedSources().catch(() => []),
                api.getAgentNotebooks().catch(() => []),
            ]);
            setStats(statsData);
            setTokens(tokensData);
            setUsage(usageData);
            setSources(sourcesData);
            setNotebooks(notebooksData);
        } catch (error) {
            console.error("Failed to load MCP data:", error);
        } finally {
            setIsLoading(false);
        }
    };

    const handleLogout = () => {
        logout();
        router.push("/");
    };

    if (authLoading || (!isAuthenticated && !authLoading)) {
        return (
            <div className="min-h-screen bg-neutral-950 flex items-center justify-center">
                <Loader2 className="animate-spin text-blue-500" size={40} />
            </div>
        );
    }

    return (
        <div className="min-h-screen bg-neutral-950 text-white">
            <DashboardNav user={user} onLogout={handleLogout} />
            <main className="container mx-auto px-6 py-8">
                <header className="mb-8">
                    <Link href="/dashboard" className="flex items-center gap-2 text-neutral-400 hover:text-white mb-4 text-sm">
                        <ArrowLeft size={16} />
                        Back to Dashboard
                    </Link>
                    <div className="flex items-center justify-between">
                        <div>
                            <h1 className="text-3xl font-bold tracking-tight flex items-center gap-3">
                                <Bot className="text-purple-400" />
                                MCP Usage
                            </h1>
                            <p className="text-neutral-400 mt-1">Manage your API tokens and monitor coding agent activity.</p>
                        </div>
                        <button onClick={loadData} className="flex items-center gap-2 px-4 py-2 rounded-lg bg-white/5 hover:bg-white/10 transition-colors text-sm">
                            <RefreshCw size={16} />
                            Refresh
                        </button>
                    </div>
                </header>

                {/* Tabs */}
                <div className="flex gap-2 mb-6 border-b border-white/10 pb-4">
                    {(["overview", "tokens", "usage", "sources"] as const).map((tab) => (
                        <button
                            key={tab}
                            onClick={() => setActiveTab(tab)}
                            className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
                                activeTab === tab ? "bg-blue-600 text-white" : "bg-white/5 text-neutral-400 hover:bg-white/10"
                            }`}
                        >
                            {tab.charAt(0).toUpperCase() + tab.slice(1)}
                        </button>
                    ))}
                </div>

                {isLoading ? (
                    <div className="flex items-center justify-center py-12">
                        <Loader2 className="animate-spin text-blue-500" size={32} />
                    </div>
                ) : (
                    <>
                        {activeTab === "overview" && <OverviewTab stats={stats} tokens={tokens} usage={usage} notebooks={notebooks} />}
                        {activeTab === "tokens" && <TokensTab tokens={tokens} onRefresh={loadData} />}
                        {activeTab === "usage" && <UsageTab usage={usage} />}
                        {activeTab === "sources" && <SourcesTab sources={sources} />}
                    </>
                )}
            </main>
        </div>
    );
}


function DashboardNav({ user, onLogout }: { user: any; onLogout: () => void }) {
    return (
        <nav className="border-b border-white/5 bg-neutral-900/50 backdrop-blur-xl">
            <div className="container mx-auto flex h-16 items-center justify-between px-6">
                <Link href="/" className="flex items-center gap-2">
                    <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-blue-600/20 text-blue-400">
                        <BrainCircuit size={20} />
                    </div>
                    <span className="font-bold tracking-tight">NotebookLM</span>
                </Link>
                <div className="flex items-center gap-4">
                    <span className="text-sm text-neutral-400 hidden md:block">{user?.email}</span>
                    <button onClick={onLogout} className="flex items-center gap-2 text-sm font-medium text-neutral-400 hover:text-white transition-colors">
                        <LogOut size={16} />
                        <span className="hidden md:inline">Log out</span>
                    </button>
                    <div className="h-8 w-8 rounded-full bg-gradient-to-tr from-blue-500 to-purple-500 flex items-center justify-center text-xs font-bold">
                        {user?.displayName?.[0]?.toUpperCase() || user?.email?.[0]?.toUpperCase() || "U"}
                    </div>
                </div>
            </div>
        </nav>
    );
}

function StatCard({ title, value, icon, color }: { title: string; value: string | number; icon: React.ReactNode; color: string }) {
    return (
        <div className="rounded-xl border border-white/5 bg-neutral-900/50 p-6 backdrop-blur-sm">
            <div className="flex items-center justify-between mb-4">
                <h3 className="text-sm font-medium text-neutral-400">{title}</h3>
                <div className={color}>{icon}</div>
            </div>
            <div className="text-2xl font-bold">{value}</div>
        </div>
    );
}

function OverviewTab({ stats, tokens, usage, notebooks }: { stats: McpStats | null; tokens: ApiToken[]; usage: McpUsageEntry[]; notebooks: AgentNotebook[] }) {
    return (
        <div className="space-y-6">
            {/* Stats Grid */}
            <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
                <StatCard title="Active Tokens" value={stats?.activeTokens || 0} icon={<Key size={20} />} color="text-amber-400" />
                <StatCard title="Total API Calls" value={stats?.totalUsage || 0} icon={<Activity size={20} />} color="text-blue-400" />
                <StatCard title="Verified Sources" value={stats?.verifiedSources || 0} icon={<Code size={20} />} color="text-green-400" />
                <StatCard title="Agent Sessions" value={stats?.agentSessions || 0} icon={<Bot size={20} />} color="text-purple-400" />
            </div>

            {/* Recent Activity */}
            <div className="grid gap-6 md:grid-cols-2">
                <div className="rounded-xl border border-white/5 bg-neutral-900/50 p-6">
                    <h3 className="text-lg font-semibold mb-4 flex items-center gap-2">
                        <Clock size={18} className="text-blue-400" />
                        Recent API Usage
                    </h3>
                    {usage.length === 0 ? (
                        <p className="text-neutral-500 text-sm">No recent API activity.</p>
                    ) : (
                        <div className="space-y-3">
                            {usage.slice(0, 5).map((entry) => (
                                <div key={entry.id} className="flex items-center justify-between p-3 rounded-lg bg-white/5">
                                    <div>
                                        <div className="font-mono text-sm text-blue-400">{entry.endpoint}</div>
                                        <div className="text-xs text-neutral-500">{entry.tokenName}</div>
                                    </div>
                                    <span className="text-xs text-neutral-500">{new Date(entry.createdAt).toLocaleString()}</span>
                                </div>
                            ))}
                        </div>
                    )}
                </div>

                <div className="rounded-xl border border-white/5 bg-neutral-900/50 p-6">
                    <h3 className="text-lg font-semibold mb-4 flex items-center gap-2">
                        <Bot size={18} className="text-purple-400" />
                        Connected Agents
                    </h3>
                    {notebooks.length === 0 ? (
                        <p className="text-neutral-500 text-sm">No agents connected yet.</p>
                    ) : (
                        <div className="space-y-3">
                            {notebooks.slice(0, 5).map((nb) => (
                                <div key={nb.id} className="flex items-center justify-between p-3 rounded-lg bg-white/5">
                                    <div>
                                        <div className="font-medium text-sm">{nb.session?.agentName || "Unknown Agent"}</div>
                                        <div className="text-xs text-neutral-500">{nb.title}</div>
                                    </div>
                                    <span className={`text-xs px-2 py-1 rounded-full ${nb.session?.status === "active" ? "bg-green-500/20 text-green-400" : "bg-neutral-500/20 text-neutral-400"}`}>
                                        {nb.session?.status || "unknown"}
                                    </span>
                                </div>
                            ))}
                        </div>
                    )}
                </div>
            </div>
        </div>
    );
}


function TokensTab({ tokens, onRefresh }: { tokens: ApiToken[]; onRefresh: () => void }) {
    const [showCreateModal, setShowCreateModal] = useState(false);
    const [newTokenName, setNewTokenName] = useState("");
    const [newToken, setNewToken] = useState<string | null>(null);
    const [isCreating, setIsCreating] = useState(false);
    const [copied, setCopied] = useState(false);

    const handleCreateToken = async () => {
        if (!newTokenName.trim()) return;
        setIsCreating(true);
        try {
            const result = await api.createApiToken(newTokenName);
            setNewToken(result.token);
            setNewTokenName("");
            onRefresh();
        } catch (error) {
            console.error("Failed to create token:", error);
            alert("Failed to create token");
        } finally {
            setIsCreating(false);
        }
    };

    const handleRevokeToken = async (tokenId: string) => {
        if (!confirm("Are you sure you want to revoke this token? This action cannot be undone.")) return;
        try {
            await api.revokeApiToken(tokenId);
            onRefresh();
        } catch (error) {
            console.error("Failed to revoke token:", error);
            alert("Failed to revoke token");
        }
    };

    const copyToClipboard = (text: string) => {
        navigator.clipboard.writeText(text);
        setCopied(true);
        setTimeout(() => setCopied(false), 2000);
    };

    return (
        <div className="space-y-6">
            <div className="flex items-center justify-between">
                <h3 className="text-lg font-semibold">API Tokens</h3>
                <button onClick={() => setShowCreateModal(true)} className="flex items-center gap-2 px-4 py-2 rounded-lg bg-blue-600 hover:bg-blue-700 transition-colors text-sm font-medium">
                    <Plus size={16} />
                    Create Token
                </button>
            </div>

            {/* New Token Display */}
            {newToken && (
                <motion.div initial={{ opacity: 0, y: -10 }} animate={{ opacity: 1, y: 0 }} className="rounded-xl border border-green-500/30 bg-green-500/10 p-6">
                    <div className="flex items-start gap-3">
                        <Shield className="text-green-400 mt-1" size={20} />
                        <div className="flex-1">
                            <h4 className="font-semibold text-green-400 mb-2">Token Created Successfully!</h4>
                            <p className="text-sm text-neutral-300 mb-4">Copy this token now. You won't be able to see it again.</p>
                            <div className="flex items-center gap-2 p-3 rounded-lg bg-black/30 font-mono text-sm">
                                <code className="flex-1 break-all">{newToken}</code>
                                <button onClick={() => copyToClipboard(newToken)} className="p-2 hover:bg-white/10 rounded transition-colors">
                                    {copied ? <Check size={16} className="text-green-400" /> : <Copy size={16} />}
                                </button>
                            </div>
                            <button onClick={() => setNewToken(null)} className="mt-4 text-sm text-neutral-400 hover:text-white">
                                Dismiss
                            </button>
                        </div>
                    </div>
                </motion.div>
            )}

            {/* Create Token Modal */}
            {showCreateModal && !newToken && (
                <motion.div initial={{ opacity: 0, y: -10 }} animate={{ opacity: 1, y: 0 }} className="rounded-xl border border-white/10 bg-neutral-900 p-6">
                    <h4 className="font-semibold mb-4">Create New API Token</h4>
                    <input
                        type="text"
                        value={newTokenName}
                        onChange={(e) => setNewTokenName(e.target.value)}
                        placeholder="Token name (e.g., Kiro Agent)"
                        className="w-full px-4 py-3 rounded-lg bg-white/5 border border-white/10 focus:border-blue-500 focus:outline-none mb-4"
                    />
                    <div className="flex gap-3">
                        <button onClick={handleCreateToken} disabled={isCreating || !newTokenName.trim()} className="flex items-center gap-2 px-4 py-2 rounded-lg bg-blue-600 hover:bg-blue-700 disabled:opacity-50 transition-colors text-sm font-medium">
                            {isCreating ? <Loader2 size={16} className="animate-spin" /> : <Plus size={16} />}
                            Create
                        </button>
                        <button onClick={() => setShowCreateModal(false)} className="px-4 py-2 rounded-lg bg-white/5 hover:bg-white/10 transition-colors text-sm">
                            Cancel
                        </button>
                    </div>
                </motion.div>
            )}

            {/* Token List */}
            <div className="rounded-xl border border-white/5 bg-neutral-900/50 overflow-hidden">
                {tokens.length === 0 ? (
                    <div className="p-8 text-center text-neutral-500">
                        <Key size={40} className="mx-auto mb-4 opacity-50" />
                        <p>No API tokens yet. Create one to connect coding agents.</p>
                    </div>
                ) : (
                    <table className="w-full">
                        <thead className="bg-white/5">
                            <tr>
                                <th className="text-left px-6 py-3 text-sm font-medium text-neutral-400">Name</th>
                                <th className="text-left px-6 py-3 text-sm font-medium text-neutral-400">Token</th>
                                <th className="text-left px-6 py-3 text-sm font-medium text-neutral-400">Last Used</th>
                                <th className="text-left px-6 py-3 text-sm font-medium text-neutral-400">Status</th>
                                <th className="text-right px-6 py-3 text-sm font-medium text-neutral-400">Actions</th>
                            </tr>
                        </thead>
                        <tbody className="divide-y divide-white/5">
                            {tokens.map((token) => (
                                <tr key={token.id} className="hover:bg-white/5">
                                    <td className="px-6 py-4 font-medium">{token.name}</td>
                                    <td className="px-6 py-4 font-mono text-sm text-neutral-400">
                                        {token.tokenPrefix}...{token.tokenSuffix}
                                    </td>
                                    <td className="px-6 py-4 text-sm text-neutral-400">
                                        {token.lastUsedAt ? new Date(token.lastUsedAt).toLocaleDateString() : "Never"}
                                    </td>
                                    <td className="px-6 py-4">
                                        <span className={`text-xs px-2 py-1 rounded-full ${token.isActive ? "bg-green-500/20 text-green-400" : "bg-red-500/20 text-red-400"}`}>
                                            {token.isActive ? "Active" : "Revoked"}
                                        </span>
                                    </td>
                                    <td className="px-6 py-4 text-right">
                                        {token.isActive && (
                                            <button onClick={() => handleRevokeToken(token.id)} className="p-2 text-red-400 hover:bg-red-500/10 rounded transition-colors">
                                                <Trash2 size={16} />
                                            </button>
                                        )}
                                    </td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                )}
            </div>
        </div>
    );
}


function UsageTab({ usage }: { usage: McpUsageEntry[] }) {
    return (
        <div className="space-y-6">
            <h3 className="text-lg font-semibold">API Usage History</h3>
            <div className="rounded-xl border border-white/5 bg-neutral-900/50 overflow-hidden">
                {usage.length === 0 ? (
                    <div className="p-8 text-center text-neutral-500">
                        <Activity size={40} className="mx-auto mb-4 opacity-50" />
                        <p>No API usage recorded yet.</p>
                    </div>
                ) : (
                    <table className="w-full">
                        <thead className="bg-white/5">
                            <tr>
                                <th className="text-left px-6 py-3 text-sm font-medium text-neutral-400">Endpoint</th>
                                <th className="text-left px-6 py-3 text-sm font-medium text-neutral-400">Token</th>
                                <th className="text-left px-6 py-3 text-sm font-medium text-neutral-400">IP Address</th>
                                <th className="text-left px-6 py-3 text-sm font-medium text-neutral-400">Time</th>
                            </tr>
                        </thead>
                        <tbody className="divide-y divide-white/5">
                            {usage.map((entry) => (
                                <tr key={entry.id} className="hover:bg-white/5">
                                    <td className="px-6 py-4 font-mono text-sm text-blue-400">{entry.endpoint}</td>
                                    <td className="px-6 py-4">
                                        <div className="text-sm">{entry.tokenName}</div>
                                        <div className="text-xs text-neutral-500 font-mono">{entry.tokenPrefix}...</div>
                                    </td>
                                    <td className="px-6 py-4 text-sm text-neutral-400">{entry.ipAddress || "N/A"}</td>
                                    <td className="px-6 py-4 text-sm text-neutral-400">{new Date(entry.createdAt).toLocaleString()}</td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                )}
            </div>
        </div>
    );
}

function SourcesTab({ sources }: { sources: VerifiedSource[] }) {
    const [expandedSource, setExpandedSource] = useState<string | null>(null);

    const getLanguageColor = (lang: string) => {
        const colors: Record<string, string> = {
            javascript: "text-yellow-400",
            typescript: "text-blue-400",
            python: "text-green-400",
            dart: "text-cyan-400",
            json: "text-orange-400",
        };
        return colors[lang.toLowerCase()] || "text-neutral-400";
    };

    return (
        <div className="space-y-6">
            <h3 className="text-lg font-semibold">Verified Code Sources</h3>
            {sources.length === 0 ? (
                <div className="rounded-xl border border-white/5 bg-neutral-900/50 p-8 text-center text-neutral-500">
                    <Code size={40} className="mx-auto mb-4 opacity-50" />
                    <p>No verified code sources yet.</p>
                    <p className="text-sm mt-2">Code verified by AI agents will appear here.</p>
                </div>
            ) : (
                <div className="space-y-4">
                    {sources.map((source) => (
                        <div key={source.id} className="rounded-xl border border-white/5 bg-neutral-900/50 overflow-hidden">
                            <div className="p-4 flex items-center justify-between cursor-pointer hover:bg-white/5" onClick={() => setExpandedSource(expandedSource === source.id ? null : source.id)}>
                                <div className="flex items-center gap-3">
                                    <Code size={18} className={getLanguageColor(source.metadata.language)} />
                                    <div>
                                        <div className="font-medium">{source.title}</div>
                                        <div className="text-xs text-neutral-500 flex items-center gap-2">
                                            <span className={getLanguageColor(source.metadata.language)}>{source.metadata.language}</span>
                                            <span>•</span>
                                            <span>{new Date(source.created_at).toLocaleDateString()}</span>
                                            {source.metadata.agentName && (
                                                <>
                                                    <span>•</span>
                                                    <span className="text-purple-400">{source.metadata.agentName}</span>
                                                </>
                                            )}
                                        </div>
                                    </div>
                                </div>
                                <div className="flex items-center gap-2">
                                    {source.metadata.verification?.score && (
                                        <span className={`text-xs px-2 py-1 rounded-full ${source.metadata.verification.score >= 80 ? "bg-green-500/20 text-green-400" : source.metadata.verification.score >= 60 ? "bg-yellow-500/20 text-yellow-400" : "bg-red-500/20 text-red-400"}`}>
                                            Score: {source.metadata.verification.score}
                                        </span>
                                    )}
                                    {expandedSource === source.id ? <EyeOff size={16} /> : <Eye size={16} />}
                                </div>
                            </div>
                            {expandedSource === source.id && (
                                <motion.div initial={{ height: 0 }} animate={{ height: "auto" }} className="border-t border-white/5">
                                    <pre className="p-4 overflow-x-auto text-sm bg-black/30">
                                        <code>{source.content}</code>
                                    </pre>
                                </motion.div>
                            )}
                        </div>
                    ))}
                </div>
            )}
        </div>
    );
}
