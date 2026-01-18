# Railway Deployment Site Verification Plan

## Overview
This document outlines the comprehensive verification and security validation plan for deploying the LLM Stack on Railway. Follow this plan to ensure a secure, reliable, and properly configured deployment.

---

## 1. Pre-Deployment Security Hardening

### 1.1 Secrets Management
**Recommendations:**
- [ ] Never commit secrets to git repository
- [ ] Use Railway's environment variables for all sensitive data
- [ ] Rotate all default credentials and API keys
- [ ] Use strong, randomly generated passwords (min 32 characters)
- [ ] Enable Railway's secret encryption at rest
- [ ] Implement principle of least privilege for all API keys

**Verification Steps:**
```bash
# Check for exposed secrets in codebase
git secrets --scan
grep -r "password\|secret\|api_key" --include="*.py" --include="*.js" --include="*.env"

# Verify no .env files are committed
git ls-files | grep -E "\.env$|\.env\."

# Check Railway environment variables are set
railway variables

# Verify strong password requirements
railway variables | grep -E "PASSWORD|SECRET|KEY" | wc -l
```

### 1.2 Access Control & Authentication
**Recommendations:**
- [ ] Enable Railway team RBAC (Role-Based Access Control)
- [ ] Use Railway's SSO if available for team access
- [ ] Implement API key rotation policy (every 90 days)
- [ ] Use separate credentials for each environment (dev/staging/prod)
- [ ] Enable MFA for all Railway accounts with deploy access
- [ ] Document who has access to production deployments

**Verification Steps:**
```bash
# List Railway project access
railway team

# Verify service tokens are scoped correctly
railway whoami

# Check for API key expiration policies
# (Manual review of key creation dates)
```

### 1.3 Network Security
**Recommendations:**
- [ ] Use Railway's private networking for internal service communication
- [ ] Disable public access for internal services (PostgreSQL, Redis, Qdrant)
- [ ] Enable CORS only for trusted domains
- [ ] Implement rate limiting on all public APIs
- [ ] Use HTTPS/TLS for all external communications
- [ ] Configure Railway's built-in DDoS protection

**Service Visibility Matrix:**
| Service | Public Access | Private Network | Notes |
|---------|--------------|-----------------|-------|
| PostgreSQL | ❌ No | ✅ Yes | Plugin - internal only |
| Redis | ❌ No | ✅ Yes | Plugin - internal only |
| Qdrant | ❌ No | ✅ Yes | Internal vector DB |
| R2R | ❌ No | ✅ Yes | Internal API only |
| LiteLLM | ⚠️ Limited | ✅ Yes | API access via OpenWebUI only |
| OpenWebUI | ✅ Yes | ✅ Yes | Primary user interface |
| React Client | ✅ Yes | ✅ Yes | Frontend application |

**Verification Steps:**
```bash
# Check service visibility in Railway dashboard
railway status

# Verify CORS configuration in OpenWebUI
curl -I -X OPTIONS https://your-openwebui.railway.app

# Test internal service connectivity (should fail from outside)
curl -I https://r2r-internal.railway.app
curl -I https://qdrant-internal.railway.app

# Verify TLS certificates
echo | openssl s_client -connect your-domain.railway.app:443 -servername your-domain.railway.app 2>/dev/null | openssl x509 -noout -dates
```

### 1.4 Container Security
**Recommendations:**
- [ ] Use official, minimal base images (alpine, distroless)
- [ ] Scan container images for vulnerabilities
- [ ] Run containers as non-root users
- [ ] Implement read-only root filesystems where possible
- [ ] Remove unnecessary packages and tools
- [ ] Keep base images updated with security patches

**Verification Steps:**
```bash
# Scan Docker images for vulnerabilities (if using Docker locally)
docker scout cve your-image:tag
trivy image your-image:tag

# Check Dockerfiles for security best practices
grep -r "USER" Dockerfile* # Should not be root
grep -r "FROM.*:latest" Dockerfile* # Should use specific tags

# Verify minimal attack surface
docker history your-image:tag
```

