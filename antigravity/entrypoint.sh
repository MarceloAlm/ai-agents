#!/bin/bash
set -e

# Seed da config CLI na primeira execução: o volume antigravity-home mascara
# /home/node, então na 1ª vez que o container roda a pasta chega vazia.
# O modo de autenticação é decidido aqui, em runtime (nada é fixado na imagem):
#   - Sem GEMINI_API_KEY  -> OAuth com conta do Google (Google AI Pro/Ultra)
#   - Com GEMINI_API_KEY  -> rota API key (headless/CI): modelProvider gemini
SEED_DIR="$HOME/.gemini/antigravity-cli"
SKILLS_DIR="$SEED_DIR/skills"
SETTINGS="$SEED_DIR/settings.json"
mkdir -p "$SKILLS_DIR"

if [ ! -f "$SETTINGS" ]; then
    if [ -n "${GEMINI_API_KEY:-}" ]; then
        printf '{\n  "modelProvider": "gemini"\n}\n' > "$SETTINGS"
    else
        printf '{}\n' > "$SETTINGS"
    fi
fi

if [ ! -f "$SKILLS_DIR/container-ambiente.md" ]; then
    cp /etc/antigravity/skills/container-ambiente.md "$SKILLS_DIR/container-ambiente.md"
fi

exec agy "$@"