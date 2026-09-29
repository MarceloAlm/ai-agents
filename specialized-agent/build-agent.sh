#!/bin/bash
# build-agent.sh - Compila a imagem leve do agente desacoplado (sem Ollama embutido)
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTAINER_CMD="${CONTAINER_TOOL:-podman}"
if ! command -v "$CONTAINER_CMD" >/dev/null 2>&1; then
    CONTAINER_CMD="docker"
fi

echo "Construindo imagem leve specialized-agent:standalone (Python 3.12)..."
$CONTAINER_CMD build -t specialized-agent:standalone -f "$DIR/Dockerfile.agent" "$DIR"
echo "Imagem construída com sucesso: specialized-agent:standalone"
