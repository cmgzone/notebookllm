export default async function globalTeardown() {
  try {
    const pool = globalThis.__notebookLlmPgPool;
    if (pool && typeof pool.end === 'function') {
      await pool.end();
    }
  } catch {}
}

