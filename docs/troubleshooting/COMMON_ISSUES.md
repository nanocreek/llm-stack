# Common Issues and Troubleshooting

This guide consolidates common issues encountered when deploying and running the LLM Stack on Railway, with step-by-step solutions for each problem.

## Table of Contents

1. [Railway Deployment Issues](#railway-deployment-issues)
2. [Service-Specific Issues](#service-specific-issues)
3. [Inter-Service Communication Issues](#inter-service-communication-issues)
4. [Performance Issues](#performance-issues)
5. [Data and Configuration Issues](#data-and-configuration-issues)

---

## Railway Deployment Issues

### Issue: Deployment Fails to Start

**Symptoms:**
- Deployment build succeeds but container fails to start
- Service shows "Crashed" or "Failed" status after 5-10 minutes
- No logs appear in Railway dashboard

**Causes:**
- Missing required environment variables
- Health check timeout exceeded
- Service depends on unavailable dependencies
- Invalid railway.toml configuration

**Solution:**

1. **Check Environment Variables:**
   ```bash
   # Verify all required variables are set
   # Railway Dashboard → Service → Variables
   
   # For LiteLLM:
   - LITELLM_MASTER_KEY must be set
   
   # For Open WebUI:
   - WEBUI_SECRET_KEY must be set
   - QDRANT_URI must be complete: http://qdrant.railway.internal:6333
   
   # For R2R:
   - All R2R_POSTGRES_* variables must reference ${{Postgres.*}}
   ```

2. **Check Health Check Configuration:**
   - Verify service exposes health check endpoint
   - Ensure health check timeout is reasonable (start period: 60-120s)
   - Check Dockerfile HEALTHCHECK statement

3. **Review Logs:**
   ```bash
   # Railway Dashboard → Service → Logs
   # Look for:
   - "panic" or "fatal" errors
   - "connection refused" messages
   - Missing environment variable warnings
   ```

4. **Verify Dependencies:**
   - PostgreSQL plugin is added and running
   - Redis plugin is added and running
   - Dependent services are deployed before this service

**Prevention:**
- Use `.env.example` files as templates
- Test all required variables before deployment
- Deploy dependencies first (PostgreSQL, Redis, Qdrant)
- Monitor first deployment closely

**Related Links:**
- [Environment Variables Guide](../../ENV_VARIABLES_GUIDE.md:1)
- [Quick Start Railway](../../QUICK_START_RAILWAY.md:1)

---

### Issue: Build Errors During Deployment

**Symptoms:**
- Deployment fails during Docker build phase
- Error messages about missing dependencies or files
- Build logs show compilation failures

**Causes:**
- Incorrect Dockerfile syntax
- Missing dependencies in requirements.txt or package.json
- Base image incompatibility
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
   cd services/{service-name}
   docker build -t test-build .
   
   # If successful locally, check Railway context
   ```

3. **Verify railway.toml:**
   ```toml
   [build]
   builder = "DOCKERFILE"
   dockerfilePath = "Dockerfile"
   
   [deploy]
   startCommand = # Verify correct start command
   ```

4. **Check File Paths:**
   - Ensure all COPY and ADD paths in Dockerfile are correct
   - Verify .dockerignore doesn't exclude required files
   - Check that root directory is set to service directory

**Prevention:**
- Test Dockerfiles locally before pushing
- Use pinned versions for base images
- Keep Dockerfiles simple and well-commented

**Related Links:**
- Service-specific READMEs in [`services/*/README.md`](../../services/README.md:1)

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
- Resource constraints (CPU throttling)

**Solution:**

1. **Check Resource Usage:**
   ```bash
   # Railway Dashboard → Service → Metrics
   # Look for:
   - Memory usage hitting 100%
   - CPU usage constantly at maximum
   - Disk space issues
   ```

2. **Increase Resource Allocation:**
   ```bash
   # Railway Dashboard → Service → Settings → Resources
   # Increase:
   - Memory (start with 1GB, scale to 2GB if needed)
   - CPU (0.5 → 1 CPU core)
   ```

3. **Review Health Check Logs:**
   ```bash
   # Look for health check endpoint errors
   # Increase start period if service needs more initialization time
   ```

4. **Check Application Logs:**
   ```bash
   # Look for crash logs, stack traces, or OOM errors
   # Fix application-level issues causing crashes
   ```

**Prevention:**
- Set appropriate resource limits from the start
- Test with realistic load before production
- Monitor resource usage trends over time
- Set up alerts for high memory/CPU usage

**Related Links:**
- [Architecture Overview - Resource Recommendations](../architecture/OVERVIEW.md:1)

---

### Issue: Environment Variable Configuration Problems

**Symptoms:**
- Service can't connect to PostgreSQL or Redis
- Authentication failures between services
- Wrong endpoints being used

**Causes:**
- Typos in variable names (case-sensitive)
- Incorrect Railway reference syntax
- Variables not updated after plugin addition
- Missing required variables

**Solution:**

1. **Verify Variable Syntax:**
   ```bash
   # CORRECT:
   DATABASE_URL=${{Postgres.DATABASE_URL}}
   REDIS_URL=${{Redis.REDIS_URL}}
   
   # INCORRECT:
   DATABASE_URL=${{postgres.database_url}}  # Wrong case
   REDIS_URL={{Redis.REDIS_URL}}            # Missing $
   ```

2. **Check Plugin Names:**
   ```bash
   # Railway Dashboard → Project → View All Services
   # Verify plugin names match exactly:
   - "Postgres" (capital P)
   - "Redis" (capital R)
   ```

3. **Use Raw Editor for Bulk Updates:**
   ```bash
   # Railway Dashboard → Service → Variables → RAW Editor
   # Copy entire .env template and paste
   # Verify all variables are present
   ```

4. **Test Variable Resolution:**
   ```bash
   # Add temporary debug logging to see resolved values
   # (Remove after verification)
   ```

**Prevention:**
- Use provided `.env.example` files as templates
- Copy-paste from ENV_VARIABLES_GUIDE.md
- Double-check variable names before deployment
- Use RAW Editor for consistency

**Related Links:**
- [Environment Variables Guide](../../ENV_VARIABLES_GUIDE.md:1)

---

## Service-Specific Issues

### LiteLLM: API Key Problems

**Symptoms:**
- 401 Unauthorized errors when calling LiteLLM
- Open WebUI can't connect to LiteLLM
- "Invalid API key" messages in logs

**Causes:**
- LITELLM_MASTER_KEY not set or mismatched
- Open WebUI OPENAI_API_KEY doesn't match LiteLLM key
- Key has trailing spaces or special characters

**Solution:**

1. **Verify Key Consistency:**
   ```bash
   # LiteLLM service must have:
   LITELLM_MASTER_KEY=sk-your-key-here
   
   # Open WebUI service must have SAME value:
   OPENAI_API_KEY=sk-your-key-here
   
   # Keys MUST match exactly
   ```

2. **Generate New Key:**
   ```bash
   # Generate strong key
   openssl rand -base64 32
   
   # Copy output and set in BOTH services
   ```

3. **Check for Whitespace:**
   ```bash
   # Ensure no leading/trailing spaces
   # Paste into text editor first to verify
   ```

4. **Test Connection:**
   ```bash
   curl -X POST http://litellm.railway.internal:4000/v1/models \
     -H "Authorization: Bearer YOUR_KEY_HERE"
   
   # Should return list of models
   ```

**Prevention:**
- Use environment variable references where possible
- Store keys in password manager
- Document which services share keys
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
- Invalid model name in request

**Solution:**

1. **Configure Provider API Keys:**
   ```bash
   # Railway Dashboard → LiteLLM → Variables
   # Add keys for providers you want to use:
   OPENAI_API_KEY=sk-...
   ANTHROPIC_API_KEY=sk-ant-...
   AZURE_API_KEY=...
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
   - Review provider service status pages

**Prevention:**
- Document all configured models
- Set up billing alerts with providers
- Test model access after configuration changes
- Use fallback models in config.yaml

**Related Links:**
- [LiteLLM README - Configuration](../../services/litellm/README.md:80)

---

### Open WebUI: QDRANT_URI Configuration Error

**Symptoms:**
- Open WebUI fails to start
- Error: "ValueError: QDRANT_URI is not set"
- RAG features don't work

**Causes:**
- QDRANT_URI environment variable missing
- URI format incorrect
- Qdrant service not accessible

**Solution:**

1. **Set QDRANT_URI:**
   ```bash
   # Railway Dashboard → Open WebUI → Variables
   # Add complete URI:
   QDRANT_URI=http://qdrant.railway.internal:6333
   
   # Format is critical:
   # - Protocol: http://
   # - Hostname: qdrant.railway.internal
   # - Port: 6333
   ```

2. **Keep Compatibility Variables:**
   ```bash
   # Also set these for backward compatibility:
   QDRANT_HOST=qdrant.railway.internal
   QDRANT_PORT=6333
   VECTOR_DB=qdrant
   ```

3. **Verify Qdrant is Running:**
   ```bash
   # Check Qdrant service status
   # Railway Dashboard → Qdrant → Should show "Healthy"
   
   # Test connectivity
   curl http://qdrant.railway.internal:6333/health
   ```

4. **Restart Open WebUI:**
   ```bash
   # After setting variables, redeploy Open WebUI
   # Railway Dashboard → Open WebUI → Deploy
   ```

**Prevention:**
- Deploy Qdrant before Open WebUI
- Use complete URI format from the start
- Verify all three Qdrant variables are set
- Test RAG features after deployment

**Related Links:**
- [Open WebUI README - QDRANT_URI](../../services/openwebui/README.md:225)

---

### PostgreSQL: Connection Issues

**Symptoms:**
- "Connection refused" errors
- "Could not connect to database" messages
- Services can't access PostgreSQL

**Causes:**
- PostgreSQL plugin not added
- Incorrect connection variable references
- Database not fully initialized
- Authentication credentials wrong

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
   R2R_POSTGRES_HOST=${{Postgres.PGHOST}}
   R2R_POSTGRES_PORT=${{Postgres.PGPORT}}
   R2R_POSTGRES_USER=${{Postgres.PGUSER}}
   R2R_POSTGRES_PASSWORD=${{Postgres.PGPASSWORD}}
   R2R_POSTGRES_DBNAME=${{Postgres.PGDATABASE}}
   
   # OR use full connection string:
   DATABASE_URL=${{Postgres.DATABASE_URL}}
   ```

3. **Wait for Initialization:**
   ```bash
   # PostgreSQL may take 30-60 seconds to initialize
   # Check PostgreSQL plugin logs for "ready to accept connections"
   ```

4. **Test Connection:**
   ```bash
   # From service container (if accessible):
   psql $DATABASE_URL
   
   # Should connect successfully
   ```

**Prevention:**
- Add PostgreSQL plugin before dependent services
- Use Railway variable interpolation consistently
- Document database schema and migrations
- Test connections before deploying dependent services

**Related Links:**
- [PostgreSQL README](../../services/postgres-pgvector/README.md:1)

---

### Redis: Connection Failures

**Symptoms:**
- Session management not working
- Cache misses or errors
- "Could not connect to Redis" messages

**Causes:**
- Redis plugin not added
- REDIS_URL not configured
- Connection timeout
- Redis memory exhausted

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
   # Format: redis://[password@]host:port
   ```

3. **Check Memory Usage:**
   ```bash
   # Railway Dashboard → Redis → Metrics
   # If memory at 100%, increase allocation or clean up data
   ```

4. **Test Connection:**
   ```bash
   # From service container:
   redis-cli -u $REDIS_URL ping
   # Should return "PONG"
   ```

**Prevention:**
- Add Redis plugin before services that need caching
- Monitor Redis memory usage
- Implement proper TTL for cached data
- Use Redis for ephemeral data only (it's not backed up)

**Related Links:**
- [Service Communication - Redis](../architecture/SERVICE_COMMUNICATION.md:195)

---

### Qdrant: Vector Storage Problems

**Symptoms:**
- Vector search returns no results
- Can't create collections
- 401 Unauthorized errors
- Slow query performance

**Causes:**
- QDRANT_API_KEY not configured or mismatched
- Qdrant service not running
- Collection doesn't exist
- Vector dimensions mismatch
- Indexing still in progress

**Solution:**

1. **Verify API Key:**
   ```bash
   # Qdrant service:
   QDRANT_API_KEY=your-key-here
   
   # R2R service (must match):
   R2R_QDRANT_API_KEY=your-key-here
   ```

2. **Check Collection Exists:**
   ```bash
   curl -H "api-key: YOUR_KEY" \
     http://qdrant.railway.internal:6333/collections
   
   # Should list your collections
   ```

3. **Verify Vector Dimensions:**
   ```bash
   # Check collection schema
   curl -H "api-key: YOUR_KEY" \
     http://qdrant.railway.internal:6333/collections/{collection_name}
   
   # Vectors in query must match "size" field
   ```

4. **Wait for Indexing:**
   ```bash
   # After bulk upload, indexing may take time
   # Check metrics:
   curl http://qdrant.railway.internal:6333/metrics | grep indexing
   ```

5. **Performance Optimization:**
   ```bash
   # Enable vector cache for better performance
   QDRANT__PERFORMANCE__VECTOR_CACHE_SIZE_GB=1
   
   # Use quantization for large collections
   # (see Qdrant documentation)
   ```

**Prevention:**
- Always set API keys consistently
- Create collections before inserting vectors
- Document vector dimensions for each collection
- Monitor indexing progress after bulk uploads
- Test search queries before production use

**Related Links:**
- [Qdrant README](../../services/qdrant/README.md:1)
- [Qdrant Troubleshooting Guide](../../services/qdrant/TROUBLESHOOTING.md:1)

---

### R2R: RAG Pipeline Failures

**Symptoms:**
- Document ingestion fails
- RAG queries return errors
- pgvector extension errors in logs
- Can't retrieve documents

**Causes:**
- Dependencies not available (PostgreSQL, Qdrant, Redis)
- pgvector extension error (expected on Railway)
- Vector embeddings not generated
- LiteLLM connection issues

**Solution:**

1. **Verify All Dependencies Running:**
   ```bash
   # Check status of:
   - PostgreSQL plugin: Running
   - Redis plugin: Running
   - Qdrant service: Healthy
   - LiteLLM service: Healthy (if using completions)
   ```

2. **pgvector Errors (EXPECTED):**
   ```bash
   # These warnings are normal on Railway:
   "⚠ pgvector extension creation failed (expected on Railway)"
   "Vector storage will use Qdrant (configured in r2r.toml)"
   
   # This is by design - see PGVECTOR_WORKAROUND.md
   # R2R uses Qdrant for vectors, PostgreSQL for metadata
   ```

3. **Test Document Ingestion:**
   ```bash
   curl -X POST http://r2r.railway.internal:7272/v3/ingest \
     -H "Content-Type: application/json" \
     -d '{
       "document": {
         "text": "Test document",
         "metadata": {"title": "Test"}
       }
     }'
   
   # Should return success response
   ```

4. **Check Qdrant for Vectors:**
   ```bash
   # Verify vectors were stored
   curl -H "api-key: $QDRANT_API_KEY" \
     http://qdrant.railway.internal:6333/collections
   ```

5. **Test RAG Query:**
   ```bash
   curl -X POST http://r2r.railway.internal:7272/v3/rag \
     -H "Content-Type: application/json" \
     -d '{"query": "What is the test document about?"}'
   ```

**Prevention:**
- Deploy dependencies before R2R
- Understand pgvector error is expected behavior
- Test ingest/query pipeline after deployment
- Monitor R2R logs for actual errors (not pgvector warnings)

**Related Links:**
- [R2R README](../../services/r2r/README.md:1)
- [R2R pgvector Workaround](../../services/r2r/PGVECTOR_WORKAROUND.md:1)

---

## Inter-Service Communication Issues

### Issue: Services Can't Reach Each Other

**Symptoms:**
- "Connection refused" errors between services
- "Could not resolve hostname" errors
- Timeout errors on internal API calls

**Causes:**
- Incorrect internal DNS names
- Service not running or unhealthy
- Wrong port number
- Services in different Railway projects

**Solution:**

1. **Verify DNS Names:**
   ```bash
   # CORRECT internal DNS format:
   litellm.railway.internal:4000
   openwebui.railway.internal:8080
   r2r.railway.internal:7272
   qdrant.railway.internal:6333
   
   # INCORRECT:
   litellm.railway.com          # External domain, not internal
   litellm:4000                 # Missing .railway.internal
   ```

2. **Check Service Health:**
   ```bash
   # Railway Dashboard → Each Service
   # Verify all show "Healthy" status
   # Check logs for errors
   ```

3. **Verify Port Numbers:**
   ```bash
   # Common ports:
   - LiteLLM: 4000
   - Open WebUI: 8080
   - R2R: 7272
   - Qdrant HTTP: 6333
   - Qdrant gRPC: 6334
   ```

4. **Test Health Endpoints:**
   ```bash
   # From any service container or Railway shell:
   curl http://litellm.railway.internal:4000/health
   curl http://r2r.railway.internal:7272/health
   curl http://qdrant.railway.internal:6333/health
   ```

5. **Verify Same Project:**
   ```bash
   # All services must be in the same Railway project
   # Railway Dashboard → Project → View all services
   ```

**Prevention:**
- Use internal DNS consistently
- Document service endpoints
- Test inter-service communication after deployment
- Keep all services in same project

**Related Links:**
- [Service Communication](../architecture/SERVICE_COMMUNICATION.md:1)

---

### Issue: Authentication Failures Between Services

**Symptoms:**
- 401 Unauthorized errors
- 403 Forbidden errors
- API calls rejected despite correct credentials

**Causes:**
- Mismatched API keys between services
- Missing Authorization headers
- Wrong authentication method

**Solution:**

1. **LiteLLM ↔ Open WebUI:**
   ```bash
   # Keys must match exactly:
   # LiteLLM:
   LITELLM_MASTER_KEY=sk-abc123
   
   # Open WebUI:
   OPENAI_API_KEY=sk-abc123  # Same value!
   ```

2. **Qdrant ↔ R2R:**
   ```bash
   # Keys must match:
   # Qdrant:
   QDRANT_API_KEY=secure-key
   
   # R2R:
   R2R_QDRANT_API_KEY=secure-key  # Same value!
   ```

3. **Verify Headers:**
   ```bash
   # LiteLLM expects:
   Authorization: Bearer {key}
   
   # Qdrant expects:
   api-key: {key}
   ```

4. **Test with Correct Auth:**
   ```bash
   # LiteLLM
   curl -H "Authorization: Bearer $KEY" \
     http://litellm.railway.internal:4000/v1/models
   
   # Qdrant
   curl -H "api-key: $KEY" \
     http://qdrant.railway.internal:6333/collections
   ```

**Prevention:**
- Document which services share keys
- Use single source of truth for keys
- Test authentication immediately after setting keys
- Rotate keys consistently across all services

**Related Links:**
- [Service Communication - Authentication](../architecture/SERVICE_COMMUNICATION.md:127)

---

### Issue: Timeout Errors

**Symptoms:**
- Requests timeout after 30-60 seconds
- Gateway timeout (504) errors
- "Request took too long" messages

**Causes:**
- Service overloaded or processing slowly
- Long-running operations without proper timeout handling
- Insufficient resources (CPU/memory)
- Network congestion

**Solution:**

1. **Increase Client Timeout:**
   ```python
   # Python example
   import httpx
   
   client = httpx.Client(timeout=120.0)  # 2 minute timeout
   response = client.post(url, json=data)
   ```

2. **Check Service Resources:**
   ```bash
   # Railway Dashboard → Service → Metrics
   # Look for:
   - CPU at 100% (scale up)
   - Memory at limit (scale up)
   - High request latency
   ```

3. **Optimize Operations:**
   ```bash
   # For R2R document processing:
   - Batch smaller chunks
   - Process asynchronously
   - Monitor job queue in Redis
   
   # For Qdrant vector operations:
   - Batch insert/search operations
   - Wait for indexing to complete
   - Enable vector caching
   ```

4. **Implement Retry Logic:**
   ```python
   # Python example with retries
   import tenacity
   
   @tenacity.retry(
       stop=tenacity.stop_after_attempt(3),
       wait=tenacity.wait_exponential(multiplier=1, min=4, max=10)
   )
   def call_service():
       return httpx.post(url, timeout=60.0)
   ```

**Prevention:**
- Set appropriate timeouts for different operation types
- Monitor service response times
- Scale resources proactively
- Use async operations for long-running tasks
- Implement circuit breakers for failing services

**Related Links:**
- [Service Communication - Timeout Issues](../architecture/SERVICE_COMMUNICATION.md:258)

---

## Performance Issues

### Issue: Slow Response Times

**Symptoms:**
- LLM responses take longer than expected
- Vector search queries are slow
- UI feels sluggish
- High latency metrics

**Causes:**
- Insufficient CPU or memory allocation
- Database query optimization needed
- Vector search not optimized
- No caching enabled

**Solution:**

1. **Scale Service Resources:**
   ```bash
   # Railway Dashboard → Service → Settings → Resources
   # For each slow service:
   - Increase memory (1GB → 2GB)
   - Increase CPU (0.5 → 1 core)
   ```

2. **Enable Redis Caching:**
   ```bash
   # For LiteLLM:
   REDIS_URL=${{Redis.REDIS_URL}}
   
   # For Open WebUI:
   REDIS_URL=${{Redis.REDIS_URL}}
   ```

3. **Optimize Qdrant:**
   ```bash
   # Enable vector cache
   QDRANT__PERFORMANCE__VECTOR_CACHE_SIZE_GB=2
   
   # Increase index threads
   QDRANT__PERFORMANCE__INDEX_THREADS=4
   
   # Use quantization for large collections
   # (see Qdrant documentation)
   ```

4. **Database Optimization:**
   ```bash
   # Add database indexes on frequently queried fields
   # Review slow query logs
   # Consider connection pooling tuning
   ```

5. **Monitor Metrics:**
   ```bash
   # Track these metrics:
   - API response time (p50, p95, p99)
   - Database query time
   - Vector search latency
   - Memory and CPU usage
   ```

**Prevention:**
- Right-size resources from the start based on workload
- Enable caching layers (Redis)
- Monitor performance metrics continuously
- Load test before production launch
- Optimize queries and operations proactively

**Related Links:**
- [Qdrant Troubleshooting - Performance](../../services/qdrant/TROUBLESHOOTING.md:93)

---

### Issue: Memory Exhaustion

**Symptoms:**
- Service crashes with OOM (Out of Memory) errors
- Memory usage shows constant 100%
- Service restarts repeatedly
- Slow performance before crash

**Causes:**
- Insufficient memory allocation
- Memory leaks in application
- Large vector collections without quantization
- Too many concurrent operations

**Solution:**

1. **Immediate Fix - Scale Up:**
   ```bash
   # Railway Dashboard → Service → Settings → Resources
   # Double current memory allocation
   # Example: 1GB → 2GB
   ```

2. **Identify Memory Hog:**
   ```bash
   # Check each service's memory usage
   # Railway Dashboard → Service → Metrics
   
   # Common culprits:
   - Qdrant: Large unoptimized collections
   - R2R: Document processing batches too large
   - PostgreSQL: Connection pool too large
   ```

3. **Optimize Qdrant Memory:**
   ```bash
   # Use quantization to reduce memory 75%
   # When creating collections:
   "quantization_config": {
     "scalar": {
       "type": "int8",
       "quantile": 0.99,
       "always_ram": true
     }
   }
   
   # Reduce vector cache if set too high
   QDRANT__PERFORMANCE__VECTOR_CACHE_SIZE_GB=1
   ```

4. **Optimize Application:**
   ```python
   # Process in smaller batches
   batch_size = 100  # Instead of 1000
   
   # Clear large objects from memory
   import gc
   gc.collect()
   
   # Use generators instead of loading all data
   ```

5. **Monitor Long-Term:**
   ```bash
   # Set up alerts:
   - Memory > 80% for 5 minutes → Warning
   - Memory > 90% for 1 minute → Critical
   ```

**Prevention:**
- Allocate sufficient memory from the start
- Use quantization for vector databases
- Process data in appropriate batch sizes
- Monitor memory trends over time
- Implement memory-efficient algorithms

**Related Links:**
- [Qdrant Troubleshooting - Memory Usage](../../services/qdrant/TROUBLESHOOTING.md:160)

---

### Issue: High Database Load

**Symptoms:**
- Slow query performance
- High CPU usage on PostgreSQL
- Connection pool exhaustion
- Timeout errors on database queries

**Causes:**
- Missing database indexes
- N+1 query problems
- Too many connections
- Inefficient queries

**Solution:**

1. **Add Indexes:**
   ```sql
   -- Common indexes needed:
   
   -- For conversation lookup
   CREATE INDEX idx_conversations_user_id ON conversations(user_id);
   CREATE INDEX idx_conversations_created_at ON conversations(created_at);
   
   -- For document metadata
   CREATE INDEX idx_documents_collection ON documents(collection_name);
   CREATE INDEX idx_documents_created_at ON documents(created_at);
   ```

2. **Optimize Connection Pooling:**
   ```python
   # Reduce max connections if pool exhaustion
   # In application configuration:
   pool_size = 10  # Instead of 20
   max_overflow = 5  # Instead of 20
   ```

3. **Review Query Patterns:**
   ```bash
   # PostgreSQL slow query log
   # Identify queries taking > 1 second
   # Optimize with indexes or query restructuring
   ```

4. **Scale PostgreSQL:**
   ```bash
   # Railway Dashboard → PostgreSQL Plugin → Settings
   # Increase resources if needed
   ```

**Prevention:**
- Add indexes for all frequently queried columns
- Use connection pooling appropriately
- Monitor query performance regularly
- Use database query analysis tools
- Implement caching for repeated queries

---

## Data and Configuration Issues

### Issue: LiteLLM config.yaml Problems

**Symptoms:**
- Models not appearing in available list
- Configuration errors in logs
- Can't route to specific providers
- Invalid YAML syntax errors

**Causes:**
- Malformed YAML syntax
- Missing required fields
- Incorrect model names
- Environment variable references wrong

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

3. **Verify Model Names:**
   ```bash
   # Check LiteLLM documentation for correct format:
   # OpenAI: "openai/model-name"
   # Anthropic: "anthropic/model-name"
   # Azure: "azure/deployment-name"
   ```

4. **Test Configuration:**
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
- Test each model after adding to config
- Document model configurations
- Version control config.yaml

**Related Links:**
- [LiteLLM README - Configuration](../../services/litellm/README.md:97)

---

### Issue: Missing Required Configurations

**Symptoms:**
- Service starts but features don't work
- Silent failures with no error messages
- Partial functionality only

**Causes:**
- Optional environment variables not set
- Configuration files missing
- Default values not appropriate for production
- Feature flags not enabled

**Solution:**

1. **Review Service-Specific Requirements:**
   ```bash
   # Check each service README for:
   - Required environment variables (marked "Required")
   - Optional but recommended variables
   - Configuration files needed
   ```

2. **Common Missing Configs:**
   ```bash
   # Open WebUI:
   WEBUI_SECRET_KEY=<required>        # Often forgotten
   QDRANT_URI=<required for RAG>      # Must be complete URI
   
   # Qdrant:
   QDRANT_API_KEY=<recommended>       # Should set for production
   
   # LiteLLM:
   LITELLM_MASTER_KEY=<required>      # Must be set
   ```

3. **Check Feature-Specific Configs:**
   ```bash
   # For RAG features:
   - VECTOR_DB=qdrant
   - QDRANT_URI=http://qdrant.railway.internal:6333
   
   # For caching:
   - REDIS_URL=${{Redis.REDIS_URL}}
   
   # For database persistence:
   - DATABASE_URL=${{Postgres.DATABASE_URL}}
   ```

4. **Use Checklists:**
   ```bash
   # Follow deployment checklist:
   1. ✅ All required variables set
   2. ✅ All optional but recommended variables considered
   3. ✅ Configuration files in place
   4. ✅ Dependencies running
   5. ✅ Test each feature after deployment
   ```

**Prevention:**
- Use complete .env.example files as templates
- Follow service-specific deployment guides
- Create deployment checklist
- Test all features after configuration
- Document required vs. optional configs

**Related Links:**
- [Environment Variables Guide](../../ENV_VARIABLES_GUIDE.md:1)
- [Quick Start Railway](../../QUICK_START_RAILWAY.md:1)

---

### Issue: Database Schema Issues

**Symptoms:**
- "Relation does not exist" errors
- "Column not found" errors
- Migration failures
- Data not persisting correctly

**Causes:**
- Database migrations not run
- Schema out of sync with application
- Tables not created
- Permissions issues

**Solution:**

1. **Check Migration Status:**
   ```bash
   # For services with migrations:
   # - Check logs for migration execution
   # - Verify all tables exist
   ```

2. **Manually Create Tables (if needed):**
   ```sql
   -- Connect to PostgreSQL
   psql $DATABASE_URL
   
   -- List tables
   \dt
   
   -- Check for missing tables
   -- Run migrations if available
   ```

3. **Verify Permissions:**
   ```bash
   # Ensure database user has required permissions:
   # - SELECT, INSERT, UPDATE, DELETE
   # - CREATE TABLE (for migrations)
   ```

4. **Reset Database (Last Resort):**
   ```bash
   # In development only:
   # 1. Drop all tables
   # 2. Redeploy service (should recreate schema)
   # 3. Verify tables created correctly
   
   # WARNING: This loses all data!
   ```

**Prevention:**
- Document database schema and migrations
- Run migrations as part of deployment
- Test schema changes in development first
- Version control migration scripts
- Have database backup before schema changes

---

## Getting Additional Help

If issues persist after trying solutions in this guide:

1. **Check Service-Specific Troubleshooting:**
   - [Qdrant Troubleshooting](../../services/qdrant/TROUBLESHOOTING.md:1)
   - [R2R pgvector Workaround](../../services/r2r/PGVECTOR_WORKAROUND.md:1)

2. **Review Architecture Documentation:**
   - [Architecture Overview](../architecture/OVERVIEW.md:1)
   - [Service Communication](../architecture/SERVICE_COMMUNICATION.md:1)

3. **Check Railway Resources:**
   - [Railway Status](https://status.railway.app)
   - [Railway Documentation](https://docs.railway.app)
   - [Railway Discord](https://discord.gg/railway)

4. **Project-Specific Resources:**
   - [Main README](../../README.md:1)
   - [Quick Start Guide](../../QUICK_START_RAILWAY.md:1)
   - [Environment Variables Guide](../../ENV_VARIABLES_GUIDE.md:1)

5. **Community Support:**
   - Open an issue on GitHub with:
     - Detailed error messages
     - Service logs (last 100 lines)
     - Environment variable configuration (redact sensitive values)
     - Steps to reproduce
   - Join relevant Discord communities:
     - Railway Discord
     - Qdrant Discord
     - R2R community

---

**Last Updated**: 2026-01-19  
**Version**: 1.0 (Railway-optimized)  
**Feedback**: Please contribute additional issues and solutions via GitHub issues
