#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="latest"
VERSION=""

for arg in "$@"; do
    case "$arg" in
        dotnet)
            TARGET="dotnet"
            ;;
        ml)
            TARGET="ml"
            ;;
        all)
            TARGET="all"
            ;;
        latest|base)
            TARGET="latest"
            ;;
        *)
            if [ -z "$VERSION" ]; then
                VERSION="$arg"
            fi
            ;;
    esac
done

if [ -z "$VERSION" ]; then
    VERSION=$(podman run --rm node:lts-slim npm view opencode-ai version 2>/dev/null || echo latest)
fi

echo "Versão do opencode-ai para o build: $VERSION"

build_base() {
    echo "Construindo imagem opencode:latest a partir de $DIR/Dockerfile..."
    podman build --layers=false --build-arg OPENCODE_VERSION="$VERSION" -t opencode:latest -t opencode -f "$DIR/Dockerfile" "$DIR"
}

build_dotnet() {
    if ! podman image exists opencode:latest 2>/dev/null; then
        build_base
    fi
    echo "Construindo imagem opencode:dotnet a partir de $DIR/Dockerfile.dotnet (sobre opencode:latest)..."
    podman build --layers=false -t opencode:dotnet -f "$DIR/Dockerfile.dotnet" "$DIR"
}

build_ml() {
    if ! podman image exists opencode:dotnet 2>/dev/null; then
        build_dotnet
    fi
    echo "Construindo imagem opencode:ml a partir de $DIR/Dockerfile.ml (sobre opencode:dotnet)..."
    podman build --layers=false -t opencode:ml -f "$DIR/Dockerfile.ml" "$DIR"
}

case "$TARGET" in
    dotnet)
        build_dotnet
        ;;
    ml)
        build_ml
        ;;
    all)
        build_base
        build_dotnet
        build_ml
        ;;
    latest)
        build_base
        ;;
esac

echo "Limpando camadas intermediárias e imagens não tagueadas..."
podman image prune -f 2>/dev/null || true
echo "Build concluído com sucesso!"
