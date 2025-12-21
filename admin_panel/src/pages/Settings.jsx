import { useState, useEffect } from 'react';
import { neon } from '../lib/neon';
import { CreditCard, Shield, Save, Plus, Trash2, Key, Loader2, Upload, FileText, Zap } from 'lucide-react';

export default function Settings() {
    const [settings, setSettings] = useState([]);
    const [apiKeys, setApiKeys] = useState([]);
    const [loading, setLoading] = useState(true);
    const [saving, setSaving] = useState(false);
    const [envContent, setEnvContent] = useState('');
    const [showEnvImport, setShowEnvImport] = useState(false);

    // New API Key Form
    const [newKeyService, setNewKeyService] = useState('');
    const [newKeyValue, setNewKeyValue] = useState('');

    // Stripe Configuration
    const [stripePublishableKey, setStripePublishableKey] = useState('');
    const [stripeSecretKey, setStripeSecretKey] = useState('');
    const [stripeTestMode, setStripeTestMode] = useState(true);

    useEffect(() => {
        fetchData();
    }, []);

    const fetchData = async () => {
        setLoading(true);
        try {
            const settingsData = await neon.query('SELECT * FROM app_settings ORDER BY key', []);
            const keysData = await neon.query('SELECT service_name, description, updated_at FROM api_keys ORDER BY service_name', []);
            setSettings(settingsData);
            setApiKeys(keysData);

            // Fetch Stripe test mode setting
            const stripeTestModeSetting = settingsData.find(s => s.key === 'stripe_test_mode');
            if (stripeTestModeSetting) {
                setStripeTestMode(stripeTestModeSetting.value === 'true');
            }
        } catch (error) {
            console.error(error);
            alert('Failed to fetch settings');
        } finally {
            setLoading(false);
        }
    };

    const handleSettingChange = (key, value) => {
        setSettings(settings.map(s => s.key === key ? { ...s, value } : s));
    };

    const saveSettings = async () => {
        setSaving(true);
        try {
            for (const setting of settings) {
                await neon.execute(
                    `INSERT INTO app_settings (key, value, type, updated_at) 
                     VALUES ($1, $2, $3, CURRENT_TIMESTAMP)
                     ON CONFLICT (key) DO UPDATE SET value = $2, updated_at = CURRENT_TIMESTAMP`,
                    [setting.key, setting.value, setting.type]
                );
            }
            alert('Settings saved!');
        } catch (error) {
            console.error(error);
            alert('Failed to save settings');
        } finally {
            setSaving(false);
        }
    };

    const saveApiKey = async (e) => {
        e.preventDefault();
        if (!newKeyService || !newKeyValue) return;

        try {
            await neon.execute(
                `INSERT INTO api_keys (service_name, encrypted_value, description, updated_at)
                 VALUES ($1, $2, $3, CURRENT_TIMESTAMP)
                 ON CONFLICT (service_name) DO UPDATE SET encrypted_value = $2, description = $3, updated_at = CURRENT_TIMESTAMP`,
                [newKeyService.toLowerCase().trim(), newKeyValue.trim(), `${newKeyService} API Key`]
            );

            setNewKeyService('');
            setNewKeyValue('');
            fetchData();
            alert('API Key saved!');
        } catch (error) {
            console.error(error);
            alert('Failed to save API Key');
        }
    };

    const deleteApiKey = async (service) => {
        if (!confirm(`Delete key for ${service}?`)) return;
        try {
            await neon.execute('DELETE FROM api_keys WHERE service_name = $1', [service]);
            fetchData();
        } catch (error) {
            console.error(error);
            alert('Failed to delete key');
        }
    };

    const deployFromEnv = async () => {
        if (!envContent.trim()) {
            alert('Please paste your .env content');
            return;
        }

        setSaving(true);
        try {
            const lines = envContent.split('\n');
            let imported = 0;

            for (const line of lines) {
                const trimmed = line.trim();
                if (!trimmed || trimmed.startsWith('#')) continue;

                const match = trimmed.match(/^([A-Z_]+)=(.+)$/);
                if (match) {
                    const [, envKey, value] = match;

                    // Map env keys to service names
                    const serviceMap = {
                        'GEMINI_API_KEY': 'gemini',
                        'ELEVENLABS_API_KEY': 'elevenlabs',
                        'ELEVENLABS_AGENT_ID': 'elevenlabs_agent_id',
                        'MURF_API_KEY': 'murf',
                        'GOOGLE_CLOUD_TTS_API_KEY': 'google_cloud_tts',
                        'OPENROUTER_API_KEY': 'openrouter',
                        'SERPER_API_KEY': 'serper',
                        'PAYPAL_CLIENT_ID': 'paypal_client_id',
                        'PAYPAL_SECRET': 'paypal_secret',
                        'STRIPE_PUBLISHABLE_KEY': 'stripe_publishable_key',
                        'STRIPE_SECRET_KEY': 'stripe_secret_key',
                    };

                    const serviceName = serviceMap[envKey];
                    if (serviceName && value) {
                        await neon.execute(
                            `INSERT INTO api_keys (service_name, encrypted_value, description, updated_at)
                             VALUES ($1, $2, $3, CURRENT_TIMESTAMP)
                             ON CONFLICT (service_name) DO UPDATE SET encrypted_value = $2, updated_at = CURRENT_TIMESTAMP`,
                            [serviceName, value.replace(/^["']|["']$/g, ''), `${serviceName} API Key`]
                        );
                        imported++;
                    }
                }
            }

            alert(`Successfully imported ${imported} API keys!`);
            setEnvContent('');
            setShowEnvImport(false);
            fetchData();
        } catch (error) {
            console.error(error);
            alert('Failed to import keys: ' + error.message);
        } finally {
            setSaving(false);
        }
    };

    if (loading) return <div className="flex items-center justify-center h-64"><Loader2 className="h-8 w-8 animate-spin" /></div>;

    return (
        <div className="p-8 space-y-8">
            <div className="mb-8">
                <h1 className="text-3xl font-bold mb-2">Settings & Configuration</h1>
                <p className="text-muted-foreground">Manage application settings and API keys</p>
            </div>

            {/* App Settings Section */}
            <section className="rounded-lg bg-card border border-border p-6">
                <div className="flex items-center justify-between mb-6">
                    <h2 className="text-xl font-bold">App Configuration</h2>
                    <button
                        onClick={saveSettings}
                        disabled={saving}
                        className="flex items-center rounded-md bg-primary px-4 py-2 text-sm font-medium text-primary-foreground hover:bg-primary/90 disabled:opacity-50"
                    >
                        {saving ? <Loader2 className="mr-2 h-4 w-4 animate-spin" /> : <Save className="mr-2 h-4 w-4" />}
                        Save Changes
                    </button>
                </div>

                <div className="grid gap-6 md:grid-cols-2">
                    {settings.map((setting) => (
                        <div key={setting.key}>
                            <label className="block text-sm font-medium mb-1">
                                {setting.description || setting.key}
                            </label>
                            <input
                                type={setting.type === 'number' ? 'number' : 'text'}
                                className="block w-full rounded-md border border-border bg-background p-2 focus:border-primary focus:ring-primary"
                                value={setting.value || ''}
                                onChange={(e) => handleSettingChange(setting.key, e.target.value)}
                            />
                        </div>
                    ))}
                    {settings.length === 0 && <p className="text-muted-foreground">No settings defined.</p>}
                </div>
            </section>

            {/* API Keys Section */}
            <section className="rounded-lg bg-card border border-border p-6">
                <div className="flex items-center justify-between mb-6">
                    <h2 className="text-xl font-bold flex items-center">
                        <Key className="mr-2 h-5 w-5" />
                        API Keys Management
                    </h2>
                    <button
                        onClick={() => setShowEnvImport(!showEnvImport)}
                        className="flex items-center rounded-md bg-secondary px-4 py-2 text-sm font-medium hover:bg-secondary/80"
                    >
                        <Upload className="mr-2 h-4 w-4" />
                        Deploy from .env
                    </button>
                </div>

                {/* Deploy from .env Section */}
                {showEnvImport && (
                    <div className="bg-muted p-4 rounded-md mb-6 border border-border">
                        <h3 className="text-sm font-medium mb-4 flex items-center">
                            <FileText className="mr-2 h-4 w-4" />
                            Paste your .env file content
                        </h3>
                        <textarea
                            placeholder="GEMINI_API_KEY=your_key_here&#10;PAYPAL_CLIENT_ID=your_id&#10;PAYPAL_SECRET=your_secret"
                            className="w-full h-32 rounded-md border border-border bg-background p-2 font-mono text-sm"
                            value={envContent}
                            onChange={(e) => setEnvContent(e.target.value)}
                        />
                        <div className="flex gap-2 mt-4">
                            <button
                                onClick={deployFromEnv}
                                disabled={saving}
                                className="flex items-center rounded-md bg-primary px-4 py-2 text-sm font-medium text-primary-foreground hover:bg-primary/90 disabled:opacity-50"
                            >
                                {saving ? <Loader2 className="mr-2 h-4 w-4 animate-spin" /> : <Upload className="mr-2 h-4 w-4" />}
                                Import Keys
                            </button>
                            <button
                                onClick={() => setShowEnvImport(false)}
                                className="rounded-md bg-secondary px-4 py-2 text-sm font-medium hover:bg-secondary/80"
                            >
                                Cancel
                            </button>
                        </div>
                        <p className="mt-2 text-xs text-muted-foreground">
                            Supported keys: GEMINI_API_KEY, PAYPAL_CLIENT_ID, PAYPAL_SECRET, STRIPE_PUBLISHABLE_KEY, STRIPE_SECRET_KEY, ELEVENLABS_API_KEY
                        </p>
                    </div>
                )}

                {/* PayPal Configuration Section */}
                <section className="rounded-lg bg-card border border-border p-6 mb-6">
                    <div className="flex items-center justify-between mb-4">
                        <h2 className="text-xl font-bold flex items-center">
                            <CreditCard className="mr-2 h-5 w-5" />
                            PayPal Configuration
                        </h2>
                    </div>
                    <div className="bg-muted/50 p-4 rounded-md border border-border">
                        <p className="text-sm text-muted-foreground mb-4">
                            Enter your PayPal API credentials to enable payments.
                            Get these from the <a href="https://developer.paypal.com/dashboard/" target="_blank" rel="noreferrer" className="text-primary hover:underline">PayPal Developer Dashboard</a>.
                        </p>
                        <div className="space-y-4">
                            <div>
                                <label className="block text-sm font-medium mb-1">Client ID</label>
                                <div className="flex gap-2">
                                    <input
                                        type="password"
                                        className="flex-1 rounded-md border border-border bg-background p-2"
                                        placeholder="Make sure to use Sandbox keys for testing"
                                        value={newKeyService === 'paypal_client_id' ? newKeyValue : ''}
                                        onChange={(e) => {
                                            setNewKeyService('paypal_client_id');
                                            setNewKeyValue(e.target.value);
                                        }}
                                    />
                                    <button
                                        onClick={(e) => saveApiKey(e)}
                                        disabled={!newKeyValue || newKeyService !== 'paypal_client_id'}
                                        className="px-4 py-2 bg-primary text-primary-foreground rounded-md text-sm font-medium hover:bg-primary/90 disabled:opacity-50"
                                    >
                                        Save
                                    </button>
                                </div>
                                {apiKeys.find(k => k.service_name === 'paypal_client_id') && (
                                    <p className="text-xs text-green-600 mt-1 flex items-center">
                                        <Shield className="h-3 w-3 mr-1" /> Configured
                                    </p>
                                )}
                            </div>
                            <div>
                                <label className="block text-sm font-medium mb-1">Secret Key</label>
                                <div className="flex gap-2">
                                    <input
                                        type="password"
                                        className="flex-1 rounded-md border border-border bg-background p-2"
                                        placeholder="Ex: EIo..."
                                        value={newKeyService === 'paypal_secret' ? newKeyValue : ''}
                                        onChange={(e) => {
                                            setNewKeyService('paypal_secret');
                                            setNewKeyValue(e.target.value);
                                        }}
                                    />
                                    <button
                                        onClick={(e) => saveApiKey(e)}
                                        disabled={!newKeyValue || newKeyService !== 'paypal_secret'}
                                        className="px-4 py-2 bg-primary text-primary-foreground rounded-md text-sm font-medium hover:bg-primary/90 disabled:opacity-50"
                                    >
                                        Save
                                    </button>
                                </div>
                                {apiKeys.find(k => k.service_name === 'paypal_secret') && (
                                    <p className="text-xs text-green-600 mt-1 flex items-center">
                                        <Shield className="h-3 w-3 mr-1" /> Configured
                                    </p>
                                )}
                            </div>
                        </div>
                    </div>
                </section>

                {/* Stripe Configuration Section */}
                <section className="rounded-lg bg-card border border-border p-6 mb-6">
                    <div className="flex items-center justify-between mb-4">
                        <h2 className="text-xl font-bold flex items-center">
                            <Zap className="mr-2 h-5 w-5" />
                            Stripe Configuration
                        </h2>
                        <div className="flex items-center gap-2">
                            <label className="text-sm font-medium">Test Mode</label>
                            <button
                                type="button"
                                onClick={async () => {
                                    const newValue = !stripeTestMode;
                                    setStripeTestMode(newValue);
                                    try {
                                        await neon.execute(
                                            `INSERT INTO app_settings (key, value, type, description, updated_at) 
                                             VALUES ('stripe_test_mode', $1, 'boolean', 'Stripe Test Mode', CURRENT_TIMESTAMP)
                                             ON CONFLICT (key) DO UPDATE SET value = $1, updated_at = CURRENT_TIMESTAMP`,
                                            [newValue.toString()]
                                        );
                                    } catch (error) {
                                        console.error(error);
                                    }
                                }}
                                className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors ${stripeTestMode ? 'bg-yellow-500' : 'bg-green-500'}`}
                            >
                                <span className={`inline-block h-4 w-4 transform rounded-full bg-white transition-transform ${stripeTestMode ? 'translate-x-1' : 'translate-x-6'}`} />
                            </button>
                            <span className={`text-xs font-medium ${stripeTestMode ? 'text-yellow-600' : 'text-green-600'}`}>
                                {stripeTestMode ? 'Test' : 'Live'}
                            </span>
                        </div>
                    </div>
                    <div className="bg-muted/50 p-4 rounded-md border border-border">
                        <p className="text-sm text-muted-foreground mb-4">
                            Enter your Stripe API credentials to enable payments.
                            Get these from the <a href="https://dashboard.stripe.com/apikeys" target="_blank" rel="noreferrer" className="text-primary hover:underline">Stripe Dashboard</a>.
                            {stripeTestMode && <span className="text-yellow-600 ml-1">(Use test keys for testing)</span>}
                        </p>
                        <div className="space-y-4">
                            <div>
                                <label className="block text-sm font-medium mb-1">Publishable Key</label>
                                <div className="flex gap-2">
                                    <input
                                        type="text"
                                        className="flex-1 rounded-md border border-border bg-background p-2 font-mono text-sm"
                                        placeholder={stripeTestMode ? "pk_test_..." : "pk_live_..."}
                                        value={stripePublishableKey}
                                        onChange={(e) => setStripePublishableKey(e.target.value)}
                                    />
                                    <button
                                        onClick={async () => {
                                            if (!stripePublishableKey) return;
                                            try {
                                                await neon.execute(
                                                    `INSERT INTO api_keys (service_name, encrypted_value, description, updated_at)
                                                     VALUES ('stripe_publishable_key', $1, 'Stripe Publishable Key', CURRENT_TIMESTAMP)
                                                     ON CONFLICT (service_name) DO UPDATE SET encrypted_value = $1, updated_at = CURRENT_TIMESTAMP`,
                                                    [stripePublishableKey.trim()]
                                                );
                                                setStripePublishableKey('');
                                                fetchData();
                                                alert('Stripe Publishable Key saved!');
                                            } catch (error) {
                                                console.error(error);
                                                alert('Failed to save key');
                                            }
                                        }}
                                        disabled={!stripePublishableKey}
                                        className="px-4 py-2 bg-primary text-primary-foreground rounded-md text-sm font-medium hover:bg-primary/90 disabled:opacity-50"
                                    >
                                        Save
                                    </button>
                                </div>
                                {apiKeys.find(k => k.service_name === 'stripe_publishable_key') && (
                                    <p className="text-xs text-green-600 mt-1 flex items-center">
                                        <Shield className="h-3 w-3 mr-1" /> Configured
                                    </p>
                                )}
                            </div>
                            <div>
                                <label className="block text-sm font-medium mb-1">Secret Key</label>
                                <div className="flex gap-2">
                                    <input
                                        type="password"
                                        className="flex-1 rounded-md border border-border bg-background p-2 font-mono text-sm"
                                        placeholder={stripeTestMode ? "sk_test_..." : "sk_live_..."}
                                        value={stripeSecretKey}
                                        onChange={(e) => setStripeSecretKey(e.target.value)}
                                    />
                                    <button
                                        onClick={async () => {
                                            if (!stripeSecretKey) return;
                                            try {
                                                await neon.execute(
                                                    `INSERT INTO api_keys (service_name, encrypted_value, description, updated_at)
                                                     VALUES ('stripe_secret_key', $1, 'Stripe Secret Key', CURRENT_TIMESTAMP)
                                                     ON CONFLICT (service_name) DO UPDATE SET encrypted_value = $1, updated_at = CURRENT_TIMESTAMP`,
                                                    [stripeSecretKey.trim()]
                                                );
                                                setStripeSecretKey('');
                                                fetchData();
                                                alert('Stripe Secret Key saved!');
                                            } catch (error) {
                                                console.error(error);
                                                alert('Failed to save key');
                                            }
                                        }}
                                        disabled={!stripeSecretKey}
                                        className="px-4 py-2 bg-primary text-primary-foreground rounded-md text-sm font-medium hover:bg-primary/90 disabled:opacity-50"
                                    >
                                        Save
                                    </button>
                                </div>
                                {apiKeys.find(k => k.service_name === 'stripe_secret_key') && (
                                    <p className="text-xs text-green-600 mt-1 flex items-center">
                                        <Shield className="h-3 w-3 mr-1" /> Configured
                                    </p>
                                )}
                            </div>
                        </div>
                        <p className="mt-4 text-xs text-muted-foreground">
                            <strong>Note:</strong> Use test keys (pk_test_*, sk_test_*) for development. Switch to live keys (pk_live_*, sk_live_*) for production.
                        </p>
                    </div>
                </section>

                {/* Add Key Form */}
                <form onSubmit={saveApiKey} className="bg-muted p-4 rounded-md mb-6 border border-border">
                    <h3 className="text-sm font-medium mb-4">Add / Update Individual Key</h3>
                    <div className="flex gap-4 flex-col sm:flex-row">
                        <input
                            type="text"
                            placeholder="Service Name (e.g. gemini, elevenlabs)"
                            className="flex-1 rounded-md border border-border bg-background p-2"
                            value={newKeyService}
                            onChange={(e) => setNewKeyService(e.target.value)}
                            required
                        />
                        <input
                            type="password"
                            placeholder="API Key Value"
                            className="flex-1 rounded-md border border-border bg-background p-2"
                            value={newKeyValue}
                            onChange={(e) => setNewKeyValue(e.target.value)}
                            required
                        />
                        <button
                            type="submit"
                            className="inline-flex items-center justify-center rounded-md bg-primary px-4 py-2 text-sm font-medium text-primary-foreground hover:bg-primary/90"
                        >
                            <Plus className="mr-2 h-4 w-4" />
                            Add/Update
                        </button>
                    </div>
                </form>

                {/* Keys List */}
                <div className="overflow-hidden bg-card border border-border rounded-lg">
                    <table className="min-w-full">
                        <thead className="bg-muted/50">
                            <tr>
                                <th className="py-3.5 pl-4 pr-3 text-left text-sm font-semibold">Service</th>
                                <th className="px-3 py-3.5 text-left text-sm font-semibold">Description</th>
                                <th className="px-3 py-3.5 text-left text-sm font-semibold">Updated</th>
                                <th className="relative py-3.5 pl-3 pr-4">
                                    <span className="sr-only">Actions</span>
                                </th>
                            </tr>
                        </thead>
                        <tbody className="divide-y divide-border">
                            {apiKeys.map((key) => (
                                <tr key={key.service_name} className="hover:bg-muted/30">
                                    <td className="whitespace-nowrap py-4 pl-4 pr-3 text-sm font-medium">
                                        {key.service_name}
                                    </td>
                                    <td className="whitespace-nowrap px-3 py-4 text-sm text-muted-foreground">
                                        {key.description}
                                    </td>
                                    <td className="whitespace-nowrap px-3 py-4 text-sm text-muted-foreground">
                                        {new Date(key.updated_at).toLocaleDateString()}
                                    </td>
                                    <td className="relative whitespace-nowrap py-4 pl-3 pr-4 text-right text-sm font-medium">
                                        <button
                                            onClick={() => deleteApiKey(key.service_name)}
                                            className="text-destructive hover:text-destructive/80"
                                        >
                                            <Trash2 className="h-4 w-4" />
                                        </button>
                                    </td>
                                </tr>
                            ))}
                            {apiKeys.length === 0 && (
                                <tr>
                                    <td colSpan={4} className="py-4 text-center text-sm text-muted-foreground">No keys found.</td>
                                </tr>
                            )}
                        </tbody>
                    </table>
                </div>
            </section>
        </div>
    );
}
