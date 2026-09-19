#!/bin/bash
# Antigravity CLI (agy) em container — SEMPRE OAuth (conta do Google), nunca API key.
# 1º login: rode  antigravity auth login  -> imprime a URL de autorização; abra no
# navegador, entre com a conta e cole o código exibido. O token é persistido em
# ~/.gemini/antigravity-cli/antigravity-oauth-token (GEMINI_FORCE_FILE_STORAGE=true).
#
# --hostname antigravity: hostname fixo -> chave estável de criptografia do FileKeychain.
ARGS=(
    podman run --rm -it --userns=keep-id
    --hostname antigravity
    -v "antigravity-home:/home/antigravity"
    -v "$PWD:/workspace"
    -w /workspace
)
ARGS+=(antigravity:latest "$@")
exec "${ARGS[@]}"