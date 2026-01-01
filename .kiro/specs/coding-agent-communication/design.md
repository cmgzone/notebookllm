# Design Document: Coding Agent Communication

## Overview

This design enables bidirectional communication between users and third-party coding agents. The system creates dedicated "Agent Notebooks" that store verified code sources and maintain conversation threads that route messages between the user's app and external coding agents via webhooks.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Third-Party Coding Agent                      │
│                  (Claude, Kiro, Cursor, etc.)                   │
└─────────────────────┬───────────────────────────────────────────┘
                      │ MCP Protocol
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                    MCP Server (Enhanced)                         │
│  New Tools:                                                      │
│  • create_agent_notebook - Create dedicated notebook             │
│  • save_code_with_context - Save code with conversation context │
│  • get_followup_messages - Poll for user messages               │
│  • respond_to_followup - Send response to user                  │
└─────────────────────┬───────────────────────────────────────────┘
                      │ HTTP API
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Backend API (Enhanced)                        │
│  New Endpoints:                                                  │
│  • POST /api/coding-agent/notebooks - Create agent notebook     │
│  • POST /api/coding-agent/sources/with-context - Save with ctx  │
│  • GET /api/coding-agent/followups - Get pending messages       │
│  • POST /api/coding-agent/followups/:id/respond - Send response │
│  • POST /api/coding-agent/webhook/register - Register webhook   │
└─────────────────────┬───────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Database (New Tables)                         │
│  • agent_sessions - Track agent connections                     │
│  • source_conversations - Store chat threads per source         │
│  • agent_webhooks - Store webhook configurations                │
└─────────────────────┬───────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Flutter App (Enhanced)                        │
│  • Agent Notebook badge/indicator                               │
│  • Source chat interface                                        │
│  • Agent connection status                                      │
│  • Follow-up message composer                                   │
└─────────────────────────────────────────────────────────────────┘
```

## Components and Interfaces

### 1. Agent Session Service

Manages the lifecycle of agent connections.

```typescript
interface AgentSession {
  id: string;
  userId: string;
  agentName: string;
  agentIdentifier: string;  // Unique ID for the agent type
  webhookUrl?: string;
  webhookSecret?: string;
  notebookId: string;
  status: 'active' | 'expired' | 'disconnected';
  lastActivity: Date;
  createdAt: Date;
  metadata: Record<string, any>;
}

interface AgentSessionService {
  createSession(userId: string, agentConfig: AgentConfig): Promise<AgentSession>;
  getSession(sessionId: string): Promise<AgentSession | null>;
  getSessionByAgent(userId: string, agentIdentifier: string): Promise<AgentSession | null>;
  updateActivity(sessionId: string): Promise<void>;
  expireSession(sessionId: string): Promise<void>;
}
```

### 2. Agent Notebook Service

Handles creation and management of agent-specific notebooks.

```typescript
interface AgentNotebook {
  id: string;
  userId: string;
  title: string;
  description: string;
  agentSessionId: string;
  agentName: string;
  agentIcon?: string;
  isAgentNotebook: true;
  createdAt: Date;
}

interface AgentNotebookService {
  createOrGetNotebook(userId: string, agentSession: AgentSession): Promise<AgentNotebook>;
  getAgentNotebooks(userId: string): Promise<AgentNotebook[]>;
  deleteNotebook(notebookId: string): Promise<void>;
}
```

### 3. Source Conversation Service

Manages chat threads on sources.

```typescript
interface SourceMessage {
  id: string;
  sourceId: string;
  role: 'user' | 'agent';
  content: string;
  timestamp: Date;
  metadata?: {
    codeModification?: string;
    attachments?: string[];
  };
}

interface SourceConversation {
  sourceId: string;
  messages: SourceMessage[];
  agentSessionId: string;
  lastMessageAt: Date;
}

interface SourceConversationService {
  addMessage(sourceId: string, role: 'user' | 'agent', content: string): Promise<SourceMessage>;
  getConversation(sourceId: string): Promise<SourceConversation>;
  getPendingUserMessages(agentSessionId: string): Promise<SourceMessage[]>;
}
```

### 4. Webhook Service

Handles communication with third-party agents.

```typescript
interface WebhookPayload {
  type: 'followup_message';
  sourceId: string;
  sourceTitle: string;
  sourceCode: string;
  sourceLanguage: string;
  message: string;
  conversationHistory: SourceMessage[];
  userId: string;
  timestamp: string;
}

interface WebhookResponse {
  success: boolean;
  response?: string;
  codeUpdate?: {
    code: string;
    description: string;
  };
}

