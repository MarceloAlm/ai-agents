#!/bin/bash
# run-searxng.sh - Inicializador do container isolado do SearXNG em rede privada
set -e

CONTAINER_NAME="searxng"
NETWORK="${CONTAINER_NETWORK:-specialized-net}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETTINGS_PATH="$SCRIPT_DIR/settings.yml"

# Detecta podman ou docker
CONTAINER_CMD="${CONTAINER_TOOL:-podman}"
if ! command -v "$CONTAINER_CMD" >/dev/null 2>&1; then
    if command -v docker >/dev/null 2>&1; then
        CONTAINER_CMD="docker"
    else
        echo "Erro: nem 'podman' nem 'docker' foram encontrados no sistema."
        exit 1
    fi
fi

if [ ! -f "$SETTINGS_PATH" ]; then
    echo "Erro: Arquivo $SETTINGS_PATH não encontrado."
    exit 1
fi

echo "=================================================================="
echo "    INICIANDO CONTAINER ISOLADO: SEARXNG (Metabuscador Privado)   "
echo "=================================================================="
echo "Ferramenta de container: $CONTAINER_CMD"
echo "Rede interna privada:    $NETWORK (sem portas expostas no host)"
echo "Acesso à internet:       Habilitado via egress da rede $NETWORK"
echo "Arquivo de Settings:     $SETTINGS_PATH"
echo "------------------------------------------------------------------"

# Garante que a rede interna isolada existe
$CONTAINER_CMD network create "$NETWORK" 2>/dev/null || true

# Verifica se o container já está rodando
if $CONTAINER_CMD ps --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER_NAME}$"; then
    echo "O container '$CONTAINER_NAME' já está em execução na rede '$NETWORK'."
    echo "Endpoint interno: http://${CONTAINER_NAME}:8080/search?q=teste&format=json"
    exit 0
fi

# Remove container antigo se estiver parado
$CONTAINER_CMD rm -f "$CONTAINER_NAME" 2>/dev/null || true

# Executa o container isolado na rede especializada sem expor portas no host
EXTRA_ARGS=()
if [ -n "$PUBLISH_PORT_FOR_DEBUG" ]; then
    echo "Aviso: PUBLISH_PORT_FOR_DEBUG definido. Expondo 127.0.0.1:${PUBLISH_PORT_FOR_DEBUG}:8080 no host..."
    EXTRA_ARGS+=("-p" "127.0.0.1:${PUBLISH_PORT_FOR_DEBUG}:8080")
fi

$CONTAINER_CMD run -d \
  --name "$CONTAINER_NAME" \
  --network "$NETWORK" \
  "${EXTRA_ARGS[@]}" \
  -v "$SETTINGS_PATH:/etc/searxng/settings.yml:ro" \
  docker.io/searxng/searxng:latest

echo "Aguardando inicialização do SearXNG na rede '$NETWORK'..."
sleep 2

echo ""
echo "Instância SearXNG ativa:"
echo "  • Rede interna:    $NETWORK"
echo "  • Nome do serviço: $CONTAINER_NAME"
echo "  • Endpoint interno:http://${CONTAINER_NAME}:8080/search?q=exemplo&format=json"
echo "  • Status no host:  NENHUMA porta exposta no host (acesso exclusivo inter-container)"
echo "  • Conexão externa: Egress de internet ativo para consultas"
echo "=================================================================="
