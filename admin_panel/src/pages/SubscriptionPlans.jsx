import { useState, useEffect } from 'react';
import { neon } from '../lib/neon';
import { Plus, Edit2, Trash2, Check, X, Loader2, DollarSign, Calendar } from 'lucide-react';

export default function SubscriptionPlans() {
    const [plans, setPlans] = useState([]);
    const [loading, setLoading] = useState(true);
    const [editingPlan, setEditingPlan] = useState(null);
    const [showForm, setShowForm] = useState(false);

    const [formData, setFormData] = useState({
        name: '',
        description: '',
        credits_per_month: 30,
        price: 0,
        is_active: true,
        is_free_plan: false
    });

    useEffect(() => {
        fetchPlans();
    }, []);

    const fetchPlans = async () => {
        setLoading(true);
        try {
            const data = await neon.query('SELECT * FROM subscription_plans ORDER BY price ASC', []);
            setPlans(data);
        } catch (error) {
            console.error('Error fetching plans:', error);
            alert('Failed to fetch subscription plans');
        } finally {
            setLoading(false);
        }
    };

    const handleSubmit = async (e) => {
        e.preventDefault();
        try {
            if (editingPlan) {
                await neon.execute(
                    `UPDATE subscription_plans 
                     SET name = $1, description = $2, credits_per_month = $3, price = $4, is_active = $5, is_free_plan = $6, updated_at = CURRENT_TIMESTAMP
                     WHERE id = $7`,
                    [formData.name, formData.description, formData.credits_per_month, formData.price, formData.is_active, formData.is_free_plan, editingPlan.id]
                );
            } else {
                await neon.execute(
                    `INSERT INTO subscription_plans (name, description, credits_per_month, price, is_active, is_free_plan)
                     VALUES ($1, $2, $3, $4, $5, $6)`,
                    [formData.name, formData.description, formData.credits_per_month, formData.price, formData.is_active, formData.is_free_plan]
                );
            }

            resetForm();
            fetchPlans();
            alert(editingPlan ? 'Plan updated successfully!' : 'Plan created successfully!');
        } catch (error) {
            console.error('Error saving plan:', error);
            alert('Failed to save plan');
        }
    };

    const handleDelete = async (id) => {
        if (!confirm('Are you sure you want to delete this plan?')) return;

        try {
            await neon.execute('DELETE FROM subscription_plans WHERE id = $1', [id]);
            fetchPlans();
            alert('Plan deleted successfully!');
        } catch (error) {
            console.error('Error deleting plan:', error);
            alert('Failed to delete plan. Make sure no users are subscribed to this plan.');
        }
    };

    const handleEdit = (plan) => {
        setEditingPlan(plan);
        setFormData({
            name: plan.name,
            description: plan.description || '',
            credits_per_month: plan.credits_per_month,
            price: plan.price,
            is_active: plan.is_active,
            is_free_plan: plan.is_free_plan
        });
        setShowForm(true);
    };

    const resetForm = () => {
        setFormData({
            name: '',
            description: '',
            credits_per_month: 30,
            price: 0,
            is_active: true,
            is_free_plan: false
        });
        setEditingPlan(null);
        setShowForm(false);
    };

    const toggleActive = async (plan) => {
        try {
            await neon.execute(
                'UPDATE subscription_plans SET is_active = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2',
                [!plan.is_active, plan.id]
            );
            fetchPlans();
        } catch (error) {
            console.error('Error toggling active status:', error);
            alert('Failed to update plan status');
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
                        <h1 className="text-3xl font-bold mb-2">Subscription Plans</h1>
                        <p className="text-muted-foreground">Manage subscription tiers and pricing</p>
                    </div>
                    <button
                        onClick={() => setShowForm(!showForm)}
                        className="flex items-center rounded-md bg-primary px-4 py-2 text-sm font-medium text-primary-foreground hover:bg-primary/90"
                    >
                        <Plus className="mr-2 h-4 w-4" />
                        New Plan
                    </button>
                </div>
            </div>

            {/* Form */}
            {showForm && (
                <div className="bg-card border border-border rounded-lg p-6 mb-6">
                    <h2 className="text-xl font-semibold mb-4">{editingPlan ? 'Edit Plan' : 'Create New Plan'}</h2>
                    <form onSubmit={handleSubmit} className="space-y-4">
                        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                            <div>
                                <label className="block text-sm font-medium mb-1">Plan Name</label>
                                <input
                                    type="text"
                                    value={formData.name}
                                    onChange={(e) => setFormData({ ...formData, name: e.target.value })}
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
                            <div>
                                <label className="block text-sm font-medium mb-1">Credits per Month</label>
                                <input
                                    type="number"
                                    value={formData.credits_per_month}
                                    onChange={(e) => setFormData({ ...formData, credits_per_month: parseInt(e.target.value) })}
                                    className="w-full rounded-md border border-border bg-background p-2"
                                    required
                                />
                            </div>
                            <div className="flex items-center gap-4 pt-6">
                                <label className="flex items-center gap-2">
                                    <input
                                        type="checkbox"
                                        checked={formData.is_active}
                                        onChange={(e) => setFormData({ ...formData, is_active: e.target.checked })}
                                        className="rounded"
                                    />
                                    <span className="text-sm">Active</span>
                                </label>
                                <label className="flex items-center gap-2">
                                    <input
                                        type="checkbox"
                                        checked={formData.is_free_plan}
                                        onChange={(e) => setFormData({ ...formData, is_free_plan: e.target.checked })}
                                        className="rounded"
                                    />
                                    <span className="text-sm">Free Plan</span>
                                </label>
                            </div>
                        </div>
                        <div>
                            <label className="block text-sm font-medium mb-1">Description</label>
                            <textarea
                                value={formData.description}
                                onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                                className="w-full rounded-md border border-border bg-background p-2"
                                rows={3}
                            />
                        </div>
                        <div className="flex gap-2">
                            <button
                                type="submit"
                                className="flex items-center rounded-md bg-primary px-4 py-2 text-sm font-medium text-primary-foreground hover:bg-primary/90"
                            >
                                {editingPlan ? 'Update Plan' : 'Create Plan'}
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

            {/* Plans Grid */}
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                {plans.map((plan) => (
                    <div
                        key={plan.id}
                        className={`bg-card border-2 rounded-lg p-6 relative ${plan.is_free_plan ? 'border-green-500' : 'border-border'
                            } ${!plan.is_active ? 'opacity-60' : ''}`}
                    >
                        {plan.is_free_plan && (
                            <div className="absolute -top-3 left-4 bg-green-500 text-white px-3 py-1 rounded-full text-xs font-semibold">
                                FREE PLAN
                            </div>
                        )}
                        {!plan.is_active && (
                            <div className="absolute -top-3 right-4 bg-red-500 text-white px-3 py-1 rounded-full text-xs font-semibold">
                                INACTIVE
                            </div>
                        )}

                        <div className="mb-4">
                            <h3 className="text-xl font-bold mb-2">{plan.name}</h3>
                            <div className="flex items-baseline gap-1 mb-3">
                                <span className="text-3xl font-bold">${plan.price}</span>
                                <span className="text-muted-foreground">/month</span>
                            </div>
                            <div className="flex items-center gap-2 text-sm text-muted-foreground mb-2">
                                <Calendar className="h-4 w-4" />
                                <span>{plan.credits_per_month} credits/month</span>
                            </div>
                            {plan.description && (
                                <p className="text-sm text-muted-foreground">{plan.description}</p>
                            )}
                        </div>

                        <div className="flex gap-2 pt-4 border-t border-border">
                            <button
                                onClick={() => handleEdit(plan)}
                                className="flex-1 flex items-center justify-center gap-1 rounded-md bg-secondary px-3 py-2 text-sm hover:bg-secondary/80"
                            >
                                <Edit2 className="h-3 w-3" />
                                Edit
                            </button>
                            <button
                                onClick={() => toggleActive(plan)}
                                className="flex-1 flex items-center justify-center gap-1 rounded-md bg-secondary px-3 py-2 text-sm hover:bg-secondary/80"
                            >
                                {plan.is_active ? <X className="h-3 w-3" /> : <Check className="h-3 w-3" />}
                                {plan.is_active ? 'Deactivate' : 'Activate'}
                            </button>
                            <button
                                onClick={() => handleDelete(plan.id)}
                                className="rounded-md bg-destructive px-3 py-2 text-sm text-destructive-foreground hover:bg-destructive/90"
                            >
                                <Trash2 className="h-3 w-3" />
                            </button>
                        </div>
                    </div>
                ))}
            </div>

            {plans.length === 0 && (
                <div className="text-center py-12 text-muted-foreground">
                    No subscription plans found. Create your first plan!
                </div>
            )}
        </div>
    );
}
