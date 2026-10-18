#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
OPENCODE_VERSION="${1:-latest}"

echo "==> [1/5] Criando diretórios e usuário opencode (UID 1100)..."
mkdir -p /etc/sudoers.d /etc/opencode /workspace
groupadd --gid 1100 opencode
useradd --uid 1100 --gid opencode --shell /bin/bash --create-home opencode

echo "==> [2/5] Instalando ferramentas do sistema..."
apt-get update
apt-get install -y --no-install-recommends \
    ripgrep git ca-certificates curl wget jq unzip zip tree file sudo

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

echo "==> [3/5] Instalando OpenCode 2 (@opencode/cli) via npm (versão: $OPENCODE_VERSION)..."
# Remove uma eventual instalação legada da linha 1.x (opencode-ai), que disputa
# o mesmo binário "opencode" e não pode coexistir com a V2.
npm uninstall -g opencode-ai 2>/dev/null || true
npm i -g --no-fund --no-audit "@opencode/cli@${OPENCODE_VERSION}"
npm cache clean --force 2>/dev/null || true

echo "==> [4/5] Configurando permissões e arquivo de configuração do opencode (formato nativo V2)..."
chown -R opencode:opencode /workspace
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

chown -R root:root /etc/opencode
chmod -R 755 /etc/opencode
find /etc/opencode -type f -exec chmod 644 {} +

echo "==> [5/5] Limpeza de caches e arquivos temporários..."
apt-get clean
rm -rf /var/lib/apt/lists/* /root/.npm /root/.cache /var/cache/* /var/tmp/*
find /tmp -mindepth 1 ! -name "setup-*.sh" ! -name "setup" -delete 2>/dev/null || true

echo "==> Provisionamento do opencode (base) concluído com sucesso!"
