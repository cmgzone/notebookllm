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

## 🔧 Needs Wiring

### 1. Proactive Insights API Endpoint ⚠️ HIGH PRIORITY

**Issue**: `gituProactiveService` exists but has no REST endpoint.

**Solution**: Add to `backend/src/routes/gitu.ts`:

```typescript
/**
 * GET /insights
 * Get proactive insights for the authenticated user
 */
router.get('/insights', async (req: AuthRequest, res: Response) => {
  try {
    const useCache = req.query.useCache !== 'false';
    const insights = await gituProactiveService.getProactiveInsights(
      req.userId!,
      useCache
    );
    res.json({ success: true, insights });
  } catch (error: any) {
    res.status(500).json({ 
      error: 'Failed to load insights', 
      message: error.message 
    });
  }
});

/**
 * POST /insights/refresh
 * Force refresh proactive insights
 */
router.post('/insights/refresh', async (req: AuthRequest, res: Response) => {
  try {
    gituProactiveService.clearCache(req.userId!);
    const insights = await gituProactiveService.getProactiveInsights(
      req.userId!,
      false
    );
    res.json({ success: true, insights });
  } catch (error: any) {
    res.status(500).json({ 
      error: 'Failed to refresh insights', 
      message: error.message 
    });
  }
});

/**
 * POST /missions
 * Start a new Swarm mission
 */
router.post('/missions', async (req: AuthRequest, res: Response) => {
  try {
    const { objective } = req.body;
    if (!objective || typeof objective !== 'string') {
      return res.status(400).json({ error: 'objective is required' });
    }
    const mission = await gitu ProactiveService.startMission(req.userId!, objective);
    res.json({ success: true, mission });
  } catch (error: any) {
    res.status(500).json({ 
      error: 'Failed to start mission', 
      message: error.message 
    });
  }
});
```

**Frontend Provider Needed**: Create `proactive_insights_provider.dart` if it doesn't exist or wire it properly.

---

### 2. Proactive Dashboard Route ⚠️ HIGH PRIORITY

**Issue**: `GituProactiveDashboard` widget exists but not routed.

**Solution**: Add to `lib/core/router.dart`:

```dart
GoRoute(
  path: '/gitu/dashboard',
  name: 'gitu-dashboard',
  pageBuilder: (context, state) =>
      buildTransitionPage(child: const GituDashboardScreen()),
),
```

Create wrapper screen:
```dart
// lib/features/gitu/gitu_dashboard_screen.dart
class GituDashboardScreen extends StatelessWidget {
  const GituDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gitu Dashboard')),
      body: const GituProactiveDashboard(),
    );
  }
}
```

**Add to App Drawer Navigation**:
```dart
ListTile(
  leading: const Icon(LucideIcons.sparkles),
  title: const Text('Gitu Dashboard'),
  onTap: () => context.push('/gitu/dashboard'),
),
```

---

### 3. WebSocket Real-Time Broadcasting 🔄 MEDIUM PRIORITY

**Issue**: WebSocket server receives messages but doesn't broadcast events like:
- New proactive suggestions
- Mission status updates
- Incoming Gmail/WhatsApp messages

**Solution**: Enhance WebSocket gateway to broadcast events.

**Backend**: Modify `backend/src/websocket/gituMessageGateway.ts`:

```typescript
// Add method to broadcast insights update
broadcastInsightsUpdate(userId: string) {
  const client = this.clients.get(userId);
  if (client && client.readyState === WebSocket.OPEN) {
    client.send(JSON.stringify({
      type: 'insights_updated',
      payload: { timestamp: new Date().toISOString() }
    }));
  }
}

// Call this when insights change (e.g., new email, task completion)
```

**Frontend**: Handle in `gitu_provider.dart`:

```dart
case 'insights_updated':
  // Trigger refresh of proactive insights
  ref.read(proactiveInsightsProvider.notifier).refresh();
  break;
```

---

