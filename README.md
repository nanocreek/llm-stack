# LLM Stack Template

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/od9RFE?referralCode=qeah9u&utm_medium=integration&utm_source=template&utm_campaign=generic)

A complete LLM application stack deployed on Railway, featuring a React frontend, RAG framework, vector database, LLM proxy, and web UI with managed PostgreSQL and Redis.

**✨ One-Click Deployment Available:** Click the button above to deploy all services automatically!

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
- At least one LLM provider API key (OpenAI, Anthropic, etc.)

### Deployment Options

#### Option A: Deploy from Template (Recommended) 🚀

**If a Railway template has been created for this repository**, you can use the one-click deployment:

**Click the "Deploy on Railway" button at the top of this page!**

The template will automatically:
- ✅ Create all 5 services from the `services/` directories
- ✅ Add PostgreSQL and Redis managed plugins
- ✅ Set up service-to-service communication
- ✅ Prompt you for required environment variables

**You only need to provide:**
1. Your LLM provider API keys (e.g., OpenAI, Anthropic)
2. A master key for LiteLLM authentication

**Deployment takes ~5-10 minutes.** Railway handles all the complexity!

#### Option A1: Create the Railway Template (For Repository Maintainers)

If you're the repository owner and want to enable one-click deployment for users, you need to create the template through Railway's UI. Railway templates **cannot be created via a `railway.json` file** - they must be configured through Railway's Template Builder.

**Two ways to create the template:**

**Method 1: From an Existing Deployment (Easier)**
1. Deploy the stack manually using Option B below
2. Once all services are running successfully, go to your Railway project
3. Click on the project settings (⚙️)
4. Click **"Create Template"** or **"Convert to Template"**
5. Railway will automatically capture all services, plugins, and environment variable keys
6. Publish the template
7. Update the Deploy button URL at the top of this README with your template URL

