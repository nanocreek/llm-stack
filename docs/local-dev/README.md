# Local Development Guide

⚙️ **Alternative Deployment Option** - This guide covers running the LLM Stack locally using Kubernetes (Minikube). For most users, we recommend the simpler [Railway deployment](../../README.md#-quick-start---railway-deployment).

## Overview

This documentation covers **local development** using Minikube and Kubernetes. While Railway provides automated deployment with managed infrastructure, local development gives you complete control and operates entirely on your machine.

**Primary Deployment Method:** [Railway Deployment](../../QUICK_START_RAILWAY.md) - One-click deployment with managed services  
**Alternative Method (You Are Here):** Local Kubernetes development with Minikube and Skaffold

---

## Why Choose Local Development?

### ✅ Use Local Development When You Want To:

- **Deep Customization** - Modify service configurations, add custom services, or experiment with alternative architectures
- **Pre-Deployment Testing** - Test changes in a Kubernetes environment before deploying to production
- **Offline Development** - Work without internet connectivity after initial setup
- **Learning Kubernetes** - Gain hands-on experience with Kubernetes concepts and workflows
- **Cost Considerations** - Run entirely on your own hardware without cloud costs
- **Privacy & Security** - Keep all data and API keys on your local machine
- **Development Tooling** - Use Skaffold for hot-reload development with automatic rebuilds

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
| **Skaffold** | 2.0+ | Development workflow automation | [Install Skaffold](https://skaffold.dev/docs/install/) |

**Optional but Recommended:**
- **Helm** 3.0+ - For managing complex Kubernetes packages [Install Helm](https://helm.sh/docs/intro/install/)
- **kubectx** - For switching between Kubernetes contexts [Install kubectx](https://github.com/ahmetb/kubectx)

### System Requirements

**Minimum Requirements:**
- **CPU**: 4 cores
- **RAM**: 8 GB available for Minikube
- **Disk**: 20 GB free space
- **OS**: macOS, Linux, or Windows 10/11 with WSL2

**Recommended for Optimal Performance:**
- **CPU**: 6-8 cores
- **RAM**: 16 GB (allocate 12 GB to Minikube)
- **Disk**: 40 GB SSD free space
- **OS**: macOS or Linux (Windows users should use WSL2)

### Knowledge Prerequisites

**Required Understanding:**
- Basic Docker concepts (images, containers, Dockerfiles)
- Command-line/terminal usage
- Basic understanding of environment variables

**Helpful but Optional:**
- Kubernetes fundamentals (pods, services, deployments)
- YAML configuration syntax
- Container orchestration concepts

**Don't worry if you're new to Kubernetes** - the guides walk you through each step.

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

# Check Skaffold
skaffold version
# Expected: v2.0.0 or higher
```

If any command fails, follow the installation links in the table above.

---

## Quick Start

Get the stack running locally in 30 minutes or less.

### Step 1: Install Prerequisites

Ensure all tools from the [Prerequisites](#prerequisites) section are installed and verified.

### Step 2: Clone the Repository

```bash
# Clone the repository
git clone https://github.com/yourusername/llm-stack.git
cd llm-stack
```

### Step 3: Start Minikube

```bash
# Start Minikube with recommended resources
minikube start --cpus=4 --memory=8192 --disk-size=40000

# Verify cluster is running
minikube status

# Configure Docker to use Minikube's daemon (important!)
eval $(minikube docker-env)
```

**What this does:**
- Creates a local Kubernetes cluster in a VM
- Allocates 4 CPU cores and 8GB RAM
- Configures your shell to build images directly in Minikube

**Troubleshooting:** If `minikube start` fails, try increasing resources or using a different driver:
```bash
minikube start --cpus=6 --memory=12288 --driver=docker
```

### Step 4: Deploy with Skaffold

```bash
# Run Skaffold in development mode
# This builds images, deploys to Kubernetes, and sets up port forwarding
skaffold dev --port-forward
```

**What Skaffold does:**
1. ⚡ Builds Docker images for all 7 services
2. 📦 Deploys services to Minikube using Kustomize
3. 🔌 Sets up automatic port forwarding to localhost
4. 👀 Watches for file changes and auto-rebuilds/redeploys
5. 📊 Streams logs from all services in real-time

**Expected output:**
```
Generating tags...
 - llm-stack/litellm -> llm-stack/litellm:latest
 - llm-stack/openwebui -> llm-stack/openwebui:latest
...
Port forwarding service openwebui in namespace default, remote port 8080 -> http://127.0.0.1:8080
```

⏱️ **First-time deployment:** 10-15 minutes (downloading base images and building)  
⏱️ **Subsequent deployments:** 2-5 minutes (cached layers)

### Step 5: Access Services

Once deployment completes, services are available at these URLs:

| Service | Local URL | Description |
|---------|-----------|-------------|
| **React Client** | http://localhost:3000 | Frontend application |
| **OpenWebUI** | http://localhost:8080 | Main chat interface |
| **LiteLLM** | http://localhost:4000 | LLM proxy API |
| **R2R** | http://localhost:7272 | RAG API endpoints |
| **Qdrant** | http://localhost:6333 | Vector database UI |
| **PostgreSQL** | localhost:5432 | Database (use pgAdmin or psql) |
| **Redis** | localhost:6379 | Cache (use redis-cli) |

**Start here:** Open http://localhost:8080 to access Open WebUI

### Step 6: Verify Everything Works

```bash
# Check all pods are running
kubectl get pods

# You should see all pods in "Running" state:
# NAME                          READY   STATUS    RESTARTS   AGE
# litellm-xxx                   1/1     Running   0          5m
# openwebui-xxx                 1/1     Running   0          5m
# postgres-0                    1/1     Running   0          5m
# r2r-xxx                       1/1     Running   0          5m
# qdrant-xxx                    1/1     Running   0          5m
# react-client-xxx              1/1     Running   0          5m
# redis-0                       1/1     Running   0          5m

# Test a service
curl http://localhost:4000/health
# Expected: {"status":"ok"}
```

**If pods are not running:** See [Troubleshooting](#common-issues) section below.

**Next:** Read the [Documentation Guide](#documentation-guide) to understand the architecture and workflow.

---

## Documentation Guide

This directory contains comprehensive guides for local development. Each document serves a specific purpose.

### Available Documentation

#### 📚 [`README.md`](README.md) (You Are Here)
**Gateway document** - Entry point for local development. Explains why you'd choose local development, prerequisites, quick start, and guides you to other documentation.

**Read this:** First, to understand the local development option and complete initial setup.

---

#### 🏗️ [`KUBERNETES_DEPLOYMENT_OVERVIEW.md`](KUBERNETES_DEPLOYMENT_OVERVIEW.md)
**Architecture deep-dive** - Detailed explanation of the Kubernetes deployment architecture, service communication, resource allocation, and configuration management.

**Topics covered:**
- Complete architecture diagrams
- File structure and organization
- Kubernetes manifest details for each service
- Service communication patterns (DNS, networking)
- Resource requests and limits
- Environment variable management
- Init containers and startup dependencies
- Health checks and liveness probes
- Storage and persistence options

**Read this:** When you want to understand how the entire system works, modify service configurations, or troubleshoot complex issues.

**Key sections:**
- Service communication patterns (internal DNS)
- Resource allocation tables
- Startup order and dependencies
- Security notes for dev vs production

---

#### ⚡ [`MINIKUBE_DEV_SETUP.md`](MINIKUBE_DEV_SETUP.md)
**Complete setup guide** - Step-by-step instructions for installing prerequisites, configuring Minikube, deploying services, and common development tasks.

**Topics covered:**
- Detailed prerequisite installation instructions
- Minikube cluster setup with optimal configurations
- Skaffold deployment workflow
- Environment variable configuration
- Service communication setup
- Common development workflows
- Debugging techniques
- IDE integration (VS Code, IntelliJ)
- Performance optimization
- Cleanup procedures

**Read this:** As your main reference for setup and day-to-day development tasks. This is the most comprehensive guide.

**Key sections:**
- Quick Start (detailed version)
- Environment variable management
- Troubleshooting section
- Advanced usage patterns

---

#### 🔧 [`MINIKUBE_QUICK_REFERENCE.md`](MINIKUBE_QUICK_REFERENCE.md)
**Command cheat sheet** - Quick reference for common kubectl, Minikube, and Skaffold commands. No explanations, just commands you can copy-paste.

**Topics covered:**
- One-line setup commands
- Viewing services and logs
- Port forwarding and access
- Debugging commands
- Deployment updates
- Minikube operations
- Docker in Minikube
- Cleanup procedures

**Read this:** Keep this open while developing. Reference it whenever you need to run a command but can't remember the exact syntax.

**Key sections:**
- Service access URLs
- Kubernetes DNS names
- Troubleshooting quick fixes

---

#### 🚀 [`SKAFFOLD_QUICKSTART.md`](SKAFFOLD_QUICKSTART.md)
**Development workflow guide** - Focused guide on using Skaffold for hot-reload development, automatic rebuilds, and efficient iteration.

**Topics covered:**
- What Skaffold does and why it's useful
- Configuration file structure
- File sync and hot-reload setup
- Environment variable management with Skaffold
- Development workflow best practices
- Troubleshooting Skaffold-specific issues

**Read this:** After initial setup, when you want to understand the development workflow and optimize your iteration speed.

**Key sections:**
- One-command setup
- What Skaffold does (build, deploy, watch, forward)
- File structure explanation

---

### Recommended Reading Order

**For First-Time Setup:**
1. **This README** - Understand why local dev, prerequisites, and quick start ✅
2. **[`MINIKUBE_DEV_SETUP.md`](MINIKUBE_DEV_SETUP.md)** - Complete setup with detailed steps
3. **[`SKAFFOLD_QUICKSTART.md`](SKAFFOLD_QUICKSTART.md)** - Learn the development workflow

**For Understanding Architecture:**
1. **[`KUBERNETES_DEPLOYMENT_OVERVIEW.md`](KUBERNETES_DEPLOYMENT_OVERVIEW.md)** - Read this to understand how services communicate, resource allocation, and overall architecture

**For Daily Development:**
1. **[`MINIKUBE_QUICK_REFERENCE.md`](MINIKUBE_QUICK_REFERENCE.md)** - Keep this open for quick command reference

**For Troubleshooting:**
1. **[`MINIKUBE_QUICK_REFERENCE.md`](MINIKUBE_QUICK_REFERENCE.md)** - Check troubleshooting section first
2. **[`MINIKUBE_DEV_SETUP.md`](MINIKUBE_DEV_SETUP.md)** - Detailed troubleshooting with context

---

## Common Development Tasks

### Starting the Environment

```bash
# Start Minikube (if not running)
minikube start

# Configure Docker environment
eval $(minikube docker-env)

# Deploy and watch for changes
skaffold dev --port-forward
```

**Tip:** Leave `skaffold dev` running in a terminal. It will auto-rebuild when you make code changes.

### Stopping the Environment

```bash
# Stop Skaffold (press Ctrl+C in the skaffold terminal)

# Stop Minikube (keeps the cluster)
minikube stop

# Or delete the cluster entirely (frees resources)
minikube delete
```

### Viewing Logs

```bash
# Stream logs from all services
kubectl logs -f -l app.kubernetes.io/part-of=llm-stack --all-containers

# Stream logs from a specific service
kubectl logs -f deployment/litellm

# View recent logs (no streaming)
kubectl logs deployment/r2r --tail=100
```

**Pro tip:** Use `stern` for advanced log viewing: `stern '.*'`

### Accessing Service UIs

Services are automatically port-forwarded when running `skaffold dev`:

- **Open WebUI**: http://localhost:8080
- **Qdrant Dashboard**: http://localhost:6333/dashboard
- **React Client**: http://localhost:3000

**Manual port forwarding (if Skaffold is not running):**
```bash
kubectl port-forward svc/openwebui 8080:8080
kubectl port-forward svc/qdrant 6333:6333
```

### Making Code Changes and Testing

**Skaffold watches for changes automatically:**

1. Edit code in your editor (e.g., `services/litellm/config.yaml`)
2. Save the file
3. Skaffold detects the change and rebuilds the affected service
4. New version is deployed automatically
5. Check logs to see the redeployment

**For services with file sync (React Client, LiteLLM):**
- Changes are synced directly without rebuilding (faster)
- Watch the Skaffold terminal for sync notifications

### Resetting the Environment

**Soft reset (keep cluster, rebuild services):**
```bash
# Delete deployments
kubectl delete -k k8s/overlays/dev

# Redeploy
skaffold run
```

**Hard reset (delete everything):**
```bash
# Stop Skaffold (Ctrl+C)

# Delete Minikube cluster
minikube delete

# Start fresh
minikube start --cpus=4 --memory=8192
eval $(minikube docker-env)
skaffold dev --port-forward
```

### Troubleshooting Common Issues

**Pod won't start:**
```bash
# Check pod status
kubectl describe pod <pod-name>

# View pod logs
kubectl logs <pod-name>

# Check resource usage
kubectl top nodes
kubectl top pods
```

**Connection errors between services:**
```bash
# Test DNS resolution
kubectl run -it --rm debug --image=curlimages/curl -- nslookup litellm

# Test connectivity
kubectl run -it --rm debug --image=curlimages/curl -- curl http://litellm:4000/health
```

**Out of memory:**
```bash
# Increase Minikube memory
minikube delete
minikube start --memory=12288
```

**Want more detail?** See the [Troubleshooting](#troubleshooting) section or check individual service READMEs in `services/` directory.

---

## Differences from Railway Deployment

Understanding key differences helps you work effectively in both environments.

| Aspect | Local Development (Minikube) | Railway Deployment |
|--------|------------------------------|-------------------|
| **Setup Time** | 30+ minutes (initial setup) | 5 minutes (one-click) |
| **Infrastructure** | Manual configuration of all services | Fully managed (PostgreSQL, Redis) |
| **Networking** | Manual port forwarding to localhost | Automatic public URLs with SSL |
| **Database Storage** | EmptyDir (non-persistent by default) | Managed, persistent databases |
| **Environment Variables** | Manual configuration in Kustomize | Template-based, auto-configured |
| **Resource Limits** | Limited by your machine (8-16GB RAM) | Scalable, Railway manages resources |
| **Cost** | Free (uses your hardware) | Paid (based on resource usage) |
| **Hot Reload** | Built-in with Skaffold file sync | Manual restart required |
| **Complexity** | High (Kubernetes, Docker, Skaffold) | Low (Railway abstracts complexity) |
| **Internet Required** | Only for initial image downloads | Yes, for deployment and access |
| **Team Collaboration** | Difficult (local only) | Easy (shared URLs) |
| **Production Use** | Not recommended | Production-ready |

### Development-Friendly Features (Local Only)

**✅ Hot Reload:**
- React Client: Changes sync without rebuild
- LiteLLM config: Fast rebuild on config changes

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
- [`KUBERNETES_DEPLOYMENT_OVERVIEW.md`](KUBERNETES_DEPLOYMENT_OVERVIEW.md) - Architecture and service details
- [`MINIKUBE_DEV_SETUP.md`](MINIKUBE_DEV_SETUP.md) - Complete setup guide with troubleshooting
- [`MINIKUBE_QUICK_REFERENCE.md`](MINIKUBE_QUICK_REFERENCE.md) - Quick command reference
- [`SKAFFOLD_QUICKSTART.md`](SKAFFOLD_QUICKSTART.md) - Development workflow

**General Documentation:**
- [`../../README.md`](../../README.md) - Project overview and Railway deployment
- [`../../QUICK_START_RAILWAY.md`](../../QUICK_START_RAILWAY.md) - Railway quick start guide
- [`../../ENV_VARIABLES_GUIDE.md`](../../ENV_VARIABLES_GUIDE.md) - Environment variable reference
- [`../architecture/OVERVIEW.md`](../architecture/OVERVIEW.md) - System architecture
- [`../troubleshooting/COMMON_ISSUES.md`](../troubleshooting/COMMON_ISSUES.md) - Common problems and solutions

**Service-Specific:**
- [`../../services/litellm/README.md`](../../services/litellm/README.md) - LiteLLM configuration
- [`../../services/openwebui/README.md`](../../services/openwebui/README.md) - Open WebUI setup
- [`../../services/r2r/README.md`](../../services/r2r/README.md) - R2R RAG framework
- [`../../services/qdrant/README.md`](../../services/qdrant/README.md) - Qdrant vector database

### Community & Support

**Ask Questions:**
- Open a [GitHub Issue](https://github.com/yourusername/llm-stack/issues) for bugs or feature requests
- Check existing issues for similar problems

**External Resources:**
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Minikube Documentation](https://minikube.sigs.k8s.io/)
- [Skaffold Documentation](https://skaffold.dev/)
- [Docker Documentation](https://docs.docker.com/)

### Reporting Issues

When reporting a problem, include:

1. **Environment Details:**
   - OS and version
   - Tool versions (minikube, kubectl, skaffold, docker)
   - Minikube configuration (`minikube config view`)

2. **What You're Trying to Do:**
   - Exact command you ran
   - Expected outcome
   - Actual outcome

3. **Logs and Error Messages:**
   ```bash
   # Pod logs
   kubectl logs <pod-name>
   
   # Pod description
   kubectl describe pod <pod-name>
   
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
   - Edit service Dockerfiles in `services/*/Dockerfile`
   - Modify Kubernetes manifests in `k8s/base/`
   - Update environment variables in `k8s/overlays/dev/`

2. **Learn the Architecture**
   - Read [`KUBERNETES_DEPLOYMENT_OVERVIEW.md`](KUBERNETES_DEPLOYMENT_OVERVIEW.md)
   - Understand service communication patterns
   - Explore resource allocation strategies

3. **Optimize Your Workflow**
   - Set up IDE integration (VS Code, IntelliJ)
   - Configure shell aliases for common commands
   - Use `kubectx` for faster context switching

4. **Deploy to Production**
   - When ready, deploy to Railway for production use
   - See [`../../QUICK_START_RAILWAY.md`](../../QUICK_START_RAILWAY.md)
   - Compare configurations between local and Railway

**Happy developing! 🚀**
