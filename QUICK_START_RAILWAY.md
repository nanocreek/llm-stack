# 🚀 Quick Start: Deploy to Railway in 5 Minutes

Deploy a complete LLM application stack with one click. This guide gets you from zero to a running application with LiteLLM, Open WebUI, R2R RAG framework, and vector database—all managed by Railway.

**What you'll have:** A production-ready LLM stack with chat interface, RAG capabilities, and managed databases.

## Prerequisites

- **Railway account** - [Sign up free](https://railway.app)
- **GitHub account** - For optional customization
- That's it! Railway handles everything else.

## Step 1: Deploy to Railway

Click the button below to start your deployment:

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/od9RFE?referralCode=qeah9u&utm_medium=integration&utm_source=template&utm_campaign=generic)

**What happens when you click:**
1. Railway creates a new project in your account
2. Deploys 7 services automatically:
   - **LiteLLM** - Unified API proxy for multiple LLM providers (OpenAI, Anthropic, etc.)
   - **Open WebUI** - Modern chat interface for LLM interactions
   - **PostgreSQL** - Managed database for metadata and application data
   - **Redis** - Managed cache for job queues and caching
   - **Qdrant** - High-performance vector database for embeddings
   - **R2R** - RAG framework for document processing and retrieval
   - **React Client** - Frontend application for user interaction
3. Prompts you to configure required variables
4. Sets up internal networking between services

Railway will prompt you for configuration—continue to Step 2.

## Step 2: Configure Required Variables

Railway will ask you to set these critical variables. Here's what each one does and how to set it:

### ✅ LITELLM_MASTER_KEY

**What it is:** Authentication key for LiteLLM proxy service. All other services use this to communicate with LiteLLM.

**How to generate:** Run this command in your terminal:
```bash
openssl rand -base64 32
```

**Example value:** `sk-a7K3jP9mNx8vQ2wR5tY1bZ4cD6eF8gH0`

**Where to use it:** 
- Set as `LITELLM_MASTER_KEY` in LiteLLM service
- Set as `OPENAI_API_KEY` in OpenWebUI service (same value!)

### ✅ POSTGRES_PASSWORD

**What it is:** Password for your PostgreSQL database. Railway auto-generates this if you use their managed plugin.

**Important note:** If using Railway's PostgreSQL plugin (recommended), Railway provides this automatically. You don't need to set it manually.

**If setting manually:** Use a strong password with at least 16 characters.

### ✅ REDIS_PASSWORD

**What it is:** Password for your Redis instance. Railway auto-generates this if you use their managed plugin.

**Important note:** If using Railway's Redis plugin (recommended), Railway provides this automatically via `REDIS_URL`.

**If setting manually:** Use a strong password with at least 16 characters.

### Optional: LLM Provider API Keys

Add API keys for the LLM providers you want to use:

