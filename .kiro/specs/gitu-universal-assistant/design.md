# Design Document: Gitu - Universal AI Assistant

## Overview

Gitu is an autonomous, multi-platform AI assistant that operates as a background service, accessible through WhatsApp (via Baileys), Telegram, email, terminal, and the NotebookLLM Flutter app. The system is designed with the NotebookLLM Flutter app as the primary configuration interface, allowing users to manage API keys, select AI models, configure integrations, and control all aspects of Gitu's behavior.

## Vision

Create an always-available, context-aware AI assistant that:
- Works across all user touchpoints (WhatsApp, Telegram, email, terminal, notebookllm apps)
- Maintains persistent memory and session context
- Integrates with user's digital ecosystem (Gmail, Shopify, Notebooks, Files)
- Operates autonomously with strict permission controls
- Respects user's AI model preferences from NotebookLLM app
- Supports both platform API keys and user's personal keys

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         User Touchpoints                                     │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐    │
│  │ Flutter  │  │ WhatsApp │  │ Telegram │  │  Email   │  │ Terminal │    │
│  │   App    │  │ (Baileys)│  │   Bot    │  │  (IMAP)  │  │   CLI    │    │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘    │
└───────┼─────────────┼─────────────┼─────────────┼─────────────┼───────────┘
        │             │             │             │             │
        └─────────────┴─────────────┴─────────────┴─────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         Message Gateway                                      │
│  • Platform adapters (WhatsApp, Telegram, Email, CLI)                      │
│  • Message normalization and routing                                        │
│  • User identification and session management                               │
└─────────────────────────────┬───────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         Gitu Core Service                                    │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │   Session    │  │    Memory    │  │     AI       │  │  Permission  │  │
│  │   Manager    │  │    System    │  │   Router     │  │   Manager    │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘  │
└─────────────────────────────┬───────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         Integration Layer                                    │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐    │
│  │ Notebooks│  │  Gmail   │  │ Shopify  │  │  Files   │  │  Skills  │    │
│  │   API    │  │   API    │  │   API    │  │  System  │  │  Catalog │    │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘  └──────────┘    │
└─────────────────────────────┬───────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         Data Layer                                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │  PostgreSQL  │  │    Redis     │  │  File Store  │  │   Logs DB    │  │
│  │  (Sessions,  │  │   (Cache,    │  │  (Uploads,   │  │   (Audit,    │  │
│  │   Memory,    │  │    Queue)    │  │   Exports)   │  │   Activity)  │  │
│  │   Config)    │  │              │  │              │  │              │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

## System Components

### 1. Message Gateway

The gateway handles all incoming messages from different platforms and normalizes them into a common format.

#### Platform Adapters

**WhatsApp Adapter (Baileys)**
```typescript
interface WhatsAppAdapter {
  initialize(qrCallback: (qr: string) => void): Promise<void>;
  sendMessage(to: string, message: WhatsAppMessage): Promise<void>;
  onMessage(handler: (message: IncomingMessage) => void): void;
  disconnect(): Promise<void>;
  getConnectionState(): ConnectionState;
}

interface WhatsAppMessage {
  text?: string;
  image?: Buffer;
  document?: { data: Buffer; filename: string; mimetype: string };
  audio?: Buffer;
  formatting?: WhatsAppFormatting;
}

interface WhatsAppFormatting {
  bold?: [number, number][];
  italic?: [number, number][];
  monospace?: [number, number][];
}
```

**Telegram Adapter**
```typescript
interface TelegramAdapter {
  initialize(botToken: string): Promise<void>;
  sendMessage(chatId: string, message: TelegramMessage): Promise<void>;
  onMessage(handler: (message: IncomingMessage) => void): void;
  setCommands(commands: BotCommand[]): Promise<void>;
}

interface TelegramMessage {
  text?: string;
  markdown?: string;
  photo?: Buffer;
  document?: { data: Buffer; filename: string };
  replyMarkup?: InlineKeyboard;
}
```

**Email Adapter (IMAP/SMTP)**
```typescript
interface EmailAdapter {
  initialize(config: EmailConfig): Promise<void>;
  sendEmail(to: string, subject: string, body: string): Promise<void>;
  onEmail(handler: (email: IncomingEmail) => void): void;
  searchEmails(query: EmailQuery): Promise<Email[]>;
}
```


**Terminal CLI Adapter**
```typescript
interface TerminalAdapter {
  startREPL(): void;
  sendResponse(message: string): void;
  onCommand(handler: (command: string) => void): void;
  displayProgress(task: string, progress: number): void;
}
```

**Normalized Message Format**
```typescript
interface IncomingMessage {
  id: string;
  userId: string;
  platform: 'flutter' | 'whatsapp' | 'telegram' | 'email' | 'terminal';
  platformUserId: string;  // Platform-specific user ID
  content: MessageContent;
  timestamp: Date;
  metadata: Record<string, any>;
}

interface MessageContent {
  text?: string;
  attachments?: Attachment[];
  replyTo?: string;  // Message ID being replied to
}

interface Attachment {
  type: 'image' | 'document' | 'audio' | 'video';
  data: Buffer;
  filename?: string;
  mimetype: string;
}
```

### 2. Session Manager

Manages persistent sessions across platforms and conversations.

```typescript
interface SessionManager {
  getOrCreateSession(userId: string, platform: string): Promise<Session>;
  getSession(sessionId: string): Promise<Session | null>;
  updateSession(sessionId: string, updates: Partial<Session>): Promise<Session>;
  endSession(sessionId: string): Promise<void>;
  listUserSessions(userId: string): Promise<Session[]>;
}

interface Session {
  id: string;
  userId: string;
  platform: string;
  status: 'active' | 'paused' | 'ended';
  context: SessionContext;
  startedAt: Date;
  lastActivityAt: Date;
  endedAt?: Date;
}

interface SessionContext {
  conversationHistory: Message[];
  activeNotebooks: string[];  // Notebook IDs in context
  activeIntegrations: string[];  // Integration names
  currentTask?: Task;
  variables: Record<string, any>;  // Session variables
}

interface Message {
  role: 'user' | 'assistant' | 'system';
  content: string;
  timestamp: Date;
  platform: string;
}
```

### 3. Memory System

Stores and retrieves user-specific information for personalization.

```typescript
interface MemorySystem {
  storeMemory(userId: string, memory: Memory): Promise<void>;
  retrieveMemories(userId: string, query?: string): Promise<Memory[]>;
  updateMemory(memoryId: string, updates: Partial<Memory>): Promise<Memory>;
  deleteMemory(memoryId: string): Promise<void>;
  searchMemories(userId: string, query: string): Promise<Memory[]>;
}

interface Memory {
  id: string;
  userId: string;
  category: 'personal' | 'work' | 'preference' | 'fact' | 'context';
  content: string;
  source: string;  // Where this memory came from
  confidence: number;  // 0-1, how confident we are
  tags: string[];
  createdAt: Date;
  lastAccessedAt: Date;
  accessCount: number;
}
```


### 4. AI Router

Routes requests to appropriate AI models based on user preferences and task requirements.

```typescript
interface AIRouter {
  route(request: AIRequest): Promise<AIResponse>;
  selectModel(task: TaskType, userPreferences: ModelPreferences): AIModel;
  fallback(primaryModel: AIModel, error: Error): AIModel | null;
  estimateTokens(content: string): number;
}

interface AIRequest {
  userId: string;
  sessionId: string;
  prompt: string;
  context: string[];
  taskType: TaskType;
  maxTokens?: number;
  temperature?: number;
}

type TaskType = 'chat' | 'research' | 'coding' | 'analysis' | 'summarization' | 'creative';

interface ModelPreferences {
  defaultModel: string;  // From NotebookLLM app settings
  taskSpecificModels: Record<TaskType, string>;
  apiKeySource: 'platform' | 'personal';
  personalKeys?: {
    openrouter?: string;
    gemini?: string;
    openai?: string;
    anthropic?: string;
  };
}

interface AIModel {
  provider: 'openrouter' | 'gemini' | 'openai' | 'anthropic';
  modelId: string;
  contextWindow: number;
  costPer1kTokens: number;
}

interface AIResponse {
  content: string;
  model: string;
  tokensUsed: number;
  cost: number;
  finishReason: 'stop' | 'length' | 'error';
}
```

### 5. Permission Manager

Controls access to integrations and resources with granular permissions.

```typescript
interface PermissionManager {
  grantPermission(userId: string, permission: Permission): Promise<void>;
  revokePermission(userId: string, permissionId: string): Promise<void>;
  checkPermission(userId: string, resource: string, action: string): Promise<boolean>;
  listPermissions(userId: string): Promise<Permission[]>;
  requestPermission(userId: string, permission: Permission): Promise<PermissionRequest>;
}

interface Permission {
  id: string;
  userId: string;
  resource: string;  // 'gmail', 'shopify', 'files', 'notebooks'
  actions: ('read' | 'write' | 'execute' | 'delete')[];
  scope?: PermissionScope;
  grantedAt: Date;
  expiresAt?: Date;
}

interface PermissionScope {
  // For files
  allowedPaths?: string[];
  // For email
  emailLabels?: string[];
  // For notebooks
  notebookIds?: string[];
}

interface PermissionRequest {
  id: string;
  userId: string;
  permission: Permission;
  reason: string;
  status: 'pending' | 'approved' | 'denied';
  requestedAt: Date;
  respondedAt?: Date;
}
```

### 6. MCP Integration Hub

Gitu can access and use all MCP tools - both built-in NotebookLLM MCP tools and custom MCP servers installed by the user.

```typescript
interface MCPIntegrationHub {
  // Discover available MCP tools
  discoverTools(): Promise<MCPTool[]>;
  
  // Execute MCP tool
  executeTool(toolName: string, params: any, userId: string): Promise<any>;
  
  // Check if user has access to specific MCP tool
  checkToolAccess(userId: string, toolName: string): Promise<boolean>;
  
  // Get tool metadata
  getToolMetadata(toolName: string): Promise<MCPToolMetadata>;
}

interface MCPTool {
  name: string;
  server: string;  // MCP server name
  description: string;
  inputSchema: any;  // JSON schema
  category: 'notebook' | 'github' | 'planning' | 'code' | 'custom';
}

interface MCPToolMetadata {
  name: string;
  description: string;
  parameters: MCPParameter[];
  examples: MCPExample[];
  requiredPermissions: string[];
}

interface MCPParameter {
  name: string;
  type: string;
  description: string;
  required: boolean;
  default?: any;
}

interface MCPExample {
  description: string;
  input: any;
  output: any;
}
```

**Built-in NotebookLLM MCP Tools Available to Gitu:**

1. **Notebook Management**
   - `list_notebooks` - List user's notebooks
   - `get_source` - Get source content
   - `search_sources` - Search across sources
   - `create_agent_notebook` - Create notebook for Gitu
   - `save_code_with_context` - Save code with conversation context

2. **Code Verification**
   - `verify_code` - Verify code quality
   - `batch_verify` - Verify multiple files
   - `analyze_code` - Deep code analysis
   - `review_code` - AI code review

3. **GitHub Integration**
   - `github_list_repos` - List repositories
   - `github_get_file` - Get file content
   - `github_search_code` - Search code
   - `github_create_issue` - Create issues
   - `github_add_as_source` - Import to notebook

4. **Planning Mode**
   - `list_plans` - List user's plans
   - `get_plan` - Get plan details
   - `create_plan` - Create new plan
   - `create_task` - Add tasks
   - `update_task_status` - Update progress
   - `complete_task` - Mark task complete

5. **Agent Skills**
   - `list_agent_skills` - List available skills
   - `create_agent_skill` - Create custom skill
   - `update_agent_skill` - Update skill
   - `delete_agent_skill` - Remove skill

6. **Utilities**
   - `get_current_time` - Get accurate time context
   - `web_search` - Search the web
   - `get_quota` - Check API quotas
   - `get_usage_stats` - Get usage analytics

**Custom MCP Servers:**
Gitu can also use any custom MCP servers the user has installed (e.g., database tools, cloud services, custom APIs).


### 7. VPS & Server Management

Gitu can access and manage VPS accounts and remote servers with proper authentication and permissions.

