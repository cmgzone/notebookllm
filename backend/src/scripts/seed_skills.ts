
import pool from '../config/database.js';
import { v4 as uuidv4 } from 'uuid';

const skills = [
    {
        name: 'Senior Code Reviewer',
        description: 'Strict professional code review standards focusing on SOLID principles and performance.',
        content: `Act as a Senior Principal Engineer. Review the code strictly against these criteria:
1. **SOLID Principles**: Verify adherence to SRP, OCP, LSP, ISP, and DIP.
2. **Error Handling**: Ensure no empty catches; verify localized error handling and proper logging.
3. **Performance**: Identify O(n^2) loops, memory leaks, or unnecessary re-renders.
4. **Security**: Check for input validation, sanitization, and auth checks.
5. **Maintainability**: Enforce consistent naming, early returns, and avoid "magic numbers".
Output: A score (0-100), a list of critical issues, and a refactored version of the problematic code blocks.`
    },
    {
        name: 'Enterprise Unit Tests',
        description: 'Generate robust, production-grade unit tests covering edge cases.',
        content: `Generate comprehensive unit tests with the following standards:
1. **Coverage**: Target >90% branch coverage. Test happy paths, error cases, and edge cases (nulls, boundaries).
2. **Mocking**: strict mocking of all external services/repositories.
3. **Naming**: Use 'should [expected behavior] when [condition]' format.
4. **Structure**: Follow Arrange-Act-Assert pattern clearly.
For TypeScript use Jest/Vitest. For Dart use flutter_test/mockito.`
    },
    {
        name: 'Clean Architecture Enforcer',
        description: 'Ensures code adheres to strict separation of concerns and Clean Architecture.',
        content: `Analyze the implementation for Clean Architecture compliance:
1. **Dependency Rule**: Ensure Inner circles (Domain) do not depend on Outer circles (Data, UI).
2. **Entities**: Must be pure objects without framework dependencies.
3. **Use Cases**: Should contain singular business rules.
4. **Adapters**: Ensure Interfaces are defined in the Domain layer, implemented in Data layer.
Reject any code that mixes UI logic with Business logic.`
    }
];

async function seed() {
    const client = await pool.connect();
    try {
        console.log('🌱 Seeding professional skills...');

        // Get the first user (Admin)
        const userRes = await client.query('SELECT id FROM users ORDER BY created_at ASC LIMIT 1');
        if (userRes.rows.length === 0) {
            console.error('❌ No users found. Create an admin user first.');
            return;
        }
        const userId = userRes.rows[0].id;
        console.log(`👤 assigning skills to user: ${userId}`);

        for (const skill of skills) {
            // Check if exists
            const exists = await client.query(
                'SELECT id FROM agent_skills WHERE user_id = $1 AND name = $2',
                [userId, skill.name]
            );

            if (exists.rows.length === 0) {
                await client.query(
                    `INSERT INTO agent_skills (id, user_id, name, description, content, is_active)
           VALUES ($1, $2, $3, $4, $5, true)`,
                    [uuidv4(), userId, skill.name, skill.description, skill.content]
                );
                console.log(`✅ Added skill: ${skill.name}`);
            } else {
                console.log(`ℹ️ Skill already exists: ${skill.name}`);
            }
        }

        console.log('✨ Seeding complete!');
    } catch (error) {
        console.error('❌ Seeding failed:', error);
    } finally {
        client.release();
        await pool.end();
    }
}

seed();
