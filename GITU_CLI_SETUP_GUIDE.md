# Gitu CLI Setup Guide for Coolify

Step-by-step guide to set up and use Gitu CLI with your Coolify deployment.

## Prerequisites

- SSH access to your Coolify server
- NotebookLLM backend deployed on Coolify
- SSH client installed on your local machine

## Step 1: Update Backend Dependencies

First, ensure your backend has the required dependencies:

```bash
# On your local machine, in the backend directory
cd backend
npm install commander qrcode
```

Then commit and push:
```bash
git add package.json package-lock.json
git commit -m "Add CLI dependencies"
git push
```

Coolify will automatically redeploy with the new dependencies.

## Step 2: Verify Deployment

Wait for Coolify to finish deploying, then verify:

```bash
# SSH into your Coolify server
ssh your-user@your-coolify-server.com

# Find your container
docker ps | grep notebookllm

# You should see something like:
# abc123def456  notebookllm-backend  ...
```

## Step 3: Test CLI Access

Test that the CLI works:

```bash
# Replace <container-id> with your actual container ID
docker exec -it <container-id> npm run gitu-cli -- help

# You should see the CLI help menu
```

## Step 4: Set Up Local Helper Script

### For Linux/Mac:

1. Create the helper script:
```bash
nano ~/gitu-cli.sh
```

2. Paste this content (update the variables):
```bash
#!/bin/bash
COOLIFY_HOST="your-server.com"
COOLIFY_USER="your-username"
CONTAINER_NAME="notebookllm-backend"

CONTAINER_ID=$(ssh $COOLIFY_USER@$COOLIFY_HOST "docker ps --filter 'name=$CONTAINER_NAME' --format '{{.ID}}' | head -1")

if [ -z "$CONTAINER_ID" ]; then
    echo "❌ Container not found"
    exit 1
fi

ssh $COOLIFY_USER@$COOLIFY_HOST "docker exec -it $CONTAINER_ID npm run gitu-cli -- $@"
```

3. Make it executable:
```bash
chmod +x ~/gitu-cli.sh
```

4. (Optional) Move to PATH:
```bash
sudo mv ~/gitu-cli.sh /usr/local/bin/gitu
```

5. Test it:
```bash
gitu help
# or if you didn't move it:
~/gitu-cli.sh help
```

### For Windows:

1. Use the provided PowerShell script:
```powershell
# Edit scripts/gitu-remote.ps1 and update these lines:
$COOLIFY_HOST = "your-coolify-server.com"
$COOLIFY_USER = "your-ssh-user"
$CONTAINER_NAME = "notebookllm-backend"
```

2. Test it:
```powershell
.\scripts\gitu-remote.ps1 help
```

3. (Optional) Create an alias:
```powershell
# Add to your PowerShell profile
Set-Alias gitu "C:\path\to\project\scripts\gitu-remote.ps1"
```

## Step 5: First Commands

Try these commands to verify everything works:

### 1. Health Check
```bash
gitu health-check
```

Expected output:
```
🏥 Running health checks...

✅ Database: Connected
✅ DATABASE_URL: Set
✅ JWT_SECRET: Set

Done!
```

### 2. Verify Tables
```bash
gitu verify-tables
```

Expected output:
```
Verifying Gitu tables...

✅ gitu_sessions
✅ gitu_pairing_tokens
✅ gitu_devices
✅ gitu_messages
✅ gitu_permissions

Done!
```

### 3. List Users
```bash
gitu list-users --limit 5
```

### 4. Generate QR Code
```bash
# Get a user ID from the previous command
gitu generate-qr <user-id>
```

You should see a QR code in your terminal!

## Step 6: Common Use Cases

### Use Case 1: Pair a New Terminal

```bash
# 1. Get user ID (from your app or database)
gitu list-users

# 2. Generate QR code for that user
gitu generate-qr abc-123-def-456

# 3. User scans the QR code with mobile app

# 4. Verify the session was created
gitu list-sessions --user abc-123-def-456
```

### Use Case 2: Debug Authentication Issues

```bash
# Check system health
gitu health-check

# Verify all tables exist
gitu verify-tables

# Check active sessions
gitu list-sessions

# If you have a token from logs, verify it
gitu verify-token <token>
```

