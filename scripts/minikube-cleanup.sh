#!/bin/bash

# LLM Stack - Minikube Cleanup Script
# This script cleans up resources from the Minikube cluster

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Check if a Minikube cluster exists and is running
check_minikube() {
    if ! command -v minikube &> /dev/null; then
        print_warning "Minikube is not installed, skipping..."
        return 1
    fi
    
    local status=$(minikube status 2>&1 || true)
    if echo "$status" | grep -q "Running"; then
        return 0
    else
        print_warning "Minikube cluster is not running"
        return 1
    fi
}

cleanup_kubernetes() {
    print_header "Cleaning Up Kubernetes Resources"
    
    if ! check_minikube; then
        return
    fi
    
    print_warning "Deleting all resources from the default namespace..."
    
    # Delete using Kustomize overlay
    if [ -d "k8s/overlays/dev" ]; then
        kubectl delete -k k8s/overlays/dev --ignore-not-found=true
        print_success "Kubernetes manifests deleted"
    fi
    
    # Wait for resources to be deleted
    print_warning "Waiting for resources to be cleaned up..."
    sleep 10
    
    # Verify deletion
    local remaining=$(kubectl get all -n default --no-headers=true 2>/dev/null | grep -c "^" || echo 0)
    if [ $remaining -eq 0 ]; then
        print_success "All Kubernetes resources deleted"
    else
        print_warning "Some resources may still be terminating..."
    fi
}

cleanup_docker_images() {
    print_header "Cleaning Up Docker Images (Optional)"
    
    read -p "Remove Docker images? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Set up Docker environment
        eval $(minikube docker-env 2>/dev/null || true)
        
        local images=("llm-stack/react-client" "llm-stack/r2r" "llm-stack/qdrant" "llm-stack/litellm" "llm-stack/openwebui")
        
        for image in "${images[@]}"; do
            if docker rmi "$image" 2>/dev/null; then
                print_success "Removed image: $image"
            fi
        done
    fi
}

stop_minikube() {
    print_header "Stopping/Deleting Minikube Cluster (Optional)"
    
    read -p "Stop Minikube cluster? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Stopping Minikube..."
        minikube stop
        print_success "Minikube stopped"
    fi
    
    read -p "Delete Minikube cluster entirely? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_warning "This will delete the entire Minikube cluster..."
        read -p "Are you sure? (type 'yes' to confirm): " -r
        echo
        
        if [ "$REPLY" = "yes" ]; then
            minikube delete
            print_success "Minikube cluster deleted"
        else
            print_warning "Cluster deletion cancelled"
        fi
    fi
}

main() {
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════╗"
    echo "║  LLM Stack - Minikube Cleanup Script   ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    
    cleanup_kubernetes
    cleanup_docker_images
    stop_minikube
    
    echo -e "\n${GREEN}✓ Cleanup complete!${NC}\n"
}

main "$@"