interface WebhookService {
  registerWebhook(sessionId: string, url: string, secret: string): Promise<void>;
  sendFollowup(sessionId: string, payload: WebhookPayload): Promise<WebhookResponse>;
  verifySignature(payload: string, signature: string, secret: string): boolean;
}
```

## Data Models

### Database Schema

```sql
-- Agent sessions table
CREATE TABLE agent_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  agent_name TEXT NOT NULL,
  agent_identifier TEXT NOT NULL,
  webhook_url TEXT,
  webhook_secret TEXT,
  notebook_id UUID REFERENCES notebooks(id) ON DELETE SET NULL,
  status TEXT DEFAULT 'active',
  last_activity TIMESTAMPTZ DEFAULT NOW(),
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, agent_identifier)
);

-- Source conversations table
CREATE TABLE source_conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source_id UUID NOT NULL REFERENCES sources(id) ON DELETE CASCADE,
  agent_session_id UUID REFERENCES agent_sessions(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(source_id)
);

-- Conversation messages table
CREATE TABLE conversation_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES source_conversations(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('user', 'agent')),
  content TEXT NOT NULL,
  metadata JSONB DEFAULT '{}',
  is_read BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_agent_sessions_user ON agent_sessions(user_id);
CREATE INDEX idx_agent_sessions_status ON agent_sessions(status);
CREATE INDEX idx_conversation_messages_unread ON conversation_messages(conversation_id, is_read) WHERE is_read = false;
```

### Enhanced Source Model

```typescript
interface EnhancedSource {
  id: string;
  notebookId: string;
  title: string;
  type: 'code';
  content: string;
  metadata: {
    language: string;
    verification: VerificationResult;
    isVerified: boolean;
    verifiedAt: string;
    agentSessionId?: string;
    agentName?: string;
    originalContext?: string;  // The conversation that led to this code
  };
  createdAt: Date;
}
```


## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Agent Notebook Creation Idempotence

*For any* user and agent identifier, calling create_agent_notebook multiple times SHALL return the same notebook ID and not create duplicates.

**Validates: Requirements 1.1, 1.2, 1.3**

### Property 2: Source-Notebook Association

*For any* verified source saved by an agent, the source SHALL be associated with the correct Agent_Notebook and contain complete agent context (session ID, agent name, conversation context) in metadata.

**Validates: Requirements 2.1, 2.2, 2.3**

### Property 3: Conversation History Integrity

*For any* source with a conversation, adding a message SHALL increase the conversation length by one, and the message SHALL be retrievable with correct role, content, and timestamp.

**Validates: Requirements 3.5**

### Property 4: Webhook Payload Completeness

*For any* follow-up message sent to an agent, the webhook payload SHALL contain: source ID, source title, source code, source language, user message, and conversation history.

**Validates: Requirements 3.2, 5.2**

### Property 5: Webhook Authentication

*For any* webhook request, the signature generated from the payload and secret SHALL be verifiable, and requests with invalid signatures SHALL be rejected.

**Validates: Requirements 5.3**

### Property 6: Multiple Agent Sessions

*For any* user, creating sessions with different agent identifiers SHALL result in separate, independent sessions and notebooks that do not interfere with each other.

**Validates: Requirements 4.4**

### Property 7: Session Disconnect Cleanup

*For any* agent session that is disconnected, the associated notebook and sources SHALL remain accessible but marked as disconnected, and no new messages SHALL be routed to the webhook.

**Validates: Requirements 4.3**

## Error Handling

| Error Scenario | Handling Strategy |
|----------------|-------------------|
| Webhook timeout | Queue message, retry with exponential backoff (1s, 2s, 4s, 8s, max 5 retries) |
| Webhook 4xx error | Mark message as failed, notify user |
| Webhook 5xx error | Queue for retry |
| Invalid agent token | Return 401, prompt re-authentication |
| Session expired | Return 410, offer session renewal |
| Duplicate notebook request | Return existing notebook (idempotent) |

## Testing Strategy

### Unit Tests
- Agent session CRUD operations
- Notebook creation with metadata
- Message storage and retrieval
- Webhook signature generation/verification

### Property-Based Tests
- Notebook creation idempotence (Property 1)
- Source metadata completeness (Property 2)
- Conversation history integrity (Property 3)
- Webhook payload structure (Property 4)
- Signature verification (Property 5)
- Multi-session isolation (Property 6)

### Integration Tests
- End-to-end flow: Agent creates notebook → saves code → user sends followup → agent responds
- Webhook delivery and retry logic
- Session expiration and renewal

### Testing Framework
- Jest for unit and integration tests
- fast-check for property-based testing
- Minimum 100 iterations per property test
