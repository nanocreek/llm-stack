# Setting up PostgreSQL and Redis for LiteLLM

By default, LiteLLM starts without PostgreSQL and Redis connections to allow for quick deployment and testing. Once you have PostgreSQL and Redis services running, follow these steps to enable full functionality.

## Why Enable Database and Redis?

- **PostgreSQL**: Provides persistent caching, API call logging, and request tracking
- **Redis**: Enables distributed caching, rate limiting, and session management

## Quick Setup

### For Railway Deployment

1. **Add PostgreSQL and Redis Plugins** to your Railway project
2. **Update LiteLLM environment variables**:
   ```
   DATABASE_URL=${{Postgres.DATABASE_URL}}
   REDIS_HOST=${{Redis.REDIS_HOST}}
   REDIS_PORT=${{Redis.REDIS_PORT}}
   REDIS_PASSWORD=${{Redis.REDIS_PASSWORD}}
   REDIS_URL=${{Redis.REDIS_URL}}
   ```
3. **Redeploy the LiteLLM service**

### For Kubernetes Deployment

1. **Ensure PostgreSQL and Redis services are running**:
   ```bash
   kubectl get pods | grep -E 'postgres|redis'
   ```

2. **Edit `k8s/base/litellm-deployment.yaml`** and uncomment the database environment variables:
   ```yaml
   - name: DATABASE_URL
     value: "postgresql://postgres:postgres@postgres:5432/litellm"
   - name: REDIS_HOST
     value: "redis"
   - name: REDIS_PORT
     value: "6379"
   - name: REDIS_PASSWORD
     value: ""
   ```

3. **Edit `k8s/base/litellm-configmap.yaml`** and uncomment the database settings:
   ```yaml
   database_url: os.environ/DATABASE_URL
   redis_host: os.environ/REDIS_HOST
   redis_port: os.environ/REDIS_PORT
   redis_password: os.environ/REDIS_PASSWORD
   ```

4. **Apply the changes**:
   ```bash
   kubectl apply -k k8s/base/
   ```

### For Docker/Local Development

1. **Update `services/litellm/config.yaml`** and uncomment:
   ```yaml
   general_settings:
     database_url: os.environ/DATABASE_URL
     redis_host: os.environ/REDIS_HOST
     redis_port: os.environ/REDIS_PORT
     redis_password: os.environ/REDIS_PASSWORD
   ```

2. **Set environment variables** when running the container:
   ```bash
   docker run -p 4000:4000 \
     -e LITELLM_MASTER_KEY=your-key \
     -e DATABASE_URL=postgresql://user:pass@host:5432/litellm \
     -e REDIS_HOST=redis-host \
     -e REDIS_PORT=6379 \
     -e REDIS_PASSWORD=your-redis-password \
     litellm:latest
   ```

## Verifying Connections

Once enabled, you can verify the connections are working:

1. **Check LiteLLM logs** for connection messages:
   ```bash
   # Railway
   railway logs litellm
   
   # Kubernetes
   kubectl logs -l app=litellm
   
   # Docker
   docker logs <container-id>
   ```

2. **Test the health endpoint**:
   ```bash
   curl http://your-litellm-url:4000/health
   ```

3. **Verify database tables** were created:
   ```bash
   psql $DATABASE_URL -c "\dt"
   ```

## Troubleshooting

### LiteLLM won't start after enabling connections

- **Check PostgreSQL is accessible**: `psql $DATABASE_URL`
- **Check Redis is accessible**: `redis-cli -h $REDIS_HOST -p $REDIS_PORT ping`
- **Verify credentials** are correct in environment variables
- **Check network connectivity** between services

### Performance issues after enabling

- **Monitor Redis memory usage**: Adjust `maxmemory` if needed
- **Check PostgreSQL query performance**: Add indexes if necessary
- **Review LiteLLM logs** for slow query warnings

## Best Practices

1. **Always enable in production** for better reliability and observability
2. **Use connection pooling** for high-traffic deployments
3. **Regular backups** of PostgreSQL data
4. **Monitor Redis memory** and configure eviction policies
5. **Set up proper authentication** for both services