```typescript
interface VPSManager {
  // Connect to VPS
  connectVPS(userId: string, config: VPSConfig): Promise<VPSConnection>;
  
  // Execute commands on VPS
  executeCommand(connectionId: string, command: string): Promise<CommandResult>;
  
  // File operations on VPS
  readFile(connectionId: string, path: string): Promise<string>;
  writeFile(connectionId: string, path: string, content: string): Promise<void>;
  listDirectory(connectionId: string, path: string): Promise<FileInfo[]>;
  
  // Process management
  listProcesses(connectionId: string): Promise<ProcessInfo[]>;
  startProcess(connectionId: string, command: string): Promise<ProcessInfo>;
  stopProcess(connectionId: string, pid: number): Promise<void>;
  
  // System monitoring
  getSystemStats(connectionId: string): Promise<SystemStats>;
  getLogs(connectionId: string, logPath: string, lines?: number): Promise<string>;
  
  // Deployment operations
  deployApplication(connectionId: string, config: DeployConfig): Promise<DeploymentResult>;
  restartService(connectionId: string, serviceName: string): Promise<void>;
  
  // Disconnect
  disconnect(connectionId: string): Promise<void>;
}

interface VPSConfig {
  id: string;
  name: string;
  host: string;
  port: number;
  authMethod: 'password' | 'ssh-key' | 'ssh-agent';
  username: string;
  password?: string;  // Encrypted
  privateKey?: string;  // Encrypted
  allowedCommands?: string[];  // Whitelist of allowed commands
  allowedPaths?: string[];  // Whitelist of accessible paths
}

interface VPSConnection {
  id: string;
  userId: string;
  vpsConfigId: string;
  status: 'connected' | 'disconnected' | 'error';
  connectedAt: Date;
  lastActivityAt: Date;
}

interface CommandResult {
  stdout: string;
  stderr: string;
  exitCode: number;
  executedAt: Date;
  duration: number;  // milliseconds
}

interface FileInfo {
  name: string;
  path: string;
  type: 'file' | 'directory' | 'symlink';
  size: number;
  permissions: string;
  owner: string;
  modifiedAt: Date;
}

interface ProcessInfo {
  pid: number;
  name: string;
  command: string;
  cpu: number;  // percentage
  memory: number;  // MB
  status: 'running' | 'sleeping' | 'stopped';
  startedAt: Date;
}

interface SystemStats {
  cpu: {
    usage: number;  // percentage
    cores: number;
    loadAverage: [number, number, number];  // 1, 5, 15 min
  };
  memory: {
    total: number;  // MB
    used: number;
    free: number;
    cached: number;
  };
  disk: {
    total: number;  // GB
    used: number;
    free: number;
    usage: number;  // percentage
  };
  network: {
    bytesIn: number;
    bytesOut: number;
  };
  uptime: number;  // seconds
}

interface DeployConfig {
  repository?: string;
  branch?: string;
  buildCommand?: string;
  startCommand?: string;
  envVars?: Record<string, string>;
  workingDirectory: string;
}

interface DeploymentResult {
  success: boolean;
  logs: string[];
  errors?: string[];
  deployedAt: Date;
  duration: number;
}
```

**VPS Provider Integrations:**

```typescript
interface VPSProviderManager {
  // Cloud provider APIs
  listInstances(provider: VPSProvider, credentials: ProviderCredentials): Promise<VPSInstance[]>;
  createInstance(provider: VPSProvider, config: InstanceConfig): Promise<VPSInstance>;
  deleteInstance(provider: VPSProvider, instanceId: string): Promise<void>;
  resizeInstance(provider: VPSProvider, instanceId: string, size: string): Promise<void>;
  
  // Snapshots and backups
  createSnapshot(provider: VPSProvider, instanceId: string): Promise<Snapshot>;
  restoreSnapshot(provider: VPSProvider, snapshotId: string): Promise<void>;
  
  // Monitoring
  getMetrics(provider: VPSProvider, instanceId: string): Promise<InstanceMetrics>;
}

type VPSProvider = 'digitalocean' | 'linode' | 'vultr' | 'aws-ec2' | 'gcp-compute' | 'azure-vm' | 'hetzner' | 'custom';

interface ProviderCredentials {
  provider: VPSProvider;
  apiKey?: string;
  accessKeyId?: string;
  secretAccessKey?: string;
  token?: string;
}

interface VPSInstance {
  id: string;
  name: string;
  provider: VPSProvider;
  ipAddress: string;
  region: string;
  size: string;
  status: 'active' | 'stopped' | 'creating' | 'error';
  os: string;
  createdAt: Date;
}

interface InstanceConfig {
  name: string;
  region: string;
  size: string;
  image: string;  // OS image
  sshKeys?: string[];
  userData?: string;  // Cloud-init script
  tags?: Record<string, string>;
}

interface Snapshot {
  id: string;
  name: string;
  instanceId: string;
  size: number;  // GB
  createdAt: Date;
}

interface InstanceMetrics {
  cpu: number[];  // Time series
  memory: number[];
  disk: number[];
  network: {
    inbound: number[];
    outbound: number[];
  };
  timestamp: Date[];
}
```

**Security & Safety Features:**

```typescript
interface VPSSecurity {
  // Command validation
  validateCommand(command: string, allowedCommands: string[]): boolean;
  
  // Path validation
  validatePath(path: string, allowedPaths: string[]): boolean;
  
  // Dangerous command detection
  isDangerousCommand(command: string): { dangerous: boolean; reason?: string };
  
  // Audit logging
  logVPSAction(action: VPSAuditLog): Promise<void>;
  
  // Rate limiting
  checkRateLimit(userId: string, action: string): Promise<boolean>;
}

interface VPSAuditLog {
  id: string;
  userId: string;
  vpsConfigId: string;
  action: 'connect' | 'execute' | 'read' | 'write' | 'deploy' | 'delete';
  command?: string;
  path?: string;
  success: boolean;
  error?: string;
  timestamp: Date;
}
```

**Example VPS Operations via Gitu:**

1. **Deploy Application**
   - User: "Deploy my app to production server"
   - Gitu: Connects to VPS, pulls latest code, runs build, restarts service

2. **Monitor Server**
   - User: "Check server health"
   - Gitu: Returns CPU, memory, disk usage, running processes

3. **View Logs**
   - User: "Show me the last 50 lines of nginx error log"
   - Gitu: Reads and displays log file

4. **Manage Processes**
   - User: "Restart the API service"
   - Gitu: Executes systemctl restart command

5. **File Management**
   - User: "Update the config file with new API key"
   - Gitu: Edits file on server (with confirmation)

6. **Backup & Restore**
   - User: "Create a snapshot of the database server"
   - Gitu: Uses provider API to create snapshot


### 8. Gmail Integration

Gitu can access, manage, and automate Gmail operations with OAuth 2.0 authentication.

```typescript
interface GmailManager {
  // Authentication
  authenticateGmail(userId: string, authCode: string): Promise<GmailConnection>;
  refreshToken(userId: string): Promise<void>;
  disconnectGmail(userId: string): Promise<void>;
  
  // Read operations
  listEmails(userId: string, query: EmailQuery): Promise<Email[]>;
  getEmail(userId: string, emailId: string): Promise<EmailDetail>;
  searchEmails(userId: string, searchQuery: string): Promise<Email[]>;
  getThread(userId: string, threadId: string): Promise<EmailThread>;
  
  // Write operations
  sendEmail(userId: string, email: OutgoingEmail): Promise<SentEmail>;
  replyToEmail(userId: string, emailId: string, reply: EmailReply): Promise<SentEmail>;
  forwardEmail(userId: string, emailId: string, to: string[]): Promise<SentEmail>;
  draftEmail(userId: string, draft: OutgoingEmail): Promise<Draft>;
  
  // Organization
  addLabel(userId: string, emailId: string, label: string): Promise<void>;
  removeLabel(userId: string, emailId: string, label: string): Promise<void>;
  archiveEmail(userId: string, emailId: string): Promise<void>;
  deleteEmail(userId: string, emailId: string): Promise<void>;
  markAsRead(userId: string, emailId: string): Promise<void>;
  markAsUnread(userId: string, emailId: string): Promise<void>;
  starEmail(userId: string, emailId: string): Promise<void>;
  
  // Filters and rules
  createFilter(userId: string, filter: EmailFilter): Promise<void>;
  listFilters(userId: string): Promise<EmailFilter[]>;
  deleteFilter(userId: string, filterId: string): Promise<void>;
  
  // Labels
  listLabels(userId: string): Promise<Label[]>;
  createLabel(userId: string, name: string): Promise<Label>;
  deleteLabel(userId: string, labelId: string): Promise<void>;
  
  // Analytics
  getEmailStats(userId: string, period: 'day' | 'week' | 'month'): Promise<EmailStats>;
  summarizeThread(userId: string, threadId: string): Promise<string>;
  extractActionItems(userId: string, emailId: string): Promise<ActionItem[]>;
}

interface GmailConnection {
  userId: string;
  email: string;
  accessToken: string;  // Encrypted
  refreshToken: string;  // Encrypted
  expiresAt: Date;
  scopes: string[];
  connectedAt: Date;
}

interface EmailQuery {
  labelIds?: string[];
  from?: string;
  to?: string;
  subject?: string;
  hasAttachment?: boolean;
  isUnread?: boolean;
  after?: Date;
  before?: Date;
  maxResults?: number;
  pageToken?: string;
}

interface Email {
  id: string;
  threadId: string;
  from: EmailAddress;
  to: EmailAddress[];
  cc?: EmailAddress[];
  bcc?: EmailAddress[];
  subject: string;
  snippet: string;  // First 200 chars
  date: Date;
  labels: string[];
  isUnread: boolean;
  isStarred: boolean;
  hasAttachments: boolean;
  attachmentCount: number;
}

interface EmailDetail extends Email {
  body: {
    text: string;
    html: string;
  };
  attachments: Attachment[];
  headers: Record<string, string>;
  inReplyTo?: string;
  references?: string[];
}

interface EmailAddress {
  name?: string;
  email: string;
}

interface EmailThread {
  id: string;
  subject: string;
  messages: EmailDetail[];
  participants: EmailAddress[];
  messageCount: number;
  lastMessageDate: Date;
}

interface OutgoingEmail {
  to: EmailAddress[];
  cc?: EmailAddress[];
  bcc?: EmailAddress[];
  subject: string;
  body: string;
  bodyType: 'text' | 'html';
  attachments?: EmailAttachment[];
  replyTo?: string;
  inReplyTo?: string;  // For threading
}

interface EmailReply {
  body: string;
  bodyType: 'text' | 'html';
  attachments?: EmailAttachment[];
  replyAll?: boolean;
}

interface EmailAttachment {
  filename: string;
  mimeType: string;
  data: Buffer | string;  // Base64 encoded
  size: number;
}

interface SentEmail {
  id: string;
  threadId: string;
  sentAt: Date;
}

interface Draft {
  id: string;
  message: OutgoingEmail;
  createdAt: Date;
  updatedAt: Date;
}

interface EmailFilter {
  id: string;
  criteria: {
    from?: string;
    to?: string;
    subject?: string;
    query?: string;
    hasAttachment?: boolean;
  };
  action: {
    addLabelIds?: string[];
    removeLabelIds?: string[];
    forward?: string;
    markAsRead?: boolean;
    archive?: boolean;
    delete?: boolean;
  };
}

interface Label {
  id: string;
  name: string;
  type: 'system' | 'user';
  messageListVisibility: 'show' | 'hide';
  labelListVisibility: 'labelShow' | 'labelHide';
  color?: {
    backgroundColor: string;
    textColor: string;
  };
}

interface EmailStats {
  totalEmails: number;
  unreadEmails: number;
  sentEmails: number;
  receivedEmails: number;
  topSenders: { email: string; count: number }[];
  topRecipients: { email: string; count: number }[];
  averageResponseTime: number;  // minutes
  emailsByDay: { date: string; count: number }[];
}

interface ActionItem {
  text: string;
  type: 'task' | 'deadline' | 'question' | 'request';
  priority: 'low' | 'medium' | 'high';
  dueDate?: Date;
  assignee?: string;
}
```

**Gmail AI Features:**

```typescript
interface GmailAI {
  // Smart compose
  suggestReply(emailId: string, context?: string): Promise<string[]>;
  
  // Email summarization
  summarizeEmail(emailId: string): Promise<EmailSummary>;
  summarizeThread(threadId: string): Promise<ThreadSummary>;
  
  // Smart categorization
  categorizeEmail(emailId: string): Promise<EmailCategory>;
  
  // Priority detection
  detectPriority(emailId: string): Promise<PriorityLevel>;
  
  // Action extraction
  extractActions(emailId: string): Promise<ActionItem[]>;
  
  // Sentiment analysis
  analyzeSentiment(emailId: string): Promise<SentimentAnalysis>;
  
  // Auto-response
  generateAutoResponse(emailId: string, tone: 'professional' | 'casual' | 'friendly'): Promise<string>;
  
  // Email drafting
  draftEmailFromPrompt(prompt: string, context?: EmailContext): Promise<OutgoingEmail>;
}

interface EmailSummary {
  summary: string;  // 2-3 sentences
  keyPoints: string[];
  actionItems: ActionItem[];
  sentiment: 'positive' | 'neutral' | 'negative';
  urgency: 'low' | 'medium' | 'high';
}

interface ThreadSummary {
  summary: string;
  participants: EmailAddress[];
  keyDecisions: string[];
  openQuestions: string[];
  actionItems: ActionItem[];
  timeline: { date: Date; event: string }[];
}

type EmailCategory = 'work' | 'personal' | 'promotional' | 'social' | 'updates' | 'forums' | 'spam';

type PriorityLevel = 'urgent' | 'high' | 'normal' | 'low';

interface SentimentAnalysis {
  overall: 'positive' | 'neutral' | 'negative';
  score: number;  // -1 to 1
  emotions: { emotion: string; confidence: number }[];
}

interface EmailContext {
  previousEmails?: string[];
  relatedDocuments?: string[];
  userPreferences?: {
    tone: string;
    signature: string;
    commonPhrases: string[];
  };
}
```

**Gmail Automation Rules:**

```typescript
interface GmailAutomation {
  // Create automation rule
  createRule(userId: string, rule: AutomationRule): Promise<void>;
  
  // List rules
  listRules(userId: string): Promise<AutomationRule[]>;
  
  // Execute rule
  executeRule(userId: string, ruleId: string, emailId: string): Promise<void>;
  
  // Disable/enable rule
  toggleRule(userId: string, ruleId: string, enabled: boolean): Promise<void>;
}

interface AutomationRule {
  id: string;
  name: string;
  description: string;
  trigger: EmailTrigger;
  conditions: EmailCondition[];
  actions: EmailAction[];
  enabled: boolean;
  createdAt: Date;
}

interface EmailTrigger {
  type: 'new_email' | 'label_added' | 'scheduled';
  schedule?: string;  // Cron expression for scheduled triggers
}

interface EmailCondition {
  field: 'from' | 'to' | 'subject' | 'body' | 'label' | 'attachment';
  operator: 'contains' | 'equals' | 'starts_with' | 'ends_with' | 'matches_regex';
  value: string;
}

interface EmailAction {
  type: 'reply' | 'forward' | 'label' | 'archive' | 'delete' | 'mark_read' | 'star' | 'notify' | 'create_task';
  params: Record<string, any>;
}
```

