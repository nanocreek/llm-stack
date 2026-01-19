# Minikube Development - Quick Reference

## One-Line Setup

```bash
chmod +x scripts/minikube-start.sh && ./scripts/minikube-start.sh
```

## Common Commands

### Start Development Environment

```bash
# Full setup with Minikube cluster
./scripts/minikube-start.sh

# Or manually:
minikube start --cpus=4 --memory=8192
eval $(minikube docker-env)
skaffold dev --port-forward
```

### View Services

```bash
# List all pods
kubectl get pods

# List all services
kubectl get svc

# View all resources
kubectl get all

# Watch real-time pod status
kubectl get pods --watch
```

### View Logs

```bash
# View logs for a specific pod
kubectl logs <pod-name>

# Stream logs (live)
kubectl logs -f <pod-name>

# View logs from specific container in multi-container pod
kubectl logs <pod-name> -c <container-name>

# View logs from all pods with a label
kubectl logs -l app=litellm --all-containers=true
```

### Access Services

```bash
# Port forward a specific service
kubectl port-forward svc/litellm 4000:4000

# Execute command in a pod
kubectl exec -it <pod-name> -- /bin/bash

# Get a shell in a pod
kubectl exec -it <pod-name> -- sh
```

### Debugging

```bash
# Describe a pod (shows events and status)
kubectl describe pod <pod-name>

# Get detailed pod information
kubectl get pod <pod-name> -o yaml

# Get node information
kubectl get nodes
kubectl describe node minikube

# Check resource usage
kubectl top pods
kubectl top nodes

# Get events
kubectl get events --sort-by='.lastTimestamp'
```

### Update Deployments

```bash
# Apply Kubernetes manifests
kubectl apply -k k8s/overlays/dev

# Scale a deployment
kubectl scale deployment/<name> --replicas=3

# Delete a resource
kubectl delete pod <pod-name>
kubectl delete deployment <deployment-name>

# Rollout status
kubectl rollout status deployment/<name>
kubectl rollout undo deployment/<name>
```

### Minikube Operations

```bash
# Check Minikube status
minikube status

# Stop Minikube (keeps cluster)
minikube stop

# Start a stopped Minikube
minikube start

# Delete Minikube cluster
minikube delete

# Access Minikube shell
minikube ssh

# Get IP address
minikube ip

# Dashboard
minikube dashboard

# Pause cluster
minikube pause
minikube unpause
```

### Docker in Minikube

```bash
# Configure Docker to use Minikube's daemon
eval $(minikube docker-env)

# Build images in Minikube
docker build -t llm-stack/litellm services/litellm/

# List images in Minikube
docker images

# Remove images
docker rmi <image-id>
```

## Service Access

Once port-forwarding is running via `skaffold dev --port-forward`:

| Service | Port | URL |
|---------|------|-----|
| React Client | 3000 | http://localhost:3000 |
| OpenWebUI | 8080 | http://localhost:8080 |
| LiteLLM | 4000 | http://localhost:4000 |
| R2R | 7272 | http://localhost:7272 |
| Qdrant | 6333 | http://localhost:6333 |
| PostgreSQL | 5432 | localhost:5432 |
| Redis | 6379 | localhost:6379 |

## Service Names in Kubernetes

Use these DNS names from within the cluster:

```
postgres.default.svc.cluster.local:5432
redis.default.svc.cluster.local:6379
qdrant.default.svc.cluster.local:6333
litellm.default.svc.cluster.local:4000
r2r.default.svc.cluster.local:7272
openwebui.default.svc.cluster.local:8080
react-client.default.svc.cluster.local:3000
```

Or simply (from within same namespace):

```
postgres:5432
redis:6379
qdrant:6333
litellm:4000
r2r:7272
openwebui:8080
react-client:3000
```

## File Structure

