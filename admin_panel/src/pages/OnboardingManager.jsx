import { useState, useEffect } from 'react';
import api from '../lib/api';
import { Plus, Trash2, Edit2, Save } from 'lucide-react';

export default function OnboardingManager() {
    const [screens, setScreens] = useState([]);
    const [loading, setLoading] = useState(true);
    const [editingId, setEditingId] = useState(null);
    const [editForm, setEditForm] = useState({});

    useEffect(() => {
        fetchScreens();
    }, []);

    const fetchScreens = async () => {
        setLoading(true);
        try {
            const data = await api.getOnboardingScreens();
            setScreens(data.screens || []);
        } catch (error) {
            console.error(error);
            alert('Error fetching screens');
        } finally {
            setLoading(false);
        }
    };

    const handleEdit = (screen) => {
        setEditingId(screen.id);
        setEditForm(screen);
    };

    const handleCancel = () => {
        setEditingId(null);
        setEditForm({});
    };

    const handleSave = async () => {
        try {
            // Build updated screens array
            let updatedScreens;
            if (editingId === 'new') {
                updatedScreens = [...screens, {
                    title: editForm.title,
                    description: editForm.description,
                    imageUrl: editForm.image_url,
                    iconName: editForm.icon_name
                }];
            } else {
                updatedScreens = screens.map(s => 
                    s.id === editingId 
                        ? { ...s, title: editForm.title, description: editForm.description, imageUrl: editForm.image_url, iconName: editForm.icon_name }
                        : s
                );
            }
            await api.updateOnboardingScreens(updatedScreens);
            await fetchScreens();
            handleCancel();
        } catch (error) {
            console.error(error);
            alert('Error saving screen');
        }
    };

    const handleDelete = async (id) => {
        if (!confirm('Are you sure?')) return;
        try {
            const updatedScreens = screens.filter(s => s.id !== id);
            await api.updateOnboardingScreens(updatedScreens);
            fetchScreens();
        } catch (error) {
            console.error(error);
            alert('Error deleting');
        }
    };

    const addNew = () => {
        setEditingId('new');
        setEditForm({
            title: 'New Screen',
            description: '',
            image_url: '',
            icon_name: 'auto_awesome',
        });
    };

    if (loading) return <div>Loading...</div>;

    return (
        <div className="space-y-6">
            <div className="flex items-center justify-between">
                <h1 className="text-2xl font-bold text-gray-900">Onboarding Manager</h1>
                <button
                    onClick={addNew}
                    className="flex items-center rounded-md bg-primary px-4 py-2 text-sm font-medium text-white hover:bg-primary/90"
                >
                    <Plus className="mr-2 h-4 w-4" />
                    Add Screen
                </button>
            </div>

            <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
                {/* Edit Card (if 'new') */}
                {editingId === 'new' && (
                    <EditCard
                        form={editForm}
                        setForm={setEditForm}
                        onSave={handleSave}
                        onCancel={handleCancel}
                    />
                )}

                {/* Content Cards */}
                {screens.map((screen) => (
                    editingId === screen.id ? (
                        <EditCard
                            key={screen.id}
                            form={editForm}
                            setForm={setEditForm}
                            onSave={handleSave}
                            onCancel={handleCancel}
                        />
                    ) : (
                        <div key={screen.id} className="relative flex flex-col overflow-hidden rounded-lg border border-gray-200 bg-white shadow-sm hover:shadow-md transition-shadow">
                            <div className="aspect-video w-full bg-gray-100 relative">
                                {screen.image_url ? (
                                    <img src={screen.image_url} alt={screen.title} className="h-full w-full object-cover" />
                                ) : (
                                    <div className="flex h-full items-center justify-center text-gray-400">No Image</div>
                                )}
                                <div className="absolute top-2 right-2 rounded-full bg-white/80 p-2 text-primary shadow-sm backdrop-blur-sm">
                                    <span className="material-icons text-sm">{screen.icon_name}</span>
                                </div>
                            </div>
                            <div className="flex flex-1 flex-col p-4">
                                <h3 className="text-lg font-semibold text-gray-900">{screen.title}</h3>
                                <p className="mt-2 text-sm text-gray-500 line-clamp-2">{screen.description}</p>

                                <div className="mt-4 flex items-center justify-between border-t border-gray-100 pt-4">
                                    <span className="text-xs text-gray-400">Order: {screen.order_index}</span>
                                    <div className="flex space-x-2">
                                        <button
                                            onClick={() => handleEdit(screen)}
                                            className="rounded-md p-1.5 text-gray-500 hover:bg-gray-100 hover:text-primary"
                                        >
                                            <Edit2 className="h-4 w-4" />
                                        </button>
                                        <button
                                            onClick={() => handleDelete(screen.id)}
                                            className="rounded-md p-1.5 text-gray-500 hover:bg-red-50 hover:text-red-600"
                                        >
                                            <Trash2 className="h-4 w-4" />
                                        </button>
                                    </div>
                                </div>
                            </div>
                        </div>
                    )
                ))}
            </div>
        </div>
    );
}

function EditCard({ form, setForm, onSave, onCancel }) {
    return (
        <div className="flex flex-col rounded-lg border-2 border-primary bg-white shadow-lg p-4 space-y-4">
            <div>
                <label className="block text-xs font-medium text-gray-700">Title</label>
                <input
                    type="text"
                    className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-primary focus:ring-primary sm:text-sm p-1.5 border"
                    value={form.title}
                    onChange={e => setForm({ ...form, title: e.target.value })}
                />
            </div>
            <div>
                <label className="block text-xs font-medium text-gray-700">Description</label>
                <textarea
                    rows={2}
                    className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-primary focus:ring-primary sm:text-sm p-1.5 border"
                    value={form.description}
                    onChange={e => setForm({ ...form, description: e.target.value })}
                />
            </div>
            <div>
                <label className="block text-xs font-medium text-gray-700">Image URL</label>
                <input
                    type="text"
                    className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-primary focus:ring-primary sm:text-sm p-1.5 border"
                    value={form.image_url}
                    onChange={e => setForm({ ...form, image_url: e.target.value })}
                />
            </div>
            <div>
                <label className="block text-xs font-medium text-gray-700">Icon Name (Material)</label>
                <input
                    type="text"
                    className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-primary focus:ring-primary sm:text-sm p-1.5 border"
                    value={form.icon_name}
                    onChange={e => setForm({ ...form, icon_name: e.target.value })}
                />
            </div>
            <div className="flex justify-end space-x-2 pt-2">
                <button onClick={onCancel} className="px-3 py-1.5 text-sm text-gray-600 hover:bg-gray-100 rounded">Cancel</button>
                <button onClick={onSave} className="px-3 py-1.5 text-sm bg-primary text-white rounded hover:bg-primary/90 flex items-center">
                    <Save className="h-3 w-3 mr-1" /> Save
                </button>
            </div>
        </div>
    )
}