**Example Gmail Operations via Gitu:**

1. **Smart Email Management**
   - User: "Summarize my unread emails from today"
   - Gitu: Fetches unread emails, generates summaries with action items

2. **Auto-Reply**
   - User: "Reply to John's email saying I'll review it tomorrow"
   - Gitu: Drafts professional reply, shows preview, sends with confirmation

3. **Email Search**
   - User: "Find all emails from Sarah about the project proposal"
   - Gitu: Searches and displays matching emails with summaries

4. **Bulk Operations**
   - User: "Archive all promotional emails from last month"
   - Gitu: Identifies promotional emails, archives them

5. **Smart Filters**
   - User: "Create a filter to label all emails from my boss as Important"
   - Gitu: Creates Gmail filter with specified criteria

6. **Email Analytics**
   - User: "Show me my email stats for this week"
   - Gitu: Displays sent/received counts, top contacts, response times

7. **Action Extraction**
   - User: "What tasks do I have from my emails today?"
   - Gitu: Extracts action items from emails, creates task list

8. **Thread Management**
   - User: "Summarize the conversation with the client about the contract"
   - Gitu: Finds thread, generates comprehensive summary with key points


## Critical Safety & Governance Systems

### 9. Cost & Quota Governor

Protects users and platform from runaway costs.

```typescript
interface UsageGovernor {
  // Check if operation is within budget
  checkBudget(userId: string, estimatedCost: number): Promise<BudgetCheck>;
  
  // Track usage
  recordUsage(userId: string, usage: UsageRecord): Promise<void>;
  
  // Get current usage
  getCurrentUsage(userId: string, period: 'hour' | 'day' | 'month'): Promise<UsageStats>;
  
  // Set limits
  setLimits(userId: string, limits: UsageLimits): Promise<void>;
  
  // Alert on threshold
  checkThresholds(userId: string): Promise<ThresholdAlert[]>;
}

interface BudgetCheck {
  allowed: boolean;
  reason?: string;
  currentSpend: number;
  limit: number;
  remaining: number;
  suggestedAction?: 'downgrade_model' | 'use_cache' | 'wait';
}

interface UsageRecord {
  userId: string;
  operation: string;
  model: string;
  tokensUsed: number;
  costUSD: number;
  timestamp: Date;
  platform: string;
}

interface UsageStats {
  totalCostUSD: number;
  totalTokens: number;
  operationCount: number;
  byModel: Record<string, { tokens: number; cost: number }>;
  byPlatform: Record<string, { tokens: number; cost: number }>;
  topOperations: { operation: string; cost: number; count: number }[];
}

interface UsageLimits {
  dailyLimitUSD: number;
  perTaskLimitUSD: number;
  monthlyLimitUSD: number;
  hardStop: boolean;  // If true, stop all operations when limit reached
  alertThresholds: number[];  // e.g., [0.5, 0.75, 0.9] for 50%, 75%, 90%
}

interface ThresholdAlert {
  threshold: number;
  currentUsage: number;
  limit: number;
  percentage: number;
  message: string;
}

// Shadow cost estimator
interface CostEstimator {
  estimateCost(prompt: string, model: string, context: string[]): Promise<CostEstimate>;
  suggestCheaperModel(currentModel: string, task: TaskType): AIModel | null;
}

interface CostEstimate {
  estimatedTokens: number;
  estimatedCostUSD: number;
  confidence: number;  // 0-1
  alternatives: { model: string; estimatedCost: number }[];
}
```

### 10. Enhanced Memory System with Trust Layer

Memory system with verification and confidence tracking.

```typescript
interface EnhancedMemory extends Memory {
  verified: boolean;  // User confirmed this is accurate
  lastConfirmedByUser?: Date;
  confidence: number;  // 0-1, AI's confidence
  verificationRequired: boolean;  // Must be verified before use in actions
  contradictions: string[];  // IDs of memories that contradict this
}

interface MemoryVerification {
  // Request user verification
  requestVerification(memoryId: string, reason: string): Promise<VerificationRequest>;
  
  // User confirms or corrects
  verifyMemory(memoryId: string, correct: boolean, correction?: string): Promise<void>;
  
  // Check if memory can be used for actions
  canUseForAction(memoryId: string): boolean;
  
  // Detect contradictions
  detectContradictions(newMemory: Memory): Promise<Memory[]>;
}

interface VerificationRequest {
  id: string;
  memoryId: string;
  content: string;
  reason: string;
  status: 'pending' | 'verified' | 'corrected' | 'rejected';
  requestedAt: Date;
  respondedAt?: Date;
}

// Memory safety rules
const MEMORY_SAFETY_RULES = {
  // Never execute actions based on unverified memories
  requireVerificationForActions: true,
  
  // Auto-verify low-risk memories after N confirmations
  autoVerifyThreshold: 3,
  
  // Expire unverified memories after N days
  unverifiedExpiryDays: 30,
  
  // Always ask user before using memory for:
  criticalActions: ['delete', 'deploy', 'send_email', 'execute_command'],
};
```

### 11. VPS Security Hardening

Enhanced security for VPS operations with mandatory safeguards.

```typescript
interface VPSSecurityEnhanced extends VPSSecurity {
  // Dry-run mode
  dryRun(command: string, connectionId: string): Promise<DryRunResult>;
  
  // Confirmation requirements
  requiresConfirmation(command: string): ConfirmationRequirement;
  
  // Command classification
  classifyCommand(command: string): CommandClassification;
  
  // Immutable audit log
  appendAuditLog(log: VPSAuditLog): Promise<void>;  // Append-only
}

interface DryRunResult {
  command: string;
  wouldExecute: boolean;
  estimatedImpact: {
    filesAffected: string[];
    processesAffected: string[];
    diskSpaceChange: number;
    risk: 'low' | 'medium' | 'high' | 'critical';
  };
  warnings: string[];
  recommendations: string[];
}

interface ConfirmationRequirement {
  required: boolean;
  reason: string;
  confirmationChannel: 'flutter_app' | 'any';  // flutter_app = must confirm in app
  timeout: number;  // seconds to wait for confirmation
  showDryRun: boolean;
}

interface CommandClassification {
  category: 'read' | 'write' | 'execute' | 'destructive' | 'system';
  risk: 'low' | 'medium' | 'high' | 'critical';
  requiresConfirmation: boolean;
  allowedWithoutConfirmation: boolean;
  blockedCommands: string[];  // Never allow these
}

// Destructive command patterns (always require confirmation)
const DESTRUCTIVE_PATTERNS = [
  /^rm\s+-rf/,
  /^sudo\s+rm/,
  /^systemctl\s+stop/,
  /^systemctl\s+disable/,
  /^shutdown/,
  /^reboot/,
  /^mkfs/,
  /^dd\s+if=/,
  /^:(){ :|:& };:/,  // Fork bomb
];

// Never allow these commands
const BLOCKED_COMMANDS = [
  'rm -rf /',
  'rm -rf /*',
  'mkfs.ext4 /dev/sda',
  ':(){ :|:& };:',  // Fork bomb
];

// Confirmation rules
const VPS_CONFIRMATION_RULES = {
  // Always require Flutter app confirmation for:
  destructiveCommands: true,
  systemCommands: true,
  deployments: true,
  
  // Never approve via WhatsApp alone:
  whatsappCannotApprove: ['rm', 'systemctl', 'deploy', 'delete'],
  
  // Show dry-run before confirmation:
  showDryRunFor: ['deploy', 'rm', 'systemctl'],
};
```

### 12. Identity Unification Layer

Master identity system linking all platforms.

```typescript
interface IdentityManager {
  // Get canonical user ID
  getCanonicalUserId(platformUserId: string, platform: string): Promise<string>;
  
  // Link platform account
  linkAccount(userId: string, platform: string, platformUserId: string): Promise<void>;
  
  // Unlink platform account
  unlinkAccount(userId: string, platform: string): Promise<void>;
  
  // List linked accounts
  listLinkedAccounts(userId: string): Promise<LinkedAccount[]>;
  
  // Verify identity across platforms
  verifyIdentity(userId: string, platform: string, proof: IdentityProof): Promise<boolean>;
}

interface LinkedAccount {
  platform: 'flutter' | 'whatsapp' | 'telegram' | 'email' | 'terminal';
  platformUserId: string;
  displayName: string;
  linkedAt: Date;
  lastUsedAt: Date;
  verified: boolean;
  isPrimary: boolean;  // Flutter app is always primary
}

interface IdentityProof {
  type: 'qr_code' | 'verification_code' | 'oauth' | 'email_link';
  token: string;
  expiresAt: Date;
}

// Identity rules
const IDENTITY_RULES = {
  // Flutter app is the authority
  primaryPlatform: 'flutter',
  
  // Require verification for sensitive operations
  requireVerificationFor: ['link_account', 'change_permissions', 'delete_data'],
  
  // Platform trust levels
  trustLevels: {
    flutter: 'full',      // Can do anything
    telegram: 'high',     // Can do most things
    whatsapp: 'medium',   // Limited to safe operations
    email: 'medium',      // Limited to safe operations
    terminal: 'high',     // Can do most things
  },
};
```


### 13. Background Agent Scheduler

Enables autonomous operation with scheduled tasks and event triggers.

```typescript
interface AgentScheduler {
  // Schedule recurring task
  scheduleTask(userId: string, task: ScheduledTask): Promise<string>;
  
  // Cancel scheduled task
  cancelTask(userId: string, taskId: string): Promise<void>;
  
  // List scheduled tasks
  listTasks(userId: string): Promise<ScheduledTask[]>;
  
  // Run heartbeat (system health check)
  runHeartbeat(): Promise<HeartbeatResult>;
  
  // Execute task now
  executeTaskNow(userId: string, taskId: string): Promise<TaskExecutionResult>;
  
  // Pause/resume task
  toggleTask(userId: string, taskId: string, enabled: boolean): Promise<void>;
}

interface ScheduledTask {
  id: string;
  userId: string;
  name: string;
  description: string;
  trigger: TaskTrigger;
  action: TaskAction;
  enabled: boolean;
  lastRun?: Date;
  nextRun?: Date;
  runCount: number;
  failureCount: number;
  createdAt: Date;
}

interface TaskTrigger {
  type: 'cron' | 'interval' | 'event' | 'webhook';
  
  // For cron
  cronExpression?: string;  // e.g., "0 9 * * *" = daily at 9am
  
  // For interval
  intervalMinutes?: number;
  
  // For event
  event?: {
    source: 'gmail' | 'github' | 'vps' | 'notebook';
    eventType: string;  // e.g., 'new_email', 'issue_created', 'server_down'
    filter?: Record<string, any>;
  };
  
  // For webhook
  webhookUrl?: string;
}

interface TaskAction {
  type: 'check_health' | 'summarize_emails' | 'backup' | 'monitor' | 'notify' | 'custom';
  
  // Action parameters
  params: Record<string, any>;
  
  // Notification settings
  notifyOnSuccess?: boolean;
  notifyOnFailure?: boolean;
  notificationChannels?: ('flutter' | 'whatsapp' | 'telegram' | 'email')[];
  
  // Retry settings
  maxRetries?: number;
  retryDelayMinutes?: number;
}

interface HeartbeatResult {
  timestamp: Date;
  status: 'healthy' | 'degraded' | 'critical';
  checks: {
    database: boolean;
    redis: boolean;
    whatsapp: boolean;
    telegram: boolean;
    gmail: boolean;
    vps: boolean;
  };
  issues: string[];
}

interface TaskExecutionResult {
  taskId: string;
  success: boolean;
  output: any;
  error?: string;
  duration: number;  // milliseconds
  executedAt: Date;
}

// Example scheduled tasks
const EXAMPLE_TASKS = [
  {
    name: 'Daily Email Summary',
    trigger: { type: 'cron', cronExpression: '0 9 * * *' },
    action: {
      type: 'summarize_emails',
      params: { period: 'yesterday' },
      notifyOnSuccess: true,
      notificationChannels: ['flutter', 'whatsapp'],
    },
  },
  {
    name: 'Server Health Check',
    trigger: { type: 'interval', intervalMinutes: 360 },  // Every 6 hours
    action: {
      type: 'check_health',
      params: { vpsIds: ['prod-server-1', 'prod-server-2'] },
      notifyOnFailure: true,
      notificationChannels: ['flutter', 'telegram'],
    },
  },
  {
    name: 'GitHub Issue Monitor',
    trigger: {
      type: 'event',
      event: {
        source: 'github',
        eventType: 'issue_created',
        filter: { repo: 'my-project', label: 'bug' },
      },
    },
    action: {
      type: 'notify',
      params: { message: 'New bug reported in my-project' },
      notificationChannels: ['flutter', 'telegram'],
    },
  },
];
```

### 14. WhatsApp Connection Health Monitor

Monitors WhatsApp (Baileys) connection and handles degradation gracefully.

