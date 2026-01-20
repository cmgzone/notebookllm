# Node.js Memory Limit Fix

## Problem
Backend server was crashing with "FATAL ERROR: Reached heap limit Allocation failed - JavaScript heap out of memory" even with 4GB memory limit.

## Root Causes
1. Node.js default heap memory limit (~1.4-1.7GB) was too low
2. **Memory leaks from unbounded content loading:**
   - Loading 500KB+ of content into AI prompts
   - No limits on database query results
   - Streaming buffers growing indefinitely
   - No cleanup after processing large data

## Solutions Implemented

### 1. Increased Memory Limit to 4GB
**File: `backend/package.json`**
```json
"start": "node --max-old-space-size=4096 dist/index.js"
```

### 2. Added Docker Cache-Busting
**File: `Dockerfile`**
```dockerfile
ARG CACHEBUST=1
```

### 3. Implemented Memory-Efficient Content Processing

**File: `backend/src/services/aiService.ts`**
- Limited summary content: 500KB → 50KB
- Limited flashcard content: 500KB → 30KB
- Limited quiz content: 500KB → 30KB
- Limited question generation: 500KB → 30KB
- Added buffer size limits in streaming (max 10KB)
- Added buffer cleanup after streaming

**File: `backend/src/services/researchService.ts`**
- Limited page content fetch: 5KB → 3KB per page
- Added maxContentLength: 100KB per HTTP request
- Limited sources in report: 12 → 8 sources
- Limited source content: 2KB → 1.5KB per source
- Reduced image/video references in reports

**File: `backend/src/routes/ai.ts`**
- Limited notebook chunks: 100 → 50 chunks
- Limited notebook summary: 500KB → 50KB
- Limited sources for questions: 10 → 5 sources
- Limited question content: 500KB → 30KB

## Memory Optimization Strategy

### Before (Memory Leak Pattern)
```typescript
// ❌ Loading massive content
const content = allSources.map(s => s.content).join('\n').substring(0, 500000);
const summary = await generateSummary(content);
```

### After (Memory Efficient)
```typescript
// ✅ Strict limits + cleanup
const content = allSources.slice(0, 5).map(s => 
  s.content.substring(0, 5000)
).join('\n').substring(0, 50000);
const summary = await generateSummary(content);
// content is garbage collected after use
```

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
