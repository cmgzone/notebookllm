## What’s Already in Core Memory

* There is 1 project memory covering swarm wiring improvements (mission\_updated broadcasts, JSON envelope, mission detail endpoint, internal platform set to terminal). <mccoremem id="03fifgdwbgejaflha16pbt2w5" />

## What Still Should Be Added (High Value, Reusable)

1. AI Memory Architecture (project-level)

* Source: [AI Memory Architecture Overview.md](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/.trae/documents/AI%20Memory%20Architecture%20Overview.md)

* Add a memory that NotebookLLM memory has 3 layers:

  * short-term chat history (Flutter prompt building)

  * long-term RAG (pgvector chunks)

  * semantic fact memory (gitu\_memories via MemoryService/Extractor)

1. Semantic Fact Memory rules (project-level)

* Source: [gituMemoryService.ts](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/src/services/gituMemoryService.ts), [gituMemoryExtractor.ts](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/src/services/gituMemoryExtractor.ts)

* Add memory for:

  * categories: personal/work/preference/fact/context/goal/relationship

  * verification workflow: verified + verification\_required + last\_confirmed\_by\_user + confidence scoring

  * extractor thresholds: skips user messages < 20 chars and “simple queries”; stores facts only if confidence >= 0.6

1. Swarm wiring memory update (project-level)

* Update the existing swarm memory to include the concrete interfaces:

  * new API `GET /gitu/mission/:id/detail`

  * new DB-filtered helper `listAgentsByMission(userId, missionId)`

  * websocket change: userId -> Set<WebSocket> and unregister(userId, ws)

## Execution Plan After You Confirm

* Update core memory with items (1)–(4): add 2 new project memories (Memory architecture + Semantic fact memory rules) and update the existing swarm memory.

