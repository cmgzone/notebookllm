-- Add Shopify Connections table
CREATE TABLE IF NOT EXISTS shopify_connections (
  user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  store_domain TEXT NOT NULL,
  access_token TEXT NOT NULL,
  shop_name TEXT,
  shop_email TEXT,
  shop_plan TEXT,
  api_version TEXT DEFAULT '2024-10',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_shopify_connections_user ON shopify_connections(user_id);
