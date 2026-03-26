# PostgreSQL with pgvector Extension

Production-ready PostgreSQL 16 database with pgvector extension for vector storage capabilities.

## Overview

This service provides PostgreSQL 16 with the pgvector extension pre-installed. It serves as the persistent storage layer for LiteLLM caching, logging, and optional vector storage.

### Use Cases

**Primary uses in this stack:**
- LiteLLM request caching and logging
- API call tracking and analytics
- Vector storage for embeddings (optional)
- Session persistence

## Railway Deployment

This service is designed to deploy as part of the parent [`llm-stack`](../README.md) Railway template. For standalone deployment:

1. Create new Railway service from GitHub repo
2. Set root directory: `services/postgres-pgvector`
3. Configure environment variables (see below)
4. Deploy

### Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `POSTGRES_USER` | Database user | `postgres` | No |
| `POSTGRES_PASSWORD` | Database password | None | **Yes** |
| `POSTGRES_DB` | Database name | `litellm` | No |
| `POSTGRES_HOST_AUTH_METHOD` | Authentication method | `md5` | No |

**Security Note**: Always set a strong `POSTGRES_PASSWORD` in production.

### Port Information

- **Port**: 5432 (PostgreSQL default)
- **Internal DNS**: `postgres-pgvector.railway.internal:5432`
- **Protocol**: PostgreSQL wire protocol

## Configuration

### Connection String

After deployment, connect using Railway's internal DNS:

```
postgresql://${{POSTGRES_USER}}:${{POSTGRES_PASSWORD}}@postgres-pgvector.railway.internal:5432/${{POSTGRES_DB}}
```

Or using Railway service references:

```
postgresql://${{Postgres.POSTGRES_USER}}:${{Postgres.POSTGRES_PASSWORD}}@${{Postgres.RAILWAY_PRIVATE_DOMAIN}}:5432/${{Postgres.POSTGRES_DB}}
```

### Verifying pgvector Installation

```bash
# Connect to PostgreSQL
psql $DATABASE_URL

# Check pgvector extension
SELECT * FROM pg_available_extensions WHERE name = 'vector';

# Create the extension
CREATE EXTENSION IF NOT EXISTS vector;

# Verify
\dx vector
```

## Usage

### LiteLLM Caching

LiteLLM automatically uses PostgreSQL for caching when `DATABASE_URL` is configured:

```yaml
# In litellm config or environment
general_settings:
  database_url: os.environ/DATABASE_URL
```

### Creating Vector Columns

```sql
-- Create table with vector column
CREATE TABLE items (
  id SERIAL PRIMARY KEY,
  embedding VECTOR(384),  -- 384-dimensional vector
  content TEXT
);

-- Create index for faster similarity search
CREATE INDEX ON items USING ivfflat (embedding vector_cosine_ops);
```

### Vector Operations

```sql
-- Insert vector
INSERT INTO items (embedding, content) 
VALUES ('[0.1, 0.2, 0.3, ...]', 'Example text');

-- Similarity search (cosine distance)
SELECT content, 1 - (embedding <=> '[0.1, 0.2, 0.3, ...]') AS similarity
FROM items
ORDER BY embedding <=> '[0.1, 0.2, 0.3, ...]'
LIMIT 10;
```

## Local Development

### Using Docker

```bash
# Run locally
docker run -d \
  -p 5432:5432 \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=litellm \
  -v postgres_data:/var/lib/postgresql/data \
  pgvector/pgvector:pg16

# Connect
psql postgresql://postgres:postgres@localhost:5432/litellm
```

### Using Docker Compose

```yaml
services:
  postgres:
    image: pgvector/pgvector:pg16
    ports:
      - "5432:5432"
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: litellm
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
```

## Troubleshooting

### Extension Not Found

**Error**: `type "vector" does not exist`

**Solutions**:
1. Ensure you're using the `pgvector/pgvector:pg16` image
2. Create the extension: `CREATE EXTENSION IF NOT EXISTS vector;`
3. Verify pgvector is installed: `SELECT * FROM pg_available_extensions WHERE name = 'vector';`

### Connection Refused

**Solutions**:
1. Verify service is running in Railway dashboard
2. Check internal DNS: `postgres-pgvector.railway.internal`
3. Confirm port 5432 is correct
4. Verify credentials match environment variables

### Performance Issues

**Solutions**:
1. Create appropriate indexes (ivfflat for large datasets)
2. Tune PostgreSQL parameters for your workload
3. Monitor query performance with `EXPLAIN ANALYZE`
4. Consider increasing Railway resource allocation

## Version Information

- **PostgreSQL**: 16
- **pgvector**: Latest (bundled with image)
- **Base Image**: `pgvector/pgvector:pg16`

## Additional Resources

- **pgvector Documentation**: https://github.com/pgvector/pgvector
- **PostgreSQL Documentation**: https://www.postgresql.org/docs/16/
- **Railway Databases**: https://docs.railway.app/databases/postgresql

## License

PostgreSQL is distributed under the PostgreSQL License. pgvector is distributed under the Apache 2.0 License.
