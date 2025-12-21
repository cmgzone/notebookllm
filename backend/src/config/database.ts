import { Pool } from 'pg';
import dotenv from 'dotenv';

dotenv.config();

const pool = new Pool({
    host: process.env.NEON_HOST,
    database: process.env.NEON_DATABASE,
    user: process.env.NEON_USERNAME,
    password: process.env.NEON_PASSWORD,
    port: parseInt(process.env.NEON_PORT || '5432'),
    ssl: {
        rejectUnauthorized: false,
    },
    max: 20, // Maximum number of clients in the pool
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 10000,
});

// Test the connection
pool.on('connect', () => {
    console.log('✅ Connected to Neon database');
});

pool.on('error', (err) => {
    console.error('❌ Unexpected error on idle client', err);
    process.exit(-1);
});

export default pool;
