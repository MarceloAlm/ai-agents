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
fi

# Permite argumentos flexíveis: TARGET ("sound", "rea" ou "latest") e versão opcional
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
        latest)
            TARGET="latest"
            ;;
        *)
            if [ -z "$VERSION" ]; then
                VERSION="$arg"
            fi
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
echo "Versão alvo do Antigravity CLI para o build: $VERSION"

image_exists() {
    local img="$1"
    if [ "$ENGINE" = "podman" ]; then
        podman image exists "$img" 2>/dev/null
    else
        docker image inspect "$img" >/dev/null 2>&1
    fi
}

if [ "$TARGET" = "sound" ]; then
    if ! image_exists antigravity:latest; then
        echo "Imagem base antigravity:latest não encontrada. Construindo base primeiro..."
        "$ENGINE" build "${BUILD_OPTS[@]}" --build-arg AGY_VERSION="$VERSION" -t antigravity:latest -t antigravity "$DIR"
    fi
    echo "Construindo imagem antigravity:sound a partir de $DIR/Dockerfile.sound (sobre antigravity:latest)..."
    "$ENGINE" build "${BUILD_OPTS[@]}" -t antigravity:sound -f "$DIR/Dockerfile.sound" "$DIR"
elif [ "$TARGET" = "rea" ]; then
    if ! image_exists antigravity:latest; then
        echo "Imagem base antigravity:latest não encontrada. Construindo base primeiro..."
        "$ENGINE" build "${BUILD_OPTS[@]}" --build-arg AGY_VERSION="$VERSION" -t antigravity:latest -t antigravity "$DIR"
    fi
    echo "Construindo imagem antigravity:rea a partir de $DIR/Dockerfile.rea (sobre antigravity:latest)..."
    "$ENGINE" build "${BUILD_OPTS[@]}" -t antigravity:rea -f "$DIR/Dockerfile.rea" "$DIR"
else
    echo "Construindo imagem antigravity:latest a partir de $DIR/Dockerfile..."
    "$ENGINE" build "${BUILD_OPTS[@]}" --build-arg AGY_VERSION="$VERSION" -t antigravity:latest -t antigravity "$DIR"
fi

echo "Limpando camadas intermediárias e imagens órfãs (dangling)..."
"$ENGINE" image prune -f 2>/dev/null || true
echo "Build concluído com sucesso!"