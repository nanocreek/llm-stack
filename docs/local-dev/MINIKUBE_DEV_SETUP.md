# Local Development Setup with Minikube and Skaffold

This guide provides instructions for running the LLM Stack locally using Minikube (Kubernetes) and Skaffold for development.

## Prerequisites

Before you begin, ensure you have the following installed:

### Required Tools

1. **Docker** - For building container images
   ```bash
   # Verify Docker installation
   docker --version
   ```

2. **Minikube** - Local Kubernetes cluster
   ```bash
   # Install Minikube: https://minikube.sigs.k8s.io/docs/start/
   minikube version
   ```

3. **kubectl** - Kubernetes command-line tool
   ```bash
   # Verify kubectl installation
   kubectl version --client
   ```

4. **Skaffold** - Development tool for building and deploying applications
   ```bash
   # Install Skaffold: https://skaffold.dev/docs/install/
   skaffold version
   ```

### Optional Tools

- **Helm** - Package manager for Kubernetes (not required but useful)
- **kubectx** - Tool for switching Kubernetes contexts

## Quick Start

### 1. Start Minikube

```bash
# Start a new Minikube cluster
minikube start --cpus=4 --memory=8192

# Verify cluster is running
minikube status

# Set Docker environment to use Minikube's Docker daemon
eval $(minikube docker-env)
```

### 2. Deploy with Skaffold

```bash
# Navigate to the project directory
cd /path/to/llm-stack

# Run Skaffold in development mode
skaffold dev --port-forward

# Or, for one-time deployment (without continuous watch):
skaffold run
```

**Skaffold will:**
- Build Docker images for all services using Minikube's Docker daemon
- Apply Kubernetes manifests (via Kustomize overlays)
- Set up port forwarding to access services locally
- Watch for file changes and rebuild/redeploy automatically (in `dev` mode)

### 3. Access Services

Once services are running, they're accessible via port forwarding:

| Service | Local Port | URL |
|---------|-----------|-----|
| React Client | 3000 | `http://localhost:3000` |
| OpenWebUI | 8080 | `http://localhost:8080` |
| LiteLLM | 4000 | `http://localhost:4000` |
| R2R | 7272 | `http://localhost:7272` |
| Qdrant | 6333 | `http://localhost:6333` |
| PostgreSQL | 5432 | `localhost:5432` |
| Redis | 6379 | `localhost:6379` |

### 4. Verify Deployment

```bash
# Check all resources
kubectl get all -n default

# View pod status
kubectl get pods -n default

# Check service status
kubectl get svc -n default

# View logs for a specific service
kubectl logs -f deployment/litellm -n default
```

## Configuration

### Environment Variables

The development environment comes with default configuration. To override variables, create a `.env.local` file in your project root:

```bash
# .env.local
LITELLM_MASTER_KEY=your-custom-master-key
OPENAI_API_KEY=sk-proj-your-openai-key
ANTHROPIC_API_KEY=sk-ant-your-anthropic-key
```

To apply these to the deployment:

```bash
# Update secrets manually
kubectl create secret generic litellm-secret \
  --from-literal=master-key=your-custom-master-key \
  --from-literal=openai-api-key=sk-proj-your-openai-key \
  --from-literal=anthropic-api-key=sk-ant-your-anthropic-key \
  --dry-run=client -o yaml | kubectl apply -f -
```

### Service Communication

Services communicate using Kubernetes service names as DNS:

- **React Client** → **OpenWebUI**: `http://openwebui:8080`
- **OpenWebUI** → **LiteLLM**: `http://litellm:4000/v1`
- **R2R** → **Qdrant**: `http://qdrant:6333`
- **R2R** → **PostgreSQL**: `postgres:5432`
- **R2R** → **Redis**: `redis:6379`

## Common Development Tasks

### Rebuild All Services

```bash
# Force rebuild of all images
skaffold build --file-output build.json
```

### View Real-time Logs

```bash
# Stream logs from all pods
kubectl logs -f -l app.kubernetes.io/part-of=llm-stack --all-containers=true

# Or for a specific service
kubectl logs -f deployment/r2r
```

### Access Service Shell

```bash
# Get shell access to a pod
kubectl exec -it deployment/litellm -- /bin/bash

# For containers without bash (Alpine images)
kubectl exec -it deployment/qdrant -- /bin/sh
```

