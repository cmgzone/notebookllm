# Gitu - Universal AI Assistant

## Overview
Gitu is an autonomous, multi-platform AI assistant that works in the background across all user touchpoints - WhatsApp (via Baileys), Telegram, email, terminal, and more. Unlike coding-focused agents, Gitu is a general-purpose assistant that can access notebooks, Gmail, Shopify, files, servers, and custom integrations while maintaining strict permission controls and memory persistence.

**Primary Configuration Interface**: The existing NotebookLLM Flutter app serves as the main control panel for configuring Gitu, managing API keys (personal or platform), selecting AI models, and controlling all settings.

## Vision Statement
Create an always-available, context-aware AI assistant that users can interact with from anywhere, that learns from every interaction, can execute tasks autonomously, and integrates seamlessly with the user's digital ecosystem - all configured through the familiar NotebookLLM app interface.

## User Stories

### US-0: Flutter App Configuration Hub
**As a user**, I want to configure and manage Gitu entirely through the NotebookLLM Flutter app so that I have a centralized, familiar interface for all settings.

**Acceptance Criteria:**
- User accesses Gitu settings from NotebookLLM app settings menu
- User can enable/disable Gitu assistant
- User can view Gitu status (online, offline, busy)
- User can configure which platforms Gitu responds on
- User can set Gitu's personality and behavior
- User can view Gitu activity logs
- User can manage connected platforms (WhatsApp, Telegram, etc.)
- Settings sync across all devices running NotebookLLM app

### US-0.1: API Key Management
**As a user**, I want to choose between using my own API keys or platform-provided keys so that I have flexibility in how I use AI services.

**Acceptance Criteria:**
- User can select "Use Platform Keys" or "Use My Own Keys"
- When using own keys, user can add OpenRouter, Gemini, OpenAI, Anthropic keys
- User can set different keys for different purposes (chat, research, coding)
- User can view API usage and costs per key
- User can switch between platform and personal keys anytime
- Platform keys respect user's subscription tier
- Personal keys bypass platform rate limits
- User receives warnings when keys are near quota limits
- Keys are encrypted and stored securely
- User can test keys before saving

### US-0.2: AI Model Selection
**As a user**, I want Gitu to respect my AI model preferences from the NotebookLLM app so that it uses my preferred models for different tasks.

**Acceptance Criteria:**
- Gitu uses the default AI model selected in NotebookLLM settings
- User can set different models for different Gitu tasks (chat, research, coding, analysis)
- User can override model selection per conversation
- Gitu respects model context window limits
- Gitu falls back to alternative models if primary is unavailable
- User can see which model Gitu is using in real-time
- Model selection syncs across all Gitu platforms
- User can set model preferences per platform (e.g., faster model for WhatsApp)

### US-1: Multi-Platform Access
**As a user**, I want to interact with Gitu from any platform (NotebookLLM app, WhatsApp, Telegram, terminal, email) so that I can get assistance wherever I am.

**Acceptance Criteria:**
- User can send messages to Gitu via NotebookLLM Flutter app
- User can send messages to Gitu via WhatsApp (using Baileys library)
- User can send messages to Gitu via Telegram Bot
- User can send messages to Gitu via email (Gmail)
- User can interact with Gitu via terminal CLI
- All platforms share the same conversation context
- Gitu recognizes the user across all platforms
- User can link/unlink platforms from Flutter app
- User receives platform-specific formatting (e.g., WhatsApp supports bold, Telegram supports markdown)

### US-1.1: WhatsApp Integration (Baileys)
**As a user**, I want to connect my WhatsApp to Gitu using Baileys so that I can chat with my assistant via WhatsApp.

**Acceptance Criteria:**
- User scans QR code in Flutter app to link WhatsApp
- Gitu appears as a regular WhatsApp contact
- User can send text, voice, images to Gitu on WhatsApp
- Gitu responds with text, images, documents on WhatsApp
- Gitu supports WhatsApp formatting (bold, italic, code)
- User can create WhatsApp groups with Gitu
- Gitu maintains connection even when phone is offline
- User can unlink WhatsApp from Flutter app
- Multi-device support (WhatsApp Web compatibility)

### US-2: Background Operation
**As a user**, I want Gitu to run continuously in the background so that it can monitor, respond, and execute tasks even when I'm not actively using it.

**Acceptance Criteria:**
- Gitu runs as a background service on the server
- Gitu can wake up on scheduled tasks
- Gitu can respond to incoming messages automatically
- Gitu monitors specified channels/sources
- Gitu can execute long-running tasks asynchronously
- User receives notifications when Gitu completes tasks
- Gitu maintains uptime with auto-restart on failure
- User can view Gitu's background activity from Flutter app

