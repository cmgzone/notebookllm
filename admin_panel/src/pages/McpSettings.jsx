import { useState, useEffect } from 'react';
import api from '../lib/api';
import { Bot, Settings, Users, Activity, Save, Loader2, ToggleLeft, ToggleRight, RefreshCw } from 'lucide-react';

export default function McpSettings() {
    const [settings, setSettings] = useState(null);
    const [stats, setStats] = useState(null);
    const [users, setUsers] = useState([]);
    const [loading, setLoading] = useState(true);
    const [saving, setSaving] = useState(false);
    const [activeTab, setActiveTab] = useState('settings');

    useEffect(() => {
        fetchData();
    }, []);

    const fetchData = async () => {
        setLoading(true);
        try {
            const [settingsRes, statsRes, usageRes] = await Promise.all([
                api.getMcpSettings(),
                api.getMcpStats(),
                api.getMcpUsage(),
            ]);
            setSettings(settingsRes.settings);
            setStats(statsRes);
            setUsers(usageRes.users || []);
        } catch (error) {
            console.error('Failed to fetch MCP data:', error);
            alert('Failed to load MCP settings');
        } finally {
            setLoading(false);
        }
    };

    const handleSave = async () => {
        setSaving(true);
        try {
            await api.updateMcpSettings(settings);
            alert('MCP settings saved successfully!');
            fetchData();
        } catch (error) {
            console.error('Failed to save settings:', error);
            alert('Failed to save settings: ' + error.message);
        } finally {
            setSaving(false);
        }
    };

    const updateSetting = (key, value) => {
        setSettings(prev => ({ ...prev, [key]: value }));
    };

    if (loading) {
        return (
            <div className="flex items-center justify-center h-64">
                <Loader2 className="h-8 w-8 animate-spin" />
            </div>
        );
    }

    return (
        <div className="p-8 space-y-8">
            <div className="mb-8">
                <h1 className="text-3xl font-bold mb-2 flex items-center gap-3">
                    <Bot className="h-8 w-8" />
                    MCP Settings
                </h1>
                <p className="text-muted-foreground">
                    Configure MCP (Model Context Protocol) limits and monitor usage across plans.
                </p>
            </div>

            {/* Tabs */}
            <div className="flex gap-2 border-b border-border pb-4">
                {['settings', 'usage', 'stats'].map((tab) => (
                    <button
                        key={tab}
                        onClick={() => setActiveTab(tab)}
                        className={`px-4 py-2 rounded-t-lg text-sm font-medium transition-colors ${
                            activeTab === tab
                                ? 'bg-primary text-primary-foreground'
                                : 'bg-muted hover:bg-muted/80'
                        }`}
                    >
                        {tab.charAt(0).toUpperCase() + tab.slice(1)}
                    </button>
                ))}
            </div>

            {activeTab === 'settings' && (
                <SettingsTab
                    settings={settings}
                    updateSetting={updateSetting}
                    onSave={handleSave}
                    saving={saving}
                />
            )}

            {activeTab === 'usage' && (
                <UsageTab users={users} onRefresh={fetchData} />
            )}

            {activeTab === 'stats' && (
                <StatsTab stats={stats} settings={settings} />
            )}
        </div>
    );
}

