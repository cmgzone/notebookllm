
"use client";

import React, { useState } from 'react';
import { Sparkles, X, Globe, FileText, Image as ImageIcon, Loader2 } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import api, { ResearchConfig, ResearchProgress, ResearchSource } from '../lib/api';

interface ResearchDialogProps {
    isOpen: boolean;
    onClose: () => void;
    notebookId: string;
    onComplete: (report: string, sources: ResearchSource[]) => void;
}

export default function ResearchDialog({ isOpen, onClose, notebookId, onComplete }: ResearchDialogProps) {
    const [query, setQuery] = useState("");
    const [isResearching, setIsResearching] = useState(false);
    const [progressData, setProgressData] = useState<ResearchProgress | null>(null);

    const [depth, setDepth] = useState<ResearchConfig['depth']>('standard');
    const [template, setTemplate] = useState<ResearchConfig['template']>('general');

    const handleStartResearch = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!query.trim()) return;

        setIsResearching(true);
        setProgressData({ status: "Initializing...", progress: 0, isComplete: false, sources: [], images: [] });

        try {
            await api.performResearchStream(
                query,
                { depth, template, notebookId },
                (data) => {
                    setProgressData(data);
                    if (data.isComplete && data.result) {
                        // Wait a moment before closing or allowing review
                        // For now, we auto-complete after a short delay or let user click "Done"
                    }
                }
            );
        } catch (error) {
            console.error("Research failed:", error);
            alert("Research failed to start.");
            setIsResearching(false);
        }
    };

    const handleFinish = () => {
        if (progressData?.result && progressData.sources) {
            onComplete(progressData.result, progressData.sources);
            onClose();
        }
    };

    if (!isOpen) return null;

    return (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 backdrop-blur-sm p-4">
            <motion.div
                initial={{ opacity: 0, scale: 0.95 }}
                animate={{ opacity: 1, scale: 1 }}
                exit={{ opacity: 0, scale: 0.95 }}
                className="w-full max-w-4xl bg-neutral-900 border border-white/10 rounded-2xl shadow-2xl overflow-hidden flex flex-col max-h-[90vh]"
            >
                {/* Header */}
                <div className="p-4 border-b border-white/10 flex items-center justify-between bg-neutral-800/50">
                    <div className="flex items-center gap-2 text-blue-400">
                        <Sparkles size={20} />
                        <h2 className="font-semibold text-white">Deep Research</h2>
                    </div>
                    {!isResearching && (
                        <button onClick={onClose} className="text-neutral-400 hover:text-white transition-colors">
                            <X size={20} />
                        </button>
                    )}
                </div>

                {/* Content */}
                <div className="flex-1 overflow-hidden flex flex-col">
                    {!isResearching ? (
                        <form onSubmit={handleStartResearch} className="p-8 flex flex-col gap-6">
                            <div>
                                <label className="block text-sm font-medium text-neutral-300 mb-2">
                                    What would you like to research?
                                </label>
                                <textarea
                                    value={query}
                                    onChange={(e) => setQuery(e.target.value)}
                                    placeholder="e.g., The impact of AI on healthcare in the next decade..."
                                    className="w-full h-32 bg-neutral-800 border border-white/10 rounded-xl p-4 text-white text-lg placeholder-neutral-500 focus:outline-none focus:border-blue-500/50 resize-none transition-all"
                                    autoFocus
                                />
                            </div>

                            <div className="grid grid-cols-2 gap-6">
                                <div>
                                    <label className="block text-sm font-medium text-neutral-300 mb-2">Depth</label>
                                    <div className="flex bg-neutral-800 p-1 rounded-lg">
                                        {(['quick', 'standard', 'deep'] as const).map((d) => (
                                            <button
                                                key={d}
                                                type="button"
                                                onClick={() => setDepth(d)}
                                                className={`flex-1 py-1.5 text-sm font-medium rounded-md capitalize transition-all ${depth === d ? 'bg-blue-600 text-white shadow-sm' : 'text-neutral-400 hover:text-white'
                                                    }`}
                                            >
                                                {d}
                                            </button>
                                        ))}
                                    </div>
                                </div>
                                <div>
                                    <label className="block text-sm font-medium text-neutral-300 mb-2">Report Format</label>
                                    <select
                                        value={template}
                                        onChange={(e) => setTemplate(e.target.value as any)}
                                        className="w-full bg-neutral-800 border border-white/10 rounded-lg px-3 py-2 text-white text-sm focus:outline-none focus:border-blue-500/50"
                                    >
                                        <option value="general">General Overview</option>
                                        <option value="academic">Academic Paper</option>
                                        <option value="marketAnalysis">Market Analysis</option>
                                        <option value="productComparison">Product Comparison</option>
                                    </select>
                                </div>
                            </div>

                            <div className="flex justify-end pt-4">
                                <button
                                    type="submit"
                                    disabled={!query.trim()}
                                    className="px-6 py-3 bg-blue-600 hover:bg-blue-500 text-white font-medium rounded-xl flex items-center gap-2 transition-all disabled:opacity-50 disabled:cursor-not-allowed"
                                >
                                    <Sparkles size={18} />
                                    Start Research
                                </button>
                            </div>
                        </form>
                    ) : (
                        <div className="flex flex-col h-full">
                            {/* Progress Status Area */}
                            <div className="p-6 bg-neutral-800/30 border-b border-white/5">
                                <div className="flex items-center justify-between mb-2">
                                    <span className="text-sm font-medium text-blue-400 animate-pulse">
                                        {progressData?.status || "Thinking..."}
                                    </span>
                                    <span className="text-xs text-neutral-500">
                                        {Math.round((progressData?.progress || 0) * 100)}%
                                    </span>
                                </div>
                                <div className="h-1.5 w-full bg-neutral-800 rounded-full overflow-hidden">
                                    <motion.div
                                        initial={{ width: 0 }}
                                        animate={{ width: `${(progressData?.progress || 0) * 100}%` }}
                                        className="h-full bg-gradient-to-r from-blue-500 to-purple-500"
                                    />
                                </div>
                            </div>

                            {/* Streaming Results Grid */}
                            <div className="flex-1 overflow-hidden flex flex-col md:flex-row">
                                {/* Left: Source Stream */}
                                <div className="flex-1 overflow-y-auto p-4 border-r border-white/5">
                                    <h3 className="text-xs font-bold text-neutral-500 uppercase tracking-wider mb-4 flex items-center gap-2">
                                        <Globe size={14} /> Found Sources ({progressData?.sources?.length || 0})
                                    </h3>
                                    <div className="space-y-3">
                                        <AnimatePresence>
                                            {progressData?.sources?.map((source, idx) => (
                                                <motion.div
                                                    key={idx}
                                                    initial={{ opacity: 0, y: 10 }}
                                                    animate={{ opacity: 1, y: 0 }}
                                                    className="p-3 bg-neutral-800/50 rounded-lg border border-white/5 hover:border-white/10 transition-colors"
                                                >
                                                    <div className="flex items-start gap-3">
                                                        <img
                                                            src={`https://www.google.com/s2/favicons?domain=${new URL(source.url).hostname}&sz=32`}
                                                            alt=""
                                                            className="w-4 h-4 mt-1 opacity-70"
                                                            onError={(e) => { (e.target as HTMLImageElement).src = 'data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="lucide lucide-globe"><circle cx="12" cy="12" r="10"/><path d="M12 2a14.5 14.5 0 0 0 0 20 14.5 14.5 0 0 0 0-20"/><path d="M2 12h20"/></svg>'; }}
                                                        />
                                                        <div className="min-w-0">
                                                            <h4 className="text-sm font-medium text-neutral-200 truncate">{source.title}</h4>
                                                            <a href={source.url} target="_blank" rel="noopener noreferrer" className="text-xs text-neutral-500 hover:text-blue-400 truncate block">
                                                                {new URL(source.url).hostname}
                                                            </a>
                                                        </div>
                                                        <div className={`text-xs px-1.5 py-0.5 rounded ml-auto ${source.credibility === 'academic' ? 'bg-green-900/40 text-green-400' :
                                                                source.credibility === 'news' ? 'bg-blue-900/40 text-blue-400' :
                                                                    'bg-neutral-700/40 text-neutral-400'
                                                            }`}>
                                                            {source.credibilityScore}%
                                                        </div>
                                                    </div>
                                                </motion.div>
                                            ))}
                                        </AnimatePresence>
                                        {(!progressData?.sources || progressData.sources.length === 0) && (
                                            <div className="text-center py-10 text-neutral-600 text-sm">
                                                Scanning the web...
                                            </div>
                                        )}
                                    </div>
                                </div>

                                {/* Right: Media Stream */}
                                <div className="w-full md:w-80 overflow-y-auto p-4 bg-neutral-900/50">
                                    <h3 className="text-xs font-bold text-neutral-500 uppercase tracking-wider mb-4 flex items-center gap-2">
                                        <ImageIcon size={14} /> Images ({progressData?.images?.length || 0})
                                    </h3>
                                    <div className="grid grid-cols-2 gap-2">
                                        <AnimatePresence>
                                            {progressData?.images?.map((img, idx) => (
                                                <motion.div
                                                    key={idx}
                                                    initial={{ opacity: 0, scale: 0.9 }}
                                                    animate={{ opacity: 1, scale: 1 }}
                                                    className="aspect-square rounded-lg overflow-hidden bg-neutral-800 border border-white/5 relative group"
                                                >
                                                    <img src={img} alt="" className="w-full h-full object-cover opacity-80 group-hover:opacity-100 transition-opacity" />
                                                </motion.div>
                                            ))}
                                        </AnimatePresence>
                                    </div>
                                </div>
                            </div>

                            {/* Footer Actions */}
                            {progressData?.isComplete && (
                                <div className="p-4 border-t border-white/10 bg-neutral-800/50 flex justify-end">
                                    <button
                                        onClick={handleFinish}
                                        className="px-6 py-2 bg-green-600 hover:bg-green-500 text-white font-medium rounded-lg transition-colors flex items-center gap-2"
                                    >
                                        View Report <Sparkles size={16} />
                                    </button>
                                </div>
                            )}
                        </div>
                    )}
                </div>
            </motion.div>
        </div>
    );
}
