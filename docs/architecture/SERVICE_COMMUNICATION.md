# Service Communication

This document explains how services in the LiteLLM Stack communicate with each other, including communication patterns, service discovery, authentication flows, and debugging techniques.

## Table of Contents

- [Communication Patterns](#communication-patterns)
- [Service Discovery](#service-discovery)
- [Authentication Flow](#authentication-flow)
- [Key Internal API Endpoints](#key-internal-api-endpoints)
- [Environment Variables for Communication](#environment-variables-for-communication)
- [Common Communication Issues](#common-communication-issues)
- [Testing and Examples](#testing-and-examples)

---

## Communication Patterns

### 1. Synchronous HTTP/REST

**Pattern**: Request-response model for immediate data retrieval or processing.

**Use Cases**:
- Chat completions (Client → LiteLLM)
- Embedding generation (Client → LiteLLM)
- Health checks (Railway → LiteLLM)

**Characteristics**:
- Blocking operation
- Immediate response required
- Timeout handling necessary
- Retry logic for transient failures

**Example Flow**:
```
Client → LiteLLM:4000/v1/chat/completions
          ↓
          LiteLLM → External LLM API
          ↓
          Response → Client
```

---

### 2. Database Connection Pooling

**Pattern**: Persistent TCP connections to PostgreSQL for efficient database access.

**Use Cases**:
- API logging (LiteLLM → PostgreSQL)
- Response caching (LiteLLM → PostgreSQL)
- Analytics and audit trails

**Characteristics**:
- Long-lived connections
- Connection pooling for efficiency
- Transaction support
- Automatic reconnection on failure

**Connection Management**:
```python
# Typical connection pool configuration
DATABASE_URL = "postgresql://user:pass@host:5432/db"
pool_size = 10  # Number of persistent connections
max_overflow = 20  # Additional connections if pool exhausted
```

---

### 3. Cache Operations (Redis)

**Pattern**: High-speed key-value operations for response caching.

**Use Cases**:
- Response caching (LiteLLM → Redis)
- Rate limiting (LiteLLM → Redis)
- Session management (optional)

**Characteristics**:
- Sub-millisecond latency
- TTL-based expiration
- Pub/sub for messaging
- Ephemeral data (survives restarts but not data loss)

**Operation Types**:
```bash
# Cache check
GET litellm:cache:{model}:{hash}

# Cache store with TTL
SET litellm:cache:{model}:{hash} {response} EX 3600

# Rate limiting
INCR litellm:ratelimit:{key}
EXPIRE litellm:ratelimit:{key} 60
```

---

## Service Discovery

### Railway Internal DNS

Railway automatically provides DNS-based service discovery using the `.railway.internal` domain.

**DNS Naming Convention**:
```
{service-name}.railway.internal
```

**Service DNS Names**:
| Service | Internal DNS | Port |
|---------|-------------|------|
| LiteLLM | `litellm.railway.internal` | 4000 |

**Plugin Services** (PostgreSQL, Redis):
- Use Railway variable interpolation: `${{Postgres.PGHOST}}`
- Railway automatically provides hostnames and credentials
- DNS names are dynamically assigned by Railway

---

### Service Discovery Mechanism

**How It Works**:
1. Railway assigns each service a unique internal hostname
2. DNS queries automatically resolve to the service's container IP
3. No manual configuration or service registry required
4. Services can immediately communicate after deployment

**DNS Resolution Example**:
```bash
# Inside any service container
nslookup litellm.railway.internal
# Returns: 10.x.x.x (internal IP)

curl http://litellm.railway.internal:4000/health
# Successfully connects to LiteLLM
```

---

### Environment Variable Reference Pattern

**For Custom Services**:
```bash
# Direct hostname reference
LITELLM_URL=http://litellm.railway.internal:4000
```

**For Railway Plugins**:
```bash
# Variable interpolation (automatically resolved)
DATABASE_URL=${{Postgres.DATABASE_URL}}
REDIS_URL=${{Redis.REDIS_URL}}
POSTGRES_HOST=${{Postgres.PGHOST}}
POSTGRES_PORT=${{Postgres.PGPORT}}
```

---

## Authentication Flow

### 1. LiteLLM Authentication

**Mechanism**: Bearer token authentication using `LITELLM_MASTER_KEY`.

**Flow**:
```
Client/Service → LiteLLM
Request Headers:
  Authorization: Bearer {LITELLM_MASTER_KEY}

LiteLLM validates key → Process request → Return response
```

**Configuration**:
```bash
# LiteLLM service
LITELLM_MASTER_KEY=sk-your-master-key-here

# Client using LiteLLM
OPENAI_API_KEY=sk-your-master-key-here  # Must match LITELLM_MASTER_KEY
```

**Security Notes**:
- Generate strong key: `openssl rand -base64 32`
- Never commit keys to version control
- Rotate keys periodically in production
- Store securely in Railway environment variables

---

### 2. PostgreSQL Authentication

**Mechanism**: Username/password authentication via connection string.

**Flow**:
```
Service → PostgreSQL
Connection String: postgresql://user:password@host:port/database

PostgreSQL validates credentials → Establishes connection
```

**Railway Management**:
- Railway automatically generates credentials
- Services use `${{Postgres.*}}` variables
- No manual credential management required

**Connection String Format**:
```
postgresql://{PGUSER}:{PGPASSWORD}@{PGHOST}:{PGPORT}/{PGDATABASE}
```

---

### 3. Redis Authentication

**Mechanism**: Password authentication (optional) via connection URL.

**Flow**:
```
Service → Redis
Connection URL: redis://:password@host:port

Redis validates password (if set) → Establishes connection
```

**Railway Management**:
- Railway provides `REDIS_URL` with embedded credentials
- Password protection optional but recommended
- Services reference via `${{Redis.REDIS_URL}}`

---

## Key Internal API Endpoints

### LiteLLM (Port 4000)

**Base URL**: `http://litellm.railway.internal:4000`

| Endpoint | Method | Purpose | Authentication |
|----------|--------|---------|----------------|
| `/health` | GET | Health check | None |
| `/health/liveliness` | GET | Liveness probe | None |
| `/v1/models` | GET | List available models | Bearer token |
| `/v1/chat/completions` | POST | Chat completion | Bearer token |
| `/v1/completions` | POST | Text completion | Bearer token |
| `/v1/embeddings` | POST | Generate embeddings | Bearer token |

**Example**:
```bash
curl -X POST http://litellm.railway.internal:4000/v1/chat/completions \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-4",
    "messages": [{"role": "user", "content": "Hello"}]
  }'
```

---

## Environment Variables for Communication

### LiteLLM Service

```bash
# Server configuration
LITELLM_HOST=0.0.0.0
LITELLM_PORT=4000
LITELLM_MASTER_KEY=sk-your-key-here

# Optional: Database and cache
DATABASE_URL=${{Postgres.DATABASE_URL}}
REDIS_URL=${{Redis.REDIS_URL}}
REDIS_HOST=${{Redis.REDIS_HOST}}
REDIS_PORT=${{Redis.REDIS_PORT}}

# LLM provider API keys
OPENAI_API_KEY=sk-...
ANTHROPIC_API_KEY=sk-ant-...
```

---

## Common Communication Issues

### Issue 1: Connection Refused

**Symptoms**:
```
Error: connect ECONNREFUSED
curl: (7) Failed to connect to service
```

**Causes**:
- Service is not running or still starting
- Incorrect hostname or port
- Service hasn't passed health checks yet

**Solutions**:
1. Verify service is running in Railway dashboard
2. Check service logs for startup errors
3. Confirm hostname uses `.railway.internal` suffix
4. Wait for health checks to pass (check Railway status)
5. Test with health endpoint first: `curl http://litellm.railway.internal:4000/health`

---

### Issue 2: Authentication Failures

**Symptoms**:
```
401 Unauthorized
403 Forbidden
Authentication failed
```

**Causes**:
- Missing or incorrect API key
- Invalid credentials

**Solutions**:

**For LiteLLM**:
```bash
# Verify correct key is set
# LiteLLM service:
LITELLM_MASTER_KEY=sk-abc123

# Client:
Authorization: Bearer sk-abc123  # Must match exactly
```

---

### Issue 3: Timeout Errors

**Symptoms**:
```
Request timeout after 30s
Gateway timeout (504)
Connection timed out
```

**Causes**:
- Service overloaded or processing slowly
- Network congestion
- Long-running operations without proper timeout handling

**Solutions**:
1. Increase timeout in client configuration
2. Check service resource allocation (CPU, memory)
3. Review service logs for slow operations
4. Implement retry logic with exponential backoff

**Example timeout configuration**:
```python
import httpx

client = httpx.Client(timeout=60.0)  # 60 second timeout
response = client.post(url, json=data)
```

---

### Issue 4: DNS Resolution Failures

**Symptoms**:
```
getaddrinfo ENOTFOUND litellm.railway.internal
Could not resolve hostname
```

**Causes**:
- Service name typo
- Service doesn't exist in project
- Railway internal DNS not available

**Solutions**:
1. Verify exact service name in Railway dashboard
2. Confirm service is deployed in same Railway project
3. Use correct format: `{service-name}.railway.internal`
4. Check Railway platform status: https://status.railway.app

---

### Issue 5: Wrong Port

**Symptoms**:
```
Empty reply from server
Connection reset by peer
```

**Causes**:
- Using wrong port number
- Service listening on different port than configured

**Solutions**:
1. Verify port in service's environment variables
2. Check service-specific documentation for default ports
3. Review Dockerfile EXPOSE statements
4. Test with correct port mapping

**Correct Ports**:
```bash
litellm.railway.internal:4000      # LiteLLM
```

---

## Testing and Examples

### Health Check Testing

Test LiteLLM is accessible:

```bash
# LiteLLM
curl http://litellm.railway.internal:4000/health
# Expected: {"status": "healthy"}
```

---

### End-to-End Communication Test

**1. Test LiteLLM Chat Completion**:
```bash
curl -X POST http://litellm.railway.internal:4000/v1/chat/completions \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-4",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

---

### Python Client Example

```python
import httpx
import os

# Service endpoints
LITELLM_URL = "http://litellm.railway.internal:4000"

# Authentication
LITELLM_KEY = os.getenv("LITELLM_MASTER_KEY")

# LiteLLM chat completion
def chat_completion(message: str, model: str = "gpt-4"):
    response = httpx.post(
        f"{LITELLM_URL}/v1/chat/completions",
        headers={"Authorization": f"Bearer {LITELLM_KEY}"},
        json={
            "model": model,
            "messages": [{"role": "user", "content": message}]
        },
        timeout=60.0
    )
    return response.json()

# Example usage
result = chat_completion("What is LiteLLM?")
print(result["choices"][0]["message"]["content"])
```

---

### JavaScript/TypeScript Client Example

```typescript
// Service endpoints
const LITELLM_URL = "http://litellm.railway.internal:4000";

// Authentication
const LITELLM_KEY = process.env.LITELLM_MASTER_KEY;

// LiteLLM chat completion
async function chatCompletion(message: string, model: string = "gpt-4") {
  const response = await fetch(`${LITELLM_URL}/v1/chat/completions`, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${LITELLM_KEY}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      model: model,
      messages: [{ role: "user", content: message }]
    })
  });
  return response.json();
}

// Example usage
const result = await chatCompletion("What is LiteLLM?");
console.log(result.choices[0].message.content);
```

---

## Additional Resources

- **Architecture Overview**: [`docs/architecture/OVERVIEW.md`](OVERVIEW.md:1)
- **Environment Variables**: [`ENV_VARIABLES_GUIDE.md`](../../ENV_VARIABLES_GUIDE.md:1)
- **Service READMEs**: [`services/*/README.md`](../../services/README.md:1)

---

**Last Updated**: 2026-03-26  
**Version**: 2.0 (Simplified - LiteLLM + PostgreSQL + Redis)
