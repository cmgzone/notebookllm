# How to Use Planning Mode with NotebookLLM MCP

This guide shows you how to interact with the Planning Mode feature using the NotebookLLM MCP tools.

## Plan Created

**Plan ID**: `0e4dd3c3-b543-4a92-9ec1-5c05894d9bca`  
**Title**: Add Planning Mode to NotebookLLM  
**Status**: Draft (ready to be populated)

## Quick Start: Using MCP Tools

### 1. View Your Plan

```javascript
// Get the plan details
const plan = await mcp_notebookllm_get_plan({
  planId: "0e4dd3c3-b543-4a92-9ec1-5c05894d9bca",
  includeRelations: true
});

console.log(plan);
```

### 2. Add a Requirement (EARS Pattern)

```javascript
// Create a requirement using ubiquitous EARS pattern
const requirement = await mcp_notebookllm_create_requirement({
  planId: "0e4dd3c3-b543-4a92-9ec1-5c05894d9bca",
  title: "THE system SHALL allow users to create, view, update, and delete plans",
  description: "Core CRUD operations for plan management",
  earsPattern: "ubiquitous",
  acceptanceCriteria: [
    "Users can create a new plan with title and description",
    "Users can view a list of all their plans",
    "Users can update plan details",
    "Users can delete plans they own",
    "Plans support draft, active, completed, and archived statuses"
  ]
});

console.log("Requirement created:", requirement.id);
```

### 3. Add a Design Note

```javascript
// Create a design note linked to the requirement
const designNote = await mcp_notebookllm_create_design_note({
  planId: "0e4dd3c3-b543-4a92-9ec1-5c05894d9bca",
  content: `## Database Schema Design

### Core Tables
- **plans**: Main plan storage with status tracking
- **plan_requirements**: EARS-formatted requirements
- **plan_design_notes**: Design documentation linked to requirements
- **plan_tasks**: Hierarchical task structure

### Key Design Decisions
1. **UUID Primary Keys**: For distributed system compatibility
2. **JSONB for Arrays**: Flexible storage for acceptance criteria
3. **Cascading Deletes**: Maintain referential integrity`,
  requirementIds: [requirement.id]
});

console.log("Design note created:", designNote.id);
```

### 4. Create a Task

```javascript
// Create a task linked to the requirement
const task = await mcp_notebookllm_create_task({
  planId: "0e4dd3c3-b543-4a92-9ec1-5c05894d9bca",
  title: "Database Schema Setup",
  description: "Create and migrate database tables for planning mode",
  requirementIds: [requirement.id],
  priority: "high"
});

console.log("Task created:", task.id);
```

### 5. Update Task Status

```javascript
// Start working on the task
await mcp_notebookllm_update_task_status({
  planId: "0e4dd3c3-b543-4a92-9ec1-5c05894d9bca",
  taskId: task.id,
  status: "in_progress",
  reason: "Starting database schema implementation"
});

console.log("Task status updated to in_progress");
```

### 6. Add Task Output (Code)

```javascript
// Add code output to the task
await mcp_notebookllm_add_task_output({
  planId: "0e4dd3c3-b543-4a92-9ec1-5c05894d9bca",
  taskId: task.id,
  type: "code",
  content: `-- Create plans table
CREATE TABLE IF NOT EXISTS plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL,
  title VARCHAR(255) NOT NULL,
  description TEXT,
  status VARCHAR(20) DEFAULT 'draft',
  created_at TIMESTAMPTZ DEFAULT NOW()
);`,
  agentName: "Kiro"
});

console.log("Code output added to task");
```

### 7. Complete the Task

```javascript
// Mark task as completed
await mcp_notebookllm_complete_task({
  planId: "0e4dd3c3-b543-4a92-9ec1-5c05894d9bca",
  taskId: task.id,
  summary: "Database schema created and migration script executed successfully"
});

console.log("Task completed!");
```

### 8. List All Plans

```javascript
// View all your plans
const plans = await mcp_notebookllm_list_plans({
  status: "active",
  includeArchived: false,
  limit: 50
});

console.log(`Found ${plans.plans.length} plans`);
plans.plans.forEach(p => {
  console.log(`- ${p.title} (${p.status})`);
});
```

## Complete Example: Creating a Full Plan

Here's a complete example that creates a plan with requirements, design notes, and tasks:

