<div align="center">
    <p><a href="https://inferadb.com"><img src=".github/inferadb.png" width="100" /></a></p>
    <h1>InferaDB Documentation</h1>
    <p>Technical specifications, deployment guides, and design proposals</p>
</div>

Most documentation lives within component repositories:

- **[engine/](https://github.com/inferadb/engine/tree/main/docs)** — Engine docs (API, IPL, architecture)
- **[control/](https://github.com/inferadb/control/tree/main/docs)** — Control docs (authentication, entities)

Deployment documentation lives in the [deploy repository](https://github.com/inferadb/deploy/tree/main/docs).

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
