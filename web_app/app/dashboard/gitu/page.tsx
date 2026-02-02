"use client";

import React, { useEffect, useState } from "react";
import {
    Sparkles,
    Settings,
    MessageCircle,
    Send,
    ShoppingBag,
    Shield,
    Globe,
    Zap,
    Bot,
    ArrowLeft,
    Loader2,
    Check,
    X,
    Trash2,
    RefreshCw,
    ExternalLink,
    Mail,
    Smartphone,
    Terminal,
    Eye,
    EyeOff,
    Link as LinkIcon,
} from "lucide-react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { motion, AnimatePresence } from "framer-motion";
import { useAuth } from "@/lib/auth-context";
import api, { GituSettings, LinkedAccount, WhatsAppStatus, ShopifyStatus, AIModelOption } from "@/lib/api";

type Tab = "overview" | "connections" | "settings";

export default function GituDashboardPage() {
    const { user, isLoading: authLoading, isAuthenticated } = useAuth();
    const router = useRouter();
    const [settings, setSettings] = useState<GituSettings | null>(null);
    const [accounts, setAccounts] = useState<LinkedAccount[]>([]);
    const [waStatus, setWaStatus] = useState<WhatsAppStatus | null>(null);
    const [shopifyStatus, setShopifyStatus] = useState<ShopifyStatus | null>(null);
    const [aiModels, setAiModels] = useState<AIModelOption[]>([]);
    const [isLoading, setIsLoading] = useState(true);
    const [activeTab, setActiveTab] = useState<Tab>("overview");

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
            const [settingsData, accountsData, waStatusData, shopifyStatusData, modelsData] = await Promise.all([
                api.getGituSettings().catch(() => null),
                api.getLinkedAccounts().catch(() => []),
                api.getWhatsAppStatus().catch(() => null),
                api.getShopifyStatus().catch(() => null),
                api.getAIModels().catch(() => []),
            ]);
            setSettings(settingsData);
            setAccounts(accountsData);
            setWaStatus(waStatusData);
            setShopifyStatus(shopifyStatusData);
            setAiModels(modelsData);
        } catch (error) {
            console.error("Failed to load Gitu data:", error);
        } finally {
            setIsLoading(false);
        }
    };

    const toggleGitu = async () => {
        if (!settings) return;
        const newStatus = !settings.enabled;
        try {
            await api.toggleGituEnabled(newStatus);
            setSettings({ ...settings, enabled: newStatus });
        } catch (error) {
            alert("Failed to toggle Gitu");
        }
    };

    if (authLoading || (!isAuthenticated && !authLoading)) {
        return (
            <div className="min-h-screen bg-neutral-950 flex items-center justify-center">
                <Loader2 className="animate-spin text-blue-500" size={40} />
            </div>
        );
    }

    return (
        <div className="min-h-screen bg-neutral-950 text-white pb-20">
            <nav className="border-b border-white/5 bg-neutral-900/50 backdrop-blur-xl sticky top-0 z-50">
                <div className="container mx-auto flex h-16 items-center justify-between px-6">
                    <div className="flex items-center gap-4">
                        <Link href="/dashboard" className="p-2 hover:bg-white/5 rounded-lg transition-colors">
                            <ArrowLeft size={20} />
                        </Link>
                        <div className="flex items-center gap-2">
                            <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-blue-600/20 text-blue-400">
                                <Sparkles size={20} />
                            </div>
                            <span className="font-bold tracking-tight">Gitu Assistant</span>
                        </div>
                    </div>
                    <div className="flex items-center gap-4">
                        <div className="flex items-center gap-2 px-3 py-1.5 rounded-full bg-white/5 border border-white/10">
                            <div className={`h-2 w-2 rounded-full ${settings?.enabled ? 'bg-green-500' : 'bg-red-500'} animate-pulse`} />
                            <span className="text-xs font-medium">{settings?.enabled ? 'Systems Active' : 'Disconnected'}</span>
                        </div>
                    </div>
                </div>
            </nav>

            <main className="container mx-auto px-6 py-8">
                <header className="mb-8 flex flex-col md:flex-row md:items-end justify-between gap-6">
                    <div>
                        <h1 className="text-3xl font-bold tracking-tight">Gitu Dashboard</h1>
                        <p className="text-neutral-400 mt-1">Manage your universal AI assistant and connected platforms.</p>
                    </div>

                    <div className="flex items-center gap-3">
                        <button
                            onClick={toggleGitu}
                            className={`flex items-center gap-2 px-6 py-3 rounded-xl font-semibold transition-all shadow-lg ${settings?.enabled
                                ? 'bg-neutral-800 text-neutral-400 border border-white/5 hover:bg-neutral-700 hover:text-white'
                                : 'bg-blue-600 text-white hover:bg-blue-700'
                                }`}
                        >
                            {settings?.enabled ? <X size={18} /> : <Check size={18} />}
                            {settings?.enabled ? 'Disable Assistant' : 'Enable Assistant'}
                        </button>
                    </div>
                </header>

                <div className="flex gap-2 mb-8 border-b border-white/10 pb-4">
                    {(["overview", "connections", "settings"] as Tab[]).map((tab) => (
                        <button
                            key={tab}
                            onClick={() => setActiveTab(tab)}
                            className={`px-6 py-2.5 rounded-xl text-sm font-medium transition-all flex items-center gap-2 ${activeTab === tab
                                ? "bg-blue-600 text-white shadow-lg shadow-blue-600/20"
                                : "bg-white/5 text-neutral-400 hover:bg-white/10"
                                }`}
                        >
                            {tab === "overview" && <Globe size={16} />}
                            {tab === "connections" && <LinkIcon size={16} />}
                            {tab === "settings" && <Settings size={16} />}
                            {tab.charAt(0).toUpperCase() + tab.slice(1)}
                        </button>
                    ))}
                </div>

                <AnimatePresence mode="wait">
                    {isLoading ? (
                        <motion.div
                            initial={{ opacity: 0 }}
                            animate={{ opacity: 1 }}
                            exit={{ opacity: 0 }}
                            className="flex items-center justify-center py-20"
                        >
                            <Loader2 className="animate-spin text-blue-500" size={32} />
                        </motion.div>
                    ) : (
                        <motion.div
                            key={activeTab}
                            initial={{ opacity: 0, y: 10 }}
                            animate={{ opacity: 1, y: 0 }}
                            exit={{ opacity: 0, y: -10 }}
                            transition={{ duration: 0.2 }}
                        >
                            {activeTab === "overview" && (
                                <OverviewTab
                                    settings={settings}
                                    accounts={accounts}
                                    waStatus={waStatus}
                                    shopifyStatus={shopifyStatus}
                                />
                            )}
                            {activeTab === "connections" && (
                                <ConnectionsTab
                                    waStatus={waStatus}
                                    accounts={accounts}
                                    shopifyStatus={shopifyStatus}
                                    onRefresh={loadData}
                                />
                            )}
                            {activeTab === "settings" && (
                                <SettingsTab
                                    settings={settings}
                                    aiModels={aiModels}
                                    onRefresh={loadData}
                                />
                            )}
                        </motion.div>
                    )}
                </AnimatePresence>
            </main>
        </div>
    );
}

