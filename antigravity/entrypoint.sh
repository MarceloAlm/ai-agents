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

if [ -f "$SETTINGS" ]; then
    # Mescla as configurações padrão de permissões, modelo e opções de execução,
    # preservando regras e personalizações customizadas do usuário.
    if [ -f /etc/antigravity/settings.json ]; then
        jq -M -s '
          .[0] as $defaults |
          .[1] as $user |
          ($defaults * $user) |
          .permissions.allow = (($defaults.permissions.allow // []) + ($user.permissions.allow // []) | unique) |
          .permissions.ask = (($defaults.permissions.ask // []) + ($user.permissions.ask // []) | unique)
        ' /etc/antigravity/settings.json "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
    fi
else
    if [ -f /etc/antigravity/settings.json ]; then
        cp /etc/antigravity/settings.json "$SETTINGS"
    fi
fi

if [ -d /etc/antigravity/skills/container-ambiente ]; then
    mkdir -p "$SKILLS_DIR" "$HOME/.gemini/config/skills"
    cp -r /etc/antigravity/skills/container-ambiente "$SKILLS_DIR/container-ambiente"
    cp -r /etc/antigravity/skills/container-ambiente "$HOME/.gemini/config/skills/container-ambiente"
fi

# Chaveamento dinâmico: API Key (Gemini) vs OAuth (conta Google)
if [ -n "$GEMINI_API_KEY" ]; then
    jq '.modelProvider = "gemini"' "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
else
    # Sem API key: remove modelProvider = "gemini" se presente, garantindo fluxo OAuth
    if jq -e '.modelProvider == "gemini"' "$SETTINGS" >/dev/null 2>&1; then
        jq 'del(.modelProvider)' "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
    fi
fi

# Injeção dinâmica de servidor ou gateway MCP via ambiente
if [ -n "$MCP_GATEWAY_URL" ]; then
    MCP_CFG="$HOME/.gemini/config/mcp_config.json"
    mkdir -p "$(dirname "$MCP_CFG")"
    [ -s "$MCP_CFG" ] || echo '{}' > "$MCP_CFG"

    FRAG=$(mktemp)
    if [ -n "$MCP_TOKEN" ]; then
        cat > "$FRAG" <<EOF
{
  "mcpServers": {
    "gateway": {
      "serverUrl": "$MCP_GATEWAY_URL",
      "headers": {
        "Authorization": "Bearer $MCP_TOKEN"
      }
    }
  }
}
EOF
    else
        cat > "$FRAG" <<EOF
{
  "mcpServers": {
    "gateway": {
      "serverUrl": "$MCP_GATEWAY_URL"
    }
  }
}
EOF
    fi
    jq -s '.[0] * .[1]' "$MCP_CFG" "$FRAG" > "$MCP_CFG.tmp" && mv "$MCP_CFG.tmp" "$MCP_CFG"
    rm -f "$FRAG"
fi

if [ -z "$GEMINI_API_KEY" ] && [ ! -f "$SEED_DIR/antigravity-oauth-token" ]; then
    echo "[entrypoint] OAuth sem sessão ainda: rode 'agy auth login' (URL + código) ou apenas 'agy' e complete o login no terminal." >&2
fi

exec agy "$@"