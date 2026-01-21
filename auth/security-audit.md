# Security Audit: Ledger-Based Token Validation

**Audit Date**: 2026-01-21  
**Audited By**: Ralph (automated agent)  
**Status**: Completed with findings

## Executive Summary

This audit reviewed the Ledger-based token validation implementation against the security checklist defined in PRD Task 11. The implementation demonstrates sound cryptographic practices but has gaps in information leakage prevention and audit trail completeness.

**Critical Findings**: 0  
**High Findings**: 1 (Information leakage via error messages)  
**Medium Findings**: 2 (Incomplete audit logging, missing rate limiting)  
**Low Findings**: 1 (Actor ID not in Ledger entity)

---

## Checklist Results

### 1. ✅ Ed25519 signature verification uses constant-time comparison

**Status**: PASS

**Analysis**: The `jsonwebtoken` crate v10.x uses the `ring` cryptographic library for Ed25519 signature verification. Ring implements constant-time comparison for cryptographic operations, preventing timing attacks on signature validation.

**Evidence**:
- `engine/crates/inferadb-engine-auth/src/jwt.rs`: `verify_signature()` calls `jsonwebtoken::decode()`
- jsonwebtoken internally uses ring's `signature::verify()` which is constant-time

### 2. ❌ Key lookup errors don't leak key existence

**Status**: FAIL - Information leakage

**Finding**: The `AuthError` enum exposes different error variants that reveal key state:
- `KeyNotFound { kid }` - Key doesn't exist
- `KeyRevoked { kid }` - Key exists but was revoked  
- `KeyInactive { kid }` - Key exists but is disabled
- `KeyExpired { kid }` - Key exists but expired

In `grpc_interceptor.rs`, these errors are converted to gRPC responses with `error.to_string()`, exposing the specific error message to clients.

**Impact**: An attacker can enumerate valid key IDs by distinguishing "not found" from "revoked/inactive" responses.

**Mitigation**: Return a generic "Authentication failed" message externally while logging the specific reason internally.

**Files affected**:
- `engine/crates/inferadb-engine-auth/src/error.rs`
- `engine/crates/inferadb-engine-api/src/grpc_interceptor.rs`
- `engine/crates/inferadb-engine-auth/src/middleware.rs`

### 3. ❌ Key revocation checks don't leak key status to attackers

**Status**: FAIL - Same as #2

**Finding**: This is the same underlying issue as #2. The distinct error messages allow attackers to determine if a key was revoked vs never existed.

### 4. ⚠️ All Ledger writes include actor identification

**Status**: PARTIAL

**Finding**: The `PublicSigningKey` struct lacks a `created_by` field. While the audit log captures `user_id` for some operations, the Ledger entity itself doesn't record who created or modified it.

**Current state**: `create_certificate` handler has access to `org_ctx.member.user_id` but doesn't include it in `PublicSigningKey`.

**Recommendation**: Add `created_by: Option<i64>` field to `PublicSigningKey` struct.

### 5. ⚠️ All key operations are logged to audit trail

**Status**: PARTIAL

**Finding**: Audit coverage is incomplete:
- ✅ Certificate revocation: Logged via `AuditEventType::ClientCertificateRevoked`
- ✅ Emergency revocation: Logged with `emergency: true` flag
- ❌ Certificate creation: `AuditEventType::ClientCertificateCreated` exists but not used
- ❌ Certificate rotation: No audit event logged

**Recommendation**: Add `log_audit_event` calls to `create_certificate` and `rotate_certificate` handlers.

### 6. ⚠️ No sensitive data in error messages

**Status**: PARTIAL

**Finding**: 
- ✅ Private keys never exposed in errors
- ✅ Token contents not logged
- ⚠️ Key IDs (`kid`) are included in error messages

Key IDs are not cryptographically sensitive, but they can aid enumeration attacks (see #2).

### 7. ❌ Rate limiting on key lookup failures

**Status**: FAIL - Not implemented

**Finding**: The `SigningKeyCache::get_decoding_key()` method has no rate limiting on failed lookups. Repeated authentication failures with invalid/revoked keys don't trigger any throttling.

**Impact**: Low severity because:
- Key IDs are UUIDs, making brute-force impractical
- Most attacks would come via compromised tokens, not key enumeration

**Recommendation**: Implement a token bucket or leaky bucket rate limiter on the authentication middleware layer, keyed by client IP.

### 8. ✅ Cache timing doesn't leak key existence

**Status**: PASS

**Analysis**: The `SigningKeyCache` implementation has timing characteristics that don't meaningfully leak information:

- **Cache hit**: Returns immediately (fast path)
- **Cache miss**: Fetches from Ledger, then validates (slow path)

The timing difference between hit/miss is observable but not exploitable:
1. The key ID comes from the JWT header (attacker-supplied), not enumeration
2. All error paths after Ledger fetch have similar timing
3. The cache stores successfully validated keys, not arbitrary lookups

---

## Recommendations by Priority

### High Priority

1. **Unify authentication error responses** (Addresses #2, #3, #6)
   - Create a generic "Authentication failed" message for all key-related errors
   - Log specific error internally for debugging
   - Update `auth_error_to_status()` in grpc_interceptor.rs

### Medium Priority

2. **Complete audit trail coverage** (Addresses #5)
   - Add `log_audit_event(AuditEventType::ClientCertificateCreated, ...)` to `create_certificate`
   - Add `log_audit_event(AuditEventType::ClientCertificateRotated, ...)` to `rotate_certificate`
   - Create `AuditEventType::ClientCertificateRotated` enum variant

3. **Implement rate limiting** (Addresses #7)
   - Add rate limiting middleware to authentication endpoints
   - Consider IP-based and org-based rate limits
   - Return 429 Too Many Requests for exceeded limits

### Low Priority

4. **Add actor identification to Ledger entities** (Addresses #4)
   - Add `created_by: Option<i64>` to `PublicSigningKey`
   - Populate from `org_ctx.member.user_id` in handlers
   - Aids forensic investigation without querying audit logs

---

## Verification Pending

The following items require additional verification:

- [ ] Security review completed by second engineer
- [ ] All findings acknowledged by security team
- [ ] High-priority mitigations implemented
- [ ] Penetration test scheduled for production deployment

---

## Files Reviewed

- `engine/crates/inferadb-engine-auth/src/signing_key_cache.rs`
- `engine/crates/inferadb-engine-auth/src/jwt.rs`
- `engine/crates/inferadb-engine-auth/src/error.rs`
- `engine/crates/inferadb-engine-auth/src/middleware.rs`
- `engine/crates/inferadb-engine-api/src/grpc_interceptor.rs`
- `common/crates/inferadb-storage/src/auth/signing_key.rs`
- `common/crates/inferadb-storage-ledger/src/auth.rs`
- `control/crates/inferadb-control-api/src/handlers/clients.rs`