### 1.5 Data Security & Privacy
**Recommendations:**
- [ ] Enable encryption at rest for PostgreSQL (Railway plugin default)
- [ ] Enable encryption in transit (TLS) for all connections
- [ ] Implement data retention policies
- [ ] Configure Qdrant data persistence with encryption
- [ ] Sanitize logs (no PII, credentials, or sensitive data)
- [ ] Implement backup encryption for database backups
- [ ] Use Railway's volume encryption for persistent data

**Verification Steps:**
```bash
# Verify PostgreSQL encryption settings
railway run psql -c "SHOW ssl;"

# Check Redis encryption
railway run redis-cli INFO | grep ssl

# Review log sanitization
railway logs | grep -iE "password|secret|api_key|token"

# Verify Qdrant storage encryption
curl http://qdrant-service:6333/cluster
```

### 1.6 Dependency Security
**Recommendations:**
- [ ] Audit all third-party dependencies
- [ ] Enable automated security updates
- [ ] Use dependency scanning tools (Snyk, Dependabot)
- [ ] Pin dependency versions in package managers
- [ ] Review dependencies for known vulnerabilities
- [ ] Minimize dependency count

**Verification Steps:**
```bash
# Python dependencies audit
pip-audit
safety check

# Node.js dependencies audit
npm audit
yarn audit

# Check for outdated packages
pip list --outdated
npm outdated

# Review dependency licenses
pip-licenses
license-checker
```

---

## 2. Configuration Validation

### 2.1 Environment Variables
**Required Variables by Service:**

**PostgreSQL (Railway Plugin):**
- `DATABASE_URL` - Auto-provided by Railway
- `POSTGRES_DB` - Database name
- `POSTGRES_USER` - Admin user
- `POSTGRES_PASSWORD` - Strong password (min 32 chars)

**Redis (Railway Plugin):**
- `REDIS_URL` - Auto-provided by Railway

**Qdrant:**
- `QDRANT_API_KEY` - Strong API key for authentication
- `QDRANT_STORAGE_PATH` - Persistence volume path
- `QDRANT_GRPC_PORT` - Internal gRPC port (6334)
- `QDRANT_HTTP_PORT` - Internal HTTP port (6333)

**R2R:**
- `POSTGRES_HOST` - Internal PostgreSQL hostname
- `POSTGRES_DBNAME` - Database name
- `POSTGRES_USER` - Database user
- `POSTGRES_PASSWORD` - Database password
- `R2R_PROJECT_NAME` - Project identifier
- `QDRANT_URL` - Internal Qdrant URL
- `QDRANT_API_KEY` - Qdrant authentication key
- `LITELLM_API_BASE` - LiteLLM endpoint URL
- `EMBEDDING_MODEL` - Model for embeddings
- `LLM_MODEL` - Language model identifier

**LiteLLM:**
- `LITELLM_MASTER_KEY` - Master API key (strong, unique)
- `OPENAI_API_KEY` - OpenAI credentials (if used)
- `ANTHROPIC_API_KEY` - Anthropic credentials (if used)
- `DATABASE_URL` - PostgreSQL connection for proxy
- `LITELLM_LOG_LEVEL` - Logging verbosity

**OpenWebUI:**
- `WEBUI_SECRET_KEY` - Session secret (strong, unique)
- `OLLAMA_BASE_URL` - LiteLLM proxy URL
- `DATABASE_URL` - PostgreSQL connection
- `ENABLE_OAUTH` - OAuth configuration
- `CORS_ALLOW_ORIGIN` - Allowed origins list

**React Client:**
- `REACT_APP_API_URL` - Backend API endpoint
- `REACT_APP_ENV` - Environment identifier

