#!/bin/bash
set -e

# Seed da config CLI na primeira execução: o volume antigravity-home mascara
# /home/antigravity, então na 1ª vez que o container roda a pasta chega vazia.
#
# Autenticação padrão: OAuth com conta do Google (Google AI Pro/Ultra).
# O agy persiste o token em antigravity-oauth-token (FileKeychain, via
# GEMINI_FORCE_FILE_STORAGE=true na imagem). 1º login: rode `agy auth login`
# (ou apenas `agy`) e cole o código de autorização; depois autentica em silêncio.
# Também aceita GEMINI_API_KEY se passada via ambiente (com modelProvider no settings).
SEED_DIR="$HOME/.gemini/antigravity-cli"
SKILLS_DIR="$SEED_DIR/skills"
SETTINGS="$SEED_DIR/settings.json"
# Garante que o volume montado em /home pertença ao UID/GID atual
if [ -d "$HOME" ] && [ "$(stat -c '%u' "$HOME" 2>/dev/null)" != "$(id -u)" ]; then
    sudo chown -R "$(id -u):$(id -g)" "$HOME" 2>/dev/null || true
fi

mkdir -p "$SKILLS_DIR"

# Marca no volume persistente compartilhado qual variante está em execução (base, sound, rea)
echo "${AGY_VARIANT:-base}" > "$SEED_DIR/variant"

