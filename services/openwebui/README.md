# OpenWebUI Service

This service deploys OpenWebUI as part of the Railway template stack. OpenWebUI is a user-friendly web interface for interacting with Large Language Models (LLMs) via an OpenAI-compatible API.

## Service Overview

**OpenWebUI** provides a modern, feature-rich chat interface for LLM interactions. It connects to LiteLLM as its backend, which provides a unified interface to multiple LLM providers. The service includes user management, conversation history, and file upload capabilities.

### Key Features
- Modern, responsive web interface for LLM interactions
- User authentication and session management
- Conversation history and persistence
- File upload and document handling
- OpenAI-compatible API integration
- Built-in security and access control
- Role-based user management

## Configuration

### Port Information
- **Internal Port**: 8080
- **Internal DNS**: `openwebui.railway.internal:8080`
- **Protocol**: HTTP
- **Health Check Endpoint**: `/` (root)

### Health Check
- **Endpoint**: `/` (root endpoint)
- **Interval**: 30 seconds
- **Timeout**: 5 seconds
- **Start Period**: 10 seconds
- **Retries**: 3 consecutive failures before restart

## Environment Variables

The following environment variables are required for OpenWebUI to function properly:

| Variable | Source | Required | Description |
|----------|--------|----------|-------------|
| `PORT` | Default: `8080` | Yes | OpenWebUI server port |
| `OPENAI_API_BASE_URL` | `http://litellm.railway.internal:4000/v1` | Yes | LiteLLM OpenAI-compatible endpoint |
| `OPENAI_API_KEY` | `${{LiteLLM.LITELLM_MASTER_KEY}}` | Yes | API key for LiteLLM authentication |
| `DATABASE_URL` | `${{Postgres.DATABASE_URL}}` | Yes | PostgreSQL connection string for data persistence |
| `REDIS_URL` | `${{Redis.REDIS_URL}}` | Yes | Redis connection URL for caching and sessions |
| `WEBUI_AUTH` | Default: `false` | No | Enable/disable authentication (set to `false` for public access) |
| `ENABLE_SIGNUP` | Default: `true` | No | Allow new user registration |
| `DEFAULT_USER_ROLE` | Default: `user` | No | Default role for new users |
| `WEBUI_LOG_LEVEL` | Default: `INFO` | No | Logging level (DEBUG, INFO, WARNING, ERROR) |
| `ENABLE_API_KEY_GENERATION` | Default: `true` | No | Allow users to generate API keys |
| `ENABLE_OAUTH` | Default: `false` | No | Enable OAuth integration |
| `SESSION_COOKIE_SECURE` | Default: `false` | No | Set secure cookies (true in production) |
| `WEBUI_SECRET_KEY` | Required | Yes | Secret key for session encryption |
| `WEBUI_NAME` | Default: `OpenWebUI` | No | Display name for the application |
| `VECTOR_DB` | Default: `qdrant` | Yes (for RAG) | Vector database provider for embeddings |
| `QDRANT_URI` | `http://qdrant.railway.internal:6333` | Yes (if VECTOR_DB=qdrant) | Complete Qdrant connection URI |
| `QDRANT_HOST` | `qdrant.railway.internal` | No | Qdrant host (kept for compatibility) |
| `QDRANT_PORT` | `6333` | No | Qdrant port (kept for compatibility) |

## Dependencies

OpenWebUI requires the following services to be running:

