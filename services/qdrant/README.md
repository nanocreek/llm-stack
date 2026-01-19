# Qdrant Vector Database Service

Production-grade Qdrant vector database optimized for Railway deployment. Serves as the primary vector storage backend for R2R (Retrieval-Augmented Generation) and other AI applications.

## Overview

**Qdrant** is a high-performance, open-source vector database designed for fast similarity search operations on high-dimensional vectors, making it ideal for RAG and AI-powered applications.

### Key Features

- 🚀 Fast similarity search on high-dimensional vectors
- 📦 Multi-tenancy with collections
- 💾 Persistent storage with automatic snapshots
- 🔐 API authentication for security
- 🌐 RESTful API (HTTP) on port 6333
- ⚡ gRPC API on port 6334 for high-performance clients
- 💪 Built-in health checks and monitoring
- 📊 Metrics endpoint for observability

## Railway Deployment

### Quick Setup

This service is designed to deploy as part of the parent [`llm-stack`](../../README.md) Railway template. For standalone deployment:

1. Fork this repository
2. Create new Railway service from GitHub repo
3. Set root directory: `services/qdrant`
4. Configure environment variables (see below)
5. Deploy

### Configuration

#### Essential Environment Variables

```bash
# Security (REQUIRED for production)
QDRANT_API_KEY=your-secure-api-key  # Generate: openssl rand -base64 32

# Ports (default values work for Railway)
QDRANT__SERVICE__HTTP_PORT=6333
QDRANT__SERVICE__GRPC_PORT=6334

# Snapshots (recommended for production)
QDRANT__SNAPSHOTS__ENABLED=true
QDRANT__SNAPSHOTS__SNAPSHOT_INTERVAL=600  # 10 minutes
QDRANT__SNAPSHOTS__MAX_SNAPSHOTS_TO_KEEP=5

# Logging
QDRANT__LOG_LEVEL=info
```

#### Advanced Configuration

| Variable | Default | Description | Production Recommendation |
|----------|---------|-------------|---------------------------|
| `QDRANT__STORAGE__FLUSH_INTERVAL_MS` | 5000 | Data persistence interval (ms) | 5000 |
| `QDRANT__PERFORMANCE__INDEX_THREADS` | 0 (auto) | Indexing thread count | 0 (auto-detect) |
| `QDRANT__PERFORMANCE__VECTOR_CACHE_SIZE_GB` | 0 (disabled) | Cache for frequently accessed vectors | 1-2 for large collections |

### Port Information

- **HTTP API**: 6333 - RESTful API access
- **gRPC**: 6334 - High-performance client connections
- **Internal DNS**: `qdrant.railway.internal:6333` (HTTP)
- **Internal DNS**: `qdrant.railway.internal:6334` (gRPC)

### Health Checks

Railway monitors service health automatically:
- **Endpoint**: `/readyz` - True readiness probe
- **Timeout**: 10 seconds
- **Interval**: 30 seconds
- **Start Period**: 60 seconds (initialization grace period)
- **Failure Threshold**: 3 consecutive failures

### Resource Recommendations

| Workload | CPU | Memory | Storage | Use Case |
|----------|-----|--------|---------|----------|
| **Development** | 0.5 | 512 MB | 10 GB | Testing, small datasets |
| **Small Production** | 1 | 2 GB | 50 GB | <100K vectors |
| **Medium Production** | 2 | 4 GB | 200 GB | 100K-1M vectors |
| **Large Production** | 4+ | 8+ GB | 500+ GB | >1M vectors |

## Usage

### Connecting from Other Services

#### Python

```python
from qdrant_client import QdrantClient

client = QdrantClient(
    url="http://qdrant.railway.internal:6333",
    api_key=os.getenv("QDRANT_API_KEY")
)

# List collections
collections = client.get_collections()
```

#### JavaScript/TypeScript

```typescript
import { QdrantClient } from "@qdrant/js-client-rest";

const client = new QdrantClient({
  url: "http://qdrant.railway.internal:6333",
  apiKey: process.env.QDRANT_API_KEY,
});

// Search vectors
const results = await client.search("collection_name", {
  vector: [0.1, 0.2, 0.3, ...],
  limit: 10,
});
```

#### REST API

```bash
# Create collection
curl -X PUT http://qdrant.railway.internal:6333/collections/my_collection \
  -H "api-key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "vectors": {
      "size": 384,
      "distance": "Cosine"
    }
  }'

# Insert vectors
curl -X PUT http://qdrant.railway.internal:6333/collections/my_collection/points \
  -H "api-key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "points": [
      {
        "id": 1,
        "vector": [0.1, 0.2, 0.3, ...],
        "payload": {"text": "example"}
      }
    ]
  }'

# Search vectors
curl -X POST http://qdrant.railway.internal:6333/collections/my_collection/points/search \
  -H "api-key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "vector": [0.1, 0.2, 0.3, ...],
    "limit": 10
  }'
```