### 4. Cross-Platform Message Routing 🔄 MEDIUM PRIORITY

**Issue**: Messages from Gmail/WhatsApp need to flow through AI router and back.

**Current State**:
- Gmail messages are fetched via API
- WhatsApp messages come via adapter
- Both need unified handling

**Solution**: Ensure `gituAIRouter` processes all incoming messages and sends responses back.

**File**: `backend/src/services/gituAIRouter.ts`

Ensure it handles:
```typescript
// Process incoming Gmail
async processGmailMessage(userId: string, emailId: string) {
  // Fetch email
  // Route to AI
  // Generate response suggestion
  // Store in gitu_messages
}

// Process incoming WhatsApp
async processWhatsAppMessage(userId: string, from: string, message: string) {
  // Same flow
}
```

---

### 5. MCP (Model Context Protocol) Web Research Tools 🛠️ LOW PRIORITY

**Issue**: Conversation history mentions "web research capabilities" but they're not registered.

**Solution**: Create MCP tool wrappers.

**File**: `backend/src/tools/gituMCPTools.ts`

```typescript
export const gituMCPTools = {
  web_search: {
    name: 'web_search',
    description: 'Search the web for information',
    async execute(query: string) {
      // Call your web search service (Serper, etc.)
      return { results: [] };
    }
  },
  deep_research: {
    name: 'deep_research',
    description: 'Perform deep research on a topic',
    async execute(topic: string) {
      // Multi-step research
      return { report: '' };
    }
  }
};
```

Register in main application entry point.

---

### 6. Scheduled Proactive Checks 🕐 MEDIUM PRIORITY

**Issue**: `gituProactiveService.runProactiveChecks()` exists but isn't called periodically.

**Solution**: Set up cron job or interval.

**File**: `backend/src/server.ts` or create `backend/src/jobs/proactiveChecks.ts`

```typescript
import cron from 'node-cron';
import { gituProactiveService } from './services/gituProactiveService.js';

// Run every 30 minutes
cron.schedule('*/30 * * * *', async () => {
  console.log('[Cron] Running proactive checks...');
  await gituProactiveService.runProactiveChecks();
});
```

---

### 7. Gmail Auto-Refresh Status 🔄 LOW PRIORITY

**Issue**: Gmail connection status should auto-refresh.

**Solution**: Add polling or webhook.

**Frontend**: In `gmail_connection_screen.dart`:

```dart
Timer.periodic(Duration(minutes: 5), (_) {
  ref.read(gmailConnectionProvider.notifier).refreshStatus();
});
```

---

### 8. WhatsApp Connection Error Visibility ⚠️ MEDIUM PRIORITY

**Issue**: WhatsApp connection errors are only logged, not shown to user.

**Solution**: Expose error state in API and show in UI.

**Backend**: Add to `/gitu/whatsapp/status`:

```typescript
router.get('/whatsapp/status', async (req: AuthRequest, res: Response) => {
  try {
    const state = whatsappAdapter.getConnectionState();
    const error = whatsappAdapter.getLastError(); // Add this method
    // ... rest of code
    res.json({
      success: true,
      status,
      error: error || null,
      // ...
    });
  } catch (error: any) {
    // ...
  }
});
```

**Frontend**: Show error banner if present.

---

### 9. Missions in Proactive Dashboard ✅ ALREADY WIRED

The dashboard already shows active missions via:
```dart
insights.activeMissions
```

Just ensure the backend endpoint returns them:
```typescript
const activeMissions = await gituMissionControl.listActiveMissions(userId);
```

This seems to already be in place in `gituProactiveService.getProactiveInsights()`.

---

### 10. Suggestion Actions 🎯 MEDIUM PRIORITY

**Issue**: Suggestions have `action` field but clicking doesn't execute them.

**Solution**: Handle suggestion actions in dashboard.

**Frontend**: In `gitu_proactive_dashboard.dart`:

