import { type Request, type Response, type NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import pool from '../config/database.js';

export interface AuthRequest extends Request {
    userId?: string;
    userEmail?: string;
    userRole?: string;
}

/**
 * Middleware to authenticate JWT tokens
 */
export const authenticateToken = (
    req: AuthRequest,
    res: Response,
    next: NextFunction
) => {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1]; // Bearer TOKEN

    if (!token) {
        return res.status(401).json({ error: 'Access token required' });
    }

    const jwtSecret = process.env.JWT_SECRET || 'your-super-secret-jwt-key-change-in-production';

    try {
        const decoded = jwt.verify(token, jwtSecret) as {
            userId: string;
            email: string;
            role?: string;
        };
        req.userId = decoded.userId;
        req.userEmail = decoded.email;
        if (decoded.role) req.userRole = decoded.role;
        next();
    } catch (error) {
        return res.status(403).json({ error: 'Invalid or expired token' });
    }
};

/**
 * Middleware to require admin role
 */
export const requireAdmin = async (
    req: AuthRequest,
    res: Response,
    next: NextFunction
) => {
    if (!req.userId) {
        return res.status(401).json({ error: 'Authentication required' });
    }

    try {
        const result = await pool.query(
            'SELECT role FROM users WHERE id = $1',
            [req.userId]
        );

        if (result.rows.length === 0) {
            return res.status(401).json({ error: 'User not found' });
        }

        const user = result.rows[0];
        if (user.role !== 'admin') {
            return res.status(403).json({ error: 'Admin access required' });
        }

        req.userRole = 'admin';
        next();
    } catch (error) {
        console.error('Admin check error:', error);
        res.status(500).json({ error: 'Failed to verify admin status' });
    }
};

/**
 * Optional authentication - doesn't fail if no token
 */
export const optionalAuth = (
    req: AuthRequest,
    res: Response,
    next: NextFunction
) => {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];

    if (!token) {
        return next();
    }

    const jwtSecret = process.env.JWT_SECRET || 'your-super-secret-jwt-key-change-in-production';

    try {
        const decoded = jwt.verify(token, jwtSecret) as {
            userId: string;
            email: string;
            role?: string;
        };
        req.userId = decoded.userId;
        req.userEmail = decoded.email;
        if (decoded.role) req.userRole = decoded.role;
    } catch (error) {
        // Token invalid but we continue anyway
    }
    next();
};
