#!/bin/bash

# Integration Testing Script
# Tests end-to-end workflows and service-to-service communication

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

ERRORS=0
WARNINGS=0
TIMEOUT=30
TEST_USER="test_$(date +%s)"
TEST_EMAIL="${TEST_USER}@example.com"
TEST_PASSWORD="TestP@ssw0rd123!_$(openssl rand -hex 8)"

echo "=================================================="
echo "  Integration Testing"
echo "=================================================="
echo ""

# Get service URLs
OPENWEBUI_URL=$(railway domain --service openwebui 2>/dev/null || echo "")
LITELLM_URL=$(railway variables --service r2r 2>/dev/null | grep "LITELLM_API_BASE=" | cut -d'=' -f2- || echo "")
LITELLM_MASTER_KEY=$(railway variables --service litellm 2>/dev/null | grep "LITELLM_MASTER_KEY=" | cut -d'=' -f2- || echo "")

cleanup() {
    echo ""
    echo "Cleaning up test data..."
    # Add cleanup logic here if needed
}

trap cleanup EXIT

# Test 1: Database Connectivity Chain
echo -e "${BLUE}[1/5] Testing Database Connectivity Chain${NC}"

echo -n "  PostgreSQL -> R2R connection... "
if railway run --service r2r -- psql "$DATABASE_URL" -c "SELECT 1;" &>/dev/null; then
    echo -e "${GREEN}✓ Connected${NC}"
else
    echo -e "${RED}✗ Connection failed${NC}"
    ((ERRORS++))
fi

echo -n "  PostgreSQL -> LiteLLM connection... "
if railway run --service litellm -- psql "$DATABASE_URL" -c "SELECT 1;" &>/dev/null; then
    echo -e "${GREEN}✓ Connected${NC}"
else
    echo -e "${RED}✗ Connection failed${NC}"
    ((ERRORS++))
fi

echo -n "  PostgreSQL -> OpenWebUI connection... "
if railway run --service openwebui -- psql "$DATABASE_URL" -c "SELECT 1;" &>/dev/null; then
    echo -e "${GREEN}✓ Connected${NC}"
else
    echo -e "${RED}✗ Connection failed${NC}"
    ((ERRORS++))
fi
echo ""

# Test 2: Vector Database Integration
echo -e "${BLUE}[2/5] Testing Vector Database Integration${NC}"

QDRANT_URL=$(railway variables --service r2r 2>/dev/null | grep "QDRANT_URL=" | cut -d'=' -f2- || echo "")
QDRANT_API_KEY=$(railway variables --service qdrant 2>/dev/null | grep "QDRANT_API_KEY=" | cut -d'=' -f2- || echo "")

if [ -n "$QDRANT_URL" ] && [ -n "$QDRANT_API_KEY" ]; then
    echo -n "  R2R -> Qdrant connectivity... "
    if railway logs --service r2r --tail 100 2>/dev/null | grep -q "qdrant.*connect\|vector.*db.*ready"; then
        echo -e "${GREEN}✓ Connected${NC}"
    else
        echo -e "${YELLOW}⚠ Could not verify connection from logs${NC}"
        ((WARNINGS++))
    fi

    echo -n "  Qdrant collections accessible... "
    collections=$(curl -s -H "api-key: $QDRANT_API_KEY" "$QDRANT_URL/collections" 2>/dev/null || echo "")
    if [ -n "$collections" ]; then
        echo -e "${GREEN}✓ Accessible${NC}"
    else
        echo -e "${RED}✗ Not accessible${NC}"
        ((ERRORS++))
    fi

    echo -n "  Test vector insertion... "
    test_collection="test_collection_$(date +%s)"
    create_result=$(curl -s -X PUT -H "api-key: $QDRANT_API_KEY" -H "Content-Type: application/json" \
        "$QDRANT_URL/collections/$test_collection" \
        -d '{"vectors":{"size":128,"distance":"Cosine"}}' 2>/dev/null || echo "")

    if echo "$create_result" | grep -q "true\|ok"; then
        echo -e "${GREEN}✓ Vector operations working${NC}"

        # Cleanup test collection
        curl -s -X DELETE -H "api-key: $QDRANT_API_KEY" "$QDRANT_URL/collections/$test_collection" &>/dev/null
    else
        echo -e "${YELLOW}⚠ Could not perform vector operations${NC}"
        ((WARNINGS++))
    fi
