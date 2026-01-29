/**
 * Property-Based Tests for Plan Creation Completeness
 * 
 * These tests validate correctness properties using fast-check for property-based testing.
 * Each test runs with randomly generated inputs.
 * 
 * Feature: planning-mode, Property 1: Plan Creation Completeness
 * **Validates: Requirements 1.1, 4.1**
 */

import * as fc from 'fast-check';
import { v4 as uuidv4 } from 'uuid';
import pool from '../config/database.js';
import { planService, CreatePlanInput } from '../services/planService.js';

// ==================== TEST SETUP ====================

// Track created test data for cleanup
const createdUserIds: string[] = [];
const createdPlanIds: string[] = [];

// Helper to create a test user
async function createTestUser(): Promise<string> {
  const userId = uuidv4();
  const email = `test-plan-${userId}@example.com`;
  
  await pool.query(
    `INSERT INTO users (id, email, password_hash, display_name) 
     VALUES ($1, $2, 'test-hash', 'Test User')
     ON CONFLICT (id) DO NOTHING`,
    [userId, email]
  );
  
  createdUserIds.push(userId);
  return userId;
}

// Cleanup function
async function cleanup() {
  // Delete plans first (foreign key constraint)
  if (createdPlanIds.length > 0) {
    await pool.query(
      `DELETE FROM plans WHERE id = ANY($1)`,
      [createdPlanIds]
    );
  }
  
  // Delete users
  if (createdUserIds.length > 0) {
    await pool.query(
      `DELETE FROM users WHERE id = ANY($1)`,
      [createdUserIds]
    );
  }
  
  createdPlanIds.length = 0;
  createdUserIds.length = 0;
}

// ==================== ARBITRARIES ====================

// Generate valid plan titles (non-empty strings)
const planTitleArb = fc.stringOf(
  fc.constantFrom(...'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 '),
  { minLength: 1, maxLength: 100 }
).filter(s => s.trim().length > 0);

// Generate optional plan descriptions
const planDescriptionArb = fc.option(
  fc.string({ minLength: 0, maxLength: 200 }),
  { nil: undefined }
);

// Generate optional isPrivate flag
const isPrivateArb = fc.option(fc.boolean(), { nil: undefined });

// Generate complete plan creation input
const createPlanInputArb: fc.Arbitrary<CreatePlanInput> = fc.record({
  title: planTitleArb,
  description: planDescriptionArb,
  isPrivate: isPrivateArb,
});

// ==================== PROPERTY TESTS ====================

describe('Plan Service - Property-Based Tests', () => {
  afterEach(async () => {
    await cleanup();
  });

  afterAll(async () => {
    await cleanup();
    await pool.end();
  });

  /**
   * Property 1: Plan Creation Completeness
   * 
   * For any valid plan creation request with title and description, 
   * the created plan SHALL contain all required fields:
   * - id (valid UUID)
   * - userId (matches the creating user)
   * - title (matches input)
   * - description (matches input or undefined)
   * - status = 'draft'
   * - isPrivate (defaults to true if not specified)
   * - createdAt (valid timestamp)
   * - updatedAt (valid timestamp)
   * - empty tasks array (via taskSummary with total=0)
   * - empty requirements array
   * - empty design notes array
   * 
   * **Validates: Requirements 1.1, 4.1**
   */
  describe('Property 1: Plan Creation Completeness', () => {
    it('created plan contains all required fields and spec structure', async () => {
      await fc.assert(
        fc.asyncProperty(
          createPlanInputArb,
          async (input) => {
            // Create a test user
            const userId = await createTestUser();
            
            // Create the plan
            const plan = await planService.createPlan(userId, input);
            createdPlanIds.push(plan.id);
            
            // ===== VERIFY REQUIRED FIELDS (Requirement 1.1) =====
            
            // Verify id is a valid UUID
            expect(plan.id).toBeDefined();
            expect(typeof plan.id).toBe('string');
            expect(plan.id.length).toBe(36); // UUID format
            
            // Verify userId matches the creating user
            expect(plan.userId).toBe(userId);
            
            // Verify title matches input
            expect(plan.title).toBe(input.title);
            
            // Verify description matches input (or undefined if not provided)
            if (input.description !== undefined) {
              expect(plan.description).toBe(input.description);
            }
            
            // Verify status is 'draft' for new plans
            expect(plan.status).toBe('draft');
            
            // Verify isPrivate defaults to true if not specified
            const expectedIsPrivate = input.isPrivate !== undefined ? input.isPrivate : true;
            expect(plan.isPrivate).toBe(expectedIsPrivate);
            
            // Verify timestamps are valid dates
            expect(plan.createdAt).toBeInstanceOf(Date);
            expect(plan.updatedAt).toBeInstanceOf(Date);
            const now = Date.now();
            const maxClockSkewMs = 10_000;
            expect(plan.createdAt.getTime()).toBeLessThanOrEqual(now + maxClockSkewMs);
            expect(plan.updatedAt.getTime()).toBeLessThanOrEqual(now + maxClockSkewMs);
            
            // Verify completedAt is undefined for new plans
            expect(plan.completedAt).toBeUndefined();
            
            // ===== VERIFY SPEC STRUCTURE (Requirement 4.1) =====
            
            // Get plan with relations to verify spec structure
            const planWithRelations = await planService.getPlan(plan.id, userId, true);
            expect(planWithRelations).not.toBeNull();
            
            // Verify empty tasks array (taskSummary with total=0)
            expect(planWithRelations!.taskSummary).toBeDefined();
            expect(planWithRelations!.taskSummary!.total).toBe(0);
            expect(planWithRelations!.taskSummary!.notStarted).toBe(0);
            expect(planWithRelations!.taskSummary!.inProgress).toBe(0);
            expect(planWithRelations!.taskSummary!.paused).toBe(0);
            expect(planWithRelations!.taskSummary!.blocked).toBe(0);
            expect(planWithRelations!.taskSummary!.completed).toBe(0);
            
            // Verify requirements array is empty
            expect(planWithRelations!.requirements).toBeDefined();
            expect(Array.isArray(planWithRelations!.requirements)).toBe(true);
            expect(planWithRelations!.requirements!.length).toBe(0);
            
            // Verify design notes array is empty
            expect(planWithRelations!.designNotes).toBeDefined();
            expect(Array.isArray(planWithRelations!.designNotes)).toBe(true);
            expect(planWithRelations!.designNotes!.length).toBe(0);
          }
        ),
        { numRuns: 5, timeout: 30000 }
      );
    }, 60000);

    it('created plan is retrievable from database with same values', async () => {
      await fc.assert(
        fc.asyncProperty(
          createPlanInputArb,
          async (input) => {
            const userId = await createTestUser();
            
            // Create the plan
            const createdPlan = await planService.createPlan(userId, input);
            createdPlanIds.push(createdPlan.id);
            
            // Retrieve the plan from database
            const retrievedPlan = await planService.getPlan(createdPlan.id, userId);
            
            expect(retrievedPlan).not.toBeNull();
            expect(retrievedPlan!.id).toBe(createdPlan.id);
            expect(retrievedPlan!.userId).toBe(createdPlan.userId);
            expect(retrievedPlan!.title).toBe(createdPlan.title);
            expect(retrievedPlan!.description).toBe(createdPlan.description);
            expect(retrievedPlan!.status).toBe(createdPlan.status);
            expect(retrievedPlan!.isPrivate).toBe(createdPlan.isPrivate);
          }
        ),
        { numRuns: 5, timeout: 30000 }
      );
    }, 60000);
  });
});
