import { useState, useEffect } from 'react';
import { neon } from '../lib/neon';
import { Plus, Edit2, Trash2, Loader2, DollarSign, Coins, Check, X } from 'lucide-react';

export default function CreditPackages() {
    const [packages, setPackages] = useState([]);
    const [loading, setLoading] = useState(true);
    const [editingPackage, setEditingPackage] = useState(null);
    const [showForm, setShowForm] = useState(false);

    const [formData, setFormData] = useState({
        name: '',
        description: '',
        credits: 100,
        price: 4.99,
        is_active: true
    });

    useEffect(() => {
        fetchPackages();
    }, []);

    const fetchPackages = async () => {
        setLoading(true);
        try {
            const data = await neon.query('SELECT * FROM credit_packages ORDER BY price ASC', []);
            setPackages(data);
        } catch (error) {
            console.error('Error fetching packages:', error);
            alert('Failed to fetch credit packages');
        } finally {
            setLoading(false);
        }
    };

    const handleSubmit = async (e) => {
        e.preventDefault();
        try {
            if (editingPackage) {
                await neon.execute(
                    `UPDATE credit_packages 
                     SET name = $1, description = $2, credits = $3, price = $4, is_active = $5
                     WHERE id = $6`,
                    [formData.name, formData.description, formData.credits, formData.price, formData.is_active, editingPackage.id]
                );
            } else {
                await neon.execute(
                    `INSERT INTO credit_packages (name, description, credits, price, is_active)
                     VALUES ($1, $2, $3, $4, $5)`,
                    [formData.name, formData.description, formData.credits, formData.price, formData.is_active]
                );
            }

            resetForm();
            fetchPackages();
            alert(editingPackage ? 'Package updated successfully!' : 'Package created successfully!');
        } catch (error) {
            console.error('Error saving package:', error);
            alert('Failed to save package');
        }
    };

    const handleDelete = async (id) => {
        if (!confirm('Are you sure you want to delete this package?')) return;

        try {
            await neon.execute('DELETE FROM credit_packages WHERE id = $1', [id]);
            fetchPackages();
            alert('Package deleted successfully!');
        } catch (error) {
            console.error('Error deleting package:', error);
            alert('Failed to delete package');
        }
    };

    const handleEdit = (pkg) => {
        setEditingPackage(pkg);
        setFormData({
            name: pkg.name,
            description: pkg.description || '',
            credits: pkg.credits,
            price: pkg.price,
            is_active: pkg.is_active
        });
        setShowForm(true);
    };

    const resetForm = () => {
        setFormData({
            name: '',
            description: '',
            credits: 100,
            price: 4.99,
            is_active: true
        });
        setEditingPackage(null);
        setShowForm(false);
    };

    const toggleActive = async (pkg) => {
        try {
            await neon.execute(
                'UPDATE credit_packages SET is_active = $1 WHERE id = $2',
                [!pkg.is_active, pkg.id]
            );
            fetchPackages();
        } catch (error) {
            console.error('Error toggling active status:', error);
            alert('Failed to update package status');
        }
    };

    if (loading) {
        return (
            <div className="flex items-center justify-center h-64">
                <Loader2 className="h-8 w-8 animate-spin" />
            </div>
        );
    }

    return (
        <div className="p-8">
            <div className="mb-8">
                <div className="flex items-center justify-between">
                    <div>
                        <h1 className="text-3xl font-bold mb-2">Credit Packages</h1>
                        <p className="text-muted-foreground">Manage one-time credit purchase options</p>
                    </div>
                    <button
                        onClick={() => setShowForm(!showForm)}
                        className="flex items-center rounded-md bg-primary px-4 py-2 text-sm font-medium text-primary-foreground hover:bg-primary/90"
                    >
                        <Plus className="mr-2 h-4 w-4" />
                        New Package
                    </button>
                </div>
            </div>

            {/* Form */}
            {showForm && (
                <div className="bg-card border border-border rounded-lg p-6 mb-6">
                    <h2 className="text-xl font-semibold mb-4">{editingPackage ? 'Edit Package' : 'Create New Package'}</h2>
                    <form onSubmit={handleSubmit} className="space-y-4">
                        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                            <div>
                                <label className="block text-sm font-medium mb-1">Package Name</label>
                                <input
                                    type="text"
                                    value={formData.name}
                                    onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                                    className="w-full rounded-md border border-border bg-background p-2"
                                    required
                                />
                            </div>
                            <div>
                                <label className="block text-sm font-medium mb-1">Credits</label>
                                <input
                                    type="number"
                                    value={formData.credits}
                                    onChange={(e) => setFormData({ ...formData, credits: parseInt(e.target.value) })}
                                    className="w-full rounded-md border border-border bg-background p-2"
                                    required
                                />
                            </div>
                            <div>
                                <label className="block text-sm font-medium mb-1">Price (USD)</label>
                                <input
                                    type="number"
                                    step="0.01"
                                    value={formData.price}
                                    onChange={(e) => setFormData({ ...formData, price: parseFloat(e.target.value) })}
                                    className="w-full rounded-md border border-border bg-background p-2"
                                    required
                                />
                            </div>
                        </div>
                        <div>
                            <label className="block text-sm font-medium mb-1">Description</label>
                            <textarea
                                value={formData.description}
                                onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                                className="w-full rounded-md border border-border bg-background p-2"
                                rows={2}
                            />
                        </div>
                        <div>
                            <label className="flex items-center gap-2">
                                <input
                                    type="checkbox"
                                    checked={formData.is_active}
                                    onChange={(e) => setFormData({ ...formData, is_active: e.target.checked })}
                                    className="rounded"
                                />
                                <span className="text-sm">Active (visible to users)</span>
                            </label>
                        </div>
                        <div className="flex gap-2">
                            <button
                                type="submit"
                                className="flex items-center rounded-md bg-primary px-4 py-2 text-sm font-medium text-primary-foreground hover:bg-primary/90"
                            >
                                {editingPackage ? 'Update Package' : 'Create Package'}
                            </button>
                            <button
                                type="button"
                                onClick={resetForm}
                                className="rounded-md bg-secondary px-4 py-2 text-sm font-medium hover:bg-secondary/80"
                            >
                                Cancel
                            </button>
                        </div>
                    </form>
                </div>
            )}

            {/* Packages Grid */}
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
                {packages.map((pkg) => (
                    <div
                        key={pkg.id}
                        className={`bg-card border-2 rounded-lg p-6 relative ${!pkg.is_active ? 'opacity-60 border-border' : 'border-primary/20 hover:border-primary/50'
                            } transition-all`}
                    >
                        {!pkg.is_active && (
                            <div className="absolute -top-3 right-4 bg-red-500 text-white px-3 py-1 rounded-full text-xs font-semibold">
                                INACTIVE
                            </div>
                        )}

                        <div className="mb-4">
                            <h3 className="text-lg font-bold mb-3">{pkg.name}</h3>
                            <div className="flex items-center gap-2 mb-3">
                                <Coins className="h-5 w-5 text-primary" />
                                <span className="text-2xl font-bold">{pkg.credits}</span>
                                <span className="text-sm text-muted-foreground">credits</span>
                            </div>
                            <div className="flex items-baseline gap-1 mb-3">
                                <DollarSign className="h-5 w-5 text-muted-foreground" />
                                <span className="text-2xl font-bold">{pkg.price}</span>
                            </div>
                            {pkg.description && (
                                <p className="text-sm text-muted-foreground">{pkg.description}</p>
                            )}
                            <div className="mt-3 text-xs text-muted-foreground">
                                ${(pkg.price / pkg.credits).toFixed(4)} per credit
                            </div>
                        </div>

                        <div className="flex gap-2 pt-4 border-t border-border">
                            <button
                                onClick={() => handleEdit(pkg)}
                                className="flex-1 flex items-center justify-center gap-1 rounded-md bg-secondary px-2 py-2 text-sm hover:bg-secondary/80"
                            >
                                <Edit2 className="h-3 w-3" />
                                Edit
                            </button>
                            <button
                                onClick={() => toggleActive(pkg)}
                                className="flex-1 flex items-center justify-center gap-1 rounded-md bg-secondary px-2 py-2 text-sm hover:bg-secondary/80"
                            >
                                {pkg.is_active ? <X className="h-3 w-3" /> : <Check className="h-3 w-3" />}
                                {pkg.is_active ? 'Hide' : 'Show'}
                            </button>
                            <button
                                onClick={() => handleDelete(pkg.id)}
                                className="rounded-md bg-destructive px-2 py-2 text-sm text-destructive-foreground hover:bg-destructive/90"
                            >
                                <Trash2 className="h-3 w-3" />
                            </button>
                        </div>
                    </div>
                ))}
            </div>

            {packages.length === 0 && (
                <div className="text-center py-12 text-muted-foreground">
                    No credit packages found. Create your first package!
                </div>
            )}
        </div>
    );
}
