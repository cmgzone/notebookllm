import { createClient } from 'redis';
import dotenv from 'dotenv';

dotenv.config();

// Create Redis client
const redisClient = createClient({
    url: process.env.REDIS_URL || 'redis://localhost:6379',
    socket: {
        reconnectStrategy: (retries) => {
            if (retries > 10) {
                console.error('❌ Redis: Too many reconnection attempts, giving up');
                return new Error('Too many retries');
            }
            // Exponential backoff: 50ms, 100ms, 200ms, 400ms, etc.
            const delay = Math.min(retries * 50, 3000);
            console.log(`🔄 Redis: Reconnecting in ${delay}ms (attempt ${retries})`);
            return delay;
        },
    },
});

// Error handling
redisClient.on('error', (err) => {
    console.error('❌ Redis Client Error:', err);
});

redisClient.on('connect', () => {
    console.log('🔌 Redis: Connecting...');
});

redisClient.on('ready', () => {
    console.log('✅ Redis: Connected and ready');
});

redisClient.on('reconnecting', () => {
    console.log('🔄 Redis: Reconnecting...');
});

redisClient.on('end', () => {
    console.log('🔌 Redis: Connection closed');
});

// Connect to Redis
let isConnected = false;

export async function connectRedis() {
    if (isConnected) {
        return redisClient;
    }

    try {
        await redisClient.connect();
        isConnected = true;
        console.log('✅ Redis connected successfully');
        return redisClient;
    } catch (error: any) {
        console.error('❌ Redis connection failed:', error.message);
        console.log('⚠️  App will continue without Redis caching');
        // Don't throw - allow app to run without Redis
        return null;
    }
}

// Graceful shutdown
export async function disconnectRedis() {
    if (isConnected) {
        await redisClient.quit();
        isConnected = false;
        console.log('✅ Redis disconnected');
    }
}

// Helper function to safely execute Redis commands
export async function safeRedisCommand<T>(
    command: () => Promise<T>,
    fallback: T
): Promise<T> {
    if (!isConnected) {
        return fallback;
    }

    try {
        return await command();
    } catch (error: any) {
        console.error('Redis command error:', error.message);
        return fallback;
    }
}

export default redisClient;
