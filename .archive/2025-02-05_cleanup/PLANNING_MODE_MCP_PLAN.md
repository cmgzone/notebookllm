# Planning Mode Implementation Plan

**Plan ID**: `0e4dd3c3-b543-4a92-9ec1-5c05894d9bca`  
**Status**: Draft  
**Created**: January 5, 2026

## Overview

This plan documents the implementation of Planning Mode in NotebookLLM - a comprehensive feature that enables spec-driven development workflows with requirements (EARS patterns), design notes, tasks, and progress tracking.

## Requirements (EARS Patterns)

### 1. Core Plan Management (Ubiquitous)
**THE system SHALL allow users to create, view, update, and delete plans**

- Users can create a new plan with title and description
- Users can view a list of all their plans
- Users can update plan details
- Users can delete plans they own
- Plans support draft, active, completed, and archived statuses

### 2. AI-Assisted Planning (Ubiquitous)
**THE system SHALL support AI-assisted plan creation and brainstorming**

- Users can chat with AI to brainstorm plan ideas
- AI can generate requirements from conversation
- AI can suggest tasks based on requirements
- AI maintains context throughout the planning session

### 3. Task Management (Ubiquitous)
**THE system SHALL manage tasks with hierarchical structure and status tracking**

- Tasks support not_started, in_progress, paused, blocked, completed statuses
- Tasks can have sub-tasks (parent-child hierarchy)
- Task status changes are recorded in history
- Tasks can be assigned priority levels (low, medium, high, critical)
- Tasks can be linked to requirements

### 4. EARS Requirements (Ubiquitous)
**THE system SHALL follow EARS patterns for requirements specification**

- Support ubiquitous pattern: THE <system> SHALL <response>
- Support event pattern: WHEN <trigger>, THE <system> SHALL <response>
- Support state pattern: WHILE <condition>, THE <system> SHALL <response>
- Support unwanted pattern: IF <condition>, THEN THE <system> SHALL <response>
- Support optional pattern: WHERE <option>, THE <system> SHALL <response>
- Requirements include acceptance criteria

### 5. MCP Integration (Ubiquitous)
**THE system SHALL enable coding agents to interact with plans via MCP**

- Agents can create plans via MCP tools
- Agents can add requirements and design notes
- Agents can create and update tasks
- Agents can add outputs (code, comments) to tasks
- Agents can track task completion

### 6. Status History (Event-Driven)
**WHEN a task status changes, THE system SHALL record the change in history**

- Status changes include timestamp
- Status changes include who made the change (user or agent)
- Status changes can include a reason
- History is queryable and displayed in UI

### 7. Real-time Updates (Ubiquitous)
**THE system SHALL provide real-time updates via WebSocket**

- WebSocket connection established for active plans
- Task updates broadcast to connected clients
- Plan updates broadcast to connected clients
- Connection handles reconnection gracefully

### 8. Progress Analytics (Ubiquitous)
**THE system SHALL track progress and provide analytics**

- Calculate completion percentage based on tasks
- Show task count by status
- Track time spent on tasks
- Display completion trends over time
- Show analytics on plan detail screen

### 9. Plan Sharing (Ubiquitous)
**THE system SHALL support plan sharing with agents**

- Users can grant agents access to plans
- Access includes permission levels (read, write)
- Users can revoke agent access
- Agents can only access plans they have permission for

### 10. Blocked Task Validation (Unwanted Behavior)
**IF a task is marked as blocked, THEN THE system SHALL require a blocking reason**

- Blocked status requires reason field
- Reason is stored and displayed
- Reason helps identify blockers for resolution

## Design Notes

### Database Schema Design

#### Core Tables
- **plans**: Main plan storage with status tracking
- **plan_requirements**: EARS-formatted requirements
- **plan_design_notes**: Design documentation linked to requirements
- **plan_tasks**: Hierarchical task structure
- **task_status_history**: Audit trail for status changes
- **task_agent_outputs**: Agent-generated content
- **plan_agent_access**: Access control for agents

