# Qdrant on Railway: Deployment Checklist

Use this checklist to ensure proper deployment and configuration of Qdrant on Railway.

## Pre-Deployment Phase

### Planning & Capacity Analysis
- [ ] **Determine workload size**
  - Estimated number of vectors: __________
  - Vector dimensions: __________
  - Expected collections: __________
  - Estimated storage: __________ GB

- [ ] **Calculate resource requirements**
  - Required CPU: __________
  - Required Memory: __________
  - Required Storage: __________

- [ ] **Document expected usage patterns**
  - Average QPS (queries per second): __________
  - Peak QPS: __________
  - Read/Write ratio: __________
  - Maximum acceptable latency: __________ms

- [ ] **Define RTO/RPO goals**
  - Maximum acceptable downtime: __________
  - Maximum acceptable data loss: __________

### Security Planning
- [ ] **Generate API Key**
  ```bash
  QDRANT_API_KEY=$(openssl rand -base64 32)
  echo $QDRANT_API_KEY  # Save this securely
  ```

- [ ] **Plan key rotation schedule**
  - Rotation frequency: __________
  - Key rotation date: __________

- [ ] **Identify clients that need API key**
  - Client 1: __________
  - Client 2: __________
  - Client 3: __________

- [ ] **Review security requirements**
  - [ ] API key required?
  - [ ] Network isolation needed?
  - [ ] Audit logging required?
  - [ ] Encryption at rest needed?

---

## Deployment Phase

### Environment Setup

#### Railway Project Setup
- [ ] **Create Railway project**
  - Project name: __________ 
  - Select: "Empty Project"
  - **DO NOT** use "Deploy from GitHub"

- [ ] **Add Qdrant service**
  - Click "New" → "GitHub Repo"
  - Select forked llm-stack repository
  - Set source directory: `services/qdrant`
  - Verify Dockerfile and railway.toml detected
  - Click "Deploy"

- [ ] **Configure resource allocation**
  - CPU: __________ cores
  - Memory: __________ GB
  - Disk: __________ GB

### Environment Variables Configuration

#### Mandatory Configuration
- [ ] **Set Core Variables**
  ```
  QDRANT__SERVICE__HTTP_PORT=6333
  QDRANT__SERVICE__GRPC_PORT=6334
  ```

- [ ] **Set Security Variables**
  ```
  QDRANT_API_KEY=<generated-key-from-above>
  ```

#### Optional but Recommended for Production
- [ ] **Snapshot Configuration**
  ```
  QDRANT__SNAPSHOTS__ENABLED=true
  QDRANT__SNAPSHOTS__SNAPSHOT_INTERVAL=600
  QDRANT__SNAPSHOTS__MAX_SNAPSHOTS_TO_KEEP=5
  ```

- [ ] **Performance Variables**
  ```
  QDRANT__PERFORMANCE__INDEX_THREADS=0
  QDRANT__STORAGE__FLUSH_INTERVAL_MS=5000
  ```

- [ ] **Logging Configuration**
  ```
  QDRANT__LOG_LEVEL=info
  ```

- [ ] **Advanced Configuration** (if needed)
  - Vector cache: `QDRANT__PERFORMANCE__VECTOR_CACHE_SIZE_GB=0`
  - Other custom settings: __________

### Deployment Verification

#### Service Startup
- [ ] **Monitor build logs**
  - [ ] Dockerfile build successful
  - [ ] Image pushed to registry
  - [ ] Container started

- [ ] **Monitor startup logs** (wait 60+ seconds)
  - [ ] No "panic" or "fatal" errors
  - [ ] Service listening on 6333 and 6334
  - [ ] Ready to accept connections

- [ ] **Verify health check passes**
  - [ ] Dashboard shows "Healthy" status
  - [ ] Health check endpoint responding
  - [ ] No restart loops

#### Network Connectivity
- [ ] **Test internal DNS**
  - [ ] Service name: `qdrant`
  - [ ] Internal address: `qdrant.railway.internal:6333`
  - [ ] Document for client configs

