# LiteLLM with Redis for Production

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/llm-stack?referralCode=qeah9u&utm_medium=integration&utm_source=template&utm_campaign=generic)

Production-ready LiteLLM proxy with PostgreSQL and Redis. Unified API for 100+ LLM providers.

## Overview

This stack provides a streamlined, production-ready LiteLLM deployment with persistent storage and caching:

**Core Services:**
- **LiteLLM** - Unified proxy for 100+ LLM providers (OpenAI, Anthropic, Azure, Google, and more)
- **PostgreSQL w/pgvector** - Managed database for caching, logging, and vector storage
- **Redis** - High-performance cache for rate limiting, session management, and job queues

**Primary Use Case:** Deploy a production-grade LLM proxy to Railway with minimal configuration. Route requests to multiple providers through a single, unified API endpoint with built-in caching and persistence.

**Alternative:** Run locally using Minikube + Skaffold (see [Local Development](#local-development) section).

---

## 🚀 Quick Start - Railway Deployment

### ✨ **Recommended Method: One-Click Template Deployment**

Deploy the stack to Railway in under 5 minutes:

<div align="center">

### **👉 [Deploy to Railway](https://railway.com/deploy?referralCode=YOUR_REFERRAL_CODE) 👈**

</div>

#### What Happens Automatically:
1. ✅ LiteLLM, PostgreSQL, and Redis services are deployed
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
3. Click **"Deploy"** and wait 3-5 minutes
4. Generate a public domain for the **litellm** service
5. Access your LiteLLM proxy at the generated URL!

**📚 Detailed Guide:** See [`QUICK_START_RAILWAY.md`](QUICK_START_RAILWAY.md:1) for step-by-step instructions with screenshots.

**💡 Optional:** After deployment, you can detach services from the template and customize them independently.

---

## What Gets Deployed

| Service | Port | Description | Documentation |
|---------|------|-------------|---------------|
| **LiteLLM** | 4000 | OpenAI-compatible proxy for 100+ LLM providers. Handles API key management, load balancing, caching, and fallbacks. | [`services/litellm/README.md`](services/litellm/README.md:1) |
| **PostgreSQL** | - | Managed database with pgvector extension for caching, logging, and vector storage. | [`services/postgres-pgvector/README.md`](services/postgres-pgvector/README.md:1) |
| **Redis** | - | Managed cache for rate limiting, session management, and distributed caching. | Railway Plugin |

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
- `OPENAI_API_KEY` - OpenAI models (GPT-4, GPT-3.5, etc.)
- `ANTHROPIC_API_KEY` - Anthropic models (Claude)
- `AZURE_API_KEY` / `AZURE_API_BASE` - Azure OpenAI
- `GOOGLE_APPLICATION_CREDENTIALS` - Google Vertex AI
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

## Usage Examples

### Basic API Call

```bash
curl -X POST http://litellm.railway.internal:4000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -d '{
    "model": "gpt-4",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

### List Available Models

```bash
curl http://litellm.railway.internal:4000/v1/models \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY"
```

### Health Check

```bash
curl http://litellm.railway.internal:4000/health
```

### Using with OpenAI SDK

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://litellm.railway.internal:4000",
    api_key="your-litellm-master-key"
)

response = client.chat.completions.create(
    model="gpt-4",
    messages=[{"role": "user", "content": "Hello!"}]
)
print(response.choices[0].message.content)
```

---

## Local Development

### Alternative: Run Locally with Minikube

For local development and testing, you can run the stack on your machine using Kubernetes.

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

# Access LiteLLM via port-forwarding
kubectl port-forward svc/litellm 4000:4000
```

**📚 Comprehensive Guides:**
- [`docs/local-dev/MINIKUBE_DEV_SETUP.md`](docs/local-dev/MINIKUBE_DEV_SETUP.md:1) - Complete setup and deployment guide
- [`docs/local-dev/SKAFFOLD_QUICKSTART.md`](docs/local-dev/SKAFFOLD_QUICKSTART.md:1) - Hot-reload development workflow
- [`docs/local-dev/MINIKUBE_QUICK_REFERENCE.md`](docs/local-dev/MINIKUBE_QUICK_REFERENCE.md:1) - Common commands and troubleshooting
- [`docs/local-dev/KUBERNETES_DEPLOYMENT_OVERVIEW.md`](docs/local-dev/KUBERNETES_DEPLOYMENT_OVERVIEW.md:1) - Architecture deep-dive

**Note:** Local development requires more setup and resources than Railway deployment. Railway is recommended for most users.

---

## Architecture

The stack uses a streamlined microservices architecture:

```
┌─────────────────────────────────────────────────────────────────┐
│                        Railway Platform                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│                         ┌──────────────┐                        │
│                         │   LiteLLM    │                        │
│  External Clients ───▶  │   :4000      │                        │
│                         └──────┬───────┘                        │
│                                │                                 │
│              ┌─────────────────┼─────────────────┐               │
│              │                 │                 │               │
│              ▼                 ▼                 ▼               │
│       ┌──────────┐      ┌──────────┐      ┌──────────┐          │
│       │ PostgreSQL│      │   Redis   │      │ External │          │
│       │  (Plugin) │      │  (Plugin) │      │ LLM APIs │          │
│       └──────────┘      └──────────┘      └──────────┘          │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Key Communication Paths:**
- **Clients → LiteLLM:** External clients connect to LiteLLM proxy (port 4000)
- **LiteLLM → LLM APIs:** LiteLLM routes requests to configured LLM providers
- **LiteLLM → PostgreSQL:** Caching, logging, and request tracking
- **LiteLLM → Redis:** Distributed caching and rate limiting

**Internal DNS:** All services use Railway's private networking (`service-name.railway.internal`) for secure, low-latency communication.

**📖 Architecture Deep-Dive:** See [`docs/architecture/OVERVIEW.md`](docs/architecture/OVERVIEW.md:1) for detailed information.

---

## Troubleshooting

### Common Issues

**LiteLLM Won't Start**
1. Check service logs in Railway dashboard → Select service → "Logs" tab
2. Verify `LITELLM_MASTER_KEY` is set
3. Ensure PostgreSQL and Redis plugins show "Running" status

**LLM API Errors**
1. Verify your LLM provider API keys are valid and have sufficient credits
2. Check [`services/litellm/config.yaml`](services/litellm/config.yaml:1) for model configuration
3. Review LiteLLM service logs for authentication errors

**Database Connection Issues**
1. Confirm PostgreSQL plugin is added and running
2. Verify `${{Postgres.*}}` variables are correctly referenced
3. Check LiteLLM service logs for connection errors

**Redis Connection Issues**
1. Confirm Redis plugin is added and running
2. Verify `${{Redis.REDIS_URL}}` variable is correctly referenced
3. Check LiteLLM service logs for Redis connection errors

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
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [Redis Documentation](https://redis.io/documentation)

**Acknowledgments:**
Built with [Railway](https://railway.app) • Powered by [LiteLLM](https://github.com/BerriAI/litellm)
