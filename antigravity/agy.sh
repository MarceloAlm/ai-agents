#!/bin/bash
# Antigravity CLI (agy) em container — Padrão OAuth (conta do Google). Aceita API key se passada.
# 1º login: rode  agy auth login  (ou apenas agy) -> imprime a URL de autorização; abra no
# navegador, entre com a conta e cole o código exibido. O token é persistido em
# ~/.gemini/antigravity-cli/antigravity-oauth-token (GEMINI_FORCE_FILE_STORAGE=true).
#
# --hostname antigravity: hostname fixo -> chave estável de criptografia do FileKeychain.

ARGS=(
    podman run --rm -it "--userns=keep-id:uid=1100,gid=1100"
    --hostname antigravity
    -v "antigravity-home:/home/antigravity"
    -v "$PWD:/workspace"
    -w /workspace
)

# Repassa credenciais e endpoints MCP se definidos no host
[ -n "$GEMINI_API_KEY" ] && ARGS+=(-e "GEMINI_API_KEY=$GEMINI_API_KEY")
[ -n "$MCP_GATEWAY_URL" ] && ARGS+=(-e "MCP_GATEWAY_URL=$MCP_GATEWAY_URL")
[ -n "$MCP_TOKEN" ] && ARGS+=(-e "MCP_TOKEN=$MCP_TOKEN")

ARGS+=(antigravity:latest "$@")
exec "${ARGS[@]}"

