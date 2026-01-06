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
RUN mkdir -p /app/config

# Create a startup script that handles R2R configuration and initialization
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
echo "Starting R2R server..."\n\
\n\
# Wait for PostgreSQL to be ready\n\
echo "Waiting for PostgreSQL..."\n\
until pg_isready -h ${R2R_POSTGRES_HOST:-localhost} -p ${R2R_POSTGRES_PORT:-5432} -U ${R2R_POSTGRES_USER:-postgres}; do\n\
  echo "PostgreSQL is unavailable - sleeping"\n\
  sleep 2\n\
done\n\
echo "PostgreSQL is up!"\n\
\n\
# Wait for Qdrant to be ready\n\
echo "Waiting for Qdrant..."\n\
until curl -f http://${R2R_QDRANT_HOST:-qdrant.railway.internal}:${R2R_QDRANT_PORT:-6333}/healthz > /dev/null 2>&1; do\n\
  echo "Qdrant is unavailable - sleeping"\n\
  sleep 2\n\
done\n\
echo "Qdrant is up!"\n\
\n\
# Start R2R server with proper command\n\
exec r2r serve --host ${R2R_HOST:-0.0.0.0} --port ${R2R_PORT:-7272}' > /app/start.sh && \
    chmod +x /app/start.sh

# Expose port 7272
EXPOSE 7272

# Health check - checks the health endpoint with longer timeout
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=5 \
    CMD curl -f http://localhost:7272/health || exit 1

# Start R2R server
CMD ["/app/start.sh"]
