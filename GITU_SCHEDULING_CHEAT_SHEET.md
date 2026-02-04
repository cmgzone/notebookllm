# Gitu Auto-Scheduling - Quick Reference Card 🚀

**Status:** ✅ PRODUCTION READY  
**Test Results:** 8/8 PASSED  
**Confidence:** 85-95%

---

## 📝 What Users Can Say

### Reminders (One-Time)
```
"remind me tomorrow at 3pm to call John"
"remind me in 30 minutes about the meeting"
"remind me next Friday at 2pm to submit report"
```

### Daily Tasks
```
"every day at 8pm remind me to exercise"
"daily at 7am send me weather update"
```

### Weekly Tasks
```
"every Monday at 9am send me a summary"
"every Friday at 5pm remind me to review week"
```

### Interval Tasks
```
"every 30 minutes remind me to drink water"
"every hour check my emails"
"every 2 hours remind me to stretch"
```

### Scheduled Tasks
```
"schedule a meeting reminder for tomorrow at 2pm"
"schedule email summary for next Monday at 10am"
```

---

## 🔌 API Endpoint

```bash
POST /api/gitu/tasks/parse
Authorization: Bearer YOUR_TOKEN
Content-Type: application/json

{
  "text": "remind me in 2 minutes to test"
}
```

**Response:**
```json
{
  "success": true,
  "task": { "id": "...", "name": "...", "trigger": {...}, "action": {...} },
  "confidence": 0.9,
  "originalText": "..."
}
```

---

## 🧪 Test Command

```bash
cd backend
npx tsx src/scripts/test-task-scheduler.ts
```

**Expected:** 8/8 tests pass ✅

---

## 🚀 Start Backend

```bash
cd backend
npm start
```

**Look for:** `✅ Gitu Task Scheduler started`

---

## 📊 Task Types

| Pattern | Trigger Type | Example |
|---------|-------------|---------|
| Reminder | `once` | Tomorrow at 3pm |
| Daily | `cron` | Every day at 8pm |
| Weekly | `cron` | Every Monday at 9am |
| Interval | `interval` | Every 30 minutes |
| Schedule | `once` | Next Monday at 10am |

---

## 🎯 Action Types

| Keywords | Action | Result |
|----------|--------|--------|
| "summary", "summarize" | `ai_request` | AI generates content |
| "remind", "notify", "tell" | `send_message` | Sends message |
| Default | `send_message` | Sends message |

---

## 📁 Key Files

- `backend/src/services/gituTaskParser.ts` - Parser
- `backend/src/services/gituTaskScheduler.ts` - Scheduler
- `backend/src/routes/gitu.ts` - API endpoint
- `backend/src/scripts/test-task-scheduler.ts` - Tests

---

## 📚 Documentation

- `GITU_AUTO_SCHEDULING_VERIFIED.md` - Full verification report
- `GITU_SCHEDULING_TEST_RESULTS.md` - Detailed test results
- `GITU_SCHEDULING_QUICK_START.md` - Usage guide
- `GITU_SCHEDULING_COMPLETE.md` - Implementation details

---

## ✅ Verified Features

- ✅ Natural language parsing
- ✅ 8 different patterns supported
- ✅ Confidence scoring (85-95%)
- ✅ Action type inference
- ✅ Cron scheduling
- ✅ Interval scheduling
- ✅ One-time execution
- ✅ Execution history
- ✅ Auto-starts with backend
- ✅ Multi-platform support

---

## 🔧 Dependencies

```json
{
  "chrono-node": "^2.7.8"
}
```

**Status:** ✅ Installed

---

## 🎉 Bottom Line

**YES, Gitu can auto-schedule tasks when asked by users!**

Just say things like:
- "remind me tomorrow at 3pm to call John"
- "every Monday at 9am send me a summary"
- "every 30 minutes remind me to drink water"

And Gitu will handle the rest! 🚀