#### Key Design Decisions
1. **UUID Primary Keys**: For distributed system compatibility
2. **JSONB for Arrays**: Flexible storage for acceptance criteria and metadata
3. **Cascading Deletes**: Maintain referential integrity
4. **Indexed Queries**: Optimized for common access patterns
5. **Timestamps**: Track creation, updates, and completion

### Flutter UI Architecture

#### Screen Hierarchy
- **PlansListScreen**: Overview of all plans with filters
- **PlanDetailScreen**: Tabbed interface (Requirements, Design, Tasks, Analytics)
- **PlanningAIScreen**: Chat interface for AI-assisted planning
- **TaskDetailSheet**: Bottom sheet for task management

#### State Management
- **PlanningProvider**: Riverpod StateNotifier for plans state
- **WebSocket Integration**: Real-time updates via planning_provider
- **Optimistic Updates**: Immediate UI feedback with rollback on error

#### Key Features
- Pull-to-refresh for plans list
- Search and filter capabilities
- Status badges and progress indicators
- Hierarchical task display with expand/collapse

### MCP Integration Design

#### Tool Categories
1. **Plan Management**: create_plan, get_plan, list_plans, update_plan_status
2. **Requirements**: create_requirement, list_requirements
3. **Design Notes**: create_design_note, list_design_notes
4. **Task Management**: create_task, update_task_status, complete_task
5. **Agent Outputs**: add_task_output
6. **Access Control**: grant_plan_access, revoke_plan_access

#### Authentication
- Personal API tokens for agent authentication
- Token validation middleware
- Rate limiting per token

#### WebSocket Protocol
- Connection: wss://api/planning/ws?token=xxx
- Message types: task_updated, plan_updated, requirement_added
- Heartbeat for connection health

### EARS Pattern Implementation

#### Pattern Templates
- **Ubiquitous**: THE <system> SHALL <response>
- **Event**: WHEN <trigger>, THE <system> SHALL <response>
- **State**: WHILE <condition>, THE <system> SHALL <response>
- **Unwanted**: IF <condition>, THEN THE <system> SHALL <response>
- **Optional**: WHERE <option>, THE <system> SHALL <response>
- **Complex**: Combination of above patterns

#### Validation
- Pattern validation on requirement creation
- Template suggestions in UI
- Acceptance criteria as checklist

#### Benefits
- Clear, testable requirements
- Consistent specification format
- Easy to understand for both humans and AI

### Progress Tracking & Analytics

#### Metrics Calculated
- **Completion Percentage**: (completed tasks / total tasks) * 100
- **Task Status Summary**: Count by status (not_started, in_progress, etc.)
- **Time Tracking**: Sum of time_spent_minutes across tasks
- **Completion Trend**: Historical data points for progress visualization

#### Analytics Display
- Progress bar with percentage
- Pie chart for task status distribution
- Line chart for completion trend
- Time spent summary

#### Performance Optimization
- Cached analytics calculations
- Incremental updates on task changes
- Efficient database queries with indexes

## Implementation Tasks

### ✅ Task 1: Database Schema Setup (COMPLETED)
**Priority**: High  
**Requirements**: Core Plan Management

- [x] Create migration file add_planning_mode.sql
- [x] Define plans table with status enum
- [x] Define plan_requirements table with EARS patterns
- [x] Define plan_tasks table with hierarchy support
- [x] Add indexes for performance
- [x] Create triggers for updated_at timestamps
- [x] Run migration script

**Status**: Completed - Schema exists in `backend/migrations/add_planning_mode.sql`

---

### ✅ Task 2: Flutter Data Models (COMPLETED)
**Priority**: High  
**Requirements**: Core Plan Management, Task Management, EARS Requirements

- [x] Create Plan model with status enum
- [x] Create Requirement model with EARS patterns
- [x] Create PlanTask model with status tracking
- [x] Add fromBackendJson converters
- [x] Add toBackendJson converters
- [x] Generate Freezed code

**Status**: Completed - Models exist in `lib/features/planning/models/`

---

### ✅ Task 3: Backend API Endpoints (COMPLETED)
**Priority**: High  
**Requirements**: Core Plan Management, MCP Integration

