# Qdrant Vector Database Service - Production Ready

This service provides a production-grade Qdrant vector database deployment optimized for Railway. It serves as the primary vector storage backend for the R2R (Retrieval-Augmented Generation) service and other AI applications.

## Service Overview

**Qdrant** is a high-performance, open-source vector database designed for fast similarity search operations. It's optimized for managing and searching high-dimensional vectors, making it ideal for RAG (Retrieval-Augmented Generation) and AI-powered applications.

### Key Features
- 🚀 Fast similarity search on high-dimensional vectors
- 📦 Multi-tenancy with collections
- 💾 Persistent storage with automatic snapshots
- 🔐 API authentication for security
- 🌐 RESTful API (HTTP) on port 6333
- ⚡ gRPC API on port 6334 for high-performance clients
- 💪 Built-in health checks and comprehensive monitoring
- 📊 Metrics endpoint for observability
- 🔄 Automatic recovery with intelligent restart policies

## Railway-Optimized Configuration

### Deployment Strategy
This Qdrant deployment is optimized for Railway with:
- **Pinned Docker image** (v1.13.1) - No breaking changes from `latest`
- **Intelligent health checks** - Uses `/readyz` readiness probe
- **Restart policies** - Automatic recovery with exponential backoff
- **Volume-backed storage** - Data persists across restarts
- **Security by default** - API key support for authentication

### Port Information
- **HTTP API Port**: 6333 - RESTful API access
- **gRPC Port**: 6334 - High-performance client connections
- **Internal DNS**: `qdrant.railway.internal:6333` (HTTP)
- **Internal DNS**: `qdrant.railway.internal:6334` (gRPC)

### Health Check Configuration
Railway monitors service health with:
- **Endpoint**: `/readyz` - Readiness probe (true ready state)
- **Timeout**: 10 seconds - Sufficient for response time
- **Interval**: 30 seconds - Regular health monitoring
- **Start Period**: 60 seconds - Grace period for initialization
- **Failure Threshold**: 3 consecutive failures mark unhealthy
- **Success Threshold**: 1 success marks healthy again

## Critical Configuration for Production

### Security - API Key (REQUIRED for Production)
```bash
QDRANT_API_KEY=sk-your-secure-32-character-key-here
```
Generate with: `openssl rand -base64 32`

**Why it matters**: Without an API key, anyone with network access can read/modify your vectors. Always set this in production.

### Environment Variables

| Variable | Description | Default | Production Recommended |
|----------|-------------|---------|----------------------|
| **QDRANT__SERVICE__HTTP_PORT** | HTTP API port | 6333 | 6333 |
| **QDRANT__SERVICE__GRPC_PORT** | gRPC API port | 6334 | 6334 |
| **QDRANT_API_KEY** | Secure database access key | None | Required (32+ chars) |
| **QDRANT__STORAGE__FLUSH_INTERVAL_MS** | Data persistence interval | 5000 | 5000 (DFS-backed volumes) |
| **QDRANT__SNAPSHOTS__ENABLED** | Auto snapshot creation | true | true |
| **QDRANT__SNAPSHOTS__SNAPSHOT_INTERVAL** | Snapshot frequency (seconds) | 600 | 600 |
| **QDRANT__SNAPSHOTS__MAX_SNAPSHOTS_TO_KEEP** | Retained snapshots | 3 | 5 (safety margin) |
| **QDRANT__LOG_LEVEL** | Logging verbosity | info | info |
| **QDRANT__PERFORMANCE__INDEX_THREADS** | Indexing thread count | 0 (auto) | 0 (auto-detect) |

### Advanced Configuration

#### Snapshot Management
```bash
# Enable automatic backups
QDRANT__SNAPSHOTS__ENABLED=true
QDRANT__SNAPSHOTS__SNAPSHOT_INTERVAL=600  # 10 minutes
QDRANT__SNAPSHOTS__MAX_SNAPSHOTS_TO_KEEP=5
```

#### Memory & Performance
```bash
# Increase if you have large collections (>1M vectors)
QDRANT__PERFORMANCE__INDEX_THREADS=8

# Cache for frequently accessed vectors (default: disabled)
QDRANT__PERFORMANCE__VECTOR_CACHE_SIZE_GB=1
```

