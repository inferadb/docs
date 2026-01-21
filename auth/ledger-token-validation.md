# Ledger-Based Token Validation

This guide covers the deployment and operation of InferaDB's Ledger-backed token validation system. Signing keys are stored in Ledger, enabling Engine to validate tokens without Control connectivity.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Client Applications                           │
│              (SDK, CLI, Dashboard, External Services)                │
└───────────────────────────┬─────────────────────────────────────────┘
                            │
                            │ JWT (with org_id, kid)
                            ▼
┌─────────────────────────────────────────────────────────────────────┐
│                            Engine                                    │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │                    Token Validation                          │    │
│  │  1. Extract org_id and kid from JWT                         │    │
│  │  2. Get signing key from SigningKeyCache                    │    │
│  │  3. Verify Ed25519 signature                                │    │
│  │  4. Validate claims (exp, iat, scope)                       │    │
│  └──────────────────────────┬──────────────────────────────────┘    │
│                             │                                        │
│  ┌──────────────────────────▼──────────────────────────────────┐    │
│  │                   SigningKeyCache                            │    │
│  │  ┌─────────────┐    miss    ┌─────────────────────────┐     │    │
│  │  │  L1: Moka   │───────────►│  L2: Ledger Storage     │     │    │
│  │  │ (TTL: 300s) │            │  (PublicSigningKeyStore)│     │    │
│  │  └─────────────┘            └─────────────────────────┘     │    │
│  │         │                              │                     │    │
│  │         │ cache                        │ fallback            │    │
│  │         ▼ hit                          ▼ (on transient error)│    │
│  │  ┌─────────────────────────────────────────────────────┐    │    │
│  │  │            Return DecodingKey                       │    │    │
│  │  └─────────────────────────────────────────────────────┘    │    │
│  └─────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
                            │
                            │ gRPC
                            ▼
┌─────────────────────────────────────────────────────────────────────┐
│                           Ledger                                     │
│                                                                      │
│  Namespace: {org_id}                                                │
│  Key: signing-keys/{kid}                                            │
│  Value: PublicSigningKey (JSON)                                     │
│                                                                      │
│  ┌───────────────────────────────────────────────────────────┐      │
│  │  PublicSigningKey                                         │      │
│  │  - kid: "cert_abc123"                                     │      │
│  │  - public_key: "base64url(Ed25519 public key)"           │      │
│  │  - client_id: 42                                          │      │
│  │  - active: true                                           │      │
│  │  - valid_from: "2025-01-01T00:00:00Z"                    │      │
│  │  - valid_until: "2026-01-01T00:00:00Z"                   │      │
│  │  - revoked_at: null                                       │      │
│  └───────────────────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────────────┘

                            ▲
                            │ gRPC
                            │
┌─────────────────────────────────────────────────────────────────────┐
│                           Control                                    │
│  ┌───────────────────────────────────────────────────────────┐      │
│  │                  Certificate Handlers                      │      │
│  │  - create_certificate → writes PublicSigningKey           │      │
│  │  - revoke_certificate → sets revoked_at                   │      │
│  │  - rotate_certificate → creates new key with grace period │      │
│  └───────────────────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────────────┘
```

### Key Flow

1. **Key Registration**: Control creates a certificate and writes the public key to Ledger
2. **Token Validation**: Engine extracts `kid` from JWT, fetches signing key from cache/Ledger
3. **Key Revocation**: Control marks key as revoked in Ledger; Engine sees update on cache refresh

### Namespace Mapping

- `namespace_id == org_id`: Each organization's keys live in their Ledger namespace
- Key path: `signing-keys/{kid}` within the namespace

## Configuration

### Control Configuration

```yaml
control:
  storage: ledger
  ledger:
    # Ledger cluster endpoint
    endpoint: "http://inferadb-ledger.inferadb:50051"
    # Unique client ID for idempotency
    client_id: "control-prod-us-west-1"
    # Control's namespace for internal data
    namespace_id: 1
```

| Field          | Description                          | Required |
| -------------- | ------------------------------------ | -------- |
| `endpoint`     | Ledger gRPC endpoint URL             | Yes      |
| `client_id`    | Unique identifier for idempotency    | Yes      |
| `namespace_id` | Control's internal namespace         | Yes      |
| `vault_id`     | Optional vault for finer scoping     | No       |

### Engine Configuration

Engine uses the same Ledger cluster but each organization's keys are in their respective namespace:

```yaml
engine:
  auth:
    # Signing key cache TTL (default: 300 seconds)
    signing_key_cache_ttl: 300
    # Maximum cached keys (default: 10,000)
    signing_key_cache_capacity: 10000
  storage:
    ledger:
      endpoint: "http://inferadb-ledger.inferadb:50051"
      client_id: "engine-prod-us-west-1"
