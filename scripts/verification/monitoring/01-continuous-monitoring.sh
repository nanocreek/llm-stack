#!/bin/bash

# Continuous Security Monitoring Script
# Monitors Railway services for security issues and anomalies

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${LOG_FILE:-$SCRIPT_DIR/security-monitoring.log}"
ALERT_THRESHOLD_ERRORS=10
ALERT_THRESHOLD_AUTH_FAILURES=20
MONITORING_WINDOW_HOURS=24

echo "=================================================="
echo "  Security Monitoring"
echo "  $(date)"
echo "=================================================="
echo ""

# Initialize log file
touch "$LOG_FILE"

# Function to log with timestamp
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to send alert (customize for your alerting system)
send_alert() {
    local severity=$1
    local message=$2

    log_message "ALERT [$severity]: $message"

    # Uncomment and configure for your alerting system
    # echo "$message" | mail -s "Security Alert: $severity" admin@example.com
    # curl -X POST https://hooks.slack.com/services/YOUR/WEBHOOK/URL -d "{\"text\":\"$message\"}"
}

log_message "Starting security monitoring check"

# Monitor 1: Failed Authentication Attempts
echo -e "${BLUE}[1/8] Monitoring Authentication Failures${NC}"
auth_failures=0

for service in openwebui r2r litellm; do
    failures=$(railway logs --service "$service" --since "${MONITORING_WINDOW_HOURS}h" 2>/dev/null | \
        grep -icE "authentication failed|invalid credentials|unauthorized|401|403" || echo "0")

    if [ "$failures" -gt 0 ]; then
        log_message "$service: $failures authentication failures in last ${MONITORING_WINDOW_HOURS}h"
        auth_failures=$((auth_failures + failures))
    fi
done

if [ $auth_failures -gt $ALERT_THRESHOLD_AUTH_FAILURES ]; then
    echo -e "${RED}✗ High authentication failure rate: $auth_failures${NC}"
    send_alert "HIGH" "Detected $auth_failures failed authentication attempts in ${MONITORING_WINDOW_HOURS}h"
elif [ $auth_failures -gt 0 ]; then
    echo -e "${YELLOW}⚠ $auth_failures authentication failures detected${NC}"
else
    echo -e "${GREEN}✓ No authentication failures${NC}"
fi
echo ""

# Monitor 2: Error Rate Analysis
echo -e "${BLUE}[2/8] Monitoring Error Rates${NC}"
total_errors=0

for service in r2r litellm openwebui qdrant; do
    errors=$(railway logs --service "$service" --since "${MONITORING_WINDOW_HOURS}h" 2>/dev/null | \
        grep -icE "error|exception|critical|fatal" || echo "0")

    if [ "$errors" -gt 0 ]; then
        log_message "$service: $errors errors in last ${MONITORING_WINDOW_HOURS}h"
        total_errors=$((total_errors + errors))

        if [ "$errors" -gt $ALERT_THRESHOLD_ERRORS ]; then
            echo -e "${RED}✗ $service: High error rate ($errors)${NC}"
            send_alert "MEDIUM" "$service has $errors errors in ${MONITORING_WINDOW_HOURS}h"
        else
            echo -e "${YELLOW}⚠ $service: $errors errors${NC}"
        fi
    else
        echo -e "${GREEN}✓ $service: No errors${NC}"
    fi
done

if [ $total_errors -eq 0 ]; then
    log_message "No errors detected across all services"
fi
echo ""

# Monitor 3: Service Health Status
echo -e "${BLUE}[3/8] Checking Service Health${NC}"
unhealthy_services=0

services=("postgres-pgvector" "redis" "qdrant" "r2r" "litellm" "openwebui" "react-client")
for service in "${services[@]}"; do
    status=$(railway status --service "$service" 2>/dev/null | grep -oiE "success|failed|crashed|deploying" || echo "unknown")

    case "$status" in
        *success*|*active*|*running*)
            echo -e "${GREEN}✓ $service: Healthy${NC}"
            ;;
        *deploying*|*building*)
            echo -e "${YELLOW}⚠ $service: Deploying${NC}"
            log_message "$service is currently deploying"
            ;;
        *failed*|*crashed*)
            echo -e "${RED}✗ $service: Unhealthy${NC}"
            ((unhealthy_services++))
            send_alert "HIGH" "$service is unhealthy: $status"
            ;;
        *)
            echo -e "${YELLOW}⚠ $service: Unknown status${NC}"
            log_message "$service has unknown status"
            ;;
    esac
done

if [ $unhealthy_services -gt 0 ]; then
    send_alert "CRITICAL" "$unhealthy_services service(s) are unhealthy"
fi
echo ""

# Monitor 4: Database Connection Pool
echo -e "${BLUE}[4/8] Monitoring Database Connections${NC}"

db_warnings=$(railway logs --service r2r --since "${MONITORING_WINDOW_HOURS}h" 2>/dev/null | \
    grep -icE "connection pool|too many connections|database.*timeout" || echo "0")

if [ $db_warnings -gt 5 ]; then
    echo -e "${RED}✗ Database connection issues detected ($db_warnings)${NC}"
    send_alert "MEDIUM" "Database connection pool issues detected: $db_warnings occurrences"
elif [ $db_warnings -gt 0 ]; then
    echo -e "${YELLOW}⚠ $db_warnings database connection warnings${NC}"
    log_message "Database connection warnings: $db_warnings"
else
    echo -e "${GREEN}✓ No database connection issues${NC}"
fi
echo ""

