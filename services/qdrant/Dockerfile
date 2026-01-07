# Use pinned version for reproducibility (not :latest)
# v1.13.1 is stable and well-tested
FROM qdrant/qdrant:v1.13.1

# Install curl for health checks
USER root
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get clean

# Switch back to qdrant user for security
USER qdrant

# Health check configuration
# Uses /readyz endpoint which properly checks readiness
# start-period allows time for Qdrant to fully initialize
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:6333/readyz || exit 1
