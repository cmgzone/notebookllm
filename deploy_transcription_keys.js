// Deploy Transcription API Keys to Neon Database
const { Client } = require('pg');

async function deployKeys() {
  const databaseUrl = process.env.DATABASE_URL;
  const deepgramKey = process.env.DEEPGRAM_API_KEY;
  const assemblyAiKey = process.env.ASSEMBLYAI_API_KEY;

  if (!databaseUrl) {
    console.error('Missing DATABASE_URL environment variable');
    process.exitCode = 1;
    return;
  }

  if (!deepgramKey || !assemblyAiKey) {
    console.error('Missing DEEPGRAM_API_KEY and/or ASSEMBLYAI_API_KEY environment variables');
    process.exitCode = 1;
    return;
  }

  const client = new Client({
    connectionString: databaseUrl,
    ssl: { rejectUnauthorized: false },
  });

  try {
    await client.connect();
    console.log('Connected to Neon database');

    // Ensure api_keys table exists
    await client.query(`
      CREATE TABLE IF NOT EXISTS api_keys (
        service_name TEXT PRIMARY KEY,
        encrypted_value TEXT NOT NULL,
        description TEXT,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);
    console.log('Table api_keys ready');

    // Insert Deepgram key
    await client.query(`
      INSERT INTO api_keys (service_name, encrypted_value, description, updated_at)
      VALUES ('deepgram', $1, 'Deepgram Real-time Transcription API', CURRENT_TIMESTAMP)
      ON CONFLICT (service_name) 
      DO UPDATE SET encrypted_value = EXCLUDED.encrypted_value, updated_at = CURRENT_TIMESTAMP
    `, [deepgramKey]);
    console.log('✓ Deepgram API key deployed');

    // Insert AssemblyAI key
    await client.query(`
      INSERT INTO api_keys (service_name, encrypted_value, description, updated_at)
      VALUES ('assemblyai', $1, 'AssemblyAI Transcription API', CURRENT_TIMESTAMP)
      ON CONFLICT (service_name) 
      DO UPDATE SET encrypted_value = EXCLUDED.encrypted_value, updated_at = CURRENT_TIMESTAMP
    `, [assemblyAiKey]);
    console.log('✓ AssemblyAI API key deployed');

    // Verify
    const result = await client.query(`
      SELECT service_name, description, updated_at 
      FROM api_keys 
      WHERE service_name IN ('deepgram', 'assemblyai')
    `);
    console.log('\nDeployed keys:');
    result.rows.forEach(row => {
      console.log(`  - ${row.service_name}: ${row.description} (${row.updated_at})`);
    });

    console.log('\n✅ All transcription API keys deployed successfully!');
  } catch (error) {
    console.error('Error:', error.message);
  } finally {
    await client.end();
  }
}

deployKeys();
