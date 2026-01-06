# LLM Stack Template

A complete LLM application stack deployed on Railway, featuring a React frontend, RAG framework, vector database, LLM proxy, and web UI with managed PostgreSQL and Redis.

## Overview

This template provides a production-ready LLM application stack that includes:

- **React Client** - Frontend application for user interaction
- **R2R** - Retrieval-Augmented Generation framework for document processing
- **Qdrant** - High-performance vector database for embeddings
- **LiteLLM** - Unified API proxy for multiple LLM providers
- **OpenWebUI** - Chat interface for LLM interactions
- **PostgreSQL** - Managed database for document metadata
- **Redis** - Managed cache for job queues and caching

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Railway Platform                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐       │
│  │ React Client │───▶│ OpenWebUI    │───▶│  LiteLLM     │       │
│  │   :3000      │    │   :8080      │    │   :4000      │       │
│  └──────────────┘    └──────────────┘    └──────┬───────┘       │
│                                                     │             │
│                                                     ▼             │
│                                              External LLM APIs   │
│                                                                  │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐       │
│  │     R2R      │◀───│   Qdrant     │    │ PostgreSQL   │       │
│  │   :7272      │    │   :6333      │    │   (Plugin)   │       │
│  └──────┬───────┘    └──────────────┘    └──────────────┘       │
│         │                                                   │     │
│         └───────────────────────────────────────────────────┘     │
│                              │                                  │
│                              ▼                                  │
│                         ┌──────────┐                            │
│                         │  Redis   │                            │
│                         │ (Plugin) │                            │
│                         └──────────┘                            │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Service Inventory

| Service | Port | Description | Internal DNS |
|---------|------|-------------|--------------|
| **React Client** | 3000 | Frontend React application | `react-client.railway.internal` |
| **R2R** | 7272 | RAG framework for document processing | `r2r.railway.internal` |
| **Qdrant** | 6333 | Vector database for embeddings | `qdrant.railway.internal` |
| **LiteLLM** | 4000 | LLM API proxy for multiple providers | `litellm.railway.internal` |
| **OpenWebUI** | 8080 | Chat interface for LLM interactions | `openwebui.railway.internal` |
| **PostgreSQL** | - | Managed database plugin | `${{Postgres.PGHOST}}` |
| **Redis** | - | Managed cache plugin | `${{Redis.REDIS_URL}}` |

## Quick Start

### Prerequisites

