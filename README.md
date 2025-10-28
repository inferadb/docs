# **InferaDB: The Inference Database for Fine-Grained Authorization**

## **Executive Summary**

Modern applications demand fine-grained, contextual authorization systems capable of enforcing access control across distributed, multi-tenant, and multi-region environments. Traditional role-based (RBAC) and attribute-based (ABAC) systems fail to scale with the complexity of today’s ecosystems, where relationships, hierarchies, and dynamic policies define access semantics.

**InferaDB** is an inference-driven authorization database that unifies relationship-based access control (ReBAC), logical policy reasoning, and standardized interoperability through the **AuthZEN** specification. It draws inspiration from **Google Zanzibar** [1], incorporates the execution and co-location principles of **SpacetimeDB** [2], and introduces a modular, reasoning-first approach to access control through deterministic policy inference and sandboxed logic execution.

Built in **Rust** for low-latency and strong consistency, and orchestrated in **TypeScript** for developer accessibility, InferaDB delivers authorization that is **explainable, auditable, and composable** — by design.

## **1. Motivation**

### **1.1 The Challenge of Modern Authorization**

Authorization is one of the most critical yet under-engineered components of modern distributed systems. Developers often hardcode access rules, deploy unverified policy code, or rely on brittle role-based systems that collapse under the complexity of real-world resource graphs.
Common challenges include:

* Inconsistent authorization logic across services.
* Poor visibility and auditability of decisions.
* Scaling decision latency under high RPS workloads.
* Difficulty modeling relationships between entities and actions.
* Lack of standardization for interoperability and policy exchange.

**InferaDB** addresses these challenges by modeling authorization as a graph of relationships and logical inferences, not just static roles or attributes.

### **1.2 The Opportunity**

Systems like **Google Zanzibar** proved that globally consistent, fine-grained authorization is possible. However, existing open-source implementations such as **AuthZed (SpiceDB)** and **OpenFGA** focus narrowly on tuple-based access without extending into executable policy logic or inference reasoning. Meanwhile, tools like **Oso** introduce embedded logic engines but lack the distributed consistency model required for production-scale access control.

InferaDB bridges these gaps with a single mission:

> **To provide developers with a strongly consistent, inference-driven authorization system that combines logic, data, and standardization into a unified model.**

## **2. Design Philosophy**

The design of InferaDB is guided by five core principles:

| Principle                        | Description                                                                                                                                                     |
| -------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Inference as a Primitive**     | Authorization is derived from reasoning, not static checks. Each decision represents a provable inference derived from relationships, policies, and conditions. |
| **Consistency Above All**        | Strongly consistent reads and writes ensure deterministic outcomes under high concurrency.                                                                      |
| **Composable Policy Logic**      | Policies are declarative, modular, and composable. Developers can extend logic safely through sandboxed WASM modules.                                           |
| **Developer-Centric Experience** | Authorization should be understandable, testable, and observable. Tooling matters as much as throughput.                                                        |
| **Transparent Trust**            | Every decision is auditable, signed, and replayable. Determinism is verifiable through revision tokens and tamper-evident logs.                                 |

## **3. System Overview**

InferaDB consists of two core planes:

* **Control Plane:** Manages tenants, schemas, policies, and replication topology.
* **Data Plane:** Executes authorization checks in isolated, per-tenant **PDP (Policy Decision Point)** cells that co-locate computation with data.

This architecture ensures predictable performance, fault isolation, and causal consistency across globally distributed deployments.

## **4. Architecture**

### **4.1 High-Level Architecture**

```plaintext
┌──────────────────────────────────────────────────────────┐
│                   Developer Layer                        │
│  CLI • SDKs • Dashboard (Next.js)                        │
└───────────────────┬───────────────────────────────────────┘
                    │
                    ▼
┌──────────────────────────────────────────────────────────┐
│                   Control Plane                          │
│  Tenant Registry • Policy Branch Manager • Schema Store  │
│  Module Registry • Audit Log • Replication Orchestrator  │
└───────────────────┬───────────────────────────────────────┘
                    │
        ┌───────────┴───────────┬───────────┬───────────┐
        ▼                       ▼           ▼           ▼
┌────────────────┐   ┌────────────────┐   ┌────────────────┐
│ PDP Cell (A)   │   │ PDP Cell (B)   │   │ PDP Cell (C)   │
│  • Tuple Store │   │  • Tuple Store │   │  • Tuple Store │
│  • Cache       │   │  • Cache       │   │  • Cache       │
│  • Evaluator   │   │  • Evaluator   │   │  • Evaluator   │
│  • WASM Sandbox│   │  • WASM Sandbox│   │  • WASM Sandbox│
└────────────────┘   └────────────────┘   └────────────────┘
        │                       │           │
        ▼                       ▼           ▼
         ───────────► Event Bus / Replicator ◄────────────
```

