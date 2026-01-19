# LLM Stack - Kubernetes Deployment Overview

This document provides an overview of the Kubernetes and Skaffold configuration for local development with Minikube.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      Minikube Kubernetes Cluster                │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Stateful Services                                       │  │
│  ├──────────────────────────────────────────────────────────┤  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │  │
│  │  │  PostgreSQL  │  │    Redis     │  │   Qdrant     │   │  │
│  │  │  :5432       │  │   :6379      │  │   :6333      │   │  │
│  │  └──────────────┘  └──────────────┘  └──────────────┘   │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Application Services                                    │  │
│  ├──────────────────────────────────────────────────────────┤  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │  │
│  │  │  LiteLLM     │  │   R2R        │  │  OpenWebUI   │   │  │
│  │  │  :4000       │  │   :7272      │  │   :8080      │   │  │
│  │  └──────────────┘  └──────────────┘  └──────────────┘   │  │
│  │                                                              │  │
│  │  ┌──────────────────────────────────────────────────────┐  │  │
│  │  │  React Client                                        │  │  │
│  │  │  :3000                                               │  │  │
│  │  └──────────────────────────────────────────────────────┘  │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Port Forwarding (Skaffold)                             │  │
│  ├──────────────────────────────────────────────────────────┤  │
│  │  LocalHost:3000    → react-client:3000                  │  │
│  │  LocalHost:8080    → openwebui:8080                     │  │
│  │  LocalHost:4000    → litellm:4000                       │  │
│  │  LocalHost:7272    → r2r:7272                           │  │
│  │  LocalHost:6333    → qdrant:6333                        │  │
│  │  LocalHost:5432    → postgres:5432                      │  │
│  │  LocalHost:6379    → redis:6379                         │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## File Structure

```
llm-stack/
├── skaffold.yaml                      # Skaffold configuration
├── k8s/
│   ├── base/                          # Base Kubernetes manifests
│   │   ├── kustomization.yaml         # Base kustomization
│   │   ├── postgres-*.yaml            # PostgreSQL StatefulSet + ConfigMap + Service
│   │   ├── redis-*.yaml               # Redis StatefulSet + Service
│   │   ├── qdrant-*.yaml              # Qdrant Deployment + Service
│   │   ├── litellm-*.yaml             # LiteLLM Deployment + ConfigMap + Service
│   │   ├── r2r-*.yaml                 # R2R Deployment + Service
│   │   ├── openwebui-*.yaml           # OpenWebUI Deployment + Service
│   │   └── react-client-*.yaml        # React Client Deployment + Service
│   └── overlays/dev/                  # Development-specific overrides
│       ├── kustomization.yaml         # Dev kustomization with patches
│       └── deployment-patch.yaml      # Patch for local Docker images
├── scripts/
│   ├── minikube-start.sh              # Automated setup script
│   └── minikube-cleanup.sh            # Cleanup script
├── MINIKUBE_DEV_SETUP.md              # Detailed setup guide
├── MINIKUBE_QUICK_REFERENCE.md        # Quick reference for commands
└── KUBERNETES_DEPLOYMENT_OVERVIEW.md  # This file
```

## Key Configurations

### Skaffold Configuration (`skaffold.yaml`)

**Build Section:**
- Defines 5 service artifacts with Docker build context
- Configures image sync for hot reload on React Client and LiteLLM
- Uses `imagePullPolicy: IfNotPresent` for local development

**Deploy Section:**
- Uses `kubectl` for deployment
- Applies Kustomize overlays for dev environment
- Patch applies `imagePullPolicy: Never` to use local images

**Port Forwarding:**
- Automatically forwards local ports to service ports
- React Client: 3000→3000
- OpenWebUI: 8080→8080
- LiteLLM: 4000→4000
- R2R: 7272→7272
- Qdrant: 6333→6333
- PostgreSQL: 5432→5432
- Redis: 6379→6379

**Profiles:**
- `minikube` profile with Minikube context activation

### Kustomize Structure

**Base (`k8s/base/`):**
- Complete, production-ready manifests
- No environment-specific configurations
- Can be used for any Kubernetes cluster

**Overlay (`k8s/overlays/dev/`):**
- Development-specific patches and customizations
- Default secrets for local development
- Image pull policy set to `Never` (uses local Docker images)
- Service name prefix: `dev-`

### Service Manifests

Each service has up to 3 manifest files:

1. **Deployment/StatefulSet**: Pod specification, environment variables, resource limits, health checks
2. **Service**: Exposes the deployment within the cluster
3. **ConfigMap/Secret** (if needed): Configuration files or sensitive data

#### PostgreSQL (`postgres-*.yaml`)

- **StatefulSet**: Single replica with ordered pod names
- **Storage**: EmptyDir (not persistent in dev environment)
- **Secret**: Contains database password
- **Service**: Headless (ClusterIP: None) for StatefulSet
- **Environment Variables**:
  - `POSTGRES_USER`: postgres
  - `POSTGRES_PASSWORD`: postgres-dev-password-123
  - `POSTGRES_DB`: r2r_db