```typescript
interface WhatsAppHealthMonitor {
  // Get connection health
  getConnectionHealth(): Promise<ConnectionHealth>;
  
  // Monitor connection
  startMonitoring(callback: (health: ConnectionHealth) => void): void;
  
  // Handle connection issues
  handleConnectionIssue(issue: ConnectionIssue): Promise<void>;
  
  // Reconnect
  reconnect(): Promise<boolean>;
}

interface ConnectionHealth {
  status: 'stable' | 'degraded' | 'offline' | 'banned';
  lastMessageSent?: Date;
  lastMessageReceived?: Date;
  reconnectAttempts: number;
  uptime: number;  // seconds
  issues: ConnectionIssue[];
}

interface ConnectionIssue {
  type: 'timeout' | 'rate_limit' | 'session_expired' | 'banned' | 'network_error';
  severity: 'low' | 'medium' | 'high' | 'critical';
  message: string;
  occurredAt: Date;
  resolved: boolean;
}

// WhatsApp reliability strategy
const WHATSAPP_STRATEGY = {
  // Treat as best-effort
  reliability: 'best-effort',
  
  // Fallback to Telegram if WhatsApp down
  fallbackPlatform: 'telegram',
  
  // Notify user of connection issues
  notifyOnDegradation: true,
  
  // Auto-reconnect settings
  autoReconnect: true,
  maxReconnectAttempts: 5,
  reconnectDelaySeconds: 60,
  
  // Push critical config to Flutter app
  criticalConfigPlatform: 'flutter',
};
```


## Data Models

### Database Schema

```sql
-- Users table (extends existing NotebookLLM users)
-- Gitu-specific fields added to existing users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS gitu_enabled BOOLEAN DEFAULT false;
ALTER TABLE users ADD COLUMN IF NOT EXISTS gitu_settings JSONB DEFAULT '{}';

-- Gitu sessions
CREATE TABLE gitu_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  platform TEXT NOT NULL,
  status TEXT DEFAULT 'active',
  context JSONB DEFAULT '{}',
  started_at TIMESTAMPTZ DEFAULT NOW(),
  last_activity_at TIMESTAMPTZ DEFAULT NOW(),
  ended_at TIMESTAMPTZ,
  CONSTRAINT valid_platform CHECK (platform IN ('flutter', 'whatsapp', 'telegram', 'email', 'terminal'))
);

CREATE INDEX idx_gitu_sessions_user ON gitu_sessions(user_id, status);
CREATE INDEX idx_gitu_sessions_activity ON gitu_sessions(last_activity_at DESC);

-- Gitu memories
CREATE TABLE gitu_memories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  category TEXT NOT NULL,
  content TEXT NOT NULL,
  source TEXT NOT NULL,
  confidence NUMERIC(3,2) DEFAULT 0.5,
  verified BOOLEAN DEFAULT false,
  last_confirmed_by_user TIMESTAMPTZ,
  verification_required BOOLEAN DEFAULT false,
  tags TEXT[] DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  last_accessed_at TIMESTAMPTZ DEFAULT NOW(),
  access_count INTEGER DEFAULT 0,
  CONSTRAINT valid_category CHECK (category IN ('personal', 'work', 'preference', 'fact', 'context')),
  CONSTRAINT valid_confidence CHECK (confidence >= 0 AND confidence <= 1)
);

CREATE INDEX idx_gitu_memories_user ON gitu_memories(user_id, category);
CREATE INDEX idx_gitu_memories_verified ON gitu_memories(user_id, verified);
CREATE INDEX idx_gitu_memories_tags ON gitu_memories USING GIN(tags);

-- Memory contradictions
CREATE TABLE gitu_memory_contradictions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  memory_id UUID NOT NULL REFERENCES gitu_memories(id) ON DELETE CASCADE,
  contradicts_memory_id UUID NOT NULL REFERENCES gitu_memories(id) ON DELETE CASCADE,
  detected_at TIMESTAMPTZ DEFAULT NOW(),
  resolved BOOLEAN DEFAULT false,
  resolution TEXT
);

-- Linked accounts (identity unification)
CREATE TABLE gitu_linked_accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  platform TEXT NOT NULL,
  platform_user_id TEXT NOT NULL,
  display_name TEXT,
  linked_at TIMESTAMPTZ DEFAULT NOW(),
  last_used_at TIMESTAMPTZ DEFAULT NOW(),
  verified BOOLEAN DEFAULT false,
  is_primary BOOLEAN DEFAULT false,
  UNIQUE(platform, platform_user_id),
  CONSTRAINT valid_platform CHECK (platform IN ('flutter', 'whatsapp', 'telegram', 'email', 'terminal'))
);

CREATE INDEX idx_gitu_linked_accounts_user ON gitu_linked_accounts(user_id);
CREATE INDEX idx_gitu_linked_accounts_platform ON gitu_linked_accounts(platform, platform_user_id);

-- Permissions
CREATE TABLE gitu_permissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  resource TEXT NOT NULL,
  actions TEXT[] NOT NULL,
  scope JSONB DEFAULT '{}',
  granted_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ,
  revoked_at TIMESTAMPTZ
);

CREATE INDEX idx_gitu_permissions_user ON gitu_permissions(user_id, resource);

-- VPS configurations
CREATE TABLE gitu_vps_configs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  host TEXT NOT NULL,
  port INTEGER DEFAULT 22,
  auth_method TEXT NOT NULL,
  username TEXT NOT NULL,
  encrypted_password TEXT,
  encrypted_private_key TEXT,
  allowed_commands TEXT[] DEFAULT '{}',
  allowed_paths TEXT[] DEFAULT '{}',
  provider TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  last_used_at TIMESTAMPTZ,
  CONSTRAINT valid_auth_method CHECK (auth_method IN ('password', 'ssh-key', 'ssh-agent'))
);

CREATE INDEX idx_gitu_vps_user ON gitu_vps_configs(user_id);

-- VPS audit logs (append-only)
CREATE TABLE gitu_vps_audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  vps_config_id UUID REFERENCES gitu_vps_configs(id) ON DELETE SET NULL,
  action TEXT NOT NULL,
  command TEXT,
  path TEXT,
  success BOOLEAN DEFAULT true,
  error TEXT,
  timestamp TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_gitu_vps_audit_user ON gitu_vps_audit_logs(user_id, timestamp DESC);
CREATE INDEX idx_gitu_vps_audit_config ON gitu_vps_audit_logs(vps_config_id, timestamp DESC);

-- Gmail connections
CREATE TABLE gitu_gmail_connections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  encrypted_access_token TEXT NOT NULL,
  encrypted_refresh_token TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  scopes TEXT[] NOT NULL,
  connected_at TIMESTAMPTZ DEFAULT NOW(),
  last_sync_at TIMESTAMPTZ,
  UNIQUE(user_id)
);

-- Scheduled tasks
CREATE TABLE gitu_scheduled_tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  trigger JSONB NOT NULL,
  action JSONB NOT NULL,
  enabled BOOLEAN DEFAULT true,
  last_run_at TIMESTAMPTZ,
  next_run_at TIMESTAMPTZ,
  run_count INTEGER DEFAULT 0,
  failure_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_gitu_scheduled_tasks_user ON gitu_scheduled_tasks(user_id, enabled);
CREATE INDEX idx_gitu_scheduled_tasks_next_run ON gitu_scheduled_tasks(next_run_at) WHERE enabled = true;

-- Task execution history
CREATE TABLE gitu_task_executions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id UUID NOT NULL REFERENCES gitu_scheduled_tasks(id) ON DELETE CASCADE,
  success BOOLEAN NOT NULL,
  output JSONB,
  error TEXT,
  duration INTEGER,  -- milliseconds
  executed_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_gitu_task_executions_task ON gitu_task_executions(task_id, executed_at DESC);

-- Usage tracking
CREATE TABLE gitu_usage_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  operation TEXT NOT NULL,
  model TEXT,
  tokens_used INTEGER DEFAULT 0,
  cost_usd NUMERIC(10,6) DEFAULT 0,
  platform TEXT NOT NULL,
  timestamp TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_gitu_usage_user_time ON gitu_usage_records(user_id, timestamp DESC);
CREATE INDEX idx_gitu_usage_user_cost ON gitu_usage_records(user_id, cost_usd DESC);

-- Usage limits
CREATE TABLE gitu_usage_limits (
  user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  daily_limit_usd NUMERIC(10,2) DEFAULT 10.00,
  per_task_limit_usd NUMERIC(10,2) DEFAULT 1.00,
  monthly_limit_usd NUMERIC(10,2) DEFAULT 100.00,
  hard_stop BOOLEAN DEFAULT true,
  alert_thresholds NUMERIC[] DEFAULT '{0.5, 0.75, 0.9}',
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Automation rules
CREATE TABLE gitu_automation_rules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  trigger JSONB NOT NULL,
  conditions JSONB DEFAULT '[]',
  actions JSONB NOT NULL,
  enabled BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_gitu_automation_user ON gitu_automation_rules(user_id, enabled);
```


## Phased Implementation Plan

### Phase 1: MVP (Months 1-2) - Core Foundation ✅

**Goal:** Get Gitu working with basic functionality and prove the concept.

**Components:**
- ✅ Flutter App configuration UI
  - Gitu settings screen
  - API key management (platform vs personal)
  - AI model selection
  - Enable/disable Gitu
  - View activity logs

- ✅ Core Service
  - Message gateway (basic)
  - Session manager
  - AI router with cost estimation
  - Permission manager (basic)

- ✅ Platforms
  - Telegram bot (most reliable)
  - Terminal CLI
  - Flutter app chat

- ✅ MCP Integration
  - Notebook tools only
  - Code verification
  - Basic planning mode

- ✅ Data Layer
  - PostgreSQL schema
  - Redis for caching
  - Basic audit logging

**Success Criteria:**
- User can configure Gitu in Flutter app
- User can chat with Gitu via Telegram
- Gitu can access notebooks via MCP
- Cost tracking works
- Basic permissions enforced

### Phase 2: Multi-Platform & Memory (Months 3-4)

**Goal:** Add WhatsApp, enhance memory, enable background tasks.

**Components:**
- ✅ WhatsApp Integration (Baileys)
  - QR code linking in Flutter app
  - Message handling
  - Connection health monitoring
  - Fallback to Telegram on failure

- ✅ Enhanced Memory System
  - Memory with confidence scores
  - Verification workflow
  - Contradiction detection
  - User can view/edit memories in Flutter app

- ✅ Background Agent Scheduler
  - Cron-based tasks
  - Event triggers
  - Heartbeat monitoring

- ✅ Identity Unification
  - Link multiple platforms
  - Canonical user ID
  - Platform trust levels

**Success Criteria:**
- WhatsApp works reliably (with fallback)
- Memory system learns and verifies
- Scheduled tasks execute correctly
- User identity unified across platforms

### Phase 3: Integrations (Months 5-6)

**Goal:** Connect to user's digital ecosystem.

**Components:**
- ✅ Gmail Integration
  - OAuth authentication
  - Read/search emails
  - Send/reply with AI assistance
  - Email summarization
  - Automation rules

- ✅ Shopify Integration
  - API key connection
  - Order management
  - Inventory tracking
  - Customer support automation

- ✅ Notebook Deep Integration
  - Full MCP tool access
  - Source management
  - Research automation

- ✅ File System Access
  - Permission-scoped access
  - File operations
  - Search and analysis

**Success Criteria:**
- Gmail automation works
- Shopify queries answered
- Notebooks fully accessible
- File operations safe and logged

### Phase 4: Autonomous Features (Months 7-8)

**Goal:** Make Gitu proactive and autonomous.

**Components:**
- ✅ VPS Manager
  - SSH connections
  - Command execution with dry-run
  - Mandatory confirmations for destructive ops
  - System monitoring
  - Deployment automation

- ✅ Advanced Permissions
  - Granular scopes
  - Time-based expiry
  - Permission requests
  - Audit trail

- ✅ Rule Engine
  - IF-THEN rules
  - Event-driven automation
  - Rule testing
  - Rule sharing

- ✅ Plugin System
  - Plugin marketplace
  - Custom integrations
  - Sandboxed execution

**Success Criteria:**
- VPS operations safe and audited
- Permissions granular and revocable
- Rules automate common tasks
- Plugins extend functionality

### Phase 5: Intelligence & Voice (Months 9-10)

**Goal:** Add voice interaction and proactive assistance.

**Components:**
- ✅ Voice Interaction
  - Voice message transcription
  - Text-to-speech responses (ElevenLabs)
  - Wake word detection
  - Multi-platform voice support

- ✅ Proactive Assistance
  - Pattern analysis
  - Suggestion engine
  - Proactive notifications
  - Learning from feedback

- ✅ Agent Skills Integration
  - Access skill catalog
  - Custom skill creation
  - Skill composition
  - Skill marketplace

- ✅ Advanced Analytics
  - Usage dashboard
  - Time saved estimates
  - Conversation analytics
  - Export reports

**Success Criteria:**
- Voice works across platforms
- Proactive suggestions helpful
- Skills enhance capabilities
- Analytics show value

### Phase 6: Polish & Security (Months 11-12)

**Goal:** Production-ready, secure, optimized.

**Components:**
- ✅ Security Hardening
  - Penetration testing
  - Security audit
  - Bug bounty program
  - Compliance (GDPR, SOC 2)

- ✅ Performance Optimization
  - Caching strategies
  - Query optimization
  - Load testing
  - Horizontal scaling

- ✅ Cost Optimization
  - Model selection optimization
  - Caching aggressive
  - Batch operations
  - Usage governor tuning

- ✅ User Experience
  - Onboarding wizard
  - In-app tutorials
  - Error message improvements
  - Documentation

- ✅ Beta Testing
  - Select user group
  - Feedback collection
  - Bug fixes
  - Feature refinement

**Success Criteria:**
- Security audit passed
- 99.9% uptime achieved
- Cost per user optimized
- Beta users satisfied (NPS > 50)


## Flutter App UI Design

### Gitu Settings Screen

