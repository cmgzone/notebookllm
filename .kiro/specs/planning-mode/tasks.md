# Implementation Plan: Planning Mode

## Overview

This implementation plan covers the Planning Mode feature, which enables users to create spec-driven plans and share them with coding agents via MCP. The implementation is divided into backend services, MCP tools, and Flutter app UI.

## Tasks

- [x] 1. Database Schema and Migration
  - [x] 1.1 Create migration file for planning mode tables
    - Create `backend/migrations/add_planning_mode.sql` with all 7 tables
    - Include indexes for performance
    - _Requirements: 1.1, 3.1, 4.1_
  - [x] 1.2 Create migration runner script
    - Create `backend/src/scripts/run-planning-mode-migration.ts`
    - _Requirements: 1.1_

- [x] 2. Backend Plan Service
  - [x] 2.1 Create Plan service with CRUD operations
    - Create `backend/src/services/planService.ts`
    - Implement createPlan, getPlan, listPlans, updatePlan, deletePlan, archivePlan
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5_
  - [x] 2.2 Write property test for plan creation completeness

    - **Property 1: Plan Creation Completeness**
    - **Validates: Requirements 1.1, 4.1**
  - [ ]* 2.3 Write property test for cascade deletion
    - **Property 3: Cascade Deletion**
    - **Validates: Requirements 1.4**
  - [ ]* 2.4 Write property test for archive filtering
    - **Property 4: Archive Filtering**
    - **Validates: Requirements 1.5**

- [x] 3. Backend Task Service
  - [x] 3.1 Create Task service with CRUD and status operations
    - Create `backend/src/services/planTaskService.ts`
    - Implement createTask, getTask, updateTask, deleteTask
    - Implement updateStatus, pauseTask, resumeTask, blockTask
    - Record status history on every change
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.6_
  - [ ]* 3.2 Write property test for task CRUD completeness
    - **Property 5: Task CRUD Completeness**
    - **Validates: Requirements 3.1**
  - [ ]* 3.3 Write property test for status update audit trail
    - **Property 6: Status Update Audit Trail**
    - **Validates: Requirements 3.2**
  - [ ]* 3.4 Write property test for pause/resume round trip
    - **Property 7: Pause/Resume Round Trip**
    - **Validates: Requirements 3.3, 3.4**

- [x] 4. Backend Access Control Service
  - [x] 4.1 Create Access Control service
    - Create `backend/src/services/planAccessService.ts`
    - Implement grantAccess, revokeAccess, checkAccess, listAccessiblePlans
    - _Requirements: 7.1, 7.2, 7.3, 7.4_
  - [ ]* 4.2 Write property test for access grant/revoke round trip
    - **Property 14: Access Grant/Revoke Round Trip**
    - **Validates: Requirements 7.1, 7.2**
  - [ ]* 4.3 Write property test for unauthorized access denial
    - **Property 15: Unauthorized Access Denial**
    - **Validates: Requirements 7.3**

- [x] 5. Checkpoint - Backend Services
  - Ensure all tests pass, ask the user if questions arise.

- [x] 6. Backend API Routes
  - [x] 6.1 Create Planning routes
    - Create `backend/src/routes/planning.ts`
    - Implement POST/GET/PUT/DELETE /plans endpoints
    - Implement POST/GET/PUT/DELETE /plans/:id/tasks endpoints
    - Implement POST/DELETE /plans/:id/access endpoints
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 3.1, 7.1, 7.2_
  - [x] 6.2 Register routes in main app
    - Update `backend/src/index.ts` to include planning routes
    - _Requirements: 1.1_

- [x] 7. MCP Server Extensions
  - [x] 7.1 Add planning MCP tools to existing MCP server
    - Update `backend/mcp-server/src/index.ts`
    - Add list_plans, get_plan, create_plan tools
    - Add create_task, update_task_status, add_task_output, complete_task tools
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6_
  - [ ]* 7.2 Write property test for MCP plan access control
    - **Property 11: MCP Plan Access Control**
    - **Validates: Requirements 5.1, 7.4**
  - [ ]* 7.3 Write property test for MCP task update persistence
    - **Property 12: MCP Task Update Persistence**
    - **Validates: Requirements 5.3**
  - [ ]* 7.4 Write property test for MCP task creation
    - **Property 13: MCP Task Creation**
    - **Validates: Requirements 5.4, 5.5**

