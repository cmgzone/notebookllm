# Gitu AI Assistant - Wiring Checklist

## Overview
This document outlines what needs to be wired/connected to make Gitu a fully functional AI assistant.

## ✅ Already Implemented

### Backend Services
- ✅ `gituProactiveService` - Aggregates data from platforms and generates insights
- ✅ `gituMemoryService` - Manages long-term user memories
- ✅ `gituMissionControl` - Multi-agent swarm orchestration
- ✅ `gituTaskScheduler` - Scheduled task execution
- ✅ `gituAIRouter` - Routes messages to appropriate AI models
- ✅ `gituGmailManager` - Gmail integration
- ✅ `whatsappAdapter` - WhatsApp integration
- ✅ `gituShopifyManager` - Shopify integration
- ✅ `gituRuleEngine` - Automation rules
- ✅ `gituPluginSystem` - Custom plugins
- ✅ `gituPermissionManager` - Permission management
- ✅ `gituTerminalService` - CLI terminal auth

### Frontend Components
- ✅ `GituChatScreen` - Chat interface with WebSocket
- ✅ `GituProactiveDashboard` - Insights dashboard UI
- ✅ `GituSettingsScreen` - Settings management
- ✅ Various connection screens (Gmail, WhatsApp, Shopify)
- ✅ Task, Rule, Plugin management screens

### Database
- ✅ `gitu_missions` table
- ✅ `gitu_mission_logs` table
- ✅ `gitu_memories` table
- ✅ `gitu_scheduled_tasks` table
- ✅ `gitu_linked_accounts` table
- ✅ `gitu_messages` table

## ✅ Wiring Status (Current Repo)

### Backend (REST)
- ✅ Proactive insights endpoint: [gitu.ts](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/src/routes/gitu.ts)
- ✅ WhatsApp endpoints: [gitu.ts](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/src/routes/gitu.ts)
- ✅ Terminal auth endpoints: [gitu.ts](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/src/routes/gitu.ts)
- ✅ Missions, rules, plugins, permissions endpoints: [gitu.ts](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/src/routes/gitu.ts)

### Backend (WebSocket)
- ✅ Gateway broadcasts insights + mission updates + incoming messages: [gituMessageGateway.ts](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/src/services/gituMessageGateway.ts)
- ✅ WebSocket services are initialized on server startup: [index.ts](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/src/index.ts)

### Flutter
- ✅ Dashboard route is registered: [router.dart](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/lib/core/router.dart)
- ✅ Dashboard screen exists: [gitu_dashboard_screen.dart](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/lib/features/gitu/gitu_dashboard_screen.dart)
- ✅ Insights provider hits the backend endpoint: [proactive_insights_provider.dart](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/lib/features/gitu/proactive_insights_provider.dart)

## 🔧 Known “Weird” Areas (What Can Break If DB Isn’t Clean)
- `gitu_messages` had multiple conflicting schemas across older migrations and runtime schema creation.
  - Repair migration: [011_fix_gitu_messages_canonical.sql](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/migrations/011_fix_gitu_messages_canonical.sql)
  - Runtime schema repair: [gituSchema.ts](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/src/config/gituSchema.ts)
- Platform constraints include `web` consistently (messages, sessions, linked accounts): [update_gitu_platforms.sql](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/migrations/update_gitu_platforms.sql)

## 🧪 Minimal Verification Checklist
- Backend boots without “ensure schema” errors: [index.ts](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/src/index.ts)
- `GET /api/gitu/insights` returns a success payload
- Flutter route `/gitu/dashboard` loads and renders
- `plugin.execute` scheduled tasks execute plugins and write to `gitu_plugin_executions`

---

**Last Updated**: 2026-01-31  
**Status**: Wired (Verify DB + Runtime Schema)
