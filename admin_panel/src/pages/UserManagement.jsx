import { useState, useEffect } from 'react';
import api from '../lib/api';
import { Users, Shield, Ban, Check, Search, Loader2 } from 'lucide-react';

export default function UserManagement() {
    const [users, setUsers] = useState([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);
    const [searchTerm, setSearchTerm] = useState('');

    useEffect(() => {
        loadUsers();
    }, []);

    const loadUsers = async () => {
        try {
            setLoading(true);
            const response = await api.getUsers();
            setUsers(response.users || []);
        } catch (err) {
            setError(err.message);
        } finally {
            setLoading(false);
        }
    };

    const toggleUserRole = async (userId, currentRole) => {
        try {
            const newRole = currentRole === 'admin' ? 'user' : 'admin';
            await api.updateUserRole(userId, newRole);
            await loadUsers();
        } catch (err) {
            alert('Failed to update role: ' + err.message);
        }
    };

    const toggleUserStatus = async (userId, currentStatus) => {
        try {
            await api.updateUserStatus(userId, !currentStatus);
            await loadUsers();
        } catch (err) {
            alert('Failed to update status: ' + err.message);
        }
    };

    const filteredUsers = users.filter(user =>
        user.email?.toLowerCase().includes(searchTerm.toLowerCase()) ||
        user.display_name?.toLowerCase().includes(searchTerm.toLowerCase())
    );

    if (loading) {
        return (
            <div className="flex items-center justify-center h-64">
                <Loader2 className="h-12 w-12 animate-spin text-primary" />
            </div>
        );
    }

    if (error) {
        return (
            <div className="p-8">
                <div className="bg-destructive/10 border border-destructive rounded-lg p-4">
                    <p className="text-destructive">Error: {error}</p>
                </div>
            </div>
        );
    }

    return (
        <div className="p-8">
            <div className="mb-8">
                <h1 className="text-3xl font-bold mb-2">User Management</h1>
                <p className="text-muted-foreground">Manage user accounts and permissions</p>
            </div>

            {/* Search */}
            <div className="mb-6">
                <div className="relative">
                    <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-5 w-5 text-muted-foreground" />
                    <input
                        type="text"
                        placeholder="Search users..."
                        value={searchTerm}
                        onChange={(e) => setSearchTerm(e.target.value)}
                        className="w-full pl-10 pr-4 py-2 border border-border rounded-lg bg-background"
                    />
                </div>
            </div>

            {/* Stats */}
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
                <div className="bg-card border border-border rounded-lg p-4">
                    <div className="flex items-center gap-3">
                        <Users className="h-8 w-8 text-primary" />
                        <div>
                            <p className="text-sm text-muted-foreground">Total Users</p>
                            <p className="text-2xl font-bold">{users.length}</p>
                        </div>
                    </div>
                </div>
                <div className="bg-card border border-border rounded-lg p-4">
                    <div className="flex items-center gap-3">
                        <Shield className="h-8 w-8 text-green-600" />
                        <div>
                            <p className="text-sm text-muted-foreground">Admins</p>
                            <p className="text-2xl font-bold">{users.filter(u => u.role === 'admin').length}</p>
                        </div>
                    </div>
                </div>
                <div className="bg-card border border-border rounded-lg p-4">
                    <div className="flex items-center gap-3">
                        <Check className="h-8 w-8 text-blue-600" />
                        <div>
                            <p className="text-sm text-muted-foreground">Active</p>
                            <p className="text-2xl font-bold">{users.filter(u => u.is_active).length}</p>
                        </div>
                    </div>
                </div>
            </div>

            {/* Users Table */}
            <div className="bg-card border border-border rounded-lg overflow-hidden">
                <table className="w-full">
                    <thead className="bg-muted/50">
                        <tr>
                            <th className="text-left p-4 font-semibold">User</th>
                            <th className="text-left p-4 font-semibold">Email</th>
                            <th className="text-left p-4 font-semibold">Role</th>
                            <th className="text-left p-4 font-semibold">Status</th>
                            <th className="text-left p-4 font-semibold">Created</th>
                            <th className="text-left p-4 font-semibold">Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        {filteredUsers.map((user) => (
                            <tr key={user.id} className="border-t border-border hover:bg-muted/30 transition-colors">
                                <td className="p-4">
                                    <div className="flex items-center gap-3">
                                        <div className="w-10 h-10 rounded-full bg-primary/10 flex items-center justify-center">
                                            <span className="text-primary font-semibold">
                                                {(user.display_name || user.email).charAt(0).toUpperCase()}
                                            </span>
                                        </div>
                                        <span className="font-medium">{user.display_name || 'Unknown'}</span>
                                    </div>
                                </td>
                                <td className="p-4 text-muted-foreground">{user.email}</td>
                                <td className="p-4">
                                    <button
                                        onClick={() => toggleUserRole(user.id, user.role)}
                                        className={`px-3 py-1 rounded-full text-xs font-medium ${user.role === 'admin'
                                            ? 'bg-green-100 text-green-700 hover:bg-green-200'
                                            : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                                            }`}
                                    >
                                        {user.role === 'admin' ? (
                                            <span className="flex items-center gap-1">
                                                <Shield className="h-3 w-3" />
                                                Admin
                                            </span>
                                        ) : (
                                            'User'
                                        )}
                                    </button>
                                </td>
                                <td className="p-4">
                                    <button
                                        onClick={() => toggleUserStatus(user.id, user.is_active)}
                                        className={`px-3 py-1 rounded-full text-xs font-medium ${user.is_active
                                            ? 'bg-blue-100 text-blue-700 hover:bg-blue-200'
                                            : 'bg-red-100 text-red-700 hover:bg-red-200'
                                            }`}
                                    >
                                        {user.is_active ? (
                                            <span className="flex items-center gap-1">
                                                <Check className="h-3 w-3" />
                                                Active
                                            </span>
                                        ) : (
                                            <span className="flex items-center gap-1">
                                                <Ban className="h-3 w-3" />
                                                Inactive
                                            </span>
                                        )}
                                    </button>
                                </td>
                                <td className="p-4 text-muted-foreground text-sm">
                                    {new Date(user.created_at).toLocaleDateString()}
                                </td>
                                <td className="p-4">
                                    <div className="flex gap-2">
                                        <button
                                            onClick={() => toggleUserRole(user.id, user.role)}
                                            className="text-sm text-primary hover:underline"
                                        >
                                            {user.role === 'admin' ? 'Demote' : 'Promote'}
                                        </button>
                                    </div>
                                </td>
                            </tr>
                        ))}
                    </tbody>
                </table>
            </div>

            {filteredUsers.length === 0 && (
                <div className="text-center py-12 text-muted-foreground">
                    No users found matching "{searchTerm}"
                </div>
            )}
        </div>
    );
}
