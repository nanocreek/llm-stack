# Environment Variables Guide

This guide explains how to use the `.env` files for Railway deployment.

## Clean .env Files for Copy-Paste

Each service has a clean `.env` file (without comments) that you can copy directly into Railway's Raw Editor.

### How to Use:

1. **In Railway, click on a service** (e.g., "Qdrant")
2. **Go to the "Variables" tab**
3. **Click "RAW Editor"** (button at the top right)
4. **Copy the entire contents** of the corresponding `.env` file below
5. **Paste into Railway's Raw Editor**
6. **Click "Update Variables"**
7. **Repeat for each service**

---

## Service Environment Variables

### 1. React Client
**File:** [`services/react-client/.env`](services/react-client/.env)

```bash
PORT=3000
VITE_API_BASE_URL=http://openwebui.railway.internal:8080
```

---

### 2. Qdrant
**File:** [`services/qdrant/.env`](services/qdrant/.env)

```bash
QDRANT__SERVICE__HTTP_PORT=6333
QDRANT__SERVICE__GRPC_PORT=6334
```

---

### 3. LiteLLM
**File:** [`services/litellm/.env`](services/litellm/.env)

```bash
LITELLM_PORT=4000
LITELLM_MASTER_KEY=sk-1234567890abcdef
OPENAI_API_KEY=
ANTHROPIC_API_KEY=
```

**⚠️ IMPORTANT:** 
- Replace `sk-1234567890abcdef` with a strong random key: `openssl rand -base64 32`
- Add your actual API keys for `OPENAI_API_KEY` and `ANTHROPIC_API_KEY`

---

### 4. R2R
**File:** [`services/r2r/.env`](services/r2r/.env)

```bash
R2R_PORT=7272
R2R_HOST=0.0.0.0
R2R_POSTGRES_HOST=${{Postgres.PGHOST}}
R2R_POSTGRES_PORT=${{Postgres.PGPORT}}
R2R_POSTGRES_USER=${{Postgres.PGUSER}}
R2R_POSTGRES_PASSWORD=${{Postgres.PGPASSWORD}}
R2R_POSTGRES_DBNAME=${{Postgres.PGDATABASE}}
R2R_VECTOR_DB_PROVIDER=qdrant
R2R_QDRANT_HOST=qdrant.railway.internal
R2R_QDRANT_PORT=6333
REDIS_URL=${{Redis.REDIS_URL}}
```

**Note:** Railway will automatically replace `${{Postgres.*}}` and `${{Redis.*}}` with actual values from your plugins.

---

### 5. OpenWebUI
**File:** [`services/openwebui/.env`](services/openwebui/.env)

```bash
PORT=8080
OPENAI_API_BASE_URL=http://litellm.railway.internal:4000/v1
OPENAI_API_KEY=sk-1234567890abcdef
DATABASE_URL=${{Postgres.DATABASE_URL}}
REDIS_URL=${{Redis.REDIS_URL}}
WEBUI_AUTH=false
WEBUI_SECRET_KEY=your_secret_key_here
VECTOR_DB=qdrant
QDRANT_URI=http://qdrant.railway.internal:6333
QDRANT_HOST=qdrant.railway.internal
QDRANT_PORT=6333
```

**⚠️ IMPORTANT:**
- Replace `sk-1234567890abcdef` with the SAME `LITELLM_MASTER_KEY` value you used in the LiteLLM service
- Replace `your_secret_key_here` with a strong random secret key (e.g., generated with `openssl rand -base64 32`)
- `VECTOR_DB` configures the vector database backend (uses Qdrant for RAG operations)
- **`QDRANT_URI` is REQUIRED when `VECTOR_DB=qdrant`** - This is the complete connection URI in format `http://qdrant.railway.internal:6333`
- `QDRANT_HOST` and `QDRANT_PORT` are kept for backward compatibility but `QDRANT_URI` is what OpenWebUI actually uses
- `DATABASE_URL` and `REDIS_URL` are provided by Railway's PostgreSQL and Redis plugins

---

## Quick Copy-Paste Order

Copy and paste in this order for best results:

1. **Qdrant** (no dependencies)
2. **LiteLLM** (no dependencies) - Remember to set your API keys!
3. **R2R** (depends on Qdrant, Postgres, Redis)
4. **OpenWebUI** (depends on LiteLLM)
5. **React Client** (depends on OpenWebUI)

---

## Important Notes

### Railway Variable Syntax

Railway automatically resolves these special variables:
- `${{Postgres.PGHOST}}` - PostgreSQL host
- `${{Postgres.PGPORT}}` - PostgreSQL port
- `${{Postgres.PGUSER}}` - PostgreSQL user
- `${{Postgres.PGPASSWORD}}` - PostgreSQL password
- `${{Postgres.PGDATABASE}}` - PostgreSQL database name
- `${{Redis.REDIS_URL}}` - Redis connection URL

### Internal DNS

Services communicate using Railway's internal DNS:
- `qdrant.railway.internal:6333`
- `litellm.railway.internal:4000`
- `r2r.railway.internal:7272`
- `openwebui.railway.internal:8080`
- `react-client.railway.internal:3000`

### Security

⚠️ **DO NOT commit `.env` files to git!**

These files contain placeholder values for local reference only. Always use Railway's variable management for actual deployments.

The `.gitignore` files in each service directory already exclude `.env` files, but double-check before committing.

---

## Troubleshooting

### Variables Not Working?

1. **Check spelling** - Variable names are case-sensitive
2. **Check plugin names** - Ensure PostgreSQL and Redis plugins are named "Postgres" and "Redis" exactly
3. **Redeploy service** - After changing variables, trigger a redeploy
4. **Check logs** - View service logs for connection errors

### Can't Find Raw Editor?

1. Click on a service in Railway
2. Go to "Variables" tab
3. Look for "RAW Editor" button (top right of the variables section)
4. If not visible, try clicking "Add Variable" first, then look for Raw Editor

---

## Alternative: Use Railway's UI

If you prefer not to use Raw Editor, you can add variables one by one through Railway's UI:

1. Click on a service
2. Go to "Variables" tab
3. Click "New Variable"
4. Enter variable name and value
5. Click "Add"
6. Repeat for each variable

This method is more tedious but works identically to the Raw Editor.
