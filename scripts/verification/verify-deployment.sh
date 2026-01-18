#!/bin/bash

# Railway Deployment Verification Orchestrator
# Runs all verification scripts in the correct order

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORT_FILE="${REPORT_FILE:-$SCRIPT_DIR/verification-report-$(date +%Y%m%d_%H%M%S).txt}"

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNINGS=0

# Report generation
init_report() {
    cat > "$REPORT_FILE" << EOF
========================================
Railway Deployment Verification Report
========================================
Date: $(date)
Environment: Production
Report: $REPORT_FILE

EOF
}

append_report() {
    echo "$1" >> "$REPORT_FILE"
}

show_help() {
    cat << EOF
Railway Deployment Verification Orchestrator

Usage: $0 [options] [phase]

Phases:
    pre-deploy     Run pre-deployment checks only
    config         Run configuration validation only
    health         Run health checks only
    security       Run security tests only
    integration    Run integration tests only
    monitoring     Run monitoring checks only
    full           Run all verification phases (default)

Options:
    --skip-pre-deploy    Skip pre-deployment checks
    --skip-security      Skip security tests
    --skip-integration   Skip integration tests
    --continue-on-error  Continue even if a phase fails
    --report <file>      Specify custom report file path
    --help               Show this help message

Examples:
    $0                              # Run full verification
    $0 pre-deploy                   # Run only pre-deployment checks
    $0 --skip-integration full      # Run all except integration tests
    $0 --continue-on-error full     # Continue even on failures

EOF
}

print_header() {
    local title=$1
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}${BOLD}  $title${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
}

run_check() {
    local name=$1
    local script=$2
    local phase=$3

    ((TOTAL_CHECKS++))

    print_header "$name"
    append_report "[$phase] $name"
    append_report "----------------------------------------"

    if [ ! -f "$script" ]; then
        echo -e "${RED}✗ Script not found: $script${NC}"
        append_report "ERROR: Script not found"
        ((FAILED_CHECKS++))
        return 1
    fi

    chmod +x "$script"

    # Run script and capture output
    if output=$("$script" 2>&1); then
        echo -e "${GREEN}✓ $name completed successfully${NC}"
        append_report "✓ PASSED"
        ((PASSED_CHECKS++))
        return 0
    else
        exit_code=$?
        echo -e "${YELLOW}⚠ $name completed with warnings or errors${NC}"
        append_report "⚠ COMPLETED WITH WARNINGS (exit code: $exit_code)"

        # Check if there were only warnings
        if echo "$output" | grep -q "warning"; then
            ((WARNINGS++))
            ((PASSED_CHECKS++))
            return 0
        else
            ((FAILED_CHECKS++))
            return 1
        fi
    fi
}

# Parse arguments
SKIP_PRE_DEPLOY=false
SKIP_SECURITY=false
SKIP_INTEGRATION=false
CONTINUE_ON_ERROR=false
PHASE="full"

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-pre-deploy)
            SKIP_PRE_DEPLOY=true
            shift
            ;;
        --skip-security)
            SKIP_SECURITY=true
            shift
            ;;
        --skip-integration)
            SKIP_INTEGRATION=true
            shift
            ;;
        --continue-on-error)
            CONTINUE_ON_ERROR=true
            shift
            ;;
        --report)
            REPORT_FILE="$2"
            shift 2
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        pre-deploy|config|health|security|integration|monitoring|full)
            PHASE=$1
            shift
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# Initialize report
init_report

# Print banner
clear
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║   Railway Deployment Verification System                 ║
║   Comprehensive Security & Integration Testing           ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF

echo ""
echo -e "${BOLD}Starting verification process...${NC}"
echo -e "Phase: ${CYAN}$PHASE${NC}"
echo -e "Report: ${CYAN}$REPORT_FILE${NC}"
echo ""

# Phase 1: Pre-Deployment Checks
if [ "$PHASE" = "full" ] || [ "$PHASE" = "pre-deploy" ]; then
    if [ "$SKIP_PRE_DEPLOY" = false ]; then
        if ! run_check "Pre-Deployment Security Checks" \
            "$SCRIPT_DIR/pre-deployment/01-secrets-check.sh" \
            "PRE-DEPLOY"; then
            if [ "$CONTINUE_ON_ERROR" = false ]; then
                echo -e "${RED}Pre-deployment checks failed. Aborting.${NC}"
                exit 1
            fi
        fi
    fi
