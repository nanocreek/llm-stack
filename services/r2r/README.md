# R2R (RAG Framework) Service

This service deploys the R2R (RAG framework) as part of the Railway template. R2R provides a Retrieval-Augmented Generation framework for managing documents and generating responses powered by LLMs.

## Service Details

- **Port**: 7272
- **Internal DNS**: `r2r.railway.internal:7272`
- **Health Check**: `/health` endpoint
- **Restart Policy**: `ON_FAILURE`

## Configuration

### Environment Variables

The service requires the following environment variables, which are automatically set by Railway:

| Variable | Source | Description |
|----------|--------|-------------|
| `R2R_HOST` | Default: `0.0.0.0` | R2R server host binding |
| `R2R_PORT` | Default: `7272` | R2R server port |
| `R2R_POSTGRES_HOST` | `${{Postgres.PGHOST}}` | PostgreSQL host |
| `R2R_POSTGRES_PORT` | `${{Postgres.PGPORT}}` | PostgreSQL port |
| `R2R_POSTGRES_USER` | `${{Postgres.PGUSER}}` | PostgreSQL username |
| `R2R_POSTGRES_PASSWORD` | `${{Postgres.PGPASSWORD}}` | PostgreSQL password |
| `R2R_POSTGRES_DBNAME` | `${{Postgres.PGDATABASE}}` | PostgreSQL database name |
| `R2R_VECTOR_DB_PROVIDER` | Default: `qdrant` | Vector database provider |
| `R2R_QDRANT_HOST` | `qdrant.railway.internal` | Qdrant host (service-to-service communication) |
| `R2R_QDRANT_PORT` | Default: `6333` | Qdrant port |
| `REDIS_URL` | `${{Redis.REDIS_URL}}` | Redis connection string |
| `R2R_LOG_LEVEL` | Default: `INFO` | Logging level (DEBUG, INFO, WARNING, ERROR) |

## Dependencies

R2R requires the following services to be running:

1. **PostgreSQL** - For document and metadata storage
2. **Qdrant** - For vector embeddings and similarity search
3. **Redis** - For caching and session management

## Dockerfile

The Dockerfile uses:
- `python:3.11-slim` base image for minimal size
- Installs system dependencies required by R2R (curl, git, build-essential, postgresql-client)
- Installs the R2R framework and uvicorn[standard] via pip
- Includes startup script with dependency wait logic for PostgreSQL and Qdrant
- Includes health check for automatic monitoring with extended timeout

## Service-to-Service Communication

From the React Client or other services, you can reach R2R using:
```
http://r2r.railway.internal:7272
```

Example API calls:
```bash
# Health check
curl http://r2r.railway.internal:7272/health

# RAG query endpoint (example)
curl -X POST http://r2r.railway.internal:7272/rag_query \
  -H "Content-Type: application/json" \
  -d '{"query": "your question"}'
```

## Health Checks

The service includes a health check that:
- Runs every 30 seconds
- Times out after 5 seconds
- Has a 10-second startup period
- Requires 3 consecutive failures to restart the container

## Local Development

To run locally with Docker Compose:

```yaml
services:
  r2r:
    build: ./services/r2r
    ports:
      - "7272:7272"
    environment:
      - R2R_HOST=0.0.0.0
      - R2R_PORT=7272
      - R2R_POSTGRES_HOST=postgres
      - R2R_POSTGRES_PORT=5432
      - R2R_POSTGRES_USER=postgres
      - R2R_POSTGRES_PASSWORD=postgres
      - R2R_POSTGRES_DBNAME=r2r
      - R2R_QDRANT_HOST=qdrant
      - R2R_QDRANT_PORT=6333
      - REDIS_URL=redis://redis:6379
    depends_on:
      - postgres
      - qdrant
      - redis
```

## Deployment on Railway

1. Ensure PostgreSQL, Redis, and Qdrant plugins/services are added to your Railway project
2. Add environment variables from `.env.example` to your R2R service
3. The `railway.toml` file automatically configures the build and deployment settings

## Troubleshooting

### Common Issues

**Health Check Failures**: 
- Verify that all required services (PostgreSQL, Qdrant, Redis) are running
- Check logs to verify environment variables are correctly set
- The startup script includes wait logic for dependencies - check logs for "waiting" messages
- Health check timeout is set to 300 seconds (5 minutes) to allow time for dependencies

**Wrong R2R Command**:
- The correct command is `r2r serve --host 0.0.0.0 --port 7272`
- Not `r2r --host 0.0.0.0 --port 7272` (missing `serve` subcommand)

**Connection Refused**: 
- Ensure PostgreSQL, Qdrant, and Redis are running and accessible
- Use `qdrant.railway.internal` for Qdrant host (service-to-service communication)
- Use Railway service references for PostgreSQL and Redis

**Port Already in Use**: 
- Ensure port 7272 is not in use by another service

**Container Keeps Restarting**:
- Check that PostgreSQL and Qdrant are fully initialized before R2R starts
- Review Railway logs for specific error messages
- Increase restart policy max retries if needed
