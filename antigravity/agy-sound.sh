#!/bin/bash
# Antigravity CLI (agy) com suporte a microfone e funções de fala (:sound)
# Padrão OAuth (conta do Google). Aceita API key se passada.
#
# Permite usar /voice (ou F5) no agy para ditar texto via microfone diretamente no CLI.
# Mapeia dinamicamente dispositivos ALSA (/dev/snd) e sockets PulseAudio/PipeWire do host.
#
# --hostname antigravity: hostname fixo -> chave estável de criptografia do FileKeychain.

set -e

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
