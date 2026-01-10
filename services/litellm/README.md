# LiteLLM Service

This service deploys LiteLLM as a unified API gateway for multiple LLM providers as part of the Railway template. LiteLLM provides a standardized interface for calling various language models (OpenAI, Anthropic, Google, Azure, and more) with a single API endpoint.

## Service Details

- **Port**: 4000
- **Internal DNS**: `litellm.railway.internal:4000`
- **Health Check**: `/health` endpoint
- **Restart Policy**: `ON_FAILURE` with max 10 retries

## Configuration

### Environment Variables

The service requires the following environment variables, which are automatically set by Railway:

| Variable | Source | Description |
|----------|--------|-------------|
| `LITELLM_HOST` | Default: `0.0.0.0` | LiteLLM server host binding |
| `LITELLM_PORT` | Default: `4000` | LiteLLM server port |
| `LITELLM_MASTER_KEY` | Required | Master API key for authentication (set in Railway) |
| `DATABASE_URL` | `${{Postgres.DATABASE_URL}}` | PostgreSQL connection for caching and logging |
| `REDIS_URL` | `${{Redis.REDIS_URL}}` | Redis connection for distributed caching |
| `OPENAI_API_KEY` | Environment | OpenAI API key for GPT models |
| `ANTHROPIC_API_KEY` | Environment | Anthropic API key for Claude models |
| `GOOGLE_APPLICATION_CREDENTIALS` | Environment | Google Cloud credentials for Vertex AI |
| `AZURE_API_KEY` | Environment | Azure OpenAI API key |
| `AZURE_API_BASE` | Environment | Azure OpenAI base URL |
| `AZURE_API_VERSION` | Environment | Azure OpenAI API version |
| `REPLICATE_API_KEY` | Environment | Replicate API key |
| `COHERE_API_KEY` | Environment | Cohere API key |
| `LITELLM_LOG_LEVEL` | Default: `INFO` | Logging level (DEBUG, INFO, WARNING, ERROR) |

## Dependencies

LiteLLM can run standalone but optionally supports the following services for enhanced functionality:

1. **PostgreSQL** (Optional) - Provides persistent caching, API call logging, and request tracking
2. **Redis** (Optional) - Enables distributed caching, rate limiting, and session management

By default, LiteLLM starts without these connections to allow quick deployment and testing. To enable them, see [SETUP_DATABASE_REDIS.md](./SETUP_DATABASE_REDIS.md).

## Dockerfile

The Dockerfile uses:
- Official LiteLLM image `ghcr.io/berriai/litellm:main-latest`
- Includes all dependencies pre-installed (PostgreSQL, Redis clients)
- Health check for automatic monitoring
- Configuration via mounted config file

## Service-to-Service Communication

From the React Client, R2R, or other services, you can reach LiteLLM using:
```
http://litellm.railway.internal:4000
```

Example API calls:
```bash
# Health check
curl http://litellm.railway.internal:4000/health

# List available models
curl http://litellm.railway.internal:4000/v1/models \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY"

# Completion endpoint (compatible with OpenAI API)
curl -X POST http://litellm.railway.internal:4000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -d '{
    "model": "gpt-4",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

## LLM Provider Configuration Examples

### OpenAI (GPT-4, GPT-3.5)
```bash
# Set in Railway environment variables
OPENAI_API_KEY=sk-...
```

**API Usage:**
```bash
curl -X POST http://litellm.railway.internal:4000/v1/chat/completions \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -d '{
    "model": "gpt-4",
    "messages": [{"role": "user", "content": "Your prompt"}]
  }'
```

### Anthropic (Claude)
```bash
# Set in Railway environment variables
ANTHROPIC_API_KEY=sk-ant-...
```

**API Usage:**
```bash
curl -X POST http://litellm.railway.internal:4000/v1/chat/completions \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -d '{
    "model": "claude-3-opus",
    "messages": [{"role": "user", "content": "Your prompt"}]
  }'
```

### Azure OpenAI
```bash
# Set in Railway environment variables
AZURE_API_KEY=your-key
AZURE_API_BASE=https://your-resource-name.openai.azure.com/
AZURE_API_VERSION=2024-02-15-preview
```

**API Usage:**
```bash
curl -X POST http://litellm.railway.internal:4000/v1/chat/completions \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -d '{
    "model": "azure/your-deployment-name",
    "messages": [{"role": "user", "content": "Your prompt"}]
  }'
