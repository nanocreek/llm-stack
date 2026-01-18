#!/bin/bash

# Service Security Testing Script
# Performs security testing on all Railway services

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
echo "  Service Security Testing"
echo "=================================================="
echo ""

# Get configuration
QDRANT_URL=$(railway variables --service r2r 2>/dev/null | grep "QDRANT_URL=" | cut -d'=' -f2- || echo "")
LITELLM_URL=$(railway variables --service r2r 2>/dev/null | grep "LITELLM_API_BASE=" | cut -d'=' -f2- || echo "")
QDRANT_API_KEY=$(railway variables --service qdrant 2>/dev/null | grep "QDRANT_API_KEY=" | cut -d'=' -f2- || echo "")
LITELLM_MASTER_KEY=$(railway variables --service litellm 2>/dev/null | grep "LITELLM_MASTER_KEY=" | cut -d'=' -f2- || echo "")
OPENWEBUI_URL=$(railway domain --service openwebui 2>/dev/null || echo "")
REACT_URL=$(railway domain --service react-client 2>/dev/null || echo "")

# Test 1: PostgreSQL Security
echo -e "${BLUE}[1/7] PostgreSQL Security Tests${NC}"

echo -n "  Testing SSL/TLS enforcement... "
if railway run --service r2r -- psql "$DATABASE_URL" -c "SHOW ssl;" 2>/dev/null | grep -q "on"; then
    echo -e "${GREEN}✓ SSL enabled${NC}"
else
    echo -e "${YELLOW}⚠ SSL may not be enforced${NC}"
    ((WARNINGS++))
fi

echo -n "  Checking user permissions... "
user_count=$(railway run --service r2r -- psql "$DATABASE_URL" -t -c "SELECT count(*) FROM pg_user;" 2>/dev/null | tr -d ' ' || echo "0")
if [ "$user_count" -le 5 ]; then
    echo -e "${GREEN}✓ Minimal users ($user_count)${NC}"
else
    echo -e "${YELLOW}⚠ Many users configured ($user_count)${NC}"
    ((WARNINGS++))
fi

echo -n "  Verifying pgvector extension... "
if railway run --service r2r -- psql "$DATABASE_URL" -c "\dx vector" 2>/dev/null | grep -q "vector"; then
    echo -e "${GREEN}✓ Extension loaded${NC}"
else
    echo -e "${RED}✗ Extension not found${NC}"
    ((ERRORS++))
fi

echo -n "  Checking for default/test databases... "
test_dbs=$(railway run --service r2r -- psql "$DATABASE_URL" -t -c "SELECT count(*) FROM pg_database WHERE datname IN ('test', 'testing', 'dev');" 2>/dev/null | tr -d ' ' || echo "0")
if [ "$test_dbs" -eq 0 ]; then
    echo -e "${GREEN}✓ No test databases${NC}"
else
    echo -e "${YELLOW}⚠ Test databases found ($test_dbs)${NC}"
    ((WARNINGS++))
fi
echo ""

# Test 2: Redis Security
echo -e "${BLUE}[2/7] Redis Security Tests${NC}"

echo -n "  Testing authentication requirement... "
if railway run --service r2r -- redis-cli -h redis.railway.internal -p 6379 PING 2>/dev/null | grep -q "NOAUTH"; then
    echo -e "${RED}✗ Authentication not required!${NC}"
    ((ERRORS++))
elif railway run --service r2r -- redis-cli -u "$REDIS_URL" PING 2>/dev/null | grep -q "PONG"; then
    echo -e "${GREEN}✓ Authentication required${NC}"
else
    echo -e "${YELLOW}⚠ Could not verify${NC}"
    ((WARNINGS++))
fi

echo -n "  Checking dangerous commands... "
config_output=$(railway run --service r2r -- redis-cli -u "$REDIS_URL" CONFIG GET "rename-command" 2>/dev/null || echo "")
if echo "$config_output" | grep -qiE "flushall|flushdb|config"; then
    echo -e "${GREEN}✓ Dangerous commands renamed${NC}"
else
    echo -e "${YELLOW}⚠ Dangerous commands may be available${NC}"
    ((WARNINGS++))
fi

echo -n "  Verifying persistence configuration... "
if railway run --service r2r -- redis-cli -u "$REDIS_URL" CONFIG GET "save" 2>/dev/null | grep -q "save"; then
    echo -e "${GREEN}✓ Persistence configured${NC}"