### US-3: Session Management
**As a user**, I want Gitu to maintain persistent sessions so that it remembers context across conversations and platforms.

**Acceptance Criteria:**
- Each user has a unique session ID
- Sessions persist across platform switches
- Gitu remembers previous conversations
- Gitu maintains context within a session
- User can start new sessions or continue existing ones
- Sessions can be named and organized
- User can view session history in Flutter app
- User can export session transcripts

### US-4: Memory System
**As a user**, I want Gitu to remember important information about me, my preferences, and past interactions so that it provides personalized assistance.

**Acceptance Criteria:**
- Gitu stores user preferences
- Gitu remembers facts about the user
- Gitu recalls past conversations
- Gitu learns from user corrections
- User can view what Gitu remembers in Flutter app
- User can edit or delete memories
- Memories are categorized (personal, work, preferences, facts)
- Memories have timestamps and sources
- User can search memories

### US-5: Notebook Integration
**As a user**, I want Gitu to access and work with my NotebookLLM notebooks so that it can reference my knowledge base.

**Acceptance Criteria:**
- Gitu can list user's notebooks
- Gitu can read notebook contents
- Gitu can search across notebooks
- Gitu can create new notebooks
- Gitu can add sources to notebooks
- Gitu can generate content based on notebooks
- Gitu respects notebook permissions
- User can grant/revoke notebook access per conversation

### US-6: Gmail Integration
**As a user**, I want Gitu to read, search, and manage my Gmail so that it can help with email tasks.

**Acceptance Criteria:**
- User can authorize Gitu to access Gmail via OAuth in Flutter app
- Gitu can read emails (with permission)
- Gitu can search emails
- Gitu can draft email responses
- Gitu can send emails on user's behalf (with confirmation)
- Gitu can organize emails (labels, archive, delete)
- Gitu can summarize email threads
- Gitu respects email privacy settings
- User can revoke Gmail access from Flutter app

### US-7: Shopify Integration
**As a user**, I want Gitu to integrate with my Shopify store so that it can help manage my e-commerce business.

**Acceptance Criteria:**
- User can connect Shopify store via API key in Flutter app
- Gitu can view orders
- Gitu can check inventory
- Gitu can answer customer questions
- Gitu can generate product descriptions
- Gitu can analyze sales data
- Gitu can create reports
- Gitu respects Shopify permissions
- User can disconnect Shopify from Flutter app

### US-8: File System Access
**As a user**, I want Gitu to access files on my server (with permissions) so that it can help with file management and analysis.

**Acceptance Criteria:**
- User defines allowed directories in Flutter app
- Gitu can list files in allowed directories
- Gitu can read file contents
- Gitu can create new files (with permission)
- Gitu can modify files (with confirmation)
- Gitu can search file contents
- Gitu can analyze file structures
- All file operations are logged
- User can revoke file access at any time from Flutter app

### US-9: Custom Agent Skills
**As a user**, I want Gitu to use custom agent skills so that it can perform specialized tasks.

**Acceptance Criteria:**
- Gitu can access the agent skills catalog
- Gitu can use skills like code-reviewer, test-generator, doc-generator
- User can create custom skills for Gitu in Flutter app
- Gitu can combine multiple skills
- Gitu suggests relevant skills for tasks
- Skills have clear descriptions and parameters
- User can enable/disable skills per platform

### US-10: Plugin System
**As a user**, I want to add custom plugins to Gitu so that I can extend its capabilities.

**Acceptance Criteria:**
- User can browse plugin marketplace in Flutter app
- User can install plugins
- Plugins can add new commands
- Plugins can add new integrations
- Plugins can access Gitu's APIs
- Plugins are sandboxed for security
- User can enable/disable plugins
- User can configure plugin settings in Flutter app

### US-11: Autonomous Wake-Up
**As a user**, I want Gitu to wake up automatically based on triggers so that it can proactively assist me.

**Acceptance Criteria:**
- Gitu can wake up on schedule (cron-like)
- Gitu can wake up on incoming messages
- Gitu can wake up on system events
- Gitu can wake up on webhook triggers
- User defines wake-up rules in Flutter app
- Gitu logs all wake-up events
- User can disable autonomous wake-up
- User receives notifications for autonomous actions

### US-12: Permission System
**As a user**, I want granular control over what Gitu can access so that my data remains secure.