```dart
onTap: () {
  if (suggestion.action != null) {
    _executeSuggestionAction(context, suggestion.action!);
  }
},

void _executeSuggestionAction(BuildContext context, SuggestionAction action) {
  switch (action.type) {
    case 'navigate':
      context.push(action.params?['route'] ?? '/');
      break;
    case 'ai_summarize_emails':
      // Call Gmail AI summary endpoint
      break;
    case 'ai_daily_summary':
      // Generate daily summary
      break;
  }
}
```

---

## 📝 Implementation Priority

### High Priority (Must Wire First)
1. ✅ **Proactive Insights API Endpoint** - Core feature, dashboard depends on it
2. ✅ **Proactive Dashboard Route** - Make dashboard accessible
3. ✅ **Main Navigation Integration** - Users need to find Gitu easily

### Medium Priority (Wire Next)
4. **WebSocket Broadcasting** - Real-time updates improve UX
5. **Cross-Platform Message Routing** - Unify Gmail/WhatsApp handling
6. **Scheduled Proactive Checks** - Background intelligence
7. **WhatsApp Error Visibility** - Better debugging
8. **Suggestion Actions** - Make suggestions actionable

### Low Priority (Nice to Have)
9. **MCP Web Research Tools** - Advanced feature
10. **Gmail Auto-Refresh** - Minor UX improvement

---

## 🧪 Testing Checklist

After wiring, test:

- [ ] `/gitu/dashboard` route loads without errors
- [ ] Proactive insights API returns data: `GET /api/gitu/insights`
- [ ] Dashboard shows Gmail/WhatsApp connection status
- [ ] Dashboard shows active tasks and missions
- [ ] Suggestions are actionable (clicking navigates or executes)
- [ ] WebSocket receives `insights_updated` events
- [ ] Scheduled proactive checks run every 30 minutes
- [ ] WhatsApp connection errors are visible in UI
- [ ] Cross-platform messages are stored and routed correctly

---

## 📚 Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│  GITU AI ASSISTANT ARCHITECTURE                             │
└─────────────────────────────────────────────────────────────┘

┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│  Flutter App     │────▶│  REST API        │────▶│  Services        │
│  - Dashboard     │     │  /gitu/insights  │     │  - Proactive     │
│  - Chat Screen   │     │  /gitu/missions  │     │  - Memory        │
│  - Settings      │     │  /gitu/tasks     │     │  - Mission Ctrl  │
└──────────────────┘     └──────────────────┘     └──────────────────┘
         │                        │                        │
         │                        │                        │
         ▼                        ▼                        ▼
┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│  WebSocket       │     │  Platform        │     │  Database        │
│  /ws/gitu        │────▶│  Adapters        │────▶│  - Missions      │
│  - Real-time     │     │  - Gmail         │     │  - Memories      │
│  - Broadcasts    │     │  - WhatsApp      │     │  - Messages      │
└──────────────────┘     └──────────────────┘     └──────────────────┘
```

---

## 🚀 Quick Start Guide

To wire Gitu AI Assistant:

1. **Backend**:
   ```bash
   # Add insights endpoint to routes/gitu.ts
   # Add WebSocket broadcasting
   # Set up cron jobs
   ```

2. **Frontend**:
   ```bash
   # Add /gitu/dashboard route
   # Update app drawer with Gitu link
   # Wire proactive insights provider
   ```

3. **Deploy**:
   ```bash
   git add .
   git commit -m "feat: wire Gitu AI assistant end-to-end"
   git push origin main
   ```

---

## 🎯 Success Criteria

Gitu is "wired" when:

✅ Dashboard is accessible from main navigation  
✅ Real-time insights load from backend  
✅ Suggestions are clickable and actionable  
✅ WebSocket broadcasts platform events  
✅ Background checks run automatically  
✅ All platforms (Gmail, WhatsApp) feed into unified AI  
✅ Missions can be started and tracked  
✅ Errors are visible to users  

---

**Last Updated**: 2026-01-31  
**Status**: Implementation Required
