#!/bin/bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${1:-latest}"

if [ "$TARGET" = "sound" ]; then
    echo "Construindo imagem antigravity:sound a partir de $DIR/Dockerfile.sound..."
    podman build -t antigravity:sound -f "$DIR/Dockerfile.sound" "$DIR"
else
    podman build -t antigravity:latest -t antigravity "$DIR"
fi