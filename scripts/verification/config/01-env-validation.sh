#!/bin/bash

# Railway Environment Variables Validation
# Validates that all required environment variables are set for each service

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

ERRORS=0
WARNINGS=0

echo "=================================================="
echo "  Railway Environment Variables Validation"
echo "=================================================="
echo ""

# Check Railway CLI is available
if ! command -v railway &> /dev/null; then
    echo -e "${RED}✗ Railway CLI not installed${NC}"
    echo "  Install: npm i -g @railway/cli"
    exit 1
fi

# Function to check if variable is set for a service
check_variable() {
    local service=$1
    local var_name=$2
    local is_required=$3

    result=$(railway variables --service "$service" 2>/dev/null | grep "^$var_name=" || echo "")

    if [ -z "$result" ]; then
        if [ "$is_required" = "true" ]; then
            echo -e "${RED}  ✗ Missing required: $var_name${NC}"
            ((ERRORS++))
        else
            echo -e "${YELLOW}  ⚠ Missing optional: $var_name${NC}"
            ((WARNINGS++))
        fi
        return 1
    else
        # Check for placeholder values
        value=$(echo "$result" | cut -d'=' -f2-)
        if [[ "$value" =~ (changeme|password123|admin|secret|replace|your_.*_here|REPLACE) ]]; then
            echo -e "${RED}  ✗ Placeholder value detected: $var_name${NC}"
            ((ERRORS++))
            return 1
        fi

        echo -e "${GREEN}  ✓ $var_name${NC}"
        return 0
    fi
}

# PostgreSQL Plugin
echo -e "${BLUE}[1/7] Checking PostgreSQL Plugin...${NC}"
check_variable "postgres-pgvector" "DATABASE_URL" "true"
check_variable "postgres-pgvector" "POSTGRES_DB" "true"
check_variable "postgres-pgvector" "POSTGRES_USER" "true"
check_variable "postgres-pgvector" "POSTGRES_PASSWORD" "true"
echo ""

# Redis Plugin
echo -e "${BLUE}[2/7] Checking Redis Plugin...${NC}"
check_variable "redis" "REDIS_URL" "true"
echo ""

# Qdrant
echo -e "${BLUE}[3/7] Checking Qdrant Service...${NC}"
check_variable "qdrant" "QDRANT_API_KEY" "true"
check_variable "qdrant" "QDRANT_STORAGE_PATH" "false"
check_variable "qdrant" "QDRANT_GRPC_PORT" "false"
check_variable "qdrant" "QDRANT_HTTP_PORT" "false"
echo ""

# R2R
echo -e "${BLUE}[4/7] Checking R2R Service...${NC}"
check_variable "r2r" "POSTGRES_HOST" "true"
check_variable "r2r" "POSTGRES_DBNAME" "true"
check_variable "r2r" "POSTGRES_USER" "true"
check_variable "r2r" "POSTGRES_PASSWORD" "true"
check_variable "r2r" "R2R_PROJECT_NAME" "true"
check_variable "r2r" "QDRANT_URL" "true"
check_variable "r2r" "QDRANT_API_KEY" "true"
check_variable "r2r" "LITELLM_API_BASE" "true"
check_variable "r2r" "EMBEDDING_MODEL" "true"
check_variable "r2r" "LLM_MODEL" "true"
echo ""

# LiteLLM
echo -e "${BLUE}[5/7] Checking LiteLLM Service...${NC}"
check_variable "litellm" "LITELLM_MASTER_KEY" "true"
check_variable "litellm" "DATABASE_URL" "true"
check_variable "litellm" "OPENAI_API_KEY" "false"
check_variable "litellm" "ANTHROPIC_API_KEY" "false"
check_variable "litellm" "LITELLM_LOG_LEVEL" "false"
echo ""

