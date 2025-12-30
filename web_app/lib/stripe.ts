import { loadStripe } from '@stripe/stripe-js';
import api from './api';

// Get Stripe publishable key from payment config
let stripePromise: Promise<any> | null = null;

export const getStripe = async () => {
    if (!stripePromise) {
        try {
            const config = await api.getPaymentConfig();
            if (config?.stripe?.publishableKey) {
                stripePromise = loadStripe(config.stripe.publishableKey);
            }
        } catch (error) {
            console.error('Failed to load Stripe config:', error);
        }
    }
    return stripePromise;
};

export interface PaymentConfig {
    paypal: {
        configured: boolean;
        clientId: string | null;
        sandboxMode: boolean;
    };
    stripe: {
        configured: boolean;
        publishableKey: string | null;
        testMode: boolean;
    };
}

// Create a checkout session for plan upgrade
export const createCheckoutSession = async (planId: string, planName: string, price: number) => {
    // In production, this would call your backend to create a Stripe Checkout Session
    // For now, we'll use client-side redirect
    const stripe = await getStripe();
    if (!stripe) {
        throw new Error('Stripe not configured');
    }

    // This is a placeholder - in production, your backend would create the session
    // and return the session ID, then you'd call stripe.redirectToCheckout({ sessionId })
    return { stripe, planId, planName, price };
};
