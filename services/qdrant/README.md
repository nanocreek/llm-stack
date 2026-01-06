# Qdrant Vector Database Service

This service provides a Qdrant vector database for the Railway template stack. It serves as the primary vector storage backend for the R2R (Retrieval-Augmented Generation) service.

## Service Overview

**Qdrant** is a high-performance, open-source vector database designed for fast similarity search operations. It's optimized for managing and searching high-dimensional vectors, making it ideal for RAG (Retrieval-Augmented Generation) applications.

### Key Features
- Fast similarity search on high-dimensional vectors
- Multi-tenancy with collections
- Persistent storage with snapshots
- RESTful API on port 6333
- Built-in health checks and monitoring

## Configuration

### Port Information
- **Internal Port**: 6333 (HTTP/gRPC)
- **Internal DNS**: `qdrant.railway.internal:6333`
- **Protocol**: HTTP and gRPC

### Health Check
- **Endpoint**: `/health` (dedicated health check endpoint)
- **Timeout**: 100 seconds
- **Interval**: 30 seconds
- **Start Period**: 40 seconds

## Environment Variables

The following environment variables can be configured in your Railway deployment:

| Variable | Description | Default | Optional |
|----------|-------------|---------|----------|
| `QDRANT_API_KEY` | Secure API key for database access | None | Yes |
| `QDRANT_STORAGE_PATH` | Path where vector data is stored | `/qdrant/storage` | Yes |
| `QDRANT_READ_ONLY_MODE` | Run database in read-only mode | `false` | Yes |
| `QDRANT_SNAPSHOT_PATH` | Path for automatic snapshots | `/qdrant/snapshots` | Yes |
| `QDRANT_ENABLE_COLLECTION_SNAPSHOTS` | Enable automatic collection snapshots | `true` | Yes |
| `QDRANT_LOG_LEVEL` | Logging verbosity (trace, debug, info, warn, error) | `info` | Yes |
| `QDRANT_MAX_MEMORY` | Maximum memory allocation (MB) | Unlimited | Yes |
| `QDRANT_INDEXING_THREADS` | Number of background indexing threads | 0 (auto) | Yes |

## Docker Image

- **Base Image**: `qdrant/qdrant:latest`
- **Size**: ~500 MB
- **Architecture**: Supports both AMD64 and ARM64

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

## Local Development

### Running Qdrant Locally

To test this service locally before deploying to Railway:

```bash
# Using Docker Compose
docker-compose up qdrant

# Or directly with Docker
docker run -p 6333:6333 \
  -v qdrant_storage:/qdrant/storage \
  qdrant/qdrant:latest
```

### Testing Health Check

```bash
curl http://localhost:6333/
# Expected response: 200 OK
```

### Accessing Qdrant Dashboard

Qdrant provides a web UI for managing collections:

- **Local**: http://localhost:6333/dashboard
- **Railway**: https://[your-qdrant-service-url]/dashboard

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

## Troubleshooting

### Connection Issues

If R2R or other services can't connect:

1. Verify the internal DNS name: `qdrant.railway.internal:6333`
2. Check service health: `curl http://qdrant.railway.internal:6333/health`
3. Review Railway service logs for errors
4. Ensure Qdrant pod is running (status should be "Active")

### Performance Issues

1. Check memory allocation: `curl http://qdrant.railway.internal:6333/metrics`
2. Monitor indexing progress for large uploads
3. Consider increasing Railway service resources if hitting limits
4. Reduce vector dimensions if possible for faster operations

### Storage Issues

1. Check available disk space in Railway volumes
2. Review snapshots for old backups that can be deleted
3. Consider archiving older collections
4. Monitor growth rate of collection sizes

### API Issues

1. Verify API key if configured (check Railway environment variables)
2. Ensure correct collection name in requests
3. Verify vector dimensions match collection definition
4. Check request format against Qdrant API documentation

## Monitoring

### Health Status
```bash
curl http://qdrant.railway.internal:6333/health
```

### Metrics
```bash
curl http://qdrant.railway.internal:6333/metrics
```

### Collection Info
```bash
curl http://qdrant.railway.internal:6333/collections
```

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