- [x] 8. Checkpoint - Backend and MCP Complete
  - Ensure all tests pass, ask the user if questions arise.

- [x] 9. Flutter Data Models
  - [x] 9.1 Create Plan and Task models
    - Create `lib/features/planning/models/plan.dart` with freezed
    - Create `lib/features/planning/models/plan_task.dart` with freezed
    - Create `lib/features/planning/models/requirement.dart` with freezed
    - _Requirements: 1.1, 3.1, 4.1_

- [x] 10. Flutter Planning Service
  - [x] 10.1 Create Planning API service
    - Create `lib/features/planning/services/planning_service.dart`
    - Implement all API calls to backend
    - _Requirements: 1.1, 1.2, 1.3, 3.1_

- [x] 11. Flutter Planning Provider
  - [x] 11.1 Create Planning state provider
    - Create `lib/features/planning/planning_provider.dart`
    - Manage plans list, current plan, tasks state
    - Handle real-time updates via WebSocket
    - _Requirements: 1.2, 6.1, 6.2_

- [x] 12. Flutter Planning UI - Plans List
  - [x] 12.1 Create Plans list screen
    - Create `lib/features/planning/ui/plans_list_screen.dart`
    - Show all plans with status summary
    - Support create, archive, delete actions
    - _Requirements: 1.1, 1.2, 1.4, 1.5_

- [x] 13. Flutter Planning UI - Plan Detail
  - [x] 13.1 Create Plan detail screen
    - Create `lib/features/planning/ui/plan_detail_screen.dart`
    - Show requirements, design notes, tasks sections
    - Display progress percentage
    - _Requirements: 1.3, 4.1, 8.1_

- [x] 14. Flutter Planning UI - Task Management
  - [x] 14.1 Create Task list and detail widgets
    - Create `lib/features/planning/ui/task_list_widget.dart`
    - Create `lib/features/planning/ui/task_detail_sheet.dart`
    - Support status changes, pause/resume, blocking
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.6_

- [x] 15. Flutter Planning AI Chat
  - [x] 15.1 Create Planning AI chat screen
    - Create `lib/features/planning/ui/planning_ai_screen.dart`
    - Integrate with existing AI chat infrastructure
    - Support requirement generation and task creation
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5_

- [x] 16. Flutter Agent Access Management
  - [x] 16.1 Create Agent access management UI
    - Create `lib/features/planning/ui/plan_sharing_sheet.dart`
    - Show connected agents, grant/revoke access
    - _Requirements: 7.1, 7.2_

- [x] 17. Checkpoint - Flutter UI Complete
  - Ensure all tests pass, ask the user if questions arise.

- [x] 18. Integration and Navigation
  - [x] 18.1 Add Planning Mode to app navigation
    - Update `lib/core/router.dart` with planning routes
    - Add Planning Mode entry point to home screen
    - _Requirements: 1.2_
  - [x] 18.2 Wire up real-time updates
    - Connect WebSocket for task status updates
    - Update UI when agents modify tasks
    - _Requirements: 6.1, 6.2_

- [x] 19. Analytics and Progress Tracking
  - [x] 19.1 Implement completion percentage calculation
    - Add to plan service and provider
    - _Requirements: 8.1_
  - [ ]* 19.2 Write property test for completion percentage
    - **Property 16: Completion Percentage Calculation**
    - **Validates: Requirements 8.1**

- [x] 20. Final Checkpoint
  - Ensure all tests pass, ask the user if questions arise.
  - Verify MCP tools work with external coding agents
  - Test real-time sync between app and agents

## Notes

- Tasks marked with `*` are optional property-based tests
- Backend uses TypeScript with fast-check for property tests
- Flutter uses Dart with freezed for immutable models
- MCP tools extend the existing `backend/mcp-server` package
- Real-time updates use the existing WebSocket infrastructure
