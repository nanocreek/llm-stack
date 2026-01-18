FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    postgresql-client \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Install Railway CLI
RUN npm install -g @railway/cli || curl -fsSL https://railway.app/install.sh | sh

# Copy requirements
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY . .

# Copy verification scripts from parent directory
COPY ../../scripts /app/scripts

# Make scripts executable
RUN chmod +x /app/scripts/verification/**/*.sh /app/scripts/verification/*.sh

# Expose port
EXPOSE 5000

# Run with eventlet worker for WebSocket support
CMD ["gunicorn", "--worker-class", "eventlet", "-w", "1", "--bind", "0.0.0.0:5000", "app:app"]