**Verification Commands:**
```bash
# List all environment variables
railway variables

# Check for required variables (per service)
railway variables --service postgres-pgvector | grep DATABASE_URL
railway variables --service redis | grep REDIS_URL
railway variables --service qdrant | grep QDRANT_API_KEY
railway variables --service r2r | grep -E "POSTGRES|QDRANT|LITELLM"
railway variables --service litellm | grep -E "LITELLM_MASTER_KEY|OPENAI_API_KEY"
railway variables --service openwebui | grep -E "WEBUI_SECRET_KEY|OLLAMA_BASE_URL"

# Verify no placeholder values
railway variables | grep -iE "changeme|password123|admin|secret|replace"

# Check variable encryption
railway variables --json | jq '.[] | select(.encrypted == false)'
```

### 2.2 Railway Service Configuration
**Verify railway.toml files exist:**
```bash
ls -la railway.toml
ls -la services/*/railway.toml
```

**Key Configuration Points:**
- [ ] Build commands are correct
- [ ] Start commands are secure (no exposed credentials)
- [ ] Health check endpoints are configured
- [ ] Port configurations match service requirements
- [ ] Resource limits are set appropriately

### 2.3 Internal DNS Configuration
**Railway Internal URLs:**
```
postgres-pgvector.railway.internal:5432
redis.railway.internal:6379
qdrant.railway.internal:6333
qdrant.railway.internal:6334
r2r.railway.internal:7272
litellm.railway.internal:4000
openwebui.railway.internal:8080
```

**Verification:**
```bash
# Test internal DNS resolution (from within Railway service)
railway run --service r2r -- nslookup postgres-pgvector.railway.internal
railway run --service r2r -- nslookup qdrant.railway.internal

# Verify service connectivity
railway run --service r2r -- curl -I http://qdrant.railway.internal:6333/health
railway run --service openwebui -- curl -I http://litellm.railway.internal:4000/health
```

---

## 3. Deployment Phase Security Verification

### 3.1 Secure Deployment Order
```
1. PostgreSQL Plugin (with encryption enabled)
2. Redis Plugin (with TLS enabled)
3. Qdrant (with API key authentication)
4. R2R (verify secure connections)
5. LiteLLM (with master key configured)
6. OpenWebUI (with secret key and CORS)
7. React Client (with secure API endpoints)
```

### 3.2 Build Security Verification
```bash
# Monitor build logs for security warnings
railway logs --service r2r --deployment latest | grep -iE "warning|error|security|vulnerability"

# Check for exposed secrets in build logs
railway logs --service r2r --deployment latest | grep -iE "password|secret|api_key|token"

# Verify build artifacts don't contain sensitive data
railway logs --service r2r --deployment latest | grep -i "copying"
```

### 3.3 Deployment Health Checks
```bash
# Verify all services are running
railway status

# Check deployment health
railway logs --service r2r --tail 50
railway logs --service litellm --tail 50
railway logs --service openwebui --tail 50
railway logs --service qdrant --tail 50

# Verify no crash loops
railway ps
```

---

## 4. Service-by-Service Security Testing

### 4.1 PostgreSQL Plugin
**Security Checks:**
```bash
# Test connection with credentials
railway run --service r2r -- psql $DATABASE_URL -c "SELECT version();"

# Verify SSL/TLS is enforced
railway run --service r2r -- psql $DATABASE_URL -c "SHOW ssl;"

# Check pgvector extension is loaded securely
railway run --service r2r -- psql $DATABASE_URL -c "\dx" | grep vector

# Verify user permissions (principle of least privilege)
railway run --service r2r -- psql $DATABASE_URL -c "\du"

# Check for default/test databases
railway run --service r2r -- psql $DATABASE_URL -c "\l"

# Audit access logs
railway logs --service postgres-pgvector | grep -i "connection\|authentication"
```

**Security Validation:**
- [ ] SSL/TLS connections enforced
- [ ] No default passwords
- [ ] Limited user permissions
- [ ] pgvector extension installed correctly
- [ ] No public access from internet
- [ ] Connection pooling configured

