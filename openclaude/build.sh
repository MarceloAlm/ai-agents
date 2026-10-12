#!/bin/bash
podman build --layers=false -t openclaude ./openclaude
podman image prune -f 2>/dev/null || true