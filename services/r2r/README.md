# R2R (RAG Framework) Service

This service deploys the R2R (RAG framework) as part of the Railway template. R2R provides a Retrieval-Augmented Generation framework for managing documents and generating responses powered by LLMs.

## Service Details

- **Port**: 7272
- **Internal DNS**: `r2r.railway.internal:7272`
- **Health Check**: `/v3/health` endpoint (with `/health` fallback)
- **Restart Policy**: `ON_FAILURE`
- **R2R Version**: 3.x (latest)

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
- **Symptom**: Service deploys successfully but health checks continuously fail with "service unavailable"
- **Root Causes**:
  1. R2R v3.x uses `/v3/health` endpoint instead of `/health` - fixed in `railway.toml`
  2. R2R needs proper configuration file to connect to PostgreSQL and Qdrant
  3. R2R requires specific environment variable format (e.g., `POSTGRES_HOST` not `R2R_POSTGRES_HOST` internally)
- **Solution**: 
  - The Dockerfile now creates a proper `r2r.json` configuration file
  - Startup script exports environment variables in R2R's expected format
  - Health check tries both `/v3/health` and `/health` endpoints
  - Extended start period (120s) allows time for database connections

**Missing Configuration File**:
- **Symptom**: R2R server fails to start or crashes immediately
- **Solution**: The Dockerfile automatically creates `/app/config/r2r.json` with:
  - Database provider: postgres
  - Vector database provider: qdrant
  - Completions provider: litellm (for LLM integration)

**Environment Variable Mapping**:
- R2R internally uses different variable names than Railway provides
- The startup script now maps:
  - `R2R_POSTGRES_HOST` → `POSTGRES_HOST`
  - `R2R_POSTGRES_PORT` → `POSTGRES_PORT`
  - `R2R_POSTGRES_USER` → `POSTGRES_USER`
  - `R2R_POSTGRES_PASSWORD` → `POSTGRES_PASSWORD`
  - `R2R_POSTGRES_DBNAME` → `POSTGRES_DBNAME`
  - `R2R_QDRANT_HOST` → `QDRANT_HOST`
  - `R2R_QDRANT_PORT` → `QDRANT_PORT`

**Dependency Wait Issues**:
- The startup script now includes:
  - Bounded retry loops (30 attempts max) instead of infinite loops
  - Clear logging of connection attempts
  - Conditional checks (skips if environment variable not set)

**Wrong R2R Command**:
- The correct command is `python -m r2r.serve --host 0.0.0.0 --port 7272 --config-path /app/config/r2r.json`
- Must use dot notation: `python -m r2r.serve` (not `python -m r2r serve`)
- Must include `--config-path` for proper initialization

**Connection Refused**: 
- Ensure PostgreSQL, Qdrant, and Redis are running and accessible
- Use `qdrant.railway.internal` for Qdrant host (service-to-service communication)
- Use Railway service references for PostgreSQL and Redis
- Check startup logs for "PostgreSQL is ready!" and "Qdrant is ready!" messages

**Port Already in Use**: 
- Ensure port 7272 is not in use by another service

**Container Keeps Restarting**:
- Check that PostgreSQL and Qdrant are fully initialized before R2R starts
- Review Railway logs for specific error messages
- Look for startup script output (should see configuration details and dependency checks)
- Increase restart policy max retries if needed (currently set to 10)

### Recent Fixes (January 2026)

**Issue**: R2R service builds successfully but healthcheck continuously fails. No startup logs visible in Railway logs.

**Root Cause**:
1. Complex startup script embedded in Dockerfile using RUN command was not executing properly
2. Script had no error output or debugging information
3. Railway's PORT variable not being respected
4. Config file generation happening at build time rather than runtime

**Solution Applied**:
1. **Separated startup script**: Moved from inline RUN command to dedicated [`start.sh`](start.sh:1) file
2. **Enhanced logging**: Added comprehensive startup logging showing:
   - Environment variables being used
   - Dependency wait status (PostgreSQL, Qdrant)
   - Configuration file creation
   - Server startup command
3. **Railway PORT support**: Script now uses `${PORT}` first, then falls back to `${R2R_PORT}` or default 7272
4. **Runtime config generation**: Config file now created at startup, allowing dynamic configuration
5. **Better healthcheck**: Changed from `/v3/health` to `/health` as primary endpoint
6. **LiteLLM integration**: Added LiteLLM URL configuration for completions provider

**Verification Steps**:
1. Check Railway logs for startup messages starting with "========================================="
2. Verify you see "✓ PostgreSQL is ready!" and "✓ Qdrant is ready!"
3. Look for "Starting R2R server..." followed by the r2r serve command
4. Healthcheck should pass within 2 minutes of dependencies being ready

If you still see issues, check:
- PostgreSQL plugin is provisioned and healthy
- Qdrant service is running and accessible at `qdrant.railway.internal:6333`
- All environment variables are correctly set in `.env.railway`