# Monitor 5: Unusual Traffic Patterns
echo -e "${BLUE}[5/8] Detecting Unusual Traffic Patterns${NC}"

rate_limit_hits=$(railway logs --service openwebui --since "${MONITORING_WINDOW_HOURS}h" 2>/dev/null | \
    grep -icE "rate limit|too many requests|429" || echo "0")

if [ $rate_limit_hits -gt 50 ]; then
    echo -e "${RED}✗ High rate limiting activity: $rate_limit_hits hits${NC}"
    send_alert "MEDIUM" "Possible DDoS or abuse: $rate_limit_hits rate limit hits"
elif [ $rate_limit_hits -gt 10 ]; then
    echo -e "${YELLOW}⚠ $rate_limit_hits rate limit hits${NC}"
    log_message "Rate limiting active: $rate_limit_hits hits"
else
    echo -e "${GREEN}✓ Normal traffic patterns${NC}"
fi
echo ""

# Monitor 6: Security Event Detection
echo -e "${BLUE}[6/8] Scanning for Security Events${NC}"

security_keywords=(
    "sql injection"
    "xss"
    "command injection"
    "path traversal"
    "malicious"
    "exploit"
    "attack"
    "intrusion"
)

security_events=0
for keyword in "${security_keywords[@]}"; do
    events=$(railway logs --since "${MONITORING_WINDOW_HOURS}h" 2>/dev/null | grep -ic "$keyword" || echo "0")
    if [ $events -gt 0 ]; then
        security_events=$((security_events + events))
        log_message "Security keyword detected: '$keyword' ($events occurrences)"
    fi
done

if [ $security_events -gt 10 ]; then
    echo -e "${RED}✗ Multiple security events detected: $security_events${NC}"
    send_alert "HIGH" "Security events detected: $security_events occurrences"
elif [ $security_events -gt 0 ]; then
    echo -e "${YELLOW}⚠ $security_events potential security events${NC}"
else
    echo -e "${GREEN}✓ No security events detected${NC}"
fi
echo ""

# Monitor 7: Resource Usage Anomalies
echo -e "${BLUE}[7/8] Checking Resource Usage${NC}"

oom_events=$(railway logs --since "${MONITORING_WINDOW_HOURS}h" 2>/dev/null | \
    grep -icE "out of memory|oom|killed|memory.*exceeded" || echo "0")

if [ $oom_events -gt 0 ]; then
    echo -e "${RED}✗ Out of memory events detected: $oom_events${NC}"
    send_alert "HIGH" "Out of memory events: $oom_events occurrences"
else
    echo -e "${GREEN}✓ No memory issues${NC}"
fi

cpu_warnings=$(railway logs --since "${MONITORING_WINDOW_HOURS}h" 2>/dev/null | \
    grep -icE "cpu.*limit|throttl" || echo "0")

if [ $cpu_warnings -gt 0 ]; then
    echo -e "${YELLOW}⚠ CPU throttling detected: $cpu_warnings times${NC}"
    log_message "CPU throttling events: $cpu_warnings"
else
    echo -e "${GREEN}✓ No CPU issues${NC}"
fi
echo ""

# Monitor 8: Certificate Expiration
echo -e "${BLUE}[8/8] Checking SSL Certificate Expiration${NC}"

OPENWEBUI_URL=$(railway domain --service openwebui 2>/dev/null || echo "")
if [ -n "$OPENWEBUI_URL" ]; then
    cert_expiry=$(echo | openssl s_client -connect "$OPENWEBUI_URL:443" -servername "$OPENWEBUI_URL" 2>/dev/null | \
        openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2 || echo "")

    if [ -n "$cert_expiry" ]; then
        expiry_epoch=$(date -d "$cert_expiry" +%s 2>/dev/null || echo "0")
        current_epoch=$(date +%s)
        days_remaining=$(( (expiry_epoch - current_epoch) / 86400 ))

        if [ $days_remaining -lt 7 ]; then
            echo -e "${RED}✗ Certificate expires in $days_remaining days!${NC}"
            send_alert "CRITICAL" "SSL certificate expires in $days_remaining days"
        elif [ $days_remaining -lt 30 ]; then
            echo -e "${YELLOW}⚠ Certificate expires in $days_remaining days${NC}"
            log_message "SSL certificate expires in $days_remaining days"
        else
            echo -e "${GREEN}✓ Certificate valid for $days_remaining days${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ Could not check certificate expiration${NC}"
    fi
else
    echo -e "${YELLOW}⚠ No public domain configured${NC}"
fi
echo ""

# Generate Summary Report
echo "=================================================="
echo "  Monitoring Summary"
echo "=================================================="

summary="Security Monitoring Report - $(date)\n"
summary+="Monitoring Window: ${MONITORING_WINDOW_HOURS}h\n"
summary+="---\n"
summary+="Authentication Failures: $auth_failures\n"
summary+="Total Errors: $total_errors\n"
summary+="Unhealthy Services: $unhealthy_services\n"
summary+="Rate Limit Hits: $rate_limit_hits\n"
summary+="Security Events: $security_events\n"
summary+="OOM Events: $oom_events\n"

echo -e "$summary"
log_message "$summary"

# Overall status
if [ $unhealthy_services -eq 0 ] && [ $security_events -eq 0 ] && [ $oom_events -eq 0 ]; then
    echo -e "${GREEN}✓ All systems operating normally${NC}"
    log_message "Monitoring check completed: All systems normal"
    exit 0
else
    echo -e "${YELLOW}⚠ Some issues detected - review logs for details${NC}"
    log_message "Monitoring check completed: Issues detected"
    exit 0
fi
