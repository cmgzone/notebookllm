import pool from '../config/database.js';

async function seedVoices() {
    const client = await pool.connect();
    try {
        console.log('🔧 Creating voice_models table...');

        // Create voice_models table
        await client.query(`
            CREATE TABLE IF NOT EXISTS voice_models (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                name TEXT NOT NULL,
                voice_id TEXT NOT NULL,
                provider TEXT NOT NULL,
                gender TEXT DEFAULT 'neutral',
                language TEXT DEFAULT 'en-US',
                description TEXT,
                is_active BOOLEAN DEFAULT true,
                is_premium BOOLEAN DEFAULT false,
                created_at TIMESTAMPTZ DEFAULT NOW(),
                updated_at TIMESTAMPTZ DEFAULT NOW(),
                UNIQUE(provider, voice_id)
            );
            CREATE INDEX IF NOT EXISTS idx_voice_models_provider ON voice_models(provider);
        `);
        console.log('✅ voice_models table created');

        console.log('🔧 Seeding voice models...');

        // ElevenLabs voices
        const elevenLabsVoices = [
            { name: 'Sarah', voice_id: 'EXAVITQu4vr4xnSDxMaL', gender: 'female', description: 'Warm and conversational' },
            { name: 'Rachel', voice_id: '21m00Tcm4TlvDq8ikWAM', gender: 'female', description: 'Clear and professional' },
            { name: 'Domi', voice_id: 'AZnzlk1XvdvUeBnXmlld', gender: 'female', description: 'Strong and confident' },
            { name: 'Bella', voice_id: 'EXAVITQu4vr4xnSDxMaL', gender: 'female', description: 'Soft and gentle' },
            { name: 'Antoni', voice_id: 'ErXwobaYiN019PkySvjV', gender: 'male', description: 'Well-rounded and versatile' },
            { name: 'Arnold', voice_id: 'VR6AewLTigWG4xSOukaG', gender: 'male', description: 'Crisp and authoritative' },
            { name: 'Adam', voice_id: 'pNInz6obpgDQGcFmaJgB', gender: 'male', description: 'Deep and narrative' },
            { name: 'Josh', voice_id: 'TxGEqnHWrfWFTfGW9XjX', gender: 'male', description: 'Young and dynamic' },
        ];

        for (const v of elevenLabsVoices) {
            await client.query(`
                INSERT INTO voice_models (name, voice_id, provider, gender, language, description, is_active, is_premium)
                VALUES ($1, $2, 'elevenlabs', $3, 'en-US', $4, true, false)
                ON CONFLICT (provider, voice_id) DO UPDATE SET name = $1, description = $4
            `, [v.name, v.voice_id, v.gender, v.description]);
        }
        console.log('✅ ElevenLabs voices added');

        // Google TTS voices
        const googleVoices = [
            { name: 'Standard Female 1', voice_id: 'en-US-Standard-A', gender: 'female', description: 'Standard quality female voice' },
            { name: 'Standard Male 1', voice_id: 'en-US-Standard-B', gender: 'male', description: 'Standard quality male voice' },
            { name: 'Standard Female 2', voice_id: 'en-US-Standard-C', gender: 'female', description: 'Standard quality female voice' },
            { name: 'Standard Male 2', voice_id: 'en-US-Standard-D', gender: 'male', description: 'Standard quality male voice' },
            { name: 'Wavenet Female', voice_id: 'en-US-Wavenet-A', gender: 'female', description: 'High quality neural voice', is_premium: true },
            { name: 'Wavenet Male', voice_id: 'en-US-Wavenet-B', gender: 'male', description: 'High quality neural voice', is_premium: true },
            { name: 'Journey Female', voice_id: 'en-US-Journey-F', gender: 'female', description: 'Ultra premium conversational', is_premium: true },
            { name: 'Journey Male', voice_id: 'en-US-Journey-D', gender: 'male', description: 'Ultra premium conversational', is_premium: true },
        ];

        for (const v of googleVoices) {
            await client.query(`
                INSERT INTO voice_models (name, voice_id, provider, gender, language, description, is_active, is_premium)
                VALUES ($1, $2, 'google', $3, 'en-US', $4, true, $5)
                ON CONFLICT (provider, voice_id) DO UPDATE SET name = $1, description = $4
            `, [v.name, v.voice_id, v.gender, v.description, v.is_premium || false]);
        }
        console.log('✅ Google TTS voices added');

        // Google Cloud TTS voices
        const googleCloudVoices = [
            { name: 'Neural2 Female', voice_id: 'en-US-Neural2-A', gender: 'female', description: 'Neural2 high quality', is_premium: true },
            { name: 'Neural2 Male', voice_id: 'en-US-Neural2-D', gender: 'male', description: 'Neural2 high quality', is_premium: true },
            { name: 'Studio Female', voice_id: 'en-US-Studio-O', gender: 'female', description: 'Studio quality voice', is_premium: true },
            { name: 'Studio Male', voice_id: 'en-US-Studio-M', gender: 'male', description: 'Studio quality voice', is_premium: true },
        ];

        for (const v of googleCloudVoices) {
            await client.query(`
                INSERT INTO voice_models (name, voice_id, provider, gender, language, description, is_active, is_premium)
                VALUES ($1, $2, 'google_cloud', $3, 'en-US', $4, true, $5)
                ON CONFLICT (provider, voice_id) DO UPDATE SET name = $1, description = $4
            `, [v.name, v.voice_id, v.gender, v.description, v.is_premium || false]);
        }
        console.log('✅ Google Cloud TTS voices added');

        // Murf voices
        const murfVoices = [
            { name: 'Natalie', voice_id: 'en-US-natalie', gender: 'female', description: 'Conversational female' },
            { name: 'Iris', voice_id: 'en-US-iris', gender: 'female', description: 'Professional female' },
            { name: 'Brianna', voice_id: 'en-US-brianna', gender: 'female', description: 'Friendly female' },
            { name: 'Hazel', voice_id: 'en-US-hazel', gender: 'female', description: 'Warm female' },
            { name: 'Miles', voice_id: 'en-US-miles', gender: 'male', description: 'Authoritative male' },
            { name: 'Michael', voice_id: 'en-US-michael', gender: 'male', description: 'Friendly male' },
            { name: 'Cooper', voice_id: 'en-US-cooper', gender: 'male', description: 'Professional male' },
            { name: 'Terrell', voice_id: 'en-US-terrell', gender: 'male', description: 'Engaging male' },
        ];

        for (const v of murfVoices) {
            await client.query(`
                INSERT INTO voice_models (name, voice_id, provider, gender, language, description, is_active, is_premium)
                VALUES ($1, $2, 'murf', $3, 'en-US', $4, true, false)
                ON CONFLICT (provider, voice_id) DO UPDATE SET name = $1, description = $4
            `, [v.name, v.voice_id, v.gender, v.description]);
        }
        console.log('✅ Murf voices added');

        // List all voices
        const result = await client.query('SELECT name, voice_id, provider, gender FROM voice_models ORDER BY provider, name');
        console.log(`\n📢 Total ${result.rows.length} voice models available:`);
        
        let currentProvider = '';
        for (const v of result.rows) {
            if (v.provider !== currentProvider) {
                currentProvider = v.provider;
                console.log(`\n  ${currentProvider.toUpperCase()}:`);
            }
            console.log(`    - ${v.name} (${v.gender})`);
        }

        console.log('\n🎉 Voice models seeded successfully!');
    } catch (error) {
        console.error('❌ Seed error:', error);
        throw error;
    } finally {
        client.release();
        await pool.end();
    }
}

seedVoices().catch(console.error);
