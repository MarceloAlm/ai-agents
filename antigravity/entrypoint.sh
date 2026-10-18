#!/bin/bash
set -e

ETC="${ANTIGRAVITY_ETC:-/etc/antigravity}"
UPDATE="${ANTIGRAVITY_UPDATE:-$ETC/update/run.sh}"

# Seed e sincronização da configuração na inicialização:
# O volume persistente antigravity-home mascara /home/antigravity.
SEED_DIR="$HOME/.gemini/antigravity-cli"
CONFIG_DIR="$HOME/.gemini/config"
SETTINGS="$SEED_DIR/settings.json"
MCP_CFG="$CONFIG_DIR/mcp_config.json"

mkdir -p "$SEED_DIR" "$CONFIG_DIR"

# 1. Atualizações do perfil gerenciadas pela versão da imagem
if [ -f "$UPDATE" ]; then
    bash "$UPDATE" || echo "[entrypoint] atualizações do perfil com falha (continua mesmo assim)" >&2
else
    # Fallback caso os scripts de update não estejam na imagem
    echo "${AGY_VARIANT:-base}" > "$SEED_DIR/variant"
    echo "${AGY_VARIANT:-base}" > "$CONFIG_DIR/variant"
    if [ -f "$ETC/AGENTS.md" ]; then
        cp -f "$ETC/AGENTS.md" "$CONFIG_DIR/AGENTS.md"
        chmod 0644 "$CONFIG_DIR/AGENTS.md" 2>/dev/null || true
    fi
fi

# 2. Mescla configurações padrão de permissões, modelo e chaveamento de autenticação
if [ -f "$ETC/settings.json" ]; then
    if [ -f "$SETTINGS" ]; then
        jq -M -s --arg key "${GEMINI_API_KEY:-}" '
          .[0] as $defaults |
          .[1] as $user |
          (($defaults * $user) |
           .permissions.allow = (($defaults.permissions.allow // []) + ($user.permissions.allow // []) | unique) |
           .permissions.ask = (($defaults.permissions.ask // []) + ($user.permissions.ask // []) | unique)) |
          if ($key | length > 0) then .modelProvider = "gemini" else del(.modelProvider) end
        ' "$ETC/settings.json" "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
    else
        jq -M --arg key "${GEMINI_API_KEY:-}" '
          if ($key | length > 0) then .modelProvider = "gemini" else del(.modelProvider) end
        ' "$ETC/settings.json" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
    fi
elif [ -f "$SETTINGS" ]; then
    jq -M --arg key "${GEMINI_API_KEY:-}" '
      if ($key | length > 0) then .modelProvider = "gemini" else del(.modelProvider) end
    ' "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
fi

# 3. Consolidação de MCPs padrão e injeção dinâmica de gateway MCP via ambiente
[ -s "$MCP_CFG" ] || echo '{}' > "$MCP_CFG"
BASE_MCP=""
[ -f "$ETC/mcp_config.json" ] && BASE_MCP="$ETC/mcp_config.json"

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

# 4. Tratamento de isolamento para a variante rea (Reverse Engineering)
if [ "${AGY_VARIANT:-base}" = "rea" ]; then
    CLEANED_REA=0
    cleanup_rea() {
        [ "$CLEANED_REA" -eq 1 ] && return 0
        CLEANED_REA=1

        # Remove servidor MCP rea do mcp_config.json
        if [ -f "$MCP_CFG" ] && grep -q '"rea"' "$MCP_CFG" 2>/dev/null; then
            jq 'del(.mcpServers.rea)' "$MCP_CFG" > "$MCP_CFG.tmp" 2>/dev/null && mv "$MCP_CFG.tmp" "$MCP_CFG"
        fi

        # Remove a skill reverse-engineering do volume persistente
        rm -rf "$CONFIG_DIR/skills/reverse-engineering" 2>/dev/null || true

        # Remove permissões do rea do settings.json
        if [ -f "$SETTINGS" ] && grep -q '"command(rea' "$SETTINGS" 2>/dev/null; then
            jq '.permissions.allow = [.permissions.allow[] | select(. != "command(rea)" and . != "command(rea *)")]' "$SETTINGS" > "$SETTINGS.tmp" 2>/dev/null && mv "$SETTINGS.tmp" "$SETTINGS"
        fi
    }

    # Injeta a skill reverse-engineering temporariamente na sessão
    REA_SKILL_SRC=""
    if [ -d "$ETC/rea-skills/reverse-engineering" ]; then
        REA_SKILL_SRC="$ETC/rea-skills/reverse-engineering"
    elif [ -d "$ETC/skills/reverse-engineering" ]; then
        REA_SKILL_SRC="$ETC/skills/reverse-engineering"
    fi
    if [ -n "$REA_SKILL_SRC" ]; then
        mkdir -p "$CONFIG_DIR/skills/reverse-engineering"
        cp -a "$REA_SKILL_SRC/." "$CONFIG_DIR/skills/reverse-engineering/"
    fi

    # Injeta permissões para comandos do rea no settings.json temporariamente
    if [ -f "$SETTINGS" ]; then
        jq '.permissions.allow = ((.permissions.allow // []) + ["command(rea)", "command(rea *)"] | unique)' "$SETTINGS" > "$SETTINGS.tmp" 2>/dev/null && mv "$SETTINGS.tmp" "$SETTINGS"
    fi

    trap cleanup_rea EXIT INT TERM HUP
fi

# 5. Notificação de autenticação OAuth se necessária
if [ -z "${GEMINI_API_KEY:-}" ] && [ ! -f "$SEED_DIR/antigravity-oauth-token" ]; then
    echo "[entrypoint] OAuth sem sessão ainda: rode 'agy auth login' (URL + código) ou apenas 'agy' e complete o login no terminal." >&2
fi

# 6. Execução do agente
if [ "${AGY_VARIANT:-base}" = "rea" ]; then
    agy "$@"
    EXIT_CODE=$?
    exit $EXIT_CODE
else
    exec agy "$@"
fi