# Qdrant on Railway: Quick Start Guide

Fast reference for deploying and operating Qdrant on Railway with best practices.

## 🚀 5-Minute Setup

### Step 1: Generate API Key
```bash
openssl rand -base64 32
# Copy the output - you'll need this
```

### Step 2: Add to Railway
1. Go to your Railway project
2. Click "New" → "GitHub Repo"
3. Select your forked `llm-stack` repository
4. Set root directory: `services/qdrant`
5. Click "Deploy"

### Step 3: Configure Environment
Railway Dashboard → Qdrant Service → "Variables"

Add these variables:
```
QDRANT__SERVICE__HTTP_PORT=6333
QDRANT__SERVICE__GRPC_PORT=6334
QDRANT_API_KEY=<paste-generated-key-here>
QDRANT__SNAPSHOTS__ENABLED=true
QDRANT__LOG_LEVEL=info
```

### Step 4: Verify
```bash
# Wait 60 seconds for startup, then:
curl http://qdrant.railway.internal:6333/readyz
# Expected: 200 OK
```

✅ Done! Qdrant is running.

---

## 📖 Common Tasks

### Create a Collection
```bash
curl -X PUT http://qdrant.railway.internal:6333/collections/my_collection \
  -H "api-key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "vectors": {
      "size": 384,
      "distance": "Cosine"
    }
  }'
```

### Insert Vectors
```bash
curl -X PUT http://qdrant.railway.internal:6333/collections/my_collection/points \
  -H "api-key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "points": [
      {
        "id": 1,
        "vector": [0.1, 0.2, 0.3, ...],
        "payload": {"text": "example"}
      }
    ]
  }'
```

### Search Vectors
```bash
curl -X POST http://qdrant.railway.internal:6333/collections/my_collection/points/search \
  -H "api-key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "vector": [0.1, 0.2, 0.3, ...],
    "limit": 10
  }'
```

### Check Health
```bash
curl http://qdrant.railway.internal:6333/readyz
```

### View Collections
```bash
curl http://qdrant.railway.internal:6333/collections \
  -H "api-key: YOUR_API_KEY"
```

### Create Snapshot
```bash
curl -X POST http://qdrant.railway.internal:6333/snapshots \
  -H "api-key: YOUR_API_KEY"
```

---

## 🔧 Configuration Profiles

### Development Environment
```bash
QDRANT__SERVICE__HTTP_PORT=6333
QDRANT__SERVICE__GRPC_PORT=6334
QDRANT__LOG_LEVEL=debug
# API key optional
```

### Production - Small
```bash
QDRANT__SERVICE__HTTP_PORT=6333
QDRANT__SERVICE__GRPC_PORT=6334
QDRANT_API_KEY=<required>
QDRANT__SNAPSHOTS__ENABLED=true
QDRANT__SNAPSHOTS__SNAPSHOT_INTERVAL=600
QDRANT__SNAPSHOTS__MAX_SNAPSHOTS_TO_KEEP=5
QDRANT__LOG_LEVEL=info
```

### Production - Large (>1M vectors)
```bash
QDRANT__SERVICE__HTTP_PORT=6333
QDRANT__SERVICE__GRPC_PORT=6334
QDRANT_API_KEY=<required>
QDRANT__SNAPSHOTS__ENABLED=true
QDRANT__SNAPSHOTS__SNAPSHOT_INTERVAL=300
QDRANT__SNAPSHOTS__MAX_SNAPSHOTS_TO_KEEP=10
QDRANT__PERFORMANCE__INDEX_THREADS=4
QDRANT__PERFORMANCE__VECTOR_CACHE_SIZE_GB=2
QDRANT__STORAGE__FLUSH_INTERVAL_MS=2000
QDRANT__LOG_LEVEL=info
```

---

## 📊 Resource Allocation

| Workload | CPU | Memory | Storage | Cost/month |
|----------|-----|--------|---------|-----------|
| Dev | 0.5 | 512MB | 10GB | $10 |
| Staging | 1 | 2GB | 50GB | $15 |
| Prod Small | 1 | 2GB | 50GB | $15 |
| Prod Medium | 2 | 4GB | 200GB | $30 |
| Prod Large | 4 | 8GB | 500GB | $60 |

---

## 🔐 Security Checklist

- [ ] API Key set in environment
- [ ] Never expose to internet
- [ ] Use internal DNS: `qdrant.railway.internal:6333`
- [ ] Rotate key every 90 days
- [ ] Monitor logs for unauthorized access

---

## 📈 Performance Tuning

