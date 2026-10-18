#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
AGY_VERSION="${1:-latest}"

echo "==> [1/6] Configurando repositórios (Debian + Microsoft)..."
apt-get update
apt-get install -y --no-install-recommends curl ca-certificates
DEBIAN_VER="$(. /etc/os-release && echo "${VERSION_ID%%.*}")"
curl -fsSL "https://packages.microsoft.com/config/debian/${DEBIAN_VER}/packages-microsoft-prod.deb" -o /tmp/packages-microsoft-prod.deb
dpkg -i /tmp/packages-microsoft-prod.deb
rm -f /tmp/packages-microsoft-prod.deb

echo "==> [2/6] Atualizando índices e instalando dependências base e .NET SDK 10..."
apt-get update
apt-get install -y --no-install-recommends \
    jq git ripgrep file procps \
    tzdata locales bind9-dnsutils traceroute iputils-ping \
    unzip zip dos2unix gawk less zstd sudo \
    shellcheck sqlfluff vim nano \
    dotnet-sdk-10.0

echo "==> [3/6] Configurando locales, fuso horário e editor padrão..."
echo "pt_BR.UTF-8 UTF-8" >> /etc/locale.gen
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
update-alternatives --set editor /usr/bin/vim.basic
ln -snf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
echo "America/Sao_Paulo" > /etc/timezone

mkdir -p /etc/vim
printf '" Suporte nativo a UTF-8 e acentuacao no Vim\nset encoding=utf-8\nset fileencoding=utf-8\nset fileencodings=utf-8,latin1\nset termencoding=utf-8\nset nocompatible\nsyntax on\n' > /etc/vim/vimrc.local

echo "==> [4/6] Instalando yq e ferramentas dotnet CLI..."
curl -fsSL https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -o /usr/local/bin/yq
chmod +x /usr/local/bin/yq

mkdir -p /dotnet-tools
dotnet tool install --tool-path /dotnet-tools dotnet-trace
dotnet tool install --tool-path /dotnet-tools dotnet-counters
dotnet tool install --tool-path /dotnet-tools dotnet-dump
dotnet tool install --tool-path /dotnet-tools roslynator.dotnet.cli
dotnet tool install --tool-path /dotnet-tools csharp-ls

echo "==> [5/6] Criando usuário antigravity (UID 1100), permissões e assets..."
groupadd --gid 1100 antigravity
useradd --uid 1100 --gid antigravity --shell /bin/bash --create-home antigravity
# Sudo mínimo: só instalações pontuais efêmeras (apt/apt-get), conforme o SKILL
# container-ambiente. Todo o resto exige senha; a conta não tem, logo é negado.
# Acesso root irrestrito no host segue via: podman exec -u root <container>.
cat << 'EOF' > /tmp/antigravity.sudoers
Cmnd_Alias APTGET = /usr/bin/apt-get install *, /usr/bin/apt-get update, /usr/bin/apt-get upgrade *, /usr/bin/apt-get autoremove *, /usr/bin/apt-get autoclean, /usr/bin/apt-get clean
Cmnd_Alias APT = /usr/bin/apt install *, /usr/bin/apt update, /usr/bin/apt upgrade *, /usr/bin/apt autoremove *, /usr/bin/apt autoclean, /usr/bin/apt clean
antigravity ALL=(ALL) NOPASSWD: APTGET, APT
EOF
/usr/sbin/visudo -cf /tmp/antigravity.sudoers
install -m 0440 /tmp/antigravity.sudoers /etc/sudoers.d/antigravity
rm -f /tmp/antigravity.sudoers

mkdir -p /etc/antigravity/skills /etc/antigravity/rules /etc/antigravity/update /workspace
chown -R antigravity:antigravity /workspace /dotnet-tools

echo "==> [6/6] Instalando Antigravity CLI (versão: $AGY_VERSION)..."
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
find /tmp -mindepth 1 ! -name "setup-*.sh" ! -name "setup" -delete 2>/dev/null || true

echo "==> Provisionamento concluído com sucesso!"
