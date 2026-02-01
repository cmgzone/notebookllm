## Current State (What’s Actually Wired)
- Swarm orchestration exists end-to-end in backend: [gituAgentOrchestrator.ts](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/src/services/gituAgentOrchestrator.ts), [gituMissionControl.ts](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/src/services/gituMissionControl.ts), [gituAgentManager.ts](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/src/services/gituAgentManager.ts).
- Multiple entrypoints can start a mission: MCP tool `deploy_swarm` in [gituMCPHub.ts](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/src/services/gituMCPHub.ts), REST endpoints in [gitu.ts](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/src/routes/gitu.ts), WhatsApp `/swarm` in [whatsappAdapter.ts](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/src/adapters/whatsappAdapter.ts).
- Dependency triggering is implemented now (doc is outdated): [Fix Agent Swarm Orchestration Logic.md](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/.trae/documents/Fix%20Agent%20Swarm%20Orchestration%20Logic.md).

## Gaps / Bugs Blocking “Fully Wired”
- Mission real-time updates aren’t emitted: MissionControl has a stub and `broadcastMissionUpdate` is never called: [gituMissionControl.ts](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/src/services/gituMissionControl.ts), [gituMessageGateway.ts](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/src/services/gituMessageGateway.ts).
- WebSocket broadcast is effectively single-client per user and can unregister the wrong connection: [gituMessageGateway.ts](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/src/services/gituMessageGateway.ts), [gituWebSocketService.ts](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/src/services/gituWebSocketService.ts).
- Agent completion detection is brittle (`includes('DONE')/('FAILED')`) and can false-positive: [gituAgentManager.ts](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/src/services/gituAgentManager.ts).
- Agent step does two AI calls (wasted tokens + inconsistent behavior): [gituAgentManager.ts](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/src/services/gituAgentManager.ts).
- Platform constraint mismatch: internal calls use platform `agent` / `orchestrator`, but DB constraint only allows external platforms: [update_gitu_platforms.sql](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/migrations/update_gitu_platforms.sql), [gituAIRouter.ts](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/src/services/gituAIRouter.ts).
- Flutter swarm dashboard/provider mainly polls and has placeholder-level detail rendering: [mission_control_provider.dart](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/lib/features/gitu/swarm/providers/mission_control_provider.dart), [swarm_dashboard.dart](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/lib/features/gitu/swarm/ui/swarm_dashboard.dart).

## Improvements To Implement (In Order)
1. Fix platform mismatch for background agents/orchestrator
   - Ensure gitu AI history writes use a valid platform (`web` or `terminal`) and keep internal source in metadata or in-memory tagging.
   - Align with the platform constraints described in [Gitu Assistant Wiring + Fix Weird Parts.md](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/.trae/documents/Gitu%20Assistant%20Wiring%20+%20Fix%20Weird%20Parts.md).
2. Wire mission event emission end-to-end
   - Emit `mission_updated` whenever mission status or plan changes (call gateway broadcast from MissionControl).
   - Upgrade gateway to support multiple sockets per user (store `Set<WebSocket>`), and make unregister remove only the correct socket.
3. Make agent completion reliable + cheaper
   - Remove the duplicate `gituAIRouter.route()` call.
   - Switch to structured completion output (e.g. strict JSON with `{status:"done"|"failed"|"continue"}`) and parse it robustly.
4. Improve mission detail ergonomics for UI
   - Add/extend a mission detail endpoint returning `plan.tasks[]` plus per-task agent status/result snippets.
   - Optional: add SSE as a fallback for Flutter if you don’t want WS yet.
5. Scalability cleanups
   - Replace “load all agents then filter by mission” with a DB query filtered by `memory->>'missionId'`.
   - Unify duplicated mission-start routes in [gitu.ts](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/src/routes/gitu.ts).

## Verification
- Add/extend Jest tests for:
  - Agent completion parsing (no false positives).
  - Mission update broadcast payload shape.
  - Mission detail endpoint correctness.
- Manual smoke test: start a swarm via REST/MCP, see real-time mission updates in web WS and correct task unlocking.

## Notes (Project Rules)
- Follow workspace rules in [project_rules.md](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/.trae/rules/project_rules.md): store knowledge after significant implementation, keep features real (no placeholders), and fix errors before adding new features.