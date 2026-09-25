#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "Construindo imagem specialized-agent..."
podman build -t specialized-agent "$DIR"
