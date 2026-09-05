#!/bin/bash
VERSION="${1:-}"
if [ -z "$VERSION" ]; then
    VERSION=$(podman run --rm node:lts-slim npm view opencode-ai version 2>/dev/null || echo latest)
fi
podman build --build-arg OPENCODE_VERSION=$VERSION -t opencode ./opencode
