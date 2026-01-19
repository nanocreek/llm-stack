# Architecture Overview

This document provides a comprehensive overview of the LLM Stack deployment architecture on Railway, explaining how all services work together to deliver a complete AI application platform.

## Table of Contents

- [System Overview](#system-overview)
- [Services Breakdown](#services-breakdown)
- [Data Flow](#data-flow)
- [Deployment Architecture](#deployment-architecture)
- [Network Communication](#network-communication)
- [Storage Strategy](#storage-strategy)
- [Service Relationships Diagram](#service-relationships-diagram)
- [Service-Specific Documentation](#service-specific-documentation)

---

## System Overview

The LLM Stack is a production-ready microservices architecture designed for one-click deployment to Railway. It provides everything needed to build and deploy AI-powered applications, including:

- **AI Model Access**: Unified interface to 100+ LLM providers
- **User Interface**: Modern web interface for chat interactions
- **Document Processing**: RAG (Retrieval-Augmented Generation) pipeline
- **Vector Search**: High-performance similarity search for embeddings
- **Data Persistence**: Relational and vector database storage
- **Caching**: Redis-based caching for performance optimization
- **Custom Frontend**: React-based client template for extensibility

**Primary Use Case**: Deploy a complete, scalable AI application stack with minimal configuration. All services are pre-configured to work together using Railway's internal networking.

**Deployment Target**: Optimized for Railway platform with automatic service discovery, health monitoring, and restart policies.

---

## Services Breakdown

### 1. LiteLLM (Port 4000)

**Purpose**: Unified API gateway and router for multiple Large Language Model providers.

**Role in Stack**: 
- Provides OpenAI-compatible API endpoint for all LLM interactions
- Centralizes API key management for various LLM providers
- Handles request routing, load balancing, and automatic failover
- Enables model switching without code changes

**Key Technologies**:
- Python-based proxy service
- OpenAI API compatibility layer
- Multi-provider support (OpenAI, Anthropic, Azure, Google, etc.)

**Configuration**: 
- [`services/litellm/config.yaml`](../../services/litellm/config.yaml:1) - Model definitions and routing rules
- Environment variables for API keys and database connections

**Dependencies**:
- PostgreSQL (optional) - API call logging and analytics
- Redis (optional) - Distributed caching and rate limiting

**Documentation**: [`services/litellm/README.md`](../../services/litellm/README.md:1)

---

### 2. Open WebUI (Port 8080)

**Purpose**: Feature-rich web interface for LLM interactions with chat functionality, user management, and document handling.

**Role in Stack**:
- Primary user-facing interface for AI interactions
- Manages user sessions and conversation history
- Provides document upload and RAG integration
- Handles authentication and access control

**Key Technologies**:
- Modern web application (Node.js/Python backend)
- OpenAI-compatible client integration
- Session management and authentication
- Document processing capabilities

**Configuration**:
- Environment variables for LiteLLM connection
- PostgreSQL for user data and conversations
- Redis for session management
- Qdrant integration for vector search

**Dependencies**:
- **LiteLLM** (required) - Backend LLM API
- **PostgreSQL** (required) - User data and conversation history
- **Redis** (required) - Session caching
- **Qdrant** (optional) - RAG and vector search features

**Documentation**: [`services/openwebui/README.md`](../../services/openwebui/README.md:1)

---

### 3. PostgreSQL with pgvector (Port 5432)

**Purpose**: Managed relational database with optional vector extension support.

**Role in Stack**:
- Primary data store for application metadata
- User accounts and authentication data
- Conversation history and document metadata
- LiteLLM API logs and analytics

**Key Technologies**:
- PostgreSQL 16 (Railway managed plugin)
- pgvector extension (optional, for this stack Qdrant is primary)
- Persistent storage with automatic backups

**Configuration**:
- Railway automatically provides connection credentials
- Services reference via `${{Postgres.*}}` variables

**Dependencies**: None (standalone service)

**Consumed By**:
- LiteLLM (optional logging)
- Open WebUI (required)
- R2R (required for metadata)

**Documentation**: [`services/postgres-pgvector/README.md`](../../services/postgres-pgvector/README.md:1)

---

### 4. Redis (Port 6379)

**Purpose**: High-performance in-memory cache and session store.

**Role in Stack**:
- Session management for Open WebUI
- API response caching for LiteLLM
- R2R job queue and task management
- Rate limiting and distributed locks

**Key Technologies**:
- Redis 7 (Railway managed plugin)
- In-memory key-value store
- Pub/sub messaging

**Configuration**:
- Railway automatically provides connection URL
- Services reference via `${{Redis.REDIS_URL}}`

**Dependencies**: None (standalone service)

**Consumed By**:
- LiteLLM (optional caching)
- Open WebUI (required sessions)
- R2R (required job queue)

**Documentation**: Railway Plugin (no custom service)

---

### 5. Qdrant (Port 6333 HTTP, 6334 gRPC)

**Purpose**: High-performance vector database for embeddings and similarity search.

**Role in Stack**:
- Primary vector storage for document embeddings
- Similarity search for RAG (Retrieval-Augmented Generation)
- Efficient nearest-neighbor queries
- Persistent vector storage with snapshots

**Key Technologies**:
- Qdrant v1.13.1 (Rust-based vector database)
- RESTful HTTP API and high-performance gRPC
- Multiple distance metrics (Cosine, Euclidean, Dot Product)
- Quantization for memory optimization

**Configuration**:
- Environment variables for ports and API keys
- Persistent volume at `/qdrant/storage`
- Automatic snapshot generation

**Dependencies**: None (standalone service)

**Consumed By**:
- R2R (primary vector storage)
- Open WebUI (RAG features)

**Documentation**: 
- [`services/qdrant/README.md`](../../services/qdrant/README.md:1)
- [`services/qdrant/TROUBLESHOOTING.md`](../../services/qdrant/TROUBLESHOOTING.md:1)

---

### 6. R2R (Port 7272)

**Purpose**: Retrieval-Augmented Generation framework for document processing and intelligent search.

**Role in Stack**:
- Document ingestion and chunking
- Embedding generation and vector storage
- RAG query pipeline (retrieve + generate)
- Document management API

**Key Technologies**:
- R2R 3.x framework (Python)
- Document processors (PDF, DOCX, TXT, etc.)
- Integration with LiteLLM for completions
- Vector storage via Qdrant

**Configuration**:
- Dynamic configuration generation in `start.sh`
- PostgreSQL for document metadata
- Qdrant for vector embeddings
- Redis for job queues

**Dependencies**:
- **PostgreSQL** (required) - Document metadata
- **Qdrant** (required) - Vector storage
- **Redis** (required) - Job queue
- **LiteLLM** (optional) - LLM completions

**Important Note**: This deployment includes a pgvector error suppression wrapper because Railway's PostgreSQL doesn't include the pgvector extension. R2R uses Qdrant for vectors instead.

**Documentation**: 
- [`services/r2r/README.md`](../../services/r2r/README.md:1)
- [`services/r2r/PGVECTOR_WORKAROUND.md`](../../services/r2r/PGVECTOR_WORKAROUND.md:1)

---

### 7. React Client (Port 3000)

**Purpose**: Modern React-based frontend template for custom AI application development.

**Role in Stack**:
- Alternative frontend to Open WebUI
- Custom integration examples
- Extensible UI template for developers
- Direct API integration showcase

**Key Technologies**:
- React 18 with modern hooks
- Vite for fast development and building
- TypeScript support
- Modular component architecture

**Configuration**:
- `VITE_API_BASE_URL` points to Open WebUI or directly to services
- Environment variables for service endpoints

**Dependencies**:
- Open WebUI (typical backend)
- Can integrate with any service via internal DNS

**Documentation**: [`services/react-client/README.md`](../../services/react-client/README.md:1) (if exists)

---

## Data Flow

### User Request Flow

```
User → Open WebUI → LiteLLM → External LLM APIs → Response
                                      ↓
                                   Response → LiteLLM → Open WebUI → User
```

**Detailed Steps**:
1. **User Input**: User enters a prompt in Open WebUI chat interface
2. **Request Routing**: Open WebUI sends request to `http://litellm.railway.internal:4000/v1/chat/completions`
3. **Model Selection**: LiteLLM routes to configured model based on `config.yaml`
4. **External API Call**: LiteLLM forwards request to OpenAI, Anthropic, or other provider
5. **Response Processing**: LiteLLM receives response and forwards to Open WebUI
6. **Display**: Open WebUI displays response to user
7. **Persistence**: Conversation saved to PostgreSQL, session cached in Redis

---

### RAG (Retrieval-Augmented Generation) Pipeline

```
Document Upload → R2R → Process & Chunk → Generate Embeddings → Store in Qdrant
                  ↓
             Metadata → PostgreSQL

User Query → R2R → Query Qdrant → Retrieve Relevant Chunks
                                            ↓
                     Context + Query → LiteLLM → LLM → Answer
```

**Detailed Steps**:
1. **Document Ingestion**: 
   - User uploads document via Open WebUI or R2R API
   - R2R processes and chunks document into segments
   
2. **Embedding Generation**:
   - R2R generates vector embeddings for each chunk
   - Embeddings stored in Qdrant as vectors
   - Metadata (title, source, timestamps) stored in PostgreSQL

3. **Query Processing**:
   - User asks a question via Open WebUI
   - R2R generates query embedding
   
4. **Similarity Search**:
   - R2R queries Qdrant for similar document chunks (k-nearest neighbors)
   - Qdrant returns top N most relevant chunks
   
5. **Context Assembly**:
   - R2R combines relevant chunks into context
   - Constructs prompt: `Context: {chunks}\n\nQuestion: {user_query}`
   
6. **LLM Generation**:
   - R2R sends augmented prompt to LiteLLM
   - LiteLLM routes to configured LLM
   - LLM generates answer based on provided context
   
7. **Response Delivery**:
   - Answer returned to user with source attribution
   - Query/response logged in PostgreSQL

---

### Caching and Session Management

```
User Login → Open WebUI → Session Created → Redis (cache)
                                              ↓
                                    Session Validated on Each Request

LLM Request → LiteLLM → Check Redis Cache → Return Cached Response (if exists)
                              ↓
                        No Cache → Call LLM API → Cache Response → Return
```

---

## Deployment Architecture

### Railway Platform Integration

**Isolated Containers**:
- Each service runs in a dedicated Linux container
- Railway manages container orchestration automatically
- Resource allocation (CPU, memory) configurable per service

**Health Monitoring**:
- Each service defines health check endpoint in `Dockerfile`
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
| Open WebUI | `ON_FAILURE` | 10 | 30s |
| Qdrant | `ON_FAILURE` | 10 | 30s |
| R2R | `ON_FAILURE` | 10 | 30s |
| React Client | `ON_FAILURE` | 10 | 30s |
| PostgreSQL | Railway Managed | N/A | Railway Internal |
| Redis | Railway Managed | N/A | Railway Internal |

---

## Network Communication

### Internal DNS Resolution

Railway provides automatic DNS resolution for all services:

| Service | Internal DNS | Port | Protocol |
|---------|-------------|------|----------|
| LiteLLM | `litellm.railway.internal` | 4000 | HTTP |
| Open WebUI | `openwebui.railway.internal` | 8080 | HTTP |
| R2R | `r2r.railway.internal` | 7272 | HTTP |
| Qdrant | `qdrant.railway.internal` | 6333, 6334 | HTTP, gRPC |
| React Client | `react-client.railway.internal` | 3000 | HTTP |
| PostgreSQL | `${{Postgres.PGHOST}}` | 5432 | PostgreSQL Wire |
| Redis | `${{Redis.REDIS_HOST}}` | 6379 | Redis Protocol |

**Notes**:
- PostgreSQL and Redis use Railway plugin variables (e.g., `${{Postgres.PGHOST}}`)
- Internal DNS only accessible within Railway project
- External access requires public domain generation

---

### Communication Patterns

**Synchronous HTTP**:
- Open WebUI → LiteLLM (chat completions)
- R2R → Qdrant (vector search)
- R2R → LiteLLM (RAG completions)
- React Client → Open WebUI (API calls)

**Database Connections**:
- Open WebUI → PostgreSQL (persistent TCP connection pool)
- R2R → PostgreSQL (persistent TCP connection pool)
- LiteLLM → PostgreSQL (optional logging)

**Cache Connections**:
- Open WebUI → Redis (session management)
- R2R → Redis (job queue)
- LiteLLM → Redis (response caching)

**Vector Operations**:
- R2R → Qdrant (HTTP REST or gRPC)
- Open WebUI → Qdrant (HTTP REST for search)

---

### Port Exposure

**Internal Only** (Railway private network):
- All service-to-service communication
- Database and cache connections

**External Access** (requires public domain):
- Open WebUI (port 8080) - Primary user interface
- React Client (port 3000) - Alternative frontend
- Other services can be exposed if needed via Railway settings

**Security**:
- Internal services not accessible from internet by default
- Authentication via API keys (LiteLLM, Qdrant)
- PostgreSQL and Redis authentication handled by Railway

---

## Storage Strategy

### Where Data Lives

| Data Type | Storage Location | Persistence | Backup Strategy |
|-----------|-----------------|-------------|-----------------|
| **User Accounts** | PostgreSQL | Persistent | Railway automated backups |
| **Conversation History** | PostgreSQL | Persistent | Railway automated backups |
| **Document Metadata** | PostgreSQL | Persistent | Railway automated backups |
| **API Logs** | PostgreSQL | Persistent | Railway automated backups |
| **Vector Embeddings** | Qdrant | Persistent | Qdrant snapshots + volume |
| **Document Vectors** | Qdrant | Persistent | Qdrant snapshots + volume |
| **Session Data** | Redis | Ephemeral | Not backed up (recreated) |
| **Cache Data** | Redis | Ephemeral | Not backed up (regenerated) |
| **R2R Job Queue** | Redis | Ephemeral | Job retry on failure |

---

### PostgreSQL Schema Strategy

**Database Organization**:
- Separate tables per service (logical separation)
- Shared database instance (Railway managed)
- Connection pooling via service environment variables

**Key Tables** (conceptual):
```
openwebui_users          - User accounts
openwebui_conversations  - Chat history
openwebui_documents      - Uploaded files metadata
r2r_documents           - RAG document registry
r2r_chunks              - Document chunk metadata
litellm_logs            - API call logs (optional)
```

---

### Qdrant Collections Strategy

**Collection Organization**:
- One collection per document type or use case
- Configurable vector dimensions (e.g., 384, 768, 1536)
- Distance metrics: Cosine (recommended for text embeddings)

**Example Collections**:
```
documents_default       - General document storage
user_documents_<user>   - User-specific documents
knowledge_base          - Company knowledge embeddings
```

**Persistence**:
- Data stored in `/qdrant/storage` (Railway volume)
- Automatic snapshots every 10 minutes (configurable)
- Survives service restarts and redeployments

---

### Redis Key Strategy

**Namespacing**:
```
openwebui:session:{session_id}     - User sessions
openwebui:cache:{cache_key}        - UI cache
litellm:cache:{model}:{hash}       - Response cache
r2r:job:{job_id}                   - Job status
r2r:queue:pending                  - Job queue
```

**TTL (Time-To-Live)**:
- Sessions: 24 hours (refreshed on activity)
- LLM cache: 1 hour (configurable)
- Job data: 7 days (configurable)

---

## Service Relationships Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          Railway Platform                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  ┌─────────────┐      ┌──────────────┐      ┌─────────────┐            │
│  │React Client │─────▶│  Open WebUI  │─────▶│  LiteLLM    │───────┐    │
│  │   :3000     │      │    :8080     │      │   :4000     │       │    │
│  └─────────────┘      └──────┬───────┘      └─────────────┘       │    │
│         │                    │                      │               │    │
│         │                    │                      │               ▼    │
│         │                    ▼                      │        External    │
│         │             ┌─────────────┐              │        LLM APIs    │
│         │             │ PostgreSQL  │              │      (OpenAI, etc) │
│         │             │  (Plugin)   │              │                    │
│         │             └──────┬──────┘              │                    │
│         │                    │                     │                    │
│         │                    │  ┌──────────────────┘                    │
│         │                    │  │                                       │
│         │                    │  │  ┌─────────────┐                     │
│         └────────────────────┼──┼─▶│   Qdrant    │                     │
│                              │  │  │   :6333     │                     │
│                              │  │  └──────▲──────┘                     │
│                              │  │         │                             │
│                              │  │         │                             │
│         ┌────────────────────┼──┼─────────┘                             │
│         │                    │  │                                       │
│         │                    ▼  ▼                                       │
│    ┌────┴─────┐         ┌──────────┐                                   │
│    │   R2R    │◀────────│  Redis   │                                   │
│    │  :7272   │         │ (Plugin) │                                   │
│    └──────────┘         └──────────┘                                   │
│                                                                           │
└─────────────────────────────────────────────────────────────────────────┘

Legend:
─────▶  HTTP/API Communication
◀────▶  Bidirectional Database/Cache Connection
```

**Communication Flow**:
1. Users access **React Client** or **Open WebUI** via public URL
2. **Open WebUI** queries **LiteLLM** for chat completions
3. **LiteLLM** forwards requests to external LLM providers
4. **Open WebUI** stores data in **PostgreSQL** and uses **Redis** for sessions
5. **R2R** handles document ingestion, stores vectors in **Qdrant**, metadata in **PostgreSQL**
6. **R2R** uses **Redis** for job queue management
7. **R2R** optionally calls **LiteLLM** for RAG completions
8. **Open WebUI** queries **Qdrant** directly for vector search in RAG features

---

## Service-Specific Documentation

For detailed information about each service:

### Core Services
- **LiteLLM**: [`services/litellm/README.md`](../../services/litellm/README.md:1)
- **Open WebUI**: [`services/openwebui/README.md`](../../services/openwebui/README.md:1)
- **R2R**: [`services/r2r/README.md`](../../services/r2r/README.md:1)
- **Qdrant**: [`services/qdrant/README.md`](../../services/qdrant/README.md:1)
- **PostgreSQL**: [`services/postgres-pgvector/README.md`](../../services/postgres-pgvector/README.md:1)

### Troubleshooting
- **Qdrant Troubleshooting**: [`services/qdrant/TROUBLESHOOTING.md`](../../services/qdrant/TROUBLESHOOTING.md:1)
- **R2R pgvector Workaround**: [`services/r2r/PGVECTOR_WORKAROUND.md`](../../services/r2r/PGVECTOR_WORKAROUND.md:1)
- **Common Issues**: [`docs/troubleshooting/COMMON_ISSUES.md`](../troubleshooting/COMMON_ISSUES.md:1)

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
- **Open WebUI Documentation**: https://docs.openwebui.com
- **R2R Documentation**: https://docs.r2r.dev
- **Qdrant Documentation**: https://qdrant.tech/documentation

---

**Last Updated**: 2026-01-19  
**Architecture Version**: 1.0 (Railway-optimized)
