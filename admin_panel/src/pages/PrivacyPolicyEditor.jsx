import { useState, useEffect } from 'react';
import { neon } from '../lib/neon';
import { Save, Loader2, CheckCircle } from 'lucide-react';

export default function PrivacyPolicyEditor() {
    const [policy, setPolicy] = useState({ content: '', version: '' });
    const [loading, setLoading] = useState(true);
    const [saving, setSaving] = useState(false);
    const [saved, setSaved] = useState(false);

    useEffect(() => {
        fetchPolicy();
    }, []);

    const fetchPolicy = async () => {
        setLoading(true);
        try {
            // Get the active policy or the latest one
            const data = await neon.query('SELECT * FROM privacy_policies WHERE is_active = true ORDER BY published_at DESC LIMIT 1');
            if (data.length > 0) {
                setPolicy(data[0]);
            } else {
                setPolicy({ content: '', version: '1.0.0' });
            }
        } catch (error) {
            console.error(error);
        } finally {
            setLoading(false);
        }
    };

    const handleSave = async () => {
        setSaving(true);
        setSaved(false);
        try {
            // We always insert a new version for history, or we could update if it's the same version
            // For simplicity, let's just insert a new one if it's "modified" logic, but here simple UPDATE/INSERT based on ID is fine.
            // Actually, inserting new row is safer for "version history" but simpler to just UPSERT if we treat it as single DOC.
            // Let's UPDATE current if ID exists, else INSERT.

            // Wait, schema has `id` and `is_active`.
            // Let's deactivate old ones and insert new one for proper versioning.

            await neon.execute('UPDATE privacy_policies SET is_active = false');

            await neon.execute(
                `INSERT INTO privacy_policies (content, version, is_active, published_at)
                 VALUES ($1, $2, true, CURRENT_TIMESTAMP)`,
                [policy.content, policy.version || '1.0']
            );

            setSaved(true);
            setTimeout(() => setSaved(false), 3000);
        } catch (error) {
            console.error(error);
            alert('Failed to save policy');
        } finally {
            setSaving(false);
        }
    };

    if (loading) return <div>Loading...</div>;

    return (
        <div className="h-[calc(100vh-120px)] flex flex-col">
            <div className="mb-6 flex items-center justify-between">
                <div>
                    <h1 className="text-2xl font-bold text-gray-900">Privacy Policy</h1>
                    <p className="text-sm text-gray-500">Edit the application privacy policy (Markdown supported)</p>
                </div>
                <div className="flex items-center space-x-4">
                    <div className="flex items-center space-x-2">
                        <label className="text-sm font-medium text-gray-700">Version</label>
                        <input
                            type="text"
                            className="w-24 rounded-md border-gray-300 p-1.5 text-sm shadow-sm border focus:border-primary focus:ring-primary"
                            value={policy.version}
                            onChange={(e) => setPolicy({ ...policy, version: e.target.value })}
                        />
                    </div>
                    <button
                        onClick={handleSave}
                        disabled={saving}
                        className="flex items-center rounded-md bg-primary px-4 py-2 text-sm font-medium text-white hover:bg-primary/90 disabled:opacity-50"
                    >
                        {saving ? (
                            <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                        ) : saved ? (
                            <CheckCircle className="mr-2 h-4 w-4" />
                        ) : (
                            <Save className="mr-2 h-4 w-4" />
                        )}
                        {saved ? 'Saved' : 'Publish'}
                    </button>
                </div>
            </div>

            <div className="flex-1 rounded-lg border border-gray-200 bg-white shadow-sm overflow-hidden flex flex-col">
                <div className="bg-gray-50 px-4 py-2 border-b border-gray-200 flex justify-between items-center text-xs text-gray-500">
                    <span>Markdown Editor</span>
                    <span>Preview in Mobile App</span>
                </div>
                <textarea
                    className="flex-1 w-full resize-none border-0 p-4 focus:ring-0 sm:text-sm font-mono leading-relaxed"
                    placeholder="# Type your privacy policy here..."
                    value={policy.content}
                    onChange={(e) => setPolicy({ ...policy, content: e.target.value })}
                />
            </div>
        </div>
    );
}
