# Railway Deployment Verification Scripts

Comprehensive security and verification automation for Railway deployment of the LLM Stack.

## Overview

This directory contains automated scripts to verify, test, and monitor your Railway deployment. These scripts implement the verification plan outlined in `plans/SITE_VERIFICATION_PLAN.md`.

## Quick Start

### Prerequisites

1. **Railway CLI** installed and authenticated:
   ```bash
   npm i -g @railway/cli
   railway login
   ```

2. **Required tools**:
   ```bash
   # PostgreSQL client
   sudo apt-get install postgresql-client

   # Optional: Security scanning tools
   pip install pip-audit safety
   npm install -g npm-audit
   ```

3. **Link to your Railway project**:
   ```bash
   railway link
   ```

### Run Full Verification

```bash
cd scripts/verification
./verify-deployment.sh
```

This will run all verification phases and generate a comprehensive report.

## Directory Structure

```
scripts/verification/
├── verify-deployment.sh          # Main orchestrator script
├── pre-deployment/               # Pre-deployment security checks
│   └── 01-secrets-check.sh      # Secrets and credential scanning
├── config/                       # Configuration validation
│   └── 01-env-validation.sh     # Environment variables validation
├── health/                       # Service health monitoring
│   └── 01-service-health.sh     # Health checks for all services
├── security/                     # Security testing
│   └── 01-service-security-tests.sh  # Security tests per service
├── integration/                  # Integration testing
│   └── 01-integration-tests.sh  # End-to-end workflow tests
├── monitoring/                   # Continuous monitoring
│   └── 01-continuous-monitoring.sh  # Security event monitoring
├── backup/                       # Backup and restore
│   └── 01-backup-restore.sh     # Database backup/restore tools
└── README.md                     # This file
```

## Detailed Usage

### 1. Pre-Deployment Security Checks

Scans for exposed secrets, credentials, and security misconfigurations.

```bash
./pre-deployment/01-secrets-check.sh
```

**What it checks:**
- Exposed secrets in codebase (API keys, passwords, tokens)
- Committed .env files
- .gitignore security entries
- Hardcoded credentials
- Railway CLI setup
- Placeholder values in configuration

**Example output:**
```
[1/6] Scanning for exposed secrets in codebase...
✓ No exposed secrets found in codebase

[2/6] Checking for committed .env files...
✓ No .env files committed to repository
```

### 2. Configuration Validation

Validates Railway environment variables for all services.

```bash
./config/01-env-validation.sh
```

**What it validates:**
- Required environment variables for each service
- Password strength (minimum 16 characters)
- API key strength (minimum 32 characters)
- Internal networking configuration
- Placeholder value detection

**Services checked:**
- PostgreSQL Plugin
- Redis Plugin
- Qdrant
- R2R
- LiteLLM
- OpenWebUI
- React Client

### 3. Service Health Checks

Tests connectivity and health of all deployed services.

```bash
./health/01-service-health.sh
```

**What it checks:**
- Service deployment status
- Database connectivity and SSL
- Redis authentication and TLS
- Qdrant API accessibility
- R2R health endpoints
- LiteLLM proxy status
- OpenWebUI public access
- React Client availability
- Security headers presence

### 4. Security Testing

Comprehensive security tests for each service.

```bash
./security/01-service-security-tests.sh
```

**What it tests:**

**PostgreSQL:**
- SSL/TLS enforcement
- User permissions
- pgvector extension
- Default databases

**Redis:**
- Authentication requirement
- Dangerous commands disabled
- Persistence configuration

**Qdrant:**
- API key enforcement
- Internal networking
- Telemetry settings

**R2R:**
- Debug endpoints disabled
- Database SSL connections
- Secrets in logs
- Input validation

**LiteLLM:**
- Master key requirement
- API key protection
- Internal networking

**OpenWebUI:**
- HTTPS enforcement
- Security headers
- CORS policy
- Authentication requirement
- Cookie security

**React Client:**
- Exposed secrets detection
- Source maps disabled
- HTTPS API endpoints
- Content Security Policy

### 5. Integration Testing

Tests end-to-end workflows and service communication.

```bash
./integration/01-integration-tests.sh
```

**What it tests:**
- Database connectivity chain
- Vector database integration
- LLM proxy integration
- Authentication flow
- End-to-end data flow
- Service-to-service communication

### 6. Continuous Monitoring

Monitors for security events and anomalies.

```bash
./monitoring/01-continuous-monitoring.sh
```

**What it monitors:**
- Failed authentication attempts
- Error rate analysis
- Service health status
- Database connection pool
- Unusual traffic patterns
- Security event detection
- Resource usage anomalies
- SSL certificate expiration

**Automated monitoring (cron):**
```bash
# Add to crontab for daily monitoring
0 9 * * * /path/to/scripts/verification/monitoring/01-continuous-monitoring.sh
```

### 7. Backup and Restore

Create and restore backups of databases.

```bash
# Create backup
./backup/01-backup-restore.sh backup

# List available backups
./backup/01-backup-restore.sh list

# Restore from backup
./backup/01-backup-restore.sh restore 20260118_143000

# Verify backup integrity
./backup/01-backup-restore.sh verify 20260118_143000

# Cleanup old backups (>30 days)
./backup/01-backup-restore.sh cleanup
```

**What it backs up:**
- PostgreSQL database (pg_dump)
- Qdrant vector collections (snapshots)

**Backup options:**
```bash
# Backup only PostgreSQL
./backup/01-backup-restore.sh backup --postgres-only

# Backup only Qdrant
./backup/01-backup-restore.sh backup --qdrant-only
```

