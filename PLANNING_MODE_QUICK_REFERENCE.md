# Planning Mode - Quick Reference

## Your Plan

**Plan ID**: `0e4dd3c3-b543-4a92-9ec1-5c05894d9bca`  
**Title**: Add Planning Mode to NotebookLLM  
**Status**: Draft

## MCP Tools Quick Reference

### Plan Management

```javascript
// Create plan
mcp_notebookllm_create_plan({ title, description, isPrivate })

// Get plan
mcp_notebookllm_get_plan({ planId, includeRelations: true })

// List plans
mcp_notebookllm_list_plans({ status, includeArchived, limit, offset })
```

### Requirements

```javascript
// Create requirement
mcp_notebookllm_create_requirement({
  planId,
  title,
  description,
  earsPattern, // ubiquitous, event, state, unwanted, optional
  acceptanceCriteria: []
})
```

### Design Notes

```javascript
// Create design note
mcp_notebookllm_create_design_note({
  planId,
  content,
  requirementIds: []
})
```

### Tasks

```javascript
// Create task
mcp_notebookllm_create_task({
  planId,
  title,
  description,
  parentTaskId, // optional, for sub-tasks
  requirementIds: [],
  priority // low, medium, high, critical
})

// Update status
mcp_notebookllm_update_task_status({
  planId,
  taskId,
  status, // not_started, in_progress, paused, blocked, completed
  reason // required for blocked
})

// Add output
mcp_notebookllm_add_task_output({
  planId,
  taskId,
  type, // comment, code, file, completion
  content,
  agentName
})

// Complete task
mcp_notebookllm_complete_task({
  planId,
  taskId,
  summary
})
```

## EARS Patterns

| Pattern | Template | Example |
|---------|----------|---------|
| **Ubiquitous** | THE <system> SHALL <response> | THE system SHALL encrypt all passwords |
| **Event** | WHEN <trigger>, THE <system> SHALL <response> | WHEN user clicks login, THE system SHALL validate credentials |
| **State** | WHILE <condition>, THE <system> SHALL <response> | WHILE user is authenticated, THE system SHALL display dashboard |
| **Unwanted** | IF <condition>, THEN THE <system> SHALL <response> | IF login fails 3 times, THEN THE system SHALL lock account |
| **Optional** | WHERE <option>, THE <system> SHALL <response> | WHERE 2FA is enabled, THE system SHALL require OTP |

## Task Status Flow

```
not_started → in_progress → completed
                ↓
              paused → in_progress
                ↓
              blocked → in_progress
```

## Priority Levels

- **low**: Nice to have, can be deferred
- **medium**: Standard priority (default)
- **high**: Important, should be done soon
- **critical**: Urgent, blocking other work

## Common Workflows

### 1. Create a Simple Plan

```javascript
const plan = await mcp_notebookllm_create_plan({
  title: "My Feature",
  description: "Build feature X"
});

const req = await mcp_notebookllm_create_requirement({
  planId: plan.id,
  title: "THE system SHALL do X",
  earsPattern: "ubiquitous"
});

const task = await mcp_notebookllm_create_task({
  planId: plan.id,
  title: "Implement X",
  requirementIds: [req.id]
});
```

### 2. Work on a Task

```javascript
// Start
await mcp_notebookllm_update_task_status({
  planId, taskId,
  status: "in_progress"
});

// Add code
await mcp_notebookllm_add_task_output({
  planId, taskId,
  type: "code",
  content: "// code here",
  agentName: "Kiro"
});

// Complete
await mcp_notebookllm_complete_task({
  planId, taskId,
  summary: "Feature implemented"
});
```

### 3. Create Sub-Tasks

```javascript
const parent = await mcp_notebookllm_create_task({
  planId, title: "Main Task"
});

const sub1 = await mcp_notebookllm_create_task({
  planId,
  parentTaskId: parent.id,
  title: "Sub-task 1"
});

const sub2 = await mcp_notebookllm_create_task({
  planId,
  parentTaskId: parent.id,
  title: "Sub-task 2"
});
```

## Files Created

1. **PLANNING_MODE_MCP_PLAN.md** - Full documentation with all requirements, design notes, and tasks
2. **HOW_TO_USE_PLANNING_MODE_MCP.md** - Detailed guide with examples
3. **PLANNING_MODE_SUMMARY.md** - Implementation summary and overview
4. **planning-mode-mcp-setup.js** - Structured data for requirements and tasks
5. **PLANNING_MODE_QUICK_REFERENCE.md** - This file

## Resources

- **Spec Files**: `.kiro/specs/planning-mode/`
- **Models**: `lib/features/planning/models/`
- **UI**: `lib/features/planning/ui/`
- **Backend**: `backend/src/routes/planning.ts`
- **MCP**: `backend/mcp-server/src/index.ts`
- **Migration**: `backend/migrations/add_planning_mode.sql`

## Tips

✅ **DO**:
- Use descriptive titles
- Add acceptance criteria to requirements
- Link tasks to requirements
- Update task status as you work
- Add summaries when completing tasks
- Use sub-tasks for complex work

❌ **DON'T**:
- Forget to mark blocked tasks with a reason
- Skip linking tasks to requirements
- Leave tasks in in_progress indefinitely
- Create tasks without descriptions

## Need Help?

- Check `HOW_TO_USE_PLANNING_MODE_MCP.md` for detailed examples
- Review `PLANNING_MODE_MCP_PLAN.md` for the complete feature documentation
- Look at existing implementation in `lib/features/planning/`

---

**Quick Start**: Use the plan ID `0e4dd3c3-b543-4a92-9ec1-5c05894d9bca` with the MCP tools above to start adding requirements and tasks!
