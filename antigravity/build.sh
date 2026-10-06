#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="latest"
VERSION=""

# Permite argumentos flexíveis: TARGET ("sound" ou "latest") e versão opcional
# Ex.: ./build.sh
#      ./build.sh sound
#      ./build.sh 1.3.0
#      ./build.sh sound 1.3.0
for arg in "$@"; do
    case "$arg" in
        sound)
            TARGET="sound"
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

if [ "$TARGET" = "sound" ]; then
    echo "Construindo imagem antigravity:sound a partir de $DIR/Dockerfile.sound..."
    podman build --build-arg AGY_VERSION="$VERSION" -t antigravity:sound -f "$DIR/Dockerfile.sound" "$DIR"
else
    echo "Construindo imagem antigravity:latest a partir de $DIR/Dockerfile..."
    podman build --build-arg AGY_VERSION="$VERSION" -t antigravity:latest -t antigravity "$DIR"
fi