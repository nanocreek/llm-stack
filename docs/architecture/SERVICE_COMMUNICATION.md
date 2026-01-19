# Service Communication

This document explains how services in the LLM Stack communicate with each other, including communication patterns, service discovery, authentication flows, and debugging techniques.

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
- Chat completions (Open WebUI → LiteLLM)
- Vector search queries (R2R → Qdrant)
- Document ingestion (Client → R2R)
- Health checks (Railway → All Services)

**Characteristics**:
- Blocking operation
- Immediate response required
- Timeout handling necessary
- Retry logic for transient failures

**Example Flow**:
```
Client → OpenWebUI:8080/api/chat
         ↓
         OpenWebUI → LiteLLM:4000/v1/chat/completions
                     ↓
                     LiteLLM → External LLM API
                     ↓
                     Response → OpenWebUI → Client
```

---

### 2. Database Connection Pooling

**Pattern**: Persistent TCP connections to PostgreSQL for efficient database access.

**Use Cases**:
- User authentication (Open WebUI → PostgreSQL)
- Conversation history storage (Open WebUI → PostgreSQL)
- Document metadata (R2R → PostgreSQL)
- API logging (LiteLLM → PostgreSQL, optional)

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

**Pattern**: High-speed key-value operations for session data and caching.

**Use Cases**:
- Session management (Open WebUI → Redis)
- Response caching (LiteLLM → Redis)
- Job queue (R2R → Redis)
- Rate limiting (LiteLLM → Redis)

**Characteristics**:
- Sub-millisecond latency
- TTL-based expiration
- Pub/sub for messaging
- Ephemeral data (survives restarts but not data loss)

**Operation Types**:
```bash
# Session storage
SET openwebui:session:{id} {data} EX 86400

# Cache check
GET litellm:cache:{model}:{hash}

# Queue operation
LPUSH r2r:queue:pending {job_data}
```

---

### 4. Vector Operations (Qdrant)

**Pattern**: Specialized vector similarity search and storage operations.

**Use Cases**:
- Store document embeddings (R2R → Qdrant)
- Similarity search (R2R → Qdrant)
- Collection management (R2R → Qdrant)
- Direct search (Open WebUI → Qdrant, optional)

**Characteristics**:
- RESTful HTTP API (primary)
- gRPC API (high-performance option)
- Batch operations for efficiency
- Asynchronous indexing

**API Types**:
```bash
# HTTP REST (Port 6333)
POST /collections/{name}/points/search

# gRPC (Port 6334)
# Higher performance for high-volume operations
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
| Open WebUI | `openwebui.railway.internal` | 8080 |
| R2R | `r2r.railway.internal` | 7272 |
| Qdrant | `qdrant.railway.internal` | 6333, 6334 |
| React Client | `react-client.railway.internal` | 3000 |

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
QDRANT_HOST=qdrant.railway.internal
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

# Open WebUI (as LiteLLM client)
OPENAI_API_KEY=sk-your-master-key-here  # Must match LITELLM_MASTER_KEY
```

**Security Notes**:
- Generate strong key: `openssl rand -base64 32`
- Never commit keys to version control
- Rotate keys periodically in production
- Store securely in Railway environment variables

---

### 2. Qdrant Authentication

**Mechanism**: API key header authentication.

**Flow**:
```
Client/Service → Qdrant
Request Headers:
  api-key: {QDRANT_API_KEY}

Qdrant validates key → Process request → Return response
```

**Configuration**:
```bash
# Qdrant service
QDRANT_API_KEY=your-secure-api-key

# R2R service (as Qdrant client)
R2R_QDRANT_API_KEY=your-secure-api-key  # Must match
```

**Optional**: Qdrant can run without authentication for internal development, but API key is **strongly recommended** for production.

---

### 3. PostgreSQL Authentication

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

### 4. Redis Authentication

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

### 5. Open WebUI Session Management

**Mechanism**: Session cookies with Redis backend.

**Flow**:
```
User Login → Open WebUI
           ↓
  Generate session ID + Store in Redis
           ↓
  Set-Cookie: session_id={id}; HttpOnly; Secure
           ↓
Subsequent Requests → Validate session from Redis
```

**Configuration**:
```bash
WEBUI_SECRET_KEY=your-secret-key-here  # For cookie signing
SESSION_COOKIE_SECURE=true  # HTTPS only in production
REDIS_URL=${{Redis.REDIS_URL}}  # Session storage
```

---

## Key Internal API Endpoints

### LiteLLM (Port 4000)

**Base URL**: `http://litellm.railway.internal:4000`

| Endpoint | Method | Purpose | Authentication |
|----------|--------|---------|----------------|
| `/health` | GET | Health check | None |
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

### Open WebUI (Port 8080)

**Base URL**: `http://openwebui.railway.internal:8080`

| Endpoint | Method | Purpose | Authentication |
|----------|--------|---------|----------------|
| `/` | GET | Web UI / Health check | None |
| `/api/chat` | POST | Chat interaction | Session cookie |
| `/api/documents` | POST | Upload document | Session cookie |
| `/api/auth/signin` | POST | User login | None |

