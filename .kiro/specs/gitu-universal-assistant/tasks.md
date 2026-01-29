# Implementation Tasks: Gitu - Universal AI Assistant

## Phase 1: MVP (Months 1-2) - Core Foundation

### 1.1 Database Setup

**Task 1.1.1: Create Gitu Database Schema**
- [x] Run migration: `backend/migrations/add_gitu_core.sql`
- [x] Create tables: gitu_sessions, gitu_memories, gitu_linked_accounts
- [x] Create tables: gitu_permissions, gitu_usage_records, gitu_usage_limits
- [x] Add indexes for performance
- [x] Test schema with sample data
- **Estimated Time:** 4 hours
- **Dependencies:** None

**Task 1.1.2: Extend Users Table**
- [x] Add `gitu_enabled` boolean column to users table
- [x] Add `gitu_settings` JSONB column to users table
- [x] Create migration script
- [x] Test with existing users
- **Estimated Time:** 2 hours
- **Dependencies:** Task 1.1.1

### 1.2 Backend Core Service

**Task 1.2.1: Session Manager**
- [x] Create `backend/src/services/gituSessionService.ts`
- [x] Implement `getOrCreateSession()`
- [x] Implement `updateSession()`
- [x] Implement `endSession()`
- [x] Add session cleanup cron job
- [x] Write unit tests
- **Estimated Time:** 8 hours
- **Dependencies:** Task 1.1.1

**Task 1.2.2: AI Router**
- [x] Create `backend/src/services/gituAIRouter.ts`
- [x] Implement model selection logic
- [x] Implement cost estimation
- [x] Implement fallback logic
- [x] Add support for platform vs personal keys
- [x] Write unit tests
- **Estimated Time:** 12 hours
- **Dependencies:** None

**Task 1.2.3: Usage Governor**
- [x] Create `backend/src/services/gituUsageGovernor.ts`
- [x] Implement budget checking
- [x] Implement usage tracking
- [x] Implement threshold alerts
- [x] Add circuit breaker logic
- [ ] Write unit tests
- **Estimated Time:** 10 hours
- **Dependencies:** Task 1.2.2

**Task 1.2.4: Permission Manager**
- [x] Create `backend/src/services/gituPermissionManager.ts`
- [x] Implement permission CRUD
- [x] Implement permission checking
- [x] Add permission scopes
- [x] Write unit tests
- **Estimated Time:** 8 hours
- **Dependencies:** Task 1.1.1

### 1.3 Message Gateway

**Task 1.3.1: Message Normalization**
- [x] Create `backend/src/services/gituMessageGateway.ts`
- [x] Define `IncomingMessage` interface
- [x] Implement message normalization
- [x] Add platform detection
- [ ] Write unit tests
- **Estimated Time:** 6 hours
- **Dependencies:** None

**Task 1.3.2: Telegram Bot Adapter**
- [x] Create `backend/src/adapters/telegramAdapter.ts`
- [x] Initialize Telegram Bot API
- [x] Implement message sending
- [x] Implement message receiving
- [x] Add command handling
- [x] Test with real Telegram bot
- **Estimated Time:** 12 hours
- **Dependencies:** Task 1.3.1

**Task 1.3.3: Terminal CLI Adapter**
- [x] Create `backend/src/adapters/terminalAdapter.ts`
- [x] Implement REPL interface
- [x] Add command parsing
- [x] Add response formatting
- [x] Add colored output with chalk
- [x] Add progress indicators with ora
- [x] Add command history management
- [x] Add built-in commands (help, status, session, clear, exit, history)
- [x] Test on Windows/Linux/macOS
- **Status:** ✅ Complete
- **Estimated Time:** 10 hours
- **Dependencies:** Task 1.3.1

**Task 1.3.3.1: Terminal Authentication System**
- [x] Create `backend/src/routes/gitu.ts` with auth endpoints
- [x] Create `backend/src/services/gituTerminalService.ts`
- [x] Implement pairing token generation (5-minute expiry)
- [x] Implement token validation and device linking
- [x] Add JWT-based auth token generation (90-day expiry)
- [x] Add device management (list, unlink)
- [x] Create database migration for pairing tokens table
- [x] Add auth commands to terminal adapter:
  - [x] `gitu auth <token>` - Link terminal with pairing token
  - [x] `gitu auth status` - Check authentication status
  - [x] `gitu auth logout` - Unlink terminal
  - [x] `gitu auth refresh` - Refresh auth token
