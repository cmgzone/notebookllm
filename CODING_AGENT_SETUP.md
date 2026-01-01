# Coding Agent Setup Guide

A backend-only coding agent that verifies code and saves it as sources to your app. Third-party coding agents can connect via MCP.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Third-Party Agents                        │
│              (Claude, Kiro, Cursor, etc.)                   │
└─────────────────────┬───────────────────────────────────────┘
                      │ MCP Protocol (stdio)
                      ▼
┌─────────────────────────────────────────────────────────────┐
│              Coding Agent MCP Server                         │
│         backend/mcp-server/src/index.ts                     │
│                                                              │
│  Tools:                                                      │
│  • verify_code - Check code correctness                     │
│  • verify_and_save - Verify & save as source                │
│  • batch_verify - Verify multiple snippets                  │
│  • analyze_code - Deep analysis                             │
│  • get_verified_sources - Retrieve saved sources            │
└─────────────────────┬───────────────────────────────────────┘
                      │ HTTP API
                      ▼
┌─────────────────────────────────────────────────────────────┐
│                   Backend API                                │
│            /api/coding-agent/*                              │
│                                                              │
│  Endpoints:                                                  │
│  • POST /verify - Verify code                               │
│  • POST /verify-and-save - Verify & save                    │
│  • POST /batch-verify - Batch verification                  │
│  • POST /analyze - Deep analysis                            │
│  • GET /sources - Get verified sources                      │
│  • DELETE /sources/:id - Delete source                      │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│            Code Verification Service                         │
│    backend/src/services/codeVerificationService.ts          │
│                                                              │
│  Features:                                                   │
│  • Syntax validation (JS/TS, Python, Dart, JSON)           │
│  • Security scanning (XSS, SQL injection, secrets)         │
│  • AI-powered analysis (Gemini)                             │
│  • Best practices checking                                   │
│  • Complexity assessment                                     │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│                   Database                                   │
│              sources table                                   │
│                                                              │
│  Stores verified code with:                                  │
│  • Verification results                                      │
│  • Language metadata                                         │
│  • User/notebook associations                               │
└─────────────────────────────────────────────────────────────┘
```

## Quick Start

### 1. Run Database Migration

```bash
cd backend
npx tsx src/scripts/run-coding-agent-migration.ts
```

### 2. Start Backend

```bash
cd backend
npm run dev
```

### 3. Build MCP Server

```bash
cd backend/mcp-server
npm install
npm run build
```

### 4. Configure MCP Client

Add to your MCP config (e.g., `.kiro/settings/mcp.json`):

```json
{
  "mcpServers": {
    "coding-agent": {
      "command": "node",
      "args": ["./backend/mcp-server/dist/index.js"],
      "env": {
        "BACKEND_URL": "http://localhost:3000"
      }
    }
  }
}
```

## API Reference

### Verify Code

```bash
curl -X POST http://localhost:3000/api/coding-agent/verify \
  -H "Content-Type: application/json" \
  -d '{
    "code": "const x = 1;",
    "language": "javascript"
  }'
```

Response:
```json
{
  "success": true,
  "verification": {
    "isValid": true,
    "score": 95,
    "errors": [],
    "warnings": [],
    "suggestions": [],
    "metadata": {
      "language": "javascript",
      "linesOfCode": 1,
      "complexity": "low",
      "verifiedAt": "2025-01-01T00:00:00.000Z"
    }
  }
}
```

### Verify and Save

Requires authentication. Code must score >= 60 to be saved.

```bash
curl -X POST http://localhost:3000/api/coding-agent/verify-and-save \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "code": "function add(a, b) { return a + b; }",
    "language": "javascript",
    "title": "Add Function",
    "description": "Simple addition utility"
  }'
```

## Verification Scoring

| Severity | Error Impact | Warning Impact |
|----------|-------------|----------------|
| Critical | -25 points  | -10 points     |
| High     | -15 points  | -5 points      |
| Medium   | -10 points  | -3 points      |
| Low      | -5 points   | -1 point       |

Code must score >= 60 to be saved as a source.

## Security Checks

The service scans for:
- `eval()` usage
- `innerHTML` assignments (XSS risk)
- Hardcoded passwords/API keys/secrets
- SQL injection patterns
- Shell injection risks
- Unsafe subprocess calls

## Supported Languages

- JavaScript / TypeScript
- Python
- Dart
- JSON
- Generic (basic checks for any language)

## Files Created

```
backend/
├── src/
│   ├── services/
│   │   └── codeVerificationService.ts  # Core verification logic
│   ├── routes/
│   │   └── codingAgent.ts              # API endpoints
│   └── scripts/
│       └── run-coding-agent-migration.ts
├── migrations/
│   └── add_coding_agent_support.sql
└── mcp-server/
    ├── src/
    │   └── index.ts                    # MCP server
    ├── package.json
    ├── tsconfig.json
    ├── .env.example
    ├── README.md
    └── mcp-config-example.json
```
