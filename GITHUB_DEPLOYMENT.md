# GitHub Deployment Guide

## Prerequisites
- Git installed and configured
- GitHub account with repository access
- SSH key or personal access token configured

## Step 1: Check Git Status

```powershell
git status
```

This shows all modified files that need to be committed.

## Step 2: Stage Changes

```powershell
# Stage all changes
git add .

# Or stage specific files
git add lib/core/api/api_service.dart
git add lib/core/auth/auth_service.dart
git add BACKEND_INTEGRATION_FIX.md
```

## Step 3: Commit Changes

```powershell
git commit -m "fix: backend integration - fix API response parsing and auth handling

- Fix _handleResponse() to handle null/empty responses
- Fix auth service to handle backend response structure
- Add proper error handling for all API calls
- Fix notebook provider to handle unauthenticated state
- Add null checks and validation throughout"
```

## Step 4: Push to GitHub

```powershell
# Push to main branch
git push origin main

# Or push to a feature branch first
git push origin feature/backend-integration-fix
```

## Step 5: Create Pull Request (if using feature branch)

1. Go to GitHub repository
2. Click "Compare & pull request"
3. Add description of changes
4. Request reviewers
5. Merge when approved

## Troubleshooting

### Authentication Issues
```powershell
# Check current git config
git config --list

# Set credentials
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

### SSH Key Issues
```powershell
# Generate SSH key
ssh-keygen -t ed25519 -C "your.email@example.com"

# Add to SSH agent
ssh-add ~/.ssh/id_ed25519

# Test connection
ssh -T git@github.com
```

### Push Rejected
```powershell
# Pull latest changes first
git pull origin main

# Then push
git push origin main
```

## Commit Message Format

Use conventional commits:
- `fix:` - Bug fixes
- `feat:` - New features
- `docs:` - Documentation
- `refactor:` - Code refactoring
- `test:` - Test updates
- `chore:` - Build/dependency updates

Example:
```
fix: backend integration issues

- Fix API response parsing
- Fix auth token handling
- Add error handling

Fixes #123
```

## After Deployment

1. Verify changes on GitHub
2. Check CI/CD pipeline status
3. Monitor for any deployment issues
4. Update documentation if needed
5. Notify team of changes

## Rollback (if needed)

```powershell
# Revert last commit
git revert HEAD

# Or reset to previous commit
git reset --hard HEAD~1

# Push revert
git push origin main
```
