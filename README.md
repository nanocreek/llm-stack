# LLM Stack Template

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/od9RFE?referralCode=qeah9u&utm_medium=integration&utm_source=template&utm_campaign=generic)

A complete, production-ready AI application stack with one-click deployment to Railway. Get started with LLM-powered applications in minutes, not hours.

## Overview

This template provides everything you need to build and deploy AI-powered applications:

**Core Services:**
- **LiteLLM** - Unified proxy for 100+ LLM providers (OpenAI, Anthropic, Azure, etc.)
- **Open WebUI** - Beautiful chat interface with RAG support
- **PostgreSQL w/pgvector** - Managed database with vector search capabilities
- **Redis** - Managed cache for job queues and caching
- **Qdrant** - High-performance vector database for embeddings
- **R2R** - Retrieval-Augmented Generation framework
- **React Client** - Modern frontend for custom integrations

**Primary Use Case:** Deploy a complete AI stack to Railway with minimal configuration. Everything is pre-configured and ready to use.

**Alternative:** Run locally using Minikube + Skaffold (see [Local Development](#local-development) section).

---

## 🚀 Quick Start - Railway Deployment

### ✨ **Recommended Method: One-Click Template Deployment**

Deploy the entire stack to Railway in under 5 minutes:

<div align="center">

### **👉 [Deploy to Railway](https://railway.com/deploy?referralCode=YOUR_REFERRAL_CODE) 👈**

</div>

#### What Happens Automatically:
1. ✅ All 7 services are deployed from the `services/` directory
2. ✅ PostgreSQL and Redis plugins are added and configured
3. ✅ Service-to-service networking is set up
4. ✅ Environment variables are pre-configured with Railway references

#### What You Need to Provide:
1. **LITELLM_MASTER_KEY** - Generate a secure key: `openssl rand -base64 32`
2. **(Optional)** LLM provider API keys (OpenAI, Anthropic, etc.)
3. **(Optional)** Customize [`services/litellm/config.yaml`](services/litellm/config.yaml:1) for specific LLM models

#### Deployment Steps:
1. Click the **"Deploy to Railway"** button above
2. Railway will prompt you for required environment variables
3. Click **"Deploy"** and wait 5-10 minutes
4. Generate a public domain for **openwebui** service
5. Access your AI stack at the generated URL!

**📚 Detailed Guide:** See [`QUICK_START_RAILWAY.md`](QUICK_START_RAILWAY.md:1) for step-by-step instructions with screenshots.

**💡 Optional:** After deployment, you can detach services from the template and customize them independently.

---

## What Gets Deployed

| Service | Port | Description | Documentation |
|---------|------|-------------|---------------|
| **LiteLLM** | 4000 | OpenAI-compatible proxy for 100+ LLM providers. Handles API key management, load balancing, and fallbacks. | [`services/litellm/README.md`](services/litellm/README.md:1) |
| **Open WebUI** | 8080 | Feature-rich chat interface with RAG, document upload, conversation history, and model switching. | [`services/openwebui/README.md`](services/openwebui/README.md:1) |
| **PostgreSQL** | - | Managed database with pgvector extension for vector storage and document metadata. | [`services/postgres-pgvector/README.md`](services/postgres-pgvector/README.md:1) |
| **Redis** | - | Managed cache for R2R job queues, session management, and caching. | Railway Plugin |
| **Qdrant** | 6333 | High-performance vector database optimized for similarity search and embeddings. | [`services/qdrant/README.md`](services/qdrant/README.md:1) |
| **R2R** | 7272 | Complete RAG framework with document ingestion, chunking, embedding, and retrieval. | [`services/r2r/README.md`](services/r2r/README.md:1) |
| **React Client** | 3000 | Modern React frontend template for building custom AI-powered applications. | [`services/react-client/README.md`](services/react-client/README.md:1) |

**Service Communication:**
- All services communicate via Railway's internal private network (`*.railway.internal`)
- PostgreSQL and Redis are automatically injected as environment variables
- No manual networking configuration required

---

## Configuration

### Environment Variables

The Railway template pre-configures most variables automatically. You only need to provide:

**Required:**
- `LITELLM_MASTER_KEY` - Authentication key for your LiteLLM proxy

**Optional (for LLM access):**
- `OPENAI_API_KEY` - OpenAI models (GPT-3.5, GPT-4, etc.)
- `ANTHROPIC_API_KEY` - Anthropic models (Claude)
- Additional provider keys as needed

**📖 Complete Reference:** See [`ENV_VARIABLES_GUIDE.md`](ENV_VARIABLES_GUIDE.md:1) for all available configuration options.

### LiteLLM Configuration

Customize which LLM models are available by editing [`services/litellm/config.yaml`](services/litellm/config.yaml:1):

```yaml
model_list:
  - model_name: gpt-4
    litellm_params:
      model: openai/gpt-4
      api_key: os.environ/OPENAI_API_KEY
  - model_name: claude-3-opus
    litellm_params:
      model: anthropic/claude-3-opus-20240229
      api_key: os.environ/ANTHROPIC_API_KEY
```

After modifying the config, push changes to your repository and Railway will automatically redeploy.

---

## Local Development

### Alternative: Run Locally with Minikube

For local development and testing, you can run the entire stack on your machine using Kubernetes.

**Prerequisites:**
- [Docker](https://www.docker.com/) or [Podman](https://podman.io/)
- [Minikube](https://minikube.sigs.k8s.io/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Skaffold](https://skaffold.dev/) (optional, for hot-reload development)

**Quick Start:**
```bash
# Start Minikube cluster
minikube start --cpus=4 --memory=8192

# Deploy all services
kubectl apply -f k8s/manifests.yaml

# Access services via port-forwarding
kubectl port-forward svc/openwebui 8080:8080
```

**📚 Comprehensive Guides:**
- [`docs/local-dev/MINIKUBE_DEV_SETUP.md`](docs/local-dev/MINIKUBE_DEV_SETUP.md:1) - Complete setup and deployment guide
- [`docs/local-dev/SKAFFOLD_QUICKSTART.md`](docs/local-dev/SKAFFOLD_QUICKSTART.md:1) - Hot-reload development workflow
- [`docs/local-dev/MINIKUBE_QUICK_REFERENCE.md`](docs/local-dev/MINIKUBE_QUICK_REFERENCE.md:1) - Common commands and troubleshooting
- [`docs/local-dev/KUBERNETES_DEPLOYMENT_OVERVIEW.md`](docs/local-dev/KUBERNETES_DEPLOYMENT_OVERVIEW.md:1) - Architecture deep-dive

**Note:** Local development requires more setup and resources than Railway deployment. Railway is recommended for most users.

---

## Architecture

The stack uses a microservices architecture with internal service mesh:

```
┌─────────────────────────────────────────────────────────────────┐
│                        Railway Platform                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐     │
│  │ React Client │───▶│ OpenWebUI    │───▶│  LiteLLM     │     │
│  │   :3000      │    │   :8080      │    │   :4000      │     │
│  └──────────────┘    └──────────────┘    └──────┬───────┘     │
│                                                     │            │
│                                                     ▼            │
│                                              External LLM APIs  │
│                                                                  │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐     │
│  │     R2R      │◀───│   Qdrant     │    │ PostgreSQL   │     │
│  │   :7272      │    │   :6333      │    │   (Plugin)   │     │
│  └──────┬───────┘    └──────────────┘    └──────────────┘     │
│         │                                           │           │
│         └───────────────────────────────────────────┘           │
│                              │                                  │
│                              ▼                                  │
│                         ┌──────────┐                           │
│                         │  Redis   │                           │
│                         │ (Plugin) │                           │
│                         └──────────┘                           │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Key Communication Paths:**
- **Frontend → Backend:** React Client or Users → OpenWebUI (port 8080)
- **LLM Routing:** OpenWebUI → LiteLLM → External LLM APIs
- **RAG Pipeline:** R2R → Qdrant (vectors) + PostgreSQL (metadata) + Redis (caching)

**Internal DNS:** All services use Railway's private networking (`service-name.railway.internal`) for secure, low-latency communication.

**📖 Architecture Deep-Dive:** See [`plans/railway-template-architecture.md`](plans/railway-template-architecture.md:1) for detailed information.

---

## Troubleshooting

### Common Issues

**Service Won't Start**
1. Check service logs in Railway dashboard → Select service → "Logs" tab
2. Verify all required environment variables are set
3. Ensure PostgreSQL and Redis plugins show "Running" status

**Connection Errors Between Services**
1. Verify internal DNS names use `*.railway.internal` format
2. Check that services are using correct ports in environment variables
3. Review Railway project service dependencies

**LLM API Errors**
1. Verify your LLM provider API keys are valid and have sufficient credits
2. Check [`services/litellm/config.yaml`](services/litellm/config.yaml:1) for model configuration
3. Review LiteLLM service logs for authentication errors

**Database Connection Issues**
1. Confirm PostgreSQL plugin is added and running
2. Verify `${{Postgres.*}}` variables are correctly referenced
3. Check R2R service logs for connection errors

**Need More Help?**
- Check individual service READMEs in `services/` directories
- Review detailed local dev guides in [`docs/local-dev/`](docs/local-dev/:1)
- Open an issue on GitHub with logs and configuration details

---

## Contributing

Contributions are welcome! To contribute:

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Make your changes and test on Railway or locally
4. Update relevant documentation
5. Submit a pull request with a clear description

**Code Style:**
- Follow existing patterns in each service
- Update service-specific READMEs for changes
- Test all services after modifications
- Ensure Railway deployment still works

---

## License

This project is licensed under the MIT License - see the [`LICENSE`](LICENSE:1) file for details.

---

## Support & Resources

**Documentation:**
- [Railway Documentation](https://docs.railway.app)
- [LiteLLM Documentation](https://docs.litellm.ai)
- [Open WebUI Documentation](https://docs.openwebui.com)
- [R2R Documentation](https://docs.r2r.dev)
- [Qdrant Documentation](https://qdrant.tech/documentation)

**Acknowledgments:**
Built with [Railway](https://railway.app) • Powered by [R2R](https://github.com/SciPhi-AI/R2R), [Qdrant](https://qdrant.tech), [LiteLLM](https://github.com/BerriAI/litellm), and [Open WebUI](https://github.com/open-webui/open-webui)
