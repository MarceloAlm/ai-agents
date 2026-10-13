#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="latest"
VERSION=""

# Detecta runtime: podman ou docker
if command -v podman >/dev/null 2>&1; then
    ENGINE="podman"
elif command -v docker >/dev/null 2>&1; then
    ENGINE="docker"
else
    echo "Erro: nem 'podman' nem 'docker' foram encontrados no PATH do sistema." >&2
    exit 1
fi

echo "Motor de container detectado: $ENGINE"

BUILD_OPTS=()
if [ "$ENGINE" = "podman" ]; then
    BUILD_OPTS+=(--squash)
fi

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
    VERSION=$("$ENGINE" run --rm node:lts-slim npm view opencode-ai version 2>/dev/null || echo latest)
fi

echo "Versão do opencode-ai para o build: $VERSION"

image_exists() {
    local img="$1"
    if [ "$ENGINE" = "podman" ]; then
        podman image exists "$img" 2>/dev/null
    else
        docker image inspect "$img" >/dev/null 2>&1
    fi
}

build_base() {
    echo "Construindo imagem opencode:latest a partir de $DIR/Dockerfile..."
    "$ENGINE" build "${BUILD_OPTS[@]}" --build-arg OPENCODE_VERSION="$VERSION" -t opencode:latest -t opencode -f "$DIR/Dockerfile" "$DIR"
}

build_dotnet() {
    if ! image_exists opencode:latest; then
        build_base
    fi
    echo "Construindo imagem opencode:dotnet a partir de $DIR/Dockerfile.dotnet (sobre opencode:latest)..."
    "$ENGINE" build "${BUILD_OPTS[@]}" -t opencode:dotnet -f "$DIR/Dockerfile.dotnet" "$DIR"
}

build_ml() {
    if ! image_exists opencode:dotnet; then
        build_dotnet
    fi
    echo "Construindo imagem opencode:ml a partir de $DIR/Dockerfile.ml (sobre opencode:dotnet)..."
    "$ENGINE" build "${BUILD_OPTS[@]}" -t opencode:ml -f "$DIR/Dockerfile.ml" "$DIR"
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

echo "Limpando camadas intermediárias e imagens órfãs (dangling)..."
"$ENGINE" image prune -f 2>/dev/null || true
echo "Build do opencode concluído com sucesso!"