#### Write-Ahead Log (WAL)
```bash
# Balance between durability and performance
QDRANT__STORAGE__FLUSH_INTERVAL_MS=5000  # 5 seconds
QDRANT__STORAGE__WAL_SEGMENT_SIZE_BYTES=33554432
```

## Docker Image Strategy

- **Base Image**: `qdrant/qdrant:v1.13.1` (pinned for reproducibility)
- **Size**: ~500 MB
- **Architecture**: Multi-arch support (AMD64, ARM64)
- **Rationale**: Pinned version ensures stable deployments without breaking changes from `latest`

### Why Pinned Versions Matter
Using `latest` can cause unexpected upgrades. A pinned version:
- ✅ Ensures consistent deployments
- ✅ Prevents breaking changes
- ✅ Allows controlled testing before upgrades
- ✅ Enables rollback if needed

## Connection from Other Services

### From R2R Service

The R2R service connects to Qdrant using the internal Railway DNS:

```python
# Example Python client
from qdrant_client import QdrantClient

client = QdrantClient(
    url="http://qdrant.railway.internal:6333",
    api_key=os.getenv("QDRANT_API_KEY")  # Optional if configured
)

# List collections
collections = client.get_collections()
```

### From Node.js/TypeScript

```typescript
import { QdrantClient } from "@qdrant/js-client-rest";

const client = new QdrantClient({
  url: "http://qdrant.railway.internal:6333",
  apiKey: process.env.QDRANT_API_KEY,
});

// Perform vector search
const searchResults = await client.search("collection_name", {
  vector: [0.1, 0.2, 0.3],
  limit: 10,
});
```

## Collections and Data Management

### Creating Collections

Collections are the main organizational unit in Qdrant. They contain vectors with associated metadata.

```bash
curl -X PUT "http://qdrant.railway.internal:6333/collections/my_collection" \
  -H "Content-Type: application/json" \
  -d '{
    "vectors": {
      "size": 384,
      "distance": "Cosine"
    }
  }'
```

### Uploading Vectors

```bash
curl -X PUT "http://qdrant.railway.internal:6333/collections/my_collection/points" \
  -H "Content-Type: application/json" \
  -d '{
    "points": [
      {
        "id": 1,
        "vector": [0.1, 0.2, 0.3],
        "payload": {"text": "example"}
      }
    ]
  }'
```

## Railway Deployment Best Practices

### 🔐 Security Configuration Checklist
- [ ] **Set API Key**: Generate and configure `QDRANT_API_KEY` in Railway dashboard
- [ ] **Restrict Access**: Only expose HTTP/gRPC ports to services that need them
- [ ] **Monitor Logs**: Regularly review service logs for unauthorized access attempts
- [ ] **Use HTTPS**: Access Qdrant through Railway's managed domains with TLS
- [ ] **Rotate Keys**: Change API keys every 90 days

### 💾 Data Management Checklist
- [ ] **Enable Snapshots**: Ensure `QDRANT__SNAPSHOTS__ENABLED=true`
- [ ] **Configure Volume**: Attach Railway volume to `/qdrant/storage` for persistence
- [ ] **Monitor Storage**: Set up alerts for disk space usage
- [ ] **Test Backups**: Periodically test snapshot restore procedures
- [ ] **Archive Old Data**: Implement TTL policies for stale vectors

### ⚙️ Resource Allocation
| Workload | CPU | Memory | Storage | Notes |
|----------|-----|--------|---------|-------|
| **Development** | 0.5 | 512 MB | 10 GB | Light testing |
| **Production (Small)** | 1 | 2 GB | 50 GB | <100K vectors |
| **Production (Medium)** | 2 | 4 GB | 200 GB | 100K-1M vectors |
| **Production (Large)** | 4+ | 8+ GB | 500+ GB | >1M vectors |

### 🚀 Performance Tuning for Railway
```bash
# For collections with millions of vectors
QDRANT__PERFORMANCE__INDEX_THREADS=4
QDRANT__PERFORMANCE__VECTOR_CACHE_SIZE_GB=2

# For high-throughput applications
QDRANT__STORAGE__FLUSH_INTERVAL_MS=2000  # More frequent commits

# For cost optimization
QDRANT__STORAGE__FLUSH_INTERVAL_MS=10000  # Less frequent I/O
```

