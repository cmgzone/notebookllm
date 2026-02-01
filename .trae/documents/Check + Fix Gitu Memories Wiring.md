## Current Wiring (What Works)
- **Auto-extract on Web chat:** [gituWebSocketService.ts](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/src/services/gituWebSocketService.ts#L251-L279) calls [gituMemoryExtractor.ts](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/src/services/gituMemoryExtractor.ts) which stores via [gituMemoryService.ts](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/src/services/gituMemoryService.ts).
- **Recall in prompts:** [gituSystemPromptBuilder.ts](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/src/services/gituSystemPromptBuilder.ts#L273) pulls memories from the DB.
- **REST API + Flutter UI alignment:** Memory endpoints in [gitu.ts](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/src/routes/gitu.ts#L732-L797) match Flutter calls in [memory_provider.dart](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/lib/features/gitu/memory_provider.dart) (base URL behavior is OK via [api_service.dart](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/lib/core/api/api_service.dart#L266-L345)).
- **Matches the architecture doc:** [AI Memory Architecture Overview.md](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/.trae/documents/AI%20Memory%20Architecture%20Overview.md) describes these 3 layers; the above confirms the semantic memory layer is present and used.

## Problems Found (Not Correctly Wired / Risky)
- **Security: memory mutations are not user-scoped.** The routes call updates/deletes using only the memory id, and the service queries also use `WHERE id = $1` only (no `AND user_id = $2`). This allows one authenticated user to modify another user’s memories if they know an id.
- **Extractor wiring is web-only in practice.** There is a helper [trackOutboundMessage](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/src/services/gituMessageGateway.ts#L94-L146) that would extract on outbound messages, but it has no call sites, so non-web channels won’t create memories.
- **Likely missing gateway routing for WhatsApp/Telegram.** The adapters don’t appear to route inbound/outbound through the message gateway, so memory extraction + consistent conversation tracking is incomplete for those channels.

## Implementation Plan (Step-by-step)
### 1) Fix authorization (highest priority)
- Change memory mutation endpoints (confirm/request-verification/correct/delete) to enforce user ownership.
- Update memory service methods to require `userId` and execute `UPDATE/DELETE ... WHERE id = $1 AND user_id = $2`.
- Ensure all callers pass the authenticated `req.user.id`.

### 2) Wire extraction consistently across channels
- Decide on one canonical extraction hook (recommended: message gateway outbound tracking) so every channel can reuse it.
- Ensure WhatsApp/Telegram adapters route inbound messages into the gateway and outbound responses call `trackOutboundMessage(...)` (or equivalent central hook).

### 3) Add regression coverage
- Add backend tests for user-scoped mutations (cannot delete/confirm others’ memories).
- Add a lightweight test ensuring the chosen outbound hook triggers extractor calls.

### 4) Verify end-to-end
- Run backend test suite / lint.
- Manually verify: web chat creates a memory, Flutter memories screen lists it, and another user cannot mutate it.
