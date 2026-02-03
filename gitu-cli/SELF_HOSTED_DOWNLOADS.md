# Self-Hosted Direct Downloads (No Registry)

If you want users to download/install the CLI **directly from your server** (for example `backend.taskiumnetwork.com`) without using an npm registry, the simplest approach is to serve the **standalone binaries** and/or the **.tgz** package from a static URL.

This repo already produces:

- Standalone binaries (Windows/macOS/Linux) via `npm run package:bin:*`
- A Node installable tarball (`cmgzone-gitu-cli-<version>.tgz`) via `npm pack`

## Option A: Serve standalone binaries (recommended for “download directly”)

### 1) Build the binaries

From the `gitu-cli/` folder:

```bash
npm ci
npm run package:bin:linux
npm run package:bin:mac
npm run package:bin:win
```

Outputs:

- `dist-bin/gitu-linux-x64`
- `dist-bin/gitu-macos-x64`
- `dist-bin/gitu-win-x64.exe`

### 2) Upload them to your server and expose them over HTTPS

Pick a public base URL you control, for example:

```text
https://backend.taskiumnetwork.com/downloads/gitu-cli/
```

Serve these exact filenames at that base URL:

- `gitu-linux-x64`
- `gitu-macos-x64`
- `gitu-win-x64.exe`

### 3) Users install via the existing one-liners (using an env var)

macOS/Linux:

```bash
curl -fsSL https://raw.githubusercontent.com/cmgzone/gitucli/HEAD/scripts/install-cli.sh | GITU_CLI_DOWNLOAD_BASE_URL="https://backend.taskiumnetwork.com/downloads/gitu-cli" bash
```

Windows PowerShell:

```powershell
$env:GITU_CLI_DOWNLOAD_BASE_URL="https://backend.taskiumnetwork.com/downloads/gitu-cli"
$env:GITU_CLI_SKIP_PATH_UPDATE="1"
irm https://raw.githubusercontent.com/cmgzone/gitucli/HEAD/scripts/install-cli.ps1 | iex
```

The installer will download `gitu-<os>-x64[.exe]` from your server instead of GitHub Releases.

## Option B: Serve the npm tarball (.tgz) from your server

### 1) Build the tarball

```bash
npm ci
npm pack
```

This creates:

- `cmgzone-gitu-cli-<version>.tgz`

### 2) Upload to your server

Expose it at a stable URL, for example:

```text
https://backend.taskiumnetwork.com/downloads/gitu-cli/cmgzone-gitu-cli-1.2.3.tgz
```

### 3) Users install directly from the URL

```bash
npm install -g https://backend.taskiumnetwork.com/downloads/gitu-cli/cmgzone-gitu-cli-1.2.3.tgz
```

## When you should use a registry instead

If you want users to be able to run the standard command:

```bash
npm install -g @cmgzone/gitu-cli
```

and have it resolve via your server automatically, you need an npm-compatible registry.

See: [SELF_HOSTED_REGISTRY.md](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/gitu-cli/SELF_HOSTED_REGISTRY.md)
