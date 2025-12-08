# InferaDB Documentation

Technical specifications, design documents, and deployment guides.

## Structure

| Directory       | Description                                    |
| --------------- | ---------------------------------------------- |
| `whitepapers/`  | Long-form technical documents and publications |
| `deployment/`   | Kubernetes, multi-region, and testing guides   |
| `templates/`    | Document templates and style guide             |
| `rfcs/`         | Feature and design proposals                   |
| `designs/`      | Deep dives into subsystems                     |
| `diagrams/`     | Architecture and flow diagrams                 |

## Component Documentation

Most documentation lives within component directories:

- **[engine/docs/](../engine/docs/)** — Engine documentation (API, architecture, security)
- **[control/docs/](../control/docs/)** — Control API documentation (authentication, deployment)

## Deployment Guides

- [Local Kubernetes Testing](deployment/local-k8s-testing.md)
- [Service Discovery](deployment/service-discovery.md)
- [Tailscale Multi-Region](deployment/tailscale-multi-region.md)

## Style Guide

All documentation follows [templates/style-guide.md](templates/style-guide.md):

- **File naming**: `kebab-case.md`
- **Headers**: Plain text Title Case
- **Diagrams**: Mermaid instead of ASCII art
- **Code blocks**: Always specify language tags

## Proposing Changes

1. Fork the repository
2. Copy `templates/rfc-template.md` into `rfcs/`
3. Name your file `XXXX-short-title.md`
4. Follow the [Style Guide](templates/style-guide.md)
5. Submit a pull request