### 4.2 Redis Plugin
**Security Checks:**
```bash
# Test authenticated connection
railway run --service r2r -- redis-cli -u $REDIS_URL PING

# Verify AUTH required
railway run --service r2r -- redis-cli -h redis.railway.internal -p 6379 PING # Should fail without auth

# Check dangerous commands are disabled
railway run --service r2r -- redis-cli -u $REDIS_URL CONFIG GET "rename-command"

# Verify TLS
railway run --service r2r -- redis-cli -u $REDIS_URL INFO | grep ssl

# Check persistence configuration
railway run --service r2r -- redis-cli -u $REDIS_URL CONFIG GET "save"
```

**Security Validation:**
- [ ] Authentication required
- [ ] TLS enabled
- [ ] Dangerous commands disabled (FLUSHALL, CONFIG, etc.)
- [ ] No public access
- [ ] Persistence configured securely

### 4.3 Qdrant Vector Database
**Security Checks:**
```bash
# Health check with API key
curl -H "api-key: $QDRANT_API_KEY" http://qdrant.railway.internal:6333/health

# Verify API key is required
curl http://qdrant.railway.internal:6333/collections # Should fail (401)

# Test authenticated access
curl -H "api-key: $QDRANT_API_KEY" http://qdrant.railway.internal:6333/collections

# Check storage encryption
curl -H "api-key: $QDRANT_API_KEY" http://qdrant.railway.internal:6333/cluster

# Verify gRPC port
grpcurl -H "api-key: $QDRANT_API_KEY" qdrant.railway.internal:6334 list

# Check telemetry settings (disable if not needed)
curl -H "api-key: $QDRANT_API_KEY" http://qdrant.railway.internal:6333/telemetry
```

**Security Validation:**
- [ ] API key authentication enforced
- [ ] No public internet access
- [ ] Storage persistence with encryption
- [ ] Telemetry disabled or secured
- [ ] gRPC and HTTP endpoints secured

### 4.4 R2R Service
**Security Checks:**
```bash
# Health endpoint
curl http://r2r.railway.internal:7272/v2/health

# Verify database connection uses encrypted channel
railway logs --service r2r | grep -i "ssl\|tls"

# Test authentication endpoints
curl -X POST http://r2r.railway.internal:7272/v2/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"wrong"}' # Should fail

# Verify API rate limiting
for i in {1..100}; do curl http://r2r.railway.internal:7272/v2/health; done

# Check for exposed debug endpoints
curl http://r2r.railway.internal:7272/debug # Should not exist

# Verify CORS configuration
curl -I -X OPTIONS http://r2r.railway.internal:7272/v2/health
```

**Security Validation:**
- [ ] Authentication required for sensitive endpoints
- [ ] Database connections encrypted
- [ ] No debug endpoints exposed
- [ ] Rate limiting configured
- [ ] Input validation on all endpoints
- [ ] No sensitive data in logs

### 4.5 LiteLLM Proxy
**Security Checks:**
```bash
# Health check
curl http://litellm.railway.internal:4000/health

# Verify master key is required
curl http://litellm.railway.internal:4000/v1/models # Should fail (401)

# Test with master key
curl -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  http://litellm.railway.internal:4000/v1/models

# Check for API key leakage in logs
railway logs --service litellm | grep -iE "sk-|api_key|authorization"

# Verify proxy functionality
curl -X POST http://litellm.railway.internal:4000/v1/chat/completions \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"gpt-3.5-turbo","messages":[{"role":"user","content":"test"}]}'

# Check rate limiting per user
curl -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  http://litellm.railway.internal:4000/user/info
```

**Security Validation:**
- [ ] Master key authentication enforced
- [ ] API keys not logged
- [ ] Request/response validation
- [ ] Rate limiting per user/key
- [ ] Cost tracking enabled
- [ ] Provider API keys secured

### 4.6 OpenWebUI
**Security Checks:**
```bash
# Access from public URL
curl -I https://your-openwebui.railway.app

# Verify HTTPS redirect
curl -I http://your-openwebui.railway.app # Should redirect to HTTPS

# Check session security
curl -I https://your-openwebui.railway.app/auth/login | grep -i "secure\|httponly"

# Verify CORS configuration
curl -I -X OPTIONS https://your-openwebui.railway.app \
  -H "Origin: https://malicious-site.com" # Should be blocked

# Test authentication
curl -X POST https://your-openwebui.railway.app/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"wrong"}' # Should fail

# Check for security headers
curl -I https://your-openwebui.railway.app | grep -iE "x-frame-options|x-content-type|strict-transport"

# Verify OAuth configuration (if enabled)
curl https://your-openwebui.railway.app/.well-known/oauth-authorization-server
```

