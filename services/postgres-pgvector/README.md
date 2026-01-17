# PostgreSQL with pgvector Extension

This service provides a PostgreSQL 16 database with the pgvector extension pre-installed, required for R2R's vector storage capabilities.

## Why pgvector?

R2R uses PostgreSQL with the pgvector extension for storing and querying vector embeddings. Standard PostgreSQL deployments (including Railway's default Postgres plugin) do not include pgvector, resulting in the error:

```
type "vector" does not exist
```

This service solves that by using the official `pgvector/pgvector:pg16` Docker image.

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `POSTGRES_USER` | Database user | `postgres` |
| `POSTGRES_PASSWORD` | Database password | (required) |
| `POSTGRES_DB` | Database name | `r2r` |

## Usage

1. Deploy this service on Railway
2. Set a secure `POSTGRES_PASSWORD`
3. Configure R2R to connect using the Railway-provided connection string

## Connection String

After deployment, use the internal Railway URL:

```
postgresql://${{POSTGRES_USER}}:${{POSTGRES_PASSWORD}}@${{RAILWAY_PRIVATE_DOMAIN}}:5432/${{POSTGRES_DB}}
```