**Acceptance Criteria:**
- User grants permissions per integration in Flutter app
- User can revoke permissions at any time
- Gitu requests permission before sensitive actions
- Permission levels: read, write, execute
- Permissions are scoped (e.g., specific folders, email labels)
- All permission changes are logged
- User receives notifications for permission requests
- User can set default permission policies

### US-13: Rule-Based Behavior
**As a user**, I want to define rules for how Gitu behaves so that it acts according to my preferences.

**Acceptance Criteria:**
- User can create IF-THEN rules in Flutter app
- Rules can trigger on events (new email, time, message)
- Rules can execute actions (send message, create task, run command)
- Rules can be enabled/disabled
- Rules have priority levels
- User can test rules before activating
- Rules are validated for safety
- User can share rules with other users

### US-14: Multi-User Support
**As an admin**, I want multiple users to have their own Gitu instances so that each user has a personalized assistant.

**Acceptance Criteria:**
- Each user has isolated data
- Users cannot access each other's data
- Admin can manage user accounts
- Users can invite others (with admin approval)
- Usage quotas per user
- Billing per user (if applicable)
- Admin dashboard in Flutter app

### US-15: Voice Interaction
**As a user**, I want to interact with Gitu via voice so that I can use it hands-free.

**Acceptance Criteria:**
- User can send voice messages on any platform
- Gitu transcribes voice to text
- Gitu can respond with voice (ElevenLabs)
- Voice wake word support ("Hey Gitu")
- Multiple voice models available
- Voice works across platforms (Flutter app, WhatsApp, Telegram)
- User can select voice model in Flutter app

### US-16: Proactive Assistance
**As a user**, I want Gitu to proactively suggest actions so that it anticipates my needs.

**Acceptance Criteria:**
- Gitu analyzes patterns in user behavior
- Gitu suggests relevant actions
- Gitu sends proactive notifications (with user consent)
- User can configure proactivity level in Flutter app
- Gitu learns from user feedback on suggestions
- User can disable proactive features

### US-17: Task Execution
**As a user**, I want Gitu to execute complex tasks autonomously so that I can delegate work.

**Acceptance Criteria:**
- User can assign multi-step tasks
- Gitu breaks down tasks into steps
- Gitu executes steps sequentially
- Gitu reports progress in real-time
- Gitu handles errors gracefully
- User can pause/resume tasks from Flutter app
- User can cancel tasks
- Completed tasks are logged and viewable in Flutter app

### US-18: Integration Hub
**As a user**, I want Gitu to connect with various services so that it can work with my entire digital ecosystem.

**Acceptance Criteria:**
- Pre-built integrations: Gmail, Shopify, GitHub, Slack, Trello, Calendar, Notion
- OAuth support for secure connections
- API key management in Flutter app
- Webhook support
- User can request new integrations
- Integration health monitoring in Flutter app
- User can test integrations before enabling

### US-19: Analytics & Insights
**As a user**, I want to see how Gitu is helping me so that I can understand its value.

**Acceptance Criteria:**
- Dashboard in Flutter app shows usage statistics
- Reports on tasks completed
- Time saved estimates
- Most used features
- Conversation analytics
- Platform usage breakdown
- Export analytics data
- Weekly/monthly summary emails

### US-20: Security & Privacy
**As a user**, I want my data to be secure and private so that I can trust Gitu with sensitive information.

**Acceptance Criteria:**
- End-to-end encryption for messages
- Data encrypted at rest
- Audit logs for all actions viewable in Flutter app
- User can export all their data
- User can delete all their data
- GDPR compliant
- SOC 2 compliant (for enterprise)
- Regular security audits
- Two-factor authentication for sensitive operations

## Technical Requirements

### TR-1: Architecture
- Microservices architecture
- Message queue for async tasks (Redis/RabbitMQ)
- WebSocket for real-time communication
- REST API for integrations
- GraphQL for complex queries
- Baileys library for WhatsApp integration
- Telegram Bot API
- Gmail API (OAuth 2.0)

### TR-2: Scalability
- Horizontal scaling support
- Load balancing
- Database sharding
- Caching layer (Redis)
- CDN for static assets
- Support 10,000+ concurrent users

### TR-3: Reliability
- 99.9% uptime SLA
- Automatic failover
- Data backup every 6 hours
- Disaster recovery plan
- Health monitoring
- Auto-restart on failure

### TR-4: Performance
- Message response time < 2 seconds
- API response time < 500ms
- Support 10,000 concurrent users
- Handle 1M messages per day
- WhatsApp message delivery < 3 seconds

