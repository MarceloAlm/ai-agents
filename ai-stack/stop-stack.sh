#!/bin/bash
# stop-stack.sh - Encerra todos os serviços do Hub AI-Stack
set -e

CONTAINER_CMD="${CONTAINER_TOOL:-podman}"
if ! command -v "$CONTAINER_CMD" >/dev/null 2>&1; then
    CONTAINER_CMD="docker"
fi

echo "Encerrando containers da ai-stack ($CONTAINER_CMD)..."
$CONTAINER_CMD rm -f llamacpp ollama searxng 2>/dev/null || true

echo "Serviços encerrados com sucesso."