**Security Validation:**
- [ ] HTTPS enforced
- [ ] Secure session cookies (HttpOnly, Secure, SameSite)
- [ ] CORS properly configured
- [ ] Security headers present (CSP, X-Frame-Options, etc.)
- [ ] Authentication required
- [ ] No admin panel exposed without auth

### 4.7 React Client
**Security Checks:**
```bash
# Access from public URL
curl -I https://your-client.railway.app

# Check for exposed environment variables in bundle
curl https://your-client.railway.app/static/js/main.*.js | grep -iE "api_key|secret|password"

# Verify Content Security Policy
curl -I https://your-client.railway.app | grep -i "content-security-policy"

# Check for source maps in production (should be disabled)
curl -I https://your-client.railway.app/static/js/main.*.js.map # Should 404

# Verify API endpoints use HTTPS
curl https://your-client.railway.app | grep -o "http://[^\"]*" # Should be empty

# Check for XSS protection headers
curl -I https://your-client.railway.app | grep -i "x-xss-protection"
```

**Security Validation:**
- [ ] No secrets in frontend bundle
- [ ] Content Security Policy configured
- [ ] Source maps disabled in production
- [ ] All API calls use HTTPS
- [ ] XSS protection headers
- [ ] Subresource Integrity for CDN resources

---

## 5. Integration Security Testing

### 5.1 End-to-End Authentication Flow
```bash
# 1. User registration
curl -X POST https://your-openwebui.railway.app/api/auth/signup \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","email":"test@example.com","password":"StrongP@ssw0rd123!"}'

# 2. User login
TOKEN=$(curl -X POST https://your-openwebui.railway.app/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","password":"StrongP@ssw0rd123!"}' | jq -r '.token')

# 3. Access protected resource
curl -H "Authorization: Bearer $TOKEN" \
  https://your-openwebui.railway.app/api/user/profile

# 4. Test token expiration
sleep 3600 # Wait for token to expire
curl -H "Authorization: Bearer $TOKEN" \
  https://your-openwebui.railway.app/api/user/profile # Should fail
```

### 5.2 Service-to-Service Communication Security
```bash
# R2R -> PostgreSQL (encrypted connection)
railway run --service r2r -- curl http://localhost:7272/v2/health
railway logs --service r2r | grep -i "database connected"

# R2R -> Qdrant (with API key)
railway logs --service r2r | grep -i "qdrant"

# OpenWebUI -> LiteLLM (with master key)
railway logs --service openwebui | grep -i "litellm"

# Client -> OpenWebUI (HTTPS)
curl -I https://your-client.railway.app
```

### 5.3 Data Flow Validation
```bash
# Test document upload and processing
curl -X POST https://your-openwebui.railway.app/api/documents \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@test-document.pdf"

# Verify embedding generation
railway logs --service r2r | grep -i "embedding"

# Check vector storage
curl -H "api-key: $QDRANT_API_KEY" \
  http://qdrant.railway.internal:6333/collections/documents/points/count

# Test retrieval
curl -X POST https://your-openwebui.railway.app/api/chat \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"message":"What is in the document?"}'
```

### 5.4 Security Incident Response Test
```bash
# Simulate brute force attack
for i in {1..100}; do
  curl -X POST https://your-openwebui.railway.app/api/auth/login \
    -H "Content-Type: application/json" \
    -d '{"username":"admin","password":"wrong'$i'"}'
done

# Verify rate limiting kicked in
railway logs --service openwebui | grep -i "rate limit"

# Simulate SQL injection attempt
curl -X POST https://your-openwebui.railway.app/api/documents \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"query":"1; DROP TABLE users; --"}'

# Verify input sanitization
railway logs --service r2r | grep -i "invalid input\|sanitized"
```

