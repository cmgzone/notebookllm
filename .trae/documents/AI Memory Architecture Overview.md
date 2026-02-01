Based on my research, the AI memory system is implemented using three distinct layers.

## 1. Short-term Contextual Memory (Chat History)
This handles immediate conversation flow.
*   **Location**: `lib/features/chat/stream_provider.dart`
*   **Mechanism**: Manually constructs the prompt with the last ~10 messages.

## 2. Long-term Knowledge (RAG)
This stores documents and large data.
*   **Mechanism**: Uses `pgvector` for embedding search.
*   **Schema**: `chunks` table with `embedding VECTOR(1536)`.

## 3. Semantic Fact Memory (Gitu Memory Service)
This is the core system for learning user facts.
*   **Service**: [gituMemoryService.ts](file:///c%3A/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/src/services/gituMemoryService.ts)
*   **Extractor**: [gituMemoryExtractor.ts](file:///c%3A/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/src/services/gituMemoryExtractor.ts)
*   **Schema**: `gitu_memories` table storing `category`, `content`, `confidence`, and `verified` status.
*   **Workflow**:
    1.  `GituMemoryExtractor` analyzes conversations using AI.
    2.  Extracts facts like "User likes Python".
    3.  `GituMemoryService` stores them and detects contradictions (e.g., "User likes Java" vs "User hates Java").

This confirms the system is fully wired to learn, store, and recall user information automatically.
