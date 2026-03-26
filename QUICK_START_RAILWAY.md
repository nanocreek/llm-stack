# 🚀 Quick Start: Deploy LiteLLM to Railway in 5 Minutes

Deploy a production-ready LiteLLM proxy with PostgreSQL and Redis. This guide gets you from zero to a running LLM gateway with unified API access to 100+ providers.

**What you'll have:** A production-grade LiteLLM proxy with persistent caching and rate limiting.

## Prerequisites

- **Railway account** - [Sign up free](https://railway.app)
- **GitHub account** - For optional customization
- That's it! Railway handles everything else.

## Step 1: Deploy to Railway

Click the button below to start your deployment:

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy?referralCode=YOUR_REFERRAL_CODE)

**What happens when you click:**
1. Railway creates a new project in your account
2. Deploys 3 services automatically:
   - **LiteLLM** - Unified API proxy for 100+ LLM providers (OpenAI, Anthropic, Azure, etc.)
   - **PostgreSQL** - Managed database for caching, logging, and persistence
   - **Redis** - Managed cache for rate limiting and session management
3. Prompts you to configure required variables
4. Sets up internal networking between services

Railway will prompt you for configuration—continue to Step 2.

## Step 2: Configure Required Variables

Railway will ask you to set these critical variables. Here's what each one does and how to set it:

### ✅ LITELLM_MASTER_KEY

**What it is:** Authentication key for LiteLLM proxy service. All API requests to LiteLLM must include this key.

**How to generate:** Run this command in your terminal:
```bash
openssl rand -base64 32
```

**Example value:** `sk-a7K3jP9mNx8vQ2wR5tY1bZ4cD6eF8gH0`

**Where to use it:** 
- Set as `LITELLM_MASTER_KEY` in LiteLLM service
- Use this same key when making API calls to LiteLLM

### ✅ POSTGRES_PASSWORD (Auto-configured)

**What it is:** Password for your PostgreSQL database.

**Important note:** If using Railway's PostgreSQL plugin (recommended), Railway provides this automatically via `DATABASE_URL`. You don't need to set it manually.

### ✅ REDIS_URL (Auto-configured)

**What it is:** Connection URL for your Redis instance.

**Important note:** If using Railway's Redis plugin (recommended), Railway provides this automatically via `REDIS_URL`. You don't need to set it manually.

### Optional: LLM Provider API Keys

Add API keys for the LLM providers you want to use:

- `OPENAI_API_KEY` - For GPT-4, GPT-3.5, etc. (get from [OpenAI platform](https://platform.openai.com/api-keys))
- `ANTHROPIC_API_KEY` - For Claude models (get from [Anthropic console](https://console.anthropic.com/))
- `AZURE_API_KEY` / `AZURE_API_BASE` - For Azure OpenAI
- `GOOGLE_APPLICATION_CREDENTIALS` - For Google Vertex AI

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

⏱️ **Typical deployment time:** 3-5 minutes for all services

**How to monitor:**
1. Railway dashboard shows real-time deployment status
2. Each service card displays:
   - 🟡 Building... (compiling Docker images)
   - 🟢 Deployed (service is running)
   - 🔴 Failed (check logs for errors)

**Success looks like:** All 3 service cards show 🟢 "Deployed" status

**If something fails:** Click the service → "Logs" tab to see error details. Common issues are missing environment variables or invalid API keys.

## Step 5: Access Your LiteLLM Proxy

Once deployment completes, find your application URL:

**To access LiteLLM API:**
1. Click on the **litellm** service in Railway dashboard
2. Go to "Settings" tab
3. Find the "Public Networking" section
4. Generate a public domain (will look like: `litellm-production-xxxx.up.railway.app`)
5. Your LiteLLM proxy is now accessible at this URL!

**Test your deployment:**
```bash
# Health check
curl https://litellm-production-xxxx.up.railway.app/health

# List models (replace with your actual key)
curl https://litellm-production-xxxx.up.railway.app/v1/models \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY"
```

🎉 **You're live!** Start routing LLM requests through your unified proxy.

## Optional: Detach and Customize

Want to modify the code or configuration? Detach your Railway project to get full control.

**What detaching does:**
- Railway creates a new GitHub repository in your account
- Copies all service code and configuration files
- Links your Railway project to this new repo
- Any changes you push to the repo automatically redeploy

**Benefits:**
- ✅ Full control over code and configuration
- ✅ Ability to customize LiteLLM configuration
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
- 🔧 **Troubleshooting**: Common issues and solutions below
- 💻 **Local Development**: Want to run locally? See [`docs/local-dev/`](docs/local-dev/) for Kubernetes/Minikube setup

**Configure your models:**
- Edit [`services/litellm/config.yaml`](services/litellm/config.yaml) to add or remove LLM providers
- Restart the LiteLLM service in Railway after changes

**Integrate with your applications:**
```python
from openai import OpenAI

client = OpenAI(
    base_url="https://litellm-production-xxxx.up.railway.app",
    api_key="your-litellm-master-key"
)

response = client.chat.completions.create(
    model="gpt-4",
    messages=[{"role": "user", "content": "Hello!"}]
)
```

## Troubleshooting Quick Tips

### ❌ Deployment Failed

**Symptom:** Service shows red "Failed" status

**Fix:** Click service → "Logs" tab. Look for:
- Missing environment variables: Add them in "Variables" tab
- Invalid API keys: Verify keys at provider's website
- Port conflicts: Check `railway.toml` for correct port settings

### ❌ Can't Access LiteLLM API

**Symptom:** Generated domain shows error or won't load

**Fix:** 
1. Verify LiteLLM service is "Deployed" (green)
2. Check that public networking is enabled and domain is generated
3. Verify `LITELLM_MASTER_KEY` is set correctly
4. Check LiteLLM service logs for startup errors

### ❌ LLM Requests Failing

**Symptom:** API responds but can't generate completions

**Fix:**
1. Verify you've added at least one LLM provider API key to LiteLLM service
2. Check LiteLLM logs for API authentication errors
3. Ensure your API keys are valid and have credits/quota
4. Review [`services/litellm/config.yaml`](services/litellm/config.yaml) for model configuration

### ❌ Database/Redis Connection Errors

**Symptom:** LiteLLM starts but shows database/Redis connection warnings

**Fix:**
1. Verify PostgreSQL and Redis plugins are running (green)
2. Check that `DATABASE_URL` and `REDIS_URL` are correctly set
3. Ensure plugin names are exactly "Postgres" and "Redis"
4. Redeploy LiteLLM service after fixing variables

📖 **For more help:** Full troubleshooting guide coming soon. For now, check Railway logs and the [Railway Discord community](https://discord.gg/railway).

---

**Questions?** Open an issue on [GitHub](https://github.com/nanocreek/llm-stack) or check Railway's [documentation](https://docs.railway.app).