- [ ] **Test API endpoint manually**
  ```bash
  # From other Railway service:
  curl http://qdrant.railway.internal:6333/readyz
  # Expected: 200 OK
  ```

- [ ] **Test with API key**
  ```bash
  curl -H "api-key: YOUR_API_KEY" \
    http://qdrant.railway.internal:6333/health
  # Expected: 200 OK with health details
  ```

#### Initial Data Verification
- [ ] **Create test collection**
  ```bash
  curl -X PUT http://qdrant.railway.internal:6333/collections/test \
    -H "api-key: YOUR_API_KEY" \
    -H "Content-Type: application/json" \
    -d '{"vectors": {"size": 10, "distance": "Cosine"}}'
  ```

- [ ] **Insert test vectors**
  ```bash
  curl -X PUT http://qdrant.railway.internal:6333/collections/test/points \
    -H "api-key: YOUR_API_KEY" \
    -H "Content-Type: application/json" \
    -d '{"points": [{"id": 1, "vector": [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0], "payload": {"test": "data"}}]}'
  ```

- [ ] **Verify data persists**
  - [ ] Stop and restart service
  - [ ] Test vector still exists
  - [ ] Data survived restart

---

## Integration Phase

### Client Configuration

#### Update Dependent Services
For each service connecting to Qdrant:

**Service: R2R**
- [ ] Update connection string to `qdrant.railway.internal:6333`
- [ ] Configure API key in environment
- [ ] Test connection in logs
- [ ] Verify vector operations work

**Service: [Other Client 1]**
- [ ] Update connection configuration
- [ ] Set API key
- [ ] Verify connectivity
- [ ] Test operations

**Service: [Other Client 2]**
- [ ] Update connection configuration
- [ ] Set API key
- [ ] Verify connectivity
- [ ] Test operations

#### Documentation Updates
- [ ] **Update deployment docs**
  - [ ] Document internal DNS address
  - [ ] Document port numbers
  - [ ] Document API key requirement
  - [ ] Document connection examples

- [ ] **Update team wiki**
  - [ ] How to connect to Qdrant
  - [ ] API key location
  - [ ] Health check procedure
  - [ ] Common troubleshooting

---

## Post-Deployment Phase

### Monitoring Setup

#### Dashboard & Alerts
- [ ] **Railway Dashboard Configuration**
  - [ ] Service visible in project dashboard
  - [ ] Status shows "Healthy"
  - [ ] Metrics tab accessible
  - [ ] Logs tab accessible

- [ ] **Set up resource alerts**
  - [ ] Alert: CPU > 80% (1 min)
  - [ ] Alert: Memory > 85% (2 min)
  - [ ] Alert: Disk > 80% capacity
  - [ ] Alert: Restart > 1 per hour

- [ ] **Set up service health alerts**
  - [ ] Alert: Health check failures
  - [ ] Alert: Service stopped/crashed
  - [ ] Alert: Build failures

#### Metrics Collection
- [ ] **Start baseline measurements**
  - Current CPU usage: __________
  - Current memory usage: __________
  - Current storage usage: __________
  - Query latency (p50): __________
  - Query latency (p95): __________

### Load Testing (Recommended)

- [ ] **Create test vectors**
  - [ ] Collection size: __________ vectors
  - [ ] Vector dimensions: __________
  - [ ] Upload successfully

- [ ] **Run search performance test**
  - [ ] Target QPS: __________
  - [ ] Achieved QPS: __________
  - [ ] Average latency: __________
  - [ ] p95 latency: __________
  - [ ] CPU usage during test: __________
  - [ ] Memory usage during test: __________

- [ ] **Verify performance meets SLAs**
  - [ ] Latency acceptable: Yes / No
  - [ ] Throughput acceptable: Yes / No
  - [ ] Resource usage acceptable: Yes / No

### Backup & Recovery

- [ ] **Enable automated snapshots**
  - [ ] Snapshots enabled in environment
  - [ ] Snapshot interval set: __________ seconds
  - [ ] Verified first snapshot created

- [ ] **Test snapshot/restore process**
  - [ ] Manually create snapshot
  - [ ] Document snapshot location
  - [ ] Document restore procedure
  - [ ] Test restore (in dev environment)

- [ ] **Create backup schedule**
  - [ ] Frequency: __________
  - [ ] Retention: __________
  - [ ] External storage: __________
  - [ ] Responsible person: __________

---

## Security Hardening

### API Security
- [ ] **Verify API key enforcement**
  - [ ] Requests without key are rejected
  - [ ] Requests with invalid key are rejected
  - [ ] Valid key requests succeed

- [ ] **Document API key handling**
  - [ ] Never logged in plaintext
  - [ ] Stored securely in Railway secrets
  - [ ] Rotated on schedule
  - [ ] Shared with team securely

### Network Security
- [ ] **Restrict access**
  - [ ] Only internal services can connect
  - [ ] No public internet exposure
  - [ ] Firewall rules configured

- [ ] **Enable audit logging**
  - [ ] Log level: info or debug
  - [ ] Review logs periodically
  - [ ] Alert on suspicious access

---

## Production Readiness Certification

### Pre-Production Checklist
- [ ] All deployment steps completed
- [ ] All integration tests passed
- [ ] Monitoring and alerting active
- [ ] Backup and recovery tested
- [ ] Team trained on operations
- [ ] Runbooks created for common issues
- [ ] Security review completed
- [ ] Performance meets SLAs

### Production Deployment Sign-Off
- [ ] **Technical Lead Review**
  - Name: __________
  - Date: __________
  - Approval: Yes / No

- [ ] **Operations Team Review**
  - Name: __________
  - Date: __________
  - Approval: Yes / No

- [ ] **Security Review**
  - Name: __________
  - Date: __________
  - Approval: Yes / No

---

## Ongoing Operations

### Daily Checks (first week)
- [ ] **Day 1 Post-Production**
  - [ ] Service running smoothly
  - [ ] No alerts triggered
  - [ ] Logs show normal activity

- [ ] **Days 2-7 Post-Production**
  - [ ] Monitor: CPU, Memory, Disk
  - [ ] Monitor: Query latency
  - [ ] Monitor: Error rates
  - [ ] Verify: Data persistence
  - [ ] Verify: Health checks

### Weekly Maintenance
- [ ] **Monday**
  - [ ] Review alerts from past week
  - [ ] Check snapshot creation
  - [ ] Monitor disk usage growth

- [ ] **Friday**
  - [ ] Performance trend analysis
  - [ ] Plan for next week capacity
  - [ ] Update runbooks if needed

### Monthly Tasks
- [ ] **First Week**
  - [ ] Review all metrics
  - [ ] Analyze usage trends
  - [ ] Plan capacity changes

- [ ] **Third Week**
  - [ ] Test backup/recovery process
  - [ ] Rotate API key if schedule allows
  - [ ] Update documentation

---

## Troubleshooting Quick Links

- **Service won't start**: See `README.md` → Troubleshooting → Health Check Failures
- **Can't connect from clients**: See `README.md` → Troubleshooting → Connection Issues
- **Slow queries**: See `RAILWAY_BEST_PRACTICES.md` → Performance Optimization
- **Storage full**: See `README.md` → Troubleshooting → Storage Issues
- **Security concerns**: See `RAILWAY_BEST_PRACTICES.md` → Security Best Practices

---

## Support Contacts

- **Technical Issues**: Team Slack: #infrastructure
- **Security Issues**: Security team: security@company.com
- **Railway Support**: https://support.railway.app
- **Qdrant Community**: https://discord.gg/qdrant

---

**Checklist Version**: 1.0  
**Last Updated**: 2024  
**Next Review Date**: __________
