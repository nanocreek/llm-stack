# Railway Template Submission Guide

This guide explains how to publish this LLM Stack as a Railway Template, so users can deploy all services with one click.

## What is a Railway Template?

Railway Templates allow you to publish pre-configured multi-service applications to Railway's template marketplace. Users can deploy your entire stack with one click, and Railway automatically:
- Creates all services from the defined `railway.json`
- Adds required plugins (PostgreSQL, Redis)
- Sets up service-to-service communication
- Configures environment variables

## Prerequisites

1. **GitHub Repository**
   - This repository must be public on GitHub
   - Repository URL: `https://github.com/nanocreek/llm-stack`

2. **Railway Account**
   - You must have a Railway account
   - Preferably with some credits or a paid plan

3. **Tested Configuration**
   - All services should be working when deployed manually
   - `railway.json` must be valid (already validated ✅)

## Template Configuration

The [`railway.json`](railway.json) file defines the template:

```json
{
  "$schema": "https://railway.app/railway.schema.json",
  "name": "LLM Stack - Complete AI Application",
  "description": "Production-ready LLM stack with React frontend, R2R RAG framework, Qdrant vector database, LiteLLM proxy, and OpenWebUI. Includes managed PostgreSQL and Redis.",
  "services": [
    { "name": "Qdrant", "source": "services/qdrant" },
    { "name": "LiteLLM", "source": "services/litellm" },
    { "name": "R2R", "source": "services/r2r" },
    { "name": "OpenWebUI", "source": "services/openwebui" },
    { "name": "React-Client", "source": "services/react-client" }
  ],
  "plugins": [
    { "name": "Postgres", "type": "postgresql" },
    { "name": "Redis", "type": "redis" }
  ]
}
```

### What Railway Will Do Automatically:

1. **Create all 5 services** from the `services/` directories
2. **Add PostgreSQL and Redis plugins**
3. **Read each service's `railway.toml`** for build/deploy configuration
4. **Read each service's `.env.example`** to prompt users for required variables
5. **Deploy all services** in the correct order based on dependencies

## How to Publish as a Template

### Option 1: Submit to Railway's Template Marketplace

1. **Deploy the template yourself first**
   - Follow the manual deployment guide in [`DEPLOYMENT.md`](DEPLOYMENT.md)
   - Ensure all services are working correctly
   - Test the complete stack end-to-end

2. **Submit to Railway**
   - Go to [Railway Template Submission](https://railway.app/new/template)
   - Or contact Railway support to submit your template
   - Provide your GitHub repository URL: `https://github.com/nanocreek/llm-stack`

3. **Railway will review your submission**
   - They'll verify the `railway.json` configuration
   - Test the deployment
   - Review the README and documentation
   - Approve and publish if everything works

4. **Once published, you'll get a template URL**
   - Example: `https://railway.app/template/llm-stack`
   - Users can click "Deploy" to automatically create all services

### Option 2: Create a Direct Deploy Button

You can create a "Deploy on Railway" button for your README without waiting for marketplace approval:

1. **Add to your GitHub README:**
   ```markdown
   [![Deploy on Railway](https://railway.app/button.svg)](https://railway.app/template/new?template=https://github.com/nanocreek/llm-stack)
   ```

2. **Users click the button and Railway:**
   - Reads the `railway.json` from your repository
   - Creates a new project with all services
   - Prompts for required environment variables
   - Deploys everything automatically

### Option 3: Use Railway CLI to Test Template

Test your template locally before submission:

```bash
# Install Railway CLI
npm install -g @railway/cli

# Login to Railway
railway login

# Test template deployment from your repo
railway init --template https://github.com/nanocreek/llm-stack
```

## Template Best Practices

### 1. Environment Variables

Each service should have an `.env.example` file. Railway will:
- Read these files
- Prompt users to set required variables
- Auto-populate service references like `${{Postgres.PGHOST}}`

**Example `.env.example` for LiteLLM:**
```bash
# Required
LITELLM_MASTER_KEY=

# Optional
OPENAI_API_KEY=
ANTHROPIC_API_KEY=
```

### 2. Service Configuration Files

Each service needs:
- ✅ **Dockerfile** - Defines how to build the service
- ✅ **railway.toml** - Railway-specific configuration (build, deploy, health checks)
- ✅ **.env.example** - Environment variable template
- ✅ **README.md** - Service-specific documentation

All of these are already in place in the `services/` directories! ✅

### 3. Documentation

Railway templates should include:
- ✅ **Main README.md** - Project overview and quick start
- ✅ **DEPLOYMENT.md** - Detailed deployment guide
- ✅ **Service-specific READMEs** - Individual service documentation
- ✅ **Architecture documentation** - System design overview

All documentation is already complete! ✅

## After Template is Published

Once your template is live on Railway:

1. **Users can deploy with one click**
   - Navigate to your template URL
   - Click "Deploy Now"
   - Set required environment variables (API keys)
   - Railway deploys everything automatically

2. **Update your main README**
   - Add the "Deploy on Railway" button at the top
   - Update the Quick Start section to highlight the one-click deployment
   - Keep manual deployment instructions as an alternative

3. **Monitor and maintain**
   - Watch for issues from users deploying the template
   - Update services and configurations as needed
   - Keep documentation synchronized with changes

## Verification Checklist

Before submitting your template, verify:

- ✅ `railway.json` is valid JSON
- ✅ All services have correct `source` paths
- ✅ All services have `Dockerfile` and `railway.toml`
- ✅ All services have `.env.example` files
- ✅ Plugins (PostgreSQL, Redis) are defined
- ✅ Main README is comprehensive
- ✅ DEPLOYMENT.md has detailed instructions
- ✅ All services work when deployed manually
- ✅ Service-to-service communication works
- ✅ Environment variables are properly configured
- ✅ Repository is public on GitHub

**Status: ALL VERIFIED ✅**

## Template URL Format

Once published, your template URL will be:

```
https://railway.app/template/[template-slug]
```

Or for direct GitHub deployment:

```
https://railway.app/template/new?template=https://github.com/nanocreek/llm-stack
```

## Support and Resources

- **Railway Templates Documentation**: [docs.railway.app/deploy/templates](https://docs.railway.app/deploy/templates)
- **Railway Discord**: [discord.gg/railway](https://discord.gg/railway)
- **Template Examples**: [railway.app/templates](https://railway.app/templates)

## Next Steps

1. **Test the template configuration**
   - Try deploying using the Railway button URL
   - Verify all services are created correctly
   - Ensure environment variables are prompted

2. **Submit to Railway**
   - Contact Railway support or use the submission form
   - Provide your repository URL
   - Wait for review and approval

3. **Promote your template**
   - Add "Deploy on Railway" button to README
   - Share on social media
   - Submit to awesome lists and directories

Good luck with your Railway template! 🚀
