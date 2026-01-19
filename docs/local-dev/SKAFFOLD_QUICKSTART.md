# Skaffold + Minikube Quick Start Guide

## Prerequisites

Install the following tools:

1. **Minikube**: https://minikube.sigs.k8s.io/docs/start/
2. **kubectl**: https://kubernetes.io/docs/tasks/tools/
3. **Docker**: https://docs.docker.com/get-docker/
4. **Skaffold**: https://skaffold.dev/docs/install/

Verify installations:

```bash
minikube version
kubectl version --client
docker --version
skaffold version
```

## One-Command Setup

```bash
# Start Minikube cluster
minikube start --cpus=4 --memory=8192

# Set Docker to use Minikube's daemon
eval $(minikube docker-env)

# Run Skaffold in dev mode (auto-builds, deploys, and watches files)
skaffold dev --port-forward
```

That's it! Services will be accessible at:

- **React Client**: http://localhost:3000
- **OpenWebUI**: http://localhost:8080  
- **LiteLLM**: http://localhost:4000
- **R2R**: http://localhost:7272
- **Qdrant**: http://localhost:6333
- **PostgreSQL**: localhost:5432
- **Redis**: localhost:6379

## What Skaffold Does

When you run `skaffold dev --port-forward`:

1. **Builds** Docker images for all services
2. **Deploys** them to Minikube using Kustomize overlays
3. **Forwards** local ports to service ports in the cluster
4. **Watches** your code files and rebuilds/redeploys automatically on changes
5. **Streams** logs from all containers to your terminal

## Useful Commands

```bash
# View all pods
kubectl get pods

# View logs for a specific service
kubectl logs -f deployment/dev-litellm

# Execute command in a pod
kubectl exec -it deployment/dev-litellm -- /bin/sh

# Port forward manually
kubectl port-forward svc/dev-openwebui 8080:8080

# Delete all resources
kubectl delete -k k8s/overlays/dev

# Stop Minikube
minikube stop

# Delete Minikube cluster
minikube delete
```

## Configuration

### Environment Variables

Default secrets are defined in [`k8s/overlays/dev/kustomization.yaml`](k8s/overlays/dev/kustomization.yaml):

```yaml
secretGenerator:
  - name: litellm-secret
    literals:
      - master-key=sk-dev-master-key-12345678901234567890
      - openai-api-key=sk-proj-dev-key-test
      - anthropic-api-key=sk-ant-dev-key-test
```

To use real API keys, update these values or create a secret:

```bash
kubectl create secret generic litellm-secret \
  --from-literal=master-key=your-key \
  --from-literal=openai-api-key=your-key \
  --from-literal=anthropic-api-key=your-key \
  --dry-run=client -o yaml | kubectl apply -f -
```

## File Structure

```
k8s/
├── base/                   # Base Kubernetes manifests (production-ready)
│   ├── *-deployment.yaml
│   ├── *-service.yaml
│   ├── *-configmap.yaml
│   └── ...
└── overlays/dev/           # Development overrides
    └── kustomization.yaml  # Patches, secrets, labels for dev

skaffold.yaml              # Skaffold build and deploy config
kustomization.yaml         # Root kustomization file
```

## Troubleshooting

### Pods not starting

```bash
# Check pod status and events
kubectl describe pod <pod-name>

# View logs
kubectl logs <pod-name>

# Increase Minikube resources
minikube delete
minikube start --cpus=8 --memory=12288
```

### Image pull errors

```bash
# Set Docker environment for Minikube
eval $(minikube docker-env)

# Rebuild images
skaffold build
```

### Port forwarding not working

```bash
# Make sure skaffold is still running
# Press Ctrl+C to see if skaffold stopped

# Or manually forward ports
kubectl port-forward svc/dev-react-client 3000:3000 &
kubectl port-forward svc/dev-openwebui 8080:8080 &
```

## Next Steps

- Read [`MINIKUBE_DEV_SETUP.md`](MINIKUBE_DEV_SETUP.md) for detailed documentation
- Check [`KUBERNETES_DEPLOYMENT_OVERVIEW.md`](KUBERNETES_DEPLOYMENT_OVERVIEW.md) for architecture details
- See [`MINIKUBE_QUICK_REFERENCE.md`](MINIKUBE_QUICK_REFERENCE.md) for command reference

## More Information

- [Skaffold Documentation](https://skaffold.dev/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Kustomize Documentation](https://kustomize.io/)
- [Minikube Documentation](https://minikube.sigs.k8s.io/)
