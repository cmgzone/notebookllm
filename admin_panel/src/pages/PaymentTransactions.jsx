import { useState, useEffect } from 'react';
import api from '../lib/api';
import { Search, Filter, RefreshCw, Loader2, Download } from 'lucide-react';

export default function PaymentTransactions() {
    const [transactions, setTransactions] = useState([]);
    const [loading, setLoading] = useState(true);
    const [searchTerm, setSearchTerm] = useState('');
    const [statusFilter, setStatusFilter] = useState('all');

    useEffect(() => {
        fetchTransactions();
    }, []);

    const fetchTransactions = async () => {
        setLoading(true);
        try {
            const data = await api.getTransactions(100);
            setTransactions(data.transactions || []);
        } catch (error) {
            console.error('Error fetching transactions:', error);
            alert('Failed to fetch transactions');
        } finally {
            setLoading(false);
        }
    };

    const getStatusColor = (status) => {
        switch (status) {
            case 'purchase': return 'bg-green-100 text-green-800';
            case 'subscription': return 'bg-blue-100 text-blue-800';
            case 'usage': return 'bg-yellow-100 text-yellow-800';
            case 'refund': return 'bg-purple-100 text-purple-800';
            case 'bonus': return 'bg-cyan-100 text-cyan-800';
            default: return 'bg-gray-100 text-gray-800';
        }
    };

    const formatDate = (dateString) => {
        if (!dateString) return 'N/A';
        return new Date(dateString).toLocaleString();
    };

    const filteredTransactions = transactions.filter(tx => {
        const matchesSearch =
            (tx.user_email?.toLowerCase() || '').includes(searchTerm.toLowerCase()) ||
            (tx.description?.toLowerCase() || '').includes(searchTerm.toLowerCase()) ||
            (tx.transaction_type?.toLowerCase() || '').includes(searchTerm.toLowerCase());

        const matchesStatus = statusFilter === 'all' || tx.transaction_type === statusFilter;

        return matchesSearch && matchesStatus;
    });

    return (
        <div className="p-8 space-y-8">
            <div className="flex justify-between items-center mb-8">
                <div>
                    <h1 className="text-3xl font-bold mb-2">Credit Transactions</h1>
                    <p className="text-muted-foreground bg-clip-text text-transparent bg-gradient-to-r from-blue-600 to-cyan-600">
                        Monitor credit purchases and usage
                    </p>
                </div>
                <button
                    onClick={fetchTransactions}
                    className="p-2 rounded-full hover:bg-slate-100 transition-colors"
                    title="Refresh"
                >
                    <RefreshCw className="h-5 w-5 text-slate-600" />
                </button>
            </div>

            {/* Filters */}
            <div className="flex flex-col sm:flex-row gap-4 mb-6">
                <div className="relative flex-1">
                    <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-slate-400" />
                    <input
                        type="text"
                        placeholder="Search by email, transaction ID..."
                        className="w-full pl-10 pr-4 py-2 rounded-lg border border-slate-200 focus:outline-none focus:ring-2 focus:ring-blue-500"
                        value={searchTerm}
                        onChange={(e) => setSearchTerm(e.target.value)}
                    />
                </div>
                <div className="flex gap-2">
                    <div className="relative">
                        <Filter className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-slate-400" />
                        <select
                            className="pl-10 pr-8 py-2 rounded-lg border border-slate-200 focus:outline-none focus:ring-2 focus:ring-blue-500 appearance-none bg-white min-w-[150px]"
                            value={statusFilter}
                            onChange={(e) => setStatusFilter(e.target.value)}
                        >
                            <option value="all">All Types</option>
                            <option value="purchase">Purchase</option>
                            <option value="subscription">Subscription</option>
                            <option value="usage">Usage</option>
                            <option value="refund">Refund</option>
                            <option value="bonus">Bonus</option>
                        </select>
                    </div>
                </div>
            </div>

            {/* Table */}
            <div className="bg-white rounded-xl shadow-sm border border-slate-100 overflow-hidden">
                <div className="overflow-x-auto">
                    <table className="w-full text-left text-sm">
                        <thead className="bg-slate-50 border-b border-slate-100">
                            <tr>
                                <th className="px-6 py-4 font-semibold text-slate-700">Date</th>
                                <th className="px-6 py-4 font-semibold text-slate-700">User</th>
                                <th className="px-6 py-4 font-semibold text-slate-700">Description</th>
                                <th className="px-6 py-4 font-semibold text-slate-700">Balance After</th>
                                <th className="px-6 py-4 font-semibold text-slate-700">Type</th>
                                <th className="px-6 py-4 font-semibold text-slate-700">ID</th>
                            </tr>
                        </thead>
                        <tbody className="divide-y divide-slate-100">
                            {loading ? (
                                <tr>
                                    <td colSpan="6" className="px-6 py-12 text-center text-slate-500">
                                        <div className="flex justify-center items-center">
                                            <Loader2 className="h-6 w-6 animate-spin mr-2" />
                                            Loading transactions...
                                        </div>
                                    </td>
                                </tr>
                            ) : filteredTransactions.length === 0 ? (
                                <tr>
                                    <td colSpan="6" className="px-6 py-12 text-center text-slate-500">
                                        No transactions found matching your criteria
                                    </td>
                                </tr>
                            ) : (
                                filteredTransactions.map((tx) => (
                                    <tr key={tx.id} className="hover:bg-slate-50 transition-colors">
                                        <td className="px-6 py-4 text-slate-600">
                                            {formatDate(tx.created_at)}
                                        </td>
                                        <td className="px-6 py-4 font-medium text-slate-900">
                                            {tx.user_email || 'Unknown User'}
                                            <div className="text-xs text-slate-400 font-mono mt-0.5">
                                                {tx.user_id?.substring(0, 8)}...
                                            </div>
                                        </td>
                                        <td className="px-6 py-4 text-slate-600">
                                            {tx.description || tx.transaction_type || 'Credit Transaction'}
                                            <div className="text-xs text-slate-400">
                                                {tx.amount > 0 ? '+' : ''}{tx.amount} credits
                                            </div>
                                        </td>
                                        <td className="px-6 py-4 font-medium text-slate-900">
                                            {tx.balance_after != null ? `${tx.balance_after} credits` : '-'}
                                        </td>
                                        <td className="px-6 py-4">
                                            <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${getStatusColor(tx.transaction_type)}`}>
                                                {(tx.transaction_type || 'unknown').charAt(0).toUpperCase() + (tx.transaction_type || 'unknown').slice(1)}
                                            </span>
                                        </td>
                                        <td className="px-6 py-4">
                                            <div className="font-mono text-xs text-slate-500">
                                                {tx.id?.substring(0, 8) || '-'}
                                            </div>
                                        </td>
                                    </tr>
                                ))
                            )}
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    );
}
