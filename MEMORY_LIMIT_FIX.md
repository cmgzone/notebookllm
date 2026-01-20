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
- `--max-old-space-size=2048` - 2GB (current setting)
- `--max-old-space-size=4096` - 4GB (for high-traffic production)
- `--max-old-space-size=8192` - 8GB (for very large workloads)

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