## Local Development

### Running Qdrant Locally

To test this service locally before deploying to Railway:

```bash
# Using Docker Compose
docker-compose up qdrant

# Or directly with Docker (recommended pinned version)
docker run -p 6333:6333 \
  -v qdrant_storage:/qdrant/storage \
  qdrant/qdrant:v1.13.1
```

### Testing Health Check

```bash
# Test HTTP readiness
curl http://localhost:6333/readyz
# Expected response: 200 OK

# Test overall health
curl http://localhost:6333/health
# Expected response: 200 OK with health details
```

### Accessing Qdrant Dashboard

Qdrant provides a web UI for managing collections:

- **Local**: http://localhost:6333/dashboard
- **Railway**: https://[your-qdrant-service-url]/dashboard

### Simulating Railway Environment Locally
```bash
# Use the same pinned version as production
docker run -p 6333:6333 \
  -e QDRANT_API_KEY=test-key-123 \
  -e QDRANT__LOG_LEVEL=info \
  -v qdrant_storage:/qdrant/storage \
  qdrant/qdrant:v1.13.1
```

## Data Persistence

### Volume Configuration

Railway automatically handles data persistence through volumes. Your vector data is stored in:

```
/qdrant/storage/
```

This directory is automatically managed by Railway and persists across service restarts.

### Snapshots

Qdrant automatically creates snapshots of your collections. Snapshots are stored in:

```
/qdrant/snapshots/
```

To create a manual snapshot:

```bash
curl -X POST "http://qdrant.railway.internal:6333/snapshots"
```

## Service Dependencies

**None** - Qdrant is a standalone service with no external dependencies.

This service is consumed by:
- **R2R Service** - Uses Qdrant for vector storage and retrieval

## Performance Considerations

### Memory Usage
- Minimum recommended: 512 MB
- Production recommended: 2-4 GB
- Scales with collection size and indexing operations

### Indexing Strategy
- Use HNSW (Hierarchical Navigable Small World) for balanced performance
- Configure appropriate vector quantization for large collections
- Enable caching for frequently accessed vectors

### Optimization Tips
1. **Batch Uploads**: Upload vectors in batches of 1000-10000 for better performance
2. **Index Selection**: Choose appropriate distance metrics (Cosine, Euclidean, Manhattan)
3. **Quantization**: Enable scalar or product quantization for large collections
4. **TTL Management**: Set time-to-live on older vectors to maintain database size

## Troubleshooting Guide

### Connection Issues

**Symptom**: Services can't connect to Qdrant

**Solutions**:
1. Verify the internal DNS name: `qdrant.railway.internal:6333`
2. Check service health:
   ```bash
   curl -i http://qdrant.railway.internal:6333/readyz
   ```
3. If API key is configured:
   ```bash
   curl -H "api-key: YOUR_API_KEY" http://qdrant.railway.internal:6333/health
   ```
4. Review Railway service logs for startup errors
5. Ensure Qdrant volume is properly mounted and has space
6. Check Railway project networking settings

### Health Check Failures

**Symptom**: Service shows "Unhealthy" in Railway dashboard

**Solutions**:
1. SSH into Railway container and check logs:
   ```bash
   Railway Logs → Search for "health" or "readyz"
   ```
2. Test health endpoint manually with increased timeout:
   ```bash
   curl --max-time 30 http://qdrant.railway.internal:6333/readyz
   ```
3. Check if service is still initializing (wait 60+ seconds)
4. Verify sufficient disk space:
   ```bash
   curl http://qdrant.railway.internal:6333/metrics | grep storage
   ```
5. Increase Railway resource limits if hitting memory/CPU caps

### Performance Issues

**Symptom**: Slow search queries, high latency

**Solutions**:
1. Check memory allocation:
   ```bash
   curl http://qdrant.railway.internal:6333/metrics
   # Look for memory_available_bytes vs memory_usage_bytes
   ```
2. Monitor indexing progress for large uploads
3. Scale up Railway service resources:
   - Increase Memory (aim for 2GB+ production)
   - Increase CPU (more threads = faster indexing)