```

| Field                        | Description                    | Default |
| ---------------------------- | ------------------------------ | ------- |
| `signing_key_cache_ttl`      | Key cache TTL in seconds       | 300     |
| `signing_key_cache_capacity` | Maximum keys to cache          | 10,000  |

### Environment Variables

```bash
# Control
INFERADB__CONTROL__STORAGE=ledger
INFERADB__CONTROL__LEDGER__ENDPOINT=http://ledger:50051
INFERADB__CONTROL__LEDGER__CLIENT_ID=control-pod-1
INFERADB__CONTROL__LEDGER__NAMESPACE_ID=1

# Engine
INFERADB__ENGINE__STORAGE__LEDGER__ENDPOINT=http://ledger:50051
INFERADB__ENGINE__AUTH__SIGNING_KEY_CACHE_TTL=300
```

## Operations

### Key Rotation

Rotate a client certificate with a grace period:

```bash
# Via API
curl -X POST https://api.inferadb.com/v1/clients/{client_id}/certificates/{cert_id}/rotate \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"grace_period_seconds": 300}'
```

Response:

```json
{
  "id": 456,
  "kid": "cert_new789",
  "private_key_pem": "-----BEGIN PRIVATE KEY-----\n...",
  "valid_from": "2025-01-21T12:05:00Z",
  "message": "New certificate created. Old key remains valid until rotation completes."
}
```

**Rotation flow:**

1. New certificate created with `valid_from` set to `now + grace_period`
2. Old certificate remains valid during grace period
3. Update clients to use new certificate
4. Old certificate naturally expires or can be manually revoked

### Key Revocation

Revoke a certificate immediately:

```bash
# Standard revocation (via Control API)
curl -X DELETE https://api.inferadb.com/v1/clients/{client_id}/certificates/{cert_id} \
  -H "Authorization: Bearer $TOKEN"
```

**Emergency revocation** (bypasses certificate lookup):

```bash
# Emergency revocation (internal endpoint, requires Engine JWT)
curl -X POST https://control.internal/internal/namespaces/{namespace_id}/keys/{kid}/revoke \
  -H "Authorization: Bearer $ENGINE_JWT" \
  -d '{"reason": "Compromised key", "actor_id": "admin@company.com"}'
```

**Revocation propagation:**

- Revoked keys have `revoked_at` timestamp set
- Engine's cache refreshes within 300s (default TTL)
- New validation requests see revoked status immediately after cache miss

### Viewing Key Status

List active keys for a namespace:

```bash
# Query Ledger directly (diagnostic)
grpcurl -plaintext ledger:50051 \
  ledger.v1.Ledger/ListEntities \
  -d '{"namespace_id": 42, "prefix": "signing-keys/"}'