```javascript
// 1. Create the plan
const plan = await mcp_notebookllm_create_plan({
  title: "User Authentication Feature",
  description: "Implement secure user authentication with JWT",
  isPrivate: true
});

// 2. Add requirements
const req1 = await mcp_notebookllm_create_requirement({
  planId: plan.id,
  title: "THE system SHALL authenticate users with email and password",
  description: "Basic authentication requirement",
  earsPattern: "ubiquitous",
  acceptanceCriteria: [
    "User can enter email and password",
    "System validates credentials against database",
    "User receives JWT token on success",
    "Invalid credentials return error message"
  ]
});

const req2 = await mcp_notebookllm_create_requirement({
  planId: plan.id,
  title: "WHEN user token expires, THE system SHALL require re-authentication",
  description: "Token expiration handling",
  earsPattern: "event",
  acceptanceCriteria: [
    "Tokens expire after 15 minutes",
    "Expired token returns 401 status",
    "User is redirected to login screen"
  ]
});

// 3. Add design note
const design = await mcp_notebookllm_create_design_note({
  planId: plan.id,
  content: `## Authentication Architecture

### Technology Stack
- JWT for token-based auth
- bcrypt for password hashing
- Refresh token rotation for security

### Implementation Details
- Access tokens: 15min expiry
- Refresh tokens: 7 day expiry
- Tokens stored in httpOnly cookies
- Password requirements: 8+ chars, mixed case, numbers`,
  requirementIds: [req1.id, req2.id]
});

// 4. Create tasks
const task1 = await mcp_notebookllm_create_task({
  planId: plan.id,
  title: "Implement login endpoint",
  description: "Create POST /auth/login endpoint with JWT generation",
  requirementIds: [req1.id],
  priority: "high"
});

const task2 = await mcp_notebookllm_create_task({
  planId: plan.id,
  title: "Implement token refresh endpoint",
  description: "Create POST /auth/refresh endpoint for token renewal",
  requirementIds: [req2.id],
  priority: "high"
});

// 5. Work on task 1
await mcp_notebookllm_update_task_status({
  planId: plan.id,
  taskId: task1.id,
  status: "in_progress"
});

await mcp_notebookllm_add_task_output({
  planId: plan.id,
  taskId: task1.id,
  type: "code",
  content: `// Login endpoint implementation
app.post('/auth/login', async (req, res) => {
  const { email, password } = req.body;
  
  // Validate credentials
  const user = await db.users.findByEmail(email);
  if (!user || !await bcrypt.compare(password, user.passwordHash)) {
    return res.status(401).json({ error: 'Invalid credentials' });
  }
  
  // Generate JWT
  const token = jwt.sign({ userId: user.id }, JWT_SECRET, { expiresIn: '15m' });
  
  res.json({ token, user: { id: user.id, email: user.email } });
});`,
  agentName: "Kiro"
});

await mcp_notebookllm_complete_task({
  planId: plan.id,
  taskId: task1.id,
  summary: "Login endpoint implemented with JWT generation and bcrypt password validation"
});

// 6. Get plan with all details
const fullPlan = await mcp_notebookllm_get_plan({
  planId: plan.id,
  includeRelations: true
});

console.log("Plan Progress:", fullPlan.taskSummary.completionPercentage + "%");
console.log("Completed Tasks:", fullPlan.taskSummary.completed);
console.log("Total Tasks:", fullPlan.taskSummary.total);
```

## EARS Pattern Examples

### Ubiquitous (Always Active)
```javascript
await mcp_notebookllm_create_requirement({
  planId: planId,
  title: "THE system SHALL encrypt all passwords using bcrypt",
  earsPattern: "ubiquitous",
  acceptanceCriteria: ["Passwords hashed with bcrypt", "Salt rounds >= 10"]
});
```

### Event-Driven (Triggered by Event)
```javascript
await mcp_notebookllm_create_requirement({
  planId: planId,
  title: "WHEN user clicks login, THE system SHALL validate credentials",
  earsPattern: "event",
  acceptanceCriteria: ["Validation occurs on button click", "Loading state shown"]
});
```

### State-Driven (Active During State)
```javascript
await mcp_notebookllm_create_requirement({
  planId: planId,
  title: "WHILE user is authenticated, THE system SHALL display dashboard",
  earsPattern: "state",
  acceptanceCriteria: ["Dashboard visible when logged in", "Logout button available"]
});
```

### Unwanted Behavior (Error Handling)
```javascript
await mcp_notebookllm_create_requirement({
  planId: planId,
  title: "IF login fails 3 times, THEN THE system SHALL lock account",
  earsPattern: "unwanted",
  acceptanceCriteria: ["Counter tracks failed attempts", "Account locked after 3 failures"]
});
```

### Optional Feature
```javascript
await mcp_notebookllm_create_requirement({
  planId: planId,
  title: "WHERE 2FA is enabled, THE system SHALL require OTP",
  earsPattern: "optional",
  acceptanceCriteria: ["OTP sent via email", "OTP valid for 5 minutes"]
});
```