- [x] Implement secure credential storage in `~/.gitu/credentials.json`
- [x] Add device ID generation and persistence
- [x] Test token-based auth flow end-to-end
- **Status:** Not started
- **Estimated Time:** 12 hours
- **Dependencies:** Task 1.3.3

**Task 1.3.3.2: QR Code Authentication (Alternative Method)**
- [x] Install QR code generation library (`qrcode-terminal`)
- [x] Create WebSocket endpoint for QR auth: `/api/gitu/terminal/qr-auth`
- [x] Implement QR code generation with session ID
- [x] Add `gitu auth --qr` command to display QR code in terminal
- [x] Create Flutter UI for QR code scanning
- [x] Implement QR code scanning in Flutter app (using `qr_code_scanner`)
- [x] Add WebSocket connection for real-time auth confirmation
- [x] Send auth token to terminal via WebSocket after scan
- [x] Add QR code expiry (2 minutes)
- [-] Test QR auth flow on mobile devices
- [ ] Add fallback to token-based auth if QR fails
- **Status:** In Progress
- **Estimated Time:** 14 hours
- **Dependencies:** Task 1.3.3.1

**Task 1.3.3.3: Flutter Terminal Connection UI**
- [x] Create `lib/features/gitu/terminal_connection_screen.dart`
- [x] Add "Link Terminal" button
- [x] Implement pairing token generation and display
- [x] Add token expiry countdown timer
- [x] Add QR code display option (toggle between token and QR)
- [x] Show list of linked terminals with device names
- [x] Add unlink functionality for each device
- [x] Show last used timestamp for each device
- [x] Add copy-to-clipboard for pairing token
- [ ] Test UI on iOS and Android
- **Status:** In Progress
- **Estimated Time:** 10 hours
- **Dependencies:** Task 1.3.3.1, Task 1.3.3.2

**Task 1.3.4: Flutter App Adapter**
- [x] Create `backend/src/adapters/flutterAdapter.ts`
- [x] Implement WebSocket connection
- [x] Add message routing
- [x] Add real-time updates
- [ ] Test with Flutter app
- **Status:** In Progress
- **Estimated Time:** 8 hours
- **Dependencies:** Task 1.3.1

### 1.4 Flutter App Integration

**Task 1.4.1: Gitu Settings Screen**
- [x] Create `lib/features/gitu/gitu_settings_screen.dart`
- [x] Add enable/disable toggle
- [x] Add connection status card
- [x] Add API key selection (platform vs personal)
- [x] Add AI model selection
- [x] Add platform connections section
- [x] Test UI on iOS/Android
- **Status:** Completed
- **Estimated Time:** 16 hours
- **Dependencies:** None

**Task 1.4.2: Gitu Provider**
- [x] Create `lib/features/gitu/gitu_provider.dart`
- [x] Implement state management
- [x] Add API calls to backend
- [x] Add WebSocket connection
- [x] Handle real-time updates
- [x] Write widget tests
- **Status:** Completed
- **Estimated Time:** 12 hours
- **Dependencies:** Task 1.4.1

**Task 1.4.3: Gitu Chat Interface**
- [x] Create `lib/features/gitu/gitu_chat_screen.dart`
- [x] Add message list
- [x] Add input field
- [x] Add platform indicator
- [x] Add typing indicator
- [x] Test chat flow
- **Status:** Completed
- **Estimated Time:** 10 hours
- **Dependencies:** Task 1.4.2

### 1.5 MCP Integration

**Task 1.5.1: MCP Hub Service**
- [x] Create `backend/src/services/gituMCPHub.ts`
- [x] Implement tool discovery
- [x] Implement tool execution
- [x] Add error handling
- [x] Add quota checking
- [x] Write integration tests
- **Status:** Completed
- **Estimated Time:** 12 hours
- **Dependencies:** Task 1.2.3

**Task 1.5.2: Notebook MCP Tools Integration**
- [x] Test `list_notebooks` tool
- [x] Test `get_source` tool
- [x] Test `search_sources` tool
- [x] Test `verify_code` tool
- [x] Test `review_code` tool
- [x] Document usage patterns
- **Status:** Completed
- **Estimated Time:** 8 hours
- **Dependencies:** Task 1.5.1