**Example**:
```bash
# Access web interface
curl http://openwebui.railway.internal:8080/

# API requires authentication (session cookie)
```

---

### R2R (Port 7272)

**Base URL**: `http://r2r.railway.internal:7272`

| Endpoint | Method | Purpose | Authentication |
|----------|--------|---------|----------------|
| `/health` | GET | Health check | None |
| `/v3/health` | GET | Detailed health status | None |
| `/v3/ingest` | POST | Ingest documents | Optional API key |
| `/v3/rag` | POST | RAG query | Optional API key |
| `/v3/search` | POST | Vector search | Optional API key |
| `/v3/documents` | GET | List documents | Optional API key |

**Example**:
```bash
# Health check
curl http://r2r.railway.internal:7272/health

# Ingest document
curl -X POST http://r2r.railway.internal:7272/v3/ingest \
  -H "Content-Type: application/json" \
  -d '{
    "document": {
      "text": "Document content",
      "metadata": {"title": "Example"}
    }
  }'
```

---

### Qdrant (Port 6333 HTTP, 6334 gRPC)

**Base URL**: `http://qdrant.railway.internal:6333`

| Endpoint | Method | Purpose | Authentication |
|----------|--------|---------|----------------|
| `/health` | GET | Health check | None |
| `/readyz` | GET | Readiness probe | None |
| `/metrics` | GET | Prometheus metrics | None |
| `/collections` | GET | List collections | API key |
| `/collections/{name}/points/search` | POST | Vector search | API key |
| `/collections/{name}/points` | PUT | Insert vectors | API key |

**Example**:
```bash
# Health check (no auth)
curl http://qdrant.railway.internal:6333/health

# Search (requires API key)
curl -X POST http://qdrant.railway.internal:6333/collections/docs/points/search \
  -H "api-key: $QDRANT_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "vector": [0.1, 0.2, ...],
    "limit": 10
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

# LLM provider API keys
OPENAI_API_KEY=sk-...
ANTHROPIC_API_KEY=sk-ant-...
```

---

### Open WebUI Service

```bash
# Server configuration
PORT=8080

# LiteLLM connection
OPENAI_API_BASE_URL=http://litellm.railway.internal:4000/v1
OPENAI_API_KEY=sk-your-key-here  # Must match LITELLM_MASTER_KEY

# Database and cache
DATABASE_URL=${{Postgres.DATABASE_URL}}
REDIS_URL=${{Redis.REDIS_URL}}

# Qdrant connection (for RAG features)
VECTOR_DB=qdrant
QDRANT_URI=http://qdrant.railway.internal:6333
QDRANT_HOST=qdrant.railway.internal
QDRANT_PORT=6333

# Security
WEBUI_SECRET_KEY=your-secret-key-here
```

---

### R2R Service

```bash
# Server configuration
R2R_HOST=0.0.0.0
R2R_PORT=7272

# PostgreSQL connection
R2R_POSTGRES_HOST=${{Postgres.PGHOST}}
R2R_POSTGRES_PORT=${{Postgres.PGPORT}}
R2R_POSTGRES_USER=${{Postgres.PGUSER}}
R2R_POSTGRES_PASSWORD=${{Postgres.PGPASSWORD}}
R2R_POSTGRES_DBNAME=${{Postgres.PGDATABASE}}

# Qdrant connection
R2R_VECTOR_DB_PROVIDER=qdrant
R2R_QDRANT_HOST=qdrant.railway.internal
R2R_QDRANT_PORT=6333

# Redis connection
REDIS_URL=${{Redis.REDIS_URL}}

# LiteLLM connection (optional)
LITELLM_URL=http://litellm.railway.internal:4000
```

---

### Qdrant Service

```bash
# Ports
QDRANT__SERVICE__HTTP_PORT=6333
QDRANT__SERVICE__GRPC_PORT=6334

# Security
QDRANT_API_KEY=your-secure-api-key

# Optional: Performance tuning
QDRANT__LOG_LEVEL=info
```

---

### React Client Service

```bash
# Server configuration
PORT=3000

# Backend API
VITE_API_BASE_URL=http://openwebui.railway.internal:8080
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
5. Test with health endpoint first: `curl http://service.railway.internal:port/health`

---

### Issue 2: Authentication Failures

**Symptoms**:
```
401 Unauthorized
403 Forbidden
Authentication failed
```

**Causes**:
- Mismatched API keys between services
- Missing Authorization header
- Expired or invalid credentials

**Solutions**:

**For LiteLLM**:
```bash
# Verify both services have matching keys
# LiteLLM service:
LITELLM_MASTER_KEY=sk-abc123

# Open WebUI service:
OPENAI_API_KEY=sk-abc123  # Must match exactly
```

