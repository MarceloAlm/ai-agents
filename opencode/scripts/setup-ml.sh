#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

echo "==> [1/3] Instalando Python e bibliotecas científicas (numpy, matplotlib)..."
apt-get update
apt-get install -y --no-install-recommends \
    python3 python3-numpy python3-matplotlib

echo "==> [2/3] Instalando runner de scripts C# (dotnet-script)..."
dotnet tool install --tool-path /dotnet-tools dotnet-script
chown -R opencode:opencode /dotnet-tools

echo "==> [3/3] Limpeza de caches do NuGet e arquivos temporários..."
apt-get clean
rm -rf /var/lib/apt/lists/*
dotnet nuget locals all --clear 2>/dev/null || true
rm -rf /root/.nuget /root/.local/share/NuGet /root/.cache /var/cache/* /var/tmp/*
find /tmp -mindepth 1 ! -name "setup-*.sh" -delete 2>/dev/null || true

echo "==> Provisionamento do módulo opencode:ml concluído com sucesso!"
