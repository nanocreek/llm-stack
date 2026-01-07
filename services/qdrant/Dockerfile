# Use a pinned version instead of latest for reproducibility and stability
FROM qdrant/qdrant:v1.13.1

# Install curl for healthchecks and additional debugging tools
USER root
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    curl \
    ca-certificates && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get clean

# Switch back to qdrant user for security
USER qdrant

# Expose both HTTP and gRPC ports
EXPOSE 6333 6334

# Comprehensive health check with better timeout and retry configuration
# - interval: 30s - check health every 30 seconds
# - timeout: 5s - wait max 5 seconds for response
# - start-period: 60s - grace period for startup
# - retries: 3 - allow 3 failures before marking unhealthy
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:6333/readyz || exit 1
