// Add this to backend/src/routes/auth.ts

import jwt from 'jsonwebtoken';

// Add refresh token endpoint
router.post('/refresh', async (req, res) => {
    try {
        const { refreshToken } = req.body;
        
        if (!refreshToken) {
            return res.status(400).json({ error: 'Refresh token required' });
        }

        // Verify refresh token
        const jwtSecret = process.env.JWT_SECRET || 'your-super-secret-jwt-key-change-in-production';
        const refreshSecret = process.env.JWT_REFRESH_SECRET || jwtSecret;
        
        const decoded = jwt.verify(refreshToken, refreshSecret) as {
            userId: string;
            email: string;
            role?: string;
        };
        
        // Verify user still exists
        const userResult = await pool.query(
            'SELECT id, email, role FROM users WHERE id = $1',
            [decoded.userId]
        );
        
        if (userResult.rows.length === 0) {
            return res.status(401).json({ error: 'User not found' });
        }
        
        const user = userResult.rows[0];
        
        // Generate new access token
        const newAccessToken = jwt.sign(
            { userId: user.id, email: user.email, role: user.role },
            jwtSecret,
            { expiresIn: '15m' }
        );

        console.log(`[Auth] Token refreshed for user: ${user.email}`);

        res.json({
            success: true,
            accessToken: newAccessToken,
            expiresIn: 15 * 60 // 15 minutes in seconds
        });
    } catch (error) {
        console.error('Token refresh error:', error);
        if (error.name === 'TokenExpiredError') {
            return res.status(401).json({ error: 'Refresh token expired' });
        }
        res.status(401).json({ error: 'Invalid refresh token' });
    }
});

// Update your existing login endpoint to include refresh token
// Find your login route and modify the success response:

/*
const accessToken = jwt.sign(
    { userId: user.id, email: user.email, role: user.role },
    jwtSecret,
    { expiresIn: '15m' }
);

const refreshToken = jwt.sign(
    { userId: user.id, email: user.email, role: user.role },
    process.env.JWT_REFRESH_SECRET || jwtSecret,
    { expiresIn: '30d' }
);

res.json({
    success: true,
    user: {
        id: user.id,
        email: user.email,
        display_name: user.display_name,
        email_verified: user.email_verified,
        two_factor_enabled: user.two_factor_enabled,
        avatar_url: user.avatar_url,
        created_at: user.created_at,
        role: user.role
    },
    accessToken,
    refreshToken,
    expiresIn: 15 * 60
});
*/