function OverviewTab({ settings, accounts, waStatus, shopifyStatus }: {
    settings: GituSettings | null;
    accounts: LinkedAccount[];
    waStatus: WhatsAppStatus | null;
    shopifyStatus: ShopifyStatus | null;
}) {
    return (
        <div className="space-y-8">
            <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
                <StatusCard
                    title="Assistant Core"
                    status={settings?.enabled ? 'active' : 'inactive'}
                    description="Standard response & task processing engine"
                    icon={<Bot size={20} />}
                />
                <StatusCard
                    title="WhatsApp"
                    status={waStatus?.connected ? 'active' : 'inactive'}
                    description={waStatus?.account?.jid || "Not connected"}
                    icon={<MessageCircle size={20} />}
                />
                <StatusCard
                    title="Shopify"
                    status={shopifyStatus?.connected ? 'active' : 'inactive'}
                    description={shopifyStatus?.shopUrl || "Not connected"}
                    icon={<ShoppingBag size={20} />}
                />
            </div>

            <div className="grid gap-8 lg:grid-cols-2">
                <div className="rounded-3xl border border-white/5 bg-neutral-900/50 p-8 backdrop-blur-sm">
                    <h3 className="text-xl font-bold mb-6 flex items-center gap-3">
                        <LinkIcon size={24} className="text-blue-400" />
                        Skills & Identities
                    </h3>
                    <div className="space-y-4">
                        {accounts.length === 0 ? (
                            <div className="py-10 text-center text-neutral-500 border border-dashed border-white/10 rounded-2xl">
                                <p>No linked accounts found.</p>
                                <p className="text-sm mt-1">Connect platforms in the Connections tab.</p>
                            </div>
                        ) : (
                            accounts.map((acc) => (
                                <div key={acc.id} className="flex items-center justify-between p-5 rounded-2xl bg-white/5 hover:bg-white/10 transition-all border border-transparent hover:border-white/5 group">
                                    <div className="flex items-center gap-4">
                                        <div className="p-3 rounded-xl bg-neutral-800 text-neutral-400 group-hover:bg-blue-600/20 group-hover:text-blue-400 transition-colors">
                                            {acc.platform === 'whatsapp' && <MessageCircle size={20} />}
                                            {acc.platform === 'telegram' && <Send size={20} />}
                                            {acc.platform === 'email' && <Mail size={20} />}
                                            {acc.platform === 'flutter' && <Smartphone size={20} />}
                                            {acc.platform === 'terminal' && <Terminal size={20} />}
                                        </div>
                                        <div>
                                            <div className="font-bold flex items-center gap-2">
                                                {acc.platform.toUpperCase()}
                                                {acc.verified && <Check size={14} className="text-green-500" />}
                                            </div>
                                            <div className="text-sm text-neutral-500 truncate max-w-[200px]">{acc.displayName || acc.platformUserId}</div>
                                        </div>
                                    </div>
                                    <div className="flex items-center gap-2">
                                        {acc.isPrimary && (
                                            <span className="px-2.5 py-1 rounded-full bg-blue-500/20 text-blue-400 text-[10px] font-bold uppercase tracking-wider">Primary</span>
                                        )}
                                        <span className={`px-2.5 py-1 rounded-full text-[10px] font-bold uppercase tracking-wider ${acc.status === 'active' ? 'bg-green-500/20 text-green-400' : 'bg-red-500/20 text-red-400'
                                            }`}>
                                            {acc.status}
                                        </span>
                                    </div>
                                </div>
                            ))
                        )}
                    </div>
                </div>

                <div className="rounded-3xl border border-white/5 bg-neutral-900/50 p-8 backdrop-blur-sm">
                    <h3 className="text-xl font-bold mb-6 flex items-center gap-3">
                        <Zap size={24} className="text-amber-400" />
                        Active Features
                    </h3>
                    <div className="grid gap-4 sm:grid-cols-2">
                        <FeatureItem title="Translate" status="available" description="Multi-language support" />
                        <FeatureItem title="Shopify Analytics" status={shopifyStatus?.connected ? "available" : "unavailable"} description="Store insights" />
                        <FeatureItem title="Shell Control" status="available" description="Terminal execution" />
                        <FeatureItem title="Web Research" status="available" description="Deep web crawling" />
                    </div>
                </div>
            </div>
        </div>
    );
}