function SettingsTab({ settings, updateSetting, onSave, saving }) {
    if (!settings) return null;

    return (
        <div className="space-y-6">
            {/* Global Toggle */}
            <div className="rounded-lg bg-card border border-border p-6">
                <div className="flex items-center justify-between">
                    <div>
                        <h3 className="text-lg font-semibold">MCP Status</h3>
                        <p className="text-sm text-muted-foreground">
                            Enable or disable MCP functionality globally
                        </p>
                    </div>
                    <button
                        onClick={() => updateSetting('isMcpEnabled', !settings.isMcpEnabled)}
                        className={`flex items-center gap-2 px-4 py-2 rounded-lg font-medium transition-colors ${
                            settings.isMcpEnabled
                                ? 'bg-green-500/20 text-green-600 hover:bg-green-500/30'
                                : 'bg-red-500/20 text-red-600 hover:bg-red-500/30'
                        }`}
                    >
                        {settings.isMcpEnabled ? (
                            <>
                                <ToggleRight className="h-5 w-5" />
                                Enabled
                            </>
                        ) : (
                            <>
                                <ToggleLeft className="h-5 w-5" />
                                Disabled
                            </>
                        )}
                    </button>
                </div>
            </div>

            {/* Plan Limits */}
            <div className="grid gap-6 md:grid-cols-2">
                {/* Free Plan */}
                <div className="rounded-lg bg-card border border-border p-6">
                    <h3 className="text-lg font-semibold mb-4 flex items-center gap-2">
                        <span className="px-2 py-1 rounded bg-muted text-xs font-medium">FREE</span>
                        Free Plan Limits
                    </h3>
                    <div className="space-y-4">
                        <div>
                            <label className="block text-sm font-medium mb-1">Sources Limit</label>
                            <input
                                type="number"
                                min="0"
                                value={settings.freeSourcesLimit}
                                onChange={(e) => updateSetting('freeSourcesLimit', parseInt(e.target.value) || 0)}
                                className="w-full rounded-md border border-border bg-background p-2"
                            />
                            <p className="text-xs text-muted-foreground mt-1">Max verified code sources per user</p>
                        </div>
                        <div>
                            <label className="block text-sm font-medium mb-1">API Tokens Limit</label>
                            <input
                                type="number"
                                min="0"
                                value={settings.freeTokensLimit}
                                onChange={(e) => updateSetting('freeTokensLimit', parseInt(e.target.value) || 0)}
                                className="w-full rounded-md border border-border bg-background p-2"
                            />
                            <p className="text-xs text-muted-foreground mt-1">Max active API tokens per user</p>
                        </div>
                        <div>
                            <label className="block text-sm font-medium mb-1">API Calls per Day</label>
                            <input
                                type="number"
                                min="0"
                                value={settings.freeApiCallsPerDay}
                                onChange={(e) => updateSetting('freeApiCallsPerDay', parseInt(e.target.value) || 0)}
                                className="w-full rounded-md border border-border bg-background p-2"
                            />
                            <p className="text-xs text-muted-foreground mt-1">Daily API call limit</p>
                        </div>
                    </div>
                </div>

                {/* Premium Plan */}
                <div className="rounded-lg bg-card border border-purple-500/30 p-6">
                    <h3 className="text-lg font-semibold mb-4 flex items-center gap-2">
                        <span className="px-2 py-1 rounded bg-purple-500/20 text-purple-400 text-xs font-medium">PREMIUM</span>
                        Premium Plan Limits
                    </h3>
                    <div className="space-y-4">
                        <div>
                            <label className="block text-sm font-medium mb-1">Sources Limit</label>
                            <input
                                type="number"
                                min="0"
                                value={settings.premiumSourcesLimit}
                                onChange={(e) => updateSetting('premiumSourcesLimit', parseInt(e.target.value) || 0)}
                                className="w-full rounded-md border border-border bg-background p-2"
                            />
                            <p className="text-xs text-muted-foreground mt-1">Max verified code sources per user</p>
                        </div>
                        <div>
                            <label className="block text-sm font-medium mb-1">API Tokens Limit</label>
                            <input
                                type="number"
                                min="0"
                                value={settings.premiumTokensLimit}
                                onChange={(e) => updateSetting('premiumTokensLimit', parseInt(e.target.value) || 0)}
                                className="w-full rounded-md border border-border bg-background p-2"
                            />
                            <p className="text-xs text-muted-foreground mt-1">Max active API tokens per user</p>
                        </div>
                        <div>
                            <label className="block text-sm font-medium mb-1">API Calls per Day</label>
                            <input
                                type="number"
                                min="0"
                                value={settings.premiumApiCallsPerDay}
                                onChange={(e) => updateSetting('premiumApiCallsPerDay', parseInt(e.target.value) || 0)}
                                className="w-full rounded-md border border-border bg-background p-2"
                            />
                            <p className="text-xs text-muted-foreground mt-1">Daily API call limit</p>
                        </div>
                    </div>
                </div>
            </div>

            {/* Save Button */}
            <div className="flex justify-end">
                <button
                    onClick={onSave}
                    disabled={saving}
                    className="flex items-center gap-2 px-6 py-3 rounded-lg bg-primary text-primary-foreground font-medium hover:bg-primary/90 disabled:opacity-50"
                >
                    {saving ? <Loader2 className="h-4 w-4 animate-spin" /> : <Save className="h-4 w-4" />}
                    Save Settings
                </button>
            </div>
        </div>
    );
}

