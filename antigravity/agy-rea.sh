#!/bin/bash
# Antigravity CLI com REA (Reverse Engineer Anything) em container
# Compartilha o MESMO volume "antigravity-home" do agy padrão (mesmo login OAuth, tokens e histórico).
#
# Uso:
#   agy-rea              # Inicia o agente de engenharia reversa no diretório atual
#   agy-rea auth login   # Realiza login se ainda não autenticado

IMAGE_NAME="antigravity:rea"

ARGS=(
    podman run --rm -it "--userns=keep-id:uid=1100,gid=1100"
    --hostname antigravity
    -v "antigravity-home:/home/antigravity"
    -v "$PWD:/workspace"
    -w /workspace
)

# Repassa credenciais, flags e endpoints MCP se definidos no host
[ -n "$GEMINI_API_KEY" ] && ARGS+=(-e "GEMINI_API_KEY=$GEMINI_API_KEY")
[ -n "$MCP_GATEWAY_URL" ] && ARGS+=(-e "MCP_GATEWAY_URL=$MCP_GATEWAY_URL")
[ -n "$MCP_TOKEN" ] && ARGS+=(-e "MCP_TOKEN=$MCP_TOKEN")
[ -n "$GHIDRA_INSTALL_DIR" ] && ARGS+=(-e "GHIDRA_INSTALL_DIR=$GHIDRA_INSTALL_DIR")

ARGS+=("$IMAGE_NAME" "$@")
exec "${ARGS[@]}"