### 1.6 API Routes

**Task 1.6.1: Gitu REST API**
- [x] Create `backend/src/routes/gitu.ts`
- [x] Add POST `/api/gitu/message` endpoint
- [x] Add GET `/api/gitu/sessions` endpoint
- [x] Add GET `/api/gitu/status` endpoint
- [x] Add authentication middleware
- [x] Write API tests
- **Status:** Completed
- **Estimated Time:** 10 hours
- **Dependencies:** Task 1.2.1

**Task 1.6.2: WebSocket API**
- [x] Create `backend/src/services/gituWebSocketService.ts`
- [x] Implement connection handling
- [x] Implement message broadcasting
- [x] Add authentication
- [x] Test real-time communication
- **Status:** Completed
- **Estimated Time:** 8 hours
- **Dependencies:** Task 1.6.1

### 1.7 Testing & Documentation

**Task 1.7.1: Unit Tests**
- [x] Write tests for SessionManager
- [x] Write tests for AIRouter
- [x] Write tests for UsageGovernor
- [x] Write tests for PermissionManager
- [x] Achieve 80% code coverage
- **Status:** Completed
- **Estimated Time:** 16 hours
- **Dependencies:** All Phase 1 tasks

**Task 1.7.2: Integration Tests**
- [x] Test Telegram bot end-to-end
- [x] Test Terminal CLI end-to-end
- [x] Test Flutter app end-to-end
- [x] Test MCP tool execution
- [x] Test cost tracking
- **Status:** Completed
- **Estimated Time:** 12 hours
- **Dependencies:** Task 1.7.1

**Task 1.7.3: Documentation**
- [ ] Create `backend/docs/API.md`
- [ ] Create `backend/docs/ARCHITECTURE.md`
- [ ] Create `backend/docs/TESTING.md`
- [ ] Update `backend/README.md`
- **Estimated Time:** 4 hours
- **Dependencies:** All Phase 1 tasks

**Phase 1 Total Estimated Time:** ~192 hours (4-5 weeks with 1 developer)

---

## Phase 2: Multi-Platform & Memory (Months 3-4)

### 2.1 WhatsApp Integration (Baileys)

**Task 2.1.1: Baileys Setup**
- [x] Install Baileys library
- [x] Create `backend/src/adapters/whatsappAdapter.ts`
- [x] Implement QR code generation
- [x] Implement session persistence
- [x] Test connection
- **Status:** Completed
- **Estimated Time:** 12 hours
- **Dependencies:** Phase 1 complete

**Task 2.1.2: WhatsApp Message Handling**
- [x] Implement message sending
- [x] Implement message receiving
- [x] Add media support (images, documents)
- [x] Add formatting support (bold, italic)
- [x] Test with real WhatsApp account
- **Status:** Completed
- **Estimated Time:** 16 hours
- **Dependencies:** Task 2.1.1

**Task 2.1.3: WhatsApp Health Monitoring**
- [x] Create `backend/src/services/whatsappHealthMonitor.ts`
- [x] Implement connection health checking
- [x] Add auto-reconnect logic
- [x] Add fallback to Telegram
- [x] Add user notifications
- [x] Test integration
- **Status:** Completed
- **Estimated Time:** 10 hours
- **Dependencies:** Task 2.1.2

**Task 2.1.4: WhatsApp QR Code UI**
- [x] Create `lib/features/gitu/whatsapp_connect_dialog.dart`
- [x] Add QR code display
- [x] Add connection status
- [x] Add disconnect button
- [x] Test on iOS/Android
- **Status:** Completed
- **Estimated Time:** 8 hours
- **Dependencies:** Task 2.1.1

### 2.2 Enhanced Memory System

**Task 2.2.1: Memory Service with Trust Layer**
 - [x] Create `backend/src/services/gituMemoryService.ts`
 - [x] Implement memory CRUD with verification
 - [x] Add confidence scoring
 - [x] Add contradiction detection
 - [x] Write unit tests
 - **Status:** Completed
- **Estimated Time:** 14 hours
- **Dependencies:** Phase 1 complete

**Task 2.2.2: Memory Verification Workflow**
 - [x] Implement verification requests
 - [x] Add user confirmation flow
 - [x] Add memory correction
 - [x] Add expiry for unverified memories
 - [x] Test verification flow
 - **Status:** Completed