---

## 6. Performance & Monitoring Security

### 6.1 Health Endpoint Monitoring
```bash
# Set up health check script
cat > health-check.sh << 'EOF'
#!/bin/bash
ENDPOINTS=(
  "http://qdrant.railway.internal:6333/health"
  "http://r2r.railway.internal:7272/v2/health"
  "http://litellm.railway.internal:4000/health"
  "https://your-openwebui.railway.app/health"
)

for endpoint in "${ENDPOINTS[@]}"; do
  response=$(curl -s -o /dev/null -w "%{http_code}" "$endpoint")
  if [ "$response" != "200" ]; then
    echo "ALERT: $endpoint returned $response"
  fi
done
EOF

chmod +x health-check.sh
./health-check.sh
```

### 6.2 Security Monitoring
**Key Metrics to Monitor:**
- [ ] Failed authentication attempts
- [ ] Unusual API usage patterns
- [ ] High error rates (potential DoS)
- [ ] Unexpected database connections
- [ ] Large data transfers (potential exfiltration)
- [ ] Service restart frequency

```bash
# Monitor failed auth attempts
railway logs --service openwebui | grep -i "authentication failed" | wc -l

# Check for anomalous traffic
railway logs --service r2r | grep -E "429|503" | wc -l

# Database connection monitoring
railway logs --service r2r | grep -i "connection pool"

# Monitor resource usage
railway status --service r2r --metrics
```

### 6.3 Log Security Audit
```bash
# Ensure no sensitive data in logs
railway logs | grep -iE "password|secret|api_key|token|authorization: bearer"

# Verify log retention policy
# (Check Railway dashboard for log retention settings)

# Export logs for security analysis
railway logs --service openwebui --since 24h > security-audit-$(date +%Y%m%d).log

# Analyze for security events
grep -iE "failed|error|unauthorized|forbidden|denied" security-audit-*.log
```

---

## 7. Compliance & Security Audit

### 7.1 Security Checklist
**Infrastructure Security:**
- [ ] All services use latest stable versions
- [ ] Container images scanned for vulnerabilities
- [ ] No unnecessary services exposed publicly
- [ ] Railway private networking enabled
- [ ] TLS/SSL certificates valid and not expiring soon
- [ ] Firewall rules properly configured

**Authentication & Authorization:**
- [ ] Strong password policies enforced
- [ ] MFA enabled for admin accounts
- [ ] API keys rotated regularly
- [ ] Session timeouts configured
- [ ] JWT tokens signed securely
- [ ] OAuth properly configured (if used)

**Data Protection:**
- [ ] Encryption at rest enabled
- [ ] Encryption in transit enforced
- [ ] Database backups encrypted
- [ ] PII data properly handled
- [ ] Data retention policies implemented
- [ ] GDPR/compliance requirements met

**Network Security:**
- [ ] CORS properly configured
- [ ] Rate limiting enabled
- [ ] DDoS protection active
- [ ] No open/unnecessary ports
- [ ] Security headers configured
- [ ] CSP policies defined

**Application Security:**
- [ ] Input validation on all endpoints
- [ ] SQL injection protection
- [ ] XSS protection
- [ ] CSRF tokens implemented
- [ ] Dependency vulnerabilities patched
- [ ] Security headers present

**Monitoring & Logging:**
- [ ] Centralized logging enabled
- [ ] Security events monitored
- [ ] Alerting configured
- [ ] Log retention policy defined
- [ ] Audit trails maintained
- [ ] Incident response plan documented

### 7.2 Penetration Testing
```bash
# Use OWASP ZAP or similar tool
docker run -t owasp/zap2docker-stable zap-baseline.py \
  -t https://your-openwebui.railway.app

# SQL injection testing
sqlmap -u "https://your-openwebui.railway.app/api/search?q=test" \
  --cookie="session=YOUR_SESSION_TOKEN"

# XSS testing
curl https://your-openwebui.railway.app/api/search \
  -d "q=<script>alert('xss')</script>"

# Authentication bypass attempts
curl -X POST https://your-openwebui.railway.app/api/admin/users \
  -H "Authorization: Bearer invalid_token"
```

