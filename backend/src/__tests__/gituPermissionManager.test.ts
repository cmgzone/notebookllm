/**
 * Unit Tests for Gitu Permission Manager Service
 * 
 * Tests permission CRUD operations, permission checking, scope validation,
 * and permission lifecycle management.
 */

import { describe, it, expect, beforeEach, afterEach } from '@jest/globals';
import pool from '../config/database.js';
import gituPermissionManager, {
  CreatePermissionOptions,
  CheckPermissionOptions,
  PermissionScope,
} from '../services/gituPermissionManager.js';

describe('GituPermissionManager', () => {
  const testUserId = 'test-user-perm-' + Date.now();
  let createdPermissionIds: string[] = [];

  // Create test user before all tests
  beforeEach(async () => {
    try {
      await pool.query(
        `INSERT INTO users (id, email, display_name, password_hash) 
         VALUES ($1, $2, $3, $4) 
         ON CONFLICT (id) DO NOTHING`,
        [testUserId, `test-${testUserId}@example.com`, 'Test User', 'dummy-hash']
      );
    } catch (error) {
      // Ignore if user already exists
    }
  });

  // Clean up after each test
  afterEach(async () => {
    // Clean up permissions
    try {
      await pool.query(`DELETE FROM gitu_permissions WHERE user_id = $1`, [testUserId]);
    } catch (error) {
      // Ignore errors
    }
    
    // Clean up test user
    try {
      await pool.query(`DELETE FROM users WHERE id = $1`, [testUserId]);
    } catch (error) {
      // Ignore errors
    }
    
    createdPermissionIds = [];
  });

  describe('grantPermission', () => {
    it('should grant a basic permission', async () => {
      const options: CreatePermissionOptions = {
        resource: 'gmail',
        actions: ['read', 'write'],
      };

      const permission = await gituPermissionManager.grantPermission(testUserId, options);
      createdPermissionIds.push(permission.id);

      expect(permission.userId).toBe(testUserId);
      expect(permission.resource).toBe('gmail');
      expect(permission.actions).toEqual(['read', 'write']);
      expect(permission.grantedAt).toBeInstanceOf(Date);
      expect(permission.expiresAt).toBeInstanceOf(Date);
    });

    it('should grant a permission with scope', async () => {
      const scope: PermissionScope = {
        allowedPaths: ['/home/user/documents'],
        notebookIds: ['notebook-1', 'notebook-2'],
      };

      const options: CreatePermissionOptions = {
        resource: 'files',
        actions: ['read'],
        scope,
      };

      const permission = await gituPermissionManager.grantPermission(testUserId, options);
      createdPermissionIds.push(permission.id);

      expect(permission.scope).toEqual(scope);
      expect(permission.resource).toBe('files');
    });

    it('should reject invalid resource', async () => {
      const options: CreatePermissionOptions = {
        resource: 'invalid-resource',
        actions: ['read'],
      };

      await expect(
        gituPermissionManager.grantPermission(testUserId, options)
      ).rejects.toThrow('Invalid resource');
    });

    it('should reject invalid action', async () => {
      const options: CreatePermissionOptions = {
        resource: 'gmail',
        actions: ['invalid-action' as any],
      };

      await expect(
        gituPermissionManager.grantPermission(testUserId, options)
      ).rejects.toThrow('Invalid action');
    });
  });

  describe('checkPermission', () => {
    it('should return true for valid permission', async () => {
      // Grant permission first
      const options: CreatePermissionOptions = {
        resource: 'gmail',
        actions: ['read', 'write'],
      };
      const permission = await gituPermissionManager.grantPermission(testUserId, options);
      createdPermissionIds.push(permission.id);

      // Check permission
      const checkOptions: CheckPermissionOptions = {
        resource: 'gmail',
        action: 'read',
      };

      const hasPermission = await gituPermissionManager.checkPermission(testUserId, checkOptions);
      expect(hasPermission).toBe(true);
    });

    it('should return false for missing action', async () => {
      // Grant permission with only read
      const options: CreatePermissionOptions = {
        resource: 'gmail',
        actions: ['read'],
      };
      const permission = await gituPermissionManager.grantPermission(testUserId, options);
      createdPermissionIds.push(permission.id);

      // Check for delete action
      const checkOptions: CheckPermissionOptions = {
        resource: 'gmail',
        action: 'delete',
      };

      const hasPermission = await gituPermissionManager.checkPermission(testUserId, checkOptions);
      expect(hasPermission).toBe(false);
    });

    it('should check file path scope', async () => {
      const scope: PermissionScope = {
        allowedPaths: ['/home/user/documents', '/home/user/projects'],
      };

      const options: CreatePermissionOptions = {
        resource: 'files',
        actions: ['read'],
        scope,
      };
      const permission = await gituPermissionManager.grantPermission(testUserId, options);
      createdPermissionIds.push(permission.id);

      // Test allowed path
      const checkOptions1: CheckPermissionOptions = {
        resource: 'files',
        action: 'read',
        scope: { path: '/home/user/documents/file.txt' },
      };
      const hasPermission1 = await gituPermissionManager.checkPermission(testUserId, checkOptions1);
      expect(hasPermission1).toBe(true);

      // Test denied path
      const checkOptions2: CheckPermissionOptions = {
        resource: 'files',
        action: 'read',
        scope: { path: '/etc/passwd' },
      };
      const hasPermission2 = await gituPermissionManager.checkPermission(testUserId, checkOptions2);
      expect(hasPermission2).toBe(false);
    });

    it('should not allow prefix collisions in file path scope', async () => {
      const scope: PermissionScope = {
        allowedPaths: ['/home/user/documents'],
      };

      const permission = await gituPermissionManager.grantPermission(testUserId, {
        resource: 'files',
        actions: ['read'],
        scope,
      });
      createdPermissionIds.push(permission.id);

      const hasPermission = await gituPermissionManager.checkPermission(testUserId, {
        resource: 'files',
        action: 'read',
        scope: { path: '/home/user/documents2/file.txt' },
      });
      expect(hasPermission).toBe(false);
    });
  });

  describe('revokePermission', () => {
    it('should revoke a permission', async () => {
      // Grant permission first
      const options: CreatePermissionOptions = {
        resource: 'gmail',
        actions: ['read'],
      };
      const permission = await gituPermissionManager.grantPermission(testUserId, options);

      // Revoke it
      await gituPermissionManager.revokePermission(testUserId, permission.id);

      // Check it's revoked
      const checkOptions: CheckPermissionOptions = {
        resource: 'gmail',
        action: 'read',
      };
      const hasPermission = await gituPermissionManager.checkPermission(testUserId, checkOptions);
      expect(hasPermission).toBe(false);
    });
  });

  describe('listPermissions', () => {
    it('should list all permissions for a user', async () => {
      // Grant multiple permissions
      await gituPermissionManager.grantPermission(testUserId, {
        resource: 'gmail',
        actions: ['read'],
      });
      await gituPermissionManager.grantPermission(testUserId, {
        resource: 'files',
        actions: ['read', 'write'],
      });

      const permissions = await gituPermissionManager.listPermissions(testUserId);

      expect(permissions.length).toBeGreaterThanOrEqual(2);
      expect(permissions.some(p => p.resource === 'gmail')).toBe(true);
      expect(permissions.some(p => p.resource === 'files')).toBe(true);
    });
  });

  describe('getPermissionStats', () => {
    it('should return permission statistics', async () => {
      // Grant some permissions
      await gituPermissionManager.grantPermission(testUserId, {
        resource: 'gmail',
        actions: ['read'],
      });
      await gituPermissionManager.grantPermission(testUserId, {
        resource: 'files',
        actions: ['read'],
      });

      const stats = await gituPermissionManager.getPermissionStats(testUserId);

      expect(stats.totalPermissions).toBeGreaterThanOrEqual(2);
      expect(stats.activePermissions).toBeGreaterThanOrEqual(2);
      expect(stats.byResource).toHaveProperty('gmail');
      expect(stats.byResource).toHaveProperty('files');
    });
  });

  describe('hasAnyPermission', () => {
    it('should return true if user has active permissions', async () => {
      await gituPermissionManager.grantPermission(testUserId, {
        resource: 'gmail',
        actions: ['read'],
      });

      const hasPermission = await gituPermissionManager.hasAnyPermission(testUserId, 'gmail');
      expect(hasPermission).toBe(true);
    });

    it('should return false if user has no active permissions', async () => {
      const hasPermission = await gituPermissionManager.hasAnyPermission(testUserId, 'gmail');
      expect(hasPermission).toBe(false);
    });
  });

  describe('getAuthorizedResources', () => {
    it('should return list of authorized resources', async () => {
      await gituPermissionManager.grantPermission(testUserId, {
        resource: 'gmail',
        actions: ['read'],
      });
      await gituPermissionManager.grantPermission(testUserId, {
        resource: 'files',
        actions: ['read'],
      });

      const resources = await gituPermissionManager.getAuthorizedResources(testUserId);

      expect(resources).toContain('gmail');
      expect(resources).toContain('files');
      expect(resources.length).toBeGreaterThanOrEqual(2);
    });
  });
});