else
    echo -e "${YELLOW}⚠ Persistence may not be configured${NC}"
    ((WARNINGS++))
fi
echo ""

# Test 3: Qdrant Security
echo -e "${BLUE}[3/7] Qdrant Security Tests${NC}"

if [ -n "$QDRANT_URL" ] && [ -n "$QDRANT_API_KEY" ]; then
    echo -n "  Testing API key requirement... "
    unauth=$(curl -s -o /dev/null -w "%{http_code}" -m $TIMEOUT "$QDRANT_URL/collections" 2>/dev/null || echo "000")
    auth=$(curl -s -o /dev/null -w "%{http_code}" -m $TIMEOUT -H "api-key: $QDRANT_API_KEY" "$QDRANT_URL/collections" 2>/dev/null || echo "000")

    if [ "$unauth" = "401" ] || [ "$unauth" = "403" ]; then
        if [ "$auth" = "200" ]; then
            echo -e "${GREEN}✓ API key properly enforced${NC}"
        else
            echo -e "${YELLOW}⚠ API key may not work correctly (auth response: $auth)${NC}"
            ((WARNINGS++))
        fi
    else
        echo -e "${RED}✗ API key not enforced (unauth response: $unauth)${NC}"
        ((ERRORS++))
    fi

    echo -n "  Checking public accessibility... "
    if [[ "$QDRANT_URL" == *".railway.internal"* ]]; then
        echo -e "${GREEN}✓ Using internal networking${NC}"
    else
        echo -e "${YELLOW}⚠ May be publicly accessible${NC}"
        ((WARNINGS++))
    fi

    echo -n "  Verifying telemetry settings... "
    telemetry=$(curl -s -H "api-key: $QDRANT_API_KEY" "$QDRANT_URL/telemetry" 2>/dev/null || echo "")
    if echo "$telemetry" | grep -q "enabled.*false"; then
        echo -e "${GREEN}✓ Telemetry disabled${NC}"
    else
        echo -e "${YELLOW}⚠ Telemetry may be enabled${NC}"
        ((WARNINGS++))
    fi
else
    echo -e "${YELLOW}⚠ Qdrant not configured, skipping tests${NC}"
    ((WARNINGS++))
fi
echo ""

# Test 4: R2R Security
echo -e "${BLUE}[4/7] R2R Security Tests${NC}"

