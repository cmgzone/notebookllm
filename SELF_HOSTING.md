# Self-Hosting Gitu

You can fully self-host the Gitu stack (Backend + Database + CLI) on your own infrastructure.

## Prerequisites
*   Docker & Docker Compose
*   Node.js 18+ (if running CLI locally)

## 1. Start the Backend Stack
We provide a `docker-compose.yml` that orchestrates the API, PostgreSQL database, and Redis cache.

1.  **Configure Environment**
    Create a `.env` file in the root directory:
    ```env
    PORT=3000
    JWT_SECRET=your_secure_random_secret
    
    # AI Keys (Required for Intelligence)
    OPENAI_API_KEY=sk-...
    GEMINI_API_KEY=...
    
    # Database (Optional, defaults provided)
    DB_USER=postgres
    DB_PASSWORD=postgres
    DB_NAME=notebook_llm
    ```

2.  **Run the Stack**
    ```bash
    docker-compose up -d --build
    ```
    The API will be available at `http://localhost:3000`.

## 2. Install/Run the CLI

### Option A: Install from Source (Recommended)
If you have Node.js installed:

```bash
cd gitu-cli
npm install
npm link
```

### Option B: Run via Docker
If you prefer not to install Node.js, you can build the CLI container:

```bash
# Build the CLI image
docker build -t gitu-cli ./gitu-cli

# Run commands
docker run --network host -it gitu-cli init
docker run --network host -it gitu-cli chat
```
*Note: `--network host` is required on Linux to access `localhost:3000`. On Mac/Windows, use `host.docker.internal` as the API URL.*

### Option C: Publish + Install from Your Own Registry

If you want `npm install -g @cmgzone/gitu-cli` to install from your own server (for example `backend.taskiumnetwork.com`), you need an npm-compatible registry (Verdaccio is the lightweight option).

See: [SELF_HOSTED_REGISTRY.md](file:///c:/Users/Admin/Documents/project/NOTBOOK%20LLM/gitu-cli/SELF_HOSTED_REGISTRY.md)

## 3. Connect CLI to Self-Hosted Backend

1.  Run the initialization wizard:
    ```bash
    gitu init
    ```

2.  When asked for the **API URL**, enter:
    *   `http://localhost:3000` (if running locally)
    *   `https://your-domain.com` (if deployed to a server)

3.  Enter your authentication token (you can generate one via the backend or use the default dev token if configured).

## 4. Verification

Run the health check command:
```bash
gitu whoami
```

If successful, you are now fully self-hosted! 🚀