# Mescla configurações padrão de permissões, modelo e chaveamento de autenticação
if [ -f /etc/antigravity/settings.json ]; then
    if [ -f "$SETTINGS" ]; then
        jq -M -s --arg key "${GEMINI_API_KEY:-}" '
          .[0] as $defaults |
          .[1] as $user |
          (($defaults * $user) |
           .permissions.allow = (($defaults.permissions.allow // []) + ($user.permissions.allow // []) | unique) |
           .permissions.ask = (($defaults.permissions.ask // []) + ($user.permissions.ask // []) | unique)) |
          if ($key | length > 0) then .modelProvider = "gemini" else del(.modelProvider) end
        ' /etc/antigravity/settings.json "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
    else
        jq -M --arg key "${GEMINI_API_KEY:-}" '
          if ($key | length > 0) then .modelProvider = "gemini" else del(.modelProvider) end
        ' /etc/antigravity/settings.json > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
    fi
elif [ -f "$SETTINGS" ]; then
    jq -M --arg key "${GEMINI_API_KEY:-}" '
      if ($key | length > 0) then .modelProvider = "gemini" else del(.modelProvider) end
    ' "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
fi

if [ -d /etc/antigravity/skills ]; then
    mkdir -p "$SKILLS_DIR" "$HOME/.gemini/config/skills"
    for skill_path in /etc/antigravity/skills/*; do
        if [ -d "$skill_path" ]; then
            sname="$(basename "$skill_path")"
            mkdir -p "$SKILLS_DIR/$sname" "$HOME/.gemini/config/skills/$sname"
            cp -a "$skill_path/." "$SKILLS_DIR/$sname/"
            cp -a "$skill_path/." "$HOME/.gemini/config/skills/$sname/"
        fi
    done
fi

# Enforcement obrigatório das regras do container (Zero Secret Leak)
CONFIG_DIR="$HOME/.gemini/config"
USER_AGENTS="$CONFIG_DIR/AGENTS.md"
mkdir -p "$CONFIG_DIR"

if [ -d /etc/antigravity/rules ]; then
    mkdir -p "$CONFIG_DIR/rules"
    cp -f /etc/antigravity/rules/* "$CONFIG_DIR/rules/" 2>/dev/null || true
fi

if [ ! -f "$USER_AGENTS" ]; then
    if [ -f /etc/antigravity/AGENTS.md ]; then
        cp /etc/antigravity/AGENTS.md "$USER_AGENTS"
    fi
else
    # Se o arquivo já existe no volume persistente mas a regra foi removida, restaura no topo
    if ! grep -q "Zero Secret Leak" "$USER_AGENTS" 2>/dev/null; then
        if [ -f /etc/antigravity/rules/zero-secret-leak.md ]; then
            TMP_AGENTS=$(mktemp)
            cat /etc/antigravity/rules/zero-secret-leak.md > "$TMP_AGENTS"
            printf "\n\n" >> "$TMP_AGENTS"
            cat "$USER_AGENTS" >> "$TMP_AGENTS"
            mv "$TMP_AGENTS" "$USER_AGENTS"
        fi
    fi
fi

MCP_CFG="$HOME/.gemini/config/mcp_config.json"
mkdir -p "$(dirname "$MCP_CFG")"
[ -s "$MCP_CFG" ] || echo '{}' > "$MCP_CFG"

BASE_MCP=""
[ -f /etc/antigravity/mcp_config.json ] && BASE_MCP="/etc/antigravity/mcp_config.json"

# Consolida merge de MCPs padrão e injeção dinâmica de gateway MCP via ambiente
jq -M -s \
  --arg gw_url "${MCP_GATEWAY_URL:-}" \
  --arg gw_token "${MCP_TOKEN:-}" '
    (if length > 1 then .[0] * .[1] else .[0] end) |
    if ($gw_url | length > 0) then
      .mcpServers.gateway = {
        serverUrl: $gw_url
      } + (if ($gw_token | length > 0) then { headers: { Authorization: ("Bearer " + $gw_token) } } else {} end)
    else . end
' "$MCP_CFG" ${BASE_MCP:+"$BASE_MCP"} > "$MCP_CFG.tmp" && mv "$MCP_CFG.tmp" "$MCP_CFG"

if [ "${AGY_VARIANT:-base}" = "rea" ]; then
    CLEANED_REA=0
    cleanup_rea() {
        [ "$CLEANED_REA" -eq 1 ] && return 0
        CLEANED_REA=1

        # 1. Remove servidor MCP rea do mcp_config.json
        if [ -f "$MCP_CFG" ] && grep -q '"rea"' "$MCP_CFG" 2>/dev/null; then
            jq 'del(.mcpServers.rea)' "$MCP_CFG" > "$MCP_CFG.tmp" 2>/dev/null && mv "$MCP_CFG.tmp" "$MCP_CFG"
        fi

        # 2. Remove a skill reverse-engineering do volume persistente
        rm -rf "$HOME/.gemini/config/skills/reverse-engineering" \
               "$SKILLS_DIR/reverse-engineering" 2>/dev/null || true

        # 3. Remove permissões do rea do settings.json
        if [ -f "$SETTINGS" ] && grep -q '"command(rea' "$SETTINGS" 2>/dev/null; then
            jq '.permissions.allow = [.permissions.allow[] | select(. != "command(rea)" and . != "command(rea *)")]' "$SETTINGS" > "$SETTINGS.tmp" 2>/dev/null && mv "$SETTINGS.tmp" "$SETTINGS"
        fi
    }

    # Injeta permissões para comandos do rea no settings.json temporariamente
    if [ -f "$SETTINGS" ]; then
        jq '.permissions.allow = ((.permissions.allow // []) + ["command(rea)", "command(rea *)"] | unique)' "$SETTINGS" > "$SETTINGS.tmp" 2>/dev/null && mv "$SETTINGS.tmp" "$SETTINGS"
    fi

    trap cleanup_rea EXIT INT TERM HUP
fi

if [ -z "$GEMINI_API_KEY" ] && [ ! -f "$SEED_DIR/antigravity-oauth-token" ]; then
    echo "[entrypoint] OAuth sem sessão ainda: rode 'agy auth login' (URL + código) ou apenas 'agy' e complete o login no terminal." >&2
fi

if [ "${AGY_VARIANT:-base}" = "rea" ]; then
    agy "$@"
    EXIT_CODE=$?
    exit $EXIT_CODE
else
    exec agy "$@"
fi