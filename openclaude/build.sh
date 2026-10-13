#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Detecta runtime: podman ou docker
if command -v podman >/dev/null 2>&1; then
    ENGINE="podman"
    BUILD_FLAGS=(--layers=false --squash)
elif command -v docker >/dev/null 2>&1; then
    ENGINE="docker"
    BUILD_FLAGS=(--no-cache)
else
    echo "Erro: nem 'podman' nem 'docker' foram encontrados no PATH do sistema." >&2
    exit 1
fi

echo "Motor de container detectado: $ENGINE"
echo "Construindo imagem openclaude:latest..."
"$ENGINE" build "${BUILD_FLAGS[@]}" -t openclaude:latest -t openclaude "$DIR"

echo "Limpando camadas intermediárias e imagens órfãs (dangling)..."
"$ENGINE" image prune -f 2>/dev/null || true
echo "Build do openclaude concluído com sucesso!"