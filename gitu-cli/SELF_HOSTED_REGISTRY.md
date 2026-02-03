# Self-Hosting the CLI Package (Private npm Registry)

If you want `npm install -g @cmgzone/gitu-cli` to install from your own server (for example `backend.taskiumnetwork.com`), you need an **npm-compatible registry**.

This guide uses **Verdaccio** because it is lightweight and speaks the same protocol npm uses.

## 1) Run a registry (Verdaccio) with Docker

Create a folder on your server (example: `/opt/taskium-registry`) and add:

### `docker-compose.yml`

```yaml
version: "3.8"

services:
  verdaccio:
    image: verdaccio/verdaccio:6
    container_name: taskium-npm-registry
    restart: unless-stopped
    ports:
      - "4873:4873"
    volumes:
      - ./conf:/verdaccio/conf
      - ./storage:/verdaccio/storage
```

### `conf/config.yaml`

```yaml
storage: /verdaccio/storage

auth:
  htpasswd:
    file: /verdaccio/conf/htpasswd
    max_users: -1

uplinks: {}

packages:
  "@cmgzone/*":
    access: $authenticated
    publish: $authenticated
  "**":
    access: $authenticated
    publish: $authenticated

logs:
  - {type: stdout, format: pretty, level: http}
```

Start it:

```bash
docker compose up -d
```

Registry is now reachable on:

```text
http://<server-ip-or-hostname>:4873/
```

## 2) Put it behind your domain (HTTPS recommended)

You can reverse-proxy Verdaccio so it’s reachable as:

- `https://backend.taskiumnetwork.com/` (root), or
- `https://backend.taskiumnetwork.com/npm/` (subpath)

The exact reverse-proxy config depends on what you use (Nginx / Caddy / Traefik). The key requirement is that requests to Verdaccio keep the original `Host` header and forward all paths.

## 3) Create a registry user and get an auth token

From any machine that can reach the registry:

```bash
npm adduser --registry https://backend.taskiumnetwork.com/
```

After login, npm stores a token in your user `.npmrc`. Look for a line like:

```text
//backend.taskiumnetwork.com/:_authToken=...
```

Use that token as the value for your CI secret (see the GitHub Actions section below).

## 4) Configure installs to use your registry

For end users (or on your build machines), create/update `~/.npmrc`:

```text
@cmgzone:registry=https://backend.taskiumnetwork.com/
```

Then install normally:

```bash
npm install -g @cmgzone/gitu-cli
```

## 5) Publish to your registry

From the `gitu-cli/` folder:

```bash
npm ci
npm run build
```

Login to your registry:

```bash
npm adduser --registry https://backend.taskiumnetwork.com/
```

Publish:

```bash
npm publish --access public --registry https://backend.taskiumnetwork.com/
```

## Troubleshooting

- If installs still hit `registry.npmjs.org`, ensure your scope mapping exists in `.npmrc`:
  - `@cmgzone:registry=...`
- If publish fails with `ENEEDAUTH`, confirm the token line matches the exact host/path the registry uses.
- If you reverse-proxy under a subpath (like `/npm/`), set `TASKIUM_NPM_REGISTRY_URL` to that full base URL.