function StatusCard({ title, status, description, icon }: { title: string; status: 'active' | 'inactive'; description: string; icon: React.ReactNode }) {
    return (
        <div className="rounded-3xl border border-white/5 bg-neutral-900/50 p-6 backdrop-blur-sm hover:bg-neutral-800/80 transition-all border-l-4 border-l-transparent hover:border-l-blue-500">
            <div className="flex items-center justify-between mb-4">
                <div className="p-3 rounded-2xl bg-white/5 text-neutral-400">{icon}</div>
                <div className={`px-3 py-1 rounded-full text-[10px] font-bold uppercase tracking-widest ${status === 'active' ? 'bg-green-500/20 text-green-400' : 'bg-red-500/20 text-red-400'
                    }`}>
                    {status}
                </div>
            </div>
            <h3 className="text-lg font-bold mb-1">{title}</h3>
            <p className="text-sm text-neutral-500 truncate">{description}</p>
        </div>
    );
}

function FeatureItem({ title, status, description }: { title: string; status: 'available' | 'unavailable'; description: string }) {
    return (
        <div className={`p-4 rounded-2xl border transition-all ${status === 'available' ? 'border-white/5 bg-white/5 hover:bg-white/10' : 'border-white/5 bg-neutral-950 opacity-40 grayscale'
            }`}>
            <div className="flex items-center gap-2 mb-1">
                <h4 className="font-bold text-sm tracking-tight">{title}</h4>
                {status === 'available' && <Check size={12} className="text-green-500" />}
            </div>
            <p className="text-xs text-neutral-500">{description}</p>
        </div>
    );
}

