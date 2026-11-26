#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
OPENCODE_VERSION="${1:-latest}"

echo "==> [1/5] Criando diretórios e usuário opencode (UID 1100)..."
mkdir -p /etc/sudoers.d /etc/opencode /workspace
groupadd --gid 1100 opencode
useradd --uid 1100 --gid opencode --shell /bin/bash --create-home opencode

echo "==> [2/6] Instalando ferramentas do sistema, locales e Node.js 22 LTS..."
apt-get update
apt-get install -y --no-install-recommends \
    ripgrep git ca-certificates curl wget jq unzip zip tree tzdata locales vim \
    file sudo

echo "pt_BR.UTF-8 UTF-8" >> /etc/locale.gen
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
update-alternatives --set editor /usr/bin/vim.basic 2>/dev/null || true
ln -snf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
echo "America/Sao_Paulo" > /etc/timezone

curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt-get install -y --no-install-recommends nodejs

# Sudo mínimo: só instalações pontuais efêmeras (apt/npm), conforme o SKILL
# container-ambiente. Os argumentos casam como string concatenada — o
# subcomando deve vir primeiro (ex.: apt-get install -y pkg). Todo o resto
# exige senha; a conta não tem, logo é negado. Root no host segue via:
# podman exec -u root <container>.
cat << 'EOF' > /tmp/opencode.sudoers
Cmnd_Alias APTGET = /usr/bin/apt-get install *, /usr/bin/apt-get update, /usr/bin/apt-get upgrade *, /usr/bin/apt-get autoremove *, /usr/bin/apt-get autoclean, /usr/bin/apt-get clean
Cmnd_Alias APT = /usr/bin/apt install *, /usr/bin/apt update, /usr/bin/apt upgrade *, /usr/bin/apt autoremove *, /usr/bin/apt autoclean, /usr/bin/apt clean
Cmnd_Alias NPMG = /usr/local/bin/npm install -g *, /usr/local/bin/npm i -g *, /usr/local/bin/npm install --global *, /usr/local/bin/npm i --global *, /usr/local/bin/npm uninstall -g *, /usr/local/bin/npm remove -g *, /usr/bin/npm install -g *, /usr/bin/npm i -g *, /usr/bin/npm uninstall -g *, /usr/bin/npm remove -g *
opencode ALL=(ALL) NOPASSWD: APTGET, APT, NPMG
EOF
/usr/sbin/visudo -cf /tmp/opencode.sudoers
install -m 0440 /tmp/opencode.sudoers /etc/sudoers.d/opencode
rm -f /tmp/opencode.sudoers

if [[ "$OPENCODE_VERSION" =~ ^1(\.|$) ]]; then
    echo "==> [3/6] Instalando OpenCode 1 (opencode-ai) via npm (versão: $OPENCODE_VERSION)..."
    npm i -g --no-fund --no-audit "opencode-ai@${OPENCODE_VERSION}"
else
    echo "==> [3/6] Instalando OpenCode 2 (@opencode/cli) via npm (versão: $OPENCODE_VERSION)..."
    npm i -g --no-fund --no-audit "@opencode/cli@${OPENCODE_VERSION}"
fi
npm cache clean --force 2>/dev/null || true

echo "==> [4/6] Configurando permissões e arquivo de configuração do opencode..."
chown -R opencode:opencode /workspace
if [[ "$OPENCODE_VERSION" =~ ^1(\.|$) ]]; then
    cat << 'EOF' > /etc/opencode/opencode.json
{
  "$schema": "https://opencode.ai/config.json",
  "skills": { "paths": ["/etc/opencode/skills"] },
  "permission": {
    "edit": "allow",
    "bash": "allow",
    "external_directory": { "*": "allow" },
    "read": {
      "*": "allow",
      "*.env": "ask",
      "*.env.*": "ask",
      "*id_rsa": "ask",
      "*id_ed25519": "ask",
      "*.pem": "ask",
      "*.key": "ask",
      "*credentials*": "ask",
      "*.env.example": "allow"
    }
  }
}
EOF
else
    cat << 'EOF' > /etc/opencode/opencode.json
{
  "$schema": "https://opencode.ai/config.json",
  "skills": ["/etc/opencode/skills"],
  "permissions": [
    { "action": "read", "resource": "*", "effect": "allow" },
    { "action": "edit", "resource": "*", "effect": "allow" },
    { "action": "shell", "resource": "*", "effect": "allow" },
    { "action": "external_directory", "resource": "*", "effect": "allow" },
    { "action": "read", "resource": "*.env", "effect": "ask" },
    { "action": "read", "resource": "*.env.*", "effect": "ask" },
    { "action": "read", "resource": "*id_rsa", "effect": "ask" },
    { "action": "read", "resource": "*id_ed25519", "effect": "ask" },
    { "action": "read", "resource": "*.pem", "effect": "ask" },
    { "action": "read", "resource": "*.key", "effect": "ask" },
    { "action": "read", "resource": "*credentials*", "effect": "ask" },
    { "action": "read", "resource": "*.env.example", "effect": "allow" }
  ]
}
EOF
fi

chown -R root:root /etc/opencode
chmod -R 755 /etc/opencode
find /etc/opencode -type f -exec chmod 644 {} +

echo "==> [5/5] Limpeza de caches e arquivos temporários..."
apt-get clean
rm -rf /var/lib/apt/lists/* /root/.npm /root/.cache /var/cache/* /var/tmp/*
find /tmp -mindepth 1 ! -name "setup-*.sh" ! -name "setup" -delete 2>/dev/null || true

echo "==> Provisionamento do opencode (base) concluído com sucesso!"