```dart
// Main Gitu settings screen in NotebookLLM app
class GituSettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Gitu Assistant')),
      body: ListView(
        children: [
          // Enable/Disable Gitu
          SwitchListTile(
            title: Text('Enable Gitu'),
            subtitle: Text('Your personal AI assistant'),
            value: gituEnabled,
            onChanged: (value) => toggleGitu(value),
          ),
          
          // Connection Status
          ConnectionStatusCard(),
          
          // API Keys Section
          ExpansionTile(
            title: Text('API Keys'),
            children: [
              RadioListTile(
                title: Text('Use Platform Keys'),
                subtitle: Text('Respects your subscription tier'),
                value: 'platform',
                groupValue: apiKeySource,
                onChanged: (value) => setApiKeySource(value),
              ),
              RadioListTile(
                title: Text('Use My Own Keys'),
                subtitle: Text('Bypass platform limits'),
                value: 'personal',
                groupValue: apiKeySource,
                onChanged: (value) => setApiKeySource(value),
              ),
              if (apiKeySource == 'personal')
                PersonalKeysSection(),
            ],
          ),
          
          // AI Model Selection
          ExpansionTile(
            title: Text('AI Models'),
            children: [
              ModelSelectorTile(
                title: 'Default Model',
                currentModel: defaultModel,
                onChanged: (model) => setDefaultModel(model),
              ),
              ModelSelectorTile(
                title: 'Chat Model',
                currentModel: chatModel,
                onChanged: (model) => setChatModel(model),
              ),
              ModelSelectorTile(
                title: 'Research Model',
                currentModel: researchModel,
                onChanged: (model) => setResearchModel(model),
              ),
            ],
          ),
          
          // Connected Platforms
          ExpansionTile(
            title: Text('Connected Platforms'),
            children: [
              PlatformTile(
                platform: 'WhatsApp',
                connected: whatsappConnected,
                onConnect: () => connectWhatsApp(),
                onDisconnect: () => disconnectWhatsApp(),
              ),
              PlatformTile(
                platform: 'Telegram',
                connected: telegramConnected,
                onConnect: () => connectTelegram(),
                onDisconnect: () => disconnectTelegram(),
              ),
              PlatformTile(
                platform: 'Gmail',
                connected: gmailConnected,
                onConnect: () => connectGmail(),
                onDisconnect: () => disconnectGmail(),
              ),
            ],
          ),
          
          // Integrations
          ExpansionTile(
            title: Text('Integrations'),
            children: [
              IntegrationTile(
                name: 'Shopify',
                connected: shopifyConnected,
                onConfigure: () => configureShopify(),
              ),
              IntegrationTile(
                name: 'VPS Servers',
                connected: vpsConnected,
                onConfigure: () => configureVPS(),
              ),
              IntegrationTile(
                name: 'File System',
                connected: filesConnected,
                onConfigure: () => configureFiles(),
              ),
            ],
          ),
          
          // Permissions
          ListTile(
            title: Text('Permissions'),
            subtitle: Text('Manage what Gitu can access'),
            trailing: Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PermissionsScreen()),
            ),
          ),
          
          // Scheduled Tasks
          ListTile(
            title: Text('Scheduled Tasks'),
            subtitle: Text('Automate recurring actions'),
            trailing: Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ScheduledTasksScreen()),
            ),
          ),
          
          // Memory
          ListTile(
            title: Text('Memory'),
            subtitle: Text('What Gitu remembers about you'),
            trailing: Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => MemoryScreen()),
            ),
          ),
          
          // Activity Log
          ListTile(
            title: Text('Activity Log'),
            subtitle: Text('View Gitu\'s actions'),
            trailing: Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ActivityLogScreen()),
            ),
          ),
          
          // Usage & Costs
          ListTile(
            title: Text('Usage & Costs'),
            subtitle: Text('Track API usage and spending'),
            trailing: Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => UsageScreen()),
            ),
          ),
        ],
      ),
    );
  }
}
```

### Connection Status Card

```dart
class ConnectionStatusCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StatusIndicator(status: gituStatus),
                SizedBox(width: 8),
                Text(
                  gituStatus == 'online' ? 'Gitu is Online' : 'Gitu is Offline',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text('Last active: ${lastActive}'),
            SizedBox(height: 8),
            Text('Active platforms: ${activePlatforms.join(", ")}'),
            if (connectionIssues.isNotEmpty) ...[
              SizedBox(height: 8),
              Text(
                'Issues: ${connectionIssues.join(", ")}',
                style: TextStyle(color: Colors.orange),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

### WhatsApp QR Code Dialog

```dart
class WhatsAppConnectDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Connect WhatsApp'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Scan this QR code with WhatsApp:'),
          SizedBox(height: 16),
          QrImage(
            data: qrCodeData,
            size: 200,
          ),
          SizedBox(height: 16),
          Text(
            'Open WhatsApp > Settings > Linked Devices > Link a Device',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
      ],
    );
  }
}
```

## Error Handling & Edge Cases

### Error Categories

```typescript
enum ErrorCategory {
  // User errors
  INVALID_INPUT = 'invalid_input',
  PERMISSION_DENIED = 'permission_denied',
  QUOTA_EXCEEDED = 'quota_exceeded',
  
  // System errors
  SERVICE_UNAVAILABLE = 'service_unavailable',
  TIMEOUT = 'timeout',
  RATE_LIMIT = 'rate_limit',
  
  // Integration errors
  PLATFORM_DISCONNECTED = 'platform_disconnected',
  API_ERROR = 'api_error',
  AUTH_EXPIRED = 'auth_expired',
  
  // Safety errors
  DANGEROUS_OPERATION = 'dangerous_operation',
  CONFIRMATION_REQUIRED = 'confirmation_required',
  BLOCKED_COMMAND = 'blocked_command',
}

interface ErrorResponse {
  category: ErrorCategory;
  message: string;
  userMessage: string;  // User-friendly message
  suggestedAction?: string;
  retryable: boolean;
  retryAfter?: number;  // seconds
}
```

### Error Handling Strategy

| Error | Handling | User Experience |
|-------|----------|-----------------|
| WhatsApp disconnected | Auto-reconnect, fallback to Telegram | "WhatsApp temporarily unavailable. Using Telegram." |
| Gmail auth expired | Prompt re-authentication in Flutter app | "Please reconnect Gmail in settings" |
| VPS connection failed | Retry with exponential backoff | "Server connection failed. Retrying..." |
| Cost limit exceeded | Stop operations, notify user | "Daily budget reached. Upgrade or wait until tomorrow." |
| Dangerous command | Block, require Flutter app confirmation | "This command requires confirmation in the app" |
| Memory contradiction | Ask user to resolve | "I have conflicting information. Which is correct?" |
| API rate limit | Queue request, retry after reset | "API limit reached. Request queued." |
| Model unavailable | Fallback to alternative model | "Using alternative model (GPT-4 → Claude)" |


## Testing Strategy

### Unit Tests

**Core Components:**
- Session manager CRUD operations
- Memory system with confidence tracking
- AI router model selection logic
- Permission validation
- Cost estimation accuracy
- Command classification (safe vs dangerous)

**Coverage Target:** 80%

### Integration Tests

**Platform Integration:**
- WhatsApp message send/receive
- Telegram bot commands
- Email send/receive via Gmail API
- Terminal CLI interaction
- Flutter app API calls

**MCP Integration:**
- All MCP tool calls
- Error handling for unavailable tools
- Permission checks for MCP operations

**Database Integration:**
- Session persistence
- Memory storage and retrieval
- Audit log append-only verification

### Property-Based Tests

Using fast-check for TypeScript:

**Property 1: Cost Estimation Consistency**
*For any* prompt and model, estimating cost twice SHALL return the same result (within 5% margin).

**Property 2: Permission Enforcement**
*For any* operation requiring permission, if permission is not granted, the operation SHALL fail with PERMISSION_DENIED error.

**Property 3: Memory Verification Requirement**
*For any* memory with verificationRequired=true, attempting to use it for actions SHALL fail until verified=true.

**Property 4: Session Context Preservation**
*For any* session, after adding N messages to context, retrieving the session SHALL return exactly N messages in order.

**Property 5: Budget Hard Stop**
*For any* user with hardStop=true and dailyLimitUSD=X, when current spend reaches X, all operations SHALL be blocked.

**Property 6: Command Classification Consistency**
*For any* command matching DESTRUCTIVE_PATTERNS, classifyCommand SHALL return requiresConfirmation=true.

**Property 7: Identity Unification**
*For any* user with N linked accounts, getCanonicalUserId SHALL return the same userId for all N platform IDs.

**Property 8: Audit Log Immutability**
*For any* VPS operation, the audit log entry SHALL be created and never modified (append-only).

### End-to-End Tests

**User Journeys:**

1. **Setup Journey**
   - User enables Gitu in Flutter app
   - User connects WhatsApp via QR code
   - User sets API keys
   - User grants Gmail permission
   - Verify: Gitu responds on WhatsApp

2. **Email Automation Journey**
   - User: "Summarize my unread emails"
   - Gitu fetches emails via Gmail API
   - Gitu generates summary with AI
   - Gitu sends summary to user
   - Verify: Summary accurate, cost tracked

3. **VPS Management Journey**
   - User: "Check server health"
   - Gitu connects to VPS
   - Gitu runs system stats command
   - Gitu formats and sends results
   - Verify: Command logged, no confirmation needed

4. **Dangerous Operation Journey**
   - User: "Delete old log files on server"
   - Gitu detects dangerous command (rm)
   - Gitu runs dry-run
   - Gitu requests confirmation in Flutter app
   - User confirms
   - Gitu executes command
   - Verify: Audit log created, confirmation required

5. **Budget Limit Journey**
   - User has dailyLimitUSD=5.00
   - User makes requests totaling $4.80
   - User makes request estimated at $0.50
   - Gitu blocks request (would exceed limit)
   - Gitu notifies user
   - Verify: No charge, user notified

### Load Testing

**Scenarios:**
- 1,000 concurrent users
- 10,000 messages per minute
- 100 VPS connections simultaneously
- 1,000 scheduled tasks executing

**Metrics:**
- Response time < 2 seconds (p95)
- API response time < 500ms (p95)
- Database query time < 100ms (p95)
- Memory usage < 2GB per instance
- CPU usage < 70% average

### Security Testing

**Penetration Testing:**
- SQL injection attempts
- Command injection via VPS
- XSS in message content
- CSRF on API endpoints
- JWT token manipulation
- Rate limit bypass attempts

**Compliance Testing:**
- GDPR data export
- GDPR data deletion
- Audit log completeness
- Encryption at rest verification
- Encryption in transit verification

## Deployment Architecture

### Infrastructure

```
┌─────────────────────────────────────────────────────────────────┐
│                         Load Balancer                            │
│                      (NGINX / AWS ALB)                           │
└────────────────────────┬────────────────────────────────────────┘
                         │
         ┌───────────────┼───────────────┐
         │               │               │
         ▼               ▼               ▼
┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│   Gitu      │  │   Gitu      │  │   Gitu      │
│  Instance 1 │  │  Instance 2 │  │  Instance 3 │
│  (Node.js)  │  │  (Node.js)  │  │  (Node.js)  │
└──────┬──────┘  └──────┬──────┘  └──────┬──────┘
       │                │                │
       └────────────────┼────────────────┘
                        │
         ┌──────────────┼──────────────┐
         │              │              │
         ▼              ▼              ▼
┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│ PostgreSQL  │  │    Redis    │  │  File Store │
│  (Primary)  │  │   (Cache)   │  │   (S3/R2)   │
└─────────────┘  └─────────────┘  └─────────────┘
         │
         ▼
