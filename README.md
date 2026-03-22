# score-cache

OCI container providing fast, hermetic Bazel build caching via:

- **nginx** — reverse proxy and single entry-point for all cache services
- **Sonatype Nexus OSS** — artifact proxy for Cargo, PyPI, OCI and raw Bazel rule archives
- **bazel-remote** — dedicated Bazel remote cache speaking the REAPI protocol (HTTP + gRPC)

## Quick start

> Requires: Docker, Docker Compose, [go-task](https://taskfile.dev)

```bash
# Start the stack
task score-cache:up

# Provision Nexus proxy repositories (first run only)
task score-cache:configure-nexus

# Run integration tests
task score-cache:test

# Build and tag the nginx image
task score-cache:build

# Push to GHCR
task score-cache:push
```

## Service endpoints

| Route | Backend | Protocol |
|---|---|---|
| `http://localhost/cargo/` | Nexus `cargo-proxy` | HTTP |
| `http://localhost/pypi/` | Nexus `pypi-proxy` | HTTP |
| `http://localhost/v2/` | Nexus `oci-proxy` | Docker Distribution API |
| `http://localhost/rules/` | Nexus `rules-proxy` (raw) | HTTP |
| `http://localhost/cache/` | bazel-remote HTTP REAPI | HTTP |
| `localhost:9093` | bazel-remote gRPC REAPI | gRPC / HTTP2 |
| `http://localhost/nexus/` | Nexus admin UI | HTTP |
| `http://localhost/health` | nginx health probe | HTTP |

## Bazel configuration

```python
# .bazelrc
build --remote_cache=grpc://localhost:9093
build --repository_cache=/tmp/bazel-repo-cache
```

## Taskfile variables

All paths are variables with sensible defaults and can be overridden at the CLI:

| Variable | Default | Description |
|---|---|---|
| `result_folder` | `../../build/` | Build output directory |
| `common_tasks` | `../../images/tasks/` | Shared task files |
| `registry` | `ghcr.io` | Container registry |
| `image_owner` | `nick-hildebrant-etas` | Registry namespace |
| `image_name` | `score-cache/nginx` | Image name |
| `image_tag` | `latest` | Image tag |
| `compose_file` | `docker-compose.yml` | Compose file path |
| `HTTP_PORT` | `80` | nginx HTTP port |
| `GRPC_PORT` | `9093` | bazel-remote gRPC port |
| `BAZEL_REMOTE_MAX_SIZE_GB` | `10` | bazel-remote max cache size (GiB) |

## Ubuntu cloud image (aarch64)

Download the pre-built Ubuntu Noble 24.04 LTS aarch64 cloud image (no image
build step needed — boots directly):

```bash
task score-cache:download-cloud-image
```

## Devcontainer

The devcontainer runs headlessly via Docker — no VS Code required:

```bash
devcontainer up --workspace-folder .
devcontainer exec --workspace-folder . task --list
```