- [x] POST /api/planning/plans - Create plan
- [x] GET /api/planning/plans - List plans
- [x] GET /api/planning/plans/:id - Get plan details
- [x] PUT /api/planning/plans/:id - Update plan
- [x] DELETE /api/planning/plans/:id - Delete plan
- [x] POST /api/planning/plans/:id/requirements - Add requirement
- [x] POST /api/planning/plans/:id/design-notes - Add design note
- [x] POST /api/planning/plans/:id/tasks - Create task
- [x] PUT /api/planning/tasks/:id/status - Update task status
- [x] POST /api/planning/tasks/:id/outputs - Add agent output

**Status**: Completed - API exists in `backend/src/routes/planning.ts`

---

### ✅ Task 4: Planning Service (Flutter) (COMPLETED)
**Priority**: High  
**Requirements**: Core Plan Management

- [x] Implement PlanningService class
- [x] Add CRUD methods for plans
- [x] Add methods for requirements and design notes
- [x] Add methods for task management
- [x] Handle error responses
- [x] Add retry logic for failed requests

**Status**: Completed - Service exists in `lib/features/planning/services/planning_service.dart`

---

### ✅ Task 5: Planning Provider (State Management) (COMPLETED)
**Priority**: High  
**Requirements**: Core Plan Management, Real-time Updates

- [x] Create PlanningState class
- [x] Create PlanningNotifier with StateNotifier
- [x] Implement loadPlans method
- [x] Implement createPlan method
- [x] Implement updatePlan method
- [x] Implement deletePlan method
- [x] Add WebSocket connection handling
- [x] Handle real-time updates

**Status**: Completed - Provider exists in `lib/features/planning/planning_provider.dart`

---

### ✅ Task 6: Plans List Screen (COMPLETED)
**Priority**: Medium  
**Requirements**: Core Plan Management

- [x] Create PlansListScreen widget
- [x] Add pull-to-refresh
- [x] Add search functionality
- [x] Add status filter chips
- [x] Display plan cards with status badges
- [x] Add FAB for creating new plan
- [x] Handle empty state

**Status**: Completed - Screen exists in `lib/features/planning/ui/plans_list_screen.dart`

---

### ✅ Task 7: Plan Detail Screen (COMPLETED)
**Priority**: Medium  
**Requirements**: Core Plan Management, EARS Requirements, Progress Analytics

- [x] Create PlanDetailScreen with TabBar
- [x] Implement Requirements tab
- [x] Implement Design Notes tab
- [x] Implement Tasks tab with hierarchy
- [x] Implement Analytics tab
- [x] Add edit and delete actions
- [x] Add share with agents action

**Status**: Completed - Screen exists in `lib/features/planning/ui/plan_detail_screen.dart`

---

### ✅ Task 8: Planning AI Screen (COMPLETED)
**Priority**: Medium  
**Requirements**: AI-Assisted Planning

- [x] Create PlanningAIScreen widget
- [x] Integrate chat UI
- [x] Add AI service integration
- [x] Implement requirement generation from chat
- [x] Implement task suggestion from requirements
- [x] Add context awareness
- [x] Handle streaming responses

**Status**: Completed - Screen exists in `lib/features/planning/ui/planning_ai_screen.dart`

---

### ✅ Task 9: Task Management UI (COMPLETED)
**Priority**: Medium  
**Requirements**: Task Management

- [x] Create TaskDetailSheet bottom sheet
- [x] Add status dropdown with validation
- [x] Add priority selector
- [x] Add sub-task creation
- [x] Display status history
- [x] Display agent outputs
- [x] Create TaskListWidget with hierarchy
- [x] Add expand/collapse for sub-tasks

**Status**: Completed - UI exists in `lib/features/planning/ui/task_detail_sheet.dart` and `task_list_widget.dart`

---

### ✅ Task 10: MCP Server Implementation (COMPLETED)
**Priority**: High  
**Requirements**: MCP Integration