### 7.3 Compliance Verification
**GDPR Compliance:**
- [ ] User consent mechanisms
- [ ] Data portability features
- [ ] Right to be forgotten implementation
- [ ] Privacy policy accessible
- [ ] Data processing agreements

**SOC 2 / Security Standards:**
- [ ] Access control documentation
- [ ] Change management process
- [ ] Incident response procedures
- [ ] Vendor risk assessment
- [ ] Business continuity plan

---

## 8. Rollback & Disaster Recovery

### 8.1 Backup Verification
```bash
# PostgreSQL backup
railway run --service postgres-pgvector -- pg_dump -Fc $DATABASE_URL > backup-$(date +%Y%m%d).dump

# Verify backup integrity
railway run --service postgres-pgvector -- pg_restore --list backup-$(date +%Y%m%d).dump

# Qdrant snapshot
curl -X POST -H "api-key: $QDRANT_API_KEY" \
  http://qdrant.railway.internal:6333/collections/documents/snapshots

# Download and verify Qdrant snapshot
curl -H "api-key: $QDRANT_API_KEY" \
  http://qdrant.railway.internal:6333/collections/documents/snapshots/snapshot-name \
  -o qdrant-backup-$(date +%Y%m%d).snapshot
```

### 8.2 Rollback Procedures
**Triggers for Rollback:**
- [ ] Critical security vulnerability discovered
- [ ] Service health checks failing consistently
- [ ] Data integrity issues detected
- [ ] Authentication system compromised
- [ ] Excessive error rates (>5%)
- [ ] Performance degradation (>50% slower)

**Rollback Steps:**
```bash
# 1. Identify last known good deployment
railway deployments --service r2r

# 2. Rollback to previous deployment
railway rollback --service r2r --deployment DEPLOYMENT_ID

# 3. Verify rollback success
railway status
railway logs --service r2r --tail 100

# 4. Restore database from backup (if needed)
railway run --service postgres-pgvector -- pg_restore -d $DATABASE_URL backup.dump

# 5. Restore Qdrant collections (if needed)
curl -X PUT -H "api-key: $QDRANT_API_KEY" \
  -F "snapshot=@qdrant-backup.snapshot" \
  http://qdrant.railway.internal:6333/collections/documents/snapshots/recover
```

### 8.3 Incident Response Checklist
**Detection:**
- [ ] Alert received or anomaly detected
- [ ] Verify incident is genuine (not false positive)
- [ ] Assess severity and scope
- [ ] Document incident details

**Containment:**
- [ ] Isolate affected services
- [ ] Block malicious IPs/users if applicable
- [ ] Rotate compromised credentials
- [ ] Enable additional logging

**Eradication:**
- [ ] Identify root cause
- [ ] Remove malicious code/data
- [ ] Patch vulnerabilities
- [ ] Update security rules

**Recovery:**
- [ ] Restore from clean backups
- [ ] Verify system integrity
- [ ] Monitor for recurrence
- [ ] Gradually restore services

**Post-Incident:**
- [ ] Document lessons learned
- [ ] Update security procedures
- [ ] Communicate with stakeholders
- [ ] Implement preventive measures

---

## 9. Continuous Security Monitoring

### 9.1 Automated Security Checks
```bash
# Daily security scan script
cat > daily-security-check.sh << 'EOF'
#!/bin/bash
echo "=== Daily Security Audit $(date) ===" >> security-log.txt

# Check for failed logins
echo "Failed Logins:" >> security-log.txt
railway logs --service openwebui --since 24h | grep -i "authentication failed" | wc -l >> security-log.txt

# Verify all services healthy
echo "Service Health:" >> security-log.txt
railway status >> security-log.txt

# Check certificate expiration
echo "Certificate Status:" >> security-log.txt
echo | openssl s_client -connect your-domain.railway.app:443 -servername your-domain.railway.app 2>/dev/null | openssl x509 -noout -dates >> security-log.txt

# Scan for dependency vulnerabilities
echo "Dependency Vulnerabilities:" >> security-log.txt
pip-audit >> security-log.txt 2>&1
npm audit >> security-log.txt 2>&1

# Send alert if critical issues found
if grep -q "CRITICAL\|HIGH" security-log.txt; then
  echo "ALERT: Critical security issues detected!" | mail -s "Security Alert" admin@example.com
fi
EOF

chmod +x daily-security-check.sh
```

