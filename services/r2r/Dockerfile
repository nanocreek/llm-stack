# R2R (RAG framework) service for Railway deployment
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    build-essential \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Install R2R framework with all dependencies
RUN pip install --no-cache-dir r2r uvicorn[standard]

# Create R2R configuration directory
RUN mkdir -p /app/config /app/data

# Create R2R configuration file
RUN echo '{\n\
  "app": {\n\
    "max_logs_per_request": 100\n\
  },\n\
  "completions": {\n\
    "provider": "litellm"\n\
  },\n\
  "database": {\n\
    "provider": "postgres"\n\
  },\n\
  "vector_database": {\n\
    "provider": "qdrant",\n\
    "collection_name": "r2r_default"\n\
  }\n\
}' > /app/config/r2r.json

# Create a startup script that handles R2R configuration and initialization
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
echo "Starting R2R server..."\n\
echo "R2R Configuration:"\n\
echo "  - PostgreSQL Host: ${R2R_POSTGRES_HOST}"\n\
echo "  - Qdrant Host: ${R2R_QDRANT_HOST}"\n\
echo "  - Port: ${R2R_PORT:-7272}"\n\
\n\
# Wait for PostgreSQL to be ready\n\
if [ ! -z "${R2R_POSTGRES_HOST}" ]; then\n\
  echo "Waiting for PostgreSQL..."\n\
  for i in {1..30}; do\n\
    if pg_isready -h ${R2R_POSTGRES_HOST} -p ${R2R_POSTGRES_PORT:-5432} -U ${R2R_POSTGRES_USER:-postgres} > /dev/null 2>&1; then\n\
      echo "PostgreSQL is ready!"\n\
      break\n\
    fi\n\
    echo "PostgreSQL is unavailable - attempt $i/30"\n\
    sleep 2\n\
  done\n\
fi\n\
\n\
# Wait for Qdrant to be ready\n\
if [ ! -z "${R2R_QDRANT_HOST}" ]; then\n\
  echo "Waiting for Qdrant..."\n\
  for i in {1..30}; do\n\
    if curl -f http://${R2R_QDRANT_HOST}:${R2R_QDRANT_PORT:-6333}/healthz > /dev/null 2>&1; then\n\
      echo "Qdrant is ready!"\n\
      break\n\
    fi\n\
    echo "Qdrant is unavailable - attempt $i/30"\n\
    sleep 2\n\
  done\n\
fi\n\
\n\
# Export R2R environment variables for database connections\n\
export R2R_PROJECT_NAME="${R2R_PROJECT_NAME:-r2r_default}"\n\
export POSTGRES_HOST="${R2R_POSTGRES_HOST}"\n\
export POSTGRES_PORT="${R2R_POSTGRES_PORT:-5432}"\n\
export POSTGRES_USER="${R2R_POSTGRES_USER}"\n\
export POSTGRES_PASSWORD="${R2R_POSTGRES_PASSWORD}"\n\
export POSTGRES_DBNAME="${R2R_POSTGRES_DBNAME:-postgres}"\n\
export QDRANT_HOST="${R2R_QDRANT_HOST}"\n\
export QDRANT_PORT="${R2R_QDRANT_PORT:-6333}"\n\
\n\
echo "Starting R2R server on ${R2R_HOST:-0.0.0.0}:${R2R_PORT:-7272}"\n\
\n\
# Start R2R server with explicit configuration\n\
exec r2r serve --host ${R2R_HOST:-0.0.0.0} --port ${R2R_PORT:-7272} --config-path /app/config/r2r.json' > /app/start.sh && \
    chmod +x /app/start.sh

# Expose port 7272
EXPOSE 7272

# Health check - R2R v3 uses /v3/health endpoint
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=5 \
    CMD curl -f http://localhost:7272/v3/health || curl -f http://localhost:7272/health || exit 1

# Start R2R server
CMD ["/app/start.sh"]