┌─────────────┐
│ PostgreSQL  │
│  (Replica)  │
└─────────────┘
```

### Scaling Strategy

**Horizontal Scaling:**
- Stateless Gitu instances
- Session data in Redis
- Load balancer distributes requests
- Auto-scaling based on CPU/memory

**Database Scaling:**
- Read replicas for queries
- Connection pooling
- Query optimization
- Partitioning for large tables (audit logs, usage records)

**Caching Strategy:**
- Redis for session data (TTL: 24 hours)
- Redis for AI responses (TTL: 1 hour)
- Redis for MCP tool results (TTL: 5 minutes)
- CDN for static assets

### Monitoring & Observability

**Metrics:**
- Request rate (requests/second)
- Response time (p50, p95, p99)
- Error rate (errors/minute)
- Active sessions
- Database connections
- Redis memory usage
- Cost per user per day

**Logging:**
- Structured JSON logs
- Log levels: DEBUG, INFO, WARN, ERROR
- Correlation IDs for request tracing
- Sensitive data redaction

**Alerting:**
- Error rate > 5% for 5 minutes
- Response time p95 > 5 seconds
- Database connection pool exhausted
- Redis memory > 80%
- Daily cost > $1000
- WhatsApp connection down > 10 minutes

**Tools:**
- Prometheus for metrics
- Grafana for dashboards
- Sentry for error tracking
- Datadog for APM
- CloudWatch for AWS resources

## Security Considerations

### Authentication & Authorization

**User Authentication:**
- JWT tokens for API access
- Refresh token rotation
- Token expiry: 15 minutes (access), 7 days (refresh)
- Multi-factor authentication for sensitive operations

**Platform Authentication:**
- WhatsApp: Session-based (Baileys)
- Telegram: Bot token
- Gmail: OAuth 2.0
- VPS: SSH keys (encrypted at rest)

**Authorization:**
- Role-based access control (RBAC)
- Permission scopes
- Resource-level permissions
- Time-based permission expiry

### Data Security

**Encryption at Rest:**
- Database: AES-256
- API keys: AES-256 with user-specific keys
- SSH keys: AES-256 with user-specific keys
- Backups: Encrypted

**Encryption in Transit:**
- TLS 1.3 for all API calls
- WSS for WebSocket connections
- SSH for VPS connections

**Data Retention:**
- Session data: 30 days
- Audit logs: 1 year
- Usage records: 1 year
- Memories: Until user deletes
- Backups: 30 days

### Compliance

**GDPR:**
- Right to access: Export all user data
- Right to deletion: Delete all user data
- Right to portability: JSON export
- Consent management: Explicit opt-in
- Data processing agreements

**SOC 2 (for Enterprise):**
- Security controls
- Availability monitoring
- Processing integrity
- Confidentiality measures
- Privacy protections

## Cost Analysis

### Infrastructure Costs (Monthly)

| Component | Specification | Cost |
|-----------|--------------|------|
| Compute (3x instances) | 4 vCPU, 8GB RAM each | $150 |
| Database (PostgreSQL) | 2 vCPU, 8GB RAM, 100GB SSD | $100 |
| Redis | 2GB memory | $30 |
| Load Balancer | AWS ALB | $20 |
| File Storage | 100GB S3 | $3 |
| Bandwidth | 1TB transfer | $90 |
| Monitoring | Datadog Pro | $15/host = $45 |
| **Total Infrastructure** | | **$438/month** |

### AI Model Costs (Per 1000 Users)

Assuming average 50 messages/user/day:

| Model | Cost per 1M tokens | Daily tokens per user | Monthly cost per user | Total (1000 users) |
|-------|-------------------|----------------------|----------------------|-------------------|
| GPT-4 Turbo | $10 | 10,000 | $3.00 | $3,000 |
| Claude 3.5 Sonnet | $3 | 10,000 | $0.90 | $900 |
| Gemini 1.5 Pro | $1.25 | 10,000 | $0.38 | $380 |
| GPT-3.5 Turbo | $0.50 | 10,000 | $0.15 | $150 |

**Strategy:** Default to Gemini 1.5 Pro for cost efficiency, allow users to upgrade to GPT-4/Claude for premium features.

### Total Cost Estimate

**For 1000 users:**
- Infrastructure: $438/month
- AI (Gemini default): $380/month
- **Total: $818/month**
- **Cost per user: $0.82/month**

**Revenue Model:**
- Free tier: 10 messages/day (platform keys)
- Pro tier: $5/month (unlimited, platform keys)
- Premium tier: $15/month (unlimited, personal keys, priority support)

**Break-even:** ~164 Pro users or ~55 Premium users


## Risk Mitigation Strategies

### High-Priority Risks

#### 1. WhatsApp Account Bans (Baileys)

**Risk:** WhatsApp may ban accounts using unofficial clients.

**Mitigation:**
- ✅ Implement rate limiting (max 20 messages/minute)
- ✅ Add random delays between messages (1-3 seconds)
- ✅ Monitor connection health continuously
- ✅ Provide clear warnings to users about risks
- ✅ Offer Telegram as primary alternative
- ✅ Never use WhatsApp for critical operations
- ✅ Implement graceful degradation to other platforms
- ✅ Consider official Business API for enterprise users

**Fallback Plan:** If WhatsApp connection fails, automatically route messages to Telegram or Flutter app.

#### 2. Runaway AI Costs

**Risk:** Infinite loops or malicious usage could drain budgets.

**Mitigation:**
- ✅ Hard budget limits per user (enforced)
- ✅ Per-task cost limits
- ✅ Shadow cost estimation before execution
- ✅ Alert at 50%, 75%, 90% of budget
- ✅ Automatic model downgrade when approaching limit
- ✅ Circuit breaker for repeated expensive operations
- ✅ Rate limiting per user (max 100 requests/hour)
- ✅ Anomaly detection for unusual usage patterns

**Example Circuit Breaker:**
```typescript
if (last10RequestsCost > perTaskLimit * 5) {
  // User is making expensive requests repeatedly
  temporarilyBlockUser(userId, duration: '1 hour');
  notifyUser('Unusual activity detected. Please contact support.');
}
```

#### 3. VPS Security Breaches

**Risk:** Compromised Gitu could execute malicious commands on user servers.

**Mitigation:**
- ✅ Mandatory dry-run for destructive commands
- ✅ Human confirmation required (Flutter app only)
- ✅ Command whitelist per VPS
- ✅ Path restrictions (allowed directories only)
- ✅ Immutable audit logs
- ✅ Real-time alerts for dangerous commands
- ✅ SSH key rotation every 90 days
- ✅ Principle of least privilege (limited user accounts)
- ✅ Never store passwords in plain text
- ✅ Two-factor authentication for VPS operations

**Blocked Commands List:**
```typescript
const NEVER_ALLOW = [
  'rm -rf /',
  'dd if=/dev/zero of=/dev/sda',
  'mkfs',
  ':(){ :|:& };:',  // Fork bomb
  'chmod 777 -R /',
];
```

#### 4. Memory System Hallucinations

**Risk:** AI stores incorrect information, leading to wrong actions.

**Mitigation:**
- ✅ Confidence scores for all memories
- ✅ Verification required for action-triggering memories
- ✅ User can review and edit all memories
- ✅ Contradiction detection
- ✅ Source tracking (where memory came from)
- ✅ Expire unverified memories after 30 days
- ✅ Never execute critical actions based on unverified memories
- ✅ Ask user to confirm before using memory for actions

**Safety Rule:**
```typescript
if (memory.verificationRequired && !memory.verified) {
  throw new Error('Cannot use unverified memory for actions');
}
```

#### 5. Gmail Data Privacy

**Risk:** Sensitive email data could be exposed or misused.

**Mitigation:**
- ✅ OAuth 2.0 with minimal scopes
- ✅ User explicitly grants permissions
- ✅ Email content never stored permanently
- ✅ Encryption at rest for cached data
- ✅ Automatic token expiry and refresh
- ✅ User can revoke access anytime
- ✅ Audit log of all email operations
- ✅ No email forwarding without explicit confirmation
- ✅ PII detection and redaction in logs

#### 6. Platform Reliability (WhatsApp, Telegram)

**Risk:** Platform outages or API changes break functionality.

**Mitigation:**
- ✅ Multi-platform support (not dependent on one)
- ✅ Automatic fallback to alternative platforms
- ✅ Connection health monitoring
- ✅ Graceful degradation
- ✅ User notifications of platform issues
- ✅ Flutter app always available as fallback
- ✅ Queue messages during outages
- ✅ Retry with exponential backoff

### Medium-Priority Risks

#### 7. Database Performance Degradation

**Mitigation:**
- Query optimization
- Proper indexing
- Connection pooling
- Read replicas
- Partitioning for large tables
- Regular VACUUM and ANALYZE

#### 8. Redis Memory Exhaustion

**Mitigation:**
- TTL on all cached data
- LRU eviction policy
- Memory monitoring and alerts
- Separate Redis instances for different purposes
- Compression for large values

#### 9. API Rate Limits (External Services)

**Mitigation:**
- Rate limit tracking per service
- Exponential backoff on 429 errors
- Caching to reduce API calls
- Batch operations where possible
- User notifications when limits approached

#### 10. Compliance Violations

**Mitigation:**
- Regular compliance audits
- Data processing agreements
- Privacy policy updates
- User consent management
- GDPR-compliant data handling
- SOC 2 certification (for enterprise)

## Success Metrics & KPIs

### Adoption Metrics

| Metric | Target (3 months) | Target (6 months) | Target (12 months) |
|--------|------------------|-------------------|-------------------|
| Active Users | 1,000 | 5,000 | 20,000 |
| Daily Active Users | 300 | 2,000 | 10,000 |
| WhatsApp Connections | 600 (60%) | 3,000 (60%) | 12,000 (60%) |
| Telegram Connections | 800 (80%) | 4,000 (80%) | 16,000 (80%) |
| Gmail Connections | 400 (40%) | 2,000 (40%) | 8,000 (40%) |
| VPS Connections | 200 (20%) | 1,000 (20%) | 4,000 (20%) |

### Engagement Metrics

| Metric | Target |
|--------|--------|
| Messages per user per day | 50 |
| Sessions per user per day | 5 |
| Average session duration | 10 minutes |
| Scheduled tasks per user | 3 |
| Integrations per user | 3 |
| Memory items per user | 50 |

### Performance Metrics

| Metric | Target |
|--------|--------|
| Message response time (p95) | < 2 seconds |
| API response time (p95) | < 500ms |
| Uptime | 99.9% |
| Error rate | < 1% |
| WhatsApp connection uptime | > 95% |

### Business Metrics

| Metric | Target |
|--------|--------|
| Monthly Recurring Revenue (MRR) | $50,000 (6 months) |
| Cost per user | < $1/month |
| Revenue per user | $5-15/month |
| Gross margin | > 80% |
| Customer Acquisition Cost (CAC) | < $20 |
| Lifetime Value (LTV) | > $100 |
| LTV:CAC ratio | > 5:1 |

### Satisfaction Metrics

| Metric | Target |
|--------|--------|
| Net Promoter Score (NPS) | > 50 |
| Customer Satisfaction (CSAT) | > 4.5/5 |
| Feature adoption rate | > 60% |
| Churn rate | < 5% monthly |
| Support ticket volume | < 10% of users |

## Next Steps

1. ✅ **Review and approve design document**
2. **Create tasks.md** - Break down implementation into actionable tasks
3. **Set up development environment**
   - Node.js backend repository
   - Flutter app Gitu module
   - Database schema
   - Redis configuration
4. **Phase 1 Implementation** (Months 1-2)
   - Flutter app settings UI
   - Core service (session, AI router, permissions)
   - Telegram bot
   - Terminal CLI
   - MCP integration (notebooks only)
   - PostgreSQL + Redis setup
5. **Testing & Validation**
   - Unit tests
   - Integration tests
   - Property-based tests
   - Security testing
6. **Phase 2 Planning**
   - WhatsApp integration design
   - Memory system enhancement
   - Background scheduler design

## Conclusion

Gitu is designed as a **user-owned, model-agnostic, permission-safe AI operating system** that bridges the gap between AI capabilities and real-world user needs. The architecture prioritizes:

- **Safety:** Multiple layers of protection (dry-run, confirmation, audit logs)
- **Cost Control:** Budget limits, cost estimation, model optimization
- **Reliability:** Multi-platform support, graceful degradation, health monitoring
- **Privacy:** User-controlled permissions, encryption, compliance
- **Flexibility:** MCP integration, custom plugins, personal API keys
- **Scalability:** Horizontal scaling, caching, load balancing

The phased implementation approach ensures we build a solid foundation before adding complexity, validate assumptions early, and can pivot based on user feedback.

**This is not over-engineered — it's correctly engineered for a production-grade AI assistant that users can trust with their digital life.**


## Additional Capabilities

### 15. Web Browsing & Research

Gitu can browse the web, search for information, and conduct deep research using existing NotebookLLM capabilities.

```typescript
interface WebBrowsingManager {
  // Web search
  searchWeb(query: string, options?: SearchOptions): Promise<SearchResult[]>;
  
  // Fetch and read web pages
  fetchPage(url: string): Promise<WebPage>;
  
  // Deep research (multi-step)
  conductResearch(topic: string, depth: 'quick' | 'standard' | 'deep'): Promise<ResearchReport>;
  
  // Extract information from URLs
  extractFromUrl(url: string, extractionType: 'text' | 'data' | 'images'): Promise<ExtractedContent>;
  
  // Monitor websites for changes
  monitorWebsite(url: string, checkInterval: number): Promise<MonitoringTask>;
}

interface SearchOptions {
  maxResults?: number;
  dateRange?: { start: Date; end: Date };
  language?: string;
  region?: string;
  safeSearch?: boolean;
}

interface SearchResult {
  title: string;
  url: string;
  snippet: string;
  publishedDate?: Date;
  domain: string;
  relevanceScore: number;
}

interface WebPage {
  url: string;
  title: string;
  content: string;
  html?: string;
  metadata: {
    author?: string;
    publishedDate?: Date;
    description?: string;
    keywords?: string[];
  };
  links: string[];
  images: string[];
}

interface ResearchReport {
  topic: string;
  summary: string;
  keyFindings: string[];
  sources: ResearchSource[];
  relatedTopics: string[];
  confidence: number;
  generatedAt: Date;
}

interface ResearchSource {
  title: string;
  url: string;
  excerpt: string;
  credibility: 'high' | 'medium' | 'low';
  publishedDate?: Date;
}

interface ExtractedContent {
  url: string;
  type: 'text' | 'data' | 'images';
  content: any;
  extractedAt: Date;
}

interface MonitoringTask {
  id: string;
  url: string;
  checkInterval: number;  // minutes
  lastChecked?: Date;
  changes: WebsiteChange[];
  notifyOnChange: boolean;
}

interface WebsiteChange {
  detectedAt: Date;
  changeType: 'content' | 'structure' | 'new_page' | 'removed_page';
  description: string;
  diff?: string;
}
```

**Integration with Existing NotebookLLM Features:**

Gitu leverages the existing web browsing capabilities from NotebookLLM:

1. **Serper API Integration** (from `lib/core/search/serper_service.dart`)
   - Web search functionality
   - Real-time search results
   - News and image search

2. **Deep Research Service** (from `lib/core/ai/deep_research_service.dart`)
   - Multi-step research
   - Source verification
   - Comprehensive reports

3. **Web Browsing Service** (from `lib/core/ai/web_browsing_service.dart`)
   - Fetch and parse web pages
   - Extract structured data
   - Handle dynamic content

**Example Web Browsing Operations via Gitu:**

1. **Quick Web Search**
   - User: "Search for the latest news about AI"
   - Gitu: Uses Serper API, returns top 10 results with summaries

2. **Deep Research**
   - User: "Research the best practices for microservices architecture"
   - Gitu: Conducts multi-step research, reads multiple sources, generates comprehensive report

3. **Website Monitoring**
   - User: "Monitor my competitor's pricing page and notify me of changes"
   - Gitu: Sets up monitoring task, checks every hour, sends notification on changes

4. **Data Extraction**
   - User: "Extract all product prices from this e-commerce site"
   - Gitu: Fetches page, parses HTML, extracts structured data

5. **Content Summarization**
   - User: "Summarize this article: [URL]"
   - Gitu: Fetches page, extracts main content, generates summary

6. **Fact Checking**
   - User: "Is this claim true: [statement]"
   - Gitu: Searches web for evidence, cross-references sources, provides verdict

### 16. Extensibility & Custom Capabilities

Gitu is designed to be **infinitely extensible** through:

#### A. Custom MCP Servers

Users can install any MCP server to add new capabilities:

```typescript
interface CustomMCPIntegration {
  // Discover user's installed MCP servers
  discoverCustomServers(): Promise<MCPServer[]>;
  
