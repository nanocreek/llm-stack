#!/bin/bash

# Service Health Check Script
# Checks health of all Railway services and their endpoints

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

ERRORS=0
WARNINGS=0
TIMEOUT=10

echo "=================================================="
echo "  Railway Services Health Check"
echo "=================================================="
echo ""

# Function to check HTTP endpoint
check_http_endpoint() {
    local name=$1
    local url=$2
    local expected_code=$3
    local auth_header=$4

    echo -n "  Checking $name... "

    if [ -n "$auth_header" ]; then
        response=$(curl -s -o /dev/null -w "%{http_code}" -m $TIMEOUT -H "$auth_header" "$url" 2>/dev/null || echo "000")
    else
        response=$(curl -s -o /dev/null -w "%{http_code}" -m $TIMEOUT "$url" 2>/dev/null || echo "000")
    fi

    if [ "$response" = "$expected_code" ]; then
        echo -e "${GREEN}✓ (HTTP $response)${NC}"
        return 0
    elif [ "$response" = "000" ]; then
        echo -e "${RED}✗ Connection failed${NC}"
        ((ERRORS++))
        return 1
    else
        echo -e "${YELLOW}⚠ Unexpected response (HTTP $response, expected $expected_code)${NC}"
        ((WARNINGS++))
        return 1
    fi
}

# Function to check if service is running
check_service_status() {
    local service=$1

    echo -n "  Checking deployment status... "

    status=$(railway status --service "$service" 2>/dev/null | grep -i "status" || echo "unknown")

    if echo "$status" | grep -qi "success\|active\|running"; then
        echo -e "${GREEN}✓ Running${NC}"
        return 0
    elif echo "$status" | grep -qi "deploying\|building"; then
        echo -e "${YELLOW}⚠ Still deploying${NC}"
        ((WARNINGS++))
        return 1
    else
        echo -e "${RED}✗ Not running${NC}"
        ((ERRORS++))
        return 1
    fi
}

# Get internal URLs from environment variables
echo "Fetching service URLs from Railway..."
QDRANT_URL=$(railway variables --service r2r 2>/dev/null | grep "QDRANT_URL=" | cut -d'=' -f2- || echo "")
LITELLM_URL=$(railway variables --service r2r 2>/dev/null | grep "LITELLM_API_BASE=" | cut -d'=' -f2- || echo "")
QDRANT_API_KEY=$(railway variables --service qdrant 2>/dev/null | grep "QDRANT_API_KEY=" | cut -d'=' -f2- || echo "")
LITELLM_MASTER_KEY=$(railway variables --service litellm 2>/dev/null | grep "LITELLM_MASTER_KEY=" | cut -d'=' -f2- || echo "")
echo ""

# Check 1: PostgreSQL Plugin
echo -e "${BLUE}[1/7] PostgreSQL Plugin${NC}"
check_service_status "postgres-pgvector"

# Test database connection
echo -n "  Testing database connection... "
if railway run --service r2r -- psql "$DATABASE_URL" -c "SELECT 1;" &>/dev/null; then
    echo -e "${GREEN}✓ Connected${NC}"
else
    echo -e "${RED}✗ Connection failed${NC}"
    ((ERRORS++))
fi

# Check pgvector extension
echo -n "  Checking pgvector extension... "
if railway run --service r2r -- psql "$DATABASE_URL" -c "\dx" 2>/dev/null | grep -q "vector"; then
    echo -e "${GREEN}✓ Installed${NC}"
else
    echo -e "${YELLOW}⚠ Not installed${NC}"
    ((WARNINGS++))
fi
echo ""

# Check 2: Redis Plugin
echo -e "${BLUE}[2/7] Redis Plugin${NC}"
check_service_status "redis"

# Test Redis connection
echo -n "  Testing Redis connection... "
if railway run --service r2r -- redis-cli -u "$REDIS_URL" PING 2>/dev/null | grep -q "PONG"; then
    echo -e "${GREEN}✓ Connected${NC}"
else
    echo -e "${RED}✗ Connection failed${NC}"
    ((ERRORS++))
fi
echo ""

# Check 3: Qdrant
echo -e "${BLUE}[3/7] Qdrant Vector Database${NC}"
check_service_status "qdrant"

if [ -n "$QDRANT_URL" ] && [ -n "$QDRANT_API_KEY" ]; then
    check_http_endpoint "HTTP API" "$QDRANT_URL/health" "200" "api-key: $QDRANT_API_KEY"
    check_http_endpoint "Collections endpoint" "$QDRANT_URL/collections" "200" "api-key: $QDRANT_API_KEY"

    # Check if API key is required
    echo -n "  Verifying API key protection... "
    unauth_response=$(curl -s -o /dev/null -w "%{http_code}" -m $TIMEOUT "$QDRANT_URL/collections" 2>/dev/null || echo "000")
    if [ "$unauth_response" = "401" ] || [ "$unauth_response" = "403" ]; then
        echo -e "${GREEN}✓ Protected${NC}"
    else
        echo -e "${YELLOW}⚠ May not be protected (HTTP $unauth_response)${NC}"
        ((WARNINGS++))
    fi
else
    echo -e "${YELLOW}⚠ Qdrant URL or API key not configured${NC}"
    ((WARNINGS++))
fi
echo ""

# Check 4: R2R
echo -e "${BLUE}[4/7] R2R Service${NC}"
check_service_status "r2r"

# Check internal health endpoint
if railway run --service r2r -- curl -s -m $TIMEOUT http://localhost:7272/v2/health &>/dev/null; then
    echo -e "${GREEN}  ✓ Health endpoint responding${NC}"
