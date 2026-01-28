-- Agent Skills Migration
-- This migration adds tables for custom agent skills functionality

-- Agent Skills Table (user-specific skills)
CREATE TABLE IF NOT EXISTS agent_skills (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    content TEXT NOT NULL,
    parameters JSONB DEFAULT '{}',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, name)
);

-- Index for efficient user lookups
CREATE INDEX IF NOT EXISTS idx_agent_skills_user_id ON agent_skills(user_id);

-- Index for active skills
CREATE INDEX IF NOT EXISTS idx_agent_skills_active ON agent_skills(user_id, is_active);

-- Skill Catalog Table (global/shared skills)
CREATE TABLE IF NOT EXISTS skill_catalog (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
    slug TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    description TEXT,
    content TEXT NOT NULL,
    parameters JSONB DEFAULT '{}',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for catalog lookups
CREATE INDEX IF NOT EXISTS idx_skill_catalog_active_updated ON skill_catalog(is_active, updated_at DESC);

-- Index for slug lookups
CREATE INDEX IF NOT EXISTS idx_skill_catalog_slug ON skill_catalog(slug);

-- Trigger to update updated_at timestamp for agent_skills
CREATE OR REPLACE FUNCTION update_agent_skills_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER agent_skills_updated_at
    BEFORE UPDATE ON agent_skills
    FOR EACH ROW
    EXECUTE FUNCTION update_agent_skills_updated_at();

-- Trigger to update updated_at timestamp for skill_catalog
CREATE OR REPLACE FUNCTION update_skill_catalog_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER skill_catalog_updated_at
    BEFORE UPDATE ON skill_catalog
    FOR EACH ROW
    EXECUTE FUNCTION update_skill_catalog_updated_at();

-- Insert some default skills into the catalog
INSERT INTO skill_catalog (slug, name, description, content, parameters) VALUES
(
    'code-reviewer',
    'Code Reviewer',
    'Reviews code for best practices, security, and performance',
    'You are an expert code reviewer. Analyze the provided code for:
- Security vulnerabilities (SQL injection, XSS, authentication issues)
- Performance bottlenecks
- Best practices violations
- Code style and consistency
- Error handling
- Documentation quality

Provide actionable feedback with specific examples and suggestions for improvement.',
    '{"type": "object", "properties": {"code": {"type": "string"}, "language": {"type": "string"}, "focus": {"type": "string", "enum": ["security", "performance", "style", "comprehensive"]}}}'::jsonb
),
(
    'test-generator',
    'Test Generator',
    'Generates comprehensive unit tests for code',
    'You are a test generation expert. Generate comprehensive unit tests that cover:
- Happy path scenarios
- Edge cases
- Error conditions
- Boundary values
- Mock external dependencies

Use the specified testing framework (Jest, Vitest, pytest, etc.) and follow testing best practices.',
    '{"type": "object", "properties": {"code": {"type": "string"}, "language": {"type": "string"}, "framework": {"type": "string", "enum": ["jest", "vitest", "mocha", "pytest", "junit"]}}}'::jsonb
),
(
    'doc-generator',
    'Documentation Generator',
    'Generates comprehensive documentation from code',
    'You are a documentation expert. Generate clear, comprehensive documentation including:
- Function/method descriptions
- Parameter documentation with types
- Return value descriptions
- Usage examples
- Edge cases and error handling
- Integration notes

Follow the documentation style for the specified language (JSDoc, TSDoc, docstrings, etc.).',
    '{"type": "object", "properties": {"code": {"type": "string"}, "language": {"type": "string"}, "style": {"type": "string", "enum": ["jsdoc", "tsdoc", "docstring", "javadoc"]}}}'::jsonb
),
(
    'refactoring-assistant',
    'Refactoring Assistant',
    'Suggests code refactoring improvements',
    'You are a refactoring expert. Analyze code and suggest improvements for:
- Code duplication (DRY principle)
- Function/method length and complexity
- Naming conventions
- Design patterns application
- SOLID principles
- Separation of concerns

Provide specific refactoring suggestions with before/after examples.',
    '{"type": "object", "properties": {"code": {"type": "string"}, "language": {"type": "string"}, "focus": {"type": "string", "enum": ["dry", "solid", "patterns", "complexity"]}}}'::jsonb
),
(
    'api-designer',
    'API Designer',
    'Designs RESTful APIs and endpoints',
    'You are an API design expert. Design RESTful APIs following best practices:
- Resource naming conventions
- HTTP method usage (GET, POST, PUT, DELETE, PATCH)
- Status code selection
- Request/response structure
- Authentication/authorization
- Versioning strategy
- Error handling

Provide OpenAPI/Swagger specifications when applicable.',
    '{"type": "object", "properties": {"requirements": {"type": "string"}, "style": {"type": "string", "enum": ["rest", "graphql", "grpc"]}}}'::jsonb
)
ON CONFLICT (slug) DO NOTHING;
