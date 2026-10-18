#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="latest"
VERSION=""

# Detecta runtime disponível: podman ou docker
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

# Permite argumentos: TARGET ("sound", "rea", "base" ou "latest") e versão opcional
# Ex.: ./build.sh
#      ./build.sh sound
#      ./build.sh 1.3.0
#      ./build.sh sound 1.3.0
for arg in "$@"; do
    case "$arg" in
        sound)
            TARGET="sound"
            ;;
        rea)
            TARGET="rea"
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
                echo "Uso: ./build.sh [base|sound|rea|all|latest] [versão (ex.: 1.3.0)]" >&2
                exit 1
            fi
            VERSION="$arg"
            ;;
    esac
done

# Permite override via variável de ambiente AGY_VERSION se não passada como argumento
VERSION="${VERSION:-$AGY_VERSION}"

# Se nenhuma versão foi explicitada, consulta a versão mais recente upstream
if [ -z "$VERSION" ]; then
    ARCH="$(uname -m)"
    case "$ARCH" in
        x86_64|amd64) PLATFORM_ARCH="amd64" ;;
        aarch64|arm64) PLATFORM_ARCH="arm64" ;;
        *) PLATFORM_ARCH="amd64" ;;
    esac

    MANIFEST_URL="https://antigravity-cli-auto-updater-974169037036.us-central1.run.app/manifests/linux_${PLATFORM_ARCH}.json"
    echo "Consultando versão mais recente do Antigravity CLI ($PLATFORM_ARCH)..."

    RESPONSE=$(curl -fsSL --connect-timeout 3 --max-time 6 "$MANIFEST_URL" 2>/dev/null || true)
    if [ -n "$RESPONSE" ]; then
        if command -v jq >/dev/null 2>&1; then
            VERSION=$(echo "$RESPONSE" | jq -r '.version // empty' 2>/dev/null || true)
        fi
        if [ -z "$VERSION" ]; then
            VERSION=$(echo "$RESPONSE" | sed -nE 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' | head -n 1)
        fi
    fi
fi

VERSION="${VERSION:-latest}"
IMAGE_VERSION="${IMAGE_VERSION:-$(date -u +%Y%m%d-%H%M%S)}"

echo "Versão alvo do Antigravity CLI para o build: $VERSION"
echo "Carimbo de versão da imagem (→ /etc/antigravity/.image-version): $IMAGE_VERSION"

# Hashes dos scripts de setup: os Dockerfiles montam os scripts por bind
# e usam o hash para invalidar o cache do RUN com a mesma semântica do COPY
SETUP_HASH_BASE="$(sha256sum "$DIR/scripts/setup-base.sh" | cut -d' ' -f1)"
SETUP_HASH_SOUND="$(sha256sum "$DIR/scripts/setup-sound.sh" | cut -d' ' -f1)"
SETUP_HASH_REA="$(sha256sum "$DIR/scripts/setup-rea.sh" | cut -d' ' -f1)"

image_exists() {
    local img="$1"
    if [ "$ENGINE" = "podman" ]; then
        podman image exists "$img" 2>/dev/null
    else
        docker image inspect "$img" >/dev/null 2>&1
    fi
}

build_base() {
    echo "Construindo imagem antigravity:latest a partir de $DIR/Dockerfile..."
    "$ENGINE" build "${BUILD_OPTS[@]}" \
        --build-arg AGY_VERSION="$VERSION" \
        --build-arg IMAGE_VERSION="$IMAGE_VERSION" \
        --build-arg SETUP_HASH="$SETUP_HASH_BASE" \
        -t antigravity:latest -t antigravity "$DIR"
}

build_sound() {
    if ! image_exists antigravity:latest; then
        echo "Imagem base antigravity:latest não encontrada. Construindo base primeiro..."
        build_base
    fi
    echo "Construindo imagem antigravity:sound a partir de $DIR/Dockerfile.sound (sobre antigravity:latest)..."
    "$ENGINE" build "${BUILD_OPTS[@]}" \
        --build-arg SETUP_HASH="$SETUP_HASH_SOUND" \
        -t antigravity:sound -f "$DIR/Dockerfile.sound" "$DIR"
}

build_rea() {
    if ! image_exists antigravity:latest; then
        echo "Imagem base antigravity:latest não encontrada. Construindo base primeiro..."
        build_base
    fi
    echo "Construindo imagem antigravity:rea a partir de $DIR/Dockerfile.rea (sobre antigravity:latest)..."
    "$ENGINE" build "${BUILD_OPTS[@]}" \
        --build-arg SETUP_HASH="$SETUP_HASH_REA" \
        -t antigravity:rea -f "$DIR/Dockerfile.rea" "$DIR"
}

case "$TARGET" in
    sound)
        build_sound
        ;;
    rea)
        build_rea
        ;;
    all)
        build_base
        build_sound
        build_rea
        ;;
    latest)
        build_base
        ;;
esac

echo "Limpando camadas intermediárias e imagens órfãs (dangling)..."
"$ENGINE" image prune -f 2>/dev/null || true
echo "Build concluído com sucesso!"