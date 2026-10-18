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
else
    # RUN --mount=type=bind exige BuildKit (padrão no docker ≥ 23)
    export DOCKER_BUILDKIT=1
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
            if [ -n "$VERSION" ] || ! [[ "$arg" =~ ^[0-9]+(\.[0-9A-Za-z-]+)*$ ]]; then
                echo "Erro: argumento não reconhecido: '$arg'" >&2
                echo "Uso: ./build.sh [base|dotnet|ml|all] [versão (ex.: 2.0.32)]" >&2
                exit 1
            fi
            VERSION="$arg"
            ;;
    esac
done

if [ -z "$VERSION" ]; then
    VERSION=$("$ENGINE" run --rm node:lts-slim npm view @opencode/cli version 2>/dev/null || echo latest)
fi

# Carimbo da versão da imagem: gravado pelo Dockerfile em
# /etc/opencode/.image-version e usado para atualizar o perfil na 1ª
# execução de cada build. Sobrescrevível: IMAGE_VERSION=x ./build.sh
IMAGE_VERSION="${IMAGE_VERSION:-$(date -u +%Y%m%d-%H%M%S)}"

echo "Versão do @opencode/cli (OpenCode 2) para o build: $VERSION"
echo "Carimbo de versão da imagem (→ /etc/opencode/.image-version): $IMAGE_VERSION"

# Hashes dos scripts de setup: os Dockerfiles montam os scripts por bind
# (sem camada temporária) e usam o hash para invalidar o cache do RUN com a
# mesma semântica do COPY — engines antigas não hasheavam o conteúdo montado
SETUP_HASH_BASE="$(sha256sum "$DIR/scripts/setup-base.sh" | cut -d' ' -f1)"
SETUP_HASH_DOTNET="$(sha256sum "$DIR/scripts/setup-dotnet.sh" | cut -d' ' -f1)"
SETUP_HASH_ML="$(sha256sum "$DIR/scripts/setup-ml.sh" | cut -d' ' -f1)"

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
    "$ENGINE" build "${BUILD_OPTS[@]}" --build-arg OPENCODE_VERSION="$VERSION" --build-arg IMAGE_VERSION="$IMAGE_VERSION" --build-arg SETUP_HASH="$SETUP_HASH_BASE" -t opencode:latest -t opencode -f "$DIR/Dockerfile" "$DIR"
}

build_dotnet() {
    if ! image_exists opencode:latest; then
        build_base
    fi
    echo "Construindo imagem opencode:dotnet a partir de $DIR/Dockerfile.dotnet (sobre opencode:latest)..."
    "$ENGINE" build "${BUILD_OPTS[@]}" --build-arg SETUP_HASH="$SETUP_HASH_DOTNET" -t opencode:dotnet -f "$DIR/Dockerfile.dotnet" "$DIR"
}

build_ml() {
    if ! image_exists opencode:dotnet; then
        build_dotnet
    fi
    echo "Construindo imagem opencode:ml a partir de $DIR/Dockerfile.ml (sobre opencode:dotnet)..."
    "$ENGINE" build "${BUILD_OPTS[@]}" --build-arg SETUP_HASH="$SETUP_HASH_ML" -t opencode:ml -f "$DIR/Dockerfile.ml" "$DIR"
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