- **Estimated Time:** 10 hours
- **Dependencies:** Task 2.2.1

**Task 2.2.3: Memory UI in Flutter**
 - [x] Create `lib/features/gitu/memory_screen.dart`
 - [x] Display memories by category
 - [x] Add edit/delete functionality
 - [x] Add verification status
 - [x] Add search functionality
 - **Status:** Completed
- **Estimated Time:** 12 hours
- **Dependencies:** Task 2.2.2

### 2.3 Background Agent Scheduler

**Task 2.3.1: Scheduler Service**
- [x] Create `backend/src/services/gituScheduler.ts`
- [x] Implement cron-based scheduling
- [x] Implement event-based triggers
- [x] Add task execution
- [x] Add error handling and retries
- **Status:** Completed
- **Estimated Time:** 16 hours
- **Dependencies:** Phase 1 complete

**Task 2.3.2: Heartbeat Monitoring**
- [x] Implement system health checks
- [x] Add service status monitoring
- [x] Add alert system
- [x] Add auto-restart logic
- [x] Test reliability
- **Status:** Completed
- **Estimated Time:** 8 hours
- **Dependencies:** Task 2.3.1

**Task 2.3.3: Scheduled Tasks UI**
- [x] Create `lib/features/gitu/scheduled_tasks_screen.dart`
- [x] Display task list
- [x] Add create/edit/delete
- [x] Add enable/disable toggle
- [x] Show execution history
- **Status:** Completed
- **Estimated Time:** 12 hours
- **Dependencies:** Task 2.3.1

### 2.4 Identity Unification

**Task 2.4.1: Identity Manager**
- [x] Create `backend/src/services/gituIdentityManager.ts`
- [x] Implement account linking
- [x] Implement identity verification
- [x] Add platform trust levels
- [x] Write unit tests
- **Status:** Completed
- **Estimated Time:** 10 hours
- **Dependencies:** Phase 1 complete

**Task 2.4.2: Linked Accounts UI**
- [x] Add linked accounts section to settings
- [x] Show all connected platforms
- [x] Add link/unlink functionality
- [x] Show last used timestamps
- [x] Test account linking flow
- **Status:** Completed
- **Estimated Time:** 8 hours
- **Dependencies:** Task 2.4.1

**Phase 2 Total Estimated Time:** ~136 hours (3-4 weeks with 1 developer)

---

## Phase 3: Integrations (Months 5-6)

### 3.1 Gmail Integration

**Task 3.1.1: Gmail OAuth Setup**
- [x] Set up Google Cloud project
- [x] Configure OAuth 2.0 credentials
- [x] Create `backend/src/services/gituGmailManager.ts`
- [x] Implement OAuth flow
- [x] Test authentication
- **Status:** Completed
- **Estimated Time:** 8 hours
- **Dependencies:** Phase 2 complete

**Task 3.1.2: Gmail Operations**
- [x] Implement email listing
- [x] Implement email reading
- [x] Implement email sending
- [x] Implement email search
- [x] Add label management
- **Status:** Completed
- **Estimated Time:** 16 hours
- **Dependencies:** Task 3.1.1

**Task 3.1.3: Gmail AI Features**
- [x] Implement email summarization
- [x] Implement smart reply suggestions
- [x] Implement action item extraction
- [x] Add sentiment analysis
- [x] Test AI features
- **Status:** Completed
- **Estimated Time:** 12 hours
- **Dependencies:** Task 3.1.2

**Task 3.1.4: Gmail UI**
- [x] Create Gmail connection screen
- [x] Add OAuth button
- [x] Show connection status
- [x] Add disconnect option
- [x] Test on iOS/Android
- **Status:** Completed
- **Estimated Time:** 6 hours
- **Dependencies:** Task 3.1.1

### 3.2 Shopify Integration

**Task 3.2.1: Shopify API Setup**
- [x] Create `backend/src/services/gituShopifyManager.ts`
- [x] Implement API key authentication
- [x] Test connection
- **Status:** Completed
- **Estimated Time:** 4 hours
- **Dependencies:** Phase 2 complete

**Task 3.2.2: Shopify Operations**
- [x] Implement order listing
- [x] Implement inventory checking
- [x] Implement product management
- [x] Add analytics queries
- [x] Test operations
- **Status:** Completed
- **Estimated Time:** 12 hours
- **Dependencies:** Task 3.2.1

