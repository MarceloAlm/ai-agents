#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
OPENCODE_VERSION="${1:-latest}"

echo "==> [1/5] Criando diretórios e usuário opencode (UID 1100)..."
mkdir -p /etc/sudoers.d /etc/opencode /workspace
groupadd --gid 1100 opencode
useradd --uid 1100 --gid opencode --shell /bin/bash --create-home opencode
echo "opencode ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/opencode
chmod 0440 /etc/sudoers.d/opencode

echo "==> [2/5] Instalando ferramentas do sistema..."
apt-get update
apt-get install -y --no-install-recommends \
    ripgrep git ca-certificates curl wget jq unzip zip tree file sudo

echo "==> [3/5] Instalando opencode-ai via npm (versão: $OPENCODE_VERSION)..."
npm i -g --no-fund --no-audit "opencode-ai@${OPENCODE_VERSION}"
npm cache clean --force 2>/dev/null || true

echo "==> [4/5] Configurando permissões e arquivo de configuração do opencode..."
chown -R opencode:opencode /workspace
cat << 'EOF' > /etc/opencode/opencode.json
{
  "$schema": "https://opencode.ai/config.json",
  "skills": { "paths": ["/etc/opencode/skills"] },
  "permission": {
    "edit": "allow",
    "bash": "allow",
    "read": "allow",
    "external_directory": { "*": "allow" }
  }
}
EOF

# Posiciona o entrypoint com permissão de execução
if [ -f /tmp/setup/entrypoint.sh ]; then
    install -m 755 /tmp/setup/entrypoint.sh /usr/local/bin/opencode-entrypoint.sh
fi

echo "==> [5/5] Limpeza de caches e arquivos temporários..."
apt-get clean
rm -rf /var/lib/apt/lists/* /root/.npm /root/.cache /var/cache/* /var/tmp/*
find /tmp -mindepth 1 ! -name "setup-*.sh" ! -name "setup" -delete 2>/dev/null || true

echo "==> Provisionamento do opencode (base) concluído com sucesso!"
