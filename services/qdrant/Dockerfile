FROM qdrant/qdrant:latest

EXPOSE 6333

HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:6333/ || exit 1
