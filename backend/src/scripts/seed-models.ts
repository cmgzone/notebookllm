import pool from '../config/database.js';

async function seedModels() {
    const client = await pool.connect();
    try {
        console.log('🔧 Seeding AI models...');

        // Insert default AI models
        await client.query(`
            INSERT INTO ai_models (name, model_id, provider, description, context_window, is_active, is_premium) 
            VALUES 
                ('Gemini 2.0 Flash', 'gemini-2.0-flash', 'gemini', 'Latest fast model for quick tasks', 1000000, true, false),
                ('Gemini 2.5 Flash', 'gemini-2.5-flash', 'gemini', 'Advanced flash model with improved capabilities', 1000000, true, false),
                ('Gemini 2.5 Pro', 'gemini-2.5-pro', 'gemini', 'Most capable Gemini model for complex tasks', 2000000, true, true),
                ('Gemini 2.0 Flash Lite (Free)', 'google/gemini-2.0-flash-lite-preview-02-05:free', 'openrouter', 'Fast and free Google model via OpenRouter', 1000000, true, false),
                ('Amazon Nova Lite', 'amazon/nova-2-lite-v1:free', 'openrouter', 'Free Amazon Nova model', 128000, true, false),
                ('Llama 3.3 70B', 'meta-llama/llama-3.3-70b-instruct', 'openrouter', 'Powerful open-source model', 128000, true, false),
                ('Claude 3.5 Sonnet', 'anthropic/claude-3.5-sonnet', 'openrouter', 'Excellent for analysis and writing', 200000, true, true),
                ('GPT-4o Mini', 'openai/gpt-4o-mini', 'openrouter', 'Fast and affordable GPT-4 variant', 128000, true, false),
                ('DeepSeek V3', 'deepseek/deepseek-chat', 'openrouter', 'High-performance open model', 64000, true, false),
                ('Qwen 2.5 72B', 'qwen/qwen-2.5-72b-instruct', 'openrouter', 'Alibaba large language model', 128000, true, false)
            ON CONFLICT DO NOTHING
        `);

        console.log('✅ AI models seeded successfully!');
        
        // List the models
        const result = await client.query('SELECT name, model_id, provider, is_premium FROM ai_models ORDER BY provider, name');
        console.log('\nAvailable models:');
        result.rows.forEach(m => {
            console.log(`  - ${m.name} (${m.provider}) ${m.is_premium ? '[Premium]' : ''}`);
        });

    } catch (error) {
        console.error('❌ Seed error:', error);
        throw error;
    } finally {
        client.release();
        await pool.end();
    }
}

seedModels().catch(console.error);
