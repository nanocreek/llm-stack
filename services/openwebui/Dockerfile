# OpenWebUI service for Railway deployment
FROM ghcr.io/open-webui/open-webui:main

WORKDIR /app

# Ensure proper permissions
RUN mkdir -p /home/user && \
    chown -R 1000:1000 /home/user

# Expose port 8080
EXPOSE 8080



# OpenWebUI starts by default
CMD ["bash", "-c", "python3 -m uvicorn main:app --host 0.0.0.0 --port 8080"]