### Accessing Qdrant Dashboard

Qdrant provides a web UI for managing collections:
- **Railway**: https://[your-qdrant-service-url]/dashboard
- **Local**: http://localhost:6333/dashboard

## Data Persistence

### Volume Configuration

Railway automatically handles data persistence through volumes mounted at:
```
/qdrant/storage/
```

All vector data and collections persist across service restarts.

### Snapshots

Automatic snapshots are created based on configuration:
```
/qdrant/snapshots/
```

**Manual snapshot creation**:
```bash
curl -X POST http://qdrant.railway.internal:6333/snapshots \
  -H "api-key: YOUR_API_KEY"
```

## Performance Optimization

### For Large Collections (>100K vectors)

```bash
# Increase indexing performance
QDRANT__PERFORMANCE__INDEX_THREADS=4

# Enable vector caching
QDRANT__PERFORMANCE__VECTOR_CACHE_SIZE_GB=2

# Faster writes (more frequent flushes)
QDRANT__STORAGE__FLUSH_INTERVAL_MS=2000
```

### Memory Optimization

Use quantization to reduce memory usage by ~75%:

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

### Best Practices

1. **Batch Operations**: Upload vectors in batches of 1000-10000 for 100x better performance
2. **API Key**: Always set `QDRANT_API_KEY` in production
3. **Snapshots**: Enable automatic snapshots for data protection
4. **Monitoring**: Use `/metrics` endpoint for Prometheus-compatible metrics
5. **Resource Planning**: Provision 2GB memory per 500K vectors as baseline

## Local Development

### Using Docker

```bash
# Quick start (matches Railway configuration)
docker run -p 6333:6333 \
  -e QDRANT_API_KEY=test-key-123 \
  -v qdrant_storage:/qdrant/storage \
  qdrant/qdrant:v1.13.1

# Access dashboard
open http://localhost:6333/dashboard
```

### Health Check Testing

```bash
# Test readiness
curl http://localhost:6333/readyz
# Expected: 200 OK

# Test health with details
curl http://localhost:6333/health
# Expected: 200 OK with JSON health details
```

## Monitoring

### Key Endpoints

```bash
# Overall health
curl http://qdrant.railway.internal:6333/health

# Readiness probe (used by Railway)
curl http://qdrant.railway.internal:6333/readyz

# Prometheus metrics
curl http://qdrant.railway.internal:6333/metrics

# Collection statistics
curl -H "api-key: YOUR_API_KEY" \
  http://qdrant.railway.internal:6333/collections
```

### Key Metrics to Monitor

1. **Health Check Success Rate**: Target 99.9%+
2. **Query Latency (p95)**: 
   - Small collections: <100ms
   - Large collections: <500ms
3. **Memory Usage**: Keep <75% of allocated memory
4. **Disk Usage**: Alert at 80% capacity
5. **Indexing Speed**: 10K+ points/second

### Railway Alerts

Configure in Railway Dashboard → Qdrant Service → Settings:
- Health check failures
- CPU > 80% for 1 minute
- Memory > 85% for 2 minutes
- More than 3 restarts per hour

## Service Dependencies

**None** - Qdrant is a standalone service with no external dependencies.

**Consumed by**:
- **R2R Service** - Uses Qdrant for vector storage and retrieval
- **Other services** - Any service needing vector similarity search

## Troubleshooting

For common issues and solutions, see [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md).

**Quick diagnostics**:
```bash
# Check health
curl http://qdrant.railway.internal:6333/readyz

# Check metrics
curl http://qdrant.railway.internal:6333/metrics

# View logs (Railway Dashboard)
Railway → Qdrant Service → Logs
```

**Common issues**:
- Connection refused → Check service is running and DNS name is correct
- 401 Unauthorized → Verify `QDRANT_API_KEY` matches in client and server
- Slow queries → See [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) for performance tuning
- Out of storage → See [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) for storage management

## Additional Resources

- **Quick Start Guide**: See [`QUICK_START.md`](QUICK_START.md) for fast setup
- **Troubleshooting**: See [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) for detailed issue resolution
- **Qdrant Documentation**: https://qdrant.tech/documentation/
- **Qdrant API Reference**: https://api.qdrant.tech/api-reference
- **Railway Volumes**: https://docs.railway.app/reference/volumes

## Version Information

- **Qdrant Version**: v1.13.1 (pinned for stability)
- **Base Image**: `qdrant/qdrant:v1.13.1`
- **Image Size**: ~500 MB
- **Architecture**: Multi-arch (AMD64, ARM64)

### Why Pinned Versions?

Using `latest` can cause unexpected breaking changes. A pinned version ensures:
- ✅ Consistent deployments
- ✅ No surprise breaking changes
- ✅ Controlled testing before upgrades
- ✅ Easy rollback if needed

## License

Qdrant is distributed under the AGPL-3.0 license. See the [Qdrant repository](https://github.com/qdrant/qdrant) for details.