### 9.2 Security Metrics Dashboard
**Key Metrics:**
- Authentication failure rate
- API request rate by endpoint
- Error rate by service
- Database connection pool usage
- Response time percentiles
- Active sessions count
- Failed authorization attempts

### 9.3 Security Update Policy
- [ ] Subscribe to security advisories for all dependencies
- [ ] Review Railway security announcements weekly
- [ ] Apply critical security patches within 24 hours
- [ ] Test security updates in staging before production
- [ ] Document all security-related changes
- [ ] Maintain security changelog

---

## 10. Post-Deployment Security Validation

### Final Security Checklist
```bash
# Run comprehensive security validation
cat > final-security-check.sh << 'EOF'
#!/bin/bash
echo "=== Final Security Validation ==="

# 1. External security scan
echo "[1/10] Running external security scan..."
nmap -sV your-domain.railway.app

# 2. SSL/TLS validation
echo "[2/10] Validating SSL/TLS configuration..."
sslscan your-domain.railway.app

# 3. HTTP security headers
echo "[3/10] Checking security headers..."
curl -I https://your-openwebui.railway.app | grep -iE "x-frame|x-content|strict-transport|content-security"

# 4. Authentication testing
echo "[4/10] Testing authentication..."
curl -X POST https://your-openwebui.railway.app/api/auth/login -d '{"username":"admin","password":"wrong"}' | grep -q "401"

# 5. CORS validation
echo "[5/10] Validating CORS policy..."
curl -H "Origin: https://malicious.com" -I https://your-openwebui.railway.app

# 6. Rate limiting
echo "[6/10] Testing rate limiting..."
for i in {1..50}; do curl -s https://your-openwebui.railway.app/api/health; done

# 7. Internal service isolation
echo "[7/10] Verifying internal services not publicly accessible..."
curl -I http://qdrant.railway.internal:6333 # Should fail from external

# 8. Secrets not exposed
echo "[8/10] Checking for exposed secrets..."
railway logs | grep -iE "password|secret|api_key" && echo "WARNING: Secrets in logs!"

# 9. Database encryption
echo "[9/10] Verifying database encryption..."
railway run --service postgres-pgvector -- psql $DATABASE_URL -c "SHOW ssl;" | grep -q "on"

# 10. Dependency vulnerabilities
echo "[10/10] Scanning for dependency vulnerabilities..."
pip-audit
npm audit

echo "=== Security Validation Complete ==="
EOF

chmod +x final-security-check.sh
./final-security-check.sh
```

---

## Summary

This comprehensive security and verification plan ensures:

1. **Defense in Depth**: Multiple layers of security controls
2. **Least Privilege**: Minimal access rights for all components
3. **Encryption Everywhere**: Data protected at rest and in transit
4. **Continuous Monitoring**: Real-time security event tracking
5. **Rapid Response**: Clear procedures for incident handling
6. **Compliance Ready**: GDPR, SOC 2, and industry standards

### Critical Security Principles
- ✅ Never trust, always verify
- ✅ Fail securely by default
- ✅ Keep attack surface minimal
- ✅ Defense in depth
- ✅ Principle of least privilege
- ✅ Secure by design

### Next Steps
1. Complete all checklist items before going to production
2. Schedule regular security audits (monthly)
3. Implement automated security scanning
4. Train team on security best practices
5. Document and test incident response procedures
6. Establish security update cadence

---

**Document Version:** 1.0
**Last Updated:** 2026-01-18
**Maintained By:** DevOps/Security Team
**Review Schedule:** Monthly
