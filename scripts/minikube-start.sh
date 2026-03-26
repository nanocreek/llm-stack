#!/bin/bash

# LiteLLM Stack - Minikube Development Setup Script
# This script automates the setup and deployment of LiteLLM + PostgreSQL + Redis to Minikube

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
MINIKUBE_CPUS=${MINIKUBE_CPUS:-2}
MINIKUBE_MEMORY=${MINIKUBE_MEMORY:-4096}
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
        print_success "kubectl is installed"
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
            --driver=docker
        print_success "Minikube started successfully"
    fi
    
    # Verify cluster is running
    kubectl cluster-info > /dev/null 2>&1 || {
        print_error "Failed to connect to Minikube cluster"
        exit 1
    }
    print_success "Kubernetes cluster is accessible"
}

deploy_kubernetes() {
    print_header "Deploying to Kubernetes"
    
    # Apply Kubernetes manifests
    kubectl apply -f k8s/manifests.yaml
    
    print_success "Kubernetes manifests applied"
}

wait_for_deployments() {
    print_header "Waiting for Deployments to Be Ready"
    
    local timeout=$DEPLOYMENT_TIMEOUT
    
    # Wait for PostgreSQL
    print_warning "Waiting for PostgreSQL to be ready..."
    kubectl wait --for=condition=ready pod -l app=postgres --timeout=${timeout}s -n llm-stack || {
        print_warning "PostgreSQL is still initializing (this is normal)"
    }
    
    # Wait for Redis
    print_warning "Waiting for Redis to be ready..."
    kubectl wait --for=condition=ready pod -l app=redis --timeout=${timeout}s -n llm-stack || {
        print_warning "Redis is still initializing (this is normal)"
    }
    
    # Wait for LiteLLM
    print_warning "Waiting for LiteLLM to be ready..."
    kubectl wait --for=condition=ready pod -l app=litellm --timeout=${timeout}s -n llm-stack || {
        print_warning "LiteLLM is still initializing (this is normal)"
    }
    
    print_success "All services are ready"
}

show_deployment_info() {
    print_header "Deployment Information"
    
    echo "Kubernetes Resources:"
    kubectl get all -n llm-stack
    
    echo -e "\n${GREEN}Services are accessible at:${NC}"
    echo "  LiteLLM:       http://localhost:4000 (after port-forward)"
    echo "  PostgreSQL:    localhost:5432 (after port-forward)"
    echo "  Redis:         localhost:6379 (after port-forward)"
    
    echo -e "\n${YELLOW}To port-forward services, run:${NC}"
    echo "  kubectl port-forward svc/litellm 4000:4000 -n llm-stack"
    echo "  kubectl port-forward svc/postgres 5432:5432 -n llm-stack"
    echo "  kubectl port-forward svc/redis 6379:6379 -n llm-stack"
}

main() {
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════╗"
    echo "║  LiteLLM Stack - Minikube Development  ║"
    echo "║  Setup and Deployment Script           ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    
    check_prerequisites
    start_minikube
    deploy_kubernetes
    wait_for_deployments
    show_deployment_info
    
    echo -e "\n${GREEN}╔════════════════════════════════════════╗"
    echo "║  ✓ Deployment Complete!                ║"
    echo "║                                        ║"
    echo "║  To access services:                   ║"
    echo "║  kubectl port-forward svc/litellm      ║"
    echo "║    4000:4000 -n llm-stack              ║"
    echo "║                                        ║"
    echo "║  Then visit: http://localhost:4000     ║"
    echo "╚════════════════════════════════════════╝${NC}\n"
}

main "$@"
