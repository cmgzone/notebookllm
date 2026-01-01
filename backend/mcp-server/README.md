# Coding Agent MCP Server

An MCP (Model Context Protocol) server that allows third-party coding agents to verify code and save it as sources in your app.

## Features

- **Code Verification**: Validate code for syntax, security, and best practices
- **AI-Powered Analysis**: Deep code analysis using Gemini AI
- **Source Management**: Save verified code as sources in your app
- **Batch Processing**: Verify multiple code snippets at once
- **Multi-Language Support**: JavaScript, TypeScript, Python, Dart, JSON, and more

## Tools Available

### `verify_code`
Verify code for correctness, security vulnerabilities, and best practices.

```json
{
  "code": "function hello() { return 'world'; }",
  "language": "javascript",
  "context": "A simple greeting function",
  "strictMode": false
}
```

### `verify_and_save`
Verify code and save it as a source if it passes verification (score >= 60).

```json
{
  "code": "const add = (a, b) => a + b;",
  "language": "javascript",
  "title": "Add Function",
  "description": "Simple addition utility",
  "notebookId": "optional-notebook-id"
}
```

### `batch_verify`
Verify multiple code snippets at once.

```json
{
  "snippets": [
    { "id": "1", "code": "...", "language": "python" },
    { "id": "2", "code": "...", "language": "typescript" }
  ]
}
```

### `analyze_code`
Deep analysis with comprehensive suggestions.

```json
{
  "code": "...",
  "language": "python",
  "analysisType": "security"
}
```

### `get_verified_sources`
Retrieve previously saved verified code sources.

```json
{
  "notebookId": "optional-filter",
  "language": "optional-filter"
}
```

## Installation

```bash
cd backend/mcp-server
npm install
npm run build
```

## Configuration

Create a `.env` file:

```env
BACKEND_URL=http://localhost:3000
CODING_AGENT_API_KEY=your-api-key
```

## Usage with MCP Clients

### Kiro Configuration

Add to `.kiro/settings/mcp.json`:

```json
{
  "mcpServers": {
    "coding-agent": {
      "command": "node",
      "args": ["path/to/backend/mcp-server/dist/index.js"],
      "env": {
        "BACKEND_URL": "http://localhost:3000",
        "CODING_AGENT_API_KEY": "your-key"
      }
    }
  }
}
```

### Claude Desktop Configuration

Add to `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "coding-agent": {
      "command": "node",
      "args": ["/absolute/path/to/backend/mcp-server/dist/index.js"],
      "env": {
        "BACKEND_URL": "http://localhost:3000"
      }
    }
  }
}
```

## Architecture

```
Third-Party Agent (Claude, Kiro, etc.)
           ↓
    [MCP Protocol - stdio]
           ↓
    [Coding Agent MCP Server]
           ↓
    [HTTP API calls]
           ↓
    [Your Backend API]
           ↓
    [Code Verification Service]
           ↓
    [Database - Sources Table]
```

## Development

```bash
# Run in development mode
npm run dev

# Build for production
npm run build

# Run production build
npm start
```
