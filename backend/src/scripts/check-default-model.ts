import pool from '../config/database.js';

async function checkDefaultModel() {
    try {
        console.log('Checking default AI model...\n');
        
        const result = await pool.query(`
            SELECT id, name, model_id, provider, is_default, is_active, is_premium 
            FROM ai_models 
            ORDER BY is_default DESC NULLS LAST, name 
            LIMIT 10
        `);
        
        console.log('AI Models:');
        console.log('─'.repeat(80));
        
        result.rows.forEach(model => {
            const badges: string[] = [];
            if (model.is_default) badges.push('DEFAULT');
            if (model.is_premium) badges.push('PREMIUM');
            if (!model.is_active) badges.push('INACTIVE');
            
            const badgeStr = badges.length > 0 ? ` [${badges.join(', ')}]` : '';
            console.log(`${model.name}${badgeStr}`);
            console.log(`  Model ID: ${model.model_id}`);
            console.log(`  Provider: ${model.provider}`);
            console.log('');
        });
        
        const defaultModel = result.rows.find(m => m.is_default);
        if (defaultModel) {
            console.log('✅ Default model is set:', defaultModel.name);
        } else {
            console.log('⚠️  No default model set');
        }
        
        process.exit(0);
    } catch (error) {
        console.error('Error:', error);
        process.exit(1);
    }
}

checkDefaultModel();