fi

# Phase 2: Configuration Validation
if [ "$PHASE" = "full" ] || [ "$PHASE" = "config" ]; then
    if ! run_check "Configuration Validation" \
        "$SCRIPT_DIR/config/01-env-validation.sh" \
        "CONFIG"; then
        if [ "$CONTINUE_ON_ERROR" = false ]; then
            echo -e "${RED}Configuration validation failed. Aborting.${NC}"
            exit 1
        fi
    fi
fi

# Phase 3: Health Checks
if [ "$PHASE" = "full" ] || [ "$PHASE" = "health" ]; then
    if ! run_check "Service Health Checks" \
        "$SCRIPT_DIR/health/01-service-health.sh" \
        "HEALTH"; then
        if [ "$CONTINUE_ON_ERROR" = false ]; then
            echo -e "${RED}Health checks failed. Aborting.${NC}"
            exit 1
        fi
    fi
fi

# Phase 4: Security Tests
if [ "$PHASE" = "full" ] || [ "$PHASE" = "security" ]; then
    if [ "$SKIP_SECURITY" = false ]; then
        if ! run_check "Security Testing" \
            "$SCRIPT_DIR/security/01-service-security-tests.sh" \
            "SECURITY"; then
            if [ "$CONTINUE_ON_ERROR" = false ]; then
                echo -e "${RED}Security tests failed. Aborting.${NC}"
                exit 1
            fi
        fi
    fi
fi

# Phase 5: Integration Tests
if [ "$PHASE" = "full" ] || [ "$PHASE" = "integration" ]; then
    if [ "$SKIP_INTEGRATION" = false ]; then
        if ! run_check "Integration Testing" \
            "$SCRIPT_DIR/integration/01-integration-tests.sh" \
            "INTEGRATION"; then
            if [ "$CONTINUE_ON_ERROR" = false ]; then
                echo -e "${RED}Integration tests failed. Aborting.${NC}"
                exit 1
            fi
        fi
    fi
fi

# Phase 6: Monitoring Setup
if [ "$PHASE" = "full" ] || [ "$PHASE" = "monitoring" ]; then
    if ! run_check "Security Monitoring" \
        "$SCRIPT_DIR/monitoring/01-continuous-monitoring.sh" \
        "MONITORING"; then
        # Monitoring can fail without stopping deployment
        echo -e "${YELLOW}⚠ Monitoring checks completed with warnings${NC}"
    fi
fi

# Generate Final Report
print_header "Verification Summary"

summary="
========================================
Final Summary
========================================
Total Checks: $TOTAL_CHECKS
Passed: $PASSED_CHECKS
Failed: $FAILED_CHECKS
Warnings: $WARNINGS

Status: "

if [ $FAILED_CHECKS -eq 0 ]; then
    if [ $WARNINGS -eq 0 ]; then
        summary+="✓ ALL CHECKS PASSED"
        status_color=$GREEN
        exit_code=0
    else
        summary+="⚠ PASSED WITH WARNINGS"
        status_color=$YELLOW
        exit_code=0
    fi
else
    summary+="✗ VERIFICATION FAILED"
    status_color=$RED
    exit_code=1
fi

summary+="
========================================

Report saved to: $REPORT_FILE
"

echo -e "${status_color}$summary${NC}"
append_report "$summary"

# Additional recommendations
if [ $exit_code -eq 0 ]; then
    echo -e "${GREEN}${BOLD}✓ Deployment verification successful!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Review the full report: $REPORT_FILE"
    if [ $WARNINGS -gt 0 ]; then
        echo "  2. Address the $WARNINGS warning(s) when possible"
        echo "  3. Set up continuous monitoring with: scripts/verification/monitoring/01-continuous-monitoring.sh"
        echo "  4. Create a backup before major changes: scripts/verification/backup/01-backup-restore.sh backup"
    else
        echo "  2. Set up continuous monitoring with: scripts/verification/monitoring/01-continuous-monitoring.sh"
        echo "  3. Create a backup before major changes: scripts/verification/backup/01-backup-restore.sh backup"
    fi
    echo ""
else
    echo -e "${RED}${BOLD}✗ Deployment verification failed!${NC}"
    echo ""
    echo "Required actions:"
    echo "  1. Review the full report: $REPORT_FILE"
    echo "  2. Fix all critical errors"
    echo "  3. Re-run verification: $0"
    echo ""
fi

exit $exit_code
