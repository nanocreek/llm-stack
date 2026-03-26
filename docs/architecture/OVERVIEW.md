# Architecture Overview

This document provides a comprehensive overview of the LiteLLM Stack deployment architecture on Railway, explaining how services work together to deliver a production-ready LLM proxy.

## Table of Contents

- [System Overview](#system-overview)
- [Services Breakdown](#services-breakdown)
- [Data Flow](#data-flow)
- [Deployment Architecture](#deployment-architecture)
- [Network Communication](#network-communication)
- [Storage Strategy](#storage-strategy)
- [Service Relationships Diagram](#service-relationships-diagram)

---

## System Overview

The LiteLLM Stack is a streamlined, production-ready microservices architecture designed for one-click deployment to Railway. It provides:

- **Unified LLM API**: Single endpoint for 100+ LLM providers
- **Persistent Caching**: PostgreSQL for request logging and caching
- **High-Performance Cache**: Redis for rate limiting and session management
- **Production-Ready**: Optimized for Railway with health monitoring and restart policies

**Primary Use Case:** Deploy a production-grade LLM proxy with minimal configuration. Route requests to multiple providers through a single, unified API endpoint with built-in caching and persistence.

**Deployment Target:** Optimized for Railway platform with automatic service discovery, health monitoring, and restart policies.

---

## Services Breakdown

### 1. LiteLLM (Port 4000)

**Purpose**: Unified API gateway and router for multiple Large Language Model providers.

**Role in Stack**: 
- Provides OpenAI-compatible API endpoint for all LLM interactions
- Centralizes API key management for various LLM providers
- Handles request routing, load balancing, and automatic failover
- Enables model switching without code changes
- Caches responses in PostgreSQL and Redis for improved performance

**Key Technologies**:
- Python-based proxy service
- OpenAI API compatibility layer
- Multi-provider support (OpenAI, Anthropic, Azure, Google, etc.)
- PostgreSQL integration for caching and logging
- Redis integration for distributed caching and rate limiting

**Configuration**: 
- [`services/litellm/config.yaml`](../../services/litellm/config.yaml:1) - Model definitions and routing rules
- Environment variables for API keys and database connections

**Dependencies**:
- PostgreSQL (optional) - API call logging and caching
- Redis (optional) - Distributed caching and rate limiting

**Documentation**: [`services/litellm/README.md`](../../services/litellm/README.md:1)

---

### 2. PostgreSQL with pgvector (Port 5432)

**Purpose**: Managed relational database with vector extension support.

**Role in Stack**:
- LiteLLM request caching for improved performance
- API call logging and analytics
- Optional vector storage for embeddings

**Key Technologies**:
- PostgreSQL 16 (Railway managed plugin or self-hosted)
- pgvector extension (optional, for vector storage)
- Persistent storage with automatic backups (when using Railway plugin)

**Configuration**:
- Railway automatically provides connection credentials (Railway deployment)
- Services reference via `${{Postgres.*}}` variables
- Self-hosted via `services/postgres-pgvector`

**Dependencies**: None (standalone service)

**Consumed By**:
- LiteLLM (optional caching and logging)

**Documentation**: [`services/postgres-pgvector/README.md`](../../services/postgres-pgvector/README.md:1)

---

### 3. Redis (Port 6379)

**Purpose**: High-performance in-memory cache and session store.

**Role in Stack**:
- API response caching for LiteLLM
- Rate limiting and distributed locks
- Session management (when authentication is enabled)

**Key Technologies**:
- Redis 7 (Railway managed plugin or self-hosted)
- In-memory key-value store
- Pub/sub messaging

**Configuration**:
- Railway provides `REDIS_URL` with embedded credentials (Railway deployment)
- Self-hosted via Kubernetes manifests (local development)

**Dependencies**: None (standalone service)

**Consumed By**:
- LiteLLM (optional caching and rate limiting)

---

## Data Flow

### User Request Flow

```
Client → LiteLLM → External LLM APIs → Response
               ↓
Response → LiteLLM → Client
```

**Detailed Steps**:
1. **Client Request**: Client sends a request to LiteLLM API
2. **Cache Check**: LiteLLM checks Redis cache for identical request
3. **Cache Hit**: Return cached response immediately
4. **Cache Miss**: LiteLLM routes to configured LLM provider
5. **External API Call**: LiteLLM forwards request to OpenAI, Anthropic, etc.
6. **Response Processing**: LiteLLM receives response and caches it
7. **Persistence**: Request/response logged in PostgreSQL (optional)
8. **Return**: Response returned to client

---

### Caching Flow

```
Request → LiteLLM → Check Redis Cache → Return Cached Response (if exists)
                          ↓
                    No Cache → Call LLM API → Cache Response → Return
```

**Cache Strategy**:
- Redis: Fast in-memory caching for identical requests
- PostgreSQL: Persistent logging for analytics and audit trails
- TTL-based expiration for cached responses

---

## Deployment Architecture

### Railway Platform Integration

**Isolated Containers**:
- Each service runs in a dedicated Linux container
- Railway manages container orchestration automatically
- Resource allocation (CPU, memory) configurable per service

**Health Monitoring**:
- LiteLLM defines health check endpoint (`/health`)
- Railway monitors health checks continuously
- Automatic restart on failure (configurable retry policy)

**Service Mesh**:
- Railway provides internal private network (`.railway.internal` domain)
- Services communicate via DNS-based service discovery
- No manual networking configuration required
- SSL/TLS handled automatically for external traffic

**Build Pipeline**:
1. **Source**: Railway monitors GitHub repository
2. **Build**: Dockerfile executed in build environment
3. **Deploy**: Container started with environment variables
4. **Health Check**: Railway waits for health endpoint to respond
5. **Ready**: Service marked as healthy and accessible

**Deployment Strategy**:
- Blue-green deployments (zero-downtime updates)
- Rollback capability to previous deployments
- Automatic scaling based on resource utilization

---

### Service Restart Policies

| Service | Restart Policy | Max Retries | Health Check Interval |
|---------|---------------|-------------|----------------------|
| LiteLLM | `ON_FAILURE` | 10 | 30s |
| PostgreSQL | Railway Managed | N/A | Railway Internal |
| Redis | Railway Managed | N/A | Railway Internal |

---

## Network Communication

### Internal DNS Resolution

Railway provides automatic DNS resolution for all services:

| Service | Internal DNS | Port | Protocol |
|---------|-------------|------|----------|
| LiteLLM | `litellm.railway.internal` | 4000 | HTTP |
| PostgreSQL | `${{Postgres.PGHOST}}` | 5432 | PostgreSQL Wire |
| Redis | `${{Redis.REDIS_HOST}}` | 6379 | Redis Protocol |

**Notes**:
- PostgreSQL and Redis use Railway plugin variables (e.g., `${{Postgres.PGHOST}}`)
- Internal DNS only accessible within Railway project
- External access requires public domain generation

---

### Communication Patterns

**Synchronous HTTP**:
- Client → LiteLLM (chat completions, embeddings)
- Health checks (Railway → LiteLLM)

**Database Connections**:
- LiteLLM → PostgreSQL (persistent TCP connection pool)

**Cache Connections**:
- LiteLLM → Redis (response caching, rate limiting)

---

### Port Exposure

**Internal Only** (Railway private network):
- Service-to-service communication
- Database and cache connections

**External Access** (requires public domain):
- LiteLLM (port 4000) - Primary API endpoint

**Security**:
- Internal services not accessible from internet by default
- Authentication via API keys (LiteLLM)
- PostgreSQL and Redis authentication handled by Railway

---

## Storage Strategy

### Where Data Lives

| Data Type | Storage Location | Persistence | Backup Strategy |
|-----------|-----------------|-------------|-----------------|
| **API Logs** | PostgreSQL | Persistent | Railway automated backups (plugin) |
| **Cache Data** | Redis | Ephemeral | Not backed up (regenerated) |
| **Request Cache** | Redis | Ephemeral | TTL-based expiration |

---

### PostgreSQL Schema Strategy

**Database Organization**:
- LiteLLM manages its own tables for caching and logging
- Connection pooling via service environment variables

**Key Tables** (managed by LiteLLM):
```
litellm_logs            - API call logs
litellm_cache           - Response cache
```

---

### Redis Key Strategy

**Namespacing**:
```
litellm:cache:{model}:{hash}       - Response cache
litellm:ratelimit:{key}            - Rate limiting
litellm:session:{id}               - Session data
```

**TTL (Time-To-Live)**:
- Cache entries: 1 hour (configurable)
- Rate limit windows: Configurable per plan
- Session data: 24 hours (refreshed on activity)

---

## Service Relationships Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          Railway Platform                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│                               ┌──────────────┐                          │
│                         ┌────▶│   LiteLLM    │◀────┐                    │
│                         │     │   :4000      │     │                    │
│   External Clients ─────┤     └──────┬───────┘     │                    │
│                         │            │             │                    │
│                         │            ▼             │                    │
│                         │      External LLM APIs   │                    │
│                         │    (OpenAI, Anthropic)   │                    │
│                         │                          │                    │
│              ┌──────────┴──────────┐               │                    │
│              │                     │               │                    │
│              ▼                     ▼               │                    │
│       ┌──────────┐          ┌──────────┐          │                    │
│       │ PostgreSQL│          │   Redis   │─────────┘                    │
│       │  (Plugin) │          │  (Plugin) │  (caching)                   │
│       └──────────┘          └──────────┘                               │
│                                                                           │
└─────────────────────────────────────────────────────────────────────────┘

Legend:
─────▶  HTTP/API Communication
◀────▶  Bidirectional Database/Cache Connection
```

**Communication Flow**:
1. External clients connect to **LiteLLM** via public URL
2. **LiteLLM** checks **Redis** cache for identical requests
3. **LiteLLM** forwards requests to external LLM providers
4. **LiteLLM** logs requests to **PostgreSQL** (optional)
5. Responses cached in **Redis** for future requests

---

## Service-Specific Documentation

For detailed information about each service:

### Core Services
- **LiteLLM**: [`services/litellm/README.md`](../../services/litellm/README.md:1)
- **PostgreSQL**: [`services/postgres-pgvector/README.md`](../../services/postgres-pgvector/README.md:1)

### Configuration
- **Environment Variables**: [`ENV_VARIABLES_GUIDE.md`](../../ENV_VARIABLES_GUIDE.md:1)
- **Service Communication**: [`docs/architecture/SERVICE_COMMUNICATION.md`](SERVICE_COMMUNICATION.md:1)

### Deployment
- **Quick Start**: [`QUICK_START_RAILWAY.md`](../../QUICK_START_RAILWAY.md:1)
- **Main README**: [`README.md`](../../README.md:1)

---

## Additional Resources

- **Railway Documentation**: https://docs.railway.app
- **LiteLLM Documentation**: https://docs.litellm.ai
- **PostgreSQL Documentation**: https://www.postgresql.org/docs/
- **Redis Documentation**: https://redis.io/documentation

---

**Last Updated**: 2026-03-26  
**Architecture Version**: 2.0 (Simplified - LiteLLM + PostgreSQL + Redis)
