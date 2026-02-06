# Gitu CLI - Complete Implementation Summary

## What Was Implemented

A comprehensive command-line interface for managing Gitu Universal Assistant from your Coolify deployment.

## Files Created/Modified

### Core CLI Implementation
- ✅ `backend/src/scripts/gitu-cli.ts` - Enhanced with commander for CLI arguments
- ✅ `backend/package.json` - Added gitu-cli and gitu scripts, commander & qrcode dependencies

### Documentation
- ✅ `GITU_CLI_COOLIFY_ACCESS.md` - Comprehensive access guide for Coolify
- ✅ `GITU_CLI_QUICK_REFERENCE.md` - Quick command reference card
- ✅ `GITU_CLI_SETUP_GUIDE.md` - Step-by-step setup instructions
- ✅ `GITU_CLI_SUMMARY.md` - This file

### Helper Scripts
- ✅ `scripts/gitu-remote.ps1` - PowerShell helper for Windows users

## Available Commands

### Authentication & QR Codes
```bash
npm run gitu-cli -- generate-qr <user-id>           # Generate QR code
npm run gitu-cli -- generate-qr <user-id> --format terminal
npm run gitu-cli -- verify-token <token>            # Verify pairing token
```

### Session Management
```bash
npm run gitu-cli -- list-sessions                   # List all active sessions
npm run gitu-cli -- list-sessions --user <user-id>  # Filter by user
```

### User Management
```bash
npm run gitu-cli -- list-users                      # List users (default: 10)
npm run gitu-cli -- list-users --limit 50           # List more users
```

### System Diagnostics
```bash
npm run gitu-cli -- health-check                    # Check system health
npm run gitu-cli -- verify-tables                   # Verify database tables
```

### Interactive Mode
```bash
npm run gitu-cli -- repl                            # Start REPL mode
```

## How to Access on Coolify

### Method 1: Direct Docker Exec (Recommended)
```bash
# SSH into Coolify server
ssh user@your-server.com

# Find container
docker ps | grep notebookllm

# Execute command
docker exec -it <container-id> npm run gitu-cli -- help
```

### Method 2: Helper Script (Easiest)

**Linux/Mac:**
```bash
# Create ~/gitu-cli.sh with provided template
chmod +x ~/gitu-cli.sh
sudo mv ~/gitu-cli.sh /usr/local/bin/gitu

# Use it
gitu help
gitu generate-qr user-123
gitu list-sessions
```

**Windows:**
```powershell
# Edit scripts/gitu-remote.ps1 with your server details
.\scripts\gitu-remote.ps1 help
.\scripts\gitu-remote.ps1 generate-qr user-123
```

### Method 3: Coolify Web Terminal
1. Open Coolify Dashboard
2. Navigate to NotebookLLM Backend service
3. Click "Terminal" button
4. Run: `npm run gitu-cli -- help`

## Setup Steps

1. **Update Dependencies** (Already done)
   ```bash
   cd backend
   npm install commander qrcode
   git add package.json package-lock.json
   git commit -m "Add CLI dependencies"
   git push
   ```

2. **Wait for Coolify to Redeploy**
   - Coolify will automatically detect the changes
   - Wait for deployment to complete

3. **Test CLI Access**
   ```bash
   ssh user@server
   docker exec -it <container-id> npm run gitu-cli -- help
   ```

4. **Set Up Local Helper** (Optional but recommended)
   - Follow instructions in `GITU_CLI_SETUP_GUIDE.md`

## Common Use Cases

### 1. Pair New Terminal
```bash
# Get user ID
gitu list-users

# Generate QR code
gitu generate-qr abc-123-def

# User scans with mobile app

# Verify session
gitu list-sessions --user abc-123-def
```

### 2. Debug Authentication
```bash
gitu health-check
gitu verify-tables
gitu list-sessions
gitu verify-token <token-from-logs>
```

### 3. Monitor System
```bash
gitu list-users --limit 20
gitu list-sessions
gitu health-check
```

## Dependencies Added

```json
{
  "dependencies": {
    "commander": "^12.1.0",  // CLI argument parsing
    "qrcode": "^1.5.4"       // QR code generation
  }
}
```

## Environment Variables Required

Make sure these are set in your Coolify deployment:

```env
DATABASE_URL=postgresql://...
JWT_SECRET=your-secret-key
QR_CODE_ENABLED=true
TELEGRAM_BOT_TOKEN=your-token (optional)
```

## Troubleshooting

### Container Not Found
```bash
ssh user@server "docker ps -a"
```

### Command Not Found
```bash
docker exec -it <container-id> cat package.json | grep gitu-cli
docker exec -it <container-id> npm install
```

### Database Connection Failed
```bash
docker exec -it <container-id> env | grep DATABASE_URL
```

### Permission Denied
```bash
docker exec -u root -it <container-id> /bin/sh
```

## Documentation Structure

```
GITU_CLI_COOLIFY_ACCESS.md     # Comprehensive guide (all methods)
├── Method 1: SSH into Container
├── Method 2: Coolify Web Terminal
├── Method 3: API Endpoints
└── Troubleshooting

GITU_CLI_QUICK_REFERENCE.md    # Quick command lookup
├── Setup (one-time)
├── Common Commands
├── Example Workflows
└── Tips & Tricks

GITU_CLI_SETUP_GUIDE.md        # Step-by-step setup
├── Prerequisites
├── Step 1-7: Setup Process
├── Use Cases
├── Troubleshooting
└── Next Steps

GITU_CLI_SUMMARY.md            # This file
└── Overview & Quick Start
```

## Next Steps

1. ✅ **Deployed to GitHub** - All changes pushed
2. ⏳ **Wait for Coolify** - Auto-deployment in progress
3. 🧪 **Test CLI** - Verify commands work
4. 📱 **Test QR Pairing** - Generate QR and test with mobile app
5. 🔧 **Set Up Helper Script** - For easier local access
6. 📊 **Monitor Usage** - Track CLI usage and sessions

## Quick Start (After Coolify Deploys)

```bash
# 1. SSH into your Coolify server
ssh user@your-server.com

# 2. Find your container
CONTAINER_ID=$(docker ps --filter 'name=notebookllm-backend' --format '{{.ID}}' | head -1)

# 3. Test the CLI
docker exec -it $CONTAINER_ID npm run gitu-cli -- help

# 4. Check system health
docker exec -it $CONTAINER_ID npm run gitu-cli -- health-check

# 5. List users
docker exec -it $CONTAINER_ID npm run gitu-cli -- list-users

# 6. Generate a QR code (replace with real user ID)
docker exec -it $CONTAINER_ID npm run gitu-cli -- generate-qr <user-id>
```

## Support & Resources

- **Full Guide**: `GITU_CLI_COOLIFY_ACCESS.md`
- **Quick Reference**: `GITU_CLI_QUICK_REFERENCE.md`
- **Setup Guide**: `GITU_CLI_SETUP_GUIDE.md`
- **Terminal Docs**: `docs/gitu/TERMINAL_CLI_GUIDE.md`
- **Troubleshooting**: `docs/gitu/TROUBLESHOOTING.md`

## Security Notes

- CLI commands should only be accessible to admin users
- Use SSH keys for server access
- Never share QR codes or tokens in logs
- Implement audit logging for CLI operations
- Use environment variables for sensitive data

---

**Status**: ✅ Implemented and deployed to GitHub

**Ready to use**: After Coolify completes deployment (usually 2-5 minutes)

**First command to try**: `npm run gitu-cli -- health-check`
