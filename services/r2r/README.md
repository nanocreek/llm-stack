# R2R (RAG Framework) Service

Production-ready R2R (Retrieval-Augmented Generation) framework optimized for Railway deployment. Provides document management and AI-powered search capabilities.

## Overview

**R2R** is a comprehensive RAG framework that combines vector search, document processing, and LLM integration for building intelligent question-answering systems.

### Key Features

- 📄 Document ingestion and processing
- 🔍 Vector-based similarity search via Qdrant
- 🤖 LLM integration via LiteLLM
- 💾 PostgreSQL for metadata and document storage
- ⚡ Redis for caching and session management
- 🌐 RESTful API on port 7272

## Service Configuration

- **Port**: 7272
- **Internal DNS**: `r2r.railway.internal:7272`
- **Health Check**: `/health` (primary) or `/v3/health` (fallback)
- **Restart Policy**: `ON_FAILURE` with 10 retries
- **R2R Version**: 3.x (latest)

## Railway Deployment

### Quick Setup

This service is designed to deploy as part of the parent [`llm-stack`](../../README.md) Railway template. It requires PostgreSQL, Qdrant, and Redis services.

### Environment Variables

The following variables are automatically configured by Railway:

| Variable | Source | Description |
|----------|--------|-------------|
| `R2R_HOST` | Default: `0.0.0.0` | Server host binding |
| `R2R_PORT` | Default: `7272` | Server port (Railway's `PORT` takes precedence) |
| `R2R_POSTGRES_HOST` | `${{Postgres.PGHOST}}` | PostgreSQL host |
| `R2R_POSTGRES_PORT` | `${{Postgres.PGPORT}}` | PostgreSQL port |
| `R2R_POSTGRES_USER` | `${{Postgres.PGUSER}}` | PostgreSQL user |
| `R2R_POSTGRES_PASSWORD` | `${{Postgres.PGPASSWORD}}` | PostgreSQL password |
| `R2R_POSTGRES_DBNAME` | `${{Postgres.PGDATABASE}}` | PostgreSQL database |
| `R2R_VECTOR_DB_PROVIDER` | Default: `qdrant` | Vector database provider |
| `R2R_QDRANT_HOST` | `qdrant.railway.internal` | Qdrant host |
| `R2R_QDRANT_PORT` | Default: `6333` | Qdrant port |
| `REDIS_URL` | `${{Redis.REDIS_URL}}` | Redis connection string |
| `LITELLM_URL` | `http://litellm.railway.internal:4000` | LiteLLM proxy URL |
| `R2R_LOG_LEVEL` | Default: `INFO` | Logging level |

## Service Dependencies

R2R requires these services to be running in your Railway project:

1. **PostgreSQL** - Document and metadata storage
   - pgvector extension is **NOT required** (see note below)
2. **Qdrant** - Vector embeddings and similarity search
3. **Redis** - Caching and session management
4. **LiteLLM** (optional) - LLM proxy for completions

### Important: pgvector Not Required

This deployment uses **Qdrant** for vector storage, so the pgvector PostgreSQL extension is not needed. PostgreSQL is used only for document and metadata storage.

**Why this matters**:
- Railway's managed PostgreSQL doesn't include pgvector by default
- R2R attempts to create the pgvector extension during startup
- Our deployment includes error suppression to handle this gracefully

For technical details about the pgvector workaround, see [`PGVECTOR_WORKAROUND.md`](PGVECTOR_WORKAROUND.md).

## Usage

### API Endpoints

Access R2R from other services using internal DNS:

```bash
# Health check
curl http://r2r.railway.internal:7272/health

# Document ingestion (example)
curl -X POST http://r2r.railway.internal:7272/v3/ingest \
  -H "Content-Type: application/json" \
  -d '{
    "document": {
      "text": "Your document content",
      "metadata": {"title": "Example"}
    }
  }'

# RAG query (example)
curl -X POST http://r2r.railway.internal:7272/v3/rag \
  -H "Content-Type: application/json" \
  -d '{"query": "What is this about?"}'
```

### Client Integration

#### Python

```python
from r2r import R2RClient

client = R2RClient(base_url="http://r2r.railway.internal:7272")

# Health check
health = client.health()

# Ingest document
client.ingest_documents([{
    "text": "Document content",
    "metadata": {"title": "Example"}
}])

# Query
results = client.rag("What is this about?")
```

#### JavaScript/TypeScript

```typescript
const baseUrl = "http://r2r.railway.internal:7272";

// Health check
const response = await fetch(`${baseUrl}/health`);
const health = await response.json();

// RAG query
const ragResponse = await fetch(`${baseUrl}/v3/rag`, {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({ query: "What is this about?" })
});
const results = await ragResponse.json();
```

## Local Development

### Using Docker Compose

```yaml
services:
  r2r:
    build: ./services/r2r
    ports:
      - "7272:7272"
    environment:
      R2R_HOST: 0.0.0.0
      R2R_PORT: 7272
      R2R_POSTGRES_HOST: postgres
      R2R_POSTGRES_PORT: 5432
      R2R_POSTGRES_USER: postgres
      R2R_POSTGRES_PASSWORD: postgres
      R2R_POSTGRES_DBNAME: r2r
      R2R_QDRANT_HOST: qdrant
      R2R_QDRANT_PORT: 6333
      REDIS_URL: redis://redis:6379
    depends_on:
      - postgres
      - qdrant
      - redis
```

### Direct Docker Run

```bash
docker build -t r2r-service services/r2r/
docker run -p 7272:7272 \
  -e R2R_POSTGRES_HOST=host.docker.internal \
  -e R2R_QDRANT_HOST=host.docker.internal \
  r2r-service
```

## Monitoring & Health

### Health Check Configuration

Railway monitors R2R with:
- **Primary endpoint**: `/health`
- **Fallback endpoint**: `/v3/health`
- **Interval**: Every 30 seconds
- **Timeout**: 5 seconds
- **Start Period**: 120 seconds (allows database initialization)
- **Failure Threshold**: 3 consecutive failures

### Startup Sequence

The service waits for dependencies before starting:

1. Wait for PostgreSQL (bounded retries: 30 attempts)
2. Wait for Qdrant readiness
3. Generate R2R configuration file
4. Apply pgvector error suppression wrapper
5. Start R2R server

You'll see startup logs like:
```
===== R2R STARTUP BEGIN =====
✓ PostgreSQL is ready!
✓ Qdrant is ready!
✓ Configuration file created
✓ Wrapper script created
⚠ pgvector extension creation failed (expected)
  Vector storage will use Qdrant
```

## Troubleshooting

### Health Check Failures

**Symptoms**:
- Service builds but health checks fail
- "Service unavailable" errors

**Solutions**:
1. Check R2R is using correct health endpoint (`/health`)
2. Verify all dependencies (PostgreSQL, Qdrant, Redis) are running
3. Review Railway logs for startup errors
4. Ensure 120-second start period hasn't expired
5. Check environment variables are correctly mapped

### Connection Refused

**Solutions**:
- Verify PostgreSQL, Qdrant, and Redis are accessible
- Use internal DNS: `qdrant.railway.internal`, not external URLs
- Check Railway service references are correctly set
- Look for "PostgreSQL is ready!" and "Qdrant is ready!" in logs

### Container Keeps Restarting

**Solutions**:
1. Review Railway logs for specific error messages
2. Check dependency wait logic (should show connection attempts)
3. Verify PostgreSQL credentials are correct
4. Ensure Qdrant is fully initialized before R2R starts
5. Check restart policy hasn't exceeded max retries (10)

### pgvector Extension Errors

If you see pgvector-related errors, this is **expected and normal**. The service includes error suppression that allows R2R to continue without pgvector since vector storage uses Qdrant.

For details, see [`PGVECTOR_WORKAROUND.md`](PGVECTOR_WORKAROUND.md).

## Configuration Files

The service automatically generates:

1. **`/app/config/r2r.json`** - R2R configuration
   - Database provider: postgres
   - Vector database: qdrant
   - Completions provider: litellm

2. **`/app/r2r_wrapper.py`** - pgvector error suppression
   - Patches PostgreSQL module at runtime
   - Catches and logs pgvector errors as warnings
   - Allows graceful continuation

## Performance Considerations

### Resource Requirements

- **Minimum**: 512 MB memory, 0.5 CPU
- **Recommended**: 1-2 GB memory, 1 CPU core
- Scales with document processing volume

### Optimization Tips

1. **Batch Processing**: Ingest documents in batches for better performance
2. **Redis Caching**: Ensure Redis is configured for faster repeated queries
3. **Qdrant Indexing**: Wait for vector indexing to complete before querying
4. **LiteLLM Configuration**: Optimize completion provider settings

## Additional Resources

- **pgvector Technical Details**: See [`PGVECTOR_WORKAROUND.md`](PGVECTOR_WORKAROUND.md)
- **R2R Documentation**: https://github.com/SciPhi-AI/R2R
- **Railway Deployment**: See parent [`README.md`](../../README.md)

## Version Information

- **R2R Version**: 3.x (latest from pip)
- **Base Image**: `python:3.11-slim`
- **Python**: 3.11

## License

R2R is open source. See the [R2R repository](https://github.com/SciPhi-AI/R2R) for license details.
