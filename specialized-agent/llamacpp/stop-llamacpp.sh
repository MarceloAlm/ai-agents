#!/bin/bash
# stop-llamacpp.sh - Encerra o container do llama-server
set -e

CONTAINER_CMD="${CONTAINER_TOOL:-podman}"
if ! command -v "$CONTAINER_CMD" >/dev/null 2>&1; then
    CONTAINER_CMD="docker"
fi

echo "Encerrando container 'llamacpp'..."
$CONTAINER_CMD rm -f llamacpp 2>/dev/null || true
echo "Container 'llamacpp' finalizado com sucesso."
