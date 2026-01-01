# Implementation Plan: Coding Agent Communication

## Overview

This plan implements bidirectional communication between users and third-party coding agents. We'll build the backend services first, then update the MCP server, and finally add Flutter UI components.

## Tasks

- [x] 1. Database Migration for Agent Communication
  - [x] 1.1 Create agent_sessions table with user_id, agent_name, agent_identifier, webhook_url, webhook_secret, notebook_id, status, metadata
    - _Requirements: 4.1, 4.4_
  - [x] 1.2 Create source_conversations table linking sources to conversations
    - _Requirements: 3.5_
  - [x] 1.3 Create conversation_messages table with role, content, metadata, is_read
    - _Requirements: 3.5_
  - [x] 1.4 Add indexes for performance
    - _Requirements: 4.4_

- [x] 2. Agent Session Service
  - [x] 2.1 Create agentSessionService.ts with createSession, getSession, getSessionByAgent, updateActivity, expireSession
    - _Requirements: 1.1, 1.2, 1.3, 4.2_
  - [x] 2.2 Write property test for session creation idempotence
    - **Property 1: Agent Notebook Creation Idempotence**
    - **Validates: Requirements 1.1, 1.2, 1.3**
  - [x] 2.3 Write property test for multiple agent sessions
    - **Property 6: Multiple Agent Sessions**
    - **Validates: Requirements 4.4**

- [x] 3. Agent Notebook Service
  - [x] 3.1 Create agentNotebookService.ts with createOrGetNotebook, getAgentNotebooks, deleteNotebook
    - _Requirements: 1.1, 1.2, 1.3, 4.3_
  - [x] 3.2 Update notebooks table to support isAgentNotebook flag and agent metadata
    - _Requirements: 1.4_

- [x] 4. Source Conversation Service
  - [x] 4.1 Create sourceConversationService.ts with addMessage, getConversation, getPendingUserMessages
    - _Requirements: 3.2, 3.3, 3.5_
  - [x] 4.2 Write property test for conversation history integrity
    - **Property 3: Conversation History Integrity**
    - **Validates: Requirements 3.5**

- [x] 5. Webhook Service
  - [x] 5.1 Create webhookService.ts with registerWebhook, sendFollowup, verifySignature
    - _Requirements: 5.1, 5.2, 5.3, 5.4_
  - [x] 5.2 Implement retry logic with exponential backoff for failed webhooks
    - _Requirements: 3.4_
  - [x] 5.3 Write property test for webhook payload completeness
    - **Property 4: Webhook Payload Completeness**
    - **Validates: Requirements 3.2, 5.2**
  - [x] 5.4 Write property test for webhook authentication
    - **Property 5: Webhook Authentication**
    - **Validates: Requirements 5.3**

- [x] 6. Backend API Routes
  - [x] 6.1 Add POST /api/coding-agent/notebooks - Create or get agent notebook
    - _Requirements: 1.1, 1.2, 1.3_
  - [x] 6.2 Add POST /api/coding-agent/sources/with-context - Save source with conversation context
    - _Requirements: 2.1, 2.2, 2.3_
  - [x] 6.3 Add GET /api/coding-agent/followups - Get pending user messages for agent
    - _Requirements: 3.2_
  - [x] 6.4 Add POST /api/coding-agent/followups/:id/respond - Agent responds to user
    - _Requirements: 3.3_
  - [x] 6.5 Add POST /api/coding-agent/webhook/register - Register webhook endpoint
    - _Requirements: 5.1_
  - [x] 6.6 Write property test for source-notebook association
    - **Property 2: Source-Notebook Association**
    - **Validates: Requirements 2.1, 2.2, 2.3**

- [x] 7. Checkpoint - Backend Complete
  - Ensure all backend tests pass, ask the user if questions arise.

- [ ] 8. Update MCP Server
  - [ ] 8.1 Add create_agent_notebook tool to MCP server
    - _Requirements: 1.1, 1.2_
  - [ ] 8.2 Add save_code_with_context tool that includes conversation context
    - _Requirements: 2.1, 2.2, 2.3_
  - [ ] 8.3 Add get_followup_messages tool for polling user messages
    - _Requirements: 3.2_
  - [ ] 8.4 Add respond_to_followup tool for sending responses
    - _Requirements: 3.3_
  - [ ] 8.5 Add register_webhook tool for webhook configuration
    - _Requirements: 5.1_

- [ ] 9. Flutter API Service Updates
  - [ ] 9.1 Add getAgentNotebooks() method to ApiService
    - _Requirements: 4.1_
  - [ ] 9.2 Add getSourceConversation(sourceId) method
    - _Requirements: 3.5_
  - [ ] 9.3 Add sendFollowupMessage(sourceId, message) method
    - _Requirements: 3.2_
  - [ ] 9.4 Add disconnectAgent(sessionId) method
    - _Requirements: 4.3_

- [ ] 10. Flutter UI - Agent Notebook Badge
  - [ ] 10.1 Create AgentNotebookBadge widget showing agent name and status
    - _Requirements: 1.4, 4.1_
  - [ ] 10.2 Update NotebookCard to display badge for agent notebooks
    - _Requirements: 1.4_

- [ ] 11. Flutter UI - Source Chat Interface
  - [ ] 11.1 Create SourceChatSheet widget for viewing/sending messages
    - _Requirements: 3.1, 3.2, 3.3_
  - [ ] 11.2 Add "Chat with Agent" button to code source detail screen
    - _Requirements: 3.1_
  - [ ] 11.3 Create SourceConversationProvider for managing chat state
    - _Requirements: 3.5_
  - [ ] 11.4 Display agent responses with code highlighting if code is included
    - _Requirements: 3.3_

- [ ] 12. Flutter UI - Agent Management
  - [ ] 12.1 Create AgentConnectionsScreen showing all connected agents
    - _Requirements: 4.1, 4.4_
  - [ ] 12.2 Add disconnect/reconnect functionality
    - _Requirements: 4.2, 4.3_
  - [ ] 12.3 Add route to agent connections from settings
    - _Requirements: 4.1_

- [ ] 13. Final Checkpoint
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- All tasks including property-based tests are required
- Backend tasks (1-7) should be completed before MCP and Flutter tasks
- The MCP server update (8) enables third-party agents to use the new features
- Flutter UI (10-12) provides the user-facing interface
