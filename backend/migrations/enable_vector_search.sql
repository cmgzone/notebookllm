-- Migration: Enable Vector Search (pgvector)
-- Date: 2026-01-18

BEGIN;

-- Enable the pgvector extension to work with embedding vectors
CREATE EXTENSION IF NOT EXISTS vector;

-- Update chunks table to support vector embeddings
-- Chunks table might already exist, so we modify it or create if missing
CREATE TABLE IF NOT EXISTS chunks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source_id UUID NOT NULL REFERENCES sources(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  start_char INTEGER,
  end_char INTEGER,
  token_count INTEGER,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  embedding vector(768) -- using 768 dimensions (standard for many models like text-embedding-3-small or similar, Gemini is 768)
);

-- Note: Gemini embedding-001 is 768 dimensions. 
-- OpenAI text-embedding-3-small is 1536 dimensions.
-- We should stick to 768 if we are using Gemini primarily, or make it dynamic if possible, 
-- but vector columns need fixed size usually. 
-- For flexibility with mixed models, we can use 1536 and pad, or decide on a model now.
-- Let's stick to 768 for Gemini, or 1536 if we want to support stronger models later.
-- Safe bet: 1536 and we can zero-pad if needed, or better, 768 since we are Gemini-native.
-- Let's check what model the app uses. Usually "embedding-001" (Gecko) -> 768 dimensions.
-- "text-embedding-004" -> 768 dimensions.
-- So 768 is the correct choice for Google ecosystem.

-- Add vector index for faster similarity search
-- Using IVFFlat for better performance on large datasets
CREATE INDEX IF NOT EXISTS idx_chunks_embedding ON chunks USING ivfflat (embedding vector_cosine_ops)
WITH (lists = 100);

-- Also add index on source_id for faster lookups
CREATE INDEX IF NOT EXISTS idx_chunks_source_id ON chunks(source_id);

COMMIT;
