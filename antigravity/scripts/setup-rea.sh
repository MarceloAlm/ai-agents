#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
REA_VERSION="${1:-latest}"

echo "==> [1/3] Instalando utilitários binários e OpenJDK 21..."
apt-get update
apt-get install -y --no-install-recommends \
    binutils binwalk strace ltrace gdb xxd \
    openjdk-21-jre-headless

echo "==> [2/3] Instalando Node.js 22 LTS..."
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt-get install -y --no-install-recommends nodejs

echo "==> [3/3] Instalando ferramentas REA Agents (versão: $REA_VERSION)..."
npm install --global --no-fund --no-audit "rea-agents@${REA_VERSION}" asar

echo "==> Limpeza de caches e arquivos temporários..."
npm cache clean --force 2>/dev/null || true
apt-get clean
rm -rf /var/lib/apt/lists/* /root/.npm /root/.cache /var/cache/* /var/tmp/*
find /tmp -mindepth 1 ! -name "setup-*.sh" -delete 2>/dev/null || true

echo "==> Módulo REA provisionado com sucesso!"
