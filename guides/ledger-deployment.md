# Ledger Deployment Guide

This guide covers production deployment of InferaDB Ledger, the blockchain-based storage backend that provides cryptographically verifiable persistence for Engine and Control services.

## Overview

Ledger is a Raft-based distributed storage system that:

- Provides strongly consistent key-value storage
- Maintains cryptographically signed block history
- Supports real-time change notifications via `WatchBlocks`
- Scales horizontally with StatefulSet replicas

## Prerequisites

- Kubernetes cluster (1.27+)
- Flux CD (or manual kubectl apply)
- At least 3 nodes for production (Raft quorum)
- Persistent volume provisioner

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Client Services                           │
│              (Engine, Control, CLI, SDKs)                        │
└───────────────────────────┬─────────────────────────────────────┘
                            │ gRPC :50051
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                    inferadb-ledger-client                        │
│                  (ClusterIP Load Balancer)                       │
└───────────────────────────┬─────────────────────────────────────┘
                            │
          ┌─────────────────┼─────────────────┐
          ▼                 ▼                 ▼
    ┌──────────┐      ┌──────────┐      ┌──────────┐
    │ ledger-0 │◄────►│ ledger-1 │◄────►│ ledger-2 │
    │ (leader) │      │(follower)│      │(follower)│
    └──────────┘      └──────────┘      └──────────┘
          │                 │                 │
          ▼                 ▼                 ▼
    ┌──────────┐      ┌──────────┐      ┌──────────┐
    │   PVC    │      │   PVC    │      │   PVC    │
    └──────────┘      └──────────┘      └──────────┘
```

## Deployment

### Using Flux CD (Recommended)

Ledger is deployed as part of the InferaDB Flux applications:

```bash
# Apply the base kustomization
kubectl apply -k deploy/flux/apps/base

# Or for a specific environment
kubectl apply -k deploy/flux/apps/production
```

### Manual Deployment

```bash
# Deploy Ledger StatefulSet
kubectl apply -f deploy/flux/apps/base/ledger/

# Verify pods are running
kubectl get pods -n inferadb -l app.kubernetes.io/name=inferadb-ledger

# Check Raft cluster formation
kubectl logs -n inferadb inferadb-ledger-0 | grep -i raft
```

## Configuration

### Environment Variables

| Variable             | Description                    | Default                              |
| -------------------- | ------------------------------ | ------------------------------------ |
| `LEDGER_NODE_ID`     | Unique node identifier         | Pod ordinal                          |
| `LEDGER_LISTEN_ADDR` | gRPC listen address            | `0.0.0.0:50051`                      |
| `LEDGER_DATA_DIR`    | Data directory path            | `/data`                              |
| `LEDGER_PEERS`       | Comma-separated peer addresses | Auto-discovered via headless service |
| `BOOTSTRAP_EXPECT`   | Expected cluster size          | `3`                                  |

### Storage Classes

Production deployments should use high-performance storage:

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ledger-storage
provisioner: kubernetes.io/gce-pd # Or your provider
parameters:
  type: pd-ssd
reclaimPolicy: Retain
volumeBindingMode: WaitForFirstConsumer
```

### Resource Requirements

| Environment | CPU Request | CPU Limit | Memory Request | Memory Limit | Storage |
| ----------- | ----------- | --------- | -------------- | ------------ | ------- |
| Development | 100m        | 500m      | 256Mi          | 512Mi        | 1Gi     |
| Staging     | 500m        | 1000m     | 512Mi          | 1Gi          | 10Gi    |
| Production  | 1000m       | 2000m     | 1Gi            | 2Gi          | 50Gi    |

## Monitoring

### Prometheus Metrics

Ledger exposes metrics at `/metrics` on port 9090:

- `ledger_raft_term` - Current Raft term
- `ledger_raft_commit_index` - Committed log index
- `ledger_raft_applied_index` - Applied log index
- `ledger_blocks_total` - Total blocks created
- `ledger_storage_bytes` - Storage utilization

### Health Checks

```bash
# Liveness probe
grpcurl -plaintext ledger:50051 grpc.health.v1.Health/Check

# Readiness check (includes Raft leader election)
kubectl exec -n inferadb inferadb-ledger-0 -- \
  grpcurl -plaintext localhost:50051 ledger.v1.Ledger/GetStatus
```

### Alerts

Key alerts to configure:

1. **LedgerNoLeader** - No Raft leader elected for >1 minute
2. **LedgerHighLatency** - p99 latency >100ms
3. **LedgerStorageFull** - Disk usage >80%
4. **LedgerReplicationLag** - Follower lag >1000 entries

## Operations

### Scaling

Ledger uses Raft consensus requiring odd replica counts (3, 5, 7):

```bash
# Scale to 5 replicas
kubectl scale statefulset -n inferadb inferadb-ledger --replicas=5
```

### Backup and Restore

```bash
# Create snapshot
kubectl exec -n inferadb inferadb-ledger-0 -- \
  ledger-cli snapshot create /data/backups/snapshot-$(date +%Y%m%d).tar.gz

# Restore from snapshot
kubectl exec -n inferadb inferadb-ledger-0 -- \
  ledger-cli snapshot restore /data/backups/snapshot-20240115.tar.gz
```

### Rolling Updates

StatefulSet handles rolling updates automatically:

```bash
# Update image
kubectl set image statefulset/inferadb-ledger -n inferadb \
  ledger=inferadb/ledger:v1.2.0

# Monitor rollout
kubectl rollout status statefulset/inferadb-ledger -n inferadb
```

## Troubleshooting

### Common Issues

**Pods stuck in Pending**

- Check PVC binding: `kubectl get pvc -n inferadb`
- Verify storage class exists and has available capacity

**Raft leader election failing**

- Ensure all pods can communicate on port 50051
- Check network policies allow Ledger peer traffic
- Verify `BOOTSTRAP_EXPECT` matches replica count

**High latency**

- Check disk I/O: `kubectl top pods -n inferadb`
- Review storage class performance tier
- Consider scaling horizontally

### Debug Commands

```bash
# View Raft state
kubectl exec -n inferadb inferadb-ledger-0 -- \
  grpcurl -plaintext localhost:50051 ledger.v1.Ledger/GetStatus

# Check peer connectivity
kubectl exec -n inferadb inferadb-ledger-0 -- \
  nc -zv inferadb-ledger-1.inferadb-ledger.inferadb.svc.cluster.local 50051

# Tail logs
kubectl logs -n inferadb inferadb-ledger-0 -f
```

## Network Policies

Ledger requires these network flows:

| Source     | Destination | Port  | Purpose          |
| ---------- | ----------- | ----- | ---------------- |
| Engine     | Ledger      | 50051 | gRPC client      |
| Control    | Ledger      | 50051 | gRPC client      |
| Ledger     | Ledger      | 50051 | Raft consensus   |
| Prometheus | Ledger      | 9090  | Metrics scraping |

See `deploy/policies/network-policies/production/ledger-policy.yaml` for Cilium policy definitions.

## See Also

- [Engine Configuration](../../engine/docs/guides/configuration.md)
- [Control Configuration](../../control/docs/guides/configuration.md)
- [Network Policies](../deploy/policies/README.md)
- [Runbooks](../deploy/runbooks/)
