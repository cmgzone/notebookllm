import { useState, useEffect } from 'react';
import { neon } from '../lib/neon';
import { Users, FileText, Shield, Settings2, Calendar, TrendingUp } from 'lucide-react';
import { useAuth } from '../contexts/AuthContext';

export default function Dashboard() {
    const { user } = useAuth();
    const [stats, setStats] = useState({
        totalUsers: 0,
        adminUsers: 0,
        activeUsers: 0,
        onboardingScreens: 0,
        appSettings: 0,
        recentUsers: []
    });
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        loadStats();
    }, []);

    const loadStats = async () => {
        try {
            setLoading(true);

            // Get user stats
            const users = await neon.query('SELECT role, is_active, created_at FROM users ORDER BY created_at DESC', []);
            const totalUsers = users.length;
            const adminUsers = users.filter(u => u.role === 'admin').length;
            const activeUsers = users.filter(u => u.is_active).length;
            const recentUsers = users.slice(0, 5);

            // Get onboarding screens count
            const onboarding = await neon.query('SELECT COUNT(*) as count FROM onboarding_screens', []);
            const onboardingScreens = parseInt(onboarding[0]?.count || 0);

            // Get app settings count
            const settings = await neon.query('SELECT COUNT(*) as count FROM app_settings', []);
            const appSettings = parseInt(settings[0]?.count || 0);

            setStats({
                totalUsers,
                adminUsers,
                activeUsers,
                onboardingScreens,
                appSettings,
                recentUsers
            });
        } catch (error) {
            console.error('Error loading stats:', error);
        } finally {
            setLoading(false);
        }
    };

    if (loading) {
        return (
            <div className="flex items-center justify-center h-64">
                <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary"></div>
            </div>
        );
    }

    return (
        <div className="p-8">
            {/* Header */}
            <div className="mb-8">
                <h1 className="text-3xl font-bold mb-2">Dashboard</h1>
                <p className="text-muted-foreground">Welcome back, {user?.name || user?.email}!</p>
            </div>

            {/* Stats Grid */}
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
                <StatCard
                    title="Total Users"
                    value={stats.totalUsers}
                    icon={Users}
                    color="bg-blue-500"
                    trend="+12% from last month"
                />
                <StatCard
                    title="Admin Users"
                    value={stats.adminUsers}
                    icon={Shield}
                    color="bg-green-500"
                />
                <StatCard
                    title="Active Users"
                    value={stats.activeUsers}
                    icon={TrendingUp}
                    color="bg-purple-500"
                />
                <StatCard
                    title="Onboarding Screens"
                    value={stats.onboardingScreens}
                    icon={FileText}
                    color="bg-orange-500"
                />
            </div>

            {/* Quick Actions */}
            <div className="mb-8">
                <h2 className="text-xl font-semibold mb-4">Quick Actions</h2>
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
                    <QuickActionCard
                        title="Manage Users"
                        description="View and manage user accounts"
                        icon={Users}
                        href="/users"
                    />
                    <QuickActionCard
                        title="Onboarding"
                        description="Edit onboarding screens"
                        icon={FileText}
                        href="/onboarding"
                    />
                    <QuickActionCard
                        title="Settings"
                        description="Configure app settings & API keys"
                        icon={Settings2}
                        href="/settings"
                    />
                    <QuickActionCard
                        title="Privacy Policy"
                        description="Update privacy policy"
                        icon={Shield}
                        href="/privacy"
                    />
                </div>
            </div>

            {/* Recent Activity */}
            <div className="bg-card border border-border rounded-lg p-6">
                <h2 className="text-xl font-semibold mb-4">Recent User Registrations</h2>
                <div className="space-y-3">
                    {stats.recentUsers.length === 0 ? (
                        <p className="text-muted-foreground text-sm">No recent users</p>
                    ) : (
                        stats.recentUsers.map((user, index) => (
                            <div key={index} className="flex items-center justify-between py-2 border-b border-border last:border-0">
                                <div className="flex items-center gap-3">
                                    <Calendar className="h-4 w-4 text-muted-foreground" />
                                    <div>
                                        <p className="text-sm font-medium">New user registered</p>
                                        <p className="text-xs text-muted-foreground">
                                            {new Date(user.created_at).toLocaleDateString()} - {user.role === 'admin' ? 'Admin' : 'User'}
                                        </p>
                                    </div>
                                </div>
                                <span className={`px-2 py-1 rounded-full text-xs ${user.is_active ? 'bg-green-100 text-green-700' : 'bg-gray-100 text-gray-700'
                                    }`}>
                                    {user.is_active ? 'Active' : 'Inactive'}
                                </span>
                            </div>
                        ))
                    )}
                </div>
            </div>

            {/* System Info */}
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mt-8">
                <div className="bg-card border border-border rounded-lg p-6">
                    <h3 className="font-semibold mb-3">System Configuration</h3>
                    <div className="space-y-2 text-sm">
                        <div className="flex justify-between">
                            <span className="text-muted-foreground">App Settings:</span>
                            <span className="font-medium">{stats.appSettings} configured</span>
                        </div>
                        <div className="flex justify-between">
                            <span className="text-muted-foreground">Onboarding Screens:</span>
                            <span className="font-medium">{stats.onboardingScreens} screens</span>
                        </div>
                        <div className="flex justify-between">
                            <span className="text-muted-foreground">Database:</span>
                            <span className="font-medium text-green-600">Connected</span>
                        </div>
                    </div>
                </div>

                <div className="bg-gradient-to-br from-primary/10 to-primary/5 border border-primary/20 rounded-lg p-6">
                    <h3 className="font-semibold mb-3">Admin Tips</h3>
                    <ul className="space-y-2 text-sm text-muted-foreground">
                        <li>• Use the User Management page to promote users to admin</li>
                        <li>• Keep your API keys secure in the Settings page</li>
                        <li>• Update onboarding screens to improve user experience</li>
                        <li>• Review and update the privacy policy regularly</li>
                    </ul>
                </div>
            </div>
        </div>
    );
}

function StatCard({ title, value, icon: Icon, color, trend }) {
    return (
        <div className="bg-card border border-border rounded-lg p-6">
            <div className="flex items-center justify-between mb-4">
                <div className={`${color} p-3 rounded-lg`}>
                    <Icon className="h-6 w-6 text-white" />
                </div>
            </div>
            <div>
                <p className="text-sm text-muted-foreground mb-1">{title}</p>
                <p className="text-3xl font-bold">{value}</p>
                {trend && (
                    <p className="text-xs text-green-600 mt-2">{trend}</p>
                )}
            </div>
        </div>
    );
}

function QuickActionCard({ title, description, icon: Icon, href }) {
    return (
        <a
            href={href}
            className="bg-card border border-border rounded-lg p-4 hover:border-primary transition-all hover:shadow-md group"
        >
            <div className="flex items-start gap-3">
                <div className="p-2 bg-primary/10 rounded-lg group-hover:bg-primary group-hover:text-white transition-all">
                    <Icon className="h-5 w-5 text-primary group-hover:text-white" />
                </div>
                <div>
                    <h3 className="font-semibold mb-1">{title}</h3>
                    <p className="text-sm text-muted-foreground">{description}</p>
                </div>
            </div>
        </a>
    );
}
