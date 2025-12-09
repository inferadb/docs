# InferaDB Documentation

Technical specifications, deployment guides, and design proposals.

## Component Documentation

Most documentation lives within component repositories:

- **[engine/](https://github.com/inferadb/engine/tree/main/docs)** — Engine docs (API, IPL, architecture)
- **[control/](https://github.com/inferadb/control/tree/main/docs)** — Control docs (authentication, entities)

## Deployment

- [Local Kubernetes Testing](deployment/local-k8s-testing.md)
- [Service Discovery](deployment/service-discovery.md)
- [Migration to Discovery](deployment/migration-to-discovery.md)
- [Tailscale Multi-Region](deployment/tailscale-multi-region.md)

## Whitepapers

- [InferaDB Technical Overview](whitepapers/InferaDB.md)

## Structure

| Directory      | Description                          |
| -------------- | ------------------------------------ |
| `deployment/`  | Kubernetes and infrastructure guides |
| `whitepapers/` | Technical publications               |
| `templates/`   | RFC template and style guide         |
| `rfcs/`        | Feature proposals (use template)     |

## Contributing

1. Copy [templates/rfc-template.md](templates/rfc-template.md) to `rfcs/XXXX-title.md`
2. Follow the [Style Guide](templates/style-guide.md)
3. Submit a pull request
