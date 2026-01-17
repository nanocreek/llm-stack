# OpenWebUI service - using official Docker image
FROM ghcr.io/open-webui/open-webui:main

# Set environment variables for OpenWebUI
# The base image listens on 8000 by default, but we expose 8080
ENV PORT=8080
ENV HOST=0.0.0.0

# Expose port 8080
EXPOSE 8080

# Use the base image's entrypoint - it knows how to start the application properly
# Environment variables from the container are automatically available to the process
