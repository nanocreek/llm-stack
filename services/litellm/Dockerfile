# LiteLLM service using official Docker image
FROM docker.litellm.ai/berriai/litellm:v1.80.8-stable

WORKDIR /app

# Create config directory and copy configuration file
RUN mkdir -p /app/config
COPY config.yaml /app/config/config.yaml

# Expose port 4000
EXPOSE 4000

# Health check - checks the health endpoint
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:4000/health || exit 1

# Start LiteLLM server with config
CMD ["litellm", "--config", "/app/config/config.yaml", "--host", "0.0.0.0", "--port", "4000"]
