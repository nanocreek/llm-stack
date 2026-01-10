# LiteLLM service using official Docker image
FROM ghcr.io/berriai/litellm:main-latest

WORKDIR /app

# Copy the configuration file
COPY config.yaml /app/config.yaml

# Expose port 4000
EXPOSE 4000

# Health check - checks the health endpoint
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:4000/health || exit 1

# Start LiteLLM server with config
CMD ["litellm", "--config", "/app/config.yaml", "--host", "0.0.0.0", "--port", "4000"]
