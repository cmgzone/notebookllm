"use client";

import React, { useEffect, useState, Suspense } from "react";
import { CheckCircle, ArrowRight, Loader2 } from "lucide-react";
import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { motion } from "framer-motion";

function SuccessContent() {
    const searchParams = useSearchParams();
    const sessionId = searchParams.get("session_id");
    const planId = searchParams.get("plan_id");
    const [isProcessing, setIsProcessing] = useState(true);

    useEffect(() => {
        // Simulate processing time for webhook to update subscription
        const timer = setTimeout(() => {
            setIsProcessing(false);
        }, 2000);

        return () => clearTimeout(timer);
    }, []);

    return (
        <motion.div
            initial={{ opacity: 0, scale: 0.9 }}
            animate={{ opacity: 1, scale: 1 }}
            className="max-w-md w-full text-center"
        >
            {isProcessing ? (
                <div className="space-y-6">
                    <Loader2 className="animate-spin text-blue-500 mx-auto" size={60} />
                    <h1 className="text-2xl font-bold text-white">Processing your payment...</h1>
                    <p className="text-neutral-400">Please wait while we activate your subscription.</p>
                </div>
            ) : (
                <div className="space-y-6">
                    <motion.div
                        initial={{ scale: 0 }}
                        animate={{ scale: 1 }}
                        transition={{ delay: 0.2, type: "spring", stiffness: 200 }}
                    >
                        <CheckCircle className="text-green-500 mx-auto" size={80} />
                    </motion.div>

                    <h1 className="text-3xl font-bold text-white">Payment Successful!</h1>

                    <p className="text-neutral-400">
                        Your subscription has been activated. You now have access to all premium features and your credits have been added to your account.
                    </p>

                    <div className="bg-neutral-900/50 border border-white/5 rounded-xl p-6 text-left">
                        <h3 className="font-semibold text-white mb-3">What's next?</h3>
                        <ul className="space-y-2 text-sm text-neutral-400">
                            <li>✓ Your credits have been added to your account</li>
                            <li>✓ Premium features are now unlocked</li>
                            <li>✓ You'll receive a confirmation email shortly</li>
                        </ul>
                    </div>

                    <Link
                        href="/dashboard"
                        className="inline-flex items-center gap-2 bg-blue-600 hover:bg-blue-500 text-white font-semibold px-6 py-3 rounded-lg transition-colors"
                    >
                        Go to Dashboard
                        <ArrowRight size={18} />
                    </Link>
                </div>
            )}
        </motion.div>
    );
}

function LoadingFallback() {
    return (
        <div className="max-w-md w-full text-center space-y-6">
            <Loader2 className="animate-spin text-blue-500 mx-auto" size={60} />
            <h1 className="text-2xl font-bold text-white">Loading...</h1>
        </div>
    );
}

export default function SuccessPage() {
    return (
        <div className="min-h-screen bg-neutral-950 flex items-center justify-center px-4">
            <Suspense fallback={<LoadingFallback />}>
                <SuccessContent />
            </Suspense>
        </div>
    );
}
