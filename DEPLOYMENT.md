# Deployment Guide

This guide provides step-by-step instructions for deploying the LLM Stack template to Railway.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Initial Setup](#initial-setup)
- [Adding Managed Plugins](#adding-managed-plugins)
- [Configuring Environment Variables](#configuring-environment-variables)
- [Service-to-Service Communication](#service-to-service-communication)
- [Health Checks and Monitoring](#health-checks-and-monitoring)
- [Common Deployment Issues](#common-deployment-issues)
- [Post-Deployment Verification](#post-deployment-verification)

## Prerequisites

Before deploying, ensure you have:

1. **Railway Account**
   - Sign up at [railway.app](https://railway.app)
   - Verify your email address
   - Add a payment method (Railway offers a free tier)

2. **GitHub Repository**
   - Fork or clone this repository
   - Push your changes to GitHub
   - Ensure the repository is public or accessible to Railway

3. **LLM Provider API Keys**
   - At least one provider API key (OpenAI, Anthropic, etc.)
   - Keep your keys secure and never commit them to git

4. **Git Installed**
   - Ensure git is installed on your local machine
   - Test with: `git --version`

## Initial Setup

### ⚠️ Critical: This is a Monorepo

This repository contains **5 separate services** in subdirectories. Railway **CANNOT** automatically detect and deploy all services when you simply import this repo. 

**DO NOT** just click "Deploy from GitHub repo" at the root level - it will fail because the root directory contains only documentation files.

You **MUST** add each service individually and specify its root directory.

### Step 1: Fork the Repository

1. Go to https://github.com/nanocreek/llm-stack (or your fork)
2. Click **"Fork"** to create your own copy
3. Clone your fork locally (optional):
   ```bash
   git clone https://github.com/YOUR-USERNAME/llm-stack.git
   cd llm-stack
   ```

### Step 2: Create an Empty Railway Project

1. Log in to [railway.app](https://railway.app)
2. Click **"New Project"** in the dashboard
3. Select **"Empty Project"** (NOT "Deploy from GitHub repo")
4. Give your project a name like "LLM Stack"
5. You now have an empty project - good!

### Step 3: Add Database Plugins FIRST

Before adding any services, add the databases. This ensures connection variables are available when services start.

**Add PostgreSQL:**
1. In your empty project, click the **"+ New"** button
2. Select **"Database"**
3. Choose **"Add PostgreSQL"**
4. Wait for it to provision (you'll see a "Running" status)

**Add Redis:**
1. Click the **"+ New"** button again
2. Select **"Database"**
3. Choose **"Add Redis"**
4. Wait for it to provision (you'll see a "Running" status)

✅ You should now have 2 plugins showing "Running" status.

### Step 4: Add Each Service Individually

You need to add all 5 services. For **EACH** service listed below, follow the detailed steps.

**Services to Add (in this recommended order):**

| # | Service Name | Root Directory | Description |
|---|-------------|----------------|-------------|
| 1 | qdrant | `services/qdrant` | Vector database (no dependencies) |
| 2 | litellm | `services/litellm` | LLM proxy (no dependencies) |
| 3 | r2r | `services/r2r` | RAG framework (depends on qdrant, postgres, redis) |
| 4 | openwebui | `services/openwebui` | Web UI (depends on litellm) |
| 5 | react-client | `services/react-client` | Frontend (depends on openwebui) |

**Detailed Steps for EACH Service:**

1. **Click "
+ New"** in your Railway project
2. **Select "GitHub Repo"**
3. **Authorize Railway** to access your GitHub account (first time only)
4. **Select your forked repository** (`llm-stack`)
5. **⚠️ CRITICAL STEP**: Before deploying, you must set the root directory:
   - Railway may ask you to configure the service
   - Look for **"Root Directory"**, **"Source Directory"**, or click **"Settings"**
   - Enter the **exact path** from the table above (e.g., `services/qdrant`)
   - **Do NOT include a leading or trailing slash**
6. **Verify detection**: Railway should now detect:
   - A `Dockerfile` in that directory
   - A `railway.toml` in that directory
   - You'll see these mentioned in the build configuration
7. **Click "Deploy"** or **"Add Service"**
8. **Name the service**: Railway will auto-name it, or you can rename it to match the service name (e.g., "qdrant")

**Repeat these 8 steps for all 5 services.**

### Step 5: Verify All Services Are Added

After adding all services, your Railway project should show:

- ✅ **Postgres** (plugin) - Running
- ✅ **Redis** (plugin) - Running
- ✅ **qdrant** (service) - Building or Deployed
- ✅ **litellm** (service) - Building or Deployed
- ✅ **r2r** (service) - Building or Deployed
- ✅ **openwebui** (service) - Building or Deployed
- ✅ **react-client** (service) - Building or Deployed

**Total: 7 items** (2 plugins + 5 services)

### Step 6: Monitor Initial Builds

Railway will begin building all services. This may take 5-10 minutes:

1. Click on each service to view its build logs
2. Watch for successful Docker builds
3. Some services may crash initially due to missing environment variables - this is expected
4. We'll fix this in the next section

## Adding Managed Plugins

Railway provides managed plugins for PostgreSQL and Redis. These are not containerized services but fully managed by Railway.

### Adding PostgreSQL Plugin

1. In your Railway project, click **"New Service"**
2. Select **"Database"** from the service types
3. Choose **"PostgreSQL"**
4. Click **"Add PostgreSQL"**

Railway will:
- Create a PostgreSQL database
- Generate connection variables
- Make them available via `${{Postgres.*}}` syntax

### Adding Redis Plugin

1. Click **"New Service"** again
2. Select **"Database"** from the service types
3. Choose **"Redis"**
4. Click **"Add Redis"**

Railway will:
- Create a Redis instance
- Generate connection variables
- Make them available via `${{Redis.REDIS_URL}}` syntax

### Verifying Plugin Status

After adding plugins, verify they are running:

1. Navigate to your project dashboard
2. Check that both PostgreSQL and Redis show **"Running"** status
3. Click on each plugin to view connection details

## Configuring Environment Variables

Environment variables are configured at the project level and service level in Railway.

### Project-Level Variables

These variables are shared across services and configured in the [`railway.json`](railway.json) template:

1. Navigate to your project dashboard
2. Click the **"Variables"** tab
3. You'll see the following required and optional variables:

#### Required Variables

| Variable | Description | Example Value |
|----------|-------------|---------------|
| `LITELLM_MASTER_KEY` | Master key for LiteLLM authentication | `sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx` |

**Setting LITELLM_MASTER_KEY:**
- Generate a strong random key (32+ characters)
- Use a secure random generator or: `openssl rand -base64 32`
- Enter the value in the Railway dashboard

#### Optional Variables

| Variable | Description | Example Value |
|----------|-------------|---------------|
| `OPENAI_API_KEY` | OpenAI API key for GPT models | `sk-proj-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx` |
| `ANTHROPIC_API_KEY` | Anthropic API key for Claude models | `sk-ant-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx` |

**Setting Provider API Keys:**
- Obtain keys from your LLM provider's dashboard
- Enter each key in the corresponding variable field
- Only add keys for providers you intend to use

### Service-Level Variables

Each service has its own environment variables defined in its `railway.toml` file. These are automatically configured by the template:

#### React Client
- `PORT`: 3000
- `VITE_API_BASE_URL`: `http://openwebui.railway.internal:8080`

#### R2R
- `R2R_PORT`: 7272
- `R2R_HOST`: 0.0.0.0
- `R2R_POSTGRES_HOST`: `${{Postgres.PGHOST}}`
- `R2R_POSTGRES_PORT`: `${{Postgres.PGPORT}}`
- `R2R_POSTGRES_USER`: `${{Postgres.PGUSER}}`
- `R2R_POSTGRES_PASSWORD`: `${{Postgres.PGPASSWORD}}`
- `R2R_POSTGRES_DBNAME`: `${{Postgres.PGDATABASE}}`
- `R2R_VECTOR_DB_PROVIDER`: qdrant
- `R2R_QDRANT_HOST`: `qdrant.railway.internal`
- `R2R_QDRANT_PORT`: 6333
- `REDIS_URL`: `${{Redis.REDIS_URL}}`

#### Qdrant
- `QDRANT__SERVICE__HTTP_PORT`: 6333
- `QDRANT__SERVICE__GRPC_PORT`: 6334

#### LiteLLM
- `LITELLM_PORT`: 4000
- `LITELLM_MASTER_KEY`: `${{PROJECT.LITELLM_MASTER_KEY}}`
- `OPENAI_API_KEY`: `${{PROJECT.OPENAI_API_KEY}}`
- `ANTHROPIC_API_KEY`: `${{PROJECT.ANTHROPIC_API_KEY}}`

#### OpenWebUI
- `PORT`: 8080
- `OPENAI_API_BASE_URL`: `http://litellm.railway.internal:4000/v1`
- `OPENAI_API_KEY`: `${{litellm.LITELLM_MASTER_KEY}}`
- `WEBUI_AUTH`: false

### Variable Reference Syntax

Railway uses the `${{ServiceName.VARIABLE}}` syntax for service-to-service variable references:

- `${{Postgres.PGHOST}}` - PostgreSQL host from the Postgres plugin
- `${{Redis.REDIS_URL}}` - Redis connection URL from the Redis plugin
- `${{PROJECT.LITELLM_MASTER_KEY}}` - Project-level variable
- `${{litellm.LITELLM_MASTER_KEY}}` - Variable from the litellm service

## Service-to-Service Communication

Services communicate using Railway's internal DNS and the `${{}}` variable reference syntax.

### Internal DNS Addresses

Each service is accessible via an internal DNS address:

| Service | Internal DNS Address |
|---------|---------------------|
| React Client | `react-client.railway.internal` |
| R2R | `r2r.railway.internal` |
| Qdrant | `qdrant.railway.internal` |
| LiteLLM | `litellm.railway.internal` |
| OpenWebUI | `openwebui.railway.internal` |

### Communication Patterns

#### Frontend to Backend
```bash
# React Client calls OpenWebUI
VITE_API_BASE_URL=http://openwebui.railway.internal:8080
```

#### LLM Routing
```bash
# OpenWebUI calls LiteLLM
OPENAI_API_BASE_URL=http://litellm.railway.internal:4000/v1
OPENAI_API_KEY=${{litellm.LITELLM_MASTER_KEY}}
```

#### RAG Pipeline
```bash
# R2R connects to Qdrant
R2R_QDRANT_HOST=qdrant.railway.internal
R2R_QDRANT_PORT=6333

# R2R connects to PostgreSQL
R2R_POSTGRES_HOST=${{Postgres.PGHOST}}
R2R_POSTGRES_PORT=${{Postgres.PGPORT}}

# R2R connects to Redis
REDIS_URL=${{Redis.REDIS_URL}}
```

### Service Dependencies

Services are configured with dependencies in [`railway.json`](railway.json):

```json
"dependsOn": [
  "service-name"
]
```

This ensures services start in the correct order:
1. PostgreSQL, Redis, Qdrant (no dependencies)
2. LiteLLM (no internal dependencies)
3. R2R (depends on PostgreSQL, Redis, Qdrant)
4. OpenWebUI (depends on LiteLLM)
5. React Client (no dependencies)

## Health Checks and Monitoring

### Health Check Endpoints

Each service has a health check endpoint configured in [`railway.json`](railway.json):

| Service | Health Check Path | Port |
|---------|-------------------|------|
| React Client | `/` | 3000 |
| R2R | `/health` | 7272 |
| Qdrant | `/readyz` | 6333 |
| LiteLLM | `/health` | 4000 |
| OpenWebUI | `/` | 8080 |

### Monitoring Service Health

1. **Dashboard View**
   - Navigate to your project dashboard
   - Each service shows a status indicator:
     - 🟢 Healthy - Service is running and responding
     - 🟡 Building - Service is being built
     - 🔴 Crashed - Service has failed

2. **Service Logs**
   - Click on any service to view its logs
   - Look for error messages or warnings
   - Use the search/filter functionality

3. **Metrics**
   - Railway provides CPU, memory, and network metrics
   - Access these from the service's "Metrics" tab

### Configuring Health Checks

Health checks are configured in [`railway.json`](railway.json):

```json
"healthcheck": {
  "path": "/health",
  "port": 7272
}
```

Railway automatically polls these endpoints to determine service health.

## Common Deployment Issues

### Issue: Services Fail to Start

**Symptoms:**
- Service shows "Crashed" status
- Logs show startup errors

**Solutions:**
1. Check service logs for specific error messages
2. Verify all required environment variables are set
3. Ensure dependent services are running
4. Check for port conflicts (each service uses a unique port)

### Issue: Database Connection Errors

**Symptoms:**
- R2R cannot connect to PostgreSQL
- Redis connection timeouts

**Solutions:**
1. Verify PostgreSQL and Redis plugins are added and running
2. Check that `${{Postgres.*}}` and `${{Redis.REDIS_URL}}` variables are set
3. Review service logs for connection error details
4. Ensure plugins are in the same project as your services

### Issue: LLM API Authentication Failures

**Symptoms:**
- OpenWebUI shows authentication errors
- LiteLLM logs show invalid API key errors

**Solutions:**
1. Verify `LITELLM_MASTER_KEY` is set correctly
2. Check that provider API keys are valid and active
3. Ensure `OPENAI_API_KEY` is passed through to LiteLLM
4. Test API keys directly with the provider's API

### Issue: Service Communication Failures

**Symptoms:**
- Services cannot reach each other
- Connection refused errors

**Solutions:**
1. Verify internal DNS addresses are correct (`*.railway.internal`)
2. Check that ports match service configurations
3. Ensure services are in the same Railway project
4. Review service dependencies in [`railway.json`](railway.json)

### Issue: Build Failures

**Symptoms:**
- Services fail during build phase
- Docker build errors

**Solutions:**
1. Check the "Builds" tab for detailed error messages
2. Verify Dockerfiles are present in each service directory
3. Ensure all dependencies are properly specified
4. Check for syntax errors in configuration files

### Issue: Health Check Failures

**Symptoms:**
- Services show "Unhealthy" status
- Health check endpoints return errors

**Solutions:**
1. Verify health check paths are correct
2. Check that services are listening on the expected ports
3. Review service logs for startup errors
4. Test health check endpoints manually using Railway's built-in tools

## Post-Deployment Verification

After deployment, verify your stack is working correctly:

### Step 1: Check Service Status

1. Navigate to your project dashboard
2. Verify all services show "Healthy" status
3. Check that PostgreSQL and Redis plugins are "Running"

### Step 2: Test Service Communication

1. **Test React Client**
   - Click on the react-client service
   - Use the generated Railway URL to access the app
   - Verify the page loads without errors

2. **Test OpenWebUI**
   - Access OpenWebUI via its Railway URL
   - Verify the chat interface loads
   - Try sending a test message

3. **Test LiteLLM**
   - Check LiteLLM logs for successful startup
   - Verify it's listening on port 4000
   - Check for any API key errors

4. **Test R2R**
   - Check R2R logs for successful database connections
   - Verify Qdrant connection is established
   - Check for any initialization errors

### Step 3: Verify Database Connections

1. **PostgreSQL**
   - Click on the PostgreSQL plugin
   - View connection details
   - Verify R2R logs show successful connection

2. **Redis**
   - Click on the Redis plugin
   - View connection details
   - Verify R2R logs show successful connection

### Step 4: Monitor Logs

1. Review logs for each service
2. Look for any error messages or warnings
3. Verify all services are communicating correctly

### Step 5: Test End-to-End Flow

1. Access the React Client
2. Navigate to OpenWebUI
3. Send a test message
4. Verify the response is generated correctly
5. Check logs for the complete request flow

## Scaling and Optimization

### Scaling Services

Railway allows you to scale services based on demand:

1. Navigate to a service's settings
2. Adjust the "Instances" slider
3. Railway will automatically distribute load

### Resource Allocation

Each service can be configured with specific resource limits:

1. Click on a service
2. Go to the "Settings" tab
3. Adjust CPU and memory limits as needed

### Cost Optimization

To optimize costs:

1. Monitor resource usage in the "Metrics" tab
2. Scale down services during low-traffic periods
3. Use Railway's sleep mode for development environments
4. Review and remove unused services

## Security Best Practices

1. **Never commit API keys** to your repository
2. **Use strong random values** for `LITELLM_MASTER_KEY`
3. **Rotate API keys** regularly
4. **Enable Railway's built-in security features**
5. **Monitor logs** for suspicious activity
6. **Use Railway's VPC** for enhanced network isolation

## Support and Resources

- **Railway Documentation**: [docs.railway.app](https://docs.railway.app)
- **Railway Community**: [community.railway.app](https://community.railway.app)
- **Railway Support**: [support.railway.app](https://support.railway.app)

For issues specific to this template, please open an issue in the GitHub repository.
