# Service Discovery in InferaDB

## Overview

InferaDB supports dynamic service discovery for production deployments with multiple instances.

## Discovery Modes

### Static (Development)

- Manually configured URLs
- No external dependencies
- Best for: Local development, simple deployments

### Kubernetes Service (Production)

- Automatic pod discovery via k8s Endpoints API
- Health-aware routing
- Best for: Production Kubernetes deployments

## Configuration

### Server - Management API Discovery

```yaml
# server/config.yaml
auth:
  management_api:
    discovery_mode: "kubernetes_service"
    service_name: "inferadb-management"
    namespace: "inferadb"
    port: 3000
    refresh_interval_seconds: 30
```

### Management - Server API Discovery

```yaml
# management/config.yaml
cache_invalidation:
  discovery_mode: "kubernetes_pods"
  label_selector: "app=inferadb-server"
  namespace: "inferadb"
  port: 8080
  refresh_interval_seconds: 30
```

## RBAC Requirements

Service discovery requires k8s API access. Ensure ServiceAccounts have proper permissions:

```bash
# Apply RBAC configuration
kubectl apply -f server/k8s/rbac.yaml
kubectl apply -f management/k8s/rbac.yaml
```

## Monitoring

Key metrics to monitor:

- `inferadb_discovery_operations_total` - Discovery success/failure
- `inferadb_lb_endpoint_health` - Endpoint health status
- `inferadb_discovery_cache_hits_total` - Cache effectiveness

## Troubleshooting

### Discovery Fails with Permission Denied

- Check ServiceAccount is configured
- Verify RBAC Role has endpoints/services access
- Check namespace matches service location

### Endpoints Not Discovered

- Verify service exists: `kubectl get svc -n inferadb`
- Check pods are ready: `kubectl get pods -n inferadb`
- Review logs for discovery errors
