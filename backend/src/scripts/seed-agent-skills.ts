import { Pool } from 'pg';
import * as dotenv from 'dotenv';

dotenv.config();

async function seedAgentSkills() {
  const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : undefined
  });

  try {
    console.log('🌱 Seeding agent skills catalog...\n');

    const skills = [
      {
        slug: 'code-reviewer',
        name: 'Code Reviewer',
        description: 'Reviews code for best practices, security, and performance',
        content: `You are an expert code reviewer. Analyze the provided code for:
- Security vulnerabilities (SQL injection, XSS, authentication issues)
- Performance bottlenecks
- Best practices violations
- Code style and consistency
- Error handling
- Documentation quality

Provide actionable feedback with specific examples and suggestions for improvement.`,
        parameters: {
          type: 'object',
          properties: {
            code: { type: 'string' },
            language: { type: 'string' },
            focus: { type: 'string', enum: ['security', 'performance', 'style', 'comprehensive'] }
          }
        }
      },
      {
        slug: 'test-generator',
        name: 'Test Generator',
        description: 'Generates comprehensive unit tests for code',
        content: `You are a test generation expert. Generate comprehensive unit tests that cover:
- Happy path scenarios
- Edge cases
- Error conditions
- Boundary values
- Mock external dependencies

Use the specified testing framework (Jest, Vitest, pytest, etc.) and follow testing best practices.`,
        parameters: {
          type: 'object',
          properties: {
            code: { type: 'string' },
            language: { type: 'string' },
            framework: { type: 'string', enum: ['jest', 'vitest', 'mocha', 'pytest', 'junit'] }
          }
        }
      },
      {
        slug: 'doc-generator',
        name: 'Documentation Generator',
        description: 'Generates comprehensive documentation from code',
        content: `You are a documentation expert. Generate clear, comprehensive documentation including:
- Function/method descriptions
- Parameter documentation with types
- Return value descriptions
- Usage examples
- Edge cases and error handling
- Integration notes

Follow the documentation style for the specified language (JSDoc, TSDoc, docstrings, etc.).`,
        parameters: {
          type: 'object',
          properties: {
            code: { type: 'string' },
            language: { type: 'string' },
            style: { type: 'string', enum: ['jsdoc', 'tsdoc', 'docstring', 'javadoc'] }
          }
        }
      },
      {
        slug: 'refactoring-assistant',
        name: 'Refactoring Assistant',
        description: 'Suggests code refactoring improvements',
        content: `You are a refactoring expert. Analyze code and suggest improvements for:
- Code duplication (DRY principle)
- Function/method length and complexity
- Naming conventions
- Design patterns application
- SOLID principles
- Separation of concerns

Provide specific refactoring suggestions with before/after examples.`,
        parameters: {
          type: 'object',
          properties: {
            code: { type: 'string' },
            language: { type: 'string' },
            focus: { type: 'string', enum: ['dry', 'solid', 'patterns', 'complexity'] }
          }
        }
      },
      {
        slug: 'api-designer',
        name: 'API Designer',
        description: 'Designs RESTful APIs and endpoints',
        content: `You are an API design expert. Design RESTful APIs following best practices:
- Resource naming conventions
- HTTP method usage (GET, POST, PUT, DELETE, PATCH)
- Status code selection
- Request/response structure
- Authentication/authorization
- Versioning strategy
- Error handling

Provide OpenAPI/Swagger specifications when applicable.`,
        parameters: {
          type: 'object',
          properties: {
            requirements: { type: 'string' },
            style: { type: 'string', enum: ['rest', 'graphql', 'grpc'] }
          }
        }
      }
    ];

    for (const skill of skills) {
      const result = await pool.query(
        `INSERT INTO skill_catalog (slug, name, description, content, parameters, is_active)
         VALUES ($1, $2, $3, $4, $5, $6)
         ON CONFLICT (slug) DO UPDATE SET
           name = EXCLUDED.name,
           description = EXCLUDED.description,
           content = EXCLUDED.content,
           parameters = EXCLUDED.parameters,
           updated_at = NOW()
         RETURNING id, slug, name`,
        [skill.slug, skill.name, skill.description, skill.content, JSON.stringify(skill.parameters), true]
      );

      console.log(`✅ ${result.rows[0].slug} - ${result.rows[0].name}`);
    }

    // Verify
    const count = await pool.query('SELECT COUNT(*) FROM skill_catalog WHERE is_active = true');
    console.log(`\n📊 Total active skills in catalog: ${count.rows[0].count}`);

    console.log('\n✨ Seeding complete!');

  } catch (error) {
    console.error('❌ Seeding failed:', error);
    throw error;
  } finally {
    await pool.end();
  }
}

seedAgentSkills().catch(console.error);
