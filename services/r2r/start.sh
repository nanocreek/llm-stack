#!/bin/bash
set -e

echo "========================================="
echo "R2R Server Startup"
echo "========================================="
echo "Environment Check:"
echo "  - PORT: ${PORT}"
echo "  - R2R_PORT: ${R2R_PORT}"
echo "  - R2R_HOST: ${R2R_HOST}"
echo "  - PostgreSQL Host: ${R2R_POSTGRES_HOST}"
echo "  - PostgreSQL Port: ${R2R_POSTGRES_PORT}"
echo "  - PostgreSQL User: ${R2R_POSTGRES_USER}"
echo "  - PostgreSQL DB: ${R2R_POSTGRES_DBNAME}"
echo "  - Qdrant Host: ${R2R_QDRANT_HOST}"
echo "  - Qdrant Port: ${R2R_QDRANT_PORT}"
echo "========================================="

# Use Railway's PORT if available, fallback to R2R_PORT or default
ACTUAL_PORT=${PORT:-${R2R_PORT:-7272}}
ACTUAL_HOST=${R2R_HOST:-0.0.0.0}

echo "Starting on ${ACTUAL_HOST}:${ACTUAL_PORT}"

# Wait for PostgreSQL if configured
if [ ! -z "${R2R_POSTGRES_HOST}" ]; then
  echo "Waiting for PostgreSQL at ${R2R_POSTGRES_HOST}:${R2R_POSTGRES_PORT:-5432}..."
  for i in {1..30}; do
    if pg_isready -h ${R2R_POSTGRES_HOST} -p ${R2R_POSTGRES_PORT:-5432} -U ${R2R_POSTGRES_USER:-postgres} > /dev/null 2>&1; then
      echo "✓ PostgreSQL is ready!"
      break
    fi
    echo "⏳ PostgreSQL not ready - attempt $i/30"
    sleep 2
  done
fi

# Wait for Qdrant if configured
if [ ! -z "${R2R_QDRANT_HOST}" ]; then
  echo "Waiting for Qdrant at ${R2R_QDRANT_HOST}:${R2R_QDRANT_PORT:-6333}..."
  for i in {1..30}; do
    if curl -f http://${R2R_QDRANT_HOST}:${R2R_QDRANT_PORT:-6333}/healthz > /dev/null 2>&1; then
      echo "✓ Qdrant is ready!"
      break
    fi
    echo "⏳ Qdrant not ready - attempt $i/30"
    sleep 2
  done
fi

# Export environment variables that R2R expects
export R2R_PROJECT_NAME="${R2R_PROJECT_NAME:-r2r_default}"
export POSTGRES_HOST="${R2R_POSTGRES_HOST}"
export POSTGRES_PORT="${R2R_POSTGRES_PORT:-5432}"
export POSTGRES_USER="${R2R_POSTGRES_USER}"
export POSTGRES_PASSWORD="${R2R_POSTGRES_PASSWORD}"
export POSTGRES_DBNAME="${R2R_POSTGRES_DBNAME:-postgres}"
export QDRANT_HOST="${R2R_QDRANT_HOST}"
export QDRANT_PORT="${R2R_QDRANT_PORT:-6333}"

# Create minimal R2R config if it doesn't exist
if [ ! -f /app/config/r2r.json ]; then
  echo "Creating R2R configuration..."
  cat > /app/config/r2r.json <<EOF
{
  "app": {
    "max_logs_per_request": 100
  },
  "completions": {
    "provider": "litellm",
    "litellm_base_url": "http://litellm.railway.internal:4000"
  },
  "database": {
    "provider": "postgres"
  },
  "vector_database": {
    "provider": "qdrant",
    "collection_name": "r2r_default"
  }
}
EOF
fi

echo "========================================="
echo "Starting R2R server..."
echo "Config file: /app/config/r2r.json"
echo "========================================="

# Start R2R server with explicit configuration
exec r2r serve \
  --host ${ACTUAL_HOST} \
  --port ${ACTUAL_PORT} \
  --config-path /app/config/r2r.json