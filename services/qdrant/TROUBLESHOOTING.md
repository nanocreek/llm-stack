# Qdrant Troubleshooting Guide

Advanced troubleshooting for Qdrant deployment on Railway, including common issues, performance optimization, and debugging strategies.

## Quick Diagnostics

Before diving into specific issues, run these diagnostic commands:

```bash
# Check service health
curl http://qdrant.railway.internal:6333/readyz

# Check metrics
curl http://qdrant.railway.internal:6333/metrics

# List collections
curl -H "api-key: YOUR_API_KEY" http://qdrant.railway.internal:6333/collections
```

---

## Connection Issues

### Symptom: Services Can't Connect to Qdrant

**Solutions**:

1. **Verify internal DNS name**:
   ```bash
   curl -i http://qdrant.railway.internal:6333/readyz
   ```

2. **Check API key authentication** (if configured):
   ```bash
   curl -H "api-key: YOUR_API_KEY" http://qdrant.railway.internal:6333/health
   ```

3. **Review Railway service logs**:
   - Go to Railway Dashboard → Qdrant Service → Logs
   - Search for "health" or "readyz" to see health check results
   - Look for startup errors or configuration issues

4. **Verify volume mount**:
   - Ensure Qdrant volume is properly mounted to `/qdrant/storage`
   - Check Railway dashboard for volume status
   - Verify sufficient disk space available

5. **Check Railway networking**:
   - Verify all services are in the same Railway project
   - Confirm private networking is enabled
   - Test service-to-service communication

---

## Health Check Failures

### Symptom: Service Shows "Unhealthy" in Railway Dashboard

**Solutions**:

1. **Check Railway logs**:
   ```bash
   # Look for these patterns in Railway Dashboard → Qdrant → Logs
   - "health" or "readyz"
   - "error" or "exception"
   - "initialization"
   ```

2. **Test health endpoint manually with extended timeout**:
   ```bash
   curl --max-time 30 http://qdrant.railway.internal:6333/readyz
   ```

3. **Wait for initialization** (start period is 60 seconds):
   - Qdrant needs time to:
     - Load collections from disk
     - Initialize indexes
     - Prepare query engine
   - Check if service is still within the 60-second start period

4. **Verify disk space**:
   ```bash
   curl http://qdrant.railway.internal:6333/metrics | grep storage
   ```
   Look for `storage_disk_free_bytes` and `storage_disk_total_bytes`

5. **Check resource limits**:
   - Go to Railway Dashboard → Qdrant → Settings → Resources
   - Verify CPU and memory allocation
   - Increase if hitting limits (see metrics for usage)

---

## Performance Issues

### Symptom: Slow Search Queries or High Latency

**Solutions**:

1. **Check memory allocation**:
   ```bash
   curl http://qdrant.railway.internal:6333/metrics
   # Look for:
   # - memory_available_bytes
   # - memory_usage_bytes
   # - collections_points_total (total vectors)
   ```

2. **Monitor indexing progress**:
   - Large batch uploads require indexing time
   - Check logs for "indexing" status messages
   - Wait for indexing to complete before querying

3. **Scale Railway resources**:
   - **Memory**: Increase to 2GB+ for production
   - **CPU**: More threads = faster indexing and queries
   - Recommended: 1 CPU core per 250K vectors

4. **Optimize vector operations**:
   
   **Reduce vector dimensions** (if possible):
   - 384 dimensions → consider 256 if accuracy allows
   - Smaller vectors = faster search
   
   **Limit payload size**:
   ```bash
   # Use payload_values_count to restrict metadata
   curl -X POST http://qdrant.railway.internal:6333/collections/my_collection/points/search \
     -d '{
       "vector": [...],
       "limit": 10,
       "with_payload": {
         "include": ["title", "description"]
       }
     }'
   ```
   
   **Enable quantization** (for large collections >100K vectors):
   ```bash
   curl -X PUT http://qdrant.railway.internal:6333/collections/my_collection \
     -d '{
       "vectors": {
         "size": 384,
         "distance": "Cosine"
       },
       "quantization_config": {
         "scalar": {
           "type": "int8",
           "quantile": 0.99,
           "always_ram": true
         }
       }
     }'
   ```

