# Gitu Plugins Guide

Gitu supports two kinds of custom plugins:

1. **Sandboxed JS plugins** (single JavaScript snippet, runs in a VM sandbox)
2. **Container plugins** (a `plugin.yaml` manifest plus a file bundle, runs in Docker)

## 1) Sandboxed JS Plugins

### Create (HTTP)
- `POST /api/gitu/plugins`

Example body:
```json
{
  "name": "File helper",
  "description": "Write and read a file via the Gitu file API",
  "code": "module.exports = async (ctx) => { await ctx.gitu.files.write(ctx.input.path, ctx.input.content); const read = await ctx.gitu.files.read(ctx.input.path); return { read }; };",
  "entrypoint": "run",
  "enabled": true
}
```

### Execution context
Your plugin receives:
- `ctx.input`: the request payload passed at execution time
- `ctx.config`: plugin config stored in DB
- `ctx.gitu.files`: file APIs (permission-gated)
- `ctx.gitu.shell.execute`: shell execution (permission-gated + allowlisted)

### Safety model
Sandboxed JS plugins are intentionally restricted:
- No `require()`, dynamic `import()`, `process`, `fs`, `child_process`, `eval`
- No `fetch` / WebSocket from the sandbox

If you need dependencies, networking, or multi-file plugins, use container plugins.

## 2) Container Plugins (Custom “plugin.yaml” + Files)

Container plugins let you build a real plugin bundle (multiple files) and run it in a hardened Docker container.

### Create (HTTP)
- `POST /api/gitu/plugins`

Example body:
```json
{
  "name": "My Container Plugin",
  "description": "Runs a Node script inside Docker",
  "code": "name: my_container_plugin\nversion: 1.0.0\ndescription: example\nruntime: node18\nentry: main.js\npermissions:\n  network: false\n  filesystem: none\n  env: []\n",
  "config": {
    "files": {
      "main.js": "console.log('hello from container');"
    }
  },
  "enabled": true
}
```

Notes:
- `code` must be the `plugin.yaml` content (YAML).
- `config.files` must include the file referenced by `entry`.

### Manifest schema
See [pluginManifest.ts](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/backend/src/services/plugins/pluginManifest.ts).

### Runtime requirements
- Docker must be installed and available to the backend runtime.
- The backend builds and runs a container using your manifest permissions:
  - `permissions.network: false` → `--network=none`
  - `permissions.filesystem: none|read-only` → `--read-only` with `--tmpfs /tmp`

## Validate a plugin before saving
- `POST /api/gitu/plugins/validate`

This returns `{ valid, errors }` so you can fix issues before `POST /plugins`.

