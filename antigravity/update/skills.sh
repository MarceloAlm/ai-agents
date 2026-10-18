#!/bin/bash
# Sincroniza as skills GERENCIADAS da fonte — repositório de dev completo
# (marcador Dockerfile) ou a cópia da imagem em /etc/antigravity/skills — para o
# perfil do usuário (/home), com manifesto de hashes e remoção do que saiu da
# fonte. Somente leitura em /etc; skills pessoais, que nunca constam em
# manifesto, não são tocadas.
set -u

log() { printf '[update:skills] %s\n' "$*" >&2; }

ETC="${ANTIGRAVITY_ETC:-/etc/antigravity}"
HOME_DIR="${HOME:?HOME não definida}"

SKILLS_HOME="${SKILLS_HOME:-$HOME_DIR/.gemini/config/skills}"
SKILLS_CUSTOM="${SKILLS_CUSTOM:-$HOME_DIR/.gemini/config/skills-custom}"
MANIFEST="${SKILLS_MANIFEST:-$HOME_DIR/.gemini/config/.skill-manifest.txt}"
SKILLS_ETC="${SKILLS_ETC:-$ETC/skills}"

hash_of() {
    sha256sum "$1" 2>/dev/null | awk '{print $1}'
}

# Fonte: repositório de dev montado — apenas com o marcador Dockerfile, para
# que um projeto qualquer montado em /workspace não sequestre a sincronização
# global do perfil — ou a cópia imutável da imagem. Override: SKILLS_SOURCE.
pick_source() {
    local repo="${SKILLS_REPO:-/workspace/antigravity}"
    if [ -d "$repo/skills" ] && [ -f "$repo/Dockerfile" ]; then
        echo "$repo/skills"
        return 0
    fi
    if [ -d "$SKILLS_ETC" ]; then
        echo "$SKILLS_ETC"
        return 0
    fi
    echo ""
}

# Linha do manifesto: hash sha256 (64) + 2 espaços + relativo; o relativo é
# lido por posição (substr) para tolerar espaços no caminho.
prev_manifest_hash() {
    local rel="$1"
    [ -f "$MANIFEST" ] && awk -v r="$rel" 'length($0)>66 && substr($0,67)==r {print substr($0,1,64); exit}' "$MANIFEST" || true
}

sync_file() {
    local src="$1" rel="$2"
    local dst="$SKILLS_HOME/$rel"
    local sh dh prev stamp bname
    sh=$(hash_of "$src")
    [ -z "$sh" ] && return 0

    mkdir -p "$(dirname "$dst")" || return 1
    if [ -f "$dst" ]; then
        dh=$(hash_of "$dst")
        if [ "$dh" = "$sh" ]; then
            : # já idêntica à fonte, nada a fazer
        else
            prev=$(prev_manifest_hash "$rel")
            if [ -n "$prev" ] && [ "$prev" = "$dh" ]; then
                cp "$src" "$dst" || return 1
                log "atualizada: $rel"
            else
                stamp=$(date +%Y%m%d-%H%M%S)
                mkdir -p "$SKILLS_CUSTOM/$(dirname "$rel")" || return 1
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
    echo "$sh  $rel" >> "$MANIFEST.tmp" || return 1
}

# Remove do perfil arquivos GERENCIADOS que constavam no manifesto anterior e
# saíram da fonte (inclusive diretórios que esvaziaram). Arquivos pessoais —
# nunca registrados em manifesto — são preservados, mesmo dentro de
# diretórios gerenciados.
prune_removed() {
    local rel top
    [ -f "$MANIFEST" ] && [ -f "$MANIFEST.tmp" ] || return 0
    while IFS= read -r rel; do
        [ -n "$rel" ] || continue
        if ! awk -v r="$rel" 'length($0)>66 && substr($0,67)==r {found=1} END {exit !found}' "$MANIFEST.tmp"; then
            if [ -f "$SKILLS_HOME/$rel" ]; then
                rm -f "$SKILLS_HOME/$rel" || return 1
                log "removida (saiu da fonte): $rel"
            fi
        fi
    done < <(awk 'length($0)>66 {print substr($0,67)}' "$MANIFEST")
    while IFS= read -r top; do
        [ -d "$SKILLS_HOME/$top" ] || continue
        find "$SKILLS_HOME/$top" -depth -type d -empty -delete 2>/dev/null || true
    done < <({
        awk 'length($0)>66 {split(substr($0,67),p,"/"); print p[1]}' "$MANIFEST"
        awk 'length($0)>66 {split(substr($0,67),p,"/"); print p[1]}' "$MANIFEST.tmp"
    } | sort -u)
}

sync_tree() {
    local src="$1"
    local rel f
    mkdir -p "$SKILLS_HOME" || return 1
    : > "$MANIFEST.tmp" || return 1
    while IFS= read -r f; do
        rel="${f#"$src"/}"
        sync_file "$f" "$rel" || return 1
    done < <(find "$src" -type f | sort)
    prune_removed
    mv "$MANIFEST.tmp" "$MANIFEST" || return 1
}

SRC_VAR="${SKILLS_SOURCE:-}"
if [ -z "$SRC_VAR" ]; then
    SRC_VAR=$(pick_source)
fi

if [ -n "$SRC_VAR" ] && [ -d "$SRC_VAR" ]; then
    sync_tree "$SRC_VAR" || exit 1
else
    log "nenhuma fonte de skills encontrada (continua mesmo assim)"
fi

exit 0
