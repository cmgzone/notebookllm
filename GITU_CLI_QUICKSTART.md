# Gitu CLI - Quick Start (5 Minutes)

Get started with Gitu CLI on your Coolify deployment in 5 minutes.

## Step 1: Wait for Deployment (2 min)

Your changes are pushed to GitHub. Coolify will automatically:
1. Detect the changes
2. Pull the latest code
3. Run `npm install` (installs commander & qrcode)
4. Rebuild and restart the container

Check Coolify dashboard to see deployment progress.

## Step 2: Test CLI Access (1 min)

```bash
# SSH into your Coolify server
ssh your-user@your-coolify-server.com

# Find your container ID
docker ps | grep notebookllm

# Test the CLI (replace <container-id> with actual ID)
docker exec -it <container-id> npm run gitu-cli -- help
```

You should see:
```
Usage: gitu-cli [options] [command]

Gitu Universal Assistant CLI

Options:
  -V, --version                    output the version number
  -h, --help                       display help for command

Commands:
  generate-qr <userId>             Generate QR code for terminal pairing
  list-sessions                    List all active Gitu sessions
  verify-token <token>             Verify a pairing token
  list-users                       List all users
  verify-tables                    Verify Gitu database tables exist
  health-check                     Check system health
  repl                             Start interactive REPL mode
  help [command]                   display help for command
```

## Step 3: Run Your First Commands (2 min)

### Check System Health
```bash
docker exec -it <container-id> npm run gitu-cli -- health-check
```

Expected output:
```
🏥 Running health checks...

✅ Database: Connected
✅ DATABASE_URL: Set
✅ JWT_SECRET: Set

Done!
```

### List Users
```bash
docker exec -it <container-id> npm run gitu-cli -- list-users
```

### Generate QR Code
```bash
# Use a user ID from the previous command
docker exec -it <container-id> npm run gitu-cli -- generate-qr <user-id>
```

You'll see a QR code in your terminal! 🎉

## Optional: Set Up Helper Script (Bonus)

### For Linux/Mac:

Create `~/gitu`:
```bash
#!/bin/bash
COOLIFY_HOST="your-server.com"
COOLIFY_USER="your-username"
CONTAINER_NAME="notebookllm-backend"

CONTAINER_ID=$(ssh $COOLIFY_USER@$COOLIFY_HOST "docker ps --filter 'name=$CONTAINER_NAME' --format '{{.ID}}' | head -1")
ssh $COOLIFY_USER@$COOLIFY_HOST "docker exec -it $CONTAINER_ID npm run gitu-cli -- $@"
```

Make executable:
```bash
chmod +x ~/gitu
sudo mv ~/gitu /usr/local/bin/gitu
```

Now use it:
```bash
gitu help
gitu list-users
gitu generate-qr <user-id>
```

### For Windows:

Edit `scripts/gitu-remote.ps1`:
```powershell
$COOLIFY_HOST = "your-coolify-server.com"
$COOLIFY_USER = "your-ssh-user"
$CONTAINER_NAME = "notebookllm-backend"
```

Use it:
```powershell
.\scripts\gitu-remote.ps1 help
.\scripts\gitu-remote.ps1 list-users
```

## Common Commands Cheat Sheet

```bash
# System
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

# Tokens
gitu verify-token <token>

# Interactive
gitu repl
```

## Troubleshooting

### "Container not found"
```bash
docker ps -a
# Look for notebookllm-backend
```

### "Command not found"
```bash
# Check if dependencies installed
docker exec -it <container-id> npm list commander qrcode

# If missing, install
docker exec -it <container-id> npm install
```

### "Database connection failed"
```bash
# Check environment variable
docker exec -it <container-id> env | grep DATABASE_URL

# Should show your Neon database URL
```

## Next Steps

✅ CLI is working!

Now you can:
1. 📱 Test QR code pairing with mobile app
2. 🔧 Set up the helper script for easier access
3. 📚 Read full documentation:
   - `GITU_CLI_COOLIFY_ACCESS.md` - Complete guide
   - `GITU_CLI_SETUP_GUIDE.md` - Detailed setup
   - `GITU_CLI_SUMMARY.md` - Implementation overview

## Need Help?

Check the logs:
```bash
docker logs <container-id> --tail 100
```

Or run health check:
```bash
docker exec -it <container-id> npm run gitu-cli -- health-check
```

---

**That's it!** You now have full CLI access to Gitu on your Coolify deployment. 🚀
