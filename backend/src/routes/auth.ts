import express, { type Request, type Response } from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { v4 as uuidv4 } from 'uuid';
import crypto from 'crypto';
import pool from '../config/database.js';

const router = express.Router();

// Helper to get user from token (middleware-like)
const getUserFromToken = (req: Request): string | null => {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];
    if (!token) return null;
    try {
        const decoded = jwt.verify(token, process.env.JWT_SECRET!) as { userId: string };
        return decoded.userId;
    } catch {
        return null;
    }
};

// Sign up
router.post('/signup', async (req: Request, res: Response) => {
    try {
        const { email, password, displayName } = req.body;
        const normalizedEmail = email ? email.toLowerCase() : email;

        if (!email || !password) {
            return res.status(400).json({ error: 'Email and password are required' });
        }

        const existingUser = await pool.query(
            'SELECT id FROM users WHERE email = $1',
            [normalizedEmail]
        );

        if (existingUser.rows.length > 0) {
            return res.status(409).json({ error: 'User already exists' });
        }

        const salt = await bcrypt.genSalt(10);
        const passwordHash = await bcrypt.hash(password, salt);
        const userId = uuidv4();

        await pool.query(
            `INSERT INTO users (id, email, display_name, password_hash, password_salt, created_at, email_verified, two_factor_enabled) 
       VALUES ($1, $2, $3, $4, $5, NOW(), false, false)`,
            [userId, normalizedEmail, displayName || normalizedEmail.split('@')[0], passwordHash, salt]
        );

        const token = jwt.sign(
            { userId, normalizedEmail },
            process.env.JWT_SECRET!,
            { expiresIn: '30d' }
        );

        res.status(201).json({
            success: true,
            token,
            user: {
                id: userId,
                email: normalizedEmail,
                displayName: displayName || email.split('@')[0],
                emailVerified: false,
                twoFactorEnabled: false,
                avatarUrl: null
            },
        });
    } catch (error) {
        console.error('Signup error:', error);
        res.status(500).json({ error: 'Failed to create user' });
    }
});

// Login
router.post('/login', async (req: Request, res: Response) => {
    try {
        const { email, password } = req.body;

        if (!email || !password) {
            return res.status(400).json({ error: 'Email and password are required' });
        }

        const normalizedEmail = email.toLowerCase();
        console.log(`[AUTH] Attempting login for: ${normalizedEmail}`);

        const result = await pool.query(
            'SELECT id, email, display_name, password_hash, email_verified, two_factor_enabled, avatar_url FROM users WHERE email = $1',
            [normalizedEmail]
        );

        if (result.rows.length === 0) {
            console.log(`[AUTH] User not found: ${normalizedEmail}`);
            return res.status(401).json({ error: 'Invalid credentials' });
        }

        const user = result.rows[0];
        const isValid = await bcrypt.compare(password, user.password_hash);

        console.log(`[AUTH] Password valid for ${normalizedEmail}: ${isValid}`);

        if (!isValid) {
            return res.status(401).json({ error: 'Invalid credentials' });
        }

        const token = jwt.sign(
            { userId: user.id, email: user.email },
            process.env.JWT_SECRET!,
            { expiresIn: '30d' }
        );

        res.json({
            success: true,
            token,
            user: {
                id: user.id,
                email: user.email,
                displayName: user.display_name,
                emailVerified: user.email_verified,
                twoFactorEnabled: user.two_factor_enabled,
                avatarUrl: user.avatar_url
            },
        });
    } catch (error) {
        console.error('Login error:', error);
        res.status(500).json({ error: 'Login failed' });
    }
});

// Get current user
router.get('/me', async (req: Request, res: Response) => {
    try {
        const userId = getUserFromToken(req);
        if (!userId) {
            return res.status(401).json({ error: 'Unauthorized' });
        }

        const result = await pool.query(
            'SELECT id, email, display_name, created_at, email_verified, two_factor_enabled, avatar_url FROM users WHERE id = $1',
            [userId]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'User not found' });
        }

        const u = result.rows[0];
        res.json({
            success: true,
            user: {
                id: u.id,
                email: u.email,
                displayName: u.display_name,
                createdAt: u.created_at,
                emailVerified: u.email_verified,
                twoFactorEnabled: u.two_factor_enabled,
                avatarUrl: u.avatar_url
            }
        });
    } catch (error) {
        console.error('Get user error:', error);
        res.status(403).json({ error: 'Invalid token' });
    }
});