## Task Status Workflow

```javascript
// 1. Create task (starts as not_started)
const task = await mcp_notebookllm_create_task({
  planId: planId,
  title: "Implement feature X",
  priority: "high"
});

// 2. Start working
await mcp_notebookllm_update_task_status({
  planId: planId,
  taskId: task.id,
  status: "in_progress"
});

// 3. If blocked
await mcp_notebookllm_update_task_status({
  planId: planId,
  taskId: task.id,
  status: "blocked",
  reason: "Waiting for API key from client"
});

// 4. Resume work
await mcp_notebookllm_update_task_status({
  planId: planId,
  taskId: task.id,
  status: "in_progress",
  reason: "API key received, resuming implementation"
});

// 5. Complete
await mcp_notebookllm_complete_task({
  planId: planId,
  taskId: task.id,
  summary: "Feature X implemented and tested"
});
```

## Sub-Tasks Example

```javascript
// Create parent task
const parentTask = await mcp_notebookllm_create_task({
  planId: planId,
  title: "Implement authentication system",
  priority: "high"
});

// Create sub-tasks
const subTask1 = await mcp_notebookllm_create_task({
  planId: planId,
  parentTaskId: parentTask.id,
  title: "Create user model",
  priority: "high"
});

const subTask2 = await mcp_notebookllm_create_task({
  planId: planId,
  parentTaskId: parentTask.id,
  title: "Implement password hashing",
  priority: "high"
});

const subTask3 = await mcp_notebookllm_create_task({
  planId: planId,
  parentTaskId: parentTask.id,
  title: "Create login endpoint",
  priority: "high"
});

// Complete sub-tasks
await mcp_notebookllm_complete_task({
  planId: planId,
  taskId: subTask1.id,
  summary: "User model created with email and password fields"
});

await mcp_notebookllm_complete_task({
  planId: planId,
  taskId: subTask2.id,
  summary: "Password hashing implemented with bcrypt"
});

await mcp_notebookllm_complete_task({
  planId: planId,
  taskId: subTask3.id,
  summary: "Login endpoint created and tested"
});

// When all sub-tasks complete, parent can be completed
await mcp_notebookllm_complete_task({
  planId: planId,
  taskId: parentTask.id,
  summary: "Authentication system fully implemented"
});
```

## Agent Access Control

```javascript
// Grant agent access to plan
await mcp_notebookllm_grant_plan_access({
  planId: planId,
  agentSessionId: "agent-session-123",
  agentName: "Kiro",
  permissions: ["read", "write"]
});

// Revoke access
await mcp_notebookllm_revoke_plan_access({
  planId: planId,
  agentSessionId: "agent-session-123"
});
```

## Best Practices

1. **Start with Requirements**: Define clear EARS requirements before creating tasks
2. **Link Everything**: Connect tasks to requirements, design notes to requirements
3. **Use Descriptive Titles**: Make titles searchable and clear
4. **Add Acceptance Criteria**: Define what "done" means for each requirement
5. **Track Progress**: Update task status as you work
6. **Document Decisions**: Use design notes to explain architectural choices
7. **Add Context**: Include reasons when changing task status
8. **Use Sub-Tasks**: Break down complex tasks into manageable pieces
9. **Complete Tasks**: Always mark tasks as complete with a summary
10. **Review Analytics**: Check completion percentage and task summary regularly

## Troubleshooting

### Plan Not Found
```javascript
// Make sure you're using the correct plan ID
const plans = await mcp_notebookllm_list_plans({});
console.log("Available plans:", plans.plans.map(p => ({ id: p.id, title: p.title })));
```

### Task Status Update Failed
```javascript
// Blocked status requires a reason
await mcp_notebookllm_update_task_status({
  planId: planId,
  taskId: taskId,
  status: "blocked",
  reason: "This is required for blocked status"
});
```

### Permission Denied
```javascript
// Check if you have access to the plan
const plan = await mcp_notebookllm_get_plan({ planId: planId });
console.log("Plan owner:", plan.userId);
console.log("Is private:", plan.isPrivate);
```

## Resources

- **MCP Server Documentation**: `backend/mcp-server/README.md`
- **Planning Mode Spec**: `.kiro/specs/planning-mode/`
- **API Routes**: `backend/src/routes/planning.ts`
- **Flutter UI**: `lib/features/planning/ui/`

## Next Steps

Now that you have a plan created, you can:

1. Add requirements using EARS patterns
2. Document design decisions in design notes
3. Create tasks and sub-tasks
4. Track progress as you implement
5. Use the Flutter app to visualize your plan
6. Share the plan with other agents

Happy planning! 🚀
