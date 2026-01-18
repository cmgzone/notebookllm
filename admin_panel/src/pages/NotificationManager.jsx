import React, { useState, useEffect } from 'react';
import { Bell, Send, Trash2, Users, AlertCircle, CheckCircle } from 'lucide-react';
import api from '../lib/api';

export default function NotificationManager() {
    const [stats, setStats] = useState(null);
    const [loading, setLoading] = useState(true);
    const [title, setTitle] = useState('');
    const [message, setMessage] = useState('');
    const [type, setType] = useState('system');
    const [actionUrl, setActionUrl] = useState('');
    const [sending, setSending] = useState(false);
    const [error, setError] = useState('');
    const [success, setSuccess] = useState('');

    useEffect(() => {
        loadStats();
    }, []);

    const loadStats = async () => {
        try {
            const data = await api.getNotificationStats();
            setStats(data.stats);
        } catch (error) {
            console.error('Failed to load notification stats:', error);
        } finally {
            setLoading(false);
        }
    };

    const handleBroadcast = async (e) => {
        e.preventDefault();
        setSending(true);
        setError('');
        setSuccess('');

        try {
            await api.sendBroadcastNotification(title, message, type, actionUrl || undefined);
            setSuccess('Broadcast notification sent successfully!');
            setTitle('');
            setMessage('');
            setActionUrl('');
            loadStats();
        } catch (error) {
            setError(error.message || 'Failed to send notification');
        } finally {
            setSending(false);
        }
    };

    return (
        <div className="space-y-6">
            <div>
                <h1 className="text-3xl font-bold tracking-tight">Notification Manager</h1>
                <p className="text-gray-500">Send notifications to users and view engagement stats.</p>
            </div>

            {loading ? (
                <div>Loading stats...</div>
            ) : (
                <div className="grid gap-6 md:grid-cols-3">
                    <StatCard
                        title="Total Sent"
                        value={stats?.totalSent || 0}
                        icon={<Send className="text-blue-500" />}
                    />
                    <StatCard
                        title="Read Rate"
                        value={`${Math.round(stats?.readRate || 0)}%`}
                        icon={<CheckCircle className="text-green-500" />}
                    />
                    <StatCard
                        title="Active Tokens"
                        value={stats?.activeTokens || 0}
                        icon={<Bell className="text-purple-500" />}
                    />
                </div>
            )}

            <div className="bg-white p-6 rounded-xl shadow-sm border border-gray-100">
                <h2 className="text-lg font-semibold mb-6 flex items-center gap-2">
                    <Send size={20} className="text-blue-600" />
                    Send Broadcast Notification
                </h2>

                <form onSubmit={handleBroadcast} className="space-y-4 max-w-2xl">
                    <div>
                        <label className="block text-sm font-medium text-gray-700 mb-1">Title</label>
                        <input
                            type="text"
                            required
                            value={title}
                            onChange={(e) => setTitle(e.target.value)}
                            className="w-full px-4 py-2 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                            placeholder="New Feature Alert!"
                        />
                    </div>

                    <div>
                        <label className="block text-sm font-medium text-gray-700 mb-1">Message Body</label>
                        <textarea
                            required
                            value={message}
                            onChange={(e) => setMessage(e.target.value)}
                            rows={4}
                            className="w-full px-4 py-2 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                            placeholder="We've just released a new update..."
                        />
                    </div>

                    <div className="grid md:grid-cols-2 gap-4">
                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-1">Type</label>
                            <select
                                value={type}
                                onChange={(e) => setType(e.target.value)}
                                className="w-full px-4 py-2 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                            >
                                <option value="system">System Info</option>
                                <option value="promo">Promotional</option>
                                <option value="update">App Update</option>
                                <option value="alert">Alert/Warning</option>
                            </select>
                        </div>
                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-1">Action URL (Optional)</label>
                            <input
                                type="text"
                                value={actionUrl}
                                onChange={(e) => setActionUrl(e.target.value)}
                                className="w-full px-4 py-2 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                                placeholder="/notebooks"
                            />
                        </div>
                    </div>

                    {error && (
                        <div className="p-3 bg-red-50 text-red-700 rounded-lg flex items-center gap-2">
                            <AlertCircle size={18} />
                            {error}
                        </div>
                    )}

                    {success && (
                        <div className="p-3 bg-green-50 text-green-700 rounded-lg flex items-center gap-2">
                            <CheckCircle size={18} />
                            {success}
                        </div>
                    )}

                    <button
                        type="submit"
                        disabled={sending}
                        className="px-6 py-2 bg-blue-600 text-white font-medium rounded-lg hover:bg-blue-700 disabled:opacity-50 transition-colors"
                    >
                        {sending ? 'Sending...' : 'Send Broadcast'}
                    </button>
                </form>
            </div>
        </div>
    );
}

function StatCard({ title, value, icon }) {
    return (
        <div className="bg-white p-6 rounded-xl shadow-sm border border-gray-100 flex items-center justify-between">
            <div>
                <p className="text-sm text-gray-500">{title}</p>
                <p className="text-2xl font-bold mt-1">{value}</p>
            </div>
            <div className="p-3 bg-gray-50 rounded-lg">
                {icon}
            </div>
        </div>
    );
}