**Method 2: Using Template Builder (From Scratch)**
1. Go to your [Railway workspace settings](https://railway.app/account) → **Templates** page
2. Click **"New Template"**
3. **Add each service** by clicking **"+ New Service"**:
   - **Service**: Qdrant
     - **Source Repo**: `https://github.com/nanocreek/llm-stack`
     - **Root Directory**: `services/qdrant`
   - **Service**: LiteLLM
     - **Source Repo**: `https://github.com/nanocreek/llm-stack`
     - **Root Directory**: `services/litellm`
   - **Service**: R2R
     - **Source Repo**: `https://github.com/nanocreek/llm-stack`
     - **Root Directory**: `services/r2r`
   - **Service**: OpenWebUI
     - **Source Repo**: `https://github.com/nanocreek/llm-stack`
     - **Root Directory**: `services/openwebui`
   - **Service**: React-Client
     - **Source Repo**: `https://github.com/nanocreek/llm-stack`
     - **Root Directory**: `services/react-client`
4. **Add plugins**: Click **"+ New"** → **"Database"**
   - Add **PostgreSQL**
   - Add **Redis**
5. **Configure environment variables** for each service (Railway will prompt template users to fill these in)
6. **Publish the template**
7. Copy the template URL and update the Deploy button at the top of this README

**📚 Learn more:** [Creating Multi-Service Templates on Railway](https://docs.railway.com/guides/create)

#### Option B: Manual Service-by-Service Deployment

**⚠️ Important: This is a Monorepo**

If you need to deploy manually (e.g., for customization), note that this repository contains **5 separate services** in subdirectories. Railway cannot automatically detect and deploy all services when you import this repository directly.

**DO NOT** simply click "Deploy from GitHub repo" - Railway will fail to build because the root directory contains no application code.

Follow these steps to deploy this monorepo to Railway:

1. **Fork and clone this repository**
   ```bash
   git clone https://github.com/your-username/llm-stack.git
   ```

2. **Create an empty Railway project**
   - Go to [railway.app](https://railway.app)
   - Click **"New Project"** → **"Empty Project"**
   - Give your project a name (e.g., "LLM Stack")

3. **Add PostgreSQL and Redis plugins FIRST**
   - In your empty project, click **"+ New"**
   - Select **"Database"** → **"Add PostgreSQL"**
   - Click **"+ New"** again
   - Select **"Database"** → **"Add Redis"**
   
   ✅ Wait for both plugins to finish provisioning before continuing.

4. **Add each service manually** (repeat for all 5 services)

   For **EACH** of the following services, follow these steps:
   
   | Service Name | Root Directory |
   |-------------|----------------|
   | qdrant | `services/qdrant` |
   | litellm | `services/litellm` |
   | r2r | `services/r2r` |
   | openwebui | `services/openwebui` |
   | react-client | `services/react-client` |

   **Steps for each service:**
   1. Click **"+ New"** in your project
   2. Select **"GitHub Repo"**
   3. Authorize Railway to access your GitHub (if first time)
   4. Select your forked `llm-stack` repository
   5. **IMPORTANT**: Click **"Add variables"** or **"Configure"**
   6. Under **"Root Directory"** or **"Source"**, set the path from the table above
      - Example: For Qdrant, set root directory to `services/qdrant`
   7. Railway will detect the `Dockerfile` and `railway.toml` in that directory
   8. Click **"Deploy"** or **"Add service"**
   9. Repeat for the next service

5. **Configure environment variables**
   
   After all services are added, you need to set environment variables:
   
   **Option A: Per-Service Variables (Easier)**
   - Click on the **litellm** service
   - Go to **"Variables"** tab
   - Add these variables:
     - `LITELLM_PORT` = `4000`
     - `LITELLM_MASTER_KEY` = Generate a strong key: `openssl rand -base64 32`
     - `OPENAI_API_KEY` = Your OpenAI API key (optional)
     - `ANTHROPIC_API_KEY` = Your Anthropic API key (optional)
   
   - Click on the **openwebui** service → "Variables"
     - `PORT` = `8080`
     - `OPENAI_API_BASE_URL` = `http://litellm.railway.internal:4000/v1`
     - `OPENAI_API_KEY` = Use the same `LITELLM_MASTER_KEY` value
     - `WEBUI_AUTH` = `false`
   
   - Click on the **r2r** service → "Variables"
     - `R2R_PORT` = `7272`
     - `R2R_HOST` = `0.0.0.0`
     - `R2R_POSTGRES_HOST` = `${{Postgres.PGHOST}}`
     - `R2R_POSTGRES_PORT` = `${{Postgres.PGPORT}}`
     - `R2R_POSTGRES_USER` = `${{Postgres.PGUSER}}`
     - `R2R_POSTGRES_PASSWORD` = `${{Postgres.PGPASSWORD}}`
     - `R2R_POSTGRES_DBNAME` = `${{Postgres.PGDATABASE}}`
     - `R2R_VECTOR_DB_PROVIDER` = `qdrant`
     - `R2R_QDRANT_HOST` = `qdrant.railway.internal`
     - `R2R_QDRANT_PORT` = `6333`
     - `REDIS_URL` = `${{Redis.REDIS_URL}}`
   
   - Click on the **qdrant** service → "Variables"
     - `QDRANT__SERVICE__HTTP_PORT` = `6333`
     - `QDRANT__SERVICE__GRPC_PORT` = `6334`
   
   - Click on the **react-client** service → "Variables"
     - `PORT` = `3000`
     - `VITE_API_BASE_URL` = `http://openwebui.railway.internal:8080`

6. **Wait for all services to deploy**
   - Monitor each service's logs
   - All services should show "Active" or "Healthy"
   - Check for any errors in the logs

7. **Generate a public URL and access your app**
   - Click on the **openwebui** service (or **react-client**)
   - Go to **"Settings"** tab
   - Click **"Generate Domain"** under "Networking"
   - Use the generated URL to access your application

**📖 For detailed step-by-step instructions with screenshots, see [`DEPLOYMENT.md`](DEPLOYMENT.md).**

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