## Main Orchestrator

The `verify-deployment.sh` script runs all verification phases in order.

### Usage

```bash
./verify-deployment.sh [options] [phase]
```

### Phases

- `pre-deploy` - Run pre-deployment checks only
- `config` - Run configuration validation only
- `health` - Run health checks only
- `security` - Run security tests only
- `integration` - Run integration tests only
- `monitoring` - Run monitoring checks only
- `full` - Run all phases (default)

### Options

- `--skip-pre-deploy` - Skip pre-deployment checks
- `--skip-security` - Skip security tests
- `--skip-integration` - Skip integration tests
- `--continue-on-error` - Continue even if a phase fails
- `--report <file>` - Specify custom report file path

### Examples

```bash
# Run full verification (recommended before production)
./verify-deployment.sh

# Run only security tests
./verify-deployment.sh security

# Run all except integration tests
./verify-deployment.sh --skip-integration full

# Continue verification even on failures
./verify-deployment.sh --continue-on-error full

# Custom report location
./verify-deployment.sh --report /tmp/my-report.txt
```

## CI/CD Integration

### GitHub Actions

Add to `.github/workflows/railway-verify.yml`:

```yaml
name: Railway Verification

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  verify:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Install Railway CLI
        run: npm i -g @railway/cli

      - name: Install PostgreSQL client
        run: sudo apt-get install -y postgresql-client

      - name: Run pre-deployment checks
        run: ./scripts/verification/pre-deployment/01-secrets-check.sh

      - name: Authenticate Railway
        env:
          RAILWAY_TOKEN: ${{ secrets.RAILWAY_TOKEN }}
        run: railway login --token $RAILWAY_TOKEN

      - name: Run configuration validation
        run: ./scripts/verification/config/01-env-validation.sh

      - name: Run security tests
        run: ./scripts/verification/security/01-service-security-tests.sh
        continue-on-error: true

      - name: Upload verification report
        uses: actions/upload-artifact@v3
        with:
          name: verification-report
          path: scripts/verification/verification-report-*.txt
```

### Pre-deployment Hook

Create a deployment hook:

```bash
#!/bin/bash
# deploy-hook.sh

# Run verification before deployment
cd scripts/verification
./verify-deployment.sh pre-deploy config

if [ $? -ne 0 ]; then
    echo "Verification failed! Aborting deployment."
    exit 1
fi

echo "Verification passed. Proceeding with deployment..."
```

## Automated Monitoring Setup

Set up continuous monitoring with cron:

```bash
# Edit crontab
crontab -e

# Add daily monitoring at 9 AM
0 9 * * * /path/to/scripts/verification/monitoring/01-continuous-monitoring.sh

# Add health checks every 4 hours
0 */4 * * * /path/to/scripts/verification/health/01-service-health.sh

# Add weekly backups on Sunday at 2 AM
0 2 * * 0 /path/to/scripts/verification/backup/01-backup-restore.sh backup
```

## Customization

### Environment Variables

All scripts support the following environment variables:

```bash
# Backup directory
export BACKUP_DIR=/custom/backup/path

# Log file location
export LOG_FILE=/custom/log/path/security.log

# Report file location
export REPORT_FILE=/custom/report/path/report.txt
```

### Alerting Integration

Modify the monitoring script to integrate with your alerting system:

```bash
# Edit monitoring/01-continuous-monitoring.sh

send_alert() {
    local severity=$1
    local message=$2

    # Slack
    curl -X POST https://hooks.slack.com/services/YOUR/WEBHOOK/URL \
        -d "{\"text\":\"[$severity] $message\"}"

    # Email
    echo "$message" | mail -s "Security Alert: $severity" admin@example.com

    # PagerDuty
    curl -X POST https://events.pagerduty.com/v2/enqueue \
        -H "Content-Type: application/json" \
        -d "{\"routing_key\":\"YOUR_KEY\",\"event_action\":\"trigger\",\"payload\":{\"summary\":\"$message\",\"severity\":\"$severity\"}}"
}
```

## Troubleshooting

### Railway CLI not authenticated

```bash
railway login
railway link  # Link to your project
```

### PostgreSQL client missing

```bash
# Ubuntu/Debian
sudo apt-get install postgresql-client

# macOS
brew install postgresql
```

### Permission denied errors

```bash
# Make scripts executable
chmod +x scripts/verification/**/*.sh
```

### Environment variables not found

Ensure you're linked to the correct Railway project:

```bash
railway status
railway variables  # Check if variables are accessible
```

## Best Practices

1. **Before Deployment:**
   - Run `pre-deployment` and `config` checks
   - Fix all errors before deploying

2. **After Deployment:**
   - Run `health`, `security`, and `integration` checks
   - Review the verification report

3. **Production Monitoring:**
   - Set up automated monitoring with cron
   - Configure alerting for critical issues
   - Review logs weekly

4. **Backup Strategy:**
   - Create backups before major changes
   - Test restore procedures regularly
   - Keep backups for at least 30 days

5. **Security Updates:**
   - Run security tests after dependency updates
   - Re-run verification after configuration changes
   - Monitor for security advisories

## Support

For issues or questions:

1. Check the main verification plan: `plans/SITE_VERIFICATION_PLAN.md`
2. Review script output and error messages
3. Check Railway logs: `railway logs --service <service-name>`
4. Verify Railway CLI: `railway whoami`

## License

This verification suite is part of the LLM Stack project.
