#!/bin/bash

# Make sure we output everything
set -x
exec 2>&1

echo "===== R2R STARTUP BEGIN ====="
echo "Date: $(date)"
echo "PWD: $(pwd)"
echo "User: $(whoami)"
echo "================================"

# Check Python and R2R
echo "Checking Python..."
python --version

echo "Checking R2R installation..."
echo "Looking for r2r command..."
which r2r || echo "r2r not in PATH"

echo "Checking if r2r module is available..."
python -c "import r2r; print(f'R2R module found: {r2r.__version__}')" || echo "R2R module not found!"

# Determine how to run R2R
# Use Python module invocation since r2r doesn't install a standalone CLI executable
R2R_CMD="python -m r2r"
echo "Using R2R via Python module invocation"

echo "================================"
echo "Environment variables:"
env | grep -E "(PORT|R2R_|POSTGRES|QDRANT)" | sort
echo "================================"

# Set defaults - prioritize R2R_PORT over generic PORT
export ACTUAL_PORT="${R2R_PORT:-7272}"
export ACTUAL_HOST="${R2R_HOST:-0.0.0.0}"

echo "Will bind to: ${ACTUAL_HOST}:${ACTUAL_PORT}"

# Wait for PostgreSQL if configured
if [ -n "${R2R_POSTGRES_HOST}" ]; then
  echo "Waiting for PostgreSQL at ${R2R_POSTGRES_HOST}..."
  for i in {1..30}; do
    if pg_isready -h "${R2R_POSTGRES_HOST}" -p "${R2R_POSTGRES_PORT:-5432}" -U "${R2R_POSTGRES_USER:-postgres}" >/dev/null 2>&1; then
      echo "PostgreSQL is ready!"
      break
    fi
    echo "PostgreSQL not ready (attempt $i/30)"
    sleep 2
  done
  
  # Create pgvector extension after PostgreSQL is ready
  echo "================================"
  echo "Setting up pgvector extension..."
  PSQL_COMMAND="psql -h ${R2R_POSTGRES_HOST} -p ${R2R_POSTGRES_PORT:-5432} -U ${R2R_POSTGRES_USER:-postgres} -d ${R2R_POSTGRES_DBNAME:-postgres}"
  
  # Attempt to create the pgvector extension
  if ${PSQL_COMMAND} -c "CREATE EXTENSION IF NOT EXISTS vector;" 2>&1 | tee /tmp/pgvector_setup.log; then
    echo "✓ pgvector extension setup successful"
  else
    echo "⚠ pgvector extension creation may have failed"
    echo "  This could be because:"
    echo "  1. pgvector package is not installed on PostgreSQL"
    echo "  2. Extension requires SUPERUSER privileges"
    echo "  3. Extension is already created"
    echo "  Attempting to verify extension exists..."
    
    if ${PSQL_COMMAND} -c "SELECT extname FROM pg_extension WHERE extname='vector';" 2>&1 | grep -q "vector"; then
      echo "✓ pgvector extension is available"
    else
      echo "✗ pgvector extension is NOT available - R2R may fail if it requires pgvector"
      echo "  For Railway with managed PostgreSQL, ensure pgvector addon is enabled"
    fi
  fi
  echo "================================"
else
  echo "Skipping PostgreSQL wait (R2R_POSTGRES_HOST not set)"
fi

# Wait for Qdrant if configured
if [ -n "${R2R_QDRANT_HOST}" ]; then
  echo "Waiting for Qdrant at ${R2R_QDRANT_HOST}..."
  for i in {1..30}; do
    if curl -sf "http://${R2R_QDRANT_HOST}:${R2R_QDRANT_PORT:-6333}/healthz" >/dev/null 2>&1; then
      echo "Qdrant is ready!"
      break
    fi
    echo "Qdrant not ready (attempt $i/30)"
    sleep 2
  done
else
  echo "Skipping Qdrant wait (R2R_QDRANT_HOST not set)"
fi

# Export environment variables for R2R
echo "Exporting R2R environment variables..."
export R2R_PROJECT_NAME="${R2R_PROJECT_NAME:-r2r_default}"
export POSTGRES_HOST="${R2R_POSTGRES_HOST}"
export POSTGRES_PORT="${R2R_POSTGRES_PORT:-5432}"
export POSTGRES_USER="${R2R_POSTGRES_USER}"
export POSTGRES_PASSWORD="${R2R_POSTGRES_PASSWORD}"
export POSTGRES_DBNAME="${R2R_POSTGRES_DBNAME:-postgres}"
export QDRANT_HOST="${R2R_QDRANT_HOST}"
export QDRANT_PORT="${R2R_QDRANT_PORT:-6333}"

# Create R2R config
echo "Creating R2R configuration..."
mkdir -p /app/config
cat > /app/config/r2r.toml <<'EOF'
[app]
max_logs_per_request = 100

[completions]
provider = "litellm"
litellm_base_url = "http://litellm.railway.internal:4000"

[database]
provider = "postgres"

[vector_database]
provider = "qdrant"
collection_name = "r2r_default"
EOF

echo "Configuration created:"
cat /app/config/r2r.toml

echo "================================"
echo "Starting R2R server..."
echo "Command: ${R2R_CMD} serve --host ${ACTUAL_HOST} --port ${ACTUAL_PORT} --config-path /app/config/r2r.toml"
echo "================================"

# Start R2R using Python module invocation
exec python -m r2r.serve \
  --host "${ACTUAL_HOST}" \
  --port "${ACTUAL_PORT}" \
  --config-path /app/config/r2r.toml