// Forgot Password (Request Reset)
router.post('/forgot-password', async (req: Request, res: Response) => {
    try {
        const { email } = req.body;
        if (!email) return res.status(400).json({ error: 'Email required' });

        const userRes = await pool.query('SELECT id FROM users WHERE email = $1', [email]);
        if (userRes.rows.length === 0) {
            // Pretend success to avoid enumeration
            return res.json({ success: true, message: 'If account exists, email sent.' });
        }

        const token = crypto.randomBytes(32).toString('hex');
        const expiry = new Date(Date.now() + 3600000); // 1 hour

        await pool.query(
            'UPDATE users SET reset_token = $1, reset_token_expiry = $2 WHERE email = $3',
            [token, expiry, email]
        );

        // TODO: Send email
        console.log(`[DEV] Reset token for ${email}: ${token}`);

        res.json({ success: true, message: 'Reset email sent' });
    } catch (error) {
        console.error('Forgot password error:', error);
        res.status(500).json({ error: 'Server error' });
    }
});

// Reset Password
router.post('/reset-password', async (req: Request, res: Response) => {
    try {
        const { token, newPassword } = req.body;
        if (!token || !newPassword) return res.status(400).json({ error: 'Missing fields' });

        const result = await pool.query(
            'SELECT id FROM users WHERE reset_token = $1 AND reset_token_expiry > NOW()',
            [token]
        );

        if (result.rows.length === 0) {
            return res.status(400).json({ error: 'Invalid or expired token' });
        }

        const userId = result.rows[0].id;
        const salt = await bcrypt.genSalt(10);
        const hash = await bcrypt.hash(newPassword, salt);

        await pool.query(
            'UPDATE users SET password_hash = $1, password_salt = $2, reset_token = NULL, reset_token_expiry = NULL WHERE id = $3',
            [hash, salt, userId]
        );

        res.json({ success: true, message: 'Password reset successful' });
    } catch (error) {
        console.error('Reset password error:', error);
        res.status(500).json({ error: 'Server error' });
    }
});

// Delete Account
router.post('/delete-account', async (req: Request, res: Response) => {
    try {
        const userId = getUserFromToken(req);
        if (!userId) return res.status(401).json({ error: 'Unauthorized' });

        const { password } = req.body;
        if (!password) return res.status(400).json({ error: 'Password required' });

        const userRes = await pool.query('SELECT password_hash FROM users WHERE id = $1', [userId]);
        if (userRes.rows.length === 0) return res.status(404).json({ error: 'User not found' });

        const valid = await bcrypt.compare(password, userRes.rows[0].password_hash);
        if (!valid) return res.status(401).json({ error: 'Invalid password' });

        await pool.query('DELETE FROM users WHERE id = $1', [userId]);
        res.json({ success: true, message: 'Account deleted' });
    } catch (error) {
        console.error('Delete account error:', error);
        res.status(500).json({ error: 'Server error' });
    }
});

// 2FA - Enable
router.post('/2fa/enable', async (req: Request, res: Response) => {
    try {
        const userId = getUserFromToken(req);
        if (!userId) return res.status(401).json({ error: 'Unauthorized' });

        // For this simple migration, we just flip the bit matching the Flutter stub
        await pool.query('UPDATE users SET two_factor_enabled = true WHERE id = $1', [userId]);
        res.json({ success: true, twoFactorEnabled: true });
    } catch (error) {
        res.status(500).json({ error: 'Error enabling 2FA' });
    }
});

// 2FA - Disable
router.post('/2fa/disable', async (req: Request, res: Response) => {
    try {
        const userId = getUserFromToken(req);
        if (!userId) return res.status(401).json({ error: 'Unauthorized' });

        const { password } = req.body;
        const userRes = await pool.query('SELECT password_hash FROM users WHERE id = $1', [userId]);
        const valid = await bcrypt.compare(password, userRes.rows[0].password_hash);

        if (!valid) return res.status(401).json({ error: 'Invalid password' });

        await pool.query('UPDATE users SET two_factor_enabled = false WHERE id = $1', [userId]);
        res.json({ success: true, twoFactorEnabled: false });
    } catch (error) {
        res.status(500).json({ error: 'Error disabling 2FA' });
    }
});