function ConnectionsTab({ waStatus, accounts, shopifyStatus, onRefresh }: {
    waStatus: WhatsAppStatus | null;
    accounts: LinkedAccount[];
    shopifyStatus: ShopifyStatus | null;
    onRefresh: () => void;
}) {
    const [isRefreshing, setIsRefreshing] = useState(false);
    const [shopifyUrl, setShopifyUrl] = useState("");
    const [isConnectingShopify, setIsConnectingShopify] = useState(false);
    const [telegramId, setTelegramId] = useState("");
    const [isLinkingTelegram, setIsLinkingTelegram] = useState(false);

    const refresh = async () => {
        setIsRefreshing(true);
        await onRefresh();
        setIsRefreshing(false);
    };

    const handleWhatsAppLink = async () => {
        try {
            await api.linkWhatsAppCurrentSession();
            alert("WhatsApp account linked successfully!");
            onRefresh();
        } catch (error: any) {
            alert(error.message);
        }
    };

    const handleTelegramLink = async () => {
        if (!telegramId) return;
        setIsLinkingTelegram(true);
        try {
            await api.linkIdentity('telegram', telegramId);
            setTelegramId("");
            onRefresh();
        } catch (error: any) {
            alert(error.message);
        } finally {
            setIsLinkingTelegram(false);
        }
    };

    const handleShopifyConnect = async () => {
        if (!shopifyUrl) return;
        setIsConnectingShopify(true);
        try {
            const { authUrl } = await api.connectShopify(shopifyUrl);
            window.location.href = authUrl;
        } catch (error: any) {
            alert(error.message);
        } finally {
            setIsConnectingShopify(false);
        }
    };

    const handleUnlink = async (acc: LinkedAccount) => {
        if (!confirm(`Unlink ${acc.platform} account ${acc.platformUserId}?`)) return;
        try {
            await api.unlinkIdentity(acc.platform, acc.platformUserId);
            onRefresh();
        } catch (error: any) {
            alert(error.message);
        }
    };

    return (
        <div className="space-y-8">
            <div className="flex items-center justify-between">
                <h2 className="text-xl font-bold flex items-center gap-3">
                    <Globe size={24} className="text-blue-400" />
                    Manage Connections
                </h2>
                <button
                    onClick={refresh}
                    disabled={isRefreshing}
                    className="p-3 rounded-full bg-white/5 hover:bg-white/10 transition-all text-neutral-400 hover:text-white"
                >
                    <RefreshCw size={20} className={isRefreshing ? "animate-spin" : ""} />
                </button>
            </div>

            <div className="grid gap-8 lg:grid-cols-2">
                {/* WhatsApp Connection */}
                <div className="rounded-3xl border border-white/5 bg-neutral-900/50 p-8 backdrop-blur-sm shadow-xl overflow-hidden relative group">
                    <div className="absolute top-0 right-0 p-10 -mr-10 -mt-10 bg-green-500/10 rounded-full blur-3xl group-hover:bg-green-500/20 transition-all duration-500" />
                    <div className="relative z-10">
                        <div className="flex items-center gap-4 mb-6">
                            <div className="p-4 rounded-2xl bg-green-500/20 text-green-400">
                                <MessageCircle size={32} />
                            </div>
                            <div>
                                <h3 className="text-xl font-bold">WhatsApp</h3>
                                <p className="text-neutral-500 text-sm">Automated communication skill</p>
                            </div>
                        </div>

                        {waStatus?.connected ? (
                            <div className="space-y-6">
                                <div className="p-6 rounded-2xl bg-white/5 border border-white/5 space-y-4">
                                    <div className="flex justify-between items-center text-sm">
                                        <span className="text-neutral-500">Connected As:</span>
                                        <span className="font-bold text-green-400">{waStatus.account?.name || "Gitu Business"}</span>
                                    </div>
                                    <div className="flex justify-between items-center text-sm">
                                        <span className="text-neutral-500">JID:</span>
                                        <span className="text-neutral-400 font-mono text-xs">{waStatus.account?.jid}</span>
                                    </div>
                                </div>
                                <button
                                    onClick={handleWhatsAppLink}
                                    className="w-full py-4 rounded-2xl bg-green-600 hover:bg-green-700 text-white font-bold transition-all shadow-lg shadow-green-900/20"
                                >
                                    Link to My Account
                                </button>
                            </div>
                        ) : (
                            <div className="space-y-6 text-center">
                                <div className="p-8 rounded-3xl bg-neutral-950 flex flex-col items-center border border-white/5 group-hover:border-green-500/50 transition-all">
                                    {waStatus?.qrCode ? (
                                        <>
                                            <div className="bg-white p-4 rounded-3xl shadow-2xl mb-6">
                                                <img src={waStatus.qrCode} alt="WhatsApp QR" className="w-48 h-48" />
                                            </div>
                                            <p className="text-sm text-neutral-400">Scan this QR code with WhatsApp on your phone</p>
                                        </>
                                    ) : (
                                        <div className="py-20 flex flex-col items-center gap-4">
                                            <Loader2 className="animate-spin text-green-500" size={40} />
                                            <p className="text-neutral-500 text-sm">Initializing WhatsApp Adapter...</p>
                                        </div>
                                    )}
                                </div>
                            </div>
                        )}
                    </div>
                </div>

                {/* Shopify Connection */}
                <div className="rounded-3xl border border-white/5 bg-neutral-900/50 p-8 backdrop-blur-sm shadow-xl overflow-hidden relative group">
                    <div className="absolute top-0 right-0 p-10 -mr-10 -mt-10 bg-blue-500/10 rounded-full blur-3xl group-hover:bg-blue-500/20 transition-all duration-500" />
                    <div className="relative z-10">
                        <div className="flex items-center gap-4 mb-6">
                            <div className="p-4 rounded-2xl bg-blue-500/20 text-blue-400">
                                <ShoppingBag size={32} />
                            </div>
                            <div>
                                <h3 className="text-xl font-bold">Shopify</h3>
                                <p className="text-neutral-500 text-sm">E-commerce management skill</p>
                            </div>
                        </div>

                        {shopifyStatus?.connected ? (
                            <div className="space-y-6">
                                <div className="p-6 rounded-2xl bg-white/5 border border-white/5 space-y-4 text-center">
                                    <Globe className="mx-auto text-blue-400" size={32} />
                                    <div>
                                        <div className="font-bold text-lg">{shopifyStatus.shopUrl}</div>
                                        <p className="text-xs text-neutral-500 mt-1">Authorized Gitu assistant access</p>
                                    </div>
                                </div>
                                <button
                                    onClick={() => api.disconnectShopify().then(onRefresh)}
                                    className="w-full py-4 rounded-2xl bg-neutral-800 hover:bg-red-950/30 hover:text-red-400 text-neutral-400 font-bold transition-all border border-white/5"
                                >
                                    Disconnect Store
                                </button>
                            </div>
                        ) : (
                            <div className="space-y-4">
                                <input
                                    type="text"
                                    placeholder="your-store.myshopify.com"
                                    value={shopifyUrl}
                                    onChange={(e) => setShopifyUrl(e.target.value)}
                                    className="w-full p-5 rounded-2xl bg-neutral-950 border border-white/5 focus:border-blue-500 transition-all outline-none font-bold"
                                />
                                <button
                                    onClick={handleShopifyConnect}
                                    disabled={isConnectingShopify || !shopifyUrl}
                                    className="w-full py-4 rounded-2xl bg-blue-600 hover:bg-blue-700 disabled:opacity-50 text-white font-bold transition-all shadow-lg shadow-blue-900/20"
                                >
                                    {isConnectingShopify ? <Loader2 className="animate-spin mx-auto" /> : 'Connect Store'}
                                </button>
                            </div>
                        )}
                    </div>
                </div>

                {/* Telegram & Others */}
                <div className="lg:col-span-2 rounded-3xl border border-white/5 bg-neutral-900/50 p-8 backdrop-blur-sm sm:p-10">
                    <div className="flex flex-col md:flex-row gap-10">
                        <div className="flex-1 space-y-6">
                            <h3 className="text-xl font-bold flex items-center gap-3">
                                <Send size={24} className="text-sky-400" />
                                Telegram Bot
                            </h3>
                            <p className="text-neutral-500 text-sm">Link your Telegram account to interact with Gitu on the go.</p>
                            <div className="space-y-4 border border-white/5 rounded-2xl p-6 bg-neutral-950">
                                <p className="text-xs text-neutral-400 font-medium pb-2 border-b border-white/5">INSTRUCTIONS</p>
                                <ol className="text-xs text-neutral-500 space-y-3 list-decimal pl-4">
                                    <li>Find our boot on Telegram (Search: @GituAssistantBot)</li>
                                    <li>Send <b>/id</b> to the bot to get your User ID</li>
                                    <li>Enter the ID below to verify your account</li>
                                </ol>
                            </div>
                            <div className="flex gap-2">
                                <input
                                    type="text"
                                    placeholder="Telegram User ID"
                                    value={telegramId}
                                    onChange={(e) => setTelegramId(e.target.value)}
                                    className="flex-1 p-4 rounded-2xl bg-neutral-950 border border-white/5 focus:border-sky-500 transition-all outline-none font-mono"
                                />
                                <button
                                    onClick={handleTelegramLink}
                                    disabled={isLinkingTelegram || !telegramId}
                                    className="p-4 rounded-2xl bg-sky-600 hover:bg-sky-700 text-white transition-all disabled:opacity-50"
                                >
                                    {isLinkingTelegram ? <Loader2 className="animate-spin" /> : <LinkIcon size={20} />}
                                </button>
                            </div>
                        </div>

                        <div className="w-[1px] bg-white/5 hidden md:block" />

                        <div className="flex-1 space-y-6">
                            <h3 className="text-xl font-bold">Active Identities</h3>
                            <div className="space-y-3">
                                {accounts.map(acc => (
                                    <div key={acc.id} className="flex items-center justify-between p-4 rounded-2xl bg-white/5 border border-white/5 group">
                                        <div className="flex items-center gap-3">
                                            <div className="text-neutral-400 group-hover:text-blue-400 transition-colors">
                                                {acc.platform === 'telegram' && <Send size={18} />}
                                                {acc.platform === 'whatsapp' && <MessageCircle size={18} />}
                                                {acc.platform === 'terminal' && <Terminal size={18} />}
                                            </div>
                                            <div>
                                                <div className="text-sm font-bold">{acc.platformUserId}</div>
                                                <div className="text-[10px] text-neutral-500 font-mono tracking-tighter uppercase">{acc.platform}</div>
                                            </div>
                                        </div>
                                        <button
                                            onClick={() => handleUnlink(acc)}
                                            className="p-2 rounded-lg text-neutral-600 hover:text-red-400 hover:bg-red-400/10 transition-all opacity-0 group-hover:opacity-100"
                                        >
                                            <Trash2 size={16} />
                                        </button>
                                    </div>
                                ))}
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    );
}