**For Qdrant**:
```bash
# Verify both services have matching keys
# Qdrant service:
QDRANT_API_KEY=secure-key

# R2R service:
R2R_QDRANT_API_KEY=secure-key  # Must match
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
5. Consider async operations for long-running tasks

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
getaddrinfo ENOTFOUND service.railway.internal
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
404 Not Found (on wrong service)
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
openwebui.railway.internal:8080    # Open WebUI
r2r.railway.internal:7272          # R2R
qdrant.railway.internal:6333       # Qdrant HTTP
qdrant.railway.internal:6334       # Qdrant gRPC
```

---

## Testing and Examples

### Health Check Testing

Test all services are accessible:

```bash
# LiteLLM
curl http://litellm.railway.internal:4000/health
# Expected: {"status": "healthy"}

# Open WebUI
curl http://openwebui.railway.internal:8080/
# Expected: HTML content (200 OK)

# R2R
curl http://r2r.railway.internal:7272/health
# Expected: {"status": "ok"}

# Qdrant
curl http://qdrant.railway.internal:6333/health
# Expected: {"status": "ok"}
```

---

### End-to-End Communication Test

**1. Store a vector in Qdrant via R2R**:
```bash
curl -X POST http://r2r.railway.internal:7272/v3/ingest \
  -H "Content-Type: application/json" \
  -d '{
    "document": {
      "text": "Railway makes deployment easy",
      "metadata": {"source": "test"}
    }
  }'
```

**2. Query via LiteLLM**:
```bash
curl -X POST http://litellm.railway.internal:4000/v1/chat/completions \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-4",
    "messages": [{"role": "user", "content": "What is Railway?"}]
  }'
```

**3. Test RAG pipeline via R2R**:
```bash
curl -X POST http://r2r.railway.internal:7272/v3/rag \
  -H "Content-Type: application/json" \
  -d '{"query": "Tell me about deployment"}'
```

---

### Python Client Example

```python
import httpx
import os

# Service endpoints
LITELLM_URL = "http://litellm.railway.internal:4000"
R2R_URL = "http://r2r.railway.internal:7272"
QDRANT_URL = "http://qdrant.railway.internal:6333"

# Authentication
LITELLM_KEY = os.getenv("LITELLM_MASTER_KEY")
QDRANT_KEY = os.getenv("QDRANT_API_KEY")

# LiteLLM chat completion
def chat_completion(message: str):
    response = httpx.post(
        f"{LITELLM_URL}/v1/chat/completions",
        headers={"Authorization": f"Bearer {LITELLM_KEY}"},
        json={
            "model": "gpt-4",
            "messages": [{"role": "user", "content": message}]
        },
        timeout=30.0
    )
    return response.json()

# R2R document ingestion
def ingest_document(text: str, metadata: dict):
    response = httpx.post(
        f"{R2R_URL}/v3/ingest",
        json={"document": {"text": text, "metadata": metadata}},
        timeout=60.0
    )
    return response.json()

# Qdrant search
def search_vectors(collection: str, vector: list, limit: int = 10):
    response = httpx.post(
        f"{QDRANT_URL}/collections/{collection}/points/search",
        headers={"api-key": QDRANT_KEY},
        json={"vector": vector, "limit": limit},
        timeout=10.0
    )
    return response.json()
```

---

### JavaScript/TypeScript Client Example

```typescript
// Service endpoints
const LITELLM_URL = "http://litellm.railway.internal:4000";
const R2R_URL = "http://r2r.railway.internal:7272";
const QDRANT_URL = "http://qdrant.railway.internal:6333";

// Authentication
const LITELLM_KEY = process.env.LITELLM_MASTER_KEY;
const QDRANT_KEY = process.env.QDRANT_API_KEY;

// LiteLLM chat completion
async function chatCompletion(message: string) {
  const response = await fetch(`${LITELLM_URL}/v1/chat/completions`, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${LITELLM_KEY}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      model: "gpt-4",
      messages: [{ role: "user", content: message }]
    })
  });
  return response.json();
}

// R2R document ingestion
async function ingestDocument(text: string, metadata: object) {
  const response = await fetch(`${R2R_URL}/v3/ingest`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      document: { text, metadata }
    })
  });
  return response.json();
}

// Qdrant search
async function searchVectors(collection: string, vector: number[], limit = 10) {
  const response = await fetch(
    `${QDRANT_URL}/collections/${collection}/points/search`,
    {
      method: "POST",
      headers: {
        "api-key": QDRANT_KEY,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({ vector, limit })
    }
  );
  return response.json();
}
```

---

## Additional Resources

- **Architecture Overview**: [`docs/architecture/OVERVIEW.md`](OVERVIEW.md:1)
- **Troubleshooting Guide**: [`docs/troubleshooting/COMMON_ISSUES.md`](../troubleshooting/COMMON_ISSUES.md:1)
- **Environment Variables**: [`ENV_VARIABLES_GUIDE.md`](../../ENV_VARIABLES_GUIDE.md:1)
- **Service READMEs**: [`services/*/README.md`](../../services/README.md:1)

---

**Last Updated**: 2026-01-19  
**Version**: 1.0 (Railway-optimized)