**Task 3.2.3: Shopify UI**
- [x] Create Shopify connection screen
- [x] Add API key input
- [x] Show store info
- [x] Add disconnect option
- [x] Test configuration
- **Status:** Completed
- **Estimated Time:** 6 hours
- **Dependencies:** Task 3.2.1

### 3.3 File System Access

**Task 3.3.1: File Manager**
- [x] Create `backend/src/services/gituFileManager.ts`
- [x] Implement path validation
- [x] Implement file operations (read, write, list)
- [x] Add permission checking
- [x] Add audit logging
- **Status:** Completed
- **Estimated Time:** 12 hours
- **Dependencies:** Phase 2 complete

**Task 3.3.2: File Permissions UI**
- [x] Create file access configuration screen
- [x] Add allowed paths management
- [x] Show file operation logs
- [x] Add revoke access option
- [x] Test permissions
- **Status:** Completed
- **Estimated Time:** 8 hours
- **Dependencies:** Task 3.3.1

**Phase 3 Total Estimated Time:** ~84 hours (2 weeks with 1 developer)

---

## Phase 4: Autonomous Features (Months 7-8)

### 4.1 Shell Access Manager

**Task 4.1.1: Shell Permissions & Trust Modes**
- [x] Add `shell` as a valid resource in `backend/src/services/gituPermissionManager.ts`
- [x] Define `ShellTrustMode` ('sandboxed' | 'unsandboxed')
- [x] Create migration for `gitu_shell_audit_logs` table
- **Estimated Time:** 8 hours
- **Dependencies:** Task 3.3.1

**Task 4.1.2: Local Shell Command Execution**
- [x] Create `backend/src/services/gituShellManager.ts`
- [x] Implement `execute(command, mode)` method
- [x] Integrate with `gituPermissionManager` for scope validation
- [x] Implement output streaming (stdout/stderr) via WebSocket
- **Estimated Time:** 16 hours
- **Dependencies:** Task 4.1.1

**Task 4.1.3: Sandbox Policy with Docker**
- [x] Implement Docker containerization for all shell executions
- [x] Create ephemeral Docker image with restricted tools
- [x] Implement volume mounting for specific user directories only
- [x] Add a CLI switch to choose sandboxing: `--sandbox` (default, uses Docker) or `--no-sandbox` (requires admin)
- [x] Enforce extra confirmation for `--no-sandbox` (and deny by default)
- [x] Add policy unit tests and security regression tests
- **Estimated Time:** 20 hours
- **Dependencies:** Task 4.1.2

**Task 4.1.4: Terminal CLI Integration**
- [x] Add `gitu run` command (execute a shell command through the backend)
- [x] Support sandbox selection (`--sandbox` / `--no-sandbox`) and timeouts
- [x] Print structured output (stdout/stderr/exitCode) and optionally JSON
- [x] Show audit log reference IDs on completion
- [x] Test end-to-end with terminal auth + permissions
- **Estimated Time:** 10 hours
- **Dependencies:** Task 4.1.2

### 4.2 Advanced Permissions

**Task 4.2.1: Granular Permissions**
- [x] Extend permission system with scopes
- [x] Add time-based expiry
- [x] Add permission requests
- [x] Implement approval workflow
- [x] Test permissions
- **Estimated Time:** 12 hours
- **Dependencies:** Phase 3 complete

**Task 4.2.2: Permissions UI**
- [x] Create permissions management screen
- [x] Show all granted permissions
- [x] Add revoke functionality
- [x] Show permission requests
- [x] Test UI flow
- **Estimated Time:** 8 hours
- **Dependencies:** Task 4.2.1

### 4.3 Rule Engine

**Task 4.3.1: Rule Service**
- [x] Create `backend/src/services/gituRuleEngine.ts`
- [x] Implement rule creation
- [x] Implement rule execution
- [x] Add rule validation
- [x] Test rules
- **Estimated Time:** 14 hours
- **Dependencies:** Phase 3 complete

**Task 4.3.2: Rule UI**
- [x] Create rule builder screen
- [x] Add IF-THEN editor
- [x] Add rule testing
- [x] Show rule execution history
- [x] Test rule creation
- **Estimated Time:** 12 hours
- **Dependencies:** Task 4.3.1

### 4.4 Plugin System

