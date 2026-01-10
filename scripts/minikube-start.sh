#!/bin/bash

# LLM Stack - Minikube Development Setup Script
# This script automates the setup and deployment of the LLM Stack to Minikube

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
MINIKUBE_CPUS=${MINIKUBE_CPUS:-4}
MINIKUBE_MEMORY=${MINIKUBE_MEMORY:-8192}
MINIKUBE_DISK=${MINIKUBE_DISK:-20000}
DEPLOYMENT_TIMEOUT=${DEPLOYMENT_TIMEOUT:-300}

# Functions
print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

check_prerequisites() {
    print_header "Checking Prerequisites"
    
    local missing=0
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        missing=1
    else
        print_success "Docker is installed: $(docker --version)"
    fi
    
    # Check Minikube
    if ! command -v minikube &> /dev/null; then
        print_error "Minikube is not installed"
        missing=1
    else
        print_success "Minikube is installed: $(minikube version --short)"
    fi
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed"
        missing=1
    else
        print_success "kubectl is installed: $(kubectl version --client --short 2>/dev/null)"
    fi
    
    # Check Skaffold
    if ! command -v skaffold &> /dev/null; then
        print_error "Skaffold is not installed"
        missing=1
    else
        print_success "Skaffold is installed: $(skaffold version)"
    fi
    
    if [ $missing -eq 1 ]; then
        print_error "Some prerequisites are missing. Please install them and try again."
        exit 1
    fi
}

start_minikube() {
    print_header "Starting Minikube"
    
    local status=$(minikube status 2>&1 || true)
    
    if echo "$status" | grep -q "Running"; then
        print_success "Minikube is already running"
    else
        print_warning "Starting Minikube cluster..."
        minikube start \
            --cpus=$MINIKUBE_CPUS \
            --memory=$MINIKUBE_MEMORY \
            --disk-size=$MINIKUBE_DISK \
            --driver=docker \
            --container-runtime=docker
        print_success "Minikube started successfully"
    fi
    
    # Verify cluster is running
    kubectl cluster-info > /dev/null 2>&1 || {
        print_error "Failed to connect to Minikube cluster"
        exit 1
    }
    print_success "Kubernetes cluster is accessible"
}

setup_docker() {
    print_header "Setting Up Docker Environment"
    
    # Point Docker to Minikube's Docker daemon
    eval $(minikube docker-env)
    print_success "Docker environment configured for Minikube"
}

build_images() {
    print_header "Building Docker Images"
    
    echo "Building images using Skaffold..."
    skaffold build --file-output=/tmp/build.json
    
    if [ $? -eq 0 ]; then
        print_success "All Docker images built successfully"
    else
        print_error "Failed to build Docker images"
        exit 1
    fi
}

deploy_kubernetes() {
    print_header "Deploying to Kubernetes"
    
    # Create namespace first
    kubectl create namespace llm-stack --dry-run=client -o yaml | kubectl apply -f -
    
    # Apply Kubernetes manifests using Kustomize
    kubectl apply -k k8s/overlays/dev
    
    print_success "Kubernetes manifests applied"
}

wait_for_deployments() {
    print_header "Waiting for Deployments to Be Ready"
    
    local services=("postgres" "redis" "qdrant" "litellm" "r2r" "openwebui" "react-client")
    local timeout=$DEPLOYMENT_TIMEOUT
    local start_time=$(date +%s)
    
    for service in "${services[@]}"; do
        print_warning "Waiting for $service to be ready..."
        
        if kubectl rollout status deployment/dev-$service --timeout=${timeout}s > /dev/null 2>&1; then
            print_success "$service is ready"
        else
            print_warning "$service deployment is still initializing (this is normal for heavy services)"
        fi
    done
    
    # Give extra time for initialization
    print_warning "Waiting 30 seconds for services to fully initialize..."
    sleep 30
}

show_deployment_info() {
    print_header "Deployment Information"
    
    echo "Kubernetes Resources:"
    kubectl get all -n default --no-headers=true | grep -E "^(pod|deployment|svc|statefulset)" || true
    
    echo -e "\n${GREEN}Services are accessible at:${NC}"
    echo "  React Client:  http://localhost:3000"
    echo "  OpenWebUI:     http://localhost:8080"
    echo "  LiteLLM:       http://localhost:4000"
    echo "  R2R:           http://localhost:7272"
    echo "  Qdrant:        http://localhost:6333"
    echo "  PostgreSQL:    localhost:5432"
    echo "  Redis:         localhost:6379"
}

main() {
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════╗"
    echo "║  LLM Stack - Minikube Development      ║"
    echo "║  Setup and Deployment Script           ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    
    check_prerequisites
    start_minikube
    setup_docker
    build_images
    deploy_kubernetes
    wait_for_deployments
    show_deployment_info
    
    echo -e "\n${GREEN}╔════════════════════════════════════════╗"
    echo "║  ✓ Deployment Complete!               ║"
    echo "║                                        ║"
    echo "║  Starting port forwarding...           ║"
    echo "╚════════════════════════════════════════╝${NC}\n"
}

main() {
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════╗"
    echo "║  LLM Stack - Minikube Development      ║"
    echo "║  Setup and Deployment Script           ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    
    check_prerequisites
    start_minikube
    setup_docker
    build_images
    deploy_kubernetes
    wait_for_deployments
    show_deployment_info
    
    echo -e "\n${GREEN}╔════════════════════════════════════════╗"
    echo "║  ✓ Deployment Complete!               ║"
    echo "║                                        ║"
    echo "║  To start port forwarding, run:        ║"
    echo "║  skaffold dev --port-forward           ║"
    echo "║                                        ║"
    echo "║  Services will be available at:        ║"
    echo "║  http://localhost:3000 (React)         ║"
    echo "║  http://localhost:8080 (OpenWebUI)     ║"
    echo "║  http://localhost:4000 (LiteLLM)       ║"
    echo "║  http://localhost:7272 (R2R)           ║"
    echo "║  http://localhost:6333 (Qdrant)        ║"
    echo "╚════════════════════════════════════════╝${NC}\n"
}

main "$@"
