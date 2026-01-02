import pool from '../config/database.js';

async function testNotebooksApi() {
    console.log('=== Testing Notebooks API ===\n');

    try {
        // 1. Check if notebooks table exists
        console.log('1. Checking notebooks table...');
        const tableCheck = await pool.query(`
            SELECT EXISTS (
                SELECT FROM information_schema.tables 
                WHERE table_name = 'notebooks'
            );
        `);
        console.log('   Notebooks table exists:', tableCheck.rows[0].exists);

        // 2. Count total notebooks
        console.log('\n2. Counting notebooks...');
        const countResult = await pool.query('SELECT COUNT(*) FROM notebooks');
        console.log('   Total notebooks:', countResult.rows[0].count);

        // 3. List all users with notebooks
        console.log('\n3. Users with notebooks:');
        const usersWithNotebooks = await pool.query(`
            SELECT u.id, u.email, COUNT(n.id) as notebook_count
            FROM users u
            LEFT JOIN notebooks n ON u.id = n.user_id
            GROUP BY u.id, u.email
            HAVING COUNT(n.id) > 0
            ORDER BY notebook_count DESC
            LIMIT 10
        `);
        usersWithNotebooks.rows.forEach(row => {
            console.log(`   - ${row.email}: ${row.notebook_count} notebooks (user_id: ${row.id})`);
        });

        // 4. Sample notebook data
        console.log('\n4. Sample notebooks:');
        const sampleNotebooks = await pool.query(`
            SELECT n.id, n.user_id, n.title, n.created_at, u.email
            FROM notebooks n
            JOIN users u ON n.user_id = u.id
            ORDER BY n.created_at DESC
            LIMIT 5
        `);
        sampleNotebooks.rows.forEach(row => {
            console.log(`   - "${row.title}" by ${row.email}`);
            console.log(`     ID: ${row.id}`);
            console.log(`     User ID: ${row.user_id}`);
        });

        // 5. Check for any user_id mismatches
        console.log('\n5. Checking for orphaned notebooks (no matching user)...');
        const orphanedNotebooks = await pool.query(`
            SELECT n.id, n.user_id, n.title
            FROM notebooks n
            LEFT JOIN users u ON n.user_id = u.id
            WHERE u.id IS NULL
        `);
        if (orphanedNotebooks.rows.length > 0) {
            console.log('   WARNING: Found orphaned notebooks:');
            orphanedNotebooks.rows.forEach(row => {
                console.log(`   - ${row.title} (user_id: ${row.user_id})`);
            });
        } else {
            console.log('   No orphaned notebooks found.');
        }

        // 6. Test the exact query used in the API
        console.log('\n6. Testing API query for a specific user...');
        const testUser = usersWithNotebooks.rows[0];
        if (testUser) {
            console.log(`   Testing with user: ${testUser.email} (${testUser.id})`);
            const apiQuery = await pool.query(
                `SELECT n.*, 
                        COALESCE(n.is_agent_notebook, false) as is_agent_notebook,
                        (SELECT COUNT(*) FROM sources WHERE notebook_id = n.id) as source_count
                 FROM notebooks n 
                 WHERE n.user_id = $1 
                 ORDER BY n.updated_at DESC`,
                [testUser.id]
            );
            console.log(`   Query returned ${apiQuery.rows.length} notebooks`);
            if (apiQuery.rows.length > 0) {
                console.log('   First notebook:', JSON.stringify(apiQuery.rows[0], null, 2));
            }
        }

        console.log('\n=== Test Complete ===');
    } catch (error) {
        console.error('Error:', error);
    } finally {
        await pool.end();
    }
}

testNotebooksApi();
