# Migrating to Service Discovery

## Overview

This guide covers migrating from static configuration to dynamic service discovery.

## Prerequisites

- Kubernetes 1.28+
- Helm 3.0+
- kubectl access to cluster

## Migration Steps

### 1. Deploy RBAC Resources

```bash
# Apply RBAC for both services
kubectl apply -f engine/k8s/rbac.yaml
kubectl apply -f control/k8s/rbac.yaml
```

### 2. Update Configuration

**Option A: Helm (Recommended)**

```bash
# Update values.yaml
helm upgrade inferadb-engine ./engine/helm \
  --set discovery.mode=kubernetes_service \
  --set discovery.controlApi.serviceName=inferadb-control
```

**Option B: Environment Variables**

```bash
# Update deployment
kubectl set env deployment/inferadb-engine \
  INFERADB__AUTH__CONTROL_API__DISCOVERY_MODE=kubernetes_service \
  INFERADB__AUTH__CONTROL_API__SERVICE_NAME=inferadb-control
```

### 3. Verify Discovery

Check logs for successful discovery:

```bash
kubectl logs -f deployment/inferadb-engine | grep discovery
# Expected: "Discovered k8s endpoints: count=3"
```

### 4. Monitor Metrics

```bash
# Check discovery health
kubectl port-forward svc/inferadb-engine 8080:8080
curl localhost:8080/metrics | grep discovery
```

## Rollback

If issues occur, revert to static mode:

```bash
helm upgrade inferadb-engine ./engine/helm \
  --set discovery.mode=static \
  --set discovery.controlApi.staticUrl=http://inferadb-control:3000
```

## Backward Compatibility

Static configuration still works - no breaking changes.
