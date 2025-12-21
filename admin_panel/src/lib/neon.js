import { neon as neonClient } from '@neondatabase/serverless';

const NEON_HOST = import.meta.env.VITE_NEON_HOST;
const NEON_DATABASE = import.meta.env.VITE_NEON_DATABASE;
const NEON_USERNAME = import.meta.env.VITE_NEON_USERNAME;
const NEON_PASSWORD = import.meta.env.VITE_NEON_PASSWORD;

// Build connection string for Neon
const connectionString = `postgres://${NEON_USERNAME}:${NEON_PASSWORD}@${NEON_HOST}/${NEON_DATABASE}?sslmode=require`;

// Create SQL function using Neon's HTTP API
const sql = neonClient(connectionString);

export const neon = {
    async query(queryText, params = []) {
        try {
            let result;

            if (params.length > 0) {
                // Use sql.query() for parameterized queries with $1, $2, etc.
                result = await sql.query(queryText, params);
            } else {
                // For queries without parameters, we need to use a workaround
                // We'll add a dummy parameter to make it work with sql.query
                // Or we can use the fact that sql.query works with empty array
                result = await sql.query(queryText, []);
            }

            return result;
        } catch (error) {
            console.error('Neon Query Error:', error);
            console.error('Query:', queryText);
            console.error('Params:', params);
            throw error;
        }
    },

    async execute(queryText, params = []) {
        return this.query(queryText, params);
    }
};
