import { useState, useEffect } from 'react';
import { neon } from '../lib/neon';
import { Plus, Edit2, Trash2, CheckCircle, XCircle, Bot, Loader2 } from 'lucide-react';

export default function AIModels() {
    const [models, setModels] = useState([]);
    const [loading, setLoading] = useState(true);
    const [isModalOpen, setIsModalOpen] = useState(false);
    const [editingModel, setEditingModel] = useState(null);
    const [saving, setSaving] = useState(false);

    // Form state
    const [formData, setFormData] = useState({
        name: '',
        model_id: '',
        provider: 'gemini',
        description: '',
        cost_input: 0,
        cost_output: 0,
        context_window: 0,
        is_active: true,
        is_premium: false
    });

    const providers = ['gemini', 'openrouter', 'openai', 'anthropic'];

    useEffect(() => {
        fetchModels();
    }, []);

    async function fetchModels() {
        try {
            const data = await neon.query('SELECT * FROM ai_models ORDER BY provider, name');
            setModels(data);
        } catch (error) {
            console.error('Failed to fetch models:', error);
            alert('Failed to load models');
        } finally {
            setLoading(false);
        }
    }

    function handleOpenModal(model = null) {
        if (model) {
            setEditingModel(model);
            setFormData({
                name: model.name,
                model_id: model.model_id,
                provider: model.provider,
                description: model.description || '',
                cost_input: parseFloat(model.cost_input) || 0,
                cost_output: parseFloat(model.cost_output) || 0,
                context_window: parseInt(model.context_window) || 0,
                is_active: model.is_active,
                is_premium: model.is_premium
            });
        } else {
            setEditingModel(null);
            setFormData({
                name: '',
                model_id: '',
                provider: 'gemini',
                description: '',
                cost_input: 0,
                cost_output: 0,
                context_window: 0,
                is_active: true,
                is_premium: false
            });
        }
        setIsModalOpen(true);
    }

    async function handleSave(e) {
        e.preventDefault();
        setSaving(true);

        try {
            if (editingModel) {
                await neon.query(
                    `UPDATE ai_models SET 
                        name = $1, model_id = $2, provider = $3, description = $4,
                        cost_input = $5, cost_output = $6, context_window = $7,
                        is_active = $8, is_premium = $9
                    WHERE id = $10`,
                    [
                        formData.name,
                        formData.model_id,
                        formData.provider,
                        formData.description,
                        formData.cost_input,
                        formData.cost_output,
                        formData.context_window,
                        formData.is_active,
                        formData.is_premium,
                        editingModel.id
                    ]
                );
            } else {
                await neon.query(
                    `INSERT INTO ai_models (
                        name, model_id, provider, description,
                        cost_input, cost_output, context_window,
                        is_active, is_premium
                    ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
                    [
                        formData.name,
                        formData.model_id,
                        formData.provider,
                        formData.description,
                        formData.cost_input,
                        formData.cost_output,
                        formData.context_window,
                        formData.is_active,
                        formData.is_premium
                    ]
                );
            }
            await fetchModels();
            setIsModalOpen(false);
        } catch (error) {
            console.error('Failed to save model:', error);
            alert('Failed to save model: ' + error.message);
        } finally {
            setSaving(false);
        }
    }

    async function handleDelete(id) {
        if (!confirm('Are you sure you want to delete this model?')) return;

        try {
            await neon.query('DELETE FROM ai_models WHERE id = $1', [id]);
            fetchModels();
        } catch (error) {
            console.error('Failed to delete model:', error);
            alert('Failed to delete model');
        }
    }

    if (loading) return <div className="p-8 text-center">Loading AI Models...</div>;

    return (
        <div>
            <div className="sm:flex sm:items-center">
                <div className="sm:flex-auto">
                    <h1 className="text-2xl font-semibold text-gray-900">AI Models</h1>
                    <p className="mt-2 text-sm text-gray-700">
                        Manage available AI models for the application. Add custom models, pricing, and availability.
                    </p>
                </div>
                <div className="mt-4 sm:ml-16 sm:mt-0 sm:flex-none">
                    <button
                        type="button"
                        onClick={() => handleOpenModal()}
                        className="inline-flex items-center justify-center rounded-md bg-indigo-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600"
                    >
                        <Plus className="mr-2 h-4 w-4" />
                        Add Model
                    </button>
                </div>
            </div>

            <div className="mt-8 flow-root">
                <div className="-mx-4 -my-2 overflow-x-auto sm:-mx-6 lg:-mx-8">
                    <div className="inline-block min-w-full py-2 align-middle sm:px-6 lg:px-8">
                        <div className="overflow-hidden shadow ring-1 ring-black ring-opacity-5 sm:rounded-lg">
                            <table className="min-w-full divide-y divide-gray-300">
                                <thead className="bg-gray-50">
                                    <tr>
                                        <th scope="col" className="py-3.5 pl-4 pr-3 text-left text-sm font-semibold text-gray-900 sm:pl-6">Name</th>
                                        <th scope="col" className="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">Model ID</th>
                                        <th scope="col" className="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">Provider</th>
                                        <th scope="col" className="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">Cost (In/Out)</th>
                                        <th scope="col" className="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">Status</th>
                                        <th scope="col" className="relative py-3.5 pl-3 pr-4 sm:pr-6">
                                            <span className="sr-only">Actions</span>
                                        </th>
                                    </tr>
                                </thead>
                                <tbody className="divide-y divide-gray-200 bg-white">
                                    {models.map((model) => (
                                        <tr key={model.id}>
                                            <td className="whitespace-nowrap py-4 pl-4 pr-3 text-sm font-medium text-gray-900 sm:pl-6">
                                                <div className="flex items-center">
                                                    <Bot className="mr-2 h-5 w-5 text-gray-400" />
                                                    {model.name}
                                                    {model.is_premium && (
                                                        <span className="ml-2 inline-flex items-center rounded-md bg-amber-50 px-2 py-1 text-xs font-medium text-amber-700 ring-1 ring-inset ring-amber-600/20">
                                                            Premium
                                                        </span>
                                                    )}
                                                </div>
                                            </td>
                                            <td className="whitespace-nowrap px-3 py-4 text-sm text-gray-500">{model.model_id}</td>
                                            <td className="whitespace-nowrap px-3 py-4 text-sm text-gray-500 capitalize">{model.provider}</td>
                                            <td className="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                                                ${parseFloat(model.cost_input).toFixed(4)} / ${parseFloat(model.cost_output).toFixed(4)}
                                            </td>
                                            <td className="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                                                {model.is_active ? (
                                                    <span className="inline-flex items-center rounded-md bg-green-50 px-2 py-1 text-xs font-medium text-green-700 ring-1 ring-inset ring-green-600/20">
                                                        Active
                                                    </span>
                                                ) : (
                                                    <span className="inline-flex items-center rounded-md bg-red-50 px-2 py-1 text-xs font-medium text-red-700 ring-1 ring-inset ring-red-600/20">
                                                        Inactive
                                                    </span>
                                                )}
                                            </td>
                                            <td className="relative whitespace-nowrap py-4 pl-3 pr-4 text-right text-sm font-medium sm:pr-6">
                                                <button
                                                    onClick={() => handleOpenModal(model)}
                                                    className="text-indigo-600 hover:text-indigo-900 mr-4"
                                                >
                                                    <Edit2 className="h-4 w-4" />
                                                    <span className="sr-only">Edit, {model.name}</span>
                                                </button>
                                                <button
                                                    onClick={() => handleDelete(model.id)}
                                                    className="text-red-600 hover:text-red-900"
                                                >
                                                    <Trash2 className="h-4 w-4" />
                                                    <span className="sr-only">Delete, {model.name}</span>
                                                </button>
                                            </td>
                                        </tr>
                                    ))}
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>
            </div>

            {/* Modal */}
            {isModalOpen && (
                <div className="fixed inset-0 z-10 overflow-y-auto">
                    <div className="flex min-h-full items-end justify-center p-4 text-center sm:items-center sm:p-0">
                        <div className="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity" onClick={() => setIsModalOpen(false)} />

                        <div className="relative transform overflow-hidden rounded-lg bg-white px-4 pb-4 pt-5 text-left shadow-xl transition-all sm:my-8 sm:w-full sm:max-w-lg sm:p-6">
                            <h3 className="text-base font-semibold leading-6 text-gray-900 mb-4">
                                {editingModel ? 'Edit AI Model' : 'Add New AI Model'}
                            </h3>

                            <form onSubmit={handleSave} className="space-y-4">
                                <div>
                                    <label className="block text-sm font-medium text-gray-700">Display Name</label>
                                    <input
                                        type="text"
                                        required
                                        value={formData.name}
                                        onChange={e => setFormData({ ...formData, name: e.target.value })}
                                        className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm border p-2"
                                    />
                                </div>

                                <div>
                                    <label className="block text-sm font-medium text-gray-700">Model ID (API)</label>
                                    <input
                                        type="text"
                                        required
                                        value={formData.model_id}
                                        onChange={e => setFormData({ ...formData, model_id: e.target.value })}
                                        placeholder="e.g. gpt-4o"
                                        className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm border p-2"
                                    />
                                </div>

                                <div>
                                    <label className="block text-sm font-medium text-gray-700">Provider</label>
                                    <select
                                        value={formData.provider}
                                        onChange={e => setFormData({ ...formData, provider: e.target.value })}
                                        className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm border p-2"
                                    >
                                        {providers.map(p => (
                                            <option key={p} value={p}>{p}</option>
                                        ))}
                                    </select>
                                </div>

                                <div className="grid grid-cols-2 gap-4">
                                    <div>
                                        <label className="block text-sm font-medium text-gray-700">Input Cost ($/1k)</label>
                                        <input
                                            type="number"
                                            step="0.000001"
                                            value={formData.cost_input}
                                            onChange={e => setFormData({ ...formData, cost_input: e.target.value })}
                                            className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm border p-2"
                                        />
                                    </div>
                                    <div>
                                        <label className="block text-sm font-medium text-gray-700">Output Cost ($/1k)</label>
                                        <input
                                            type="number"
                                            step="0.000001"
                                            value={formData.cost_output}
                                            onChange={e => setFormData({ ...formData, cost_output: e.target.value })}
                                            className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm border p-2"
                                        />
                                    </div>
                                </div>

                                <div className="flex items-center space-x-4 pt-2">
                                    <label className="flex items-center space-x-2">
                                        <input
                                            type="checkbox"
                                            checked={formData.is_premium}
                                            onChange={e => setFormData({ ...formData, is_premium: e.target.checked })}
                                            className="h-4 w-4 rounded border-gray-300 text-indigo-600 focus:ring-indigo-600"
                                        />
                                        <span className="text-sm text-gray-900">Premium Only</span>
                                    </label>

                                    <label className="flex items-center space-x-2">
                                        <input
                                            type="checkbox"
                                            checked={formData.is_active}
                                            onChange={e => setFormData({ ...formData, is_active: e.target.checked })}
                                            className="h-4 w-4 rounded border-gray-300 text-indigo-600 focus:ring-indigo-600"
                                        />
                                        <span className="text-sm text-gray-900">Active</span>
                                    </label>
                                </div>

                                <div className="mt-5 sm:mt-6 sm:grid sm:grid-flow-row-dense sm:grid-cols-2 sm:gap-3">
                                    <button
                                        type="submit"
                                        disabled={saving}
                                        className="inline-flex w-full justify-center rounded-md bg-indigo-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600 sm:col-start-2"
                                    >
                                        {saving ? <Loader2 className="animate-spin h-5 w-5" /> : 'Save'}
                                    </button>
                                    <button
                                        type="button"
                                        onClick={() => setIsModalOpen(false)}
                                        className="mt-3 inline-flex w-full justify-center rounded-md bg-white px-3 py-2 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50 sm:col-start-1 sm:mt-0"
                                    >
                                        Cancel
                                    </button>
                                </div>
                            </form>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
}
