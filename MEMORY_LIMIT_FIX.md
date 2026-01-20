# Node.js Memory Limit Fix

## Problem
Backend server was crashing with "FATAL ERROR: Reached heap limit Allocation failed - JavaScript heap out of memory"

## Root Cause
Node.js by default limits heap memory to around 1.4-1.7GB. The backend application was exceeding this limit during operation, likely due to:
- Large AI model responses being processed
- Multiple concurrent requests
- Memory-intensive operations (embeddings, deep research, etc.)

## Solution
Increased Node.js heap memory limit to 4GB by adding the `--max-old-space-size=4096` flag to the start script.

### Changes Made

**File: `backend/package.json`**
```json
"start": "node --max-old-space-size=4096 dist/index.js"
```

**File: `Dockerfile`**
Added cache-busting argument to force Docker to rebuild and pick up the new package.json:
```dockerfile
ARG CACHEBUST=1
```

This allocates 4GB of heap memory for the Node.js process.

### Docker Cache Issue
The initial deployment was still using 2GB because Docker cached the old package.json layer. The CACHEBUST argument forces Docker to invalidate the cache and rebuild with the updated package.json.

## Memory Limit Options
- `--max-old-space-size=1024` - 1GB (minimum recommended)
- `--max-old-space-size=2048` - 2GB (previous setting)
- `--max-old-space-size=4096` - 4GB (current production setting)
- `--max-old-space-size=8192` - 8GB (for very large workloads)

## Deployment Instructions

### For Coolify or Docker-based Deployments:

1. **Pull latest changes** from GitHub (commit e5c13c3 or later)

2. **Force rebuild without cache** in Coolify:
   - Go to your deployment settings
   - Find "Build Options" or "Advanced Settings"
   - Enable "Force Rebuild" or "No Cache"
   - Or manually trigger rebuild with: `docker build --no-cache .`

3. **Verify the deployment**:
   - Check logs for: `node --max-old-space-size=4096 dist/index.js`
   - Should NOT show `--max-old-space-size=2048`

4. **Alternative**: Change CACHEBUST value in Dockerfile to force rebuild:
   ```dockerfile
   ARG CACHEBUST=2  # Change this number to force rebuild
   ```

### Verification
After deployment, check the startup logs. You should see the process starting with 4GB limit:
```
npm start
> node --max-old-space-size=4096 dist/index.js
```

If you still see `2048`, the cache wasn't cleared. Try:
- Deleting the deployment and recreating it
- Using `docker system prune -a` to clear all Docker cache
- Manually building with `--no-cache` flag

## Monitoring
To monitor memory usage:
```bash
# Check Node.js process memory
node -e "console.log(process.memoryUsage())"

# Monitor in production
pm2 monit  # if using PM2
```

## Alternative Solutions
If memory issues persist:

1. **Implement streaming for large responses** - Already done for AI chat
2. **Add response caching** - Cache frequently requested data
3. **Optimize database queries** - Use pagination, limit result sets
4. **Use worker threads** - Offload CPU-intensive tasks
5. **Horizontal scaling** - Run multiple instances behind a load balancer

## Production Recommendations
For production deployment:
- Start with 2GB and monitor
- Increase to 4GB if needed
- Consider using PM2 for process management and auto-restart
- Set up memory monitoring and alerts
- Implement proper error handling for OOM scenarios

## Testing
After deployment, monitor:
- Memory usage trends
- Response times
- Error rates
- Server uptime

If memory usage consistently approaches the limit, increase it further or investigate memory leaks.
