# WhatsApp Prompt Commands

These commands let a user trigger actions by sending WhatsApp messages to Gitu.

## Safety Model

- Normal messages are treated as chat (no tools, no shell).
- Tool execution is only enabled when you explicitly prefix the message with `/tools`.
- Local PC execution only happens if the user installed the CLI on their PC and enabled Remote Terminal.

## Commands

### Shell (run on server or user PC)

Run a direct shell command:

```
/shell git status
```

Notes:
- If a Remote Terminal is connected, and permissions allow it, execution can be routed to the user’s PC.
- Otherwise it executes on the server (subject to shell permissions/allowlists).

### Tools (enable tool use for a single message)

Enable tool execution for a single request:

```
/tools Summarize the latest errors in my logs and propose a fix
```

### Autonomous Agent

Spawn an agent:

```
/agent spawn Research best practices for X and summarize
```

List agents:

```
/agent list
```

### Swarm Mission

Start a mission:

```
/swarm Plan and implement feature X with tests
```

List active missions:

```
/swarm status
```

### Coding Mission

Start a coding-focused mission:

```
/code Fix the failing backend tests and keep changes minimal
```