function UsageTab({ users, onRefresh }) {
    return (
        <div className="space-y-6">
            <div className="flex items-center justify-between">
                <h3 className="text-lg font-semibold flex items-center gap-2">
                    <Users className="h-5 w-5" />
                    User MCP Usage
                </h3>
                <button
                    onClick={onRefresh}
                    className="flex items-center gap-2 px-4 py-2 rounded-lg bg-secondary hover:bg-secondary/80 text-sm"
                >
                    <RefreshCw className="h-4 w-4" />
                    Refresh
                </button>
            </div>

            <div className="rounded-lg bg-card border border-border overflow-hidden">
                <table className="min-w-full">
                    <thead className="bg-muted/50">
                        <tr>
                            <th className="py-3 px-4 text-left text-sm font-semibold">User</th>
                            <th className="py-3 px-4 text-left text-sm font-semibold">Plan</th>
                            <th className="py-3 px-4 text-center text-sm font-semibold">Sources</th>
                            <th className="py-3 px-4 text-center text-sm font-semibold">Tokens</th>
                            <th className="py-3 px-4 text-center text-sm font-semibold">API Calls Today</th>
                            <th className="py-3 px-4 text-left text-sm font-semibold">Last Activity</th>
                        </tr>
                    </thead>
                    <tbody className="divide-y divide-border">
                        {users.length === 0 ? (
                            <tr>
                                <td colSpan={6} className="py-8 text-center text-muted-foreground">
                                    No MCP usage data yet.
                                </td>
                            </tr>
                        ) : (
                            users.map((user) => (
                                <tr key={user.id} className="hover:bg-muted/30">
                                    <td className="py-3 px-4">
                                        <div className="font-medium">{user.displayName || 'N/A'}</div>
                                        <div className="text-xs text-muted-foreground">{user.email}</div>
                                    </td>
                                    <td className="py-3 px-4">
                                        <span className={`px-2 py-1 rounded text-xs font-medium ${
                                            user.isPremium
                                                ? 'bg-purple-500/20 text-purple-400'
                                                : 'bg-muted text-muted-foreground'
                                        }`}>
                                            {user.planName || 'Free'}
                                        </span>
                                    </td>
                                    <td className="py-3 px-4 text-center font-mono">{user.sourcesCount}</td>
                                    <td className="py-3 px-4 text-center font-mono">{user.activeTokens}</td>
                                    <td className="py-3 px-4 text-center font-mono">{user.apiCallsToday}</td>
                                    <td className="py-3 px-4 text-sm text-muted-foreground">
                                        {user.lastApiCallDate
                                            ? new Date(user.lastApiCallDate).toLocaleDateString()
                                            : 'Never'}
                                    </td>
                                </tr>
                            ))
                        )}
                    </tbody>
                </table>
            </div>
        </div>
    );
}

function StatsTab({ stats, settings }) {
    if (!stats) return null;

    const statCards = [
        { label: 'Users with MCP Usage', value: stats.stats?.usersWithUsage || 0, color: 'text-blue-400' },
        { label: 'Total Verified Sources', value: stats.stats?.totalVerifiedSources || 0, color: 'text-green-400' },
        { label: 'Active API Tokens', value: stats.stats?.totalActiveTokens || 0, color: 'text-amber-400' },
        { label: 'API Calls Today', value: stats.stats?.totalApiCallsToday || 0, color: 'text-purple-400' },
    ];

    return (
        <div className="space-y-6">
            <h3 className="text-lg font-semibold flex items-center gap-2">
                <Activity className="h-5 w-5" />
                MCP Statistics
            </h3>

            <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
                {statCards.map((stat) => (
                    <div key={stat.label} className="rounded-lg bg-card border border-border p-6">
                        <div className="text-sm text-muted-foreground mb-2">{stat.label}</div>
                        <div className={`text-3xl font-bold ${stat.color}`}>{stat.value}</div>
                    </div>
                ))}
            </div>

            {/* Current Limits Summary */}
            {settings && (
                <div className="rounded-lg bg-card border border-border p-6">
                    <h4 className="font-semibold mb-4">Current Limits Summary</h4>
                    <div className="grid gap-4 md:grid-cols-2">
                        <div>
                            <h5 className="text-sm font-medium text-muted-foreground mb-2">Free Plan</h5>
                            <ul className="space-y-1 text-sm">
                                <li>Sources: {settings.freeSourcesLimit}</li>
                                <li>Tokens: {settings.freeTokensLimit}</li>
                                <li>API Calls/Day: {settings.freeApiCallsPerDay}</li>
                            </ul>
                        </div>
                        <div>
                            <h5 className="text-sm font-medium text-purple-400 mb-2">Premium Plan</h5>
                            <ul className="space-y-1 text-sm">
                                <li>Sources: {settings.premiumSourcesLimit}</li>
                                <li>Tokens: {settings.premiumTokensLimit}</li>
                                <li>API Calls/Day: {settings.premiumApiCallsPerDay}</li>
                            </ul>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
}
