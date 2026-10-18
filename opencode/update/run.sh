#!/bin/bash
# Atualizações do perfil (/home) para a imagem em execução.
# A versão é ditada por /etc/opencode/.image-version (gravado pelo Dockerfile
# no build) e os scripts de update vêm de /etc/opencode/update/. Nada em
# /etc/opencode é escrito em tempo de execução — só o Dockerfile o atualiza.
set -u

log() { printf '[update] %s\n' "$*" >&2; }

ETC="${OPENCODE_ETC:-/etc/opencode}"
HOME_DIR="${HOME:?HOME não definida}"
CFG="$HOME_DIR/.config/opencode"
STAMP="$ETC/.image-version"
APPLIED="$CFG/.applied-version"

mkdir -p "$CFG"

# Variante ativa, registrada no volume do perfil
echo "${OPENCODE_VARIANT:-base}" > "$CFG/variant"

# AGENTS.md do perfil: regenerado a cada inicialização a partir da cópia
# imutável da imagem. O conteúdo aponta as regras canônicas em /etc/opencode;
# conteúdo pessoal deve ficar em skills, não aqui.
if [ -f "$ETC/AGENTS.md" ]; then
    cp -f "$ETC/AGENTS.md" "$CFG/AGENTS.md" || log "falha ao regenerar AGENTS.md"
    chmod 0644 "$CFG/AGENTS.md" 2>/dev/null || true
fi

version="$(cat "$STAMP" 2>/dev/null || echo dev)"

# Versão já aplicada ao perfil → caminho rápido (o AGENTS.md acima já basta)
if [ "$version" != "dev" ] && [ -f "$APPLIED" ] \
    && [ "$(cat "$APPLIED" 2>/dev/null)" = "$version" ]; then
    exit 0
fi

# --- atualizações pesadas: somente na 1ª inicialização de cada versão ---

if ! bash "$ETC/update/skills.sh"; then
    log "falha ao sincronizar skills; reexecutadas no próximo boot"
    exit 1
fi

# Artefatos de entrypoints antigos (fora do ciclo da imagem)
if [ -d "$CFG/rules" ]; then
    rm -rf "$CFG/rules"
    log "artefato obsoleto removido: ~/.config/opencode/rules"
fi
rm -f "$CFG/.image-version" # nome antigo do controle de versão no perfil

printf '%s\n' "$version" > "$APPLIED" || exit 1
log "atualizações da versão $version aplicadas ao perfil"
