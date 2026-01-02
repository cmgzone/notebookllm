import jwt from 'jsonwebtoken';
import pool from '../config/database.js';

const JWT_SECRET = process.env.JWT_SECRET || 'your-super-secret-jwt-key-change-in-production';

async function debugAuthFlow() {
    console.log('=== Debug Auth Flow ===\n');

    try {
        // 1. Get user cmg@gmail.com
        console.log('1. Looking up user cmg@gmail.com...');
        const userResult = await pool.query(
            'SELECT id, email, display_name FROM users WHERE email = $1',
            ['cmg@gmail.com']
        );
        
        if (userResult.rows.length === 0) {
            console.log('   User not found!');
            return;
        }
        
        const user = userResult.rows[0];
        console.log('   User found:');
        console.log(`   - ID: ${user.id}`);
        console.log(`   - Email: ${user.email}`);
        console.log(`   - Display Name: ${user.display_name}`);

        // 2. Generate a test token
        console.log('\n2. Generating test JWT token...');
        const token = jwt.sign(
            { userId: user.id, email: user.email, role: 'user' },
            JWT_SECRET,
            { expiresIn: '30d' }
        );
        console.log(`   Token (first 50 chars): ${token.substring(0, 50)}...`);

        // 3. Decode and verify the token
        console.log('\n3. Decoding token...');
        const decoded = jwt.verify(token, JWT_SECRET) as any;
        console.log('   Decoded payload:');
        console.log(`   - userId: ${decoded.userId}`);
        console.log(`   - email: ${decoded.email}`);
        console.log(`   - role: ${decoded.role}`);

        // 4. Verify the userId matches
        console.log('\n4. Verifying userId matches database...');
        const match = decoded.userId === user.id;
        console.log(`   Match: ${match ? '✅ YES' : '❌ NO'}`);

        // 5. Test the notebooks query with this userId
        console.log('\n5. Testing notebooks query with decoded userId...');
        const notebooksResult = await pool.query(
            `SELECT id, title, created_at FROM notebooks WHERE user_id = $1 ORDER BY created_at DESC`,
            [decoded.userId]
        );
        console.log(`   Found ${notebooksResult.rows.length} notebooks`);

        // 6. Check JWT_SECRET
        console.log('\n6. JWT_SECRET check...');
        const isDefaultSecret = JWT_SECRET === 'your-super-secret-jwt-key-change-in-production';
        console.log(`   Using default secret: ${isDefaultSecret ? '⚠️ YES (should change in production)' : '✅ NO (custom secret)'}`);

        console.log('\n=== Debug Complete ===');
        console.log('\nIf notebooks are not showing in the app, check:');
        console.log('1. Is the app using the same JWT_SECRET as the backend?');
        console.log('2. Is the token being stored correctly in the app?');
        console.log('3. Is the Authorization header being sent with requests?');
        console.log('4. Check the app logs for the userId being used');

    } catch (error) {
        console.error('Error:', error);
    } finally {
        await pool.end();
    }
}

debugAuthFlow();
