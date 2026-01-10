#!/bin/bash

# OpenWebUI startup script
set -x
exec 2>&1

echo "===== OPENWEBUI STARTUP BEGIN ====="
echo "Date: $(date)"
echo "PWD: $(pwd)"
echo "User: $(whoami)"
echo "===================================="

# Set default port if not specified
export PORT="${PORT:-8080}"
export HOST="${HOST:-0.0.0.0}"

echo "Environment variables:"
env | grep -E "(PORT|HOST|OPENWEBUI|WEBUI)" | sort || true
echo "===================================="

# Check what's available in the container
echo "Checking available commands..."
which python3 || which python || echo "No python found"
which pip || which pip3 || echo "No pip found"

echo "Current directory: $(pwd)"
ls -la / | grep -E "(app|src|bin|opt)" || true
echo "===================================="

echo "Starting OpenWebUI on ${HOST}:${PORT}..."

# Try to find and execute the main application
# The official OpenWebUI image typically has the app in /app
if [ -f "/app/main.py" ]; then
    cd /app
    exec python -m uvicorn main:app --host "${HOST}" --port "${PORT}" || exec python3 -m uvicorn main:app --host "${HOST}" --port "${PORT}"
elif [ -f "/app/backend/main.py" ]; then
    cd /app/backend
    exec python -m uvicorn main:app --host "${HOST}" --port "${PORT}" || exec python3 -m uvicorn main:app --host "${HOST}" --port "${PORT}"
else
    # Fall back to the base image's default entrypoint
    echo "Could not find main.py, attempting to use base image entrypoint..."
    # Try to run whatever the base image would normally run
    exec /bin/bash -c 'exec "$@"' bash /bin/sh -c "python -m pip install uvicorn >/dev/null 2>&1 || true; cd /app; python -m uvicorn main:app --host ${HOST} --port ${PORT} || python3 -m uvicorn main:app --host ${HOST} --port ${PORT}"
fi
