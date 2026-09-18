#!/bin/bash
set -e

# Seed da config CLI na primeira execução: o volume antigravity-home mascara
# /home/antigravity, então na 1ª vez que o container roda a pasta chega vazia.
#
# Autenticação: SEMPRE OAuth com conta do Google (Google AI Pro/Ultra). Nunca
# API key. O agy persiste o token em antigravity-oauth-token (FileKeychain, via
# GEMINI_FORCE_FILE_STORAGE=true na imagem). 1º login: rode `agy auth login`
# (ou apenas `agy`) e cole o código de autorização; depois autentica em silêncio.
SEED_DIR="$HOME/.gemini/antigravity-cli"
SKILLS_DIR="$SEED_DIR/skills"
SETTINGS="$SEED_DIR/settings.json"
mkdir -p "$SKILLS_DIR"

if [ -f "$SETTINGS" ]; then
    # OAuth sempre: remove qualquer modelProvider que forçaria API key e
    # mescla as configurações padrão de permissões, modelo e opções de execução,
    # preservando regras e personalizações customizadas do usuário.
    if [ -f /etc/antigravity/settings.json ]; then
        jq -M -s '
          .[0] as $defaults |
          .[1] as $user |
          ($defaults * $user) |
          .permissions.allow = (($defaults.permissions.allow // []) + ($user.permissions.allow // []) | unique) |
          .permissions.ask = (($defaults.permissions.ask // []) + ($user.permissions.ask // []) | unique) |
          del(.modelProvider)
        ' /etc/antigravity/settings.json "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
    fi
else
    if [ -f /etc/antigravity/settings.json ]; then
        cp /etc/antigravity/settings.json "$SETTINGS"
    fi
fi

if [ ! -f "$SKILLS_DIR/container-ambiente.md" ]; then
    cp /etc/antigravity/skills/container-ambiente.md "$SKILLS_DIR/container-ambiente.md"
fi

if [ ! -f "$SEED_DIR/antigravity-oauth-token" ]; then
    echo "[entrypoint] OAuth sem sessão ainda: rode 'agy auth login' (URL + código) ou apenas 'agy' e complete o login no terminal." >&2
fi

exec agy "$@"