#### Redis (`redis-*.yaml`)

- **StatefulSet**: Single replica with RDB persistence enabled
- **Storage**: EmptyDir (not persistent in dev environment)
- **Service**: Headless for StatefulSet
- **Command**: Redis server with appendonly enabled
- **Port**: 6379

#### Qdrant (`qdrant-*.yaml`)

- **Deployment**: Single replica
- **Image**: Official Qdrant Docker image
- **Ports**: HTTP (6333) and gRPC (6334)
- **Environment Variables**:
  - `QDRANT__SERVICE__HTTP_PORT`: 6333
  - `QDRANT__SERVICE__GRPC_PORT`: 6334
- **Health Checks**: HTTP readiness probe on /readyz

#### LiteLLM (`litellm-*.yaml`)

- **Deployment**: Single replica
- **ConfigMap**: Configuration file with model definitions
- **Secret**: API keys (master key, OpenAI, Anthropic)
- **Port**: 4000
- **Environment Variables**:
  - `LITELLM_PORT`: 4000
  - `LITELLM_MASTER_KEY`: From secret
  - `OPENAI_API_KEY`: From secret (optional)
  - `ANTHROPIC_API_KEY`: From secret (optional)

#### R2R (`r2r-*.yaml`)

- **Deployment**: Single replica
- **Init Containers**: Wait for PostgreSQL and Qdrant to be ready
- **Port**: 7272
- **Environment Variables**:
  - `R2R_PORT`: 7272
  - `R2R_POSTGRES_*`: PostgreSQL connection details
  - `R2R_QDRANT_*`: Qdrant connection details
  - `REDIS_URL`: Redis connection string
- **Resource Limits**: Higher memory due to ML workloads

#### OpenWebUI (`openwebui-*.yaml`)

- **Deployment**: Single replica
- **Init Container**: Wait for LiteLLM to be ready
- **Port**: 8080
- **Environment Variables**:
  - `OPENAI_API_BASE_URL`: Points to LiteLLM service
  - `OPENAI_API_KEY`: LiteLLM master key
  - `WEBUI_AUTH`: Disabled for development

#### React Client (`react-client-*.yaml`)

- **Deployment**: Single replica
- **Port**: 3000 (nginx)
- **Environment Variables**:
  - `VITE_API_BASE_URL`: Points to OpenWebUI service
- **Smallest resource footprint** among services

## Startup Order and Dependencies

The deployment respects Kubernetes dependency ordering:

1. **Independent Services** (start in parallel):
   - PostgreSQL (via StatefulSet)
   - Redis (via StatefulSet)
   - Qdrant (via Deployment)
   - LiteLLM (via Deployment)

2. **Dependent Services**:
   - **R2R**: Waits for PostgreSQL and Qdrant via init containers
   - **OpenWebUI**: Waits for LiteLLM via init container
   - **React Client**: No dependencies, starts independently

Init containers use liveness probes to ensure dependencies are ready.

## Service Communication Patterns

### Inside Kubernetes (Pod to Pod)

Services use DNS names within the cluster:

```
postgres.default.svc.cluster.local:5432
redis.default.svc.cluster.local:6379
qdrant.default.svc.cluster.local:6333
litellm.default.svc.cluster.local:4000
openwebui.default.svc.cluster.local:8080
r2r.default.svc.cluster.local:7272
```

Or simplified (within default namespace):

```
postgres:5432
redis:6379
qdrant:6333
litellm:4000
openwebui:8080
r2r:7272
```

### Local Machine (via Port Forwarding)

When `skaffold dev --port-forward` is running:

```
localhost:5432    # PostgreSQL
localhost:6379    # Redis
localhost:6333    # Qdrant
localhost:4000    # LiteLLM
localhost:8080    # OpenWebUI
localhost:3000    # React Client
```

## Environment Variables Management

### Development Secrets

Default secrets created in `k8s/overlays/dev/kustomization.yaml`:

```yaml
secretGenerator:
  - name: litellm-secret
    literals:
      - master-key=sk-dev-master-key-12345678901234567890
      - openai-api-key=sk-proj-dev-key-test
      - anthropic-api-key=sk-ant-dev-key-test
```

### Updating Secrets

To use real API keys in development:

```bash
# Create new secret
kubectl create secret generic litellm-secret \
  --from-literal=master-key=<your-key> \
  --from-literal=openai-api-key=<your-key> \
  --from-literal=anthropic-api-key=<your-key> \
  --dry-run=client -o yaml | kubectl apply -f -

# Restart pods to pick up new secret
kubectl rollout restart deployment/litellm
kubectl rollout restart deployment/openwebui
```

## Resource Allocation

### Default Resource Requests and Limits