```
llm-stack/
├── skaffold.yaml                 # Skaffold configuration
├── k8s/
│   ├── base/                     # Base Kubernetes manifests
│   │   ├── kustomization.yaml
│   │   ├── postgres-*.yaml
│   │   ├── redis-*.yaml
│   │   ├── qdrant-*.yaml
│   │   ├── litellm-*.yaml
│   │   ├── r2r-*.yaml
│   │   ├── openwebui-*.yaml
│   │   └── react-client-*.yaml
│   └── overlays/dev/             # Development overrides
│       ├── kustomization.yaml
│       └── deployment-patch.yaml
├── scripts/
│   ├── minikube-start.sh         # Setup automation
│   └── minikube-cleanup.sh       # Cleanup automation
├── MINIKUBE_DEV_SETUP.md         # Detailed guide
└── MINIKUBE_QUICK_REFERENCE.md   # This file
```

## Troubleshooting

### "No space left on device"

```bash
minikube delete
minikube start --disk-size=50000
```

### "ImagePullBackOff" error

```bash
# Make sure images are built
eval $(minikube docker-env)
skaffold build

# Or check if image exists
docker images | grep llm-stack
```

### Pod stuck in "Pending"

```bash
# Check resource availability
kubectl describe pod <pod-name>
kubectl top nodes

# May need to increase memory
minikube stop
minikube start --memory=12288
```

### "Connection refused" to service

```bash
# Check if service is running
kubectl get svc <service-name>

# Check pod readiness
kubectl get pods
kubectl describe pod <pod-name>

# Check logs
kubectl logs <pod-name>
```

### Database connection errors

```bash
# Check if PostgreSQL is running
kubectl logs -f statefulset/postgres

# Test connectivity from pod
kubectl run -it --rm debug --image=postgres:15-alpine -- \
  psql -h postgres -U postgres -d postgres -c "SELECT 1"
```

## Clean Up

```bash
# Stop port-forwarding and deployment watching
# (Press Ctrl+C in the skaffold dev terminal)

# Delete deployments
./scripts/minikube-cleanup.sh

# Or manually
kubectl delete -k k8s/overlays/dev
```

## Performance Tips

1. **Increase Minikube resources** for faster builds:
   ```bash
   minikube start --cpus=8 --memory=16384 --disk-size=40000
   ```

2. **Use `skaffold debug`** for interactive debugging:
   ```bash
   skaffold debug --port-forward
   ```

3. **Enable Docker layer caching** by keeping Minikube running between sessions

4. **Monitor resource usage**:
   ```bash
   watch -n 1 'kubectl top pods && echo "---" && kubectl top nodes'
   ```

## Development Workflow

1. **Start development**:
   ```bash
   skaffold dev --port-forward
   ```

2. **Make code changes** in your editor

3. **Skaffold automatically**:
   - Detects changes
   - Rebuilds Docker images
   - Redeploys to Kubernetes
   - Syncs files (for supported services)

4. **View output**:
   ```bash
   kubectl logs -f deployment/<service>
   ```

5. **Stop and cleanup**:
   ```bash
   Ctrl+C in skaffold terminal
   ./scripts/minikube-cleanup.sh
   ```

## Advanced Usage

### Debug a specific service

```bash
# Get interactive shell
kubectl exec -it deployment/litellm -- /bin/bash

# Run a command
kubectl exec deployment/litellm -- litellm --help

# Stream output
kubectl logs -f deployment/litellm
```

### Test service-to-service communication

```bash
# Run a debug pod
kubectl run -it --rm debug --image=curlimages/curl:latest -- sh

# Inside the debug pod:
curl http://litellm:4000/health
curl http://postgres:5432  # Won't connect but shows DNS works
```

### Capture traffic for debugging

```bash
# Start tcpdump in a pod
kubectl exec deployment/r2r -- tcpdump -i any -w /tmp/dump.pcap

# Copy the file locally
kubectl cp deployment/r2r:/tmp/dump.pcap ./dump.pcap

# Analyze with Wireshark
wireshark dump.pcap
```

## Resources

- [Minikube Documentation](https://minikube.sigs.k8s.io/)
- [Kubernetes Concepts](https://kubernetes.io/docs/concepts/)
- [Skaffold Documentation](https://skaffold.dev/docs/)
- [Kustomize Reference](https://kustomize.io/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)

## Full Setup Guide

For detailed information, see [`MINIKUBE_DEV_SETUP.md`](MINIKUBE_DEV_SETUP.md)