  // Use custom MCP tools
  useCustomTool(serverName: string, toolName: string, params: any): Promise<any>;
  
  // Suggest relevant MCP servers for tasks
  suggestMCPServers(task: string): Promise<MCPServerSuggestion[]>;
}

interface MCPServer {
  name: string;
  description: string;
  tools: MCPTool[];
  category: string;
  installed: boolean;
  version: string;
}

interface MCPServerSuggestion {
  server: MCPServer;
  relevance: number;
  reason: string;
  installUrl?: string;
}
```

**Example Custom MCP Servers:**
- Database tools (PostgreSQL, MongoDB, Redis)
- Cloud services (AWS, GCP, Azure)
- DevOps tools (Docker, Kubernetes, Terraform)
- Analytics (Google Analytics, Mixpanel)
- CRM (Salesforce, HubSpot)
- Project management (Jira, Asana, Linear)
- Communication (Slack, Discord, Teams)
- Payment processing (Stripe, PayPal)
- Social media (Twitter, LinkedIn, Instagram)
- Custom business APIs

#### B. Plugin System

Users can create custom plugins for Gitu:

```typescript
interface GituPlugin {
  id: string;
  name: string;
  version: string;
  description: string;
  
  // Plugin lifecycle
  initialize(context: PluginContext): Promise<void>;
  onMessage(message: IncomingMessage): Promise<PluginResponse | null>;
  onSchedule(schedule: ScheduleEvent): Promise<void>;
  cleanup(): Promise<void>;
  
  // Plugin capabilities
  commands: PluginCommand[];
  triggers: PluginTrigger[];
  settings: PluginSetting[];
}

interface PluginContext {
  userId: string;
  platform: string;
  permissions: string[];
  storage: PluginStorage;
  logger: Logger;
}

interface PluginCommand {
  name: string;
  description: string;
  parameters: PluginParameter[];
  handler: (params: any) => Promise<any>;
}

interface PluginTrigger {
  event: string;
  filter?: (event: any) => boolean;
  handler: (event: any) => Promise<void>;
}

interface PluginStorage {
  get(key: string): Promise<any>;
  set(key: string, value: any): Promise<void>;
  delete(key: string): Promise<void>;
}
```

**Example Custom Plugins:**
- Cryptocurrency price tracker
- Weather alerts
- Stock market monitor
- Habit tracker
- Expense tracker
- Meeting scheduler
- Task prioritizer
- Content aggregator
- Custom AI workflows
- Business-specific automations

#### C. Workflow Builder

Users can create custom workflows without coding:

```typescript
interface WorkflowBuilder {
  createWorkflow(workflow: Workflow): Promise<string>;
  executeWorkflow(workflowId: string, input: any): Promise<WorkflowResult>;
  listWorkflows(userId: string): Promise<Workflow[]>;
}

interface Workflow {
  id: string;
  name: string;
  description: string;
  trigger: WorkflowTrigger;
  steps: WorkflowStep[];
  enabled: boolean;
}

interface WorkflowStep {
  id: string;
  type: 'action' | 'condition' | 'loop' | 'parallel';
  action?: string;  // e.g., 'send_email', 'search_web', 'execute_command'
  params?: Record<string, any>;
  condition?: string;  // JavaScript expression
  onSuccess?: string;  // Next step ID
  onFailure?: string;  // Next step ID
}

interface WorkflowResult {
  workflowId: string;
  success: boolean;
  output: any;
  stepsExecuted: number;
  duration: number;
  errors?: string[];
}
```

**Example Workflows:**
- "When I receive an email from my boss, summarize it and send to WhatsApp"
- "Every morning, check server health and send report"
- "When stock price drops 5%, notify me and execute trade"
- "Monitor competitor website, extract prices, update spreadsheet"
- "When GitHub issue created, analyze with AI, suggest solution"

### 17. AI-Powered Capabilities

Beyond basic operations, Gitu has advanced AI capabilities:

```typescript
interface AICapabilities {
  // Natural language understanding
  understandIntent(message: string): Promise<Intent>;
  
  // Context-aware responses
  generateResponse(context: ConversationContext): Promise<string>;
  
  // Task decomposition
  breakDownTask(task: string): Promise<TaskPlan>;
  
  // Decision making
  makeDecision(situation: string, options: string[]): Promise<Decision>;
  
  // Learning from feedback
  learnFromFeedback(interaction: Interaction, feedback: Feedback): Promise<void>;
  
  // Proactive suggestions
  suggestActions(context: UserContext): Promise<Suggestion[]>;
}

interface Intent {
  action: string;
  entities: Record<string, any>;
  confidence: number;
  requiresConfirmation: boolean;
}

interface TaskPlan {
  task: string;
  steps: TaskStep[];
  estimatedDuration: number;
  requiredPermissions: string[];
  risks: string[];
}

interface TaskStep {
  description: string;
  action: string;
  dependencies: string[];
  estimatedDuration: number;
}

interface Decision {
  chosenOption: string;
  reasoning: string;
  confidence: number;
  alternatives: { option: string; score: number }[];
}

interface Suggestion {
  type: 'action' | 'information' | 'optimization';
  title: string;
  description: string;
  priority: 'low' | 'medium' | 'high';
  actionable: boolean;
  action?: () => Promise<void>;
}
```

**Summary: Gitu is NOT Limited**

Gitu is designed as an **open, extensible platform** that can:

✅ Browse the web and conduct research
✅ Use ALL NotebookLLM MCP tools
✅ Use ANY custom MCP server installed by user
✅ Run custom plugins
✅ Execute user-defined workflows
✅ Integrate with ANY API (via custom integrations)
✅ Learn and adapt to user needs
✅ Proactively suggest actions
✅ Make intelligent decisions
✅ Automate complex multi-step tasks

**The only limits are:**
1. User-defined permissions (for safety)
2. Budget limits (for cost control)
3. Platform capabilities (e.g., WhatsApp API limitations)

**Gitu is essentially a programmable AI operating system that can be extended to do virtually anything the user needs.**


### 18. Coding & Development Capabilities

Gitu has **full coding capabilities** through NotebookLLM MCP integration and can act as a coding assistant across all platforms.

```typescript
interface CodingCapabilities {
  // Code verification & quality
  verifyCode(code: string, language: string, context?: string): Promise<VerificationResult>;
  batchVerifyCode(files: CodeFile[]): Promise<BatchVerificationResult>;
  analyzeCode(code: string, language: string, analysisType?: AnalysisType): Promise<CodeAnalysis>;
  
  // Code review
  reviewCode(code: string, language: string, reviewType?: ReviewType): Promise<CodeReview>;
  contextAwareReview(code: string, githubContext: GitHubContext): Promise<CodeReview>;
  
  // Code generation
  generateCode(prompt: string, language: string, context?: string): Promise<GeneratedCode>;
  refactorCode(code: string, language: string, refactoringType: string): Promise<RefactoredCode>;
  fixBugs(code: string, language: string, errors: string[]): Promise<FixedCode>;
  
  // Testing
  generateTests(code: string, language: string, framework: string): Promise<GeneratedTests>;
  
  // Documentation
  generateDocs(code: string, language: string, style: string): Promise<Documentation>;
  
  // GitHub integration
  analyzeRepository(owner: string, repo: string): Promise<RepoAnalysis>;
  createIssue(owner: string, repo: string, issue: IssueData): Promise<Issue>;
  suggestFixes(owner: string, repo: string, issueNumber: number): Promise<FixSuggestion[]>;
  
  // Planning & architecture
  createPlan(title: string, description: string): Promise<Plan>;
  createTask(planId: string, task: TaskData): Promise<Task>;
  updateTaskStatus(planId: string, taskId: string, status: TaskStatus): Promise<void>;
  
  // Agent skills
  useSkill(skillName: string, params: any): Promise<any>;
}

interface VerificationResult {
  isValid: boolean;
  score: number;  // 0-100
  errors: CodeIssue[];
  warnings: CodeIssue[];
  suggestions: CodeSuggestion[];
}

interface CodeIssue {
  severity: 'error' | 'warning' | 'info';
  message: string;
  line?: number;
  column?: number;
  category: 'syntax' | 'security' | 'performance' | 'style' | 'logic';
}

interface CodeReview {
  score: number;
  issues: ReviewIssue[];
  suggestions: ReviewSuggestion[];
  summary: string;
  relatedFilesUsed?: string[];  // For context-aware reviews
}

interface ReviewIssue {
  severity: 'critical' | 'high' | 'medium' | 'low';
  category: 'security' | 'performance' | 'readability' | 'maintainability';
  title: string;
  description: string;
  lineNumbers: number[];
  codeSnippet: string;
  suggestedFix?: string;
}

interface GeneratedCode {
  code: string;
  language: string;
  explanation: string;
  dependencies?: string[];
  usage?: string;
}

interface GeneratedTests {
  tests: string;
  framework: string;
  coverage: string[];  // What's covered
  explanation: string;
}

interface RepoAnalysis {
  overview: string;
  structure: string[];
  keyFiles: { path: string; purpose: string }[];
  techStack: string[];
  codeQuality: number;
  suggestions: string[];
}
```

**Available Coding MCP Tools:**

1. **Code Verification**
   - `verify_code` - Verify code quality and correctness
   - `batch_verify` - Verify multiple files at once
   - `analyze_code` - Deep code analysis (performance, security, readability)

2. **Code Review**
   - `review_code` - Comprehensive AI code review
   - Context-aware reviews with GitHub integration
   - Security, performance, and style analysis

3. **GitHub Integration**
   - `github_list_repos` - List user's repositories
   - `github_get_file` - Read file from GitHub
   - `github_search_code` - Search code across repos
   - `github_create_issue` - Create issues
   - `github_add_as_source` - Import code to notebook
   - `github_analyze_repo` - AI repository analysis

4. **Planning Mode**
   - `create_plan` - Create development plan
   - `create_requirement` - Add requirements (EARS pattern)
   - `create_design_note` - Document architecture decisions
   - `create_task` - Add implementation tasks
   - `update_task_status` - Track progress
   - `complete_task` - Mark tasks complete

5. **Agent Skills**
   - `code-reviewer` - Expert code review
   - `test-generator` - Generate unit tests
   - `doc-generator` - Generate documentation
   - `refactoring-assistant` - Suggest refactorings
   - `api-designer` - Design RESTful APIs

**Example Coding Operations via Gitu:**

#### 1. Code Review via WhatsApp
```
User (WhatsApp): "Review this code:
function login(user, pass) {
  if (user == 'admin' && pass == '123') {
    return true;
  }
  return false;
}"

Gitu: "🔍 Code Review Results:

Score: 35/100 ❌

Critical Issues:
1. Security: Hardcoded credentials
2. Security: Using == instead of ===
3. Security: Plain text password comparison
4. Best Practice: No input validation

Suggestions:
- Use environment variables for credentials
- Hash passwords with bcrypt
- Add input validation
- Use strict equality (===)
- Add error handling

Would you like me to generate a secure version?"
```

#### 2. Generate Tests via Telegram
```
User (Telegram): "/generate-tests for my calculateTotal function"

Gitu: "Generated comprehensive tests using Jest:

```javascript
describe('calculateTotal', () => {
  test('calculates total with tax', () => {
    expect(calculateTotal(100, 0.1)).toBe(110);
  });
  
  test('handles zero amount', () => {
    expect(calculateTotal(0, 0.1)).toBe(0);
  });
  
  test('handles negative tax rate', () => {
    expect(() => calculateTotal(100, -0.1)).toThrow();
  });
});
```

Coverage: Happy path, edge cases, error conditions
Saved to your notebook ✅"
```

#### 3. Fix Bugs via Flutter App
```
User (Flutter): "Fix the bug in my API endpoint"

Gitu: "Analyzing your code...

Found issue: Missing error handling for database connection

Fixed version:
```typescript
app.get('/users', async (req, res) => {
  try {
    const users = await db.query('SELECT * FROM users');
    res.json(users);
  } catch (error) {
    console.error('Database error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});
```

Changes:
- Added try-catch block
- Proper error logging
- User-friendly error response
- Correct HTTP status code

Would you like me to save this to your notebook?"
```

#### 4. Repository Analysis via Email
```
User (Email): "Analyze my GitHub repo: username/my-project"

Gitu: "Repository Analysis: username/my-project

Overview:
Node.js REST API with Express and PostgreSQL

Structure:
- src/routes/ - API endpoints
- src/services/ - Business logic
- src/models/ - Database models
- tests/ - Unit tests

Tech Stack:
- Express.js, PostgreSQL, Jest, TypeScript

Code Quality: 78/100

Key Files:
- src/index.ts - Main entry point
- src/routes/auth.ts - Authentication logic
- src/services/userService.ts - User management

Suggestions:
1. Add API documentation (Swagger)
2. Implement rate limiting
3. Add integration tests
4. Set up CI/CD pipeline
5. Add input validation middleware