### For Slow Queries
```bash
# Increase resources:
Railway Dashboard → Qdrant → Settings
- Increase CPU by 1 core
- Increase Memory by 2GB

# Check metrics:
curl http://qdrant.railway.internal:6333/metrics | grep latency
```

### For Memory Issues
```bash
# Use quantization (75% memory reduction):
{
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
```

### For High Throughput
```bash
# Use batch operations (100x faster):
# Instead of 1000 individual inserts:
# Send 1 batch of 1000 points

# Increase indexing threads:
QDRANT__PERFORMANCE__INDEX_THREADS=4
```

---

## 🐛 Troubleshooting

### Service Won't Start
```bash
# Check logs:
Railway Dashboard → Qdrant → Logs

# Common issues:
# - Port already in use (change in environment)
# - Insufficient memory (increase allocation)
# - Invalid API key format (regenerate)
```

### Can't Connect
```bash
# Test connectivity:
curl http://qdrant.railway.internal:6333/readyz

# If fails, check:
# - Qdrant service is running (check status)
# - Correct DNS name (qdrant.railway.internal)
# - Correct port (6333 for HTTP)
# - API key if configured (in request header)
```

### Slow Queries
```bash
# Check metrics:
curl http://qdrant.railway.internal:6333/metrics

# Look for:
# - High memory usage (> 85%)
# - High CPU usage (> 80%)
# - Large collection sizes
```

### Out of Storage
```bash
# Check disk usage:
curl http://qdrant.railway.internal:6333/collections

# Solutions:
# 1. Delete old snapshots
# 2. Remove old collections
# 3. Enable TTL for old vectors
# 4. Increase volume size
```

---

## 🔄 Client Connection Examples

### Python
```python
from qdrant_client import QdrantClient

client = QdrantClient(
    url="http://qdrant.railway.internal:6333",
    api_key="YOUR_API_KEY"
)

# Get collections
collections = client.get_collections()
```

### JavaScript/TypeScript
```typescript
import { QdrantClient } from "@qdrant/js-client-rest";

const client = new QdrantClient({
  url: "http://qdrant.railway.internal:6333",
  apiKey: "YOUR_API_KEY",
});

// Get collections
const collections = await client.getCollections();
```

### REST API
```bash
curl -H "api-key: YOUR_API_KEY" \
  http://qdrant.railway.internal:6333/collections
```

---

## 📚 Documentation References

Quick links to detailed information:

- **[Complete README](./README.md)** - Comprehensive documentation
- **[Best Practices Guide](./RAILWAY_BEST_PRACTICES.md)** - Production strategies
- **[Deployment Checklist](./DEPLOYMENT_CHECKLIST.md)** - Step-by-step setup
- **[Improvements Summary](./IMPROVEMENTS_SUMMARY.md)** - What's new
- **[Qdrant Official Docs](https://qdrant.tech/documentation/)** - Qdrant reference

---

## 💡 Pro Tips

1. **Always use batches** - 100x faster than individual operations
2. **Enable snapshots** - Automatic backup protection
3. **Set API key** - Required for production
4. **Monitor metrics** - Catch issues early
5. **Use quantization** - For large collections (save memory & cost)
6. **Test locally first** - Use Docker before deploying
7. **Backup regularly** - Test restore procedures
8. **Rotate keys** - Every 90 days minimum

---

## ✅ Verification Checklist

After deployment, verify:

- [ ] Service shows "Healthy" in Railway dashboard
- [ ] Health check endpoint responds: `curl http://qdrant.railway.internal:6333/readyz`
- [ ] Collections can be created and listed
- [ ] Vectors can be inserted and searched
- [ ] Snapshots are created automatically
- [ ] Logs show no errors
- [ ] Metrics endpoint accessible: `curl http://qdrant.railway.internal:6333/metrics`

---

## 🆘 Getting Help

**If something isn't working:**

1. Check the **[README Troubleshooting](./README.md#troubleshooting-guide)** section
2. Review **[Best Practices](./RAILWAY_BEST_PRACTICES.md)** for similar issues
3. Check Railway logs: Dashboard → Qdrant → Logs
4. Test endpoints manually with curl
5. Check [Qdrant community Discord](https://discord.gg/qdrant)

---

## 📞 Quick Reference

**Internal Address**: `qdrant.railway.internal:6333`  
**Ports**: HTTP=6333, gRPC=6334  
**Health Endpoint**: `/readyz`  
**Metrics Endpoint**: `/metrics`  
**API Documentation**: https://api.qdrant.tech/  

---

**Last Updated**: 2024  
**For Version**: Qdrant v1.13.1  
**Railway Compatible**: All versions