Each **PDP cell** operates autonomously with local data and computation, reducing cross-region latency while preserving strong consistency through causally ordered replication.

## **5. Infera Policy Language (IPL)**

The **Infera Policy Language** (IPL) provides a declarative syntax for modeling entities, relationships, and permissions. It’s inspired by OpenFGA’s schema language but extended with conditions, contextual attributes, and logic composition.

### **Example Schema**

```praxis
entity document {
  relation viewer: user | group#member
  relation editor: user
  relation owner: user
  attribute is_public: bool

  permission view = viewer or editor or (is_public == true)
  permission edit = editor or owner
}
```

### **Computed Conditions**

```praxis
context time_now: datetime

permission view = viewer or (is_public == true and time_now < resource.expiry)
```

### **Goals**

* **Deterministic:** Same data and inputs → same result.
* **Composable:** Policies can reference other permissions or modules.
* **Validatable:** Pre-deployment linting and static analysis ensure safety.

## **6. WASM Policy Modules**

To support advanced, programmable logic safely, InferaDB introduces **WASM Policy Modules** — lightweight, tenant-scoped logic extensions executed within PDP cells.

### **Example**

```typescript
// module.can_edit.ts
export function can_edit(context, resource, subject) {
  return resource.status === "active" && subject.role === "editor";
}
```

Modules are:

* **Compiled to WASM** and signed per tenant.
* **Executed deterministically** with strict CPU/memory limits.
* **Sandboxed:** No I/O, no network access.
* **Versioned and auditable:** Each invocation is logged with its version hash.

This design combines the safety of declarative policies with the expressiveness of procedural extensions.

## **7. Consistency Model**

### **7.1 Revision Tokens (Zookies)**

Every authorization decision references a **revision token**, representing a consistent snapshot of the relationship graph at a given point in time.

### **7.2 Replication**

* **Writes:** Linearizable and region-local.
* **Reads:** Snapshot-isolated via revision tokens.
* **Replication:** Causally ordered via version vectors and event streams.
* **Conflict Resolution:** Single-writer-per-key model ensures determinism.

## **8. Scalability and Performance**

Inspired by **SpacetimeDB**, each PDP cell combines local tuple storage with co-located inference computation, achieving sub-10ms median latency even under multi-tenant workloads.

### **Scaling Mechanisms**

* **Sharding by tenant or namespace.**
* **Horizontal PDP scaling with cell discovery.**
* **Multi-tier caching (in-memory + distributed).**
* **Batch and streaming tuple ingestion.**

Target scalability: **1M+ checks per second across regions.**

## **9. Security Model**

| Concern              | Mechanism                                               |
| -------------------- | ------------------------------------------------------- |
| **Isolation**        | Per-tenant namespaces and PDP sandboxes.                |
| **Module Safety**    | WASM runtime with signed, deterministic bytecode.       |
| **Data Protection**  | End-to-end mTLS and per-tenant encryption keys.         |
| **Auditability**     | Append-only, hash-chained decision logs.                |
| **Tamper Detection** | Policy and schema signatures verified before execution. |

## **10. Developer Experience**

### **10.1 CLI**

`infera` — a unified command-line tool for:

* Initializing projects and schemas.
* Branching and merging policies.
* Uploading modules.
* Simulating authorization checks.

Example:

```bash
infera policy branch feature/new-rule
infera simulate --resource document:1 --subject user:evan
infera merge feature/new-rule
```

### **10.2 SDKs**

Official SDKs for **Go**, **Python**, **TypeScript**, **Rust**, **PHP**, and **Ruby** provide idiomatic bindings for:

