FROM qdrant/qdrant:latest

# Install curl for healthchecks
USER root
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*
USER qdrant

EXPOSE 6333

HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:6333/health || exit 1
