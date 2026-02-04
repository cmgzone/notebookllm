# Gitu Auto-Scheduling - Quick Start Guide

## Deploy (5 minutes)

```bash
cd backend
npm install
npm run build
npm start
```

Look for: `✅ Gitu Task Scheduler started`

## Use Natural Language

```bash
curl -X POST http://localhost:3000/api/gitu/tasks/parse \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"text": "remind me tomorrow at 3pm to call John"}'
```

## Supported Patterns

| Pattern | Example |
|---------|---------|
| **Reminder** | "remind me tomorrow at 3pm to call John" |
| **Recurring** | "every Monday at 9am send me a summary" |
| **Daily** | "every day at 8pm remind me to exercise" |
| **Interval** | "every 30 minutes remind me to drink water" |
| **Schedule** | "schedule a meeting for tomorrow at 2pm" |

## API Endpoints

```bash
# Parse natural language
POST /api/gitu/tasks/parse
Body: {"text": "remind me..."}

# List tasks
GET /api/gitu/tasks

# Delete task
DELETE /api/gitu/tasks/:id

# View execution history
GET /api/gitu/tasks/:id/executions
```

## Test It

```bash
# Create a 2-minute reminder
curl -X POST http://localhost:3000/api/gitu/tasks/parse \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"text": "remind me in 2 minutes to test this"}'

# Wait 2 minutes
# Check if you received the message!
```

## What It Does

1. **Parses** natural language → structured task
2. **Stores** in database
3. **Executes** at scheduled time (every 30s check)
4. **Sends** message to user on their platform
5. **Logs** execution history

## Status: ✅ Ready!

- ✅ Scheduler running
- ✅ Natural language parsing
- ✅ All platforms supported
- ✅ Execution tracking

**Just deploy and use!** 🚀