| Service | Requests (CPU/Memory) | Limits (CPU/Memory) | Notes |
|---------|----------------------|-------------------|-------|
| React Client | 100m/256Mi | 500m/512Mi | Frontend only |
| PostgreSQL | - | - | No limits in dev |
| Redis | 100m/256Mi | 500m/512Mi | Cache service |
| Qdrant | 250m/512Mi | 500m/1Gi | Vector database |
| LiteLLM | 250m/512Mi | 500m/1Gi | Proxy service |
| R2R | 500m/1Gi | 1000m/2Gi | ML workloads |
| OpenWebUI | 250m/512Mi | 500m/1Gi | Web UI |

### Total Cluster Requirements

- **CPU**: Minimum 4 cores recommended (for `skaffold dev`)
- **Memory**: Minimum 8GB recommended
- **Storage**: 20GB for Minikube

Recommended: 8 CPU, 16GB memory, 40GB storage

## Health Checks

### Liveness Probes

Detect if a container is still running and restart if not:

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 4000
  initialDelaySeconds: 30
  periodSeconds: 10
```

### Readiness Probes

Determine if a container is ready to receive traffic:

```yaml
readinessProbe:
  httpGet:
    path: /health
    port: 4000
  initialDelaySeconds: 10
  periodSeconds: 5
```

## Persistence

In the development environment, all storage is **non-persistent**:

- PostgreSQL data is stored in an `emptyDir` volume
- Redis data is stored in an `emptyDir` volume
- Data is lost when pods are deleted

### Enabling Persistence

To enable persistent volumes:

1. Replace `emptyDir: {}` with persistent volume claims:

```yaml
volumeClaimTemplates:
- metadata:
    name: postgres-data
  spec:
    accessModes: [ "ReadWriteOnce" ]
    resources:
      requests:
        storage: 20Gi
```

2. Redeploy the manifests:

```bash
kubectl apply -k k8s/overlays/dev
```

## Deployment Workflow

### Build Phase

Skaffold builds Docker images:

```
Dockerfile → Build image → Load into Minikube Docker
```

### Deploy Phase

Kustomize applies manifests with overlays:

```
k8s/base + k8s/overlays/dev → kubectl apply → Kubernetes
```

### Port Forward Phase

Skaffold establishes local port forwarding:

```
localhost:PORT ←→ cluster:SERVICE_PORT
```

### Watch Phase (Dev Mode)

Skaffold watches for changes:

```
File changes → Rebuild images → Redeploy → Update port forwarding
```

## Troubleshooting

### Images Not Building

```bash
# Check Docker environment
eval $(minikube docker-env)

# Verify images can be built
docker build -t test:latest .

# Build through Skaffold
skaffold build
```

### Pods Not Scheduling

```bash
# Check node resources
kubectl top nodes
kubectl describe nodes

# May need larger Minikube
minikube start --memory=12288 --cpus=6
```

### Service Communication Issues

```bash
# Test DNS resolution
kubectl run -it --rm debug --image=curlimages/curl:latest -- \
  nslookup litellm

# Test service connectivity
kubectl run -it --rm debug --image=curlimages/curl:latest -- \
  curl http://litellm:4000/health
```

### Database Connection Issues

```bash
# Check PostgreSQL is running
kubectl describe statefulset postgres

# Test connection
kubectl run -it --rm debug --image=postgres:15-alpine -- \
  psql -h postgres -U postgres -c "SELECT 1"
```

## Performance Considerations

1. **Image Layer Caching**: Larger images (R2R, OpenWebUI) benefit from caching
2. **Init Containers**: Wait for dependencies to reduce restart storms
3. **Resource Limits**: Prevent runaway processes from consuming all memory
4. **Readiness Probes**: Ensure traffic only goes to ready services
5. **StatefulSets**: Ordered pod creation for databases

## Security Notes

### Development Only

The default configuration includes:

- Hardcoded development secrets
- Disabled authentication (OpenWebUI)
- EmptyDir volumes (no persistence)
- ImagePullPolicy set to Never

**Do not use in production.**

### Production Deployment

For production, configure:

1. Use Secret Management (Vault, AWS Secrets Manager)
2. Enable authentication and authorization
3. Use persistent volumes with proper backups
4. Set appropriate ImagePullPolicy
5. Use private container registries
6. Implement network policies
7. Enable resource quotas and limits
8. Use read-only root filesystems where possible

## Additional Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Kustomize Documentation](https://kustomize.io/)
- [Skaffold Documentation](https://skaffold.dev/)
- [Docker in Kubernetes](https://kubernetes.io/docs/concepts/containers/docker/)
- [StatefulSets](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)

## Quick Commands

```bash
# Start everything
./scripts/minikube-start.sh

# Run Skaffold dev mode
skaffold dev --port-forward

# View all resources
kubectl get all

# View logs
kubectl logs -f deployment/<service>

# Execute command in pod
kubectl exec deployment/<service> -- <command>

# Clean up
./scripts/minikube-cleanup.sh
```

See [`MINIKUBE_QUICK_REFERENCE.md`](MINIKUBE_QUICK_REFERENCE.md) for more commands.
