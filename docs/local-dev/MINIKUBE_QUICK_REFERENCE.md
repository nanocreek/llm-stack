# Minikube Development - Quick Reference

## One-Line Setup

```bash
# Start Minikube with recommended resources
minikube start --cpus=2 --memory=4096

# Deploy the stack
kubectl apply -f k8s/manifests.yaml

# Port forward LiteLLM
kubectl port-forward svc/litellm 4000:4000 -n llm-stack
```

## Common Commands

### Start Development Environment

```bash
# Start Minikube cluster
minikube start --cpus=2 --memory=4096 --disk-size=20000

# Deploy all services
kubectl apply -f k8s/manifests.yaml

# Wait for services to be ready
kubectl wait --for=condition=ready pod -l app=postgres -n llm-stack --timeout=120s
kubectl wait --for=condition=ready pod -l app=redis -n llm-stack --timeout=120s
kubectl wait --for=condition=ready pod -l app=litellm -n llm-stack --timeout=120s

# Port forward LiteLLM
kubectl port-forward svc/litellm 4000:4000 -n llm-stack
```

### View Services

```bash
# List all pods in the llm-stack namespace
kubectl get pods -n llm-stack

# List all services in the llm-stack namespace
kubectl get svc -n llm-stack

# View all resources in the llm-stack namespace
kubectl get all -n llm-stack

# Watch real-time pod status
kubectl get pods -n llm-stack --watch
```

### View Logs

```bash
# View logs for a specific pod
kubectl logs <pod-name> -n llm-stack

# Stream logs (live)
kubectl logs -f <pod-name> -n llm-stack

# View logs from all pods with a label
kubectl logs -f -l app=litellm -n llm-stack
```

### Access Services

```bash
# Port forward LiteLLM to localhost
kubectl port-forward svc/litellm 4000:4000 -n llm-stack

# Port forward PostgreSQL to localhost
kubectl port-forward svc/postgres 5432:5432 -n llm-stack

# Port forward Redis to localhost
kubectl port-forward svc/redis 6379:6379 -n llm-stack

# Execute command in a pod
kubectl exec -it <pod-name> -n llm-stack -- /bin/bash

# Get a shell in a pod
kubectl exec -it <pod-name> -n llm-stack -- sh
```

### Debugging

```bash
# Describe a pod (shows events and status)
kubectl describe pod <pod-name> -n llm-stack

# Get detailed pod information
kubectl get pod <pod-name> -n llm-stack -o yaml

# Get node information
kubectl get nodes
kubectl describe node minikube

# Check resource usage
kubectl top pods -n llm-stack
kubectl top nodes

# Get events
kubectl get events -n llm-stack --sort-by='.lastTimestamp'
```

### Update Deployments

```bash
# Apply Kubernetes manifests
kubectl apply -f k8s/manifests.yaml

# Delete a pod (will be recreated)
kubectl delete pod <pod-name> -n llm-stack

# Scale LiteLLM deployment
kubectl scale deployment/litellm --replicas=2 -n llm-stack

# Rollout status
kubectl rollout status deployment/litellm -n llm-stack
kubectl rollout undo deployment/litellm -n llm-stack
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

## Service Access

Once port-forwarding is running:

| Service | Port | URL |
|---------|------|-----|
| LiteLLM | 4000 | http://localhost:4000 |
| PostgreSQL | 5432 | localhost:5432 |
| Redis | 6379 | localhost:6379 |

## Service Names in Kubernetes

Use these DNS names from within the cluster:

```
postgres.llm-stack.svc.cluster.local:5432
redis.llm-stack.svc.cluster.local:6379
litellm.llm-stack.svc.cluster.local:4000
```

Or simply (from within same namespace):

```
postgres:5432
redis:6379
litellm:4000
```

## File Structure

```
llm-stack/
├── k8s/
│   ├── manifests.yaml            # All-in-one Kubernetes manifest
│   └── base/                     # Individual Kubernetes manifests
│       ├── kustomization.yaml
│       ├── namespace.yaml
│       ├── litellm-*.yaml
│       ├── postgres-*.yaml
│       └── redis-*.yaml
├── docs/local-dev/
│   └── README.md                 # Local development guide
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
# Check pod description for details
kubectl describe pod <pod-name> -n llm-stack

# Check if images are available
docker images
```

### Pod stuck in "Pending"

```bash
# Check resource availability
kubectl describe pod <pod-name> -n llm-stack
kubectl top nodes

# May need to increase memory
minikube stop
minikube start --memory=6144
```

### "Connection refused" to service

```bash
# Check if service is running
kubectl get svc <service-name> -n llm-stack

# Check pod readiness
kubectl get pods -n llm-stack
kubectl describe pod <pod-name> -n llm-stack

# Check logs
kubectl logs <pod-name> -n llm-stack
```

### Database connection errors

```bash
# Check if PostgreSQL is running
kubectl logs -f statefulset/postgres -n llm-stack

# Test connectivity from pod
kubectl run -it --rm debug --image=postgres:16-alpine -n llm-stack -- \
  psql -h postgres -U postgres -d litellm -c "SELECT 1"
```

## Clean Up

```bash
# Stop port-forwarding (press Ctrl+C in the port-forward terminal)

# Delete all resources
kubectl delete -f k8s/manifests.yaml

# Delete Minikube cluster
minikube delete
```

## Performance Tips

1. **Increase Minikube resources** for better performance:
   ```bash
   minikube start --cpus=4 --memory=6144 --disk-size=40000
   ```

2. **Enable Docker layer caching** by keeping Minikube running between sessions

3. **Monitor resource usage**:
   ```bash
   watch -n 1 'kubectl top pods -n llm-stack'
   ```

## Development Workflow

1. **Start development**:
   ```bash
   minikube start
   kubectl apply -f k8s/manifests.yaml
   kubectl port-forward svc/litellm 4000:4000 -n llm-stack
   ```

2. **Make code changes** in your editor

3. **Redeploy**:
   ```bash
   kubectl apply -f k8s/manifests.yaml
   ```

4. **View output**:
   ```bash
   kubectl logs -f deployment/litellm -n llm-stack
   ```

5. **Stop and cleanup**:
   ```bash
   # Stop port-forward (Ctrl+C)
   kubectl delete -f k8s/manifests.yaml
   minikube delete
   ```

## Advanced Usage

### Debug a specific service

```bash
# Get interactive shell
kubectl exec -it deployment/litellm -n llm-stack -- /bin/bash

# Run a command
kubectl exec deployment/litellm -n llm-stack -- litellm --help

# Stream output
kubectl logs -f deployment/litellm -n llm-stack
```

### Test service-to-service communication

```bash
# Run a debug pod
kubectl run -it --rm debug --image=curlimages/curl:latest -n llm-stack -- sh

# Inside the debug pod:
curl http://litellm:4000/health
curl http://postgres:5432  # Won't connect but shows DNS works
```

## Resources

- [Minikube Documentation](https://minikube.sigs.k8s.io/)
- [Kubernetes Concepts](https://kubernetes.io/docs/concepts/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)

## Full Setup Guide

For detailed information, see [`docs/local-dev/README.md`](docs/local-dev/README.md)
