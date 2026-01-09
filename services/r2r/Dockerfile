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

# Verify R2R installation
RUN r2r --version || echo "WARNING: r2r command not found!"

# Create R2R configuration directory
RUN mkdir -p /app/config /app/data

# Copy and verify startup script
COPY start.sh /app/start.sh
RUN chmod +x /app/start.sh && \
    ls -la /app/start.sh && \
    head -5 /app/start.sh

# Expose port 7272
EXPOSE 7272

# Health check - try multiple possible endpoints
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=5 \
    CMD curl -f http://localhost:7272/health || curl -f http://localhost:7272/v3/health || exit 1

# Start R2R server using bash explicitly
CMD ["/bin/bash", "/app/start.sh"]
