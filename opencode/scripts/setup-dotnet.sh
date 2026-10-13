#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

echo "==> [1/4] Adicionando repositório Microsoft e instalando .NET SDK 10..."
wget -q https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb -O /tmp/packages-microsoft-prod.deb
dpkg -i /tmp/packages-microsoft-prod.deb
rm -f /tmp/packages-microsoft-prod.deb
apt-get update
apt-get install -y --no-install-recommends dotnet-sdk-10.0

echo "==> [2/4] Instalando ferramentas globais do .NET e Roslyn LSP..."
mkdir -p /dotnet-tools
dotnet tool install --tool-path /dotnet-tools dotnet-trace
dotnet tool install --tool-path /dotnet-tools dotnet-counters
dotnet tool install --tool-path /dotnet-tools dotnet-dump
dotnet tool install --tool-path /dotnet-tools roslynator.dotnet.cli
dotnet tool install --tool-path /dotnet-tools roslyn-language-server --prerelease

find /dotnet-tools/.store/roslyn-language-server -type f \
   \( -name 'roslyn-language-server' -o -name 'Microsoft.CodeAnalysis.LanguageServer' \) \
   -exec chmod +x {} +
chown -R opencode:opencode /dotnet-tools

echo "==> [3/4] Atualizando configuração com suporte a LSP..."
cat << 'EOF' > /etc/opencode/opencode.json
{
  "$schema": "https://opencode.ai/config.json",
  "lsp": true,
  "skills": { "paths": ["/etc/opencode/skills"] },
  "permission": {
    "edit": "allow",
    "bash": "allow",
    "read": "allow",
    "external_directory": { "*": "allow" }
  }
}
EOF

echo "==> [4/4] Limpeza de caches do NuGet e arquivos temporários..."
apt-get clean
rm -rf /var/lib/apt/lists/*
dotnet nuget locals all --clear 2>/dev/null || true
rm -rf /root/.nuget /root/.local/share/NuGet /root/.cache /var/cache/* /var/tmp/*
find /tmp -mindepth 1 ! -name "setup-*.sh" -delete 2>/dev/null || true

echo "==> Provisionamento do módulo opencode:dotnet concluído com sucesso!"
