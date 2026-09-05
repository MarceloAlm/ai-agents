#!/bin/bash
set -e

IMAGE_NAME="ai-stack-allinone"
CONTAINER_NAME="ollama"

echo "Construindo a imagem unificada $IMAGE_NAME..."
podman build -t $IMAGE_NAME .

echo "Subindo o container com GPU NVIDIA..."
podman run --rm \
  --name $CONTAINER_NAME \
  --security-opt label=disable \
  --device nvidia.com/gpu=all \
  -v ollama-store:/root/.ollama \
  -p 11434:11434 \
  -p 4000:4000 \
  $IMAGE_NAME

echo "Container gerado com sucesso!"
echo "Acompanhe o boot digitando: podman logs -f $CONTAINER_NAME"
