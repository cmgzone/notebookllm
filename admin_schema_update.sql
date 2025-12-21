-- ============================================
-- ADMIN PANEL SCHEMA UPDATE
-- ============================================

-- 1. Update USERS table with ROLE
ALTER TABLE users ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'user';
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;

-- 2. Create APP_SETTINGS table
CREATE TABLE IF NOT EXISTS app_settings (
  key TEXT PRIMARY KEY,
  value TEXT,
  type TEXT DEFAULT 'string', -- string, boolean, number, json
  description TEXT,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 3. Create ONBOARDING_SCREENS table
CREATE TABLE IF NOT EXISTS onboarding_screens (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  title TEXT NOT NULL,
  description TEXT,
  image_url TEXT,
  icon_name TEXT, -- Material icon name
  sort_order INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 4. Create PRIVACY_POLICY table (for versioning)
CREATE TABLE IF NOT EXISTS privacy_policies (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  content TEXT NOT NULL,
  version TEXT,
  is_active BOOLEAN DEFAULT FALSE,
  published_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 5. Insert Default Settings
INSERT INTO app_settings (key, value, type, description) VALUES
('app_name', 'Notebook LLM', 'string', 'Application Name'),
('maintenance_mode', 'false', 'boolean', 'Enable maintenance mode'),
('android_version_min', '1.0.0', 'string', 'Minimum Android version required')
ON CONFLICT (key) DO NOTHING;

-- 6. Insert Default Onboarding Screens (matching current hardcoded ones)
INSERT INTO onboarding_screens (title, description, image_url, icon_name, sort_order) VALUES
('Welcome to Notebook AI', 'Your intelligent companion for organizing, understanding, and creating knowledge from any source.', 'https://trae-api-sg.mchost.guru/api/ide/v1/text_to_image?prompt=notebook+ai+minimalist&image_size=portrait_4_3', 'auto_awesome', 0),
('Add Your Sources', 'Upload PDFs, paste text, or add web links. Our AI will analyze and organize your content intelligently.', 'https://trae-api-sg.mchost.guru/api/ide/v1/text_to_image?prompt=upload+documents+mobile+ui&image_size=portrait_4_3', 'upload_file', 1),
('Chat with Your Knowledge', 'Ask questions about your sources and get instant, contextual answers with citations.', 'https://trae-api-sg.mchost.guru/api/ide/v1/text_to_image?prompt=chat+interface+mobile+ai&image_size=portrait_4_3', 'chat_bubble_outline', 2),
('Create Amazing Content', 'Generate study guides, briefs, FAQs, timelines, and audio overviews from your knowledge base.', 'https://trae-api-sg.mchost.guru/api/ide/v1/text_to_image?prompt=content+creation+studio&image_size=portrait_4_3', 'create', 3)
ON CONFLICT DO NOTHING;

-- 7. Insert Default Privacy Policy
INSERT INTO privacy_policies (content, version, is_active) VALUES
('# Privacy Policy\n\n**Last updated:** December 2025\n\n## 1. Introduction\nWelcome to Notebook AI. We respect your privacy.\n\n## 2. Data Collection\nWe collect the content you upload for the purpose of processing it with AI.\n\n## 3. Security\nYour data is stored securely using industry-standard encryption.', '1.0.0', TRUE);