### Use Case 3: Monitor Active Users

```bash
# See recent users
gitu list-users --limit 20

# Check their active sessions
gitu list-sessions
```

## Step 7: Alternative Access Methods

### Method A: Direct SSH + Docker

```bash
# SSH into server
ssh user@your-server.com

# Find container
CONTAINER_ID=$(docker ps --filter 'name=notebookllm-backend' --format '{{.ID}}' | head -1)

# Run command
docker exec -it $CONTAINER_ID npm run gitu-cli -- help
```

### Method B: Coolify Web Terminal

1. Open your Coolify dashboard
2. Navigate to your NotebookLLM backend service
3. Click the "Terminal" or "Shell" button
4. Run commands directly:
```bash
npm run gitu-cli -- help
npm run gitu-cli -- list-users
npm run gitu-cli -- generate-qr <user-id>
```

### Method C: Interactive REPL Mode

For extended CLI sessions:

```bash
# Start REPL mode
gitu repl

# Now you can run commands interactively
Gitu> help
Gitu> list-users
Gitu> generate-qr abc-123
Gitu> exit
```

## Troubleshooting

### Issue: "Container not found"

**Solution:**
```bash
# List all containers
ssh user@server "docker ps -a"

# Check if backend is running
ssh user@server "docker ps | grep notebook"

# Check Coolify logs
# Go to Coolify dashboard > Your service > Logs
```

### Issue: "Command not found: npm"

**Solution:**
```bash
# Verify Node.js is installed in container
ssh user@server "docker exec -it <container-id> node --version"

# If not, check your Dockerfile
```

### Issue: "Database connection failed"

**Solution:**
```bash
# Check environment variables
ssh user@server "docker exec -it <container-id> env | grep DATABASE_URL"

# Verify DATABASE_URL is set in Coolify:
# Coolify dashboard > Your service > Environment Variables
```

### Issue: "Permission denied"

**Solution:**
```bash
# Run as root
ssh user@server "docker exec -u root -it <container-id> /bin/sh"
```

### Issue: "Module 'commander' not found"

**Solution:**
```bash
# Install dependencies in container
ssh user@server "docker exec -it <container-id> npm install"

# Or rebuild and redeploy from Coolify
```

## Security Best Practices

1. **Restrict CLI Access**: Only allow admin users to execute CLI commands
2. **Use SSH Keys**: Set up SSH key authentication instead of passwords
3. **Audit Logs**: Log all CLI command executions
4. **Environment Variables**: Never expose sensitive data in CLI output
5. **Rate Limiting**: Implement rate limiting for CLI operations

## Next Steps

1. ✅ Set up local helper script
2. ✅ Test basic commands
3. ✅ Generate your first QR code
4. 📱 Test pairing with mobile app
5. 🔄 Set up monitoring/alerts
6. 📚 Read full documentation in `docs/gitu/`

## Additional Resources

- Full CLI Reference: `GITU_CLI_COOLIFY_ACCESS.md`
- Quick Reference: `GITU_CLI_QUICK_REFERENCE.md`
- Terminal Guide: `docs/gitu/TERMINAL_CLI_GUIDE.md`
- Troubleshooting: `docs/gitu/TROUBLESHOOTING.md`

## Support

If you encounter issues:

1. Check the logs:
   ```bash
   ssh user@server "docker logs <container-id> --tail 100"
   ```

2. Verify environment:
   ```bash
   gitu health-check
   ```

3. Test database connection:
   ```bash
   ssh user@server "docker exec -it <container-id> npm run test-db-connection"
   ```

4. Check Coolify deployment status in the dashboard

## Quick Command Reference

```bash
# Help
gitu help

# Health & Status
gitu health-check
gitu verify-tables

# Users
gitu list-users
gitu list-users --limit 50

# Sessions
gitu list-sessions
gitu list-sessions --user <user-id>

# QR Codes
gitu generate-qr <user-id>
gitu generate-qr <user-id> --format terminal

# Tokens
gitu verify-token <token>

# Interactive
gitu repl
```

---

**Ready to use Gitu CLI!** 🚀

Start with `gitu health-check` to verify everything is working.
