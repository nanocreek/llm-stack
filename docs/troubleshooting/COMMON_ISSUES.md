# Common Issues and Troubleshooting

This guide consolidates common issues encountered when deploying and running the LiteLLM Stack on Railway, with step-by-step solutions for each problem.

## Table of Contents

1. [Railway Deployment Issues](#railway-deployment-issues)
2. [Service-Specific Issues](#service-specific-issues)
3. [Performance Issues](#performance-issues)

---

## Railway Deployment Issues

### Issue: Deployment Fails to Start

**Symptoms:**
- Deployment build succeeds but container fails to start
- Service shows "Crashed" or "Failed" status after 3-5 minutes
- No logs appear in Railway dashboard

**Causes:**
- Missing required environment variables
- Health check timeout exceeded
- Invalid railway.toml configuration

**Solution:**

1. **Check Environment Variables:**
   ```bash
   # Verify all required variables are set
   # Railway Dashboard → Service → Variables
   
   # For LiteLLM:
   - LITELLM_MASTER_KEY must be set
   - DATABASE_URL (auto-configured by Railway plugin)
   - REDIS_URL (auto-configured by Railway plugin)
   ```

2. **Check Health Check Configuration:**
   - Verify LiteLLM exposes health check endpoint at `/health`
   - Ensure health check timeout is reasonable (start period: 60-120s)

3. **Review Logs:**
   ```bash
   # Railway Dashboard → Service → Logs
   # Look for:
   - "panic" or "fatal" errors
   - Missing environment variable warnings
   ```

4. **Verify Dependencies:**
   - PostgreSQL plugin is added and running
   - Redis plugin is added and running

**Prevention:**
- Use `.env.example` files as templates
- Test all required variables before deployment
- Monitor first deployment closely

**Related Links:**
- [Environment Variables Guide](../../ENV_VARIABLES_GUIDE.md:1)
- [Quick Start Railway](../../QUICK_START_RAILWAY.md:1)

---

### Issue: Build Errors During Deployment

**Symptoms:**
- Deployment fails during Docker build phase
- Error messages about missing dependencies or files

**Causes:**
- Incorrect Dockerfile syntax
- Missing dependencies
- Context directory issues

**Solution:**

1. **Review Build Logs:**
   ```bash
   # Railway Dashboard → Service → Deployments → View Logs
   # Identify exact error message
   ```

2. **Test Dockerfile Locally:**
   ```bash
   # Build locally to reproduce issue
   cd services/litellm
   docker build -t test-build .
   ```

3. **Verify railway.toml:**
   ```toml
   [build]
   builder = "DOCKERFILE"
   dockerfilePath = "Dockerfile"
   ```

**Prevention:**
- Test Dockerfiles locally before pushing
- Use pinned versions for base images

---

### Issue: Service Restarts Continually

**Symptoms:**
- Service shows "Restarting" status repeatedly
- Restart count increases continuously
- Service never reaches "Healthy" state

**Causes:**
- Memory limits exceeded (OOM killer)
- Health check failures
- Application crashes on startup

**Solution:**

1. **Check Resource Usage:**
   ```bash
   # Railway Dashboard → Service → Metrics
   # Look for:
   - Memory usage hitting 100%
   - CPU usage constantly at maximum
   ```

2. **Increase Resource Allocation:**
   ```bash
   # Railway Dashboard → Service → Settings → Resources
   # Increase:
   - Memory (start with 512MB, scale to 1GB if needed)
   - CPU (0.25 → 0.5 CPU core)
   ```

3. **Check Application Logs:**
   ```bash
   # Look for crash logs, stack traces, or OOM errors
   ```

**Prevention:**
- Set appropriate resource limits from the start
- Monitor resource usage trends over time

---

## Service-Specific Issues

### LiteLLM: API Key Problems

**Symptoms:**
- 401 Unauthorized errors when calling LiteLLM
- "Invalid API key" messages in logs

**Causes:**
- LITELLM_MASTER_KEY not set correctly
- Key has trailing spaces or special characters

**Solution:**

1. **Verify Key is Set:**
   ```bash
   # LiteLLM service must have:
   LITELLM_MASTER_KEY=sk-your-key-here
   ```

2. **Generate New Key:**
   ```bash
   # Generate strong key
   openssl rand -base64 32
   
   # Copy output and set in LiteLLM service
   ```

3. **Check for Whitespace:**
   ```bash
   # Ensure no leading/trailing spaces
   # Paste into text editor first to verify
   ```

4. **Test Connection:**
   ```bash
   curl http://litellm.railway.internal:4000/v1/models \
     -H "Authorization: Bearer YOUR_KEY_HERE"
   
   # Should return list of models
   ```

**Prevention:**
- Store keys securely
- Test authentication immediately after deployment

**Related Links:**
- [LiteLLM README](../../services/litellm/README.md:1)

---

### LiteLLM: Model Access Issues

**Symptoms:**
- "Model not found" errors
- Requests to specific models fail
- Available models list is empty

**Causes:**
- LLM provider API keys not configured
- config.yaml doesn't include requested model
- Provider API rate limits or quota exceeded

**Solution:**

1. **Configure Provider API Keys:**
   ```bash
   # Railway Dashboard → LiteLLM → Variables
   # Add keys for providers you want to use:
   OPENAI_API_KEY=sk-...
   ANTHROPIC_API_KEY=sk-ant-...
   ```

2. **Update config.yaml:**
   ```yaml
   # services/litellm/config.yaml
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

3. **Verify Model Names:**
   ```bash
   # List available models
   curl http://litellm.railway.internal:4000/v1/models \
     -H "Authorization: Bearer $LITELLM_MASTER_KEY"
   ```

4. **Check Provider Status:**
   - Verify API key is valid and active
   - Check provider dashboard for quota/billing issues

**Prevention:**
- Document all configured models
- Set up billing alerts with providers
- Test model access after configuration changes

---

### PostgreSQL: Connection Issues

**Symptoms:**
- "Connection refused" errors
- "Could not connect to database" messages
- LiteLLM can't access PostgreSQL for caching

**Causes:**
- PostgreSQL plugin not added
- Incorrect connection variable references
- Database not fully initialized

**Solution:**

1. **Verify PostgreSQL Plugin:**
   ```bash
   # Railway Dashboard → Project
   # Ensure PostgreSQL plugin is added and running
   # Status should show green "Running" indicator
   ```

2. **Check Variable References:**
   ```bash
   # Services should use Railway variable interpolation:
   DATABASE_URL=${{Postgres.DATABASE_URL}}
   ```

3. **Wait for Initialization:**
   ```bash
   # PostgreSQL may take 30-60 seconds to initialize
   # Check PostgreSQL plugin logs for "ready to accept connections"
   ```

**Prevention:**
- Add PostgreSQL plugin before LiteLLM
- Use Railway variable interpolation consistently

**Related Links:**
- [PostgreSQL README](../../services/postgres-pgvector/README.md:1)

---

### Redis: Connection Failures

**Symptoms:**
- Cache not working
- "Could not connect to Redis" messages

**Causes:**
- Redis plugin not added
- REDIS_URL not configured
- Connection timeout

**Solution:**

1. **Verify Redis Plugin:**
   ```bash
   # Railway Dashboard → Project
   # Ensure Redis plugin is added and running
   ```

2. **Set REDIS_URL:**
   ```bash
   # Services should reference:
   REDIS_URL=${{Redis.REDIS_URL}}
   
   # Railway automatically provides full connection string
   ```

3. **Test Connection:**
   ```bash
   # From service container:
   redis-cli -u $REDIS_URL ping
   # Should return "PONG"
   ```

**Prevention:**
- Add Redis plugin before LiteLLM
- Monitor Redis memory usage
- Use Redis for ephemeral data only

---

## Performance Issues

### Issue: Slow Response Times

**Symptoms:**
- LLM responses take longer than expected
- High latency metrics

**Causes:**
- Insufficient CPU or memory allocation
- No caching enabled
- Provider API rate limits

**Solution:**

1. **Scale Service Resources:**
   ```bash
   # Railway Dashboard → Service → Settings → Resources
   # For LiteLLM:
   - Increase memory (512MB → 1GB)
   - Increase CPU (0.25 → 0.5 core)
   ```

2. **Enable Redis Caching:**
   ```bash
   # For LiteLLM:
   REDIS_URL=${{Redis.REDIS_URL}}
   ```

3. **Enable PostgreSQL Caching:**
   ```bash
   # For LiteLLM:
   DATABASE_URL=${{Postgres.DATABASE_URL}}
   ```

4. **Monitor Metrics:**
   ```bash
   # Track these metrics:
   - API response time (p50, p95, p99)
   - Memory and CPU usage
   ```

**Prevention:**
- Right-size resources from the start
- Enable caching layers (Redis)
- Monitor performance metrics continuously

---

### Issue: Memory Exhaustion

**Symptoms:**
- Service crashes with OOM (Out of Memory) errors
- Memory usage shows constant 100%
- Service restarts repeatedly

**Causes:**
- Insufficient memory allocation
- Memory leaks in application
- Too many concurrent operations

**Solution:**

1. **Immediate Fix - Scale Up:**
   ```bash
   # Railway Dashboard → Service → Settings → Resources
   # Double current memory allocation
   # Example: 512MB → 1GB
   ```

2. **Optimize Concurrent Requests:**
   ```bash
   # If handling many concurrent requests:
   - Reduce connection pool size
   - Implement request queuing
   ```

3. **Monitor Long-Term:**
   ```bash
   # Set up alerts:
   - Memory > 80% for 5 minutes → Warning
   - Memory > 90% for 1 minute → Critical
   ```

**Prevention:**
- Allocate sufficient memory from the start
- Monitor memory trends over time

---

### Issue: LiteLLM config.yaml Problems

**Symptoms:**
- Models not appearing in available list
- Configuration errors in logs
- Can't route to specific providers

**Causes:**
- Malformed YAML syntax
- Missing required fields
- Incorrect model names

**Solution:**

1. **Validate YAML Syntax:**
   ```bash
   # Use online YAML validator or:
   python -c "import yaml; yaml.safe_load(open('config.yaml'))"
   ```

2. **Check Required Fields:**
   ```yaml
   model_list:
     - model_name: gpt-4              # Required: Display name
       litellm_params:                # Required: Config block
         model: openai/gpt-4          # Required: Provider/model
         api_key: os.environ/OPENAI_API_KEY  # Required: Key reference
   ```

3. **Test Configuration:**
   ```bash
   # After updating config.yaml:
   # 1. Redeploy LiteLLM service
   # 2. Check logs for configuration errors
   # 3. List models:
   curl -H "Authorization: Bearer $KEY" \
     http://litellm.railway.internal:4000/v1/models
   ```

**Prevention:**
- Use provided config.yaml as template
- Validate YAML syntax before deployment
- Document model configurations

**Related Links:**
- [LiteLLM README - Configuration](../../services/litellm/README.md:97)

---

## Getting Additional Help

If issues persist after trying solutions in this guide:

1. **Review Architecture Documentation:**
   - [Architecture Overview](../architecture/OVERVIEW.md:1)
   - [Service Communication](../architecture/SERVICE_COMMUNICATION.md:1)

2. **Check Railway Resources:**
   - [Railway Status](https://status.railway.app)
   - [Railway Documentation](https://docs.railway.app)
   - [Railway Discord](https://discord.gg/railway)

3. **Project-Specific Resources:**
   - [Main README](../../README.md:1)
   - [Quick Start Guide](../../QUICK_START_RAILWAY.md:1)
   - [Environment Variables Guide](../../ENV_VARIABLES_GUIDE.md:1)

4. **Community Support:**
   - Open an issue on GitHub with:
     - Detailed error messages
     - Service logs (last 100 lines)
     - Environment variable configuration (redact sensitive values)
     - Steps to reproduce

---

**Last Updated**: 2026-03-26  
**Version**: 2.0 (Simplified - LiteLLM + PostgreSQL + Redis)
