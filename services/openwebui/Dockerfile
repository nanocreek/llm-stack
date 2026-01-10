# OpenWebUI service - using official base image with proper override
FROM ghcr.io/open-webui/open-webui:main

# Create a minimal start.sh in /app directory
# This satisfies the base image's expectation for a start.sh script
RUN mkdir -p /app && \
    printf '#!/bin/bash\nset -e\nexport PORT="${PORT:-8080}"\nexport HOST="${HOST:-0.0.0.0}"\necho "Starting OpenWebUI on ${HOST}:${PORT}..."\nexec python -m uvicorn main:app --host "${HOST}" --port "${PORT}" || exec python3 -m uvicorn main:app --host "${HOST}" --port "${PORT}"\n' > /app/start.sh && \
    chmod +x /app/start.sh && \
    ls -la /app/start.sh

# Set environment variables for OpenWebUI
ENV PORT=8080 \
    HOST=0.0.0.0

# Expose port 8080
EXPOSE 8080

# Keep the base image's entrypoint and CMD
# It should now find start.sh in /app
