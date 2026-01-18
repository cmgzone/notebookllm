
# Agent Skills Setup & Verification

## Overview
Added "Agent Skills" feature allowing both users and coding agents to manage reusable skills (prompts/workflows).

## Components Implemented

### 1. Database
- Created `agent_skills` table.
- Migration script: `backend/src/scripts/run-agent-skills-migration.ts`.

### 2. Backend API
- New Router: `backend/src/routes/agentSkills.ts`.
- Endpoints:
  - `GET /api/agent-skills`: List skills.
  - `POST /api/agent-skills`: Create skill.
  - `PUT /api/agent-skills/:id`: Update skill.
  - `DELETE /api/agent-skills/:id`: Delete skill.

### 3. Frontend UI
- New Screen: `AgentSkillsScreen` (`lib/features/agent_skills/agent_skills_screen.dart`).
- Entry Point: App Drawer -> Settings -> Agent Skills.
- State Management: `agentSkillsProvider`.
- API Service updated.

### 4. MCP Server (Coding Agent Integration)
- Updated `notebookllmmcp` to expose new tools:
  - `list_agent_skills`
  - `create_agent_skill`
  - `update_agent_skill`
  - `delete_agent_skill`
- The Coding Agent (Claude/Cursor) can now view and create skills directly.

## Verification Steps

1.  **Frontend**:
    - Run the app.
    - Go to Drawer -> Agent Skills.
    - Create a new skill (e.g., "Review Code Style").
    - Verify it appears in the list.

2.  **MCP Interaction**:
    - Ask the Coding Agent: "List my agent skills".
    - It should call `list_agent_skills` and show the skill you created.
    - Ask the Agent: "Create a new agent skill called 'Optimize Loop' that suggests loop optimizations".
    - Verify the skill appears in the App UI.

## Troubleshooting
- If MCP tools don't show up, ensure you've restarted the MCP server/client.
- Check backend logs for API errors.
