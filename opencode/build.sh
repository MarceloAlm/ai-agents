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
        all)
            TARGET="all"
            ;;
        latest|base)
            TARGET="latest"
            ;;
        *)
            if [ -n "$VERSION" ] || ! [[ "$arg" =~ ^[0-9]+(\.[0-9A-Za-z-]+)*$ ]]; then
                echo "Erro: argumento não reconhecido: '$arg'" >&2
                echo "Uso: ./build.sh [base|dotnet|all] [versão (ex.: 2.4.2)]" >&2
                exit 1
            fi
            VERSION="$arg"
            ;;
    esac
done

if [ -z "$VERSION" ]; then
    if command -v curl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
        VERSION=$(curl -fsSL https://registry.npmjs.org/@opencode/cli/latest 2>/dev/null | jq -r '.version // empty' || true)
    fi
    if [ -z "$VERSION" ]; then
        VERSION=$("$ENGINE" run --rm debian:trixie-slim bash -c 'apt-get update -qq && apt-get install -y -qq curl jq >/dev/null && curl -fsSL https://registry.npmjs.org/@opencode/cli/latest | jq -r .version' 2>/dev/null || echo latest)
    fi
elif [ "$VERSION" = "1" ]; then
    if command -v curl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
        VERSION=$(curl -fsSL https://registry.npmjs.org/opencode-ai/latest 2>/dev/null | jq -r '.version // empty' || true)
    fi
    VERSION="${VERSION:-1}"
fi

# Define estratégia de tags conforme major version:
# - v2 (padrão): opencode:2.0 -> opencode:latest (+ opencode:<versão> se específica)
# - v1 (revisões 1.*): opencode:1 + opencode:<versão> (sem sobrescrever :latest)
if [[ "$VERSION" =~ ^1(\.|$) ]]; then
    MAJOR="1"
    BASE_TAG="opencode:1"
    DOTNET_TAG="opencode:1-dotnet"
    BASE_EXTRA_TAGS=(-t "opencode:${VERSION}")
    DOTNET_EXTRA_TAGS=(-t "opencode:${VERSION}-dotnet")
    echo "Versão do opencode-ai (OpenCode 1) para o build: $VERSION"
else
    MAJOR="2"
    BASE_TAG="opencode:latest"
    DOTNET_TAG="opencode:dotnet"
    BASE_EXTRA_TAGS=(-t opencode:2.0 -t opencode)
    if [ "$VERSION" != "latest" ] && [ "$VERSION" != "2.0" ]; then
        BASE_EXTRA_TAGS+=(-t "opencode:${VERSION}")
    fi
    DOTNET_EXTRA_TAGS=(-t opencode:2.0-dotnet)
    echo "Versão do @opencode/cli (OpenCode 2) para o build: $VERSION"
fi

# Carimbo da versão da imagem: gravado pelo Dockerfile em
# /etc/opencode/.image-version e usado para atualizar o perfil na 1ª
# execução de cada build. Sobrescrevível: IMAGE_VERSION=x ./build.sh
IMAGE_VERSION="${IMAGE_VERSION:-$(date -u +%Y%m%d-%H%M%S)}"

echo "Carimbo de versão da imagem (→ /etc/opencode/.image-version): $IMAGE_VERSION"

# Hashes dos scripts de setup: os Dockerfiles montam os scripts por bind
# (sem camada temporária) e usam o hash para invalidar o cache do RUN com a
# mesma semântica do COPY — engines antigas não hasheavam o conteúdo montado
SETUP_HASH_BASE="$(sha256sum "$DIR/scripts/setup-base.sh" | cut -d' ' -f1)"
SETUP_HASH_DOTNET="$(sha256sum "$DIR/scripts/setup-dotnet.sh" | cut -d' ' -f1)"

image_exists() {
    local img="$1"
    if [ "$ENGINE" = "podman" ]; then
        podman image exists "$img" 2>/dev/null
    else
        docker image inspect "$img" >/dev/null 2>&1
    fi
}

build_base() {
    echo "Construindo imagem $BASE_TAG a partir de $DIR/Dockerfile..."
    "$ENGINE" build "${BUILD_OPTS[@]}" --build-arg OPENCODE_VERSION="$VERSION" --build-arg IMAGE_VERSION="$IMAGE_VERSION" --build-arg SETUP_HASH="$SETUP_HASH_BASE" -t "$BASE_TAG" "${BASE_EXTRA_TAGS[@]}" -f "$DIR/Dockerfile" "$DIR"
}

build_dotnet() {
    if ! image_exists "$BASE_TAG"; then
        build_base
    fi
    echo "Construindo imagem $DOTNET_TAG a partir de $DIR/Dockerfile.dotnet (sobre $BASE_TAG)..."
    "$ENGINE" build "${BUILD_OPTS[@]}" --build-arg BASE_IMAGE="$BASE_TAG" --build-arg SETUP_HASH="$SETUP_HASH_DOTNET" -t "$DOTNET_TAG" "${DOTNET_EXTRA_TAGS[@]}" -f "$DIR/Dockerfile.dotnet" "$DIR"
}

case "$TARGET" in
    dotnet)
        build_dotnet
        ;;
    all)
        build_base
        build_dotnet
        ;;
    latest)
        build_base
        ;;
esac

echo "Limpando camadas intermediárias e imagens órfãs (dangling)..."
"$ENGINE" image prune -f 2>/dev/null || true
echo "Build do opencode concluído com sucesso!"