5. **Check for slow queries in logs**:
   - Railway Logs → Search for "took" or "slow"
   - Identify which queries are problematic
   - Optimize filters and collection structure

### Symptom: High Memory Usage

**Solutions**:

```bash
# Enable vector cache (increases memory but speeds up queries)
QDRANT__PERFORMANCE__VECTOR_CACHE_SIZE_GB=1

# Increase indexing threads (uses more CPU, less memory per thread)
QDRANT__PERFORMANCE__INDEX_THREADS=4

# Use quantization (reduces memory by 75% for int8)
# Apply when creating collections (see quantization example above)
```

---

## Storage Issues

### Symptom: Out of Disk Space or Slow Writes

**Solutions**:

1. **Check disk usage**:
   ```bash
   # Get collection statistics
   curl http://qdrant.railway.internal:6333/collections
   
   # Calculate disk usage:
   # disk_usage ≈ points_count × (vector_size × 4 bytes + metadata_size)
   # Example: 1M vectors × 384 dims × 4 bytes = 1.46 GB (vectors only)
   ```

2. **Review and delete old snapshots**:
   ```bash
   # List snapshots
   curl http://qdrant.railway.internal:6333/snapshots
   
   # Delete specific snapshot
   curl -X DELETE http://qdrant.railway.internal:6333/snapshots/{snapshot_name}
   ```

3. **Implement TTL policies** (delete stale vectors):
   ```bash
   # Delete vectors older than 90 days
   curl -X POST http://qdrant.railway.internal:6333/collections/{collection_name}/points/delete \
     -H "Content-Type: application/json" \
     -d '{
       "filter": {
         "must": [
           {
             "key": "timestamp",
             "range": {
               "lt": 1704067200
             }
           }
         ]
       }
     }'
   ```

4. **Archive older collections**:
   - Create snapshot of old collection
   - Download snapshot to external storage
   - Delete collection from Qdrant
   - Restore from snapshot if needed later

5. **Increase Railway volume size**:
   - Go to Railway Dashboard → Qdrant Service → Settings
   - Adjust volume size allocation
   - Monitor growth trends to plan future increases

---

## API Authentication Issues

### Symptom: 401 Unauthorized Errors

**Solutions**:

1. **Verify API key is set**:
   - Railway Dashboard → Qdrant → Variables
   - Confirm `QDRANT_API_KEY` is present and not empty

2. **Include API key in requests**:
   ```bash
   # Correct way to pass API key
   curl -H "api-key: $QDRANT_API_KEY" http://qdrant.railway.internal:6333/health
   
   # Alternative: URL parameter (not recommended for production)
   curl "http://qdrant.railway.internal:6333/health?api_key=$QDRANT_API_KEY"
   ```

3. **Check for trailing spaces**:
   - API keys may have trailing whitespace if copy-pasted
   - Regenerate key if suspected:
     ```bash
     openssl rand -base64 32
     ```

4. **Rotate API key** (if suspected compromise):
   - Generate new key: `openssl rand -base64 32`
   - Update in Railway dashboard
   - Restart Qdrant service
   - Update all client configurations simultaneously
   - Monitor logs for unauthorized access attempts

5. **Verify client API key configuration**:
   - Python: `QdrantClient(api_key=os.getenv("QDRANT_API_KEY"))`
   - JavaScript: `new QdrantClient({ apiKey: process.env.QDRANT_API_KEY })`
   - REST: `curl -H "api-key: ..."` (header name is `api-key`, not `Authorization`)

---

## Collection and Vector Issues

### Symptom: Collection Not Found

**Solutions**:

