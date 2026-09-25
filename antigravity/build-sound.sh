#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "Construindo imagem antigravity:sound a partir de $DIR/Dockerfile.sound..."
podman build -t antigravity:sound -f "$DIR/Dockerfile.sound" "$DIR"
