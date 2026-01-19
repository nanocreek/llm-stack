# PostgreSQL with pgvector Extension

Production-ready PostgreSQL 16 database with pgvector extension for vector storage capabilities.

## Overview

This service provides PostgreSQL 16 with the pgvector extension pre-installed. While the main [`llm-stack`](../../README.md) deployment uses **Qdrant** for primary vector storage, this service is available for applications that specifically require pgvector.

### When to Use This Service

**Use Qdrant (recommended for this stack)**:
- Primary vector storage for R2R
- High-performance similarity search
- Scalable vector operations
- The default and recommended option

**Use postgres-pgvector when**:
- You specifically need pgvector for compatibility
- Migrating from existing pgvector deployments
- Local development matching pgvector-based systems
- Additional vector storage requirements

## Railway Deployment

This service is designed to deploy as part of the parent [`llm-stack`](../../README.md) Railway template. For standalone deployment:

1. Create new Railway service from GitHub repo
2. Set root directory: `services/postgres-pgvector`
3. Configure environment variables (see below)
4. Deploy

### Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `POSTGRES_USER` | Database user | `postgres` | No |
| `POSTGRES_PASSWORD` | Database password | None | **Yes** |
| `POSTGRES_DB` | Database name | `r2r` | No |
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
  -e POSTGRES_DB=r2r \
  -v postgres_data:/var/lib/postgresql/data \
  pgvector/pgvector:pg16

# Connect
psql postgresql://postgres:postgres@localhost:5432/r2r
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
      POSTGRES_DB: r2r
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

## Important Notes

### Default Stack Uses Qdrant

The main [`llm-stack`](../../README.md) deployment uses **Qdrant** as the primary vector database, not pgvector. This service is included for:
- Optional pgvector compatibility
- Local development scenarios
- Specific use cases requiring pgvector

### R2R Configuration

If using R2R with this postgres-pgvector service instead of Qdrant:
1. Set `R2R_VECTOR_DB_PROVIDER=pgvector` in R2R environment
2. Configure PostgreSQL connection in R2R
3. Disable Qdrant-related configuration
4. See [`services/r2r/README.md`](../r2r/README.md) for details

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
