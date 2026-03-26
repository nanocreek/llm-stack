# Local Development Guide

⚙️ **Alternative Deployment Option** - This guide covers running the LiteLLM Stack locally using Kubernetes (Minikube). For most users, we recommend the simpler [Railway deployment](../../README.md#-quick-start---railway-deployment).

## Overview

This documentation covers **local development** using Minikube and Kubernetes. While Railway provides automated deployment with managed infrastructure, local development gives you complete control and operates entirely on your machine.

**Primary Deployment Method:** [Railway Deployment](../../QUICK_START_RAILWAY.md) - One-click deployment with managed services  
**Alternative Method (You Are Here):** Local Kubernetes development with Minikube

---

## Why Choose Local Development?

### ✅ Use Local Development When You Want To:

- **Deep Customization** - Modify service configurations, add custom services, or experiment with alternative architectures
- **Pre-Deployment Testing** - Test changes in a Kubernetes environment before deploying to production
- **Offline Development** - Work without internet connectivity after initial setup
- **Learning Kubernetes** - Gain hands-on experience with Kubernetes concepts and workflows
- **Cost Considerations** - Run entirely on your own hardware without cloud costs
- **Privacy & Security** - Keep all data and API keys on your local machine

### ⚠️ When Railway Might Be Better:

- **Quick Start** - Railway deploys in 5 minutes vs 30+ minutes for local setup
- **Managed Infrastructure** - No need to manage PostgreSQL, Redis, or resource allocation
- **Production-Ready** - Railway provides SSL, monitoring, and automatic scaling
- **Team Collaboration** - Share environments easily with public URLs
- **No Local Resources** - Avoid using your machine's CPU/RAM for services
- **Simplicity** - Less complexity than managing Kubernetes locally

**Most users should start with Railway** and only move to local development if they need the features above.

---

## Prerequisites

### Required Tools

You **must** have these installed before proceeding:

| Tool | Version | Purpose | Installation Link |
|------|---------|---------|------------------|
| **Docker Desktop** | 20.10+ | Container runtime for building images | [Install Docker](https://docs.docker.com/get-docker/) |
| **Minikube** | 1.30+ | Local Kubernetes cluster | [Install Minikube](https://minikube.sigs.k8s.io/docs/start/) |
| **kubectl** | 1.24+ | Kubernetes command-line tool | [Install kubectl](https://kubernetes.io/docs/tasks/tools/) |

**Optional but Recommended:**
- **kubectx** - For switching between Kubernetes contexts [Install kubectx](https://github.com/ahmetb/kubectx)

### System Requirements

**Minimum Requirements:**
- **CPU**: 2 cores
- **RAM**: 4 GB available for Minikube
- **Disk**: 10 GB free space
- **OS**: macOS, Linux, or Windows 10/11 with WSL2

**Recommended for Optimal Performance:**
- **CPU**: 4 cores
- **RAM**: 8 GB (allocate 6 GB to Minikube)
- **Disk**: 20 GB SSD free space

### Verify Your Installation

Run these commands to confirm everything is installed:

```bash
# Check Docker
docker --version
# Expected: Docker version 20.10.0 or higher

# Check Minikube
minikube version
# Expected: minikube version: v1.30.0 or higher

# Check kubectl
kubectl version --client
# Expected: Client Version: v1.24.0 or higher
```

If any command fails, follow the installation links in the table above.

---

## Quick Start

Get the stack running locally in 20 minutes or less.

### Step 1: Install Prerequisites

Ensure all tools from the [Prerequisites](#prerequisites) section are installed and verified.

### Step 2: Clone the Repository

```bash
# Clone the repository
git clone https://github.com/nanocreek/llm-stack.git
cd llm-stack
```

### Step 3: Start Minikube

```bash
# Start Minikube with recommended resources
minikube start --cpus=2 --memory=4096 --disk-size=20000

# Verify cluster is running
minikube status
```

**What this does:**
- Creates a local Kubernetes cluster in a VM
- Allocates 2 CPU cores and 4GB RAM
- Configures your shell to build images directly in Minikube

**Troubleshooting:** If `minikube start` fails, try increasing resources or using a different driver:
```bash
minikube start --cpus=4 --memory=6144 --driver=docker
```

### Step 4: Deploy with kubectl

```bash
# Deploy all services
kubectl apply -f k8s/manifests.yaml

# Wait for deployments to be ready
kubectl wait --for=condition=ready pod -l app=postgres --timeout=120s
kubectl wait --for=condition=ready pod -l app=redis --timeout=120s
kubectl wait --for=condition=ready pod -l app=litellm --timeout=120s
```

**What this does:**
1. ⚡ Creates namespace and ConfigMaps
2. 📦 Deploys PostgreSQL, Redis, and LiteLLM services
3. 🔌 Sets up internal networking

**Expected output:**
```
namespace/llm-stack created
configmap/litellm-config created
secret/postgres-secret created
configmap/postgres-config created
secret/litellm-secret created
persistentvolumeclaim/postgres-data created
persistentvolumeclaim/redis-data created
statefulset.apps/postgres created
statefulset.apps/redis created
service/postgres created
service/redis created
service/litellm created
deployment.apps/litellm created
```

⏱️ **First-time deployment:** 5-10 minutes (downloading images)

### Step 5: Access Services

Once deployment completes, set up port forwarding to access services:

```bash
# Port forward LiteLLM (run in a separate terminal)
kubectl port-forward svc/litellm 4000:4000 -n llm-stack
```

| Service | Local URL | Description |
|---------|-----------|-------------|
| **LiteLLM** | http://localhost:4000 | LLM proxy API |
| **PostgreSQL** | localhost:5432 | Database (use psql or pgAdmin) |
| **Redis** | localhost:6379 | Cache (use redis-cli) |

**Start here:** Test LiteLLM health endpoint:
```bash
curl http://localhost:4000/health
```

### Step 6: Verify Everything Works

```bash
# Check all pods are running
kubectl get pods -n llm-stack

# You should see all pods in "Running" state:
# NAME                          READY   STATUS    RESTARTS   AGE
# litellm-xxx                   1/1     Running   0          5m
# postgres-0                    1/1     Running   0          5m
# redis-0                       1/1     Running   0          5m

# Test a service
curl http://localhost:4000/health
# Expected: {"status":"healthy"}
```

**If pods are not running:** See [Troubleshooting](#troubleshooting) section below.

---

## Common Development Tasks

### Starting the Environment

```bash
# Start Minikube (if not running)
minikube start

# Deploy all services
kubectl apply -f k8s/manifests.yaml

# Port forward LiteLLM
kubectl port-forward svc/litellm 4000:4000 -n llm-stack
```

### Stopping the Environment

```bash
# Stop port forwarding (press Ctrl+C in the port-forward terminal)

# Stop Minikube (keeps the cluster)
minikube stop

# Or delete the cluster entirely (frees resources)
minikube delete
```

### Viewing Logs

```bash
# Stream logs from all services
kubectl logs -f -l app.kubernetes.io/part-of=llm-stack -n llm-stack --all-containers

# Stream logs from a specific service
kubectl logs -f deployment/litellm -n llm-stack

# View recent logs (no streaming)
kubectl logs deployment/litellm -n llm-stack --tail=100
```

**Pro tip:** Use `stern` for advanced log viewing: `stern '.*' -n llm-stack`

### Making Code Changes and Testing

1. Edit configuration files (e.g., `services/litellm/config.yaml`)
2. Reapply the manifests:
   ```bash
   kubectl apply -f k8s/manifests.yaml
   ```
3. Check logs to verify changes

### Resetting the Environment

**Soft reset (keep cluster, rebuild services):**
```bash
# Delete deployments
kubectl delete -f k8s/manifests.yaml

# Redeploy
kubectl apply -f k8s/manifests.yaml
```

**Hard reset (delete everything):**
```bash
# Delete Minikube cluster
minikube delete

# Start fresh
minikube start --cpus=2 --memory=4096
kubectl apply -f k8s/manifests.yaml
```

---

## Troubleshooting

### Pod won't start:
```bash
# Check pod status
kubectl describe pod <pod-name> -n llm-stack

# View pod logs
kubectl logs <pod-name> -n llm-stack

# Check resource usage
kubectl top nodes
kubectl top pods -n llm-stack
```

### Connection errors between services:
```bash
# Test DNS resolution
kubectl run -it --rm debug --image=curlimages/curl -n llm-stack -- nslookup litellm

# Test connectivity
kubectl run -it --rm debug --image=curlimages/curl -n llm-stack -- curl http://litellm:4000/health
```

### Out of memory:
```bash
# Increase Minikube memory
minikube delete
minikube start --memory=6144
```

### Configuration Issues:
1. Verify ConfigMaps are correct: `kubectl get configmaps -n llm-stack`
2. Check environment variables: `kubectl describe deployment/litellm -n llm-stack`
3. Ensure secrets are set: `kubectl get secrets -n llm-stack`

---

## Differences from Railway Deployment

Understanding key differences helps you work effectively in both environments.

| Aspect | Local Development (Minikube) | Railway Deployment |
|--------|------------------------------|-------------------|
| **Setup Time** | 20+ minutes (initial setup) | 5 minutes (one-click) |
| **Infrastructure** | Manual configuration of all services | Fully managed (PostgreSQL, Redis) |
| **Networking** | Manual port forwarding to localhost | Automatic public URLs with SSL |
| **Database Storage** | PVC (persistent) | Managed, persistent databases |
| **Environment Variables** | Manual configuration in manifests | Template-based, auto-configured |
| **Resource Limits** | Limited by your machine (4-8GB RAM) | Scalable, Railway manages resources |
| **Cost** | Free (uses your hardware) | Paid (based on resource usage) |
| **Complexity** | Medium (Kubernetes knowledge) | Low (Railway abstracts complexity) |
| **Internet Required** | Only for initial image downloads | Yes, for deployment and access |
| **Team Collaboration** | Difficult (local only) | Easy (shared URLs) |
| **Production Use** | Not recommended | Production-ready |

### Development-Friendly Features (Local Only)

**✅ Full Control:**
- Modify any Kubernetes manifest
- Add custom services easily
- Experiment with resource limits

**✅ Debugging:**
- Direct shell access to containers
- Local log files
- Network traffic inspection

### Railway-Specific Features (Not Available Locally)

**❌ Managed Services:**
- No need to configure PostgreSQL replication
- No Redis persistence setup required
- Automatic backups

**❌ Public URLs:**
- Railway generates HTTPS endpoints automatically
- Local dev requires port forwarding

**❌ Production Features:**
- SSL certificates
- Automatic health monitoring
- Resource auto-scaling

**Recommendation:** Use local development for testing and experimentation. Deploy to Railway for production workloads.

---

## Getting Help

### Documentation Resources

**Local Development:**
- [`docs/architecture/OVERVIEW.md`](../architecture/OVERVIEW.md) - Architecture and service details
- [`docs/architecture/SERVICE_COMMUNICATION.md`](../architecture/SERVICE_COMMUNICATION.md) - Service communication patterns

**General Documentation:**
- [`../../README.md`](../../README.md) - Project overview and Railway deployment
- [`../../QUICK_START_RAILWAY.md`](../../QUICK_START_RAILWAY.md) - Railway quick start guide
- [`../../ENV_VARIABLES_GUIDE.md`](../../ENV_VARIABLES_GUIDE.md) - Environment variable reference

**Service-Specific:**
- [`../../services/litellm/README.md`](../../services/litellm/README.md) - LiteLLM configuration
- [`../../services/postgres-pgvector/README.md`](../../services/postgres-pgvector/README.md) - PostgreSQL configuration

### Community & Support

**Ask Questions:**
- Open a [GitHub Issue](https://github.com/nanocreek/llm-stack/issues) for bugs or feature requests
- Check existing issues for similar problems

**External Resources:**
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Minikube Documentation](https://minikube.sigs.k8s.io/)
- [Docker Documentation](https://docs.docker.com/)

### Reporting Issues

When reporting a problem, include:

1. **Environment Details:**
   - OS and version
   - Tool versions (minikube, kubectl, docker)
   - Minikube configuration (`minikube config view`)

2. **What You're Trying to Do:**
   - Exact command you ran
   - Expected outcome
   - Actual outcome

3. **Logs and Error Messages:**
   ```bash
   # Pod logs
   kubectl logs <pod-name> -n llm-stack
   
   # Pod description
   kubectl describe pod <pod-name> -n llm-stack
   
   # Minikube logs
   minikube logs
   ```

4. **Configuration Files:**
   - Any modified YAML files
   - Environment variables (redact secrets!)

---

## Next Steps

**✅ You've completed the local development setup!**

### Explore Further:

1. **Customize Services**
   - Edit LiteLLM configuration in `services/litellm/config.yaml`
   - Modify Kubernetes manifests in `k8s/`
   - Update environment variables

2. **Learn the Architecture**
   - Read [`docs/architecture/OVERVIEW.md`](../architecture/OVERVIEW.md)
   - Understand service communication patterns

3. **Deploy to Production**
   - When ready, deploy to Railway for production use
   - See [`../../QUICK_START_RAILWAY.md`](../../QUICK_START_RAILWAY.md)
   - Compare configurations between local and Railway

**Happy developing! 🚀**
