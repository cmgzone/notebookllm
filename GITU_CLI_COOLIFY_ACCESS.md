# Gitu CLI Access Guide for Coolify Deployment

This guide explains how to access and use the Gitu CLI when your backend is deployed on Coolify.

## Method 1: SSH into Coolify Container (Recommended)

### Step 1: Access Your Coolify Server
```bash
# SSH into your Coolify server
ssh user@your-coolify-server.com
```

### Step 2: Find Your Backend Container
```bash
# List all running containers
docker ps | grep notebookllm

# Or find by service name
docker ps --filter "name=notebookllm-backend"
```

### Step 3: Execute CLI Commands in Container
```bash
# Execute the Gitu CLI directly
docker exec -it <container-id> npm run gitu-cli -- <command>

# Examples:
docker exec -it <container-id> npm run gitu-cli -- help
docker exec -it <container-id> npm run gitu-cli -- generate-qr <user-id>
docker exec -it <container-id> npm run gitu-cli -- list-sessions
```

### Step 4: Interactive Shell (For Multiple Commands)
```bash
# Open an interactive shell in the container
docker exec -it <container-id> /bin/sh

# Once inside, you can run commands directly:
cd /app
npm run gitu-cli -- help
npm run gitu-cli -- generate-qr <user-id>
npm run gitu-cli -- list-sessions
npm run gitu-cli -- verify-token <token>

# Exit when done
exit
```

## Method 2: Coolify Web Terminal

1. **Open Coolify Dashboard**
   - Navigate to your Coolify web interface
   - Go to your NotebookLLM backend service

2. **Access Terminal**
   - Click on "Terminal" or "Shell" button
   - This opens a web-based terminal into your container

3. **Run CLI Commands**
   ```bash
   cd /app
   npm run gitu-cli -- help
   ```

## Method 3: Create API Endpoints (For Remote Access)

If you need to access Gitu CLI from your local computer without SSH, you can expose CLI commands via API endpoints.

### Add to `backend/src/routes/gitu.ts`:

```typescript
// Admin-only CLI endpoint
router.post('/cli/execute', authenticateToken, async (req, res) => {
  try {
    // Check if user is admin
    const user = await db.query.users.findFirst({
      where: eq(users.id, req.user.userId)
    });

    if (user?.role !== 'admin') {
      return res.status(403).json({ error: 'Admin access required' });
    }

    const { command, args } = req.body;

    // Execute CLI command programmatically
    // Import and call the appropriate CLI function
    const result = await executeGituCommand(command, args);

    res.json({ success: true, result });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});
```

## Available Gitu CLI Commands

### Authentication & Sessions
```bash
# Generate QR code for terminal pairing
npm run gitu-cli -- generate-qr <user-id>

# List active sessions
npm run gitu-cli -- list-sessions

# Verify a pairing token
npm run gitu-cli -- verify-token <token>

# Revoke a session
npm run gitu-cli -- revoke-session <session-id>
```

### User Management
```bash
# List all users
npm run gitu-cli -- list-users

# Get user details
npm run gitu-cli -- user-info <user-id>

# List user's connected devices
npm run gitu-cli -- list-devices <user-id>
```

### Database Operations
```bash
# Verify Gitu tables
npm run gitu-cli -- verify-tables

# Check schema
npm run gitu-cli -- check-schema

# Run migrations
npm run gitu-cli -- migrate
```

### Testing & Debugging
```bash
# Test terminal authentication flow
npm run gitu-cli -- test-terminal-auth

# Test QR authentication
npm run gitu-cli -- test-qr-auth

# Test Telegram adapter
npm run gitu-cli -- test-telegram

# Check system health
npm run gitu-cli -- health-check
```

## Quick Setup Script for Coolify

Create a helper script on your local machine:

```bash
# Save as: gitu-remote.sh
#!/bin/bash

COOLIFY_HOST="your-coolify-server.com"
COOLIFY_USER="your-ssh-user"
CONTAINER_NAME="notebookllm-backend"

# Find container ID
CONTAINER_ID=$(ssh $COOLIFY_USER@$COOLIFY_HOST "docker ps --filter 'name=$CONTAINER_NAME' --format '{{.ID}}' | head -1")

if [ -z "$CONTAINER_ID" ]; then
    echo "Error: Container not found"
    exit 1
fi

# Execute command
ssh $COOLIFY_USER@$COOLIFY_HOST "docker exec -it $CONTAINER_ID npm run gitu-cli -- $@"
```

Make it executable:
```bash
chmod +x gitu-remote.sh
```

Use it:
```bash
./gitu-remote.sh help
./gitu-remote.sh generate-qr user-123
./gitu-remote.sh list-sessions
```

## Environment Variables

Make sure these are set in your Coolify deployment:

```env
# Required for Gitu CLI
DATABASE_URL=your-neon-connection-string
JWT_SECRET=your-jwt-secret
REDIS_URL=your-redis-url (optional)

# For QR code generation
QR_CODE_ENABLED=true

# For Telegram integration
TELEGRAM_BOT_TOKEN=your-bot-token
```

## Troubleshooting

### Container Not Found
```bash
# List all containers
docker ps -a

# Check Coolify logs
docker logs <container-id>
```

### Permission Denied
```bash
# Run with proper user
docker exec -u root -it <container-id> /bin/sh
```

### CLI Command Not Found
```bash
# Verify package.json has the script
docker exec -it <container-id> cat package.json | grep gitu-cli

# Install dependencies if needed
docker exec -it <container-id> npm install
```

### Database Connection Issues
```bash
# Check environment variables
docker exec -it <container-id> env | grep DATABASE_URL

# Test database connection
docker exec -it <container-id> npm run test-db-connection
```

## Security Best Practices

1. **Restrict CLI Access**: Only allow admin users to execute CLI commands
2. **Use SSH Keys**: Set up SSH key authentication for Coolify server access
3. **Audit Logs**: Log all CLI command executions
4. **Rate Limiting**: Implement rate limiting for CLI API endpoints
5. **Environment Isolation**: Keep production CLI access separate from development

## Alternative: Local CLI Proxy

If you frequently need CLI access, consider creating a local proxy:

```typescript
// local-gitu-cli.ts
import axios from 'axios';

const API_URL = 'https://your-backend.coolify.app';
const ADMIN_TOKEN = 'your-admin-jwt-token';

async function executeRemoteCommand(command: string, args: any) {
  const response = await axios.post(
    `${API_URL}/api/gitu/cli/execute`,
    { command, args },
    { headers: { Authorization: `Bearer ${ADMIN_TOKEN}` } }
  );
  return response.data;
}

// Usage
const result = await executeRemoteCommand('generate-qr', { userId: '123' });
console.log(result);
```

## Next Steps

1. Choose your preferred access method (SSH recommended for security)
2. Set up the helper script for easier access
3. Test with basic commands like `help` and `list-sessions`
4. Configure environment variables if needed
5. Set up monitoring for CLI usage

## Support

For issues or questions:
- Check Coolify logs: `docker logs <container-id>`
- Review backend logs: `docker exec -it <container-id> tail -f /app/logs/app.log`
- Test database connectivity: `npm run test-db-connection`
- Verify migrations: `npm run gitu-cli -- verify-tables`

---

**Pro Tip**: Create an alias in your local shell for quick access:
```bash
alias gitu-remote='ssh user@coolify-server "docker exec -it \$(docker ps --filter name=notebookllm-backend --format {{.ID}} | head -1) npm run gitu-cli --"'

# Then use it like:
gitu-remote help
gitu-remote list-sessions
```
