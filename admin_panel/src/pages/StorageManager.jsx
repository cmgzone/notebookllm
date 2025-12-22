import { useState, useEffect } from 'react';
import api from '../lib/api';
import {
    Cloud,
    Database,
    HardDrive,
    RefreshCw,
    Loader2,
    CheckCircle,
    XCircle,
    Users,
    FileImage,
    TrendingUp,
    Server,
    ExternalLink
} from 'lucide-react';

export default function StorageManager() {
    const [stats, setStats] = useState(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);

    useEffect(() => {
        fetchStats();
    }, []);

    const fetchStats = async () => {
        setLoading(true);
        setError(null);
        try {
            const data = await api.getStorageStats();
            setStats(data);
        } catch (err) {
            console.error('Error fetching storage stats:', err);
            setError(err.message);
        } finally {
            setLoading(false);
        }
    };

    const formatBytes = (bytes) => {
        if (!bytes || bytes === 0) return '0 B';
        const k = 1024;
        const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
    };

    if (loading) {
        return (
            <div className="flex items-center justify-center h-64">
                <Loader2 className="h-8 w-8 animate-spin" />
            </div>
        );
    }

    if (error) {
        return (
            <div className="p-8">
                <div className="bg-red-50 border border-red-200 rounded-lg p-4 text-red-700">
                    <p className="font-medium">Error loading storage stats</p>
                    <p className="text-sm mt-1">{error}</p>
                    <button
                        onClick={fetchStats}
                        className="mt-3 px-4 py-2 bg-red-100 hover:bg-red-200 rounded-md text-sm font-medium"
                    >
                        Retry
                    </button>
                </div>
            </div>
        );
    }

    return (
        <div className="p-8 space-y-8">
            {/* Header */}
            <div className="flex items-center justify-between">
                <div>
                    <h1 className="text-3xl font-bold mb-2">Storage & CDN</h1>
                    <p className="text-muted-foreground">
                        Manage media storage and Bunny.net CDN configuration
                    </p>
                </div>
                <button
                    onClick={fetchStats}
                    className="flex items-center gap-2 px-4 py-2 bg-secondary hover:bg-secondary/80 rounded-md text-sm font-medium"
                >
                    <RefreshCw className="h-4 w-4" />
                    Refresh
                </button>
            </div>

            {/* CDN Status Card */}
            <div className={`rounded-lg border-2 p-6 ${stats?.cdnConfigured
                    ? 'bg-green-50 border-green-200'
                    : 'bg-yellow-50 border-yellow-200'
                }`}>
                <div className="flex items-start justify-between">
                    <div className="flex items-center gap-3">
                        <div className={`p-3 rounded-full ${stats?.cdnConfigured ? 'bg-green-100' : 'bg-yellow-100'
                            }`}>
                            <Cloud className={`h-6 w-6 ${stats?.cdnConfigured ? 'text-green-600' : 'text-yellow-600'
                                }`} />
                        </div>
                        <div>
                            <h2 className="text-lg font-semibold flex items-center gap-2">
                                Bunny.net CDN
                                {stats?.cdnConfigured ? (
                                    <CheckCircle className="h-5 w-5 text-green-600" />
                                ) : (
                                    <XCircle className="h-5 w-5 text-yellow-600" />
                                )}
                            </h2>
                            <p className={`text-sm ${stats?.cdnConfigured ? 'text-green-700' : 'text-yellow-700'
                                }`}>
                                {stats?.cdnConfigured
                                    ? `Connected to ${stats.cdnHostname}`
                                    : 'Not configured - media stored in database'}
                            </p>
                        </div>
                    </div>
                    {stats?.cdnConfigured && stats?.cdnHostname && (
                        <a
                            href={`https://${stats.cdnHostname}`}
                            target="_blank"
                            rel="noopener noreferrer"
                            className="flex items-center gap-1 text-sm text-green-700 hover:underline"
                        >
                            Open CDN <ExternalLink className="h-3 w-3" />
                        </a>
                    )}
                </div>

                {!stats?.cdnConfigured && (
                    <div className="mt-4 p-4 bg-white rounded-md border border-yellow-200">
                        <h3 className="font-medium text-yellow-800 mb-2">Configuration Required</h3>
                        <p className="text-sm text-yellow-700 mb-3">
                            Add these environment variables to your backend to enable Bunny.net CDN:
                        </p>
                        <pre className="bg-yellow-100 p-3 rounded text-xs font-mono text-yellow-900 overflow-x-auto">
{`BUNNY_STORAGE_ZONE=your-storage-zone-name
BUNNY_STORAGE_API_KEY=your-storage-api-key
BUNNY_CDN_HOSTNAME=your-zone.b-cdn.net
BUNNY_STORAGE_HOSTNAME=storage.bunnycdn.com`}
                        </pre>
                        <a
                            href="https://bunny.net"
                            target="_blank"
                            rel="noopener noreferrer"
                            className="inline-flex items-center gap-1 mt-3 text-sm text-yellow-700 hover:underline"
                        >
                            Get started with Bunny.net <ExternalLink className="h-3 w-3" />
                        </a>
                    </div>
                )}
            </div>

            {/* Storage Stats Grid */}
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
                {/* Total Storage */}
                <div className="bg-card border border-border rounded-lg p-6">
                    <div className="flex items-center gap-3 mb-4">
                        <div className="p-2 bg-blue-100 rounded-lg">
                            <HardDrive className="h-5 w-5 text-blue-600" />
                        </div>
                        <span className="text-sm font-medium text-muted-foreground">Total Storage</span>
                    </div>
                    <p className="text-3xl font-bold">{formatBytes(stats?.stats?.totalSize)}</p>
                    <p className="text-xs text-muted-foreground mt-1">
                        {(stats?.stats?.dbFileCount || 0) + (stats?.stats?.cdnFileCount || 0)} files
                    </p>
                </div>

                {/* Database Storage */}
                <div className="bg-card border border-border rounded-lg p-6">
                    <div className="flex items-center gap-3 mb-4">
                        <div className="p-2 bg-purple-100 rounded-lg">
                            <Database className="h-5 w-5 text-purple-600" />
                        </div>
                        <span className="text-sm font-medium text-muted-foreground">Database Storage</span>
                    </div>
                    <p className="text-3xl font-bold">{formatBytes(stats?.stats?.totalDbSize)}</p>
                    <p className="text-xs text-muted-foreground mt-1">
                        {stats?.stats?.dbFileCount || 0} files in PostgreSQL
                    </p>
                </div>

                {/* CDN Storage */}
                <div className="bg-card border border-border rounded-lg p-6">
                    <div className="flex items-center gap-3 mb-4">
                        <div className="p-2 bg-green-100 rounded-lg">
                            <Cloud className="h-5 w-5 text-green-600" />
                        </div>
                        <span className="text-sm font-medium text-muted-foreground">CDN Storage</span>
                    </div>
                    <p className="text-3xl font-bold">{formatBytes(stats?.stats?.totalCdnSize)}</p>
                    <p className="text-xs text-muted-foreground mt-1">
                        {stats?.stats?.cdnFileCount || 0} files on Bunny.net
                    </p>
                </div>

                {/* Users with Media */}
                <div className="bg-card border border-border rounded-lg p-6">
                    <div className="flex items-center gap-3 mb-4">
                        <div className="p-2 bg-orange-100 rounded-lg">
                            <Users className="h-5 w-5 text-orange-600" />
                        </div>
                        <span className="text-sm font-medium text-muted-foreground">Users with Media</span>
                    </div>
                    <p className="text-3xl font-bold">{stats?.stats?.usersWithMedia || 0}</p>
                    <p className="text-xs text-muted-foreground mt-1">
                        Active media uploaders
                    </p>
                </div>
            </div>

            {/* Top Users Table */}
            {stats?.topUsers && stats.topUsers.length > 0 && (
                <div className="bg-card border border-border rounded-lg overflow-hidden">
                    <div className="px-6 py-4 border-b border-border">
                        <h2 className="text-lg font-semibold flex items-center gap-2">
                            <TrendingUp className="h-5 w-5" />
                            Top Storage Users
                        </h2>
                    </div>
                    <div className="overflow-x-auto">
                        <table className="w-full">
                            <thead className="bg-muted/50">
                                <tr>
                                    <th className="px-6 py-3 text-left text-xs font-medium text-muted-foreground uppercase tracking-wider">
                                        User
                                    </th>
                                    <th className="px-6 py-3 text-left text-xs font-medium text-muted-foreground uppercase tracking-wider">
                                        Total Size
                                    </th>
                                    <th className="px-6 py-3 text-left text-xs font-medium text-muted-foreground uppercase tracking-wider">
                                        Database
                                    </th>
                                    <th className="px-6 py-3 text-left text-xs font-medium text-muted-foreground uppercase tracking-wider">
                                        CDN
                                    </th>
                                    <th className="px-6 py-3 text-left text-xs font-medium text-muted-foreground uppercase tracking-wider">
                                        Files
                                    </th>
                                </tr>
                            </thead>
                            <tbody className="divide-y divide-border">
                                {stats.topUsers.map((user, index) => (
                                    <tr key={user.email} className="hover:bg-muted/30">
                                        <td className="px-6 py-4 whitespace-nowrap">
                                            <div className="flex items-center gap-3">
                                                <div className="w-8 h-8 rounded-full bg-primary/10 flex items-center justify-center text-sm font-medium">
                                                    {index + 1}
                                                </div>
                                                <span className="text-sm font-medium">{user.email}</span>
                                            </div>
                                        </td>
                                        <td className="px-6 py-4 whitespace-nowrap text-sm font-semibold">
                                            {formatBytes(user.totalSize)}
                                        </td>
                                        <td className="px-6 py-4 whitespace-nowrap text-sm text-muted-foreground">
                                            {formatBytes(user.dbSize)}
                                            <span className="text-xs ml-1">({user.dbCount})</span>
                                        </td>
                                        <td className="px-6 py-4 whitespace-nowrap text-sm text-muted-foreground">
                                            {formatBytes(user.cdnSize)}
                                            <span className="text-xs ml-1">({user.cdnCount})</span>
                                        </td>
                                        <td className="px-6 py-4 whitespace-nowrap text-sm">
                                            {user.dbCount + user.cdnCount}
                                        </td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                    </div>
                </div>
            )}

            {/* Info Cards */}
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                {/* Benefits of CDN */}
                <div className="bg-card border border-border rounded-lg p-6">
                    <h3 className="font-semibold mb-4 flex items-center gap-2">
                        <Server className="h-5 w-5" />
                        Why Use Bunny.net CDN?
                    </h3>
                    <ul className="space-y-2 text-sm text-muted-foreground">
                        <li className="flex items-start gap-2">
                            <CheckCircle className="h-4 w-4 text-green-500 mt-0.5 flex-shrink-0" />
                            <span>Faster media delivery with global edge locations</span>
                        </li>
                        <li className="flex items-start gap-2">
                            <CheckCircle className="h-4 w-4 text-green-500 mt-0.5 flex-shrink-0" />
                            <span>Reduced database load and storage costs</span>
                        </li>
                        <li className="flex items-start gap-2">
                            <CheckCircle className="h-4 w-4 text-green-500 mt-0.5 flex-shrink-0" />
                            <span>Automatic image optimization and caching</span>
                        </li>
                        <li className="flex items-start gap-2">
                            <CheckCircle className="h-4 w-4 text-green-500 mt-0.5 flex-shrink-0" />
                            <span>Pay only for what you use (~$0.01/GB storage)</span>
                        </li>
                    </ul>
                </div>

                {/* Storage Types */}
                <div className="bg-card border border-border rounded-lg p-6">
                    <h3 className="font-semibold mb-4 flex items-center gap-2">
                        <FileImage className="h-5 w-5" />
                        Supported Media Types
                    </h3>
                    <div className="grid grid-cols-2 gap-3 text-sm">
                        <div className="flex items-center gap-2 text-muted-foreground">
                            <div className="w-2 h-2 rounded-full bg-blue-500"></div>
                            Images (PNG, JPG, WebP)
                        </div>
                        <div className="flex items-center gap-2 text-muted-foreground">
                            <div className="w-2 h-2 rounded-full bg-purple-500"></div>
                            Audio (MP3, WAV)
                        </div>
                        <div className="flex items-center gap-2 text-muted-foreground">
                            <div className="w-2 h-2 rounded-full bg-red-500"></div>
                            Video (MP4, WebM)
                        </div>
                        <div className="flex items-center gap-2 text-muted-foreground">
                            <div className="w-2 h-2 rounded-full bg-orange-500"></div>
                            Documents (PDF)
                        </div>
                    </div>
                    <p className="mt-4 text-xs text-muted-foreground">
                        Media is automatically stored on CDN when configured, with fallback to database storage.
                    </p>
                </div>
            </div>
        </div>
    );
}