### Port Forward Manually

```bash
# If skaffold is not running
kubectl port-forward svc/openwebui 8080:8080
kubectl port-forward svc/react-client 3000:3000
kubectl port-forward svc/litellm 4000:4000
```

### Update Deployment

```bash
# Apply changes to Kubernetes manifests without rebuilding images
kubectl apply -k k8s/overlays/dev

# Or use Kustomize directly
kustomize build k8s/overlays/dev | kubectl apply -f -
```

## Persistence

### Database Persistence

- **PostgreSQL**: Data is stored in `postgres-data` volume (not persistent in dev, destroyed on pod restart)
- **Redis**: Data is stored in `redis-data` volume (not persistent in dev, destroyed on pod restart)

To enable persistent volumes:

1. Edit `k8s/base/postgres-statefulset.yaml` and `k8s/base/redis-statefulset.yaml`
2. Replace `emptyDir: {}` with a persistent volume claim
3. Redeploy the manifests

## Troubleshooting

### Pods Not Starting

```bash
# Check pod events and status
kubectl describe pod <pod-name>

# View pod logs
kubectl logs <pod-name>

# Check resource requests vs available resources
kubectl top nodes
kubectl top pods
```

### Image Pull Errors

```bash
# Ensure Docker images are built
eval $(minikube docker-env)
skaffold build

# Or manually rebuild an image
docker build -t llm-stack/litellm:latest services/litellm/
```

### Service Communication Issues

```bash
# Test connectivity between pods
kubectl run -it --rm debug --image=curlimages/curl:latest -- sh

# From the debug pod, test a service
curl http://litellm:4000/health
curl http://postgres:5432 (will fail but shows connectivity)
```

### Minikube Memory Issues

```bash
# Check Minikube resource allocation
minikube status

# Increase memory if needed
minikube delete
minikube start --cpus=4 --memory=12288

# Or scale down services
kubectl scale deployment litellm --replicas=0
```

## Advanced Usage

### Custom Skaffold Configuration

The `skaffold.yaml` file can be customized:

```bash
# Use a specific context
skaffold dev --kubecontext=minikube

# Tail logs for specific services
skaffold dev --cleanup=false
```

### Docker Registry (for multi-node clusters)

For production-like testing with multiple nodes:

```bash
# Use a Docker registry instead of local Docker daemon
skaffold config set default-repo=localhost:5000
minikube addons enable registry
minikube addons enable registry-creds
```

### Network Policies

If you need to test network policies, create them in `k8s/base/network-policies.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-litellm
spec:
  podSelector:
    matchLabels:
      app: litellm
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: openwebui
```

## Cleanup

### Stop Skaffold

```bash
# Press Ctrl+C to stop skaffold dev
# Or run:
skaffold delete
```

### Delete Minikube Cluster

```bash
# Stop Minikube
minikube stop

# Delete the cluster entirely
minikube delete
```

### Free Up Resources

```bash
# If you want to keep the cluster but free resources
minikube pause
minikube unpause  # to resume
```

## Performance Optimization

### Docker Image Size

The build output is optimized with multi-stage builds:

- React Client: ~50MB (nginx + built app)
- LiteLLM: ~150MB (Python image + dependencies)
- R2R: ~400MB (Python image + full R2R framework)
- Qdrant: ~200MB (Qdrant official image)
- OpenWebUI: ~600MB (OpenWebUI official image)

### Build Caching

Skaffold caches images in Minikube's Docker daemon. To force a clean rebuild:

```bash
minikube docker-env  # Set up Docker environment
docker rmi <image-name>  # Remove image
skaffold build  # Rebuild
```

## Integration with IDEs

### VS Code

1. Install the "Kubernetes" extension
2. Install the "Skaffold" extension
3. The cluster will appear in the Kubernetes sidebar
4. Right-click on pods to view logs and execute commands

### IntelliJ IDEA

1. Install the "Kubernetes" plugin
2. Configure Minikube as the Kubernetes cluster
3. Use the "Services" tool window to view logs

## Next Steps

- Review [`README.md`](README.md) for project overview
- Check [`DEPLOYMENT.md`](DEPLOYMENT.md) for Railway deployment guide
- Explore individual service [`README.md`](services/litellm/README.md) files for service-specific documentation
