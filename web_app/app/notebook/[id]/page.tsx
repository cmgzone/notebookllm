
"use client";

import React, { useEffect, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import Link from "next/link";
import {
    ArrowLeft,
    BrainCircuit,
    FileText,
    Link as LinkIcon,
    Youtube,
    Image as ImageIcon,
    MoreVertical,
    Plus,
    Loader2,
    Trash2,
    MessageSquare,
    Search,
    Sparkles
} from "lucide-react";
import { useAuth } from "@/lib/auth-context";
import ResearchDialog from "@/components/research-dialog";
import ModelSelector from "@/components/model-selector";
import api, { Notebook, Source } from "@/lib/api";

export default function NotebookDetailPage() {
    const { id } = useParams() as { id: string };
    const router = useRouter();
    const { isAuthenticated, isLoading: authLoading } = useAuth();

    const [notebook, setNotebook] = useState<Notebook | null>(null);
    const [sources, setSources] = useState<Source[]>([]);
    const [isLoading, setIsLoading] = useState(true);

    // Add Source State
    const [isAddSourceOpen, setIsAddSourceOpen] = useState(false);
    const [isResearchOpen, setIsResearchOpen] = useState(false);
    const [activeTab, setActiveTab] = useState<'url' | 'text'>('url');
    const [newSourceTitle, setNewSourceTitle] = useState("");
    const [newSourceContent, setNewSourceContent] = useState("");

    // Chat State
    const [messages, setMessages] = useState<{ role: string; content: string }[]>([]);
    const [inputMessage, setInputMessage] = useState("");
    const [isChatLoading, setIsChatLoading] = useState(false);

    // Model Selection State
    const [selectedModelId, setSelectedModelId] = useState<string>("gemini-1.5-flash"); // Default
    const [selectedProvider, setSelectedProvider] = useState<string>("gemini");

    useEffect(() => {
        if (!authLoading && !isAuthenticated) {
            router.push("/login");
            return;
        }

        if (isAuthenticated && id) {
            loadNotebookData();
        }
    }, [id, authLoading, isAuthenticated]);

    const loadNotebookData = async () => {
        try {
            const [nb, srcs] = await Promise.all([
                api.getNotebook(id),
                api.getSources(id)
            ]);
            setNotebook(nb);
            setSources(srcs);
        } catch (error) {
            console.error("Failed to load notebook:", error);
            // alert("Failed to load notebook. It may not exist.");
            // router.push("/dashboard");
        } finally {
            setIsLoading(false);
        }
    };

    const handleSendMessage = async (e?: React.FormEvent) => {
        e?.preventDefault();
        if (!inputMessage.trim() || isChatLoading) return;

        const userMsg = { role: "user", content: inputMessage };
        setMessages(prev => [...prev, userMsg]);
        setInputMessage("");
        setIsChatLoading(true);

        try {
            let chatMessages = [...messages, userMsg];

            // Construct system prompt with sources context if it's the start
            if (messages.length === 0) {
                const context = sources.map(s => `Source: ${s.title}\n${s.content || s.url || ''}`).join("\n\n");
                const systemPrompt = `You are a helpful AI assistant for this notebook. Answer questions based on the provided sources.\n\nContext:\n${context}`;
                chatMessages = [{ role: "system", content: systemPrompt }, ...chatMessages];
            }

            let aiResponse = "";
            const tempAiMsg = { role: "model", content: "" };
            setMessages(prev => [...prev, tempAiMsg]);

            await api.chatWithAIStream(
                chatMessages,
                (chunk) => {
                    aiResponse += chunk;
                    setMessages(prev => {
                        const newMsgs = [...prev];
                        newMsgs[newMsgs.length - 1] = { role: "model", content: aiResponse };
                        return newMsgs;
                    });
                },
                selectedProvider,
                selectedModelId
            );

        } catch (error) {
            console.error("Chat failed:", error);
            setMessages(prev => [...prev, { role: "model", content: "Sorry, I encountered an error answering that." }]);
        } finally {
            setIsChatLoading(false);
        }
    };

    const handleAddSource = async (e: React.FormEvent) => {
        e.preventDefault();
        try {
            const type = activeTab === 'url' ? 'url' : 'text';
            const payload: any = {
                notebookId: id,
                type,
                title: newSourceTitle,
            };

            if (type === 'url') {
                payload.url = newSourceContent;
            } else {
                payload.content = newSourceContent;
            }

            const newSource = await api.createSource(payload);
            setSources([newSource, ...sources]);
            setIsAddSourceOpen(false);
            setNewSourceTitle("");
            setNewSourceContent("");
        } catch (error) {
            alert("Failed to create source");
        }
    };

    const handleDeleteSource = async (sourceId: string) => {
        if (!confirm("Delete this source?")) return;
        try {
            await api.deleteSource(sourceId);
            setSources(sources.filter(s => s.id !== sourceId));
        } catch (error) {
            alert("Failed to delete source");
        }
    };

    const getSourceIcon = (type: string) => {
        switch (type.toLowerCase()) {
            case 'pdf': return <FileText size={20} className="text-red-400" />;
            case 'youtube': return <Youtube size={20} className="text-red-500" />;
            case 'url': return <LinkIcon size={20} className="text-blue-400" />;
            case 'image': return <ImageIcon size={20} className="text-green-400" />;
            default: return <FileText size={20} className="text-neutral-400" />;
        }
    };

    if (isLoading) {
        return (
            <div className="min-h-screen bg-neutral-950 flex items-center justify-center">
                <Loader2 className="animate-spin text-blue-500" size={40} />
            </div>
        );
    }

    if (!notebook) {
        return (
            <div className="min-h-screen bg-neutral-950 flex flex-col items-center justify-center text-white">
                <h1 className="text-2xl font-bold mb-4">Notebook not found</h1>
                <Link href="/dashboard" className="text-blue-400 hover:underline">
                    Return to Dashboard
                </Link>
            </div>
        );
    }

    return (
        <div className="min-h-screen bg-neutral-950 text-white flex flex-col md:flex-row">
            {/* Sidebar / Source List */}
            <aside className="w-full md:w-80 border-r border-white/5 bg-neutral-900/50 flex flex-col h-screen overflow-hidden sticky top-0">
                <div className="p-4 border-b border-white/5 flex items-center gap-3">
                    <Link href="/dashboard" className="text-neutral-400 hover:text-white transition-colors">
                        <ArrowLeft size={20} />
                    </Link>
                    <h1 className="font-semibold truncate flex-1">{notebook.title}</h1>
                </div>

                <div className="p-4 border-b border-white/5 space-y-2">
                    <button
                        onClick={() => setIsAddSourceOpen(true)}
                        className="w-full flex items-center justify-center gap-2 bg-blue-600 hover:bg-blue-500 text-white py-2 rounded-lg font-medium transition-colors"
                    >
                        <Plus size={18} />
                        Add Source
                    </button>
                    <button
                        onClick={() => setIsResearchOpen(true)}
                        className="w-full flex items-center justify-center gap-2 bg-purple-600 hover:bg-purple-500 text-white py-2 rounded-lg font-medium transition-colors"
                    >
                        <Sparkles size={18} />
                        Deep Research
                    </button>
                </div>

                <div className="flex-1 overflow-y-auto p-4 space-y-3">
                    <div className="text-xs font-medium text-neutral-500 uppercase tracking-wider mb-2">
                        Sources ({sources.length})
                    </div>
                    {sources.length === 0 ? (
                        <div className="text-center py-8 px-4 text-neutral-500 text-sm">
                            No sources yet. Add a PDF, URL, or Text to get started.
                        </div>
                    ) : (
                        sources.map((source) => (
                            <div key={source.id} className="group flex items-start justify-between p-3 rounded-lg hover:bg-white/5 transition-colors cursor-pointer border border-transparent hover:border-white/5">
                                <div className="flex items-start gap-3 overflow-hidden">
                                    {source.credibilityScore ? (
                                        <img
                                            src={`https://www.google.com/s2/favicons?domain=${new URL(source.url || 'https://example.com').hostname}&sz=32`}
                                            className="w-5 h-5 mt-0.5 rounded-sm opacity-80"
                                            onError={(e) => { (e.target as HTMLImageElement).src = 'data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="%239CA3AF" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><path d="M12 2a14.5 14.5 0 0 0 0 20 14.5 14.5 0 0 0 0-20"/><path d="M2 12h20"/></svg>'; }}
                                        />
                                    ) : (
                                        <div className="mt-0.5">{getSourceIcon(source.type)}</div>
                                    )}
                                    <div className="min-w-0">
                                        <h4 className="text-sm font-medium text-neutral-200 truncate pr-2">
                                            {source.title}
                                        </h4>
                                        <p className="text-xs text-neutral-500 truncate">
                                            {source.credibility ? `${source.credibility} • ` : ''}
                                            {new Date(source.createdAt).toLocaleDateString()}
                                        </p>
                                    </div>
                                </div>
                                <button
                                    onClick={(e) => { e.stopPropagation(); handleDeleteSource(source.id); }}
                                    className="opacity-0 group-hover:opacity-100 text-neutral-600 hover:text-red-400 transition-all"
                                >
                                    <Trash2 size={16} />
                                </button>
                            </div>
                        ))
                    )}
                </div>
            </aside>

            {/* Research Dialog */}
            <ResearchDialog
                isOpen={isResearchOpen}
                onClose={() => setIsResearchOpen(false)}
                notebookId={id}
                onComplete={(report, newSources) => {
                    // Refresh sources and maybe add report to chat or sources?
                    loadNotebookData();
                    // Optionally open the report in chat
                    setMessages(prev => [...prev,
                    { role: 'user', content: 'Research completed.' },
                    { role: 'model', content: report }
                    ]);
                }}
            />

            {/* Add Source Modal (existing) */}
            {isAddSourceOpen && (
                <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm p-4">
                    <div className="w-full max-w-md bg-neutral-900 border border-white/10 rounded-xl p-6 shadow-2xl">
                        <h2 className="text-xl font-bold mb-4">Add Source</h2>
                        <div className="flex gap-2 mb-6">
                            <button
                                onClick={() => setActiveTab('url')}
                                className={`flex-1 py-2 text-sm font-medium rounded-lg transition-colors ${activeTab === 'url' ? 'bg-white/10 text-white' : 'text-neutral-400 hover:text-white'}`}
                            >
                                Website URL
                            </button>
                            <button
                                onClick={() => setActiveTab('text')}
                                className={`flex-1 py-2 text-sm font-medium rounded-lg transition-colors ${activeTab === 'text' ? 'bg-white/10 text-white' : 'text-neutral-400 hover:text-white'}`}
                            >
                                Paste Text
                            </button>
                        </div>

                        <form onSubmit={handleAddSource}>
                            <div className="space-y-4">
                                <div>
                                    <label className="block text-sm font-medium text-neutral-300 mb-1">
                                        Title
                                    </label>
                                    <input
                                        type="text"
                                        required
                                        value={newSourceTitle}
                                        onChange={(e) => setNewSourceTitle(e.target.value)}
                                        className="w-full bg-neutral-800 border border-white/10 rounded-lg px-3 py-2 text-white focus:outline-none focus:border-blue-500"
                                        placeholder="Source Title"
                                    />
                                </div>

                                {activeTab === 'url' && (
                                    <div>
                                        <label className="block text-sm font-medium text-neutral-300 mb-1">
                                            URL
                                        </label>
                                        <input
                                            type="url"
                                            required
                                            value={newSourceContent}
                                            onChange={(e) => setNewSourceContent(e.target.value)}
                                            className="w-full bg-neutral-800 border border-white/10 rounded-lg px-3 py-2 text-white focus:outline-none focus:border-blue-500"
                                            placeholder="https://example.com"
                                        />
                                    </div>
                                )}

                                {activeTab === 'text' && (
                                    <div>
                                        <label className="block text-sm font-medium text-neutral-300 mb-1">
                                            Content
                                        </label>
                                        <textarea
                                            required
                                            value={newSourceContent}
                                            onChange={(e) => setNewSourceContent(e.target.value)}
                                            className="w-full h-32 bg-neutral-800 border border-white/10 rounded-lg px-3 py-2 text-white focus:outline-none focus:border-blue-500 resize-none"
                                            placeholder="Paste your text here..."
                                        />
                                    </div>
                                )}
                            </div>

                            <div className="flex justify-end gap-3 mt-6">
                                <button
                                    type="button"
                                    onClick={() => setIsAddSourceOpen(false)}
                                    className="px-4 py-2 text-sm font-medium text-neutral-400 hover:text-white transition-colors"
                                >
                                    Cancel
                                </button>
                                <button
                                    type="submit"
                                    className="px-4 py-2 text-sm font-medium bg-blue-600 hover:bg-blue-500 text-white rounded-lg transition-colors"
                                >
                                    Add Source
                                </button>
                            </div>
                        </form>
                    </div>
                </div>
            )}

            {/* Main Content / Chat Area */}
            <main className="flex-1 flex flex-col h-screen overflow-hidden relative">
                <div className="p-4 border-b border-white/5 flex items-center justify-between bg-neutral-900/30">
                    <h2 className="text-lg font-semibold flex items-center gap-2">
                        <MessageSquare size={18} className="text-blue-400" />
                        Chat with Notebook
                    </h2>
                    <ModelSelector
                        selectedModel={selectedModelId}
                        onSelect={(id, provider) => {
                            setSelectedModelId(id);
                            setSelectedProvider(provider);
                        }}
                    />
                </div>

                <div className="flex-1 overflow-y-auto p-6 scroll-smooth">
                    {
                        messages.length === 0 ? (
                            <div className="h-full flex flex-col items-center justify-center text-center max-w-md mx-auto">
                                <div className="w-16 h-16 rounded-2xl bg-gradient-to-br from-blue-500/20 to-purple-500/20 flex items-center justify-center mb-6">
                                    <BrainCircuit size={32} className="text-blue-400" />
                                </div>
                                <h2 className="text-2xl font-bold mb-3">Chat with your notebook</h2>
                                <p className="text-neutral-400 mb-8">
                                    Ask questions, get summaries, or find specific information from your {sources.length} sources.
                                </p>

                                <div className="grid grid-cols-1 gap-3 text-left w-full">
                                    <button
                                        onClick={() => { setInputMessage("Summarize these sources for me"); }}
                                        className="p-3 rounded-lg border border-white/10 hover:bg-white/5 transition-colors text-sm text-neutral-300"
                                    >
                                        "Summarize these sources for me"
                                    </button>
                                    <button
                                        onClick={() => { setInputMessage("What are the key themes?"); }}
                                        className="p-3 rounded-lg border border-white/10 hover:bg-white/5 transition-colors text-sm text-neutral-300"
                                    >
                                        "What are the key themes?"
                                    </button>
                                </div>
                            </div>
                        ) : (
                            <div className="space-y-6 max-w-3xl mx-auto">
                                {messages.filter(m => m.role !== 'system').map((msg, idx) => (
                                    <div key={idx} className={`flex gap-4 ${msg.role === 'user' ? 'justify-end' : 'justify-start'}`}>
                                        {msg.role === 'model' && (
                                            <div className="w-8 h-8 rounded-full bg-purple-500/20 flex items-center justify-center flex-shrink-0 mt-1">
                                                <BrainCircuit size={16} className="text-purple-400" />
                                            </div>
                                        )}
                                        <div className={`rounded-2xl px-5 py-3.5 max-w-[85%] text-sm leading-relaxed ${msg.role === 'user'
                                            ? 'bg-blue-600 text-white'
                                            : 'bg-neutral-800 text-neutral-200 border border-white/5'
                                            }`}>
                                            <div className="prose prose-invert prose-sm max-w-none whitespace-pre-wrap">
                                                {msg.content}
                                            </div>
                                        </div>
                                    </div>
                                ))}
                                {isChatLoading && (
                                    <div className="flex gap-4 justify-start">
                                        <div className="w-8 h-8 rounded-full bg-purple-500/20 flex items-center justify-center flex-shrink-0 mt-1">
                                            <BrainCircuit size={16} className="text-purple-400" />
                                        </div>
                                        <div className="bg-neutral-800 rounded-2xl px-5 py-3.5 border border-white/5 flex items-center gap-2">
                                            <div className="w-2 h-2 bg-neutral-500 rounded-full animate-bounce" style={{ animationDelay: '0ms' }} />
                                            <div className="w-2 h-2 bg-neutral-500 rounded-full animate-bounce" style={{ animationDelay: '150ms' }} />
                                            <div className="w-2 h-2 bg-neutral-500 rounded-full animate-bounce" style={{ animationDelay: '300ms' }} />
                                        </div>
                                    </div>
                                )}
                                <div className="h-4" /> {/* Spacer */}
                            </div>
                        )
                    }
                </div >

                {/* Chat Input */}
                < form onSubmit={handleSendMessage} className="p-4 border-t border-white/5 bg-neutral-900/30" >
                    <div className="relative max-w-3xl mx-auto">
                        <div className="absolute left-4 top-3.5 text-neutral-500">
                            <MessageSquare size={18} />
                        </div>
                        <input
                            type="text"
                            value={inputMessage}
                            onChange={(e) => setInputMessage(e.target.value)}
                            placeholder="Type a message..."
                            className="w-full bg-neutral-800/50 border border-white/10 rounded-xl py-3 pl-11 pr-12 text-white placeholder-neutral-500 focus:outline-none focus:border-blue-500/50 focus:ring-1 focus:ring-blue-500/50 transition-all"
                        />
                        <button
                            type="submit"
                            disabled={!inputMessage.trim() || isChatLoading}
                            className="absolute right-2 top-2 p-1.5 bg-blue-600 text-white rounded-lg hover:bg-blue-500 disabled:opacity-50 disabled:hover:bg-blue-600 transition-colors"
                        >
                            <ArrowLeft size={16} className="rotate-90" />
                        </button>
                    </div>
                </form >
            </main >
        </div >
    );
}
