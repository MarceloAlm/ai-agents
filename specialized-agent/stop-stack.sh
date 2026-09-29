#!/bin/bash
# stop-stack.sh - Finaliza os containers da stack desacoplada
set -e

CONTAINER_CMD="${CONTAINER_TOOL:-podman}"
if ! command -v "$CONTAINER_CMD" >/dev/null 2>&1; then
    CONTAINER_CMD="docker"
fi

echo "Encerrando containers da stack isolada (ollama, llamacpp, searxng)..."
$CONTAINER_CMD rm -f ollama llamacpp searxng 2>/dev/null || true
echo "Containers finalizados com sucesso."