function SettingsTab({ settings, aiModels, onRefresh }: {
    settings: GituSettings | null;
    aiModels: AIModelOption[];
    onRefresh: () => void;
}) {
    const [isSaving, setIsSaving] = useState(false);
    const [apiKeySource, setApiKeySource] = useState<'platform' | 'personal'>('platform');
    const [defaultModel, setDefaultModel] = useState<string>('default');
    const [taskSpecificModels, setTaskSpecificModels] = useState<Record<string, string>>({});
    const [personalKeys, setPersonalKeys] = useState<Record<string, string>>({});
    const [showKey, setShowKey] = useState<string | null>(null);

    useEffect(() => {
        if (!settings) return;
        setApiKeySource(settings.modelPreferences.apiKeySource || 'platform');
        setDefaultModel(settings.modelPreferences.defaultModel || 'default');
        setTaskSpecificModels(settings.modelPreferences.taskSpecificModels || {});
        setPersonalKeys(settings.modelPreferences.personalKeys || {});
    }, [settings]);

    const handleSave = async () => {
        if (!settings) return;
        setIsSaving(true);
        try {
            await api.updateGituSettings({
                modelPreferences: {
                    ...settings.modelPreferences,
                    apiKeySource,
                    defaultModel,
                    taskSpecificModels,
                    personalKeys,
                }
            });
            onRefresh();
            alert("Settings saved successfully!");
        } catch (error: any) {
            alert(error.message);
        } finally {
            setIsSaving(false);
        }
    };

    return (
        <div className="space-y-10 max-w-4xl">
            <div className="space-y-6">
                <h3 className="text-xl font-bold flex items-center gap-3">
                    <Shield size={24} className="text-blue-400" />
                    Security & AI Models
                </h3>

                <div className="rounded-3xl border border-white/5 bg-neutral-900/50 p-8 backdrop-blur-sm space-y-8">
                    <div className="space-y-4">
                        <label className="text-sm font-bold text-neutral-400 uppercase tracking-widest">Model Routing</label>
                        <div className="space-y-6">
                            <div className="space-y-2">
                                <label className="text-xs font-bold text-neutral-500 uppercase tracking-tighter ml-1">Default Model</label>
                                <select
                                    value={defaultModel}
                                    onChange={(e) => setDefaultModel(e.target.value)}
                                    className="w-full p-4 rounded-2xl bg-neutral-950 border border-white/5 focus:border-blue-500 outline-none transition-all text-sm"
                                >
                                    <option value="default">Auto (recommended)</option>
                                    {aiModels.map((m) => (
                                        <option key={m.modelId} value={m.modelId}>
                                            {m.name} ({m.provider})
                                        </option>
                                    ))}
                                </select>
                            </div>

                            <div className="space-y-3">
                                <div className="text-xs font-bold text-neutral-500 uppercase tracking-tighter ml-1">Per-Task Model Overrides</div>
                                <div className="grid md:grid-cols-2 gap-4">
                                    {([
                                        { key: "chat", label: "Chat" },
                                        { key: "research", label: "Research" },
                                        { key: "coding", label: "Coding" },
                                        { key: "analysis", label: "Analysis" },
                                        { key: "summarization", label: "Summarization" },
                                        { key: "creative", label: "Creative" },
                                    ] as const).map((t) => (
                                        <div key={t.key} className="space-y-2">
                                            <label className="text-[10px] font-bold text-neutral-500 uppercase tracking-tighter ml-1">{t.label}</label>
                                            <select
                                                value={taskSpecificModels[t.key] || "default"}
                                                onChange={(e) => setTaskSpecificModels({ ...taskSpecificModels, [t.key]: e.target.value })}
                                                className="w-full p-3 rounded-2xl bg-neutral-950 border border-white/5 focus:border-blue-500 outline-none transition-all text-sm"
                                            >
                                                <option value="default">Use default</option>
                                                {aiModels.map((m) => (
                                                    <option key={`${t.key}:${m.modelId}`} value={m.modelId}>
                                                        {m.name} ({m.provider})
                                                    </option>
                                                ))}
                                            </select>
                                        </div>
                                    ))}
                                </div>
                            </div>
                        </div>
                    </div>

                    <div className="space-y-4">
                        <label className="text-sm font-bold text-neutral-400 uppercase tracking-widest">API Key Source</label>
                        <div className="grid sm:grid-cols-2 gap-4">
                            <button
                                onClick={() => setApiKeySource('platform')}
                                className={`p-6 rounded-3xl border-2 text-left transition-all ${apiKeySource === 'platform'
                                    ? 'border-blue-500 bg-blue-500/10 text-white'
                                    : 'border-white/5 bg-neutral-950 text-neutral-500 hover:border-white/10'
                                    }`}
                            >
                                <div className="font-bold mb-1">Gitu Platform</div>
                                <p className="text-xs opacity-70">Use centralized API credits included in your monthly subscription.</p>
                            </button>
                            <button
                                onClick={() => setApiKeySource('personal')}
                                className={`p-6 rounded-3xl border-2 text-left transition-all ${apiKeySource === 'personal'
                                    ? 'border-purple-500 bg-purple-500/10 text-white'
                                    : 'border-white/5 bg-neutral-950 text-neutral-500 hover:border-white/10'
                                    }`}
                            >
                                <div className="font-bold mb-1">Personal Keys</div>
                                <p className="text-xs opacity-70">Bring your own API keys for OpenRouter, Gemini, or Anthropic.</p>
                            </button>
                        </div>
                    </div>

                    {apiKeySource === 'personal' && (
                        <div className="space-y-6 pt-6 border-t border-white/5">
                            <div className="space-y-4">
                                <KeyField
                                    label="OpenRouter Key"
                                    name="openrouter"
                                    value={personalKeys.openrouter || ""}
                                    isVisible={showKey === 'openrouter'}
                                    toggleVisible={() => setShowKey(showKey === 'openrouter' ? null : 'openrouter')}
                                    onChange={(v) => setPersonalKeys({ ...personalKeys, openrouter: v })}
                                />
                                <KeyField
                                    label="Gemini AI Key"
                                    name="gemini"
                                    value={personalKeys.gemini || ""}
                                    isVisible={showKey === 'gemini'}
                                    toggleVisible={() => setShowKey(showKey === 'gemini' ? null : 'gemini')}
                                    onChange={(v) => setPersonalKeys({ ...personalKeys, gemini: v })}
                                />
                                <KeyField
                                    label="OpenAI Key"
                                    name="openai"
                                    value={personalKeys.openai || ""}
                                    isVisible={showKey === 'openai'}
                                    toggleVisible={() => setShowKey(showKey === 'openai' ? null : 'openai')}
                                    onChange={(v) => setPersonalKeys({ ...personalKeys, openai: v })}
                                />
                                <KeyField
                                    label="Anthropic Key"
                                    name="anthropic"
                                    value={personalKeys.anthropic || ""}
                                    isVisible={showKey === 'anthropic'}
                                    toggleVisible={() => setShowKey(showKey === 'anthropic' ? null : 'anthropic')}
                                    onChange={(v) => setPersonalKeys({ ...personalKeys, anthropic: v })}
                                />
                            </div>
                        </div>
                    )}
                </div>
            </div>

            <div className="pt-6">
                <button
                    onClick={handleSave}
                    disabled={isSaving}
                    className="flex items-center gap-2 px-10 py-5 rounded-2xl bg-blue-600 hover:bg-blue-700 text-white font-bold transition-all shadow-xl shadow-blue-900/20 disabled:opacity-50"
                >
                    {isSaving ? <Loader2 className="animate-spin" /> : <Check size={20} />}
                    Save Settings
                </button>
            </div>
        </div>
    );
}

function KeyField({ label, name, value, isVisible, toggleVisible, onChange }: {
    label: string;
    name: string;
    value: string;
    isVisible: boolean;
    toggleVisible: () => void;
    onChange: (v: string) => void;
}) {
    return (
        <div className="space-y-2">
            <label className="text-xs font-bold text-neutral-500 uppercase tracking-tighter ml-1">{label}</label>
            <div className="relative group">
                <input
                    type={isVisible ? "text" : "password"}
                    value={value}
                    onChange={(e) => onChange(e.target.value)}
                    placeholder={`sk-...`}
                    className="w-full p-4 pr-14 rounded-2xl bg-neutral-950 border border-white/5 focus:border-purple-500 outline-none transition-all font-mono text-sm"
                />
                <button
                    onClick={toggleVisible}
                    className="absolute right-4 top-1/2 -translate-y-1/2 p-2 rounded-lg text-neutral-500 hover:text-white hover:bg-white/5 transition-all"
                >
                    {isVisible ? <EyeOff size={18} /> : <Eye size={18} />}
                </button>
            </div>
        </div>
    );
}