```

### Google Vertex AI
```bash
# Set in Railway environment variables
GOOGLE_APPLICATION_CREDENTIALS=/path/to/credentials.json
```

**API Usage:**
```bash
curl -X POST http://litellm.railway.internal:4000/v1/chat/completions \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -d '{
    "model": "vertex_ai/gemini-pro",
    "messages": [{"role": "user", "content": "Your prompt"}]
  }'
```

## Health Checks

The service includes a health check that:
- Runs every 30 seconds
- Times out after 5 seconds
- Has a 10-second startup period
- Requires 3 consecutive failures to restart the container

## Local Development

To run locally with Docker Compose:

```yaml
services:
  litellm:
    build: ./services/litellm
    ports:
      - "4000:4000"
    environment:
      - LITELLM_HOST=0.0.0.0
      - LITELLM_PORT=4000
      - LITELLM_MASTER_KEY=dev-key-change-in-production
      - DATABASE_URL=postgresql://postgres:postgres@postgres:5432/litellm
      - REDIS_HOST=redis
      - REDIS_PORT=6379
      - REDIS_PASSWORD=
      - REDIS_URL=redis://redis:6379
      - OPENAI_API_KEY=sk-...  # Add your API keys
      - LITELLM_LOG_LEVEL=DEBUG
    depends_on:
      - postgres
      - redis
```

To run the container directly:

```bash
# Build the Docker image
docker build -t litellm:latest ./services/litellm

# Run without database/Redis (default)
docker run -p 4000:4000 \
  -e LITELLM_MASTER_KEY=dev-key \
  -e OPENAI_API_KEY=sk-... \
  litellm:latest

# Or run with database and Redis (when available)
docker run -p 4000:4000 \
  -e LITELLM_MASTER_KEY=dev-key \
  -e DATABASE_URL=postgresql://user:pass@host:5432/litellm \
  -e REDIS_HOST=redis-host \
  -e REDIS_PORT=6379 \
  -e REDIS_PASSWORD= \
  -e OPENAI_API_KEY=sk-... \
  litellm:latest
```

You can also use the official image directly:

```bash
docker run -p 4000:4000 \
  -v $(pwd)/config.yaml:/app/config.yaml \
  -e LITELLM_MASTER_KEY=dev-key \
  -e OPENAI_API_KEY=sk-... \
  ghcr.io/berriai/litellm:main-latest \
  --config /app/config.yaml
```

## Deployment on Railway

1. Add the LiteLLM service to your Railway project
2. Set the following environment variables in your LiteLLM service:
   - `LITELLM_MASTER_KEY`: A strong, unique key for API authentication
   - `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, etc.: Your LLM provider API keys
3. **(Optional)** For production use, add PostgreSQL and Redis plugins:
   - `DATABASE_URL`: Use `${{Postgres.DATABASE_URL}}`
   - `REDIS_HOST`: Use `${{Redis.REDIS_HOST}}`
   - `REDIS_PORT`: Use `${{Redis.REDIS_PORT}}`
   - `REDIS_PASSWORD`: Use `${{Redis.REDIS_PASSWORD}}`
   - See [SETUP_DATABASE_REDIS.md](./SETUP_DATABASE_REDIS.md) for full setup instructions
4. The `railway.toml` file automatically configures the build and deployment settings

## Troubleshooting

### Health Check Failures
- Ensure the service is properly configured and all environment variables are set
- Check logs to verify the server started successfully
- Verify port 4000 is not in use by another service

### API Key Errors
- Ensure all LLM provider API keys are correctly set in Railway environment variables
- Use the health check endpoint to verify the service is running
- Check service logs for authentication errors

### Connection Refused or Service Won't Start
- Ensure the LiteLLM service is listening on port 4000
- Check LiteLLM logs for startup errors
- Verify `LITELLM_MASTER_KEY` is set
- For service-to-service communication, ensure internal DNS is properly configured (`litellm.railway.internal`)
- If using PostgreSQL/Redis, verify they are running and accessible (see [SETUP_DATABASE_REDIS.md](./SETUP_DATABASE_REDIS.md))

### Performance Issues
- Monitor database query performance if using PostgreSQL for caching
- Consider Redis connection pooling for improved performance
- Check LiteLLM logs for timeout or rate limiting issues

## API Documentation

For complete API documentation, visit:
- [LiteLLM Documentation](https://docs.litellm.ai/)
- [OpenAI API Reference](https://platform.openai.com/docs/api-reference)

## Security Considerations

- Always use a strong, unique `LITELLM_MASTER_KEY` in production
- Store all API keys securely in Railway's environment variable system
- Consider implementing rate limiting for production deployments
- Use PostgreSQL and Redis for audit logging and performance monitoring
- Enable HTTPS for all external communication (handled by Railway)