- [x] Add create_plan tool
- [x] Add get_plan tool
- [x] Add list_plans tool
- [x] Add create_requirement tool
- [x] Add create_design_note tool
- [x] Add create_task tool
- [x] Add update_task_status tool
- [x] Add add_task_output tool
- [x] Add complete_task tool
- [x] Add grant_plan_access tool
- [x] Add revoke_plan_access tool
- [x] Update MCP server documentation

**Status**: Completed - MCP tools exist in `backend/mcp-server/src/index.ts`

---

### ✅ Task 11: WebSocket Real-time Updates (COMPLETED)
**Priority**: Medium  
**Requirements**: Real-time Updates

- [x] Create PlanningWebSocketService
- [x] Implement connection management
- [x] Implement message broadcasting
- [x] Handle task_updated events
- [x] Handle plan_updated events
- [x] Handle requirement_added events
- [x] Add reconnection logic
- [x] Integrate with PlanningProvider

**Status**: Completed - Service exists in `backend/src/services/planningWebSocketService.ts`

---

### ✅ Task 12: Progress Analytics (COMPLETED)
**Priority**: Low  
**Requirements**: Progress Analytics

- [x] Implement completion percentage calculation
- [x] Implement task status summary
- [x] Implement time tracking aggregation
- [x] Create completion trend query
- [x] Create PlanAnalytics model
- [x] Add analytics API endpoint
- [x] Create analytics UI components
- [x] Add charts (progress bar, pie chart, line chart)

**Status**: Completed - Analytics implemented in Plan model and PlanDetailScreen

---

### ✅ Task 13: Access Control & Sharing (COMPLETED)
**Priority**: Low  
**Requirements**: Plan Sharing

- [x] Create plan_agent_access table
- [x] Implement grant access API
- [x] Implement revoke access API
- [x] Add permission checking middleware
- [x] Create PlanSharingSheet UI
- [x] Display shared agents list
- [x] Add agent search/select
- [x] Handle access revocation

**Status**: Completed - Sharing exists in `lib/features/planning/ui/plan_sharing_sheet.dart`

---

### ✅ Task 14: Testing & Documentation (COMPLETED)
**Priority**: Medium  
**Requirements**: All

- [x] Write unit tests for models
- [x] Write unit tests for services
- [x] Write integration tests for API
- [x] Write property-based tests for task hierarchy
- [x] Write widget tests for screens
- [x] Update README with planning mode docs
- [x] Create user guide for planning mode
- [x] Create agent guide for MCP tools
- [x] Add inline code documentation

**Status**: Completed - Tests exist in `backend/src/__tests__/planCreation.pbt.test.ts` and documentation in `.kiro/specs/planning-mode/`

## Summary

**Total Requirements**: 10  
**Total Design Notes**: 5  
**Total Tasks**: 14  
**Completion Status**: 100% ✅

All Planning Mode features have been successfully implemented, including:
- Database schema with 7 tables
- Flutter UI with 4 main screens
- Backend API with 15+ endpoints
- MCP integration with 11 tools
- Real-time WebSocket updates
- Progress analytics and tracking
- Access control and sharing
- Comprehensive testing

The feature is production-ready and fully integrated with the NotebookLLM MCP server for coding agent interaction.

## Next Steps

1. **User Testing**: Gather feedback from users on the planning workflow
2. **Performance Optimization**: Monitor and optimize database queries
3. **Enhanced Analytics**: Add more visualization options
4. **Mobile Optimization**: Ensure responsive design on smaller screens
5. **Export/Import**: Add ability to export plans as JSON or Markdown
6. **Templates**: Create plan templates for common use cases
7. **Collaboration**: Add real-time collaborative editing
8. **Notifications**: Add push notifications for plan updates

## Resources

- **Spec Files**: `.kiro/specs/planning-mode/`
- **Models**: `lib/features/planning/models/`
- **UI**: `lib/features/planning/ui/`
- **Backend**: `backend/src/routes/planning.ts`, `backend/src/services/planService.ts`
- **MCP**: `backend/mcp-server/src/index.ts`
- **Migration**: `backend/migrations/add_planning_mode.sql`
- **Tests**: `backend/src/__tests__/planCreation.pbt.test.ts`
