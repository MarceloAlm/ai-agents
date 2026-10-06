#!/bin/bash
# Antigravity CLI (agy) em container — Padrão OAuth (conta do Google). Aceita API key se passada.
# 1º login: rode  agy auth login  (ou apenas agy) -> imprime a URL de autorização; abra no
# navegador, entre com a conta e cole o código exibido. O token é persistido em
# ~/.gemini/antigravity-cli/antigravity-oauth-token (GEMINI_FORCE_FILE_STORAGE=true).
#
# --hostname antigravity: hostname fixo -> chave estável de criptografia do FileKeychain.
# Verificação leve de atualização (avisa se houver nova versão upstream disponível)
if [ "${AGY_NO_UPDATE_CHECK:-0}" != "1" ] && [ "${AGY_CHECK_UPDATE:-1}" != "0" ]; then
    IMAGE_NAME="antigravity:latest"
    LOCAL_VERSION=$(podman inspect --format '{{index .Config.Labels "org.opencontainers.image.version"}}' "$IMAGE_NAME" 2>/dev/null || true)
    if [ -z "$LOCAL_VERSION" ]; then
        LOCAL_VERSION=$(podman run --rm "$IMAGE_NAME" agy --version 2>/dev/null | tr -d '\r\n' || true)
    fi

    if [ -n "$LOCAL_VERSION" ] && [ "$LOCAL_VERSION" != "latest" ]; then
        ARCH="$(uname -m)"
        case "$ARCH" in
            x86_64|amd64) PLATFORM_ARCH="amd64" ;;
            aarch64|arm64) PLATFORM_ARCH="arm64" ;;
            *) PLATFORM_ARCH="amd64" ;;
        esac

        MANIFEST_URL="https://antigravity-cli-auto-updater-974169037036.us-central1.run.app/manifests/linux_${PLATFORM_ARCH}.json"
        REMOTE_JSON=$(curl -fsSL --connect-timeout 1 --max-time 2 "$MANIFEST_URL" 2>/dev/null || true)
        if [ -n "$REMOTE_JSON" ]; then
            REMOTE_VERSION=$(echo "$REMOTE_JSON" | sed -nE 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' | head -n 1)
            if [ -n "$REMOTE_VERSION" ] && [ "$REMOTE_VERSION" != "$LOCAL_VERSION" ]; then
                echo "⚠️  [antigravity] Nova versão disponível: $REMOTE_VERSION (imagem local possui: $LOCAL_VERSION)" >&2
                echo "   Para atualizar a imagem com a nova versão, execute: ./antigravity/build.sh" >&2
                echo "" >&2
            fi
        fi
    fi
fi

ARGS=(
    podman run --rm -it "--userns=keep-id:uid=1100,gid=1100"
    --hostname antigravity
    -v "antigravity-home:/home/antigravity"
    -v "$PWD:/workspace"
    -w /workspace
)

# Repassa credenciais e endpoints MCP se definidos no host
[ -n "$GEMINI_API_KEY" ] && ARGS+=(-e "GEMINI_API_KEY=$GEMINI_API_KEY")
[ -n "$MCP_GATEWAY_URL" ] && ARGS+=(-e "MCP_GATEWAY_URL=$MCP_GATEWAY_URL")
[ -n "$MCP_TOKEN" ] && ARGS+=(-e "MCP_TOKEN=$MCP_TOKEN")

ARGS+=(antigravity:latest "$@")
exec "${ARGS[@]}"

