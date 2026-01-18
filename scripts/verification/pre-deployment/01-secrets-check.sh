#!/bin/bash

# Pre-Deployment Secrets Security Check
# Checks for exposed secrets, credentials, and sensitive data

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ERRORS=0
WARNINGS=0

echo "=================================================="
echo "  Pre-Deployment Secrets Security Check"
echo "=================================================="
echo ""

# Check 1: Scan for exposed secrets in codebase
echo "[1/6] Scanning for exposed secrets in codebase..."
cd "$PROJECT_ROOT"

# Patterns to search for
PATTERNS=(
    "password['\"]?\s*[:=]"
    "secret['\"]?\s*[:=]"
    "api_key['\"]?\s*[:=]"
    "apikey['\"]?\s*[:=]"
    "token['\"]?\s*[:=]"
    "auth['\"]?\s*[:=]"
    "bearer['\"]?\s*[:=]"
    "sk-[a-zA-Z0-9]{32,}"
    "ghp_[a-zA-Z0-9]{36,}"
    "xox[baprs]-[a-zA-Z0-9-]+"
)

for pattern in "${PATTERNS[@]}"; do
    results=$(grep -riE "$pattern" --include="*.py" --include="*.js" --include="*.ts" --include="*.jsx" --include="*.tsx" --include="*.env*" --exclude-dir=node_modules --exclude-dir=venv --exclude-dir=.git --exclude-dir=build --exclude-dir=dist . 2>/dev/null || true)

    if [ -n "$results" ]; then
        echo -e "${RED}✗ Found potential secrets matching pattern: $pattern${NC}"
        echo "$results" | head -5
        ((ERRORS++))
    fi
done

if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✓ No exposed secrets found in codebase${NC}"
fi

# Check 2: Verify no .env files are committed
echo ""
echo "[2/6] Checking for committed .env files..."
env_files=$(git ls-files | grep -E "\.env$|\.env\." || true)

if [ -n "$env_files" ]; then
    echo -e "${RED}✗ Found committed .env files:${NC}"
    echo "$env_files"
    ((ERRORS++))
else
    echo -e "${GREEN}✓ No .env files committed to repository${NC}"
fi

# Check 3: Check .gitignore contains proper entries
echo ""
echo "[3/6] Verifying .gitignore security entries..."
if [ -f .gitignore ]; then
    required_entries=(".env" ".env.local" ".env.*.local" "*.pem" "*.key" "*.crt" "credentials.json" "secrets.yaml")
    missing_entries=()

    for entry in "${required_entries[@]}"; do
        if ! grep -q "$entry" .gitignore; then
            missing_entries+=("$entry")
        fi
    done

    if [ ${#missing_entries[@]} -gt 0 ]; then
        echo -e "${YELLOW}⚠ Missing .gitignore entries:${NC}"
        printf '%s\n' "${missing_entries[@]}"
        ((WARNINGS++))
    else
        echo -e "${GREEN}✓ .gitignore contains all required security entries${NC}"
    fi
else
    echo -e "${RED}✗ .gitignore file not found${NC}"
    ((ERRORS++))
fi

# Check 4: Scan for hardcoded credentials patterns
echo ""
echo "[4/6] Scanning for hardcoded credentials..."
hardcoded_patterns=(
    "password\s*=\s*['\"][^'\"]+['\"]"
    "api_key\s*=\s*['\"][^'\"]+['\"]"
    "secret\s*=\s*['\"][^'\"]+['\"]"
    "token\s*=\s*['\"][^'\"]+['\"]"
)

hardcoded_found=false
for pattern in "${hardcoded_patterns[@]}"; do
    results=$(grep -riE "$pattern" --include="*.py" --include="*.js" --include="*.ts" --exclude-dir=node_modules --exclude-dir=venv --exclude-dir=.git --exclude-dir=build --exclude-dir=dist --exclude-dir=scripts . 2>/dev/null || true)

    if [ -n "$results" ]; then
        echo -e "${RED}✗ Found hardcoded credentials:${NC}"
        echo "$results" | head -3
        hardcoded_found=true
        ((ERRORS++))
    fi
done

if [ "$hardcoded_found" = false ]; then
    echo -e "${GREEN}✓ No hardcoded credentials found${NC}"
fi

# Check 5: Verify Railway CLI is installed and authenticated
echo ""
echo "[5/6] Checking Railway CLI setup..."
if command -v railway &> /dev/null; then
    echo -e "${GREEN}✓ Railway CLI installed${NC}"

    # Check if authenticated
    if railway whoami &> /dev/null; then
        echo -e "${GREEN}✓ Railway CLI authenticated${NC}"
    else
        echo -e "${YELLOW}⚠ Railway CLI not authenticated${NC}"
        echo "  Run: railway login"
        ((WARNINGS++))
    fi
else
    echo -e "${RED}✗ Railway CLI not installed${NC}"
    echo "  Install: npm i -g @railway/cli"
    ((ERRORS++))
fi

# Check 6: Check for placeholder values in config files
echo ""
echo "[6/6] Checking for placeholder values in configuration..."
placeholder_patterns=(
    "changeme"
    "password123"
    "admin123"
    "secret123"
    "replace_me"
    "your_.*_here"
    "REPLACE_WITH"
)

placeholder_found=false
for pattern in "${placeholder_patterns[@]}"; do
    results=$(grep -riE "$pattern" --include="*.yaml" --include="*.yml" --include="*.toml" --include="*.json" --include="*.env.example" --exclude-dir=node_modules --exclude-dir=venv --exclude-dir=.git . 2>/dev/null || true)

    if [ -n "$results" ]; then
        echo -e "${YELLOW}⚠ Found placeholder values:${NC}"
        echo "$results" | head -3
        placeholder_found=true
        ((WARNINGS++))
    fi
done

if [ "$placeholder_found" = false ]; then
    echo -e "${GREEN}✓ No placeholder values found in configuration files${NC}"
fi

# Summary
echo ""
echo "=================================================="
echo "  Summary"
echo "=================================================="
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ All secrets security checks passed!${NC}"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠ Passed with $WARNINGS warning(s)${NC}"
    exit 0
else
    echo -e "${RED}✗ Failed with $ERRORS error(s) and $WARNINGS warning(s)${NC}"
    echo ""
    echo "Please fix the errors before deploying to Railway."
    exit 1
fi
