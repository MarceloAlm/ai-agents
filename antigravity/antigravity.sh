#!/bin/bash
# Antigravity CLI usando a API do Google (Gemini).
# Exporte a chave antes de rodar:  export GEMINI_API_KEY=...  (https://aistudio.google.com/app/api-keys)
# Endpoint compatível custom (opcional): export GOOGLE_GEMINI_BASE_URL=...
ARGS=(
    podman run --rm -it --userns=keep-id
    -v "antigravity-home:/home/node"
    -v "$PWD:/workspace"
    -v "/etc/ssl/certs:/etc/ssl/certs:ro"
    -w /workspace
)
if [ -n "${GEMINI_API_KEY:-}" ]; then
    ARGS+=(-e GEMINI_API_KEY)
fi
if [ -n "${GOOGLE_GEMINI_BASE_URL:-}" ]; then
    ARGS+=(-e GOOGLE_GEMINI_BASE_URL)
fi
ARGS+=(antigravity:latest)
exec "${ARGS[@]}"