```

## Monitoring

### Key Metrics

**Control metrics** (via `SigningKeyMetrics`):

| Metric                                    | Type      | Description                     |
| ----------------------------------------- | --------- | ------------------------------- |
| `signing_key_operations_total`            | Counter   | Total operations by type        |
| `signing_key_operation_duration_seconds`  | Histogram | Operation latency               |
| `signing_key_errors_total`                | Counter   | Errors by kind                  |

**Engine metrics** (via `AuthMetrics`):

| Metric                                       | Type      | Description                        |
| -------------------------------------------- | --------- | ---------------------------------- |
| `inferadb_auth_validations_total`            | Counter   | Token validations (success/fail)   |
| `inferadb_auth_cache_hits_total`             | Counter   | Signing key cache hits             |
| `inferadb_auth_cache_misses_total`           | Counter   | Signing key cache misses           |
| `inferadb_auth_ledger_key_lookup_duration_s` | Histogram | Ledger fetch latency by result     |
| `inferadb_auth_key_validation_failures_total`| Counter   | Failures by reason                 |
| `inferadb_auth_fallback_used_total`          | Counter   | Fallback cache usage (degraded)    |

### Alert Rules

```yaml
groups:
  - name: inferadb-token-validation
    rules:
      # High validation failure rate
      - alert: HighTokenValidationFailures
        expr: |
          sum(rate(inferadb_auth_validations_total{result="failure"}[5m]))
          / sum(rate(inferadb_auth_validations_total[5m])) > 0.1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High token validation failure rate (>10%)"

      # Ledger unavailable (fallback in use)
      - alert: LedgerFallbackActive
        expr: rate(inferadb_auth_fallback_used_total[5m]) > 0
        for: 1m
        labels:
          severity: warning
        annotations:
          summary: "Engine using fallback cache - Ledger may be unavailable"

      # Cache miss rate spike
      - alert: HighCacheMissRate
        expr: |
          sum(rate(inferadb_auth_cache_misses_total{cache_type="signing_key"}[5m]))
          / (sum(rate(inferadb_auth_cache_hits_total{cache_type="signing_key"}[5m]))
             + sum(rate(inferadb_auth_cache_misses_total{cache_type="signing_key"}[5m]))) > 0.5
        for: 10m
        labels:
          severity: info
        annotations:
          summary: "High cache miss rate - may indicate key churn or cold start"

      # Key validation failures (potential attack)
      - alert: KeyValidationFailuresSpike
        expr: |
          sum(rate(inferadb_auth_key_validation_failures_total[1m])) > 100
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Spike in key validation failures - possible attack or misconfiguration"
```

### Grafana Dashboard

Key panels to include:

1. **Token Validation Rate** - Success vs failure over time
2. **Cache Performance** - Hit/miss ratio
3. **Ledger Lookup Latency** - p50, p95, p99
4. **Key Validation Failures** - Breakdown by reason (revoked, expired, inactive)
5. **Fallback Usage** - Indicator of Ledger connectivity issues

## Troubleshooting

### Token Validation Failures

**Symptom**: Clients receive 401 Unauthorized

**Diagnostic steps:**

1. Check the JWT header for `kid`:
   ```bash
   echo "$JWT" | cut -d. -f1 | base64 -d 2>/dev/null | jq .
   ```

2. Verify key exists in Ledger:
   ```bash
   grpcurl -plaintext ledger:50051 \
     ledger.v1.Ledger/GetEntity \
     -d '{"namespace_id": ORG_ID, "key": "signing-keys/KID"}'
   ```

3. Check key state:
   - `active: false` → Key was deactivated
   - `revoked_at: "..."` → Key was revoked
   - `valid_from` in future → Key not yet valid (rotation grace period)
   - `valid_until` in past → Key expired

**Resolution:**

- For revoked/deactivated keys: Issue new certificate
- For not-yet-valid keys: Wait for grace period or use old key
- For expired keys: Rotate or renew certificate

### High Latency

**Symptom**: Token validation latency >100ms

**Causes:**

1. **Cache cold start**: First request after Engine restart
2. **Low cache TTL**: Increase `signing_key_cache_ttl`
3. **Ledger network issues**: Check Ledger connectivity

**Resolution:**

```bash
# Check Ledger connectivity from Engine pod
kubectl exec -n inferadb engine-pod -- \
  grpcurl -plaintext inferadb-ledger:50051 grpc.health.v1.Health/Check

# Check cache metrics
kubectl exec -n inferadb engine-pod -- \
  curl -s localhost:9090/metrics | grep inferadb_auth_cache
```

### Ledger Unavailability

**Symptom**: `inferadb_auth_fallback_used_total` increasing

**Impact:**

- Engine uses fallback cache for previously-seen keys
- New keys cannot be validated
- Key revocations not propagated until Ledger recovers

**Resolution:**

1. Check Ledger cluster health:
   ```bash
   kubectl get pods -n inferadb -l app.kubernetes.io/name=inferadb-ledger
   ```

2. Check Raft leader election:
   ```bash
   kubectl logs -n inferadb inferadb-ledger-0 | grep -i "leader"
   ```

3. Verify network connectivity between Engine and Ledger

### Key Not Found After Creation

**Symptom**: Certificate created but validation fails with "key not found"

**Causes:**

1. **Eventual consistency**: Ledger write may not be immediately visible
2. **Wrong namespace**: Certificate created in different org
3. **Ledger write failure**: Check Control logs

**Resolution:**

```bash
# Check Control logs for Ledger write
kubectl logs -n inferadb control-pod | grep -i "signing.*key"

# Verify key in correct namespace
grpcurl -plaintext ledger:50051 \
  ledger.v1.Ledger/ListEntities \
  -d '{"namespace_id": ORG_ID, "prefix": "signing-keys/"}'
```

## Security Considerations

1. **Ed25519 only**: All signing keys use Ed25519 (EdDSA) for fast, secure signatures
2. **Constant-time validation**: Key state checks use constant-time comparisons
3. **No token revocation**: Tokens are short-lived (5-15 min); key revocation is sufficient
4. **Namespace isolation**: Each organization's keys are in separate Ledger namespaces
5. **Audit trail**: All key operations logged to audit log with actor identification

## See Also

- [Ledger Deployment Guide](../guides/ledger-deployment.md)
- [Engine Configuration](../../engine/docs/guides/configuration.md)
- [Control Configuration](../../control/docs/guides/configuration.md)