- `OPENAI_API_KEY` - For GPT-3.5, GPT-4, etc. (get from [OpenAI platform](https://platform.openai.com/api-keys))
- `ANTHROPIC_API_KEY` - For Claude models (get from [Anthropic console](https://console.anthropic.com/))

**Note:** You can add these later in Railway's Variables tab for the LiteLLM service.

📖 **For complete variable reference:** See [`ENV_VARIABLES_GUIDE.md`](ENV_VARIABLES_GUIDE.md)

## Step 3: Edit LiteLLM Config (Optional)

Want to configure which LLM models are available? Edit the LiteLLM configuration file before deployment.

**How to edit:**
1. In Railway's deployment flow, look for the service configuration screens
2. Find the LiteLLM service
3. Click "View Variables" or "Edit Configuration"
4. Some templates allow editing [`services/litellm/config.yaml`](services/litellm/config.yaml) directly

**What you can configure:**
- Model routing and load balancing
- Model aliases (e.g., `gpt-4` → `gpt-4-0125-preview`)
- Rate limits and timeouts
- Fallback models
- Custom model parameters

📖 **For advanced configuration:** See [LiteLLM Docs](https://docs.litellm.ai/docs/proxy/configs)

**Skip this step if:** You're fine with default settings. You can always edit this later by modifying the file in your Railway project.

## Step 4: Wait for Deployment

Railway deploys your services automatically. Here's what to expect:

⏱️ **Typical deployment time:** 5-8 minutes for all services

**How to monitor:**
1. Railway dashboard shows real-time deployment status
2. Each service card displays:
   - 🟡 Building... (compiling Docker images)
   - 🟢 Deployed (service is running)
   - 🔴 Failed (check logs for errors)

**Success looks like:** All 7 service cards show 🟢 "Deployed" status

**If something fails:** Click the service → "Logs" tab to see error details. Common issues are missing environment variables or invalid API keys.

## Step 5: Access Your Services

Once deployment completes, find your application URLs:

**To access Open WebUI (main interface):**
1. Click on the **openwebui** service in Railway dashboard
2. Go to "Settings" tab
3. Find the "Public Networking" section
4. Generated domain will look like: `openwebui-production-xxxx.up.railway.app`
5. Click the URL to open your chat interface

**Other service endpoints:**
- **React Client**: Generate domain from `react-client` service (alternative frontend)
- **R2R API**: Generate domain from `r2r` service (for document upload/search)
- **LiteLLM API**: Internal only by default (accessible via Open WebUI)

🎉 **You're live!** Start chatting with your LLM stack.

## Optional: Detach and Customize

Want to modify the code or configuration? Detach your Railway project to get full control.

**What detaching does:**
- Railway creates a new GitHub repository in your account
- Copies all service code and configuration files
- Links your Railway project to this new repo
- Any changes you push to the repo automatically redeploy

**Benefits:**
- ✅ Full control over code and configuration
- ✅ Ability to add custom services or modify existing ones
- ✅ Track changes with Git version control
- ✅ Collaborate with your team via GitHub

**How to detach:**
1. In Railway dashboard, go to your project
2. Click project settings (⚙️ icon)
3. Look for "Repository" or "GitHub" section
4. Click "Detach" or "Create GitHub Repository"
5. Railway creates a new repo and links it automatically
6. Clone your new repo to make changes locally

**After detaching:** Push changes to your repo's main branch to trigger automatic redeployments.

## Next Steps

Now that you're running, explore these resources:

- 📖 **Full Documentation**: See [`README.md`](README.md) for detailed architecture and service information
- ⚙️ **Configuration Guide**: See [`ENV_VARIABLES_GUIDE.md`](ENV_VARIABLES_GUIDE.md) for all environment variables and advanced configuration
- 🔧 **Troubleshooting**: Common issues and solutions (coming soon)
- 💻 **Local Development**: Want to run locally? See [`docs/local-dev/`](docs/local-dev/) for Kubernetes/Minikube setup

**Configure your models:**
- Edit [`services/litellm/config.yaml`](services/litellm/config.yaml) to add or remove LLM providers
- Restart the LiteLLM service in Railway after changes

**Add more services:**
- Fork/detach to a GitHub repo
- Add new services in `services/` directory
- Railway auto-detects and deploys them

## Troubleshooting Quick Tips

### ❌ Deployment Failed

**Symptom:** Service shows red "Failed" status

**Fix:** Click service → "Logs" tab. Look for:
- Missing environment variables: Add them in "Variables" tab
- Invalid API keys: Verify keys at provider's website
- Port conflicts: Check `railway.toml` for correct port settings

### ❌ Can't Access Open WebUI

**Symptom:** Generated domain shows error or won't load

**Fix:** 
1. Verify OpenWebUI service is "Deployed" (green)
2. Check that `OPENAI_API_BASE_URL` points to `http://litellm.railway.internal:4000/v1`
3. Verify `OPENAI_API_KEY` matches your `LITELLM_MASTER_KEY`
4. Check LiteLLM service logs for connection errors

### ❌ LLM Requests Failing

**Symptom:** Chat interface loads but can't generate responses

**Fix:**
1. Verify you've added at least one LLM provider API key to LiteLLM service
2. Check LiteLLM logs for API authentication errors
3. Ensure your API keys are valid and have credits/quota
4. Review [`services/litellm/config.yaml`](services/litellm/config.yaml) for model configuration

📖 **For more help:** Full troubleshooting guide coming soon. For now, check Railway logs and the [Railway Discord community](https://discord.gg/railway).

---

**Questions?** Open an issue on [GitHub](https://github.com/nanocreek/llm-stack) or check Railway's [documentation](https://docs.railway.app).