* Tuple operations.
* Policy checks.
* Audit log queries.
* AuthZEN-compatible decision requests.

### **10.3 Dashboard**

The **Infera Dashboard** allows developers to visualize schemas, simulate access paths, and analyze decision traces in real time.

## **11. Implementation Overview**

| Component                  | Language          | Description                                            |
| -------------------------- | ----------------- | ------------------------------------------------------ |
| **Server (PDP Engine)**    | Rust              | Core inference and policy evaluation engine.           |
| **API (Control Plane)**    | TypeScript        | Tenant management, policy registry, audit log API.     |
| **Dashboard (UI)**         | TypeScript        | Web interface for visualization and simulation.        |
| **WASM Modules**           | Rust / TypeScript | Sandbox-executed custom policy logic.                  |
| **Meta-Repo (`inferadb`)** | N/A               | Orchestration and containerization of the full system. |

## **12. Deployment and Infrastructure**

### **12.1 Local Development**

* **Docker Compose** or **Tilt** for rapid iteration.
* Local FoundationDB or CockroachDB for tuple storage.
* Hot reload of dashboard and API containers.

### **12.2 Production**

* **Kubernetes (Helm)** for orchestrating multi-tenant clusters.
* **Terraform** for provisioning infrastructure.
* **GitHub Actions** for CI/CD pipelines.

### **12.3 Meta-Repo Organization**

```
inferadb/
├── server/      # Rust PDP
├── api/         # TypeScript control plane
├── dashboard/   # Next.js dashboard
├── docker/      # Compose files
├── k8s/         # Kubernetes manifests
├── infra/       # Terraform, Helm, Tilt
└── config/      # Shared configuration
```

## **13. Comparison to Related Systems**

| System                  | Description                                 | Key Differences                                                              |
| ----------------------- | ------------------------------------------- | ---------------------------------------------------------------------------- |
| **Google Zanzibar [1]** | Global ReBAC model with strong consistency. | InferaDB builds upon this model but adds policy logic and modular inference. |
| **AuthZed (SpiceDB)**   | Zanzibar-style open-source engine.          | InferaDB adds inference DSL, WASM runtime, and AuthZEN compliance.           |
| **OpenFGA**             | Simplified Zanzibar implementation by Meta. | InferaDB offers stronger policy reasoning and modularity.                    |
| **Oso**                 | Embedded policy engine (Polar language).    | InferaDB is distributed, consistent, and language-agnostic.                  |
| **AuthZEN**             | Open standard for authorization APIs.       | InferaDB natively supports and extends the AuthZEN API model.                |

## **14. Roadmap**

| Phase          | Focus            | Description                                             |
| -------------- | ---------------- | ------------------------------------------------------- |
| **v0.1 (MVP)** | Core PDP         | Strong consistency, IPL DSL, AuthZEN API.               |
| **v1.0**       | Production-ready | Multi-tenant architecture, WASM runtime, audit logs.    |
| **v1.5**       | Multi-region     | Causal replication, edge PDPs, event streaming.         |
| **v2.0**       | Enterprise       | Policy analytics, attestations, managed cloud offering. |

## **15. Conclusion**

InferaDB represents a next-generation approach to authorization — where policies are logic, decisions are proofs, and relationships form the foundation of access reasoning.
By combining the consistency of Zanzibar, the interoperability of AuthZEN, and the composability of WASM-based modules, InferaDB establishes a new standard for trust, transparency, and developer experience in distributed access control.

> **Authorize by Reason, at Scale.**

## **References**

[1] Google Zanzibar: Google’s Consistent, Global Authorization System — *USENIX ATC 2019.*
[2] SpacetimeDB: A Stateful Database with Co-located Compute.
[3] AuthZEN: OpenID Foundation Authorization API Specification (v1.0).
[4] AuthZed / SpiceDB: Open-source Zanzibar implementation.
[5] OpenFGA: Fine-grained authorization by Meta.
[6] Oso: Policy engine for application-level authorization.

Would you like me to include a **visual architecture diagram (in Markdown-friendly text + mermaid)** to accompany this whitepaper?
It would illustrate the Control Plane, PDP Cells, and Replication model directly inside the document.
