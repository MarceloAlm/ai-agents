#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

echo "==> [1/2] Instalando bibliotecas de áudio..."
apt-get update
apt-get install -y --no-install-recommends \
    alsa-utils pulseaudio-utils pipewire-bin libasound2t64 libpulse0

echo "==> [2/2] Adicionando usuário ao grupo audio e limpando caches..."
usermod -aG audio antigravity 2>/dev/null || true
apt-get clean
rm -rf /var/lib/apt/lists/* /var/cache/* /var/tmp/*
find /tmp -mindepth 1 ! -name "setup-*.sh" -delete 2>/dev/null || true

echo "==> Módulo de áudio provisionado com sucesso!"