// 2FA - Verify (Stub - always accepts "123456" or any code if user has 2fa enabled for simple migration)
router.post('/2fa/verify', async (req: Request, res: Response) => {
    // This simple logic assumes verification after login if 2FA is on
    // Real implementation would verify TOTP
    res.json({ success: true });
});

router.post('/2fa/resend', async (req: Request, res: Response) => {
    res.json({ success: true, message: 'Code resent' });
});

// Email Verification - Resend
router.post('/resend-verification', async (req: Request, res: Response) => {
    try {
        const userId = getUserFromToken(req);
        if (!userId) return res.status(401).json({ error: 'Unauthorized' });

        const userRes = await pool.query('SELECT email FROM users WHERE id = $1', [userId]);
        if (userRes.rows.length === 0) return res.status(404).json({ error: 'User not found' });

        const email = userRes.rows[0].email;
        const token = crypto.randomBytes(32).toString('hex');

        await pool.query('UPDATE users SET verification_token = $1 WHERE id = $2', [token, userId]);

        // TODO: Send email
        console.log(`[DEV] Verification token for ${email}: ${token}`);

        res.json({ success: true, message: 'Verification email resent' });
    } catch (error) {
        console.error('Resend verification error:', error);
        res.status(500).json({ error: 'Server error' });
    }
});

// Verify Email
router.post('/verify-email', async (req: Request, res: Response) => {
    try {
        const { token } = req.body;
        if (!token) return res.status(400).json({ error: 'Token required' });

        const result = await pool.query(
            'SELECT id FROM users WHERE verification_token = $1',
            [token]
        );

        if (result.rows.length === 0) {
            return res.status(400).json({ error: 'Invalid token' });
        }

        const userId = result.rows[0].id;
        await pool.query(
            'UPDATE users SET email_verified = true, verification_token = NULL WHERE id = $1',
            [userId]
        );

        res.json({ success: true, message: 'Email verified' });
    } catch (error) {
        console.error('Verify email error:', error);
        res.status(500).json({ error: 'Server error' });
    }
});

// Update Profile
router.put('/profile', async (req: Request, res: Response) => {
    try {
        const userId = getUserFromToken(req);
        if (!userId) return res.status(401).json({ error: 'Unauthorized' });

        const { displayName, avatarUrl } = req.body;

        const updates = [];
        const params = [];
        let i = 1;

        if (displayName !== undefined) {
            updates.push(`display_name = $${i++}`);
            params.push(displayName);
        }
        if (avatarUrl !== undefined) {
            updates.push(`avatar_url = $${i++}`);
            params.push(avatarUrl);
        }

        if (updates.length === 0) {
            return res.status(400).json({ error: 'No fields to update' });
        }

        params.push(userId);
        await pool.query(
            `UPDATE users SET ${updates.join(', ')} WHERE id = $${i}`,
            params
        );

        res.json({ success: true, message: 'Profile updated' });
    } catch (error) {
        console.error('Update profile error:', error);
        res.status(500).json({ error: 'Server error' });
    }
});

// Change Password (Authenticated)
router.post('/change-password', async (req: Request, res: Response) => {
    try {
        const userId = getUserFromToken(req);
        if (!userId) return res.status(401).json({ error: 'Unauthorized' });

        const { currentPassword, newPassword } = req.body;
        if (!currentPassword || !newPassword) {
            return res.status(400).json({ error: 'Missing passwords' });
        }

        const userRes = await pool.query('SELECT password_hash FROM users WHERE id = $1', [userId]);
        if (userRes.rows.length === 0) return res.status(404).json({ error: 'User not found' });

        const valid = await bcrypt.compare(currentPassword, userRes.rows[0].password_hash);
        if (!valid) return res.status(401).json({ error: 'Invalid current password' });

        const salt = await bcrypt.genSalt(10);
        const hash = await bcrypt.hash(newPassword, salt);

        await pool.query(
            'UPDATE users SET password_hash = $1, password_salt = $2 WHERE id = $3',
            [hash, salt, userId]
        );

        res.json({ success: true, message: 'Password changed successfully' });
    } catch (error) {
        console.error('Change password error:', error);
        res.status(500).json({ error: 'Server error' });
    }
});

export default router;