- [Railway](https://railway.app) account
- Git installed on your local machine
- At least one LLM provider API key (OpenAI, Anthropic, etc.)

### Deployment Steps

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-username/llm-stack.git
   cd llm-stack
   ```

2. **Deploy to Railway**
   - Go to [railway.app](https://railway.app)
   - Click "New Project" → "Deploy from GitHub repo"
   - Select this repository
   - Railway will automatically detect the [`railway.json`](railway.json) template

3. **Configure environment variables**
   - Railway will prompt you to set required variables
   - Set `LITELLM_MASTER_KEY` to a strong random value
   - Add your LLM provider API keys (e.g., `OPENAI_API_KEY`)

4. **Add managed plugins**
   - Click "Add Plugin" → Select "PostgreSQL"
   - Click "Add Plugin" → Select "Redis"

5. **Deploy**
   - Railway will build and deploy all services
   - Wait for all services to show "Healthy" status

6. **Access your application**
   - Click on the "react-client" service
   - Use the generated Railway URL to access your app

For detailed deployment instructions, see [`DEPLOYMENT.md`](DEPLOYMENT.md).

## Service Communication

### Frontend to Backend
- **React Client → OpenWebUI**: HTTP requests on port 8080
  - Environment variable: `VITE_API_BASE_URL`

### LLM Routing
- **OpenWebUI → LiteLLM**: OpenAI-compatible API on port 4000
  - Uses `OPENAI_API_BASE_URL` and `OPENAI_API_KEY`
- **LiteLLM → External LLM APIs**: Provider-specific API calls
  - Configured via provider API keys

### RAG Pipeline
- **R2R → Qdrant**: HTTP on port 6333 for vector operations
  - Environment variables: `R2R_QDRANT_HOST`, `R2R_QDRANT_PORT`
- **R2R → PostgreSQL**: TCP for document metadata storage
  - Environment variables: `R2R_POSTGRES_*`
- **R2R → Redis**: TCP for caching and job queues
  - Environment variable: `REDIS_URL`

## Environment Variables

### Required Variables

| Variable | Service | Description |
|----------|---------|-------------|
| `LITELLM_MASTER_KEY` | LiteLLM | Master key for authentication (set a strong random value) |

### Optional Variables

| Variable | Service | Description |
|----------|---------|-------------|
| `OPENAI_API_KEY` | LiteLLM | OpenAI API key for GPT models |
| `ANTHROPIC_API_KEY` | LiteLLM | Anthropic API key for Claude models |

### Service-Specific Variables

Each service has its own `.env.example` file in its directory:
- [`services/react-client/.env.example`](services/react-client/.env.example)
- [`services/r2r/.env.example`](services/r2r/.env.example)
- [`services/qdrant/.env.example`](services/qdrant/.env.example)
- [`services/litellm/.env.example`](services/litellm/.env.example)
- [`services/openwebui/.env.example`](services/openwebui/.env.example)

## Service Startup Order

Services start in the following order to ensure dependencies are ready:

1. **PostgreSQL, Redis, Qdrant** (no dependencies)
2. **LiteLLM** (no internal dependencies)
3. **R2R** (depends on PostgreSQL, Redis, Qdrant)
4. **OpenWebUI** (depends on LiteLLM)
5. **React Client** (no dependencies)

## Troubleshooting

### Service Not Starting

1. **Check logs**: Click on any service in Railway dashboard → "Logs" tab
2. **Verify environment variables**: Ensure all required variables are set
3. **Check plugin status**: PostgreSQL and Redis should show "Running"

### Connection Errors

1. **Internal DNS**: Services communicate using `*.railway.internal` addresses
2. **Port conflicts**: Ensure no services use the same port
3. **Health checks**: All services have health check endpoints configured

### LLM API Errors

1. **Verify API keys**: Check that your provider API keys are valid
2. **Check LiteLLM logs**: Look for authentication or routing errors
3. **Test LiteLLM directly**: Access the LiteLLM service logs for debugging

### Database Connection Issues

1. **PostgreSQL plugin**: Ensure the plugin is added and running
2. **Connection variables**: Verify `R2R_POSTGRES_*` variables are set correctly
3. **Redis plugin**: Ensure Redis is added and `REDIS_URL` is configured

## Development

### Local Development

To run services locally:

```bash
# Start each service in its directory
cd services/react-client && npm install && npm run dev
cd services/qdrant && docker-compose up
cd services/litellm && litellm start --config config.yaml
cd services/openwebui && docker run -p 8080:8080 openwebui/open-webui
cd services/r2r && python -m r2r
```

### Service Documentation

Each service has its own README with detailed information:
- [`services/react-client/README.md`](services/react-client/README.md)
- [`services/r2r/README.md`](services/r2r/README.md)
- [`services/qdrant/README.md`](services/qdrant/README.md)
- [`services/litellm/README.md`](services/litellm/README.md)
- [`services/openwebui/README.md`](services/openwebui/README.md)

## Contributing

Contributions are welcome! Please follow these guidelines:

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/my-feature`
3. **Make your changes**
4. **Test thoroughly** on Railway
5. **Submit a pull request** with a clear description

### Code Style

- Follow existing code style in each service
- Update documentation for any changes
- Test all services after modifications

## License

This project is licensed under the MIT License - see the [`LICENSE`](LICENSE) file for details.

## Architecture Details

For detailed architecture information, see [`plans/railway-template-architecture.md`](plans/railway-template-architecture.md).

## Support

- **Railway Documentation**: [docs.railway.app](https://docs.railway.app)
- **R2R Documentation**: [docs.r2r.dev](https://docs.r2r.dev)
- **Qdrant Documentation**: [qdrant.tech/documentation](https://qdrant.tech/documentation)
- **LiteLLM Documentation**: [docs.litellm.ai](https://docs.litellm.ai)
- **OpenWebUI Documentation**: [docs.openwebui.com](https://docs.openwebui.com)

## Acknowledgments

- Built with [Railway](https://railway.app)
- Powered by [R2R](https://github.com/SciPhi-AI/R2R), [Qdrant](https://qdrant.tech), [LiteLLM](https://github.com/BerriAI/litellm), and [OpenWebUI](https://github.com/open-webui/open-webui)
