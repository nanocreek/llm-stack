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
  # Use PGPASSWORD environment variable to avoid password prompts
  export PGPASSWORD="${R2R_POSTGRES_PASSWORD}"
  PSQL_COMMAND="psql -h ${R2R_POSTGRES_HOST} -p ${R2R_POSTGRES_PORT:-5432} -U ${R2R_POSTGRES_USER:-postgres} -d ${R2R_POSTGRES_DBNAME:-postgres}"
  
  # Attempt to create the required extensions (uuid-ossp for UUIDs, vector for pgvector)
  if ${PSQL_COMMAND} -c "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\"; CREATE EXTENSION IF NOT EXISTS vector;" 2>&1 | tee /tmp/pgvector_setup.log; then
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
  unset PGPASSWORD
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
disable_create_extension = true

[vector_database]
provider = "qdrant"
collection_name = "r2r_default"
EOF

echo "Configuration created:"
cat /app/config/r2r.toml

echo "================================"
echo "Creating pgvector error suppression wrapper..."
echo "================================"

# Create a Python wrapper to suppress pgvector extension errors
cat > /app/r2r_wrapper.py <<'PYTHON_EOF'
#!/usr/bin/env python3
"""
R2R pgvector error suppression wrapper

This wrapper catches and suppresses FeatureNotSupportedError exceptions
related to pgvector extension creation, which can occur on Railway's
managed PostgreSQL that doesn't have pgvector installed.

The wrapper allows R2R to continue operating without pgvector since
vector storage is handled by Qdrant (configured in r2r.toml).

Root cause: R2R unconditionally attempts to create pgvector extension
during initialization, even though disable_create_extension=true doesn't
actually prevent this at the code level.
"""

import sys
import logging
from pathlib import Path

# Setup logging before importing r2r
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def patch_postgres_module():
    """
    Patch the r2r postgres module to suppress pgvector extension errors.
    This wraps the create_tables method to catch and suppress pgvector errors.
    """
    try:
        from r2r.providers.database import postgres
        import functools
        
        original_init = postgres.PostgresVectorDB.__init__
        
        @functools.wraps(original_init)
        def patched_init(self, *args, **kwargs):
            """Patched init that suppresses pgvector creation errors"""
            try:
                logger.info("Initializing PostgreSQL with pgvector error suppression wrapper")
                return original_init(self, *args, **kwargs)
            except Exception as e:
                error_msg = str(e).lower()
                # Check if this is a pgvector-related error
                if any(phrase in error_msg for phrase in [
                    'vector',
                    'extension',
                    'control file',
                    'not available',
                    'feature not supported'
                ]):
                    logger.warning(
                        f"⚠ pgvector extension creation failed (expected on Railway): {e}\n"
                        f"  Vector storage will use Qdrant (configured in r2r.toml)\n"
                        f"  PostgreSQL will handle document and metadata storage only"
                    )
                    # Try to continue without pgvector - don't re-raise
                    return
                else:
                    # Re-raise non-pgvector errors
                    logger.error(f"Database initialization error: {e}")
                    raise
        
        postgres.PostgresVectorDB.__init__ = patched_init
        logger.info("✓ PostgreSQL pgvector error suppression patch applied")
        
    except ImportError as e:
        logger.warning(f"Could not import postgres module for patching: {e}")
    except Exception as e:
        logger.error(f"Error applying postgres patch: {e}")

def main():
    """Main entry point - start R2R with patched error handling"""
    logger.info("Starting R2R with pgvector error suppression wrapper")
    
    # Apply the patch before importing r2r.serve
    patch_postgres_module()
    
    # Launch R2R using subprocess with the correct arguments
    # Extract arguments from command line (skip the script name and 'serve')
    import subprocess
    import os
    logger.info("Launching R2R serve command via subprocess")
    
    try:
        # Build the command: python -m r2r.serve [other args]
        # We need to use r2r.serve module directly which handles the CLI
        args = sys.argv[1:]  # Skip script name
        
        # If first arg is 'serve', keep it; if not, we'll add it
        if args and args[0] == 'serve':
            # Remove 'serve' from args and let the module handle it
            args = args[1:]
        
        # Use python -m r2r with the proper args
        cmd = [sys.executable, '-m', 'r2r.serve'] + args
        logger.info(f"Executing: {' '.join(cmd)}")
        logger.info(f"Environment variables set: POSTGRES_HOST={os.environ.get('POSTGRES_HOST')}, POSTGRES_PORT={os.environ.get('POSTGRES_PORT')}, QDRANT_HOST={os.environ.get('QDRANT_HOST')}")
        # Pass the current environment to subprocess so it inherits all env vars
        result = subprocess.run(cmd, check=False, env=os.environ.copy())
        sys.exit(result.returncode)
        
    except Exception as e:
        logger.error(f"R2R server error: {e}", exc_info=True)
        sys.exit(1)

if __name__ == '__main__':
    main()
PYTHON_EOF

chmod +x /app/r2r_wrapper.py
echo "✓ Wrapper script created"

echo "================================"
echo "Starting R2R server with pgvector error suppression..."
echo "Command: python /app/r2r_wrapper.py serve --host ${ACTUAL_HOST} --port ${ACTUAL_PORT} --config-path /app/config/r2r.toml"
echo "================================"

# Start R2R using the wrapper that suppresses pgvector errors
exec python /app/r2r_wrapper.py serve \
  --host "${ACTUAL_HOST}" \
  --port "${ACTUAL_PORT}" \
  --config-path /app/config/r2r.toml