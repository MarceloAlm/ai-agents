#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

echo "==> [1/3] Instalando dependências do sistema..."
apt-get update
apt-get install -y --no-install-recommends ripgrep git ca-certificates

echo "==> [2/3] Instalando pacote openclaude via npm..."
npm install -g --no-fund --no-audit @gitlawb/openclaude

echo "==> [3/3] Limpeza de caches e arquivos temporários..."
npm cache clean --force 2>/dev/null || true
apt-get clean
rm -rf /var/lib/apt/lists/* /root/.npm /root/.cache /var/cache/* /var/tmp/*
find /tmp -mindepth 1 ! -name "setup-*.sh" -delete 2>/dev/null || true

echo "==> Provisionamento do OpenClaude concluído com sucesso!"