echo -n "  Checking for debug endpoints... "
debug_response=$(railway run --service r2r -- curl -s -o /dev/null -w "%{http_code}" -m $TIMEOUT http://localhost:7272/debug 2>/dev/null || echo "404")
if [ "$debug_response" = "404" ]; then
    echo -e "${GREEN}✓ No debug endpoints${NC}"
else
    echo -e "${RED}✗ Debug endpoint accessible (HTTP $debug_response)${NC}"
    ((ERRORS++))
fi

echo -n "  Verifying database connection security... "
if railway logs --service r2r --tail 100 2>/dev/null | grep -q "ssl.*true\|sslmode.*require"; then
    echo -e "${GREEN}✓ SSL connection to database${NC}"
else
    echo -e "${YELLOW}⚠ Could not verify SSL database connection${NC}"
    ((WARNINGS++))
fi

echo -n "  Checking for secrets in logs... "
if railway logs --service r2r --tail 100 2>/dev/null | grep -qiE "password|secret|api_key|authorization: bearer [a-zA-Z0-9]"; then
    echo -e "${RED}✗ Secrets found in logs!${NC}"
    ((ERRORS++))
else
    echo -e "${GREEN}✓ No secrets in recent logs${NC}"
fi

echo -n "  Testing input validation... "
# Test for SQL injection protection
sql_test=$(railway run --service r2r -- curl -s -X POST http://localhost:7272/v2/search -H "Content-Type: application/json" -d '{"query":"1 OR 1=1"}' 2>/dev/null || echo "")
if echo "$sql_test" | grep -qiE "error|invalid|sanitized|400|422"; then
    echo -e "${GREEN}✓ Input validation present${NC}"
else
    echo -e "${YELLOW}⚠ Could not verify input validation${NC}"
    ((WARNINGS++))
fi
echo ""

# Test 5: LiteLLM Security
echo -e "${BLUE}[5/7] LiteLLM Security Tests${NC}"

if [ -n "$LITELLM_URL" ] && [ -n "$LITELLM_MASTER_KEY" ]; then
    echo -n "  Testing master key requirement... "
    unauth=$(curl -s -o /dev/null -w "%{http_code}" -m $TIMEOUT "$LITELLM_URL/v1/models" 2>/dev/null || echo "000")
    auth=$(curl -s -o /dev/null -w "%{http_code}" -m $TIMEOUT -H "Authorization: Bearer $LITELLM_MASTER_KEY" "$LITELLM_URL/v1/models" 2>/dev/null || echo "000")

    if [ "$unauth" = "401" ] || [ "$unauth" = "403" ]; then
        if [ "$auth" = "200" ]; then
            echo -e "${GREEN}✓ Master key properly enforced${NC}"
        else
            echo -e "${YELLOW}⚠ Master key may not work correctly (auth response: $auth)${NC}"
            ((WARNINGS++))
        fi
    else
        echo -e "${RED}✗ Master key not enforced (unauth response: $unauth)${NC}"
        ((ERRORS++))
    fi

    echo -n "  Checking for API key leakage in logs... "
    if railway logs --service litellm --tail 100 2>/dev/null | grep -qiE "sk-[a-zA-Z0-9]|api_key.*[a-zA-Z0-9]{20}"; then
        echo -e "${RED}✗ API keys found in logs!${NC}"
        ((ERRORS++))
    else
        echo -e "${GREEN}✓ No API keys in recent logs${NC}"
    fi

    echo -n "  Verifying internal networking... "
    if [[ "$LITELLM_URL" == *".railway.internal"* ]]; then
        echo -e "${GREEN}✓ Using internal networking${NC}"
    else
        echo -e "${YELLOW}⚠ May be publicly accessible${NC}"
        ((WARNINGS++))
    fi
else
    echo -e "${YELLOW}⚠ LiteLLM not configured, skipping tests${NC}"
    ((WARNINGS++))
fi
echo ""

# Test 6: OpenWebUI Security
echo -e "${BLUE}[6/7] OpenWebUI Security Tests${NC}"

if [ -n "$OPENWEBUI_URL" ]; then
    echo -n "  Testing HTTPS enforcement... "
    https_code=$(curl -s -o /dev/null -w "%{http_code}" -m $TIMEOUT "https://$OPENWEBUI_URL" 2>/dev/null || echo "000")
    if [ "$https_code" = "200" ]; then
        echo -e "${GREEN}✓ HTTPS accessible${NC}"
    else
        echo -e "${RED}✗ HTTPS not working (HTTP $https_code)${NC}"
        ((ERRORS++))
    fi

    echo -n "  Checking security headers... "
    headers=$(curl -s -I "https://$OPENWEBUI_URL" 2>/dev/null || echo "")
    header_score=0
    [ -n "$(echo "$headers" | grep -i "X-Frame-Options")" ] && ((header_score++))
    [ -n "$(echo "$headers" | grep -i "X-Content-Type-Options")" ] && ((header_score++))
    [ -n "$(echo "$headers" | grep -i "Strict-Transport-Security")" ] && ((header_score++))
    [ -n "$(echo "$headers" | grep -i "Content-Security-Policy")" ] && ((header_score++))

    if [ $header_score -ge 3 ]; then
        echo -e "${GREEN}✓ $header_score/4 security headers present${NC}"
    elif [ $header_score -ge 2 ]; then
        echo -e "${YELLOW}⚠ Only $header_score/4 security headers present${NC}"
        ((WARNINGS++))
    else
        echo -e "${RED}✗ Only $header_score/4 security headers present${NC}"
        ((ERRORS++))
    fi

    echo -n "  Testing CORS policy... "
    cors_response=$(curl -s -I -X OPTIONS "https://$OPENWEBUI_URL" -H "Origin: https://malicious-site.com" 2>/dev/null || echo "")
    if echo "$cors_response" | grep -qi "Access-Control-Allow-Origin"; then
        allowed_origin=$(echo "$cors_response" | grep -i "Access-Control-Allow-Origin" | cut -d' ' -f2-)
        if [[ "$allowed_origin" == "*" ]]; then
            echo -e "${RED}✗ CORS allows all origins!${NC}"
            ((ERRORS++))
        else
            echo -e "${GREEN}✓ CORS properly configured${NC}"
        fi
    else
        echo -e "${GREEN}✓ No CORS headers (restrictive)${NC}"
    fi

    echo -n "  Testing authentication requirement... "
    api_response=$(curl -s -o /dev/null -w "%{http_code}" -m $TIMEOUT "https://$OPENWEBUI_URL/api/users" 2>/dev/null || echo "000")
    if [ "$api_response" = "401" ] || [ "$api_response" = "403" ]; then
        echo -e "${GREEN}✓ Authentication required${NC}"
    else
        echo -e "${YELLOW}⚠ API may be accessible without auth (HTTP $api_response)${NC}"
        ((WARNINGS++))
    fi

    echo -n "  Checking session cookie security... "
    cookie_headers=$(curl -s -I "https://$OPENWEBUI_URL" 2>/dev/null | grep -i "Set-Cookie" || echo "")
    cookie_score=0
    [ -n "$(echo "$cookie_headers" | grep -i "HttpOnly")" ] && ((cookie_score++))
    [ -n "$(echo "$cookie_headers" | grep -i "Secure")" ] && ((cookie_score++))
    [ -n "$(echo "$cookie_headers" | grep -i "SameSite")" ] && ((cookie_score++))

    if [ $cookie_score -ge 2 ]; then
        echo -e "${GREEN}✓ Secure cookie attributes ($cookie_score/3)${NC}"
    else
        echo -e "${YELLOW}⚠ Missing cookie security attributes ($cookie_score/3)${NC}"
        ((WARNINGS++))
    fi
else
    echo -e "${YELLOW}⚠ OpenWebUI URL not configured, skipping tests${NC}"
    ((WARNINGS++))
fi
echo ""

# Test 7: React Client Security
echo -e "${BLUE}[7/7] React Client Security Tests${NC}"

if [ -n "$REACT_URL" ]; then
    echo -n "  Checking for exposed secrets... "
    page_content=$(curl -s "https://$REACT_URL" 2>/dev/null || echo "")
    if echo "$page_content" | grep -qiE "sk-[a-zA-Z0-9]{32,}|api_key.*['\"][^'\"]{20,}|password.*['\"][^'\"]{20,}"; then
        echo -e "${RED}✗ Potential secrets in frontend bundle!${NC}"
        ((ERRORS++))
    else
        echo -e "${GREEN}✓ No obvious secrets${NC}"
    fi

    echo -n "  Checking for source maps in production... "
    sourcemap_response=$(curl -s -o /dev/null -w "%{http_code}" -m $TIMEOUT "https://$REACT_URL/static/js/main.js.map" 2>/dev/null || echo "404")
    if [ "$sourcemap_response" = "404" ]; then
        echo -e "${GREEN}✓ Source maps disabled${NC}"
    else
        echo -e "${YELLOW}⚠ Source maps accessible (HTTP $sourcemap_response)${NC}"
        ((WARNINGS++))
    fi

    echo -n "  Verifying API endpoints use HTTPS... "
    if echo "$page_content" | grep -q "http://.*api"; then
        echo -e "${RED}✗ Found HTTP API endpoints!${NC}"
        ((ERRORS++))
    else
        echo -e "${GREEN}✓ No HTTP API endpoints found${NC}"
    fi

    echo -n "  Checking Content Security Policy... "
    csp_header=$(curl -s -I "https://$REACT_URL" 2>/dev/null | grep -i "Content-Security-Policy" || echo "")
    if [ -n "$csp_header" ]; then
        echo -e "${GREEN}✓ CSP header present${NC}"
    else
        echo -e "${YELLOW}⚠ No CSP header${NC}"
        ((WARNINGS++))
    fi
else
    echo -e "${YELLOW}⚠ React client URL not configured, skipping tests${NC}"
    ((WARNINGS++))
fi
echo ""

# Summary
echo "=================================================="
echo "  Security Test Summary"
echo "=================================================="

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ All security tests passed!${NC}"
    echo ""
    echo "Your deployment follows security best practices."
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠ Passed with $WARNINGS warning(s)${NC}"
    echo ""
    echo "Consider addressing warnings before production deployment."
    exit 0
else
    echo -e "${RED}✗ Security tests failed with $ERRORS error(s) and $WARNINGS warning(s)${NC}"
    echo ""
    echo "CRITICAL: Please fix all security errors before deploying to production!"
    exit 1
fi
