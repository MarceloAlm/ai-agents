#!/bin/bash
VERSION="${1:-latest}"
podman build --build-arg OPENCODE_VERSION=$VERSION -t opencode ./opencode
