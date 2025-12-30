"use client";

import React, { useEffect, useState } from "react";
import {
    BrainCircuit,
    Check,
    Zap,
    Crown,
    Rocket,
    ArrowLeft,
    Loader2
} from "lucide-react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { motion } from "framer-motion";
import { useAuth } from "@/lib/auth-context";
import api, { Subscription } from "@/lib/api";

interface Plan {
    id: string;
    name: string;
    description: string;
    credits_per_month: number;
    price: string;
    is_free_plan: boolean;
}

export default function PlansPage() {
    const { isAuthenticated, isLoading: authLoading } = useAuth();
    const router = useRouter();
    const [plans, setPlans] = useState<Plan[]>([]);
    const [currentSubscription, setCurrentSubscription] = useState<Subscription | null>(null);
    const [isLoading, setIsLoading] = useState(true);
    const [upgrading, setUpgrading] = useState<string | null>(null);

    useEffect(() => {
        if (!authLoading && !isAuthenticated) {
            router.push("/login");
            return;
        }

        if (isAuthenticated) {
            loadData();
        }
    }, [authLoading, isAuthenticated, router]);

    const loadData = async () => {
        setIsLoading(true);
        try {
            const [plansData, subData] = await Promise.all([
                api.getPlans(),
                api.getSubscription(),
            ]);
            setPlans(plansData);
            setCurrentSubscription(subData);
        } catch (error) {
            console.error("Failed to load plans:", error);
        } finally {
            setIsLoading(false);
        }
    };

    const handleUpgrade = async (planId: string, isFree: boolean) => {
        if (isFree) {
            // For downgrading to free, just show a message
            alert("To downgrade to the Free plan, please contact support or wait for your current subscription to expire.");
            return;
        }

        setUpgrading(planId);
        try {
            // Create a Stripe Checkout Session
            const { url } = await api.createCheckoutSession(planId);

            if (url) {
                // Redirect to Stripe Checkout
                window.location.href = url;
            } else {
                throw new Error("No checkout URL returned");
            }
        } catch (error: any) {
            console.error("Upgrade failed:", error);
            alert(error.message || "Failed to start checkout. Please try again.");
        } finally {
            setUpgrading(null);
        }
    };

    const getPlanIcon = (name: string) => {
        switch (name.toLowerCase()) {
            case 'pro': return <Crown className="text-blue-400" size={24} />;
            case 'ultra': return <Rocket className="text-purple-400" size={24} />;
            default: return <Zap className="text-amber-400" size={24} />;
        }
    };

    const getPlanColor = (name: string) => {
        switch (name.toLowerCase()) {
            case 'pro': return 'from-blue-600 to-blue-800';
            case 'ultra': return 'from-purple-600 to-purple-800';
            default: return 'from-neutral-700 to-neutral-800';
        }
    };

    if (authLoading || isLoading) {
        return (
            <div className="min-h-screen bg-neutral-950 flex items-center justify-center">
                <Loader2 className="animate-spin text-blue-500" size={40} />
            </div>
        );
    }

    return (
        <div className="min-h-screen bg-neutral-950 text-white">
            <nav className="border-b border-white/5 bg-neutral-900/50 backdrop-blur-xl">
                <div className="container mx-auto flex h-16 items-center justify-between px-6">
                    <Link href="/dashboard" className="flex items-center gap-2 text-neutral-400 hover:text-white transition-colors">
                        <ArrowLeft size={20} />
                        <span>Back to Dashboard</span>
                    </Link>
                    <Link href="/" className="flex items-center gap-2">
                        <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-blue-600/20 text-blue-400">
                            <BrainCircuit size={20} />
                        </div>
                        <span className="font-bold tracking-tight">NotebookLM</span>
                    </Link>
                </div>
            </nav>

            <main className="container mx-auto px-6 py-12">
                <div className="text-center mb-12">
                    <h1 className="text-4xl font-bold tracking-tight mb-4">Choose Your Plan</h1>
                    <p className="text-neutral-400 text-lg max-w-2xl mx-auto">
                        Unlock more credits and premium features to supercharge your research.
                    </p>
                </div>

                <div className="grid gap-8 md:grid-cols-3 max-w-5xl mx-auto">
                    {plans.map((plan, i) => {
                        const isCurrentPlan = currentSubscription?.plan_id === plan.id;
                        const isPremium = !plan.is_free_plan;

                        return (
                            <motion.div
                                key={plan.id}
                                initial={{ opacity: 0, y: 20 }}
                                animate={{ opacity: 1, y: 0 }}
                                transition={{ delay: i * 0.1 }}
                                className={`relative rounded-2xl border ${isCurrentPlan
                                    ? 'border-blue-500/50 ring-2 ring-blue-500/20'
                                    : 'border-white/5'
                                    } bg-neutral-900/50 p-8 backdrop-blur-sm`}
                            >
                                {isCurrentPlan && (
                                    <div className="absolute -top-3 left-1/2 -translate-x-1/2 px-3 py-1 bg-blue-500 text-xs font-bold rounded-full">
                                        Current Plan
                                    </div>
                                )}

                                <div className="flex items-center gap-3 mb-4">
                                    <div className={`p-3 rounded-xl bg-gradient-to-br ${getPlanColor(plan.name)}`}>
                                        {getPlanIcon(plan.name)}
                                    </div>
                                    <div>
                                        <h3 className="text-xl font-bold">{plan.name}</h3>
                                        <p className="text-sm text-neutral-400">{plan.description}</p>
                                    </div>
                                </div>

                                <div className="my-6">
                                    <span className="text-4xl font-bold">${parseFloat(plan.price).toFixed(2)}</span>
                                    <span className="text-neutral-400">/month</span>
                                </div>

                                <ul className="space-y-3 mb-8">
                                    <li className="flex items-center gap-2 text-sm">
                                        <Check size={16} className="text-green-400" />
                                        <span>{plan.credits_per_month.toLocaleString()} credits/month</span>
                                    </li>
                                    <li className="flex items-center gap-2 text-sm">
                                        <Check size={16} className="text-green-400" />
                                        <span>{plan.is_free_plan ? '5 notebooks' : 'Unlimited notebooks'}</span>
                                    </li>
                                    <li className="flex items-center gap-2 text-sm">
                                        <Check size={16} className="text-green-400" />
                                        <span>{plan.is_free_plan ? 'Basic support' : 'Priority support'}</span>
                                    </li>
                                    {isPremium && (
                                        <>
                                            <li className="flex items-center gap-2 text-sm">
                                                <Check size={16} className="text-green-400" />
                                                <span>Advanced AI models</span>
                                            </li>
                                            <li className="flex items-center gap-2 text-sm">
                                                <Check size={16} className="text-green-400" />
                                                <span>Unlimited Deep Research</span>
                                            </li>
                                        </>
                                    )}
                                </ul>

                                <button
                                    onClick={() => handleUpgrade(plan.id, plan.is_free_plan)}
                                    disabled={isCurrentPlan || upgrading === plan.id}
                                    className={`w-full py-3 rounded-lg font-semibold transition-all ${isCurrentPlan
                                        ? 'bg-neutral-800 text-neutral-500 cursor-not-allowed'
                                        : isPremium
                                            ? 'bg-gradient-to-r from-blue-600 to-purple-600 hover:from-blue-500 hover:to-purple-500 text-white'
                                            : 'bg-white/10 hover:bg-white/20 text-white border border-white/10'
                                        }`}
                                >
                                    {upgrading === plan.id ? (
                                        <Loader2 className="animate-spin mx-auto" size={20} />
                                    ) : isCurrentPlan ? (
                                        'Current Plan'
                                    ) : plan.is_free_plan ? (
                                        'Downgrade'
                                    ) : (
                                        'Upgrade Now'
                                    )}
                                </button>
                            </motion.div>
                        );
                    })}
                </div>

                <div className="mt-12 text-center text-neutral-500 text-sm">
                    <p>Need more credits? <Link href="/dashboard" className="text-blue-400 hover:underline">Purchase credit packs</Link> anytime.</p>
                </div>
            </main>
        </div>
    );
}
