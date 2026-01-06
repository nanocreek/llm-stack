# R2R (RAG framework) service for Railway deployment
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install R2R framework
RUN pip install --no-cache-dir r2r

# Copy any application files (if needed)
# COPY . .

# Create a startup script that handles R2R configuration
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
# Start R2R server\n\
r2r --host ${R2R_HOST:-0.0.0.0} --port ${R2R_PORT:-7272}' > /app/start.sh && \
    chmod +x /app/start.sh

# Expose port 7272
EXPOSE 7272

# Health check - checks the health endpoint
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:7272/health || exit 1

# Start R2R server
CMD ["/app/start.sh"]