```bash
# List all collections
curl -H "api-key: YOUR_API_KEY" http://qdrant.railway.internal:6333/collections

# Check if collection exists in list
# If not found, create it:
curl -X PUT http://qdrant.railway.internal:6333/collections/my_collection \
  -H "api-key: YOUR_API_KEY" \
  -d '{
    "vectors": {
      "size": 384,
      "distance": "Cosine"
    }
  }'
```

### Symptom: Vector Dimensions Don't Match

**Solutions**:

1. **Check collection schema**:
   ```bash
   curl -H "api-key: YOUR_API_KEY" \
     http://qdrant.railway.internal:6333/collections/{collection_name}
   
   # Look for: "size": 384 (or whatever dimension your collection uses)
   ```

2. **Verify your vectors**:
   - Count dimensions in your vector array
   - Must match collection's configured size exactly
   - All vectors in a collection must have same dimension

3. **Fix dimension mismatch**:
   - Either: Regenerate vectors with correct dimension
   - Or: Create new collection with matching dimension
   - Or: Use embedding model that produces correct dimension

4. **For batch operations**:
   - Verify ALL vectors in batch have same dimension
   - Check one vector doesn't have trailing zeros or extra values

---

## Railway-Specific Issues

### Symptom: Service Restarts Frequently

**Possible Causes & Solutions**:

1. **Memory limits exceeded**:
   - Check metrics: `memory_usage_bytes` vs allocated memory
   - Increase memory allocation in Railway settings
   - Enable quantization to reduce memory usage

2. **Health check timeouts**:
   - Health check has 10-second timeout
   - If Qdrant is slow to respond, increase start period
   - Current settings: 60s start period, 30s interval

3. **Disk I/O issues**:
   - Check for high write volume
   - Adjust flush interval:
     ```bash
     # More frequent flushes (better durability, more I/O)
     QDRANT__STORAGE__FLUSH_INTERVAL_MS=2000
     
     # Less frequent flushes (better performance, less durability)
     QDRANT__STORAGE__FLUSH_INTERVAL_MS=10000
     ```

### Symptom: Slow Startup (Takes >60 seconds)

**Solutions**:

1. **Check collection sizes**:
   - Large collections take longer to load
   - Consider splitting into multiple smaller collections

2. **Review snapshot configuration**:
   ```bash
   # Reduce snapshot frequency during startup issues
   QDRANT__SNAPSHOTS__SNAPSHOT_INTERVAL=1200  # 20 minutes
   ```

3. **Monitor Railway logs**:
   - Look for "Loading collection..." messages
   - Check for errors during initialization
   - Verify volume mount is working

---

## Advanced Debugging

### Enable Debug Logging

```bash
# Set in Railway dashboard
QDRANT__LOG_LEVEL=debug

# Restart service to apply
```

### Metrics Analysis

```bash
# Get detailed metrics
curl http://qdrant.railway.internal:6333/metrics

# Key metrics to monitor:
# - qdrant_collections_total
# - qdrant_points_total
# - qdrant_searches_total
# - qdrant_index_updates_total
# - process_resident_memory_bytes
# - disk_free_bytes
```

### Performance Profiling

```bash
# Check query performance
curl -X POST http://qdrant.railway.internal:6333/collections/{name}/points/search \
  -d '{
    "vector": [...],
    "limit": 10,
    "with_payload": false
  }' -w "\n\nTime: %{time_total}s\n"
```

---

## Getting Additional Help

If these solutions don't resolve your issue:

1. **Check Railway Status**: https://status.railway.app
2. **Review Qdrant Docs**: https://qdrant.tech/documentation/
3. **Qdrant Discord**: https://discord.gg/qdrant
4. **Railway Discord**: https://discord.gg/railway

When asking for help, include:
- Railway logs (last 100 lines)
- Environment variables (redact sensitive values)
- Collection configuration
- Error messages with full stack trace
- Steps to reproduce the issue
