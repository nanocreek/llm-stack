#!/bin/bash

# Local development runner for Verification UI

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================="
echo "  Verification UI - Local Development"
echo "=========================================="
echo ""

# Check Python
if ! command -v python3 &> /dev/null; then
    echo "Error: Python 3 is required"
    exit 1
fi

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
echo "Activating virtual environment..."
source venv/bin/activate

# Install dependencies
echo "Installing dependencies..."
pip install -q -r requirements.txt

# Check for .env file
if [ ! -f ".env" ]; then
    echo "Creating .env from template..."
    cp .env.example .env
    echo "Please edit .env with your configuration"
fi

# Load environment variables
if [ -f ".env" ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Set default port
export PORT=${PORT:-5000}
export FLASK_ENV=${FLASK_ENV:-development}

echo ""
echo "=========================================="
echo "  Starting Verification UI"
echo "=========================================="
echo ""
echo "  Dashboard: http://localhost:$PORT"
echo "  API Docs:  http://localhost:$PORT/api/scripts"
echo ""
echo "  Press Ctrl+C to stop"
echo ""
echo "=========================================="
echo ""

# Run application
python app.py