Would you like me to create a plan to implement these improvements?"
```

#### 5. Planning Mode via Terminal
```
User (Terminal): "gitu create-plan 'User Authentication Feature'"

Gitu: "Created plan: User Authentication Feature

Requirements:
1. THE system SHALL authenticate users with email/password
2. WHEN login fails 3 times, THE system SHALL lock account
3. THE system SHALL support password reset via email

Tasks:
1. Implement login endpoint ⏳
2. Add password hashing ⏳
3. Create JWT token generation ⏳
4. Add rate limiting ⏳
5. Implement password reset ⏳

Use 'gitu start-task <task-id>' to begin implementation"
```

#### 6. Autonomous Coding Assistant
```
User (WhatsApp): "Build me a REST API for a todo app"

Gitu: "I'll build a complete REST API for you. Here's the plan:

Phase 1: Setup ✅
- Created project structure
- Initialized Node.js + Express
- Set up PostgreSQL database

Phase 2: Implementation 🔄
- Creating user authentication...
- Implementing CRUD endpoints...
- Adding validation middleware...

Phase 3: Testing ⏳
- Writing unit tests
- Writing integration tests

I'll notify you when each phase completes. 
Estimated time: 30 minutes

Track progress: gitu.app/plans/abc123"
```

#### 7. Code Refactoring
```
User (Telegram): "Refactor this code to use async/await"

Gitu: "Refactored to modern async/await:

Before:
```javascript
function getUser(id) {
  return db.query('SELECT * FROM users WHERE id = ?', [id])
    .then(result => result[0])
    .catch(err => console.error(err));
}
```

After:
```javascript
async function getUser(id) {
  try {
    const result = await db.query('SELECT * FROM users WHERE id = ?', [id]);
    return result[0];
  } catch (error) {
    console.error('Error fetching user:', error);
    throw error;
  }
}
```

Improvements:
- Modern async/await syntax
- Better error handling
- More readable code
- Proper error propagation"
```

#### 8. Documentation Generation
```
User (Flutter): "Generate docs for my UserService class"

Gitu: "Generated comprehensive documentation:

```typescript
/**
 * UserService handles all user-related operations
 * 
 * @class UserService
 * @description Provides methods for user CRUD operations,
 * authentication, and profile management
 * 
 * @example
 * const userService = new UserService(db);
 * const user = await userService.getById('123');
 */
class UserService {
  /**
   * Retrieves a user by ID
   * 
   * @param {string} id - The user's unique identifier
   * @returns {Promise<User>} The user object
   * @throws {NotFoundError} If user doesn't exist
   * 
   * @example
   * const user = await userService.getById('123');
   */
  async getById(id: string): Promise<User> {
    // ...
  }
}
```

Saved to your notebook ✅"
```

**Coding Workflow Integration:**

Gitu integrates seamlessly with your development workflow:

1. **Write Code** → Ask Gitu to review
2. **Get Review** → Gitu suggests improvements
3. **Apply Fixes** → Gitu generates fixed code
4. **Generate Tests** → Gitu creates comprehensive tests
5. **Document** → Gitu generates documentation
6. **Deploy** → Gitu can deploy to VPS
7. **Monitor** → Gitu watches for issues

**All accessible from WhatsApp, Telegram, Email, Terminal, or Flutter app!**


### 19. Coding Agent ↔ Gitu Communication (MCP Bridge)

Coding agents can communicate with Gitu through the NotebookLLM MCP server, enabling powerful collaborative workflows.

```typescript
interface CodingAgentBridge {
  // Coding agent sends message to Gitu
  sendToGitu(agentId: string, message: AgentMessage): Promise<GituResponse>;
  
  // Gitu sends message to coding agent
  sendToAgent(agentId: string, message: GituMessage): Promise<AgentResponse>;
  
  // Create shared workspace
  createSharedWorkspace(agentId: string, userId: string): Promise<Workspace>;
  
  // Collaborative coding session
  startCollabSession(agentId: string, userId: string, context: CollabContext): Promise<Session>;
  
  // Task delegation
  delegateTask(from: 'gitu' | 'agent', to: 'gitu' | 'agent', task: Task): Promise<TaskResult>;
}

interface AgentMessage {
  agentId: string;
  agentName: string;  // 'Claude Desktop', 'Cursor', 'Windsurf', 'Kiro'
  userId: string;
  content: string;
  context?: {
    currentFile?: string;
    codebase?: string;
    task?: string;
  };
  requestType: 'question' | 'task' | 'review' | 'collaboration';
}

interface GituResponse {
  content: string;
  actions?: GituAction[];
  suggestions?: string[];
  needsUserConfirmation?: boolean;
}

interface GituAction {
  type: 'deploy' | 'test' | 'monitor' | 'notify' | 'research';
  description: string;
  params: Record<string, any>;
}

interface Workspace {
  id: string;
  agentId: string;
  userId: string;
  sharedNotebooks: string[];
  sharedPlans: string[];
  permissions: WorkspacePermissions;
}

interface WorkspacePermissions {
  agentCanRead: string[];
  agentCanWrite: string[];
  gituCanRead: string[];
  gituCanWrite: string[];
}
```

**Bidirectional Communication Flows:**

#### Flow 1: Coding Agent → Gitu (Task Delegation)

```
┌─────────────────┐                    ┌─────────────────┐
│  Coding Agent   │                    │      Gitu       │
│  (Claude/Kiro)  │                    │   (Background)  │
└────────┬────────┘                    └────────┬────────┘
         │                                      │
         │  1. "Deploy this code to prod"      │
         │─────────────────────────────────────>│
         │                                      │
         │                                      │ 2. Connects to VPS
         │                                      │ 3. Runs deployment
         │                                      │ 4. Monitors status
         │                                      │
         │  5. "Deployed successfully ✅"       │
         │<─────────────────────────────────────│
         │                                      │
         │                                      │ 6. Sends WhatsApp
         │                                      │    notification to user
         │                                      │
```

#### Flow 2: Gitu → Coding Agent (Collaboration)

```
┌─────────────────┐                    ┌─────────────────┐
│      Gitu       │                    │  Coding Agent   │
│  (WhatsApp Bot) │                    │  (User's IDE)   │
└────────┬────────┘                    └────────┬────────┘
         │                                      │
         │  1. User: "Fix the login bug"       │
         │                                      │
         │  2. Gitu analyzes logs              │
         │  3. Identifies issue                │
         │                                      │
         │  4. "Found bug in auth.ts line 42"  │
         │─────────────────────────────────────>│
         │     + Code context                   │
         │     + Error logs                     │
         │     + Suggested fix                  │
         │                                      │
         │                                      │ 5. Agent applies fix
         │                                      │ 6. Runs tests
         │                                      │
         │  7. "Fixed and tested ✅"            │
         │<─────────────────────────────────────│
         │                                      │
         │  8. Notifies user on WhatsApp       │
         │                                      │
```

**Collaborative Workflows:**

#### Workflow 1: Full-Stack Development

```typescript
// User asks Gitu via WhatsApp
User (WhatsApp): "Build a user registration API"

// Gitu creates plan and delegates to coding agent
Gitu → Coding Agent (MCP):
{
  task: "Implement user registration API",
  requirements: [
    "POST /api/register endpoint",
    "Email validation",
    "Password hashing",
    "JWT token generation"
  ],
  context: {
    framework: "Express.js",
    database: "PostgreSQL",
    existingCode: "github.com/user/project"
  }
}

// Coding agent implements
Coding Agent:
- Writes code
- Generates tests
- Creates documentation

// Coding agent asks Gitu for deployment
Coding Agent → Gitu (MCP):
{
  task: "Deploy to production",
  code: "...",
  tests: "all passing"
}

// Gitu handles deployment
Gitu:
- Connects to VPS
- Runs deployment script
- Monitors health
- Notifies user on WhatsApp

// User gets notification
Gitu → User (WhatsApp):
"✅ User registration API deployed!
- Endpoint: https://api.example.com/register
- Tests: 15/15 passing
- Response time: 120ms
- Server health: Good"
```

#### Workflow 2: Bug Investigation & Fix

```typescript
// Gitu monitors server (background task)
Gitu (Background):
- Detects error spike
- Analyzes logs
- Identifies root cause

// Gitu notifies user
Gitu → User (WhatsApp):
"⚠️ Error spike detected in payment service
- Error: Database connection timeout
- Affected: 23 requests
- Root cause: Connection pool exhausted"

// User responds
User (WhatsApp): "Fix it"

// Gitu delegates to coding agent
Gitu → Coding Agent (MCP):
{
  task: "Fix database connection pool issue",
  context: {
    error: "Connection pool exhausted",
    file: "src/db/connection.ts",
    logs: "..."
  }
}

// Coding agent fixes
Coding Agent:
- Analyzes code
- Increases pool size
- Adds connection retry logic
- Updates tests

// Coding agent confirms
Coding Agent → Gitu (MCP):
{
  status: "fixed",
  changes: "Increased pool size, added retry logic",
  tested: true
}

// Gitu deploys and monitors
Gitu:
- Deploys fix
- Monitors error rate
- Confirms fix working

// Gitu notifies user
Gitu → User (WhatsApp):
"✅ Payment service fixed!
- Error rate: 0%
- Response time: Normal
- All systems operational"
```

#### Workflow 3: Research → Code → Deploy

```typescript
// User asks Gitu for research
User (Telegram): "Research best practices for rate limiting APIs"

// Gitu conducts research
Gitu:
- Searches web
- Analyzes articles
- Generates report

// Gitu shares findings with coding agent
Gitu → Coding Agent (MCP):
{
  task: "Implement rate limiting based on research",
  research: {
    recommendations: [
      "Use token bucket algorithm",
      "Rate limit per user and per IP",
      "Return 429 status with Retry-After header"
    ],
    libraries: ["express-rate-limit", "rate-limiter-flexible"],
    examples: "..."
  }
}

// Coding agent implements
Coding Agent:
- Installs library
- Implements rate limiting
- Adds tests
- Updates documentation

// Coding agent asks Gitu to test
Coding Agent → Gitu (MCP):
{
  task: "Load test rate limiting",
  endpoint: "http://localhost:3000/api/users"
}

// Gitu runs load tests
Gitu:
- Sends 1000 requests/second
- Verifies rate limiting works
- Checks response headers

// Gitu confirms and deploys
Gitu → User (Telegram):
"✅ Rate limiting implemented and tested!
- Algorithm: Token bucket
- Limit: 100 requests/minute per user
- Load test: Passed
- Deployed to production"
```

**MCP Tools for Agent-Gitu Communication:**

```typescript
// New MCP tools for bidirectional communication

interface GituMCPTools {
  // Send message to Gitu
  gitu_send_message(params: {
    message: string;
    context?: any;
    requestType: 'question' | 'task' | 'review';
  }): Promise<GituResponse>;
  
  // Delegate task to Gitu
  gitu_delegate_task(params: {
    task: string;
    taskType: 'deploy' | 'monitor' | 'research' | 'notify';
    params: any;
  }): Promise<TaskResult>;
  
  // Get Gitu's current status
  gitu_get_status(): Promise<GituStatus>;
  
  // Access Gitu's memory
  gitu_get_memory(params: {
    query?: string;
    category?: string;
  }): Promise<Memory[]>;
  
  // Ask Gitu to notify user
  gitu_notify_user(params: {
    message: string;
    platform: 'whatsapp' | 'telegram' | 'email' | 'flutter';
    priority: 'low' | 'medium' | 'high';
  }): Promise<void>;
  
  // Collaborative workspace
  gitu_create_workspace(params: {
    name: string;
    sharedResources: string[];
  }): Promise<Workspace>;
}
```

**Example: Coding Agent Uses Gitu's Capabilities**

```typescript
// In Claude Desktop / Cursor / Kiro

// 1. Agent writes code
const code = generateUserAuthCode();

// 2. Agent asks Gitu to review
const review = await gitu_send_message({
  message: "Review this authentication code",
  context: { code, language: "typescript" },
  requestType: "review"
});

// 3. Agent applies Gitu's suggestions
const improvedCode = applyReviewSuggestions(code, review.suggestions);

// 4. Agent asks Gitu to deploy
await gitu_delegate_task({
  task: "Deploy authentication service",
  taskType: "deploy",
  params: {
    code: improvedCode,
    server: "production",
    runTests: true
  }
});

// 5. Agent asks Gitu to monitor
await gitu_delegate_task({
  task: "Monitor authentication service",
  taskType: "monitor",
  params: {
    service: "auth",
    alertOn: ["error_rate > 1%", "response_time > 500ms"]
  }
});

// 6. Agent asks Gitu to notify user
await gitu_notify_user({
  message: "Authentication service deployed and monitored ✅",
  platform: "whatsapp",
  priority: "medium"
});
```

**Benefits of Agent-Gitu Communication:**

1. **Division of Labor**
   - Coding Agent: Write code, run tests, analyze codebase
   - Gitu: Deploy, monitor, notify, research, manage infrastructure

2. **24/7 Collaboration**
   - Coding agent works when user is coding
   - Gitu works in background 24/7
   - Seamless handoff between them

3. **Multi-Platform Reach**
   - Coding agent in IDE
   - Gitu accessible via WhatsApp, Telegram, Email
   - User can interact from anywhere

4. **Complementary Strengths**
   - Coding agent: Deep code understanding, IDE integration
   - Gitu: Infrastructure access, multi-platform, autonomous operation

5. **Unified Context**
   - Both share access to notebooks, plans, memories
   - Consistent understanding of user's projects
   - No context loss in handoffs

**This creates a true AI development team where coding agents and Gitu work together seamlessly!**