1. **LiteLLM** - Backend LLM service providing OpenAI-compatible API (http://litellm.railway.internal:4000)
2. **PostgreSQL** - Database for storing user data and conversation history
3. **Redis** - Cache and session store for performance optimization

## Dockerfile

The Dockerfile uses:
- `ghcr.io/open-webui/open-webui:main` - Official OpenWebUI Docker image
- Exposes port 8080 for web interface
- Includes health check for automatic monitoring
- Supports environment variable configuration

## Service-to-Service Communication

From the React Client or other services, you can reach OpenWebUI using:
```
http://openwebui.railway.internal:8080
```

### Example API Calls

```bash
# Health check
curl http://openwebui.railway.internal:8080/

# Chat completion (requires authentication)
curl -X POST http://openwebui.railway.internal:8080/api/chat \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -d '{
    "model": "gpt-4",
    "messages": [{"role": "user", "content": "Hello"}]
  }'
```

## Health Checks

The service includes a health check that:
- Runs every 30 seconds
- Times out after 5 seconds
- Has a 10-second startup period before the first check
- Requires 3 consecutive failures to trigger a restart

The health check monitors the root endpoint (`/`), which returns HTTP 200 when the service is operational.

## Local Development

To run OpenWebUI locally with Docker Compose:

```yaml
version: '3.8'
services:
  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: openwebui
      POSTGRES_PASSWORD: postgres
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data

  litellm:
    build: ./services/litellm
    ports:
      - "4000:4000"
    environment:
      LITELLM_PORT: 4000
      LITELLM_MASTER_KEY: test-key
      DATABASE_URL: postgresql://postgres:postgres@postgres:5432/openwebui
      REDIS_URL: redis://redis:6379

  openwebui:
    build: ./services/openwebui
    ports:
      - "8080:8080"
    environment:
      PORT: 8080
      OPENAI_API_BASE_URL: http://litellm:4000/v1
      OPENAI_API_KEY: test-key
      DATABASE_URL: postgresql://postgres:postgres@postgres:5432/openwebui
      REDIS_URL: redis://redis:6379
      WEBUI_AUTH: "false"
      WEBUI_SECRET_KEY: dev-secret-key
    depends_on:
      - postgres
      - redis
      - litellm

volumes:
  postgres_data:
  redis_data:
```

### Running Locally

```bash
# Build the OpenWebUI service
docker-compose build openwebui

# Start all services
docker-compose up

# Access OpenWebUI at http://localhost:8080
```

### Testing Health Check

```bash
curl http://localhost:8080/
# Expected response: HTML content with HTTP 200 status
```

## Deployment on Railway

### Prerequisites

1. Ensure PostgreSQL plugin is added to your Railway project
2. Ensure Redis plugin is added to your Railway project
3. Ensure LiteLLM service is deployed and running

### Deployment Steps

1. Add the OpenWebUI service source directory to your Railway project
2. Configure environment variables from `.env.example` in your OpenWebUI service
3. The `railway.toml` file automatically configures the build and deployment settings
4. Railway will automatically manage the restart policy and health checks

### Environment Variable Configuration

Set these variables in Railway service configuration:

```
PORT=8080
OPENAI_API_BASE_URL=http://litellm.railway.internal:4000/v1
OPENAI_API_KEY=${{LiteLLM.LITELLM_MASTER_KEY}}
DATABASE_URL=${{Postgres.DATABASE_URL}}
REDIS_URL=${{Redis.REDIS_URL}}
WEBUI_AUTH=false
ENABLE_SIGNUP=true
WEBUI_SECRET_KEY=your-secure-secret-key
WEBUI_LOG_LEVEL=INFO
```

## Restart Policy

The service uses the following restart configuration:
- **Type**: `ON_FAILURE`
- **Max Retries**: 10
- **Interval**: Automatic

This ensures the service automatically restarts if it crashes, with a maximum of 10 restart attempts.

## Troubleshooting

### QDRANT_URI Configuration Error

If you see `ValueError: QDRANT_URI is not set` in the logs:

1. **Verify `QDRANT_URI` is set in your environment variables:**
   - Go to Railway service configuration for OpenWebUI
   - Check the Variables tab
   - Ensure `QDRANT_URI=http://qdrant.railway.internal:6333` is set
   
2. **Understand why this is required:**
   - OpenWebUI's QdrantClient requires a complete pre-constructed URI string
   - Unlike R2R which constructs the connection from separate host/port, OpenWebUI expects the full URI
   
3. **Correct format for Railway internal DNS:**
   - Protocol: `http://` (Qdrant HTTP REST API)
   - Hostname: `qdrant.railway.internal` (Railway internal service DNS)
   - Port: `6333` (Qdrant HTTP API port)
   - Full URI: `http://qdrant.railway.internal:6333`

4. **Additional configuration:**
   - Keep `QDRANT_HOST=qdrant.railway.internal` (for reference)
   - Keep `QDRANT_PORT=6333` (for reference)
   - Most importantly: **Set `QDRANT_URI`** (this is what OpenWebUI actually uses)

5. **Verify Qdrant is running:**
   - Check Railway project dashboard
   - Qdrant service should show 🟢 Healthy status
   - OpenWebUI will fail to start if Qdrant is not accessible

### Connection Refused

If you see connection errors when accessing OpenWebUI:

1. Verify the service is running: Check Railway service status
2. Check PostgreSQL connectivity: Verify `DATABASE_URL` is correctly set
3. Check Redis connectivity: Verify `REDIS_URL` is correctly set
4. Check LiteLLM connectivity: Verify `OPENAI_API_BASE_URL` points to running LiteLLM service

```bash
# Test LiteLLM connectivity
curl http://litellm.railway.internal:4000/health
```

### Health Check Failures

If health checks are failing:

1. Check service logs for startup errors
2. Verify environment variables are correctly set
3. Ensure PostgreSQL and Redis are accessible
4. Check available memory and disk space

### Database Connection Issues

If OpenWebUI can't connect to PostgreSQL:

1. Verify `DATABASE_URL` format: `postgresql://user:password@host:port/database`
2. Ensure PostgreSQL service is running
3. Check PostgreSQL credentials in Railway variables
4. Verify network connectivity between services

### Session/Cache Issues

If sessions aren't persisting:

1. Verify `REDIS_URL` is correctly set
2. Ensure Redis service is running and accessible
3. Check Redis connection permissions

### Performance Issues

If OpenWebUI is slow:

1. Check available memory in Railway service configuration
2. Monitor PostgreSQL connection pool usage
3. Check Redis memory usage
4. Review OpenWebUI logs for slow queries

### API Authentication Issues

If API calls fail with authentication errors:

1. Verify `OPENAI_API_KEY` matches LiteLLM's `LITELLM_MASTER_KEY`
2. Check request headers include correct Authorization header
3. Verify API key format and validity

### Port Conflicts

If port 8080 is already in use:

1. In local development, change the host port mapping (e.g., `-p 8081:8080`)
2. On Railway, the platform manages port allocation automatically
3. Verify no other services are using port 8080

## Performance Considerations

### Memory Usage
- Minimum recommended: 512 MB
- Typical usage: 1-2 GB
- Scales with number of concurrent users and conversation history

### Database Performance
- Ensure PostgreSQL has adequate resources
- Consider indexing frequently queried fields
- Monitor connection pool utilization
- Archive old conversations if database grows large

### Redis Cache
- Monitor Redis memory usage
- Set appropriate TTL for session data
- Use Redis for frequently accessed user data

### Optimization Tips
1. Enable Redis caching for user sessions
2. Optimize database queries with proper indexing
3. Use connection pooling for database connections
4. Consider rate limiting for API endpoints
5. Monitor and tune PostgreSQL parameters

## Monitoring

### Health Status
```bash
curl http://openwebui.railway.internal:8080/
```

### Service Logs

Check Railway logs for detailed error messages and debugging information:

```bash
# View service logs in Railway dashboard
# Or use Railway CLI:
railway logs --service openwebui
```

### Metrics

Monitor these key metrics:
- Response time to LiteLLM API
- Database query performance
- Redis cache hit ratio
- User session count
- Conversation history size

## Integration with React Client

The React Client can communicate with OpenWebUI at:
```
http://openwebui.railway.internal:8080
```

### Example Frontend Integration

```javascript
// JavaScript/TypeScript example
const response = await fetch('http://openwebui.railway.internal:8080/api/chat', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer YOUR_API_KEY'
  },
  body: JSON.stringify({
    model: 'gpt-4',
    messages: [{ role: 'user', content: 'Hello' }]
  })
});

const data = await response.json();
console.log(data);
```

## Security Considerations

1. **API Keys**: Keep `OPENAI_API_KEY` and `WEBUI_SECRET_KEY` secure
2. **Database**: Ensure `DATABASE_URL` credentials are never exposed
3. **Redis**: Use authentication for Redis in production
4. **Session Cookies**: Enable secure cookies in production (`SESSION_COOKIE_SECURE=true`)
5. **Authentication**: Consider enabling `WEBUI_AUTH=true` for production deployments
6. **HTTPS**: Use HTTPS in production environments

## References

- [OpenWebUI Official Documentation](https://docs.openwebui.com/)
- [OpenWebUI GitHub Repository](https://github.com/open-webui/open-webui)
- [OpenAI API Documentation](https://platform.openai.com/docs/api-reference)
- [Railway Documentation](https://docs.railway.app/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [Redis Documentation](https://redis.io/documentation)

## Docker Build

To rebuild the image locally:

```bash
docker build -t openwebui-railway ./services/openwebui
docker run -p 8080:8080 \
  -e OPENAI_API_BASE_URL=http://localhost:4000/v1 \
  -e OPENAI_API_KEY=test-key \
  -e DATABASE_URL=postgresql://postgres:postgres@localhost:5432/openwebui \
  -e REDIS_URL=redis://localhost:6379 \
  -e WEBUI_SECRET_KEY=dev-key \
  openwebui-railway
```

## License

OpenWebUI is distributed under the MIT License. For more information, see the [OpenWebUI repository](https://github.com/open-webui/open-webui/blob/main/LICENSE).