**Task 4.4.1: Plugin Framework**
- [x] Create `backend/src/services/gituPluginSystem.ts`
- [x] Define plugin interface
- [x] Implement plugin loading
- [x] Add sandboxing
- [x] Test plugin execution
- **Estimated Time:** 16 hours
- **Dependencies:** Phase 3 complete

**Task 4.4.2: Plugin Marketplace**
- [ ] Create plugin discovery API
- [ ] Add plugin installation
- [ ] Add plugin configuration
- [ ] Test plugin lifecycle
- **Estimated Time:** 12 hours
- **Dependencies:** Task 4.4.1

**Phase 4 Total Estimated Time:** ~122 hours (3 weeks with 1 developer)

---

## Phase 5: Intelligence & Voice (Months 9-10)

### 5.1 Voice Interaction

**Task 5.1.1: Voice Input**
- [x] Integrate speech-to-text (Deepgram/Whisper)
- [x] Add voice message handling
- [x] Test across platforms
- **Estimated Time:** 10 hours
- **Dependencies:** Phase 4 complete

**Task 5.1.2: Voice Output**
- [ ] Integrate murf for TTS
- [ ] Add voice model selection
- [ ] Test voice responses
- **Estimated Time:** 8 hours
- **Dependencies:** Task 5.1.1

**Task 5.1.3: Wake Word Detection**
- [ ] Implement wake word ("Hey Gitu")
- [ ] Add always-listening mode
- [ ] Test wake word accuracy
- **Estimated Time:** 12 hours
- **Dependencies:** Task 5.1.2

### 5.2 Proactive Assistance

**Task 5.2.1: Pattern Analysis**
- [ ] Create `backend/src/services/gituProactiveAssistant.ts`
- [ ] Implement behavior pattern detection
- [ ] Add suggestion generation
- [ ] Test suggestions
- **Estimated Time:** 14 hours
- **Dependencies:** Phase 4 complete

**Task 5.2.2: Proactive Notifications**
- [ ] Implement notification system
- [ ] Add user preference controls
- [ ] Add feedback learning
- [ ] Test notifications
- **Estimated Time:** 10 hours
- **Dependencies:** Task 5.2.1

### 5.3 Agent Skills Integration

**Task 5.3.1: Skills Access**
- [ ] Integrate with agent skills catalog
- [ ] Add skill execution
- [ ] Add skill composition
- [ ] Test skills
- **Estimated Time:** 8 hours
- **Dependencies:** Phase 4 complete

**Task 5.3.2: Custom Skills**
- [ ] Add custom skill creation UI
- [ ] Add skill testing
- [ ] Add skill sharing
- [ ] Test custom skills
- **Estimated Time:** 10 hours
- **Dependencies:** Task 5.3.1

### 5.4 Analytics

**Task 5.4.1: Usage Analytics**
- [ ] Create analytics dashboard
- [ ] Add usage statistics
- [ ] Add cost tracking
- [ ] Add time saved estimates
- [ ] Test analytics
- **Estimated Time:** 12 hours
- **Dependencies:** Phase 4 complete

**Task 5.4.2: Analytics UI**
- [ ] Create analytics screen in Flutter
- [ ] Add charts and graphs
- [ ] Add export functionality
- [ ] Test UI
- **Estimated Time:** 10 hours
- **Dependencies:** Task 5.4.1

**Phase 5 Total Estimated Time:** ~94 hours (2-3 weeks with 1 developer)

---

## Phase 6: Polish & Security (Months 11-12)

### 6.1 Security Hardening

**Task 6.1.1: Security Audit**
- [ ] Conduct penetration testing
- [ ] Fix identified vulnerabilities
- [ ] Review all authentication flows
- [ ] Review all permission checks
- **Estimated Time:** 24 hours
- **Dependencies:** Phase 5 complete

**Task 6.1.2: Encryption**
- [ ] Verify encryption at rest
- [ ] Verify encryption in transit
- [ ] Add key rotation
- [ ] Test encryption
- **Estimated Time:** 12 hours
- **Dependencies:** Task 6.1.1

**Task 6.1.3: Compliance**
- [ ] GDPR compliance review
- [ ] Add data export functionality
- [ ] Add data deletion functionality
- [ ] Create privacy policy
- **Estimated Time:** 16 hours
- **Dependencies:** Task 6.1.2

### 6.2 Performance Optimization

