#!/bin/bash
# Sincroniza as skills do projeto com a pasta de skills do usuário (/home) e
# instala o estado efetivo em /etc/opencode/skills — que é o local com maior
# precedência no opencode e que o agente carrega de fato.
#
# Regras:
#  1. A fonte das skills é o repositório de containers montado em /workspace
#     (pasta skills/ da variante). Sem o repositório montado, usa as skills
#     embutidas na imagem (/etc/opencode/skills).
#  2. Cada arquivo é copiado para ~/.config/opencode/skills e o hash da fonte
#     fica registrado num manifest. Na próxima execução:
#       - se o arquivo do usuário não foi alterado, é atualizado para a nova
#         versão da fonte;
#       - se foi personalizado, a versão dele é PRESERVADA em
#         ~/.config/opencode/skills-custom/<rel>.<timestamp>.custom e a versão
#         oficial é reinstalada (nada se perde nos updates de boot).
#  3. Preferências pessoais da skill ficam SEMPRE num arquivo separado
#     (~/.config/opencode/skills/container-ambiente/preferences.md), nunca
#     sobrescrito pela sincronização.
set -u

log() { printf '[entrypoint] %s\n' "$*" >&2; }

HOME_DIR="${HOME:?HOME não definida}"

SKILLS_HOME="${SKILLS_HOME:-$HOME_DIR/.config/opencode/skills}"
SKILLS_CUSTOM="${SKILLS_CUSTOM:-$HOME_DIR/.config/opencode/skills-custom}"
SKILLS_ETC="${SKILLS_ETC:-/etc/opencode/skills}"
MANIFEST="${SKILLS_MANIFEST:-$HOME_DIR/.config/opencode/.skill-manifest.txt}"
INSTALL_ETC="${SKILLS_INSTALL_ETC:-1}"

hash_of() {
    sha256sum "$1" 2>/dev/null | awk '{print $1}'
}

pick_source() {
    local d
    for d in \
        /workspace/opencode-dotnet/skills \
        /workspace/opencode-ml/skills \
        /workspace/opencode/skills \
        /workspace/skills \
        "$SKILLS_ETC"; do
        if [ -d "$d" ]; then
            echo "$d"
            return 0
        fi
    done
    echo ""
}

prev_manifest_hash() {
    # hash da fonte registrado para este arquivo relativo na última sync
    local rel="$1"
    [ -f "$MANIFEST" ] && awk -v r="$rel" '$2==r {print $1; exit}' "$MANIFEST" || true
}

sync_file() {
    local src="$1" rel="$2"
    local dst="$SKILLS_HOME/$rel"
    local sh dh prev stamp bname
    sh=$(hash_of "$src")
    [ -z "$sh" ] && return 0

    mkdir -p "$(dirname "$dst")"
    if [ -f "$dst" ]; then
        dh=$(hash_of "$dst")
        if [ "$dh" = "$sh" ]; then
            : # já idêntica à fonte, nada a fazer
        else
            prev=$(prev_manifest_hash "$rel")
            if [ -n "$prev" ] && [ "$prev" = "$dh" ]; then
                # intocado desde a última sync -> apenas atualiza
                cp "$src" "$dst" || return 1
                log "atualizada: $rel"
            else
                # personalizado pelo usuário -> preserva em arquivo separado
                stamp=$(date +%Y%m%d-%H%M%S)
                mkdir -p "$SKILLS_CUSTOM/$(dirname "$rel")"
                bname="$SKILLS_CUSTOM/$rel.$stamp.custom"
                cp "$dst" "$bname" || return 1
                log "personalização preservada em: ${bname/#$HOME_DIR/~}"
                cp "$src" "$dst" || return 1
                log "versão oficial reinstalada: $rel"
            fi
        fi
    else
        cp "$src" "$dst" || return 1
        log "instalada: $rel"
    fi
    echo "$sh  $rel" >> "$MANIFEST.tmp"
}

sync_tree() {
    local src="$1"
    local rel
    mkdir -p "$SKILLS_HOME"
    : > "$MANIFEST.tmp"
    while IFS= read -r f; do
        rel="${f#"$src"/}"
        sync_file "$f" "$rel" || return 1
    done < <(find "$src" -type f | sort)
    mv "$MANIFEST.tmp" "$MANIFEST"
}

seed_preferences() {
    # Preferências do usuário vivem em preferences.md (arquivo separado).
    # É criado uma única vez a partir do template e nunca é sobrescrito.
    local tmpl="$SKILLS_HOME/container-ambiente/preferences.example.md"
    local dst="$SKILLS_HOME/container-ambiente/preferences.md"
    if [ -f "$tmpl" ] && [ ! -f "$dst" ]; then
        mkdir -p "$(dirname "$dst")"
        cp "$tmpl" "$dst"
        log "criado ${dst/#$HOME_DIR/~} (edite à vontade: nunca será sobrescrito)"
    fi
}

install_to_etc() {
    # O opencode carrega preferencialmente /etc/opencode/skills, então o
    # estado efetivo (projeto >= atualizado no home) precisa chegar lá.
    if [ "$INSTALL_ETC" != "1" ]; then
        return 0
    fi
    if [ ! -d "$SKILLS_HOME" ]; then
        return 0
    fi
    sudo mkdir -p "$SKILLS_ETC" || return 1
    sudo cp -a "$SKILLS_HOME/." "$SKILLS_ETC/" || return 1
    sudo chown -R root:root "$SKILLS_ETC" 2>/dev/null || true
    sudo find "$SKILLS_ETC" -type d -exec chmod 755 {} + 2>/dev/null || true
    sudo find "$SKILLS_ETC" -type f -exec chmod 644 {} + 2>/dev/null || true
    log "skills instaladas em $SKILLS_ETC"
}

SRC_VAR="${SKILLS_SOURCE:-}"
if [ -z "$SRC_VAR" ]; then
    SRC_VAR=$(pick_source)
fi

if [ -n "$SRC_VAR" ] && [ -d "$SRC_VAR" ]; then
    if [ "$SRC_VAR" = "$SKILLS_ETC" ]; then
        : # fonte já é o local efetivo; nada a sincronizar
    else
        sync_tree "$SRC_VAR" || log "falha ao sincronizar skills (continua mesmo assim)"
        seed_preferences
    fi
fi

install_to_etc || log "falha ao instalar skills em /etc (continua mesmo assim)"

# Compatibilidade com CMD ["opencode"] e com o script de execução
# (que passa "opencode" como primeiro argumento).
if [ "$#" -gt 0 ] && [ "$1" = "opencode" ]; then
    shift
fi

exec opencode "$@"