# Qdrant on Railway: Best Practices & Production Deployment Guide

This guide provides comprehensive best practices for deploying and managing Qdrant on Railway, covering security, performance, monitoring, and disaster recovery.

## Table of Contents

1. [Pre-Deployment Planning](#pre-deployment-planning)
2. [Security Best Practices](#security-best-practices)
3. [Performance Optimization](#performance-optimization)
4. [Data Management & Backup](#data-management--backup)
5. [Monitoring & Observability](#monitoring--observability)
6. [Disaster Recovery](#disaster-recovery)
7. [Cost Optimization](#cost-optimization)
8. [Scaling Strategy](#scaling-strategy)

---

## Pre-Deployment Planning

### Capacity Planning

Before deploying Qdrant to Railway, understand your requirements:

#### Vector Metrics
```
Storage per vector = (dimensions × 4 bytes) + metadata overhead
Example: 384-dim vector = (384 × 4) + ~100 = ~1,636 bytes per vector

For 1M vectors: 1,636 MB ≈ 1.6 GB minimum storage
```

#### Resource Allocation Decision Tree

```
1. Estimate total vectors: __________
2. Estimate vector dimensions: __________
3. Calculate storage: (vectors × dimensions × 4) / 1,000,000,000 = __________ GB
4. Add 50% for metadata/index: __________ GB
5. Add 100% for snapshots: __________ GB (TOTAL)

CPU needed:
- < 100K vectors: 0.5 CPU minimum
- 100K - 1M vectors: 1 CPU
- 1M - 10M vectors: 2 CPU
- > 10M vectors: 4+ CPU

Memory needed:
- < 100K vectors: 512 MB - 1 GB
- 100K - 1M vectors: 2 GB
- 1M - 10M vectors: 4 GB - 8 GB
- > 10M vectors: 8 GB+
```

### Environment Segregation

```
Development:
- Pinned version: v1.13.1
- Resources: 0.5 CPU, 512 MB RAM, 10 GB storage
- API key: Optional
- Snapshots: Disabled to save space

Staging:
- Pinned version: Same as production
- Resources: 1 CPU, 2 GB RAM, 50 GB storage
- API key: Required
- Snapshots: Enabled, 4-hour interval

Production:
- Pinned version: Explicit version tag
- Resources: 2+ CPU, 4+ GB RAM, 200+ GB storage
- API key: REQUIRED
- Snapshots: Enabled, 1-hour interval
- Replicas: Configure for failover
- Monitoring: Full suite enabled
```

---

## Security Best Practices

### 1. API Key Management

**Generation**:
```bash
# Generate strong 32-character key
openssl rand -base64 32

# Example output:
# J3p7kL2mN5x8qR9vS4w1Y6z/A0bC3dE+
```

**Configuration in Railway**:
1. Navigate to your Qdrant service
2. Click "Settings" → "Environment"
3. Add `QDRANT_API_KEY` with generated value
4. Restart service (automatic deployment)

**Implementation in Clients**:

```python
# Python
from qdrant_client import QdrantClient

client = QdrantClient(
    url="http://qdrant.railway.internal:6333",
    api_key="J3p7kL2mN5x8qR9vS4w1Y6z/A0bC3dE+"
)
```

```typescript
// TypeScript
import { QdrantClient } from "@qdrant/js-client-rest";

const client = new QdrantClient({
  url: "http://qdrant.railway.internal:6333",
  apiKey: "J3p7kL2mN5x8qR9vS4w1Y6z/A0bC3dE+",
});
```

### 2. Key Rotation Policy

**Quarterly Key Rotation Process**:

```bash
# Step 1: Generate new key
NEW_KEY=$(openssl rand -base64 32)

# Step 2: Create "dual key" period (optional - advanced)
# Modify client code to accept both old and new keys

# Step 3: Update API key in Railway dashboard
# Navigate to service → Environment → Update QDRANT_API_KEY

# Step 4: Verify new key works
curl -H "api-key: $NEW_KEY" \
  http://qdrant.railway.internal:6333/health

# Step 5: Update all clients to use new key
# (Batch this update across services)

# Step 6: Monitor logs for any failed auth attempts
```

### 3. Network Security

**Restrict Access**:
- Only expose HTTP/gRPC to services that need it
- Use Railway's internal DNS: `qdrant.railway.internal:6333`
- Never expose directly to internet without authentication

**Enable TLS** (if using external access):
```bash
# Use Railway's managed domains
# Access via: https://qdrant-prod.railway.internal
# (includes automatic TLS termination)
```

### 4. Monitoring for Security Threats

```bash
# Monitor for unauthorized access attempts
curl http://qdrant.railway.internal:6333/metrics \
  | grep -i "auth\|error\|denied"

# Check logs for 401 Unauthorized errors
# Railway Logs → Search: "401"

# Set up alerts for:
# - More than 10 failed auth attempts per hour
# - Service restart due to auth issues
# - Unusual request patterns
```

---

## Performance Optimization

### 1. Indexing Configuration

**For Collections with Varied Query Patterns**:

```bash
# Default HNSW parameters
QDRANT__HNSW_INDEX__M=16                    # Node connections (16 = balanced)
QDRANT__HNSW_INDEX__EF_CONSTRUCT=200        # Construction parameter
QDRANT__HNSW_INDEX__FULL_SCAN_THRESHOLD=10000  # Fallback threshold
```

**For Very Large Collections (>10M vectors)**:

```bash
# Aggressive indexing
QDRANT__HNSW_INDEX__M=8                     # Fewer connections = less memory
QDRANT__HNSW_INDEX__EF_CONSTRUCT=100        # Faster construction
QDRANT__HNSW_INDEX__FULL_SCAN_THRESHOLD=5000

# Enable quantization
# (Reduce memory by 4-8x, minimal accuracy loss)
# Set in collection creation:
# "quantization_config": {
#   "scalar": {
#     "type": "uint8",
#     "quantile": 0.99,
#     "always_ram": true
#   }
# }
```

### 2. Caching Strategy

```bash
# Enable vector cache for frequently accessed vectors
QDRANT__PERFORMANCE__VECTOR_CACHE_SIZE_GB=1

# Typical cache allocations:
# - Small collections (<100K): 0 GB (skip)
# - Medium (100K-1M): 1 GB
# - Large (1M-10M): 2 GB
# - XL (>10M): 4 GB
```

### 3. Batch Operations

**Always batch inserts**:

```python
# ❌ SLOW: Individual inserts (1,000 requests)
for vector in vectors:
    client.upsert(collection_name, points=[vector])

# ✅ FAST: Batch inserts (10 requests)
batch_size = 100
for i in range(0, len(vectors), batch_size):
    batch = vectors[i:i+batch_size]
    client.upsert(collection_name, points=batch)
```

**Benchmark Results**:
- Individual inserts: ~100 points/sec
- Batches of 1,000: ~10,000 points/sec
- **100x improvement** with proper batching

### 4. Flush Configuration

```bash
# Balance between durability and performance

# FOR DEVELOPMENT (less durability needed)
QDRANT__STORAGE__FLUSH_INTERVAL_MS=10000   # Flush every 10 seconds

# FOR PRODUCTION (strong durability)
QDRANT__STORAGE__FLUSH_INTERVAL_MS=5000    # Flush every 5 seconds

# FOR HIGH-THROUGHPUT (optimize performance)
QDRANT__STORAGE__FLUSH_INTERVAL_MS=2000    # Flush every 2 seconds
```

---

## Data Management & Backup

### 1. Snapshot Strategy

**Automated Snapshots**:

```bash
# Enable automatic snapshots
QDRANT__SNAPSHOTS__ENABLED=true

# Configure snapshot intervals
QDRANT__SNAPSHOTS__SNAPSHOT_INTERVAL=600  # Snapshot every 10 minutes

# Retention policy
QDRANT__SNAPSHOTS__MAX_SNAPSHOTS_TO_KEEP=10  # Keep last 10 snapshots
```

**Manual Snapshots**:

```bash
# Create on-demand snapshot
curl -X POST http://qdrant.railway.internal:6333/snapshots

# Get snapshot list
curl http://qdrant.railway.internal:6333/snapshots

# Download snapshot for backup (external storage)
# (Advanced: implement export script)
```

### 2. Backup & Recovery Procedures

**Railway Volume Backup**:

```bash
# Railway auto-manages volumes, but also:
# 1. Use snapshots for point-in-time recovery
# 2. Export critical collections regularly
# 3. Test recovery process monthly
```

**Collection Export for Compliance**:

```python
# Export collection to JSON for audit trail
from qdrant_client import QdrantClient
import json

client = QdrantClient(url="http://qdrant.railway.internal:6333")

# Get all points from collection
points = client.scroll("my_collection", limit=10000)[0]

# Save to file
with open("backup_my_collection.json", "w") as f:
    json.dump([p.dict() for p in points], f)
```

### 3. TTL Management

**Automatic Data Cleanup**:

```bash
# Delete vectors older than 30 days
curl -X POST http://qdrant.railway.internal:6333/collections/my_collection/points/delete \
  -H "Content-Type: application/json" \
  -d '{
    "filter": {
      "range": {
        "created_at": {
          "lt": $(date -d "30 days ago" +%s)
        }
      }
    }
  }'
```

---

## Monitoring & Observability

### 1. Key Metrics to Track

**Dashboard Setup** (in Railway):

| Metric | Target | Alert Threshold | Action |
|--------|--------|-----------------|--------|
| Health Check Success | 99.9% | < 95% | Investigate immediately |
| Query Latency (p95) | < 100ms | > 500ms | Scale CPU/memory |
| Memory Usage | < 75% | > 85% | Scale up |
| CPU Usage | < 70% | > 80% | Scale up |
| Disk Usage | < 70% | > 80% | Cleanup/Archive |
| Restart Count | 0/hour | > 1/hour | Check logs |

### 2. Prometheus Metrics

```bash
# Export metrics in Prometheus format
curl http://qdrant.railway.internal:6333/metrics

# Key metrics to extract:
# - qdrant_collections_total
# - qdrant_points_total
# - qdrant_searches_total
# - qdrant_indexing_inflight
# - process_resident_memory_bytes
```

### 3. Health Check Validation

```bash
# Create health check script
#!/bin/bash
QDRANT_URL="http://qdrant.railway.internal:6333"
API_KEY="your-api-key"

# Health endpoint
curl -f -H "api-key: $API_KEY" \
  --max-time 10 \
  "$QDRANT_URL/health" || exit 1

# Readiness endpoint
curl -f -H "api-key: $API_KEY" \
  --max-time 10 \
  "$QDRANT_URL/readyz" || exit 1

echo "Qdrant is healthy"
```

### 4. Logging Best Practices

**Log Levels**:
```bash
# Production: info (good visibility)
QDRANT__LOG_LEVEL=info

# Troubleshooting: debug (verbose)
QDRANT__LOG_LEVEL=debug

# Low-overhead: warn (errors only)
QDRANT__LOG_LEVEL=warn
```

**Log Aggregation**:
- Use Railway's built-in log viewer
- Search for error patterns: `ERROR`, `panic`, `timeout`
- Set up automated alerts for critical errors

---

## Disaster Recovery

### 1. Failover Strategy

**Single Instance → Multi-Instance** (when ready):

```yaml
# Plan for HA deployment
# 1. Scale to 2 replicas minimum for production
# 2. Configure load balancing in front of Qdrant
# 3. Implement raft consensus for consistency
```

### 2. Recovery Time Objectives (RTO/RPO)

```
Development:
- RTO: 1 hour (acceptable downtime)
- RPO: 4 hours (acceptable data loss)

Production:
- RTO: 15 minutes (maximum downtime)
- RPO: 5 minutes (maximum data loss)
```

### 3. Disaster Recovery Checklist

- [ ] Weekly snapshot tests (can we restore?)
- [ ] Monthly failover drills (full recovery simulation)
- [ ] Document recovery procedures
- [ ] Train team on recovery steps
- [ ] Maintain off-site backup copies
- [ ] Version control for all collection schemas

---

## Cost Optimization

### 1. Resource Right-Sizing

```
Monthly Cost Calculation:

Base: 2 CPU = $15/month, 4 GB RAM = $5/month
= $20/month base

Storage: 100 GB = $5/month

Total: ~$25/month for mid-tier production

Optimization:
- Dev: Pause during off-hours (save 30-50%)
- Staging: Share with dev (single instance)
- Production: Always-on but right-sized
```

### 2. Snapshot Storage Management

```bash
# Monitor snapshot growth
curl http://qdrant.railway.internal:6333/snapshots | jq '.result[] | .size'

# Delete old snapshots to save space
curl -X DELETE \
  http://qdrant.railway.internal:6333/snapshots/{snapshot_name}

# Recommendation: Keep only last 5 snapshots for cost
QDRANT__SNAPSHOTS__MAX_SNAPSHOTS_TO_KEEP=5
```

### 3. Vector Quantization for Cost

```python
# Reduce memory usage by 4-8x with quantization

# When creating collection:
{
  "name": "my_collection",
  "vectors": {
    "size": 384,
    "distance": "Cosine",
    "quantization_config": {
      "scalar": {
        "type": "uint8",
        "quantile": 0.99,
        "always_ram": true
      }
    }
  }
}

# Impact:
# - Original: 384 dims × 4 bytes = 1,536 bytes per vector
# - Quantized: 384 dims × 1 byte = 384 bytes per vector
# - Savings: 75% reduction in memory and storage
# - Accuracy loss: ~2-3% for most use cases
```

---

## Scaling Strategy

### Vertical Scaling (Single Instance)

**Trigger Points**:
- Memory > 85% → Scale up to next tier
- CPU > 80% for sustained periods → Increase CPU cores
- Query latency > target → Scale up resources

**Scaling Process**:
1. Monitor current usage
2. Increase Railway resource allocation
3. Test with expected workload
4. Monitor new performance

### Horizontal Scaling (Multiple Instances)

**When to Consider**:
- Approaching single-instance resource limits
- Need redundancy/high availability
- Millions of vectors requiring distributed storage
- Multi-region deployment

**Implementation**:
1. Deploy second Qdrant instance
2. Implement partition strategy (e.g., by collection or region)
3. Use load balancer to distribute traffic
4. Sync data between instances if needed

---

## Quick Reference

### Essential Commands

```bash
# Health check
curl http://qdrant.railway.internal:6333/readyz

# List all collections
curl http://qdrant.railway.internal:6333/collections

# Get collection stats
curl http://qdrant.railway.internal:6333/collections/{collection_name}

# System metrics
curl http://qdrant.railway.internal:6333/metrics

# Create snapshot
curl -X POST http://qdrant.railway.internal:6333/snapshots

# View snapshots
curl http://qdrant.railway.internal:6333/snapshots
```

### Environment Variables Template

```bash
# Copy to Railway environment:

# Core
QDRANT__SERVICE__HTTP_PORT=6333
QDRANT__SERVICE__GRPC_PORT=6334

# Security
QDRANT_API_KEY=<generate with: openssl rand -base64 32>

# Performance
QDRANT__PERFORMANCE__INDEX_THREADS=0
QDRANT__PERFORMANCE__VECTOR_CACHE_SIZE_GB=1

# Snapshots
QDRANT__SNAPSHOTS__ENABLED=true
QDRANT__SNAPSHOTS__SNAPSHOT_INTERVAL=600
QDRANT__SNAPSHOTS__MAX_SNAPSHOTS_TO_KEEP=5

# Storage
QDRANT__STORAGE__FLUSH_INTERVAL_MS=5000

# Logging
QDRANT__LOG_LEVEL=info
```

---

## Additional Resources

- **[Qdrant Official Docs](https://qdrant.tech/documentation/)**
- **[Railway Documentation](https://docs.railway.app/)**
- **[Qdrant Configuration](https://qdrant.tech/documentation/concepts/configuration/)**
- **[Performance Tuning Guide](https://qdrant.tech/documentation/concepts/indexing/)**

---

**Last Updated**: 2024
**Version**: 1.0 (Qdrant v1.13.1)
