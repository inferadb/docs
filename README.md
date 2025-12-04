# InferaDB Documentation

Technical specifications, design documents, and deployment guides for InferaDB.

## Structure

| Directory       | Description                                        | Status      |
| --------------- | -------------------------------------------------- | ----------- |
| `whitepapers/`  | Long-form technical documents and publications     | Active      |
| `deployment/`   | Kubernetes, multi-region, and local testing guides | Active      |
| `templates/`    | Document templates for RFCs and design docs        | Active      |
| `rfcs/`         | Feature and design proposals                       | Placeholder |
| `designs/`      | Deep dives into subsystems and components          | Placeholder |
| `diagrams/`     | Architecture and flow diagrams                     | Placeholder |
| `guides/`       | Contributor and authoring guides                   | Placeholder |
| `architecture/` | High-level architecture documentation              | Placeholder |

## Component Documentation

Most documentation lives within component directories:

- **[server/docs/](../server/docs/)** - Comprehensive server documentation (API, architecture, operations, security)
- **[management/docs/](../management/docs/)** - Management API documentation (authentication, flows, deployment)

## Deployment Guides

- [Local Kubernetes Testing](deployment/local-k8s-testing.md) - Set up local K8s cluster for development
- [Service Discovery](deployment/service-discovery.md) - Multi-instance service discovery configuration
- [Tailscale Multi-Region](deployment/tailscale-multi-region.md) - Cross-region deployment with Tailscale

## How to Propose a Change

1. Fork this repository
2. Copy `templates/rfc-template.md` into `rfcs/`
3. Name your file `XXXX-short-title.md` where `XXXX` is the next available number
4. Submit a pull request describing your proposal
5. Discussion happens in the PR and on the relevant GitHub Discussions thread