### TR-5: Compatibility
- Works with existing NotebookLLM backend
- Compatible with NotebookLLM Flutter app
- Works on iOS, Android, Web
- Terminal CLI for Linux, macOS, Windows
- WhatsApp via Baileys (multi-device support)
- Telegram Bot API v6.0+

### TR-6: AI Model Support
- OpenRouter (all models)
- Google Gemini (1.5 Pro, 1.5 Flash, 2.0)
- OpenAI (GPT-4, GPT-4 Turbo, GPT-3.5)
- Anthropic (Claude 3.5 Sonnet, Claude 3 Opus)
- Respects user's model selection from Flutter app
- Automatic fallback on model unavailability

## Non-Functional Requirements

### NFR-1: Usability
- Intuitive setup process (< 5 minutes)
- Clear documentation
- In-app tutorials in Flutter app
- Helpful error messages
- Onboarding wizard

### NFR-2: Maintainability
- Modular codebase
- Comprehensive tests (80% coverage)
- API versioning
- Backward compatibility
- Clear code documentation

### NFR-3: Observability
- Structured logging
- Distributed tracing
- Metrics collection
- Error tracking (Sentry)
- Real-time monitoring dashboard

### NFR-4: Compliance
- GDPR compliant
- CCPA compliant
- Data residency options
- Privacy policy
- Terms of service
- Cookie policy

## Success Metrics

1. **Adoption**: 1,000 active users in first 3 months
2. **Engagement**: Average 50 messages per user per week
3. **Retention**: 70% monthly active users
4. **Satisfaction**: NPS score > 50
5. **Performance**: 95% of messages responded to in < 2 seconds
6. **Reliability**: 99.9% uptime
7. **Integration Usage**: Average 3 integrations per user
8. **WhatsApp Adoption**: 60% of users connect WhatsApp
9. **API Key Usage**: 40% of users use personal API keys

## Out of Scope (Phase 1)

- Native mobile apps (use Flutter app instead)
- Video calls with Gitu
- AR/VR interfaces
- Blockchain integration
- Cryptocurrency payments
- Multi-language support (English only in Phase 1)
- Enterprise SSO (Phase 2)
- White-label solution (Phase 2)
- SMS integration (Phase 2)
- Discord integration (Phase 2)

## Dependencies

- NotebookLLM backend infrastructure
- NotebookLLM Flutter app (for configuration UI)
- OpenRouter/Gemini/OpenAI for AI models
- Baileys library for WhatsApp
- Telegram Bot API
- Gmail API
- Shopify API
- ElevenLabs for voice
- Redis for caching and queues
- PostgreSQL for data storage
- WebSocket server
- Node.js runtime

## Risks & Mitigations

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| WhatsApp ban (Baileys) | Critical | Medium | Use official Business API as fallback, implement rate limiting, user education |
| API rate limits | High | Medium | Implement rate limiting, caching, fallback models, user quotas |
| Security breach | Critical | Low | Regular audits, encryption, penetration testing, bug bounty |
| Integration failures | Medium | High | Graceful degradation, retry logic, monitoring, fallback options |
| Scalability issues | High | Medium | Load testing, horizontal scaling, caching, CDN |
| User privacy concerns | High | Medium | Transparent policies, user controls, compliance, data encryption |
| AI hallucinations | Medium | High | Fact-checking, source citations, user feedback, confidence scores |
| Flutter app dependency | Medium | Low | Ensure backward compatibility, versioning, graceful degradation |

## Timeline Estimate

- **Phase 1 (Months 1-2)**: Core infrastructure, Flutter app integration, basic messaging
- **Phase 2 (Months 3-4)**: WhatsApp (Baileys), Telegram, session management, memory system
- **Phase 3 (Months 5-6)**: Integrations (Gmail, Shopify, Notebooks), API key management
- **Phase 4 (Months 7-8)**: Autonomous features, plugins, advanced permissions, rules
- **Phase 5 (Months 9-10)**: Voice, proactive assistance, analytics, skills
- **Phase 6 (Months 11-12)**: Polish, optimization, security hardening, beta testing

## Next Steps

1. ✅ Review and approve requirements
2. Create detailed design document
3. Design Flutter app UI for Gitu configuration
4. Set up development environment
5. Create database schema
6. Implement core messaging infrastructure
7. Integrate with NotebookLLM Flutter app
8. Build WhatsApp integration (Baileys)
9. Build Telegram integration
10. Implement session and memory systems
11. Add notebook integration
12. Beta testing with select users
