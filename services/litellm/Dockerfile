# LiteLLM service for Railway deployment
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install LiteLLM and required dependencies
RUN pip install --no-cache-dir \
    litellm \
    python-dotenv \
    requests

# Create a minimal config directory
RUN mkdir -p /app/config

# Create a startup script that handles LiteLLM configuration
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
# Start LiteLLM server\n\
litellm --host ${LITELLM_HOST:-0.0.0.0} --port ${LITELLM_PORT:-4000} --config /app/config/config.yaml 2>&1 || \n\
litellm --host ${LITELLM_HOST:-0.0.0.0} --port ${LITELLM_PORT:-4000}' > /app/start.sh && \
    chmod +x /app/start.sh

# Expose port 4000
EXPOSE 4000

# Health check - checks the health endpoint
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:4000/health || exit 1

# Start LiteLLM server
CMD ["/app/start.sh"]