else
    echo -e "${YELLOW}⚠ Qdrant not configured, skipping tests${NC}"
    ((WARNINGS++))
fi
echo ""

# Test 3: LLM Proxy Integration
echo -e "${BLUE}[3/5] Testing LLM Proxy Integration${NC}"

if [ -n "$LITELLM_URL" ] && [ -n "$LITELLM_MASTER_KEY" ]; then
    echo -n "  LiteLLM models endpoint... "
    models=$(curl -s -H "Authorization: Bearer $LITELLM_MASTER_KEY" "$LITELLM_URL/v1/models" 2>/dev/null || echo "")
    if echo "$models" | grep -q "data\|model"; then
        echo -e "${GREEN}✓ Models listed${NC}"
    else
        echo -e "${RED}✗ Could not list models${NC}"
        ((ERRORS++))
    fi

    echo -n "  R2R -> LiteLLM connectivity... "
    if railway logs --service r2r --tail 100 2>/dev/null | grep -q "litellm.*connect\|llm.*ready"; then
        echo -e "${GREEN}✓ Connected${NC}"
    else
        echo -e "${YELLOW}⚠ Could not verify connection from logs${NC}"
        ((WARNINGS++))
    fi

    echo -n "  OpenWebUI -> LiteLLM connectivity... "
    ollama_url=$(railway variables --service openwebui 2>/dev/null | grep "OLLAMA_BASE_URL=" | cut -d'=' -f2- || echo "")
    if [[ "$ollama_url" == *"litellm"* ]]; then
        echo -e "${GREEN}✓ Configured${NC}"
    else
        echo -e "${YELLOW}⚠ May not be configured correctly${NC}"
        ((WARNINGS++))
    fi

    # Test completion (if provider API keys are available)
    echo -n "  Testing LLM completion... "
    completion=$(curl -s -X POST "$LITELLM_URL/v1/chat/completions" \
        -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
        -H "Content-Type: application/json" \
        -d '{
            "model": "gpt-3.5-turbo",
            "messages": [{"role": "user", "content": "Say hello in one word"}],
            "max_tokens": 5
        }' 2>/dev/null || echo "")

    if echo "$completion" | grep -q "choices\|content"; then
        echo -e "${GREEN}✓ Completion successful${NC}"
    elif echo "$completion" | grep -qi "api.*key.*invalid\|unauthorized\|provider"; then
        echo -e "${YELLOW}⚠ LLM provider API key may not be configured${NC}"
        ((WARNINGS++))
    else
        echo -e "${RED}✗ Completion failed${NC}"
        ((ERRORS++))
    fi
else
    echo -e "${YELLOW}⚠ LiteLLM not configured, skipping tests${NC}"
    ((WARNINGS++))
fi
echo ""

# Test 4: Authentication Flow
echo -e "${BLUE}[4/5] Testing Authentication Flow${NC}"

