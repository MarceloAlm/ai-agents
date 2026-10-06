#!/bin/bash
# Antigravity CLI (agy) com suporte a microfone e funções de fala (:sound)
# Padrão OAuth (conta do Google). Aceita API key se passada.
#
# Permite usar /voice (ou F5) no agy para ditar texto via microfone diretamente no CLI.
# Mapeia dinamicamente dispositivos ALSA (/dev/snd) e sockets PulseAudio/PipeWire do host.
#
# --hostname antigravity: hostname fixo -> chave estável de criptografia do FileKeychain.

set -e

# Verificação leve de atualização (avisa se houver nova versão upstream disponível)
if [ "${AGY_NO_UPDATE_CHECK:-0}" != "1" ] && [ "${AGY_CHECK_UPDATE:-1}" != "0" ]; then
    IMAGE_NAME="antigravity:sound"
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
                echo "⚠️  [antigravity:sound] Nova versão disponível: $REMOTE_VERSION (imagem local possui: $LOCAL_VERSION)" >&2
                echo "   Para atualizar a imagem com a nova versão, execute: ./antigravity/build-sound.sh" >&2
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

# 1. Suporte a ALSA direto (/dev/snd) e permissão de grupo de áudio
if [ -d /dev/snd ]; then
    ARGS+=(--device /dev/snd --group-add audio)
fi

# 2. Suporte a PulseAudio / PipeWire (padrão em distribuições Linux modernas)
USER_ID="$(id -u)"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$USER_ID}"
PULSE_SOCKET=""

if [ -S "$RUNTIME_DIR/pulse/native" ]; then
    PULSE_SOCKET="$RUNTIME_DIR/pulse/native"
elif [ -S "/run/user/$USER_ID/pulse/native" ]; then
    PULSE_SOCKET="/run/user/$USER_ID/pulse/native"
elif [ -S "/run/user/1000/pulse/native" ]; then
    PULSE_SOCKET="/run/user/1000/pulse/native"
fi

if [ -n "$PULSE_SOCKET" ]; then
    ARGS+=(
        -v "$PULSE_SOCKET:$PULSE_SOCKET:ro"
        -e "PULSE_SERVER=unix:$PULSE_SOCKET"
    )
    if [ -f "$HOME/.config/pulse/cookie" ]; then
        ARGS+=(-v "$HOME/.config/pulse/cookie:/home/antigravity/.config/pulse/cookie:ro")
    fi
fi

# 3. Suporte a PipeWire nativo (se presente no host)
if [ -S "$RUNTIME_DIR/pipewire-0" ]; then
    ARGS+=(
        -v "$RUNTIME_DIR/pipewire-0:$RUNTIME_DIR/pipewire-0:ro"
        -e "XDG_RUNTIME_DIR=$RUNTIME_DIR"
    )
fi

ARGS+=(antigravity:sound "$@")
exec "${ARGS[@]}"
