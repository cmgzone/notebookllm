"use client";

import React, { useEffect, useState } from 'react';
import { ChevronDown, Loader2, Sparkles, Box } from 'lucide-react';
import api, { AIModelOption } from '@/lib/api';

interface ModelSelectorProps {
    selectedModel?: string;
    onSelect: (modelId: string, provider: string) => void;
    className?: string;
}

export default function ModelSelector({ selectedModel, onSelect, className = "" }: ModelSelectorProps) {
    const [models, setModels] = useState<Record<string, AIModelOption[]>>({});
    const [isLoading, setIsLoading] = useState(true);
    const [isOpen, setIsOpen] = useState(false);
    const [currentModel, setCurrentModel] = useState<AIModelOption | null>(null);

    useEffect(() => {
        loadModels();
    }, []);

    useEffect(() => {
        if (selectedModel && models) {
            const allModels = Object.values(models).flat();
            const found = allModels.find(m => m.id === selectedModel);
            if (found) setCurrentModel(found);
        }
    }, [selectedModel, models]);

    const loadModels = async () => {
        try {
            const data: any = await api.getAIModels();
            // API returns array of models, but we might receive them grouped or flat
            // Based on mobile app, it returns a map. But let's check api.ts definition.
            // api.ts getAIModels returns AIModelOption[].
            // We need to group them if they are flat.

            // Wait, looking at api.ts:
            // async getAIModels(): Promise<AIModelOption[]> { ... }
            // Let's assume it returns a flat list and we group by provider.

            const grouped: Record<string, AIModelOption[]> = {};
            if (Array.isArray(data)) {
                data.forEach((m: AIModelOption) => {
                    if (!grouped[m.provider]) grouped[m.provider] = [];
                    grouped[m.provider].push(m);
                });
            } else if (typeof data === 'object') {
                // Logic if the API returns a map like { gemini: [], openrouter: [] }
                // The mobile app code suggested it might use a map.
                // Let's handle both just in case, or default to what api.ts says.
                // api.ts says `AIModelOption[]`.
                // Note: The previous api.ts implementation returned `data.models`.

                // If it is an object
                Object.keys(data).forEach(key => {
                    if (Array.isArray(data[key])) {
                        grouped[key] = data[key];
                    }
                });
            }

            setModels(grouped);

            // Set default if none selected
            if (!selectedModel) {
                const firstProvider = Object.keys(grouped)[0];
                if (firstProvider && grouped[firstProvider].length > 0) {
                    const first = grouped[firstProvider][0];
                    onSelect(first.id, first.provider);
                    setCurrentModel(first);
                }
            }
        } catch (error) {
            console.error("Failed to load models:", error);
        } finally {
            setIsLoading(false);
        }
    };

    if (isLoading) {
        return (
            <div className={`flex items-center gap-2 px-3 py-1.5 bg-white/5 rounded-full text-xs text-neutral-400 ${className}`}>
                <Loader2 size={12} className="animate-spin" />
                <span>Loading models...</span>
            </div>
        );
    }

    return (
        <div className={`relative ${className}`}>
            <button
                onClick={() => setIsOpen(!isOpen)}
                className="flex items-center gap-2 px-3 py-1.5 bg-white/5 hover:bg-white/10 rounded-full border border-white/5 transition-colors text-xs font-medium text-neutral-200"
            >
                {currentModel ? (
                    <>
                        {currentModel.provider === 'gemini' ? (
                            <Sparkles size={12} className="text-blue-400" />
                        ) : (
                            <Box size={12} className={currentModel.isPremium ? "text-amber-400" : "text-green-400"} />
                        )}
                        <span>{currentModel.name}</span>
                        <ChevronDown size={12} className="text-neutral-500" />
                    </>
                ) : (
                    <span>Select Model</span>
                )}
            </button>

            {isOpen && (
                <>
                    <div className="fixed inset-0 z-40" onClick={() => setIsOpen(false)} />
                    <div className="absolute top-full mt-2 right-0 w-64 max-h-80 overflow-y-auto bg-neutral-900 border border-white/10 rounded-xl shadow-xl z-50 p-2">
                        {Object.entries(models).map(([provider, providerModels]) => (
                            <div key={provider} className="mb-2 last:mb-0">
                                <div className="px-2 py-1 text-[10px] font-bold text-neutral-500 uppercase tracking-wider">
                                    {provider}
                                </div>
                                {providerModels.map(model => (
                                    <button
                                        key={model.id}
                                        onClick={() => {
                                            onSelect(model.id, model.provider);
                                            setCurrentModel(model);
                                            setIsOpen(false);
                                        }}
                                        className={`w-full text-left px-2 py-2 rounded-lg flex items-center gap-2 text-xs transition-colors ${currentModel?.id === model.id ? 'bg-blue-600/20 text-blue-400' : 'hover:bg-white/5 text-neutral-300'
                                            }`}
                                    >
                                        {provider === 'gemini' ? (
                                            <Sparkles size={14} className={currentModel?.id === model.id ? "text-blue-400" : "text-neutral-500"} />
                                        ) : (
                                            <Box size={14} className={model.isPremium ? "text-amber-500" : "text-green-500"} />
                                        )}
                                        <div className="flex-1 truncate">
                                            {model.name}
                                            {model.isPremium && <span className="ml-1 text-amber-500">💎</span>}
                                        </div>
                                    </button>
                                ))}
                            </div>
                        ))}
                    </div>
                </>
            )}
        </div>
    );
}