**Task 6.2.1: Load Testing**
- [ ] Set up load testing environment
- [ ] Test with 1,000 concurrent users
- [ ] Identify bottlenecks
- [ ] Optimize slow queries
- **Estimated Time:** 16 hours
- **Dependencies:** Phase 5 complete

**Task 6.2.2: Caching**
- [x] Implement Redis caching
- [x] Add cache invalidation
- [x] Test cache performance
- **Status:** ✅ Complete
- **Estimated Time:** 10 hours
- **Dependencies:** Task 6.2.1

**Task 6.2.3: Database Optimization**
- [ ] Add missing indexes
- [ ] Optimize slow queries
- [ ] Set up read replicas
- [ ] Test performance
- **Estimated Time:** 12 hours
- **Dependencies:** Task 6.2.2

### 6.3 Cost Optimization

**Task 6.3.1: Model Selection Optimization**
- [ ] Analyze model usage patterns
- [ ] Implement smart model selection
- [ ] Add aggressive caching
- [ ] Test cost savings
- **Estimated Time:** 10 hours
- **Dependencies:** Phase 5 complete

**Task 6.3.2: Usage Governor Tuning**
- [ ] Analyze usage patterns
- [ ] Tune budget limits
- [ ] Optimize alert thresholds
- [ ] Test governor
- **Estimated Time:** 8 hours
- **Dependencies:** Task 6.3.1

### 6.4 User Experience

**Task 6.4.1: Onboarding Wizard**
- [ ] Create onboarding flow
- [ ] Add step-by-step setup
- [ ] Add tutorial
- [ ] Test onboarding
- **Estimated Time:** 12 hours
- **Dependencies:** Phase 5 complete

**Task 6.4.2: Error Messages**
- [ ] Review all error messages
- [ ] Make messages user-friendly
- [ ] Add helpful suggestions
- [ ] Test error handling
- **Estimated Time:** 8 hours
- **Dependencies:** Task 6.4.1

**Task 6.4.3: Documentation**
- [ ] Write comprehensive user guide
- [ ] Create video tutorials
- [ ] Write API documentation
- [ ] Create troubleshooting guide
- **Estimated Time:** 20 hours
- **Dependencies:** Task 6.4.2

### 6.5 Beta Testing

**Task 6.5.1: Beta Program**
- [ ] Recruit beta testers
- [ ] Set up feedback collection
- [ ] Monitor usage
- [ ] Collect feedback
- **Estimated Time:** 40 hours (ongoing)
- **Dependencies:** All Phase 6 tasks

**Task 6.5.2: Bug Fixes**
- [ ] Fix reported bugs
- [ ] Improve based on feedback
- [ ] Refine features
- [ ] Test fixes
- **Estimated Time:** 40 hours (ongoing)
- **Dependencies:** Task 6.5.1

**Phase 6 Total Estimated Time:** ~228 hours (5-6 weeks with 1 developer)

---

## Total Project Estimate

- **Phase 1:** 192 hours (4-5 weeks)
- **Phase 2:** 136 hours (3-4 weeks)
- **Phase 3:** 84 hours (2 weeks)
- **Phase 4:** 122 hours (3 weeks)
- **Phase 5:** 94 hours (2-3 weeks)
- **Phase 6:** 228 hours (5-6 weeks)

**Total:** ~856 hours (19-23 weeks / 5-6 months with 1 full-time developer)

**With 2 developers:** 10-12 weeks (2.5-3 months)

---

## Priority Tasks (Must-Have for MVP)

1. ✅ Database schema (Task 1.1.1)
2. ✅ Session manager (Task 1.2.1)
3. ✅ AI router (Task 1.2.2)
4. ✅ Usage governor (Task 1.2.3)
5. ✅ Telegram adapter (Task 1.3.2)
6. ✅ Flutter settings UI (Task 1.4.1)
7. ✅ MCP integration (Task 1.5.1)
8. ✅ REST API (Task 1.6.1)

## Nice-to-Have (Can be deferred)

- Voice interaction (Phase 5)
- Plugin system (Phase 4)
- Advanced analytics (Phase 5)
- Shopify integration (Phase 3)

## Continuous Tasks

- Security monitoring (ongoing)
- Performance monitoring (ongoing)
- Cost optimization (ongoing)
- User feedback collection (ongoing)
- Documentation updates (ongoing)

