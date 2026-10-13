#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

ENABLE_SOUND=false
AGY_VERSION="latest"

while [ $# -gt 0 ]; do
    case "$1" in
        --sound)
            ENABLE_SOUND=true
            shift
            ;;
        --version)
            AGY_VERSION="${2:-latest}"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

echo "==> [1/8] Atualizando repositórios e instalando dependências base..."
apt-get update
apt-get install -y --no-install-recommends \
    curl jq git ripgrep ca-certificates file procps \
    tzdata locales bind9-dnsutils traceroute iputils-ping \
    unzip zip dos2unix gawk less zstd sudo \
    shellcheck sqlfluff vim nano

if [ "$ENABLE_SOUND" = true ]; then
    echo "==> [Sound] Instalando bibliotecas de áudio..."
    apt-get install -y --no-install-recommends \
        alsa-utils pulseaudio-utils pipewire-bin libasound2t64 libpulse0
fi

echo "==> [2/8] Configurando locales e fuso horário..."
echo "pt_BR.UTF-8 UTF-8" >> /etc/locale.gen
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
update-alternatives --set editor /usr/bin/vim.basic
ln -snf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
echo "America/Sao_Paulo" > /etc/timezone

echo "==> [3/8] Configurando Vim UTF-8..."
mkdir -p /etc/vim
printf '" Suporte nativo a UTF-8 e acentuacao no Vim\nset encoding=utf-8\nset fileencoding=utf-8\nset fileencodings=utf-8,latin1\nset termencoding=utf-8\nset nocompatible\nsyntax on\n' > /etc/vim/vimrc.local

echo "==> [4/8] Instalando yq (Go nativo)..."
curl -fsSL https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -o /usr/local/bin/yq
chmod +x /usr/local/bin/yq

echo "==> [5/8] Instalando .NET SDK 10..."
curl -fsSL https://packages.microsoft.com/config/debian/13/packages-microsoft-prod.deb -o /tmp/packages-microsoft-prod.deb
dpkg -i /tmp/packages-microsoft-prod.deb
rm -f /tmp/packages-microsoft-prod.deb
apt-get update
apt-get install -y --no-install-recommends dotnet-sdk-10.0

echo "==> [6/8] Instalando ferramentas globais .NET..."
mkdir -p /dotnet-tools
dotnet tool install --tool-path /dotnet-tools dotnet-trace
dotnet tool install --tool-path /dotnet-tools dotnet-counters
dotnet tool install --tool-path /dotnet-tools dotnet-dump
dotnet tool install --tool-path /dotnet-tools roslynator.dotnet.cli
dotnet tool install --tool-path /dotnet-tools csharp-ls

echo "==> [7/8] Criando usuário antigravity (UID 1100) e diretórios..."
groupadd --gid 1100 antigravity
if [ "$ENABLE_SOUND" = true ]; then
    useradd --uid 1100 --gid antigravity -G audio --shell /bin/bash --create-home antigravity
else
    useradd --uid 1100 --gid antigravity --shell /bin/bash --create-home antigravity
fi
echo "antigravity ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/antigravity
chmod 0440 /etc/sudoers.d/antigravity
mkdir -p /etc/antigravity/skills /workspace
chown -R antigravity:antigravity /workspace /dotnet-tools

echo "==> [8/8] Instalando Antigravity CLI (versão: $AGY_VERSION)..."
curl -fsSL https://antigravity.google/cli/install.sh | bash -s -- -d /usr/local/bin

if [ -f /root/.local/bin/agy ] && [ ! -f /usr/local/bin/agy ]; then
    cp /root/.local/bin/agy /usr/local/bin/agy
fi
chmod 755 /usr/local/bin/agy 2>/dev/null || true

echo "==> Limpeza de caches e arquivos temporários..."
apt-get clean
rm -rf /var/lib/apt/lists/*
dotnet nuget locals all --clear 2>/dev/null || true
rm -rf /root/.nuget /root/.local/share/NuGet /root/.cache /var/cache/* /var/tmp/*
find /tmp -mindepth 1 ! -name "setup-*.sh" -delete 2>/dev/null || true

echo "==> Provisionamento concluído com sucesso!"