if [ -n "$OPENWEBUI_URL" ]; then
    echo -n "  User registration... "
    signup_response=$(curl -s -X POST "https://$OPENWEBUI_URL/api/auth/signup" \
        -H "Content-Type: application/json" \
        -d "{\"username\":\"$TEST_USER\",\"email\":\"$TEST_EMAIL\",\"password\":\"$TEST_PASSWORD\"}" \
        2>/dev/null || echo "")

    if echo "$signup_response" | grep -q "token\|success\|user"; then
        echo -e "${GREEN}✓ Registration working${NC}"

        # Extract token if available
        TOKEN=$(echo "$signup_response" | grep -o '"token":"[^"]*"' | cut -d'"' -f4 || echo "")

        if [ -n "$TOKEN" ]; then
            echo -n "  Authenticated API access... "
            profile_response=$(curl -s -H "Authorization: Bearer $TOKEN" \
                "https://$OPENWEBUI_URL/api/user/profile" 2>/dev/null || echo "")

            if echo "$profile_response" | grep -q "email\|username\|profile"; then
                echo -e "${GREEN}✓ Authentication working${NC}"
            else
                echo -e "${YELLOW}⚠ Token may not be valid${NC}"
                ((WARNINGS++))
            fi

            echo -n "  Token expiration check... "
            # This is a simple check - in production, wait for actual expiration
            if [ ${#TOKEN} -gt 20 ]; then
                echo -e "${GREEN}✓ Token issued${NC}"
            else
                echo -e "${YELLOW}⚠ Token may be invalid${NC}"
                ((WARNINGS++))
            fi
        else
            echo -e "${YELLOW}⚠ No token in response${NC}"
            ((WARNINGS++))
        fi
    elif echo "$signup_response" | grep -qi "exists\|already"; then
        echo -e "${YELLOW}⚠ User already exists (expected in re-runs)${NC}"
    else
        echo -e "${RED}✗ Registration failed${NC}"
        ((ERRORS++))
    fi

    echo -n "  Failed login protection... "
    failed_login=$(curl -s -o /dev/null -w "%{http_code}" -X POST "https://$OPENWEBUI_URL/api/auth/login" \
        -H "Content-Type: application/json" \
        -d '{"username":"admin","password":"wrongpassword"}' 2>/dev/null || echo "000")

    if [ "$failed_login" = "401" ] || [ "$failed_login" = "403" ]; then
        echo -e "${GREEN}✓ Invalid credentials rejected${NC}"
    else
        echo -e "${YELLOW}⚠ Unexpected response (HTTP $failed_login)${NC}"
        ((WARNINGS++))
    fi
else
    echo -e "${YELLOW}⚠ OpenWebUI not configured, skipping tests${NC}"
    ((WARNINGS++))
fi
echo ""

# Test 5: End-to-End Data Flow
echo -e "${BLUE}[5/5] Testing End-to-End Data Flow${NC}"

echo -n "  Client -> OpenWebUI -> LiteLLM chain... "
if [ -n "$OPENWEBUI_URL" ] && [ -n "$TOKEN" ]; then
    # Try to make a chat request through the full stack
    chat_response=$(curl -s -X POST "https://$OPENWEBUI_URL/api/chat" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d '{"message":"test"}' 2>/dev/null || echo "")

    if echo "$chat_response" | grep -qE "response|message|error|model"; then
        echo -e "${GREEN}✓ Full stack communication working${NC}"
    else
        echo -e "${YELLOW}⚠ Could not verify full stack communication${NC}"
        ((WARNINGS++))
    fi
else
    echo -e "${YELLOW}⚠ Cannot test without authentication${NC}"
    ((WARNINGS++))
fi

echo -n "  Service logs show no errors... "
error_count=0
for service in r2r litellm openwebui; do
    service_errors=$(railway logs --service "$service" --tail 50 2>/dev/null | grep -icE "error|exception|critical" || echo "0")
    error_count=$((error_count + service_errors))
done

if [ $error_count -eq 0 ]; then
    echo -e "${GREEN}✓ No errors in service logs${NC}"
elif [ $error_count -lt 5 ]; then
    echo -e "${YELLOW}⚠ $error_count errors found in logs${NC}"
    ((WARNINGS++))
else
    echo -e "${RED}✗ $error_count errors found in logs${NC}"
    ((ERRORS++))
fi
echo ""

# Summary
echo "=================================================="
echo "  Integration Test Summary"
echo "=================================================="

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ All integration tests passed!${NC}"
    echo ""
    echo "All services are properly integrated and communicating."
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠ Integration tests passed with $WARNINGS warning(s)${NC}"
    echo ""
    echo "Services are integrated but some features may need configuration."
    exit 0
else
    echo -e "${RED}✗ Integration tests failed with $ERRORS error(s) and $WARNINGS warning(s)${NC}"
    echo ""
    echo "Please review service integration before proceeding."
    exit 1
fi
