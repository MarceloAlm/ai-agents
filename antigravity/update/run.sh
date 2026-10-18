#!/bin/bash
# Atualizações do perfil (/home) para a imagem em execução.
# A versão é ditada por /etc/antigravity/.image-version (gravado pelo Dockerfile
# no build) e os scripts de update vêm de /etc/antigravity/update/. Nada em
# /etc/antigravity é escrito em tempo de execução — só o Dockerfile o atualiza.
set -u

log() { printf '[update] %s\n' "$*" >&2; }

ETC="${ANTIGRAVITY_ETC:-/etc/antigravity}"
HOME_DIR="${HOME:?HOME não definida}"
CFG="$HOME_DIR/.gemini/config"
SEED_DIR="$HOME_DIR/.gemini/antigravity-cli"
STAMP="$ETC/.image-version"
APPLIED="$CFG/.applied-version"

mkdir -p "$CFG" "$SEED_DIR"

# Variante ativa, registrada no volume do perfil
echo "${AGY_VARIANT:-base}" > "$SEED_DIR/variant"
echo "${AGY_VARIANT:-base}" > "$CFG/variant"

# AGENTS.md do perfil: regenerado a cada inicialização a partir da cópia
# imutável da imagem. O conteúdo aponta as regras canônicas em /etc/antigravity;
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

# Artefatos legados ou redundantes (fora do ciclo da imagem)
if [ -d "$CFG/rules" ]; then
    rm -rf "$CFG/rules"
    log "artefato obsoleto removido: ~/.gemini/config/rules"
fi

# Remove cópia redundante de skills no appDataDir (descoberta nativa é em ~/.gemini/config/skills)
if [ -d "$SEED_DIR/skills" ]; then
    rm -rf "$SEED_DIR/skills"
    log "cópia redundante removida: ~/.gemini/antigravity-cli/skills"
fi

# Remove resíduo antigo de cópia aninhada de container-ambiente, se existir
if [ -d "$CFG/skills/container-ambiente/container-ambiente" ]; then
    rm -rf "$CFG/skills/container-ambiente/container-ambiente"
    log "resíduo aninhado removido: ~/.gemini/config/skills/container-ambiente/container-ambiente"
fi

printf '%s\n' "$version" > "$APPLIED" || exit 1
log "atualizações da versão $version aplicadas ao perfil"