else
    echo -e "${RED}  ✗ Health endpoint not responding${NC}"
    ((ERRORS++))
fi

# Check logs for errors
echo -n "  Checking recent logs for errors... "
error_count=$(railway logs --service r2r --tail 50 2>/dev/null | grep -ic "error\|exception\|failed" || echo "0")
if [ "$error_count" -eq 0 ]; then
    echo -e "${GREEN}✓ No errors${NC}"
elif [ "$error_count" -lt 5 ]; then
    echo -e "${YELLOW}⚠ $error_count error(s) found${NC}"
    ((WARNINGS++))
else
    echo -e "${RED}✗ $error_count errors found${NC}"
    ((ERRORS++))
fi
echo ""

# Check 5: LiteLLM
echo -e "${BLUE}[5/7] LiteLLM Proxy${NC}"
check_service_status "litellm"

if [ -n "$LITELLM_URL" ] && [ -n "$LITELLM_MASTER_KEY" ]; then
    check_http_endpoint "Health endpoint" "$LITELLM_URL/health" "200"
    check_http_endpoint "Models endpoint" "$LITELLM_URL/v1/models" "200" "Authorization: Bearer $LITELLM_MASTER_KEY"

    # Check if master key is required
    echo -n "  Verifying master key protection... "
    unauth_response=$(curl -s -o /dev/null -w "%{http_code}" -m $TIMEOUT "$LITELLM_URL/v1/models" 2>/dev/null || echo "000")
    if [ "$unauth_response" = "401" ] || [ "$unauth_response" = "403" ]; then
        echo -e "${GREEN}✓ Protected${NC}"
    else
        echo -e "${YELLOW}⚠ May not be protected (HTTP $unauth_response)${NC}"
        ((WARNINGS++))
    fi
else
    echo -e "${YELLOW}⚠ LiteLLM URL or master key not configured${NC}"
    ((WARNINGS++))
fi
echo ""

# Check 6: OpenWebUI
echo -e "${BLUE}[6/7] OpenWebUI${NC}"
check_service_status "openwebui"

# Get public URL
OPENWEBUI_URL=$(railway domain --service openwebui 2>/dev/null || echo "")
if [ -n "$OPENWEBUI_URL" ]; then
    check_http_endpoint "Public URL" "https://$OPENWEBUI_URL" "200"

    # Check HTTPS redirect
    echo -n "  Checking HTTPS enforcement... "
    http_response=$(curl -s -o /dev/null -w "%{http_code}" -m $TIMEOUT -L "http://$OPENWEBUI_URL" 2>/dev/null || echo "000")
    if [ "$http_response" = "200" ]; then
        echo -e "${GREEN}✓ HTTPS working${NC}"
    else
        echo -e "${YELLOW}⚠ HTTP response: $http_response${NC}"
        ((WARNINGS++))
    fi

    # Check security headers
    echo -n "  Checking security headers... "
    headers=$(curl -s -I "https://$OPENWEBUI_URL" 2>/dev/null || echo "")
    header_count=0
    [ -n "$(echo "$headers" | grep -i "X-Frame-Options")" ] && ((header_count++))
    [ -n "$(echo "$headers" | grep -i "X-Content-Type-Options")" ] && ((header_count++))
    [ -n "$(echo "$headers" | grep -i "Strict-Transport-Security")" ] && ((header_count++))

    if [ $header_count -ge 2 ]; then
        echo -e "${GREEN}✓ $header_count/3 security headers present${NC}"
    else
        echo -e "${YELLOW}⚠ Only $header_count/3 security headers present${NC}"
        ((WARNINGS++))
    fi
else
    echo -e "${YELLOW}⚠ Public domain not configured${NC}"
    ((WARNINGS++))
fi
echo ""

# Check 7: React Client
echo -e "${BLUE}[7/7] React Client${NC}"
check_service_status "react-client"

# Get public URL
REACT_URL=$(railway domain --service react-client 2>/dev/null || echo "")
if [ -n "$REACT_URL" ]; then
    check_http_endpoint "Public URL" "https://$REACT_URL" "200"

    # Check for exposed secrets in bundle
    echo -n "  Checking for exposed secrets in bundle... "
    bundle_content=$(curl -s "https://$REACT_URL" 2>/dev/null || echo "")
    if echo "$bundle_content" | grep -qiE "sk-[a-zA-Z0-9]{32,}|api_key.*['\"][^'\"]{20,}|secret.*['\"][^'\"]{20,}"; then
        echo -e "${RED}✗ Potential secrets found in bundle${NC}"
        ((ERRORS++))
    else
        echo -e "${GREEN}✓ No obvious secrets in bundle${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Public domain not configured${NC}"
    ((WARNINGS++))
fi
echo ""

# Overall health summary
echo "=================================================="
echo "  Overall Health Summary"
echo "=================================================="
echo ""

# Count running services
running=$(railway status 2>/dev/null | grep -c "SUCCESS\|ACTIVE" || echo "0")
total=7

echo "Services Running: $running/$total"
echo ""

# Summary
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ All services are healthy!${NC}"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠ Services operational with $WARNINGS warning(s)${NC}"
    echo "  Review warnings above for potential issues"
    exit 0
else
    echo -e "${RED}✗ Health check failed with $ERRORS error(s) and $WARNINGS warning(s)${NC}"
    echo ""
    echo "Please review and fix the errors before proceeding."
    exit 1
fi