# OpenWebUI
echo -e "${BLUE}[6/7] Checking OpenWebUI Service...${NC}"
check_variable "openwebui" "WEBUI_SECRET_KEY" "true"
check_variable "openwebui" "OLLAMA_BASE_URL" "true"
check_variable "openwebui" "DATABASE_URL" "true"
check_variable "openwebui" "CORS_ALLOW_ORIGIN" "false"
check_variable "openwebui" "ENABLE_OAUTH" "false"
echo ""

# React Client
echo -e "${BLUE}[7/7] Checking React Client Service...${NC}"
check_variable "react-client" "REACT_APP_API_URL" "true"
check_variable "react-client" "REACT_APP_ENV" "false"
echo ""

# Validation: Check for common security issues
echo "=================================================="
echo "  Security Validation"
echo "=================================================="
echo ""

# Check password strength for critical passwords
echo "[1/3] Validating password strength..."
for service in "postgres-pgvector" "r2r"; do
    password=$(railway variables --service "$service" 2>/dev/null | grep "POSTGRES_PASSWORD=" | cut -d'=' -f2-)
    if [ -n "$password" ]; then
        length=${#password}
        if [ $length -lt 16 ]; then
            echo -e "${YELLOW}⚠ $service: POSTGRES_PASSWORD is shorter than 16 characters${NC}"
            ((WARNINGS++))
        else
            echo -e "${GREEN}✓ $service: POSTGRES_PASSWORD meets length requirement${NC}"
        fi
    fi
done
echo ""

# Check for strong master keys
echo "[2/3] Validating API keys strength..."
for service in "litellm" "openwebui" "qdrant"; do
    case $service in
        "litellm")
            key=$(railway variables --service "$service" 2>/dev/null | grep "LITELLM_MASTER_KEY=" | cut -d'=' -f2-)
            key_name="LITELLM_MASTER_KEY"
            ;;
        "openwebui")
            key=$(railway variables --service "$service" 2>/dev/null | grep "WEBUI_SECRET_KEY=" | cut -d'=' -f2-)
            key_name="WEBUI_SECRET_KEY"
            ;;
        "qdrant")
            key=$(railway variables --service "$service" 2>/dev/null | grep "QDRANT_API_KEY=" | cut -d'=' -f2-)
            key_name="QDRANT_API_KEY"
            ;;
    esac

    if [ -n "$key" ]; then
        length=${#key}
        if [ $length -lt 32 ]; then
            echo -e "${YELLOW}⚠ $service: $key_name is shorter than 32 characters${NC}"
            ((WARNINGS++))
        else
            echo -e "${GREEN}✓ $service: $key_name meets length requirement${NC}"
        fi
    fi
done
echo ""

# Check internal URLs are using Railway internal networking
echo "[3/3] Validating internal service URLs..."
qdrant_url=$(railway variables --service "r2r" 2>/dev/null | grep "QDRANT_URL=" | cut -d'=' -f2-)
if [[ "$qdrant_url" == *".railway.internal"* ]]; then
    echo -e "${GREEN}✓ QDRANT_URL uses internal networking${NC}"
else
    echo -e "${YELLOW}⚠ QDRANT_URL should use .railway.internal for better security${NC}"
    ((WARNINGS++))
fi

litellm_url=$(railway variables --service "r2r" 2>/dev/null | grep "LITELLM_API_BASE=" | cut -d'=' -f2-)
if [[ "$litellm_url" == *".railway.internal"* ]]; then
    echo -e "${GREEN}✓ LITELLM_API_BASE uses internal networking${NC}"
else
    echo -e "${YELLOW}⚠ LITELLM_API_BASE should use .railway.internal for better security${NC}"
    ((WARNINGS++))
fi
echo ""

# Summary
echo "=================================================="
echo "  Summary"
echo "=================================================="
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ All environment variables validated successfully!${NC}"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠ Passed with $WARNINGS warning(s)${NC}"
    echo "  Consider addressing warnings for production deployment"
    exit 0
else
    echo -e "${RED}✗ Failed with $ERRORS error(s) and $WARNINGS warning(s)${NC}"
    echo ""
    echo "Please configure all required environment variables in Railway."
    exit 1
fi
