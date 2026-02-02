"use client";

import React, { useState } from "react";
import { BrainCircuit, Loader2, ArrowRight, AlertCircle, CheckCircle2 } from "lucide-react";
import Link from "next/link";
import api from "@/lib/api";

export default function ForgotPasswordPage() {
    const [email, setEmail] = useState("");
    const [isLoading, setIsLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [success, setSuccess] = useState<string | null>(null);

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        setError(null);
        setSuccess(null);
        setIsLoading(true);
        try {
            const res = await api.forgotPassword(email);
            setSuccess(res.message || "If an account exists, a reset email has been sent.");
        } catch (err: any) {
            setError(err.message || "Request failed. Please try again.");
        } finally {
            setIsLoading(false);
        }
    };

    return (
        <div className="min-h-screen flex items-center justify-center bg-neutral-950 px-4">
            <div className="w-full max-w-md space-y-8 rounded-2xl border border-white/5 bg-neutral-900/50 p-8 backdrop-blur-xl shadow-2xl">
                <div className="text-center">
                    <Link href="/" className="inline-flex items-center gap-2 text-blue-400 hover:text-blue-300 transition-colors">
                        <BrainCircuit size={32} />
                    </Link>
                    <h2 className="mt-6 text-3xl font-bold tracking-tight text-white">
                        Reset your password
                    </h2>
                    <p className="mt-2 text-sm text-neutral-400">
                        Enter your email and we will send a reset link if your account exists.
                    </p>
                </div>

                {error && (
                    <div className="flex items-center gap-2 rounded-lg bg-red-500/10 border border-red-500/20 p-3 text-red-400 text-sm">
                        <AlertCircle size={18} />
                        {error}
                    </div>
                )}

                {success && (
                    <div className="flex items-center gap-2 rounded-lg bg-green-500/10 border border-green-500/20 p-3 text-green-400 text-sm">
                        <CheckCircle2 size={18} />
                        {success}
                    </div>
                )}

                <form className="mt-8 space-y-6" onSubmit={handleSubmit}>
                    <div>
                        <label htmlFor="email" className="block text-sm font-medium text-neutral-200">
                            Email address
                        </label>
                        <input
                            id="email"
                            name="email"
                            type="email"
                            autoComplete="email"
                            required
                            value={email}
                            onChange={(e) => setEmail(e.target.value)}
                            className="mt-1 block w-full rounded-lg border border-white/10 bg-neutral-800/50 px-3 py-2 text-white placeholder-neutral-500 focus:border-blue-500 focus:ring-1 focus:ring-blue-500 focus:outline-none transition-all"
                            placeholder="you@example.com"
                        />
                    </div>

                    <button
                        type="submit"
                        disabled={isLoading}
                        className="group relative flex w-full justify-center rounded-lg bg-blue-600 px-4 py-2.5 text-sm font-semibold text-white hover:bg-blue-500 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 focus:ring-offset-neutral-900 disabled:opacity-50 disabled:cursor-not-allowed transition-all"
                    >
                        {isLoading ? (
                            <Loader2 className="animate-spin" size={20} />
                        ) : (
                            <span className="flex items-center gap-2">
                                Send reset link
                                <ArrowRight size={16} className="group-hover:translate-x-1 transition-transform" />
                            </span>
                        )}
                    </button>

                    <p className="text-center text-sm text-neutral-400">
                        Back to{" "}
                        <Link href="/login" className="text-blue-400 hover:text-blue-300 font-medium">
                            Sign in
                        </Link>
                    </p>
                </form>
            </div>
        </div>
    );
}