4. Optimize vector operations:
   - Reduce vector dimensions if possible
   - Use `payload_values_count` to limit metadata
   - Enable quantization for large collections

5. Check for slow queries in logs:
   ```
   Railway Logs → Search for "took" or "slow"
   ```

### Storage Issues

**Symptom**: Out of disk space or slow writes

**Solutions**:
1. Check disk usage:
   ```bash
   curl http://qdrant.railway.internal:6333/collections
   # Sum up points_count × vector_size_mb for estimate
   ```
2. Review snapshots and delete old ones:
   ```bash
   curl http://qdrant.railway.internal:6333/snapshots
   curl -X DELETE http://qdrant.railway.internal:6333/snapshots/{snapshot_name}
   ```
3. Implement TTL policies for stale vectors:
   ```bash
   # Delete vectors older than 90 days
   curl -X POST http://qdrant.railway.internal:6333/collections/{name}/points/delete \
     -H "Content-Type: application/json" \
     -d '{
       "filter": {
         "range": {
           "timestamp": {
             "lt": "NOW-90d"
           }
         }
       }
     }'
   ```
4. Archive older collections to separate storage
5. Increase Railway volume size if needed

### API Authentication Issues

**Symptom**: 401 Unauthorized errors

**Solutions**:
1. Verify `QDRANT_API_KEY` is set in Railway dashboard
2. Include API key in all requests:
   ```bash
   curl -H "api-key: $QDRANT_API_KEY" http://qdrant.railway.internal:6333/health
   ```
3. Check that API key doesn't have trailing spaces
4. Rotate API key if suspected compromise:
   ```
   1. Generate new key: openssl rand -base64 32
   2. Update in Railway dashboard
   3. Restart Qdrant service
   4. Update all client configurations
   ```
5. For clients, ensure they pass API key in headers or URL params

### Collection/Vector Issues

**Symptom**: Collection not found, vector dimensions don't match

**Solutions**:
1. List existing collections:
   ```bash
   curl http://qdrant.railway.internal:6333/collections
   ```
2. Check collection schema:
   ```bash
   curl http://qdrant.railway.internal:6333/collections/{collection_name}
   ```
3. Verify vector dimensions in your client match collection definition
4. Check request format against Qdrant API docs
5. For batch operations, ensure all vectors have same dimension

## Production Monitoring

### Key Metrics to Monitor

1. **Health Check Success Rate**
   - Target: 99.9%+
   - Action: Investigate any failures

2. **Query Latency (p95)**
   - Target: < 100ms for small collections
   - Target: < 500ms for large collections
   - Action: Increase memory/CPU if exceeding

3. **Indexing Speed**
   - Target: 10K+ points/second
   - Action: Check CPU usage, increase threads

4. **Disk Usage Growth**
   - Monitor: Collection size trend
   - Action: Implement archival/TTL before reaching 80% capacity

5. **Memory Usage**
   - Target: < 75% allocated memory
   - Action: Scale up before hitting limits

### Monitoring Endpoints

```bash
# Overall health
curl http://qdrant.railway.internal:6333/health

# Readiness probe
curl http://qdrant.railway.internal:6333/readyz

# Prometheus-compatible metrics
curl http://qdrant.railway.internal:6333/metrics

# Collection statistics
curl http://qdrant.railway.internal:6333/collections

# Specific collection details
curl http://qdrant.railway.internal:6333/collections/{collection_name}
```

### Setting Up Alerts in Railway

1. Go to Railway service → Settings
2. Create alerts for:
   - Health check failures
   - CPU > 80% (1 minute)
   - Memory > 85% (2 minutes)
   - Restarts > 3 (per hour)

## References

- [Qdrant Official Documentation](https://qdrant.tech/documentation/)
- [Qdrant API Reference](https://api.qdrant.tech/api-reference)
- [Qdrant Python Client](https://github.com/qdrant/qdrant-client)
- [Railway Volumes Documentation](https://docs.railway.app/reference/volumes)

## Docker Build

To rebuild the image locally:

```bash
docker build -t qdrant-railway .
docker run -p 6333:6333 qdrant-railway
```

## License

Qdrant is distributed under the AGPL-3.0 license. For more information, see the [Qdrant repository](https://github.com/qdrant/qdrant).
