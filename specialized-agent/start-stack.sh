#!/bin/bash
# start-stack.sh - Inicializa a infraestrutura de serviços (Ollama / llama.cpp + SearXNG)
# em rede interna privada, sem expor nenhuma porta no host, com egress à internet.
set -e

BACKEND="${1:-${LLM_BACKEND:-ollama}}"
NETWORK="${CONTAINER_NETWORK:-specialized-net}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SEARX_SETTINGS="$SCRIPT_DIR/searxng/settings.yml"
MODELS_DIR="$SCRIPT_DIR/models"
mkdir -p "$MODELS_DIR"

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

echo "=================================================================="
echo "    INICIANDO STACK ISOLADA (BACKEND: ${BACKEND^^} + SEARXNG)    "
echo "=================================================================="
echo "Gerenciador:        $CONTAINER_CMD"
echo "Backend Neural:     $BACKEND (ollama, llamacpp ou all)"
echo "Rede Privada:       $NETWORK (sem portas expostas no host)"
echo "Acesso à Internet:  Habilitado (egress da bridge $NETWORK)"
echo "------------------------------------------------------------------"

# 1. Cria a rede privada se não existir
echo "[1/3] Configurando rede privada '$NETWORK'..."
$CONTAINER_CMD network create "$NETWORK" 2>/dev/null || true

GPU_FLAGS=()
if [ "$CONTAINER_CMD" = "podman" ]; then
    GPU_FLAGS=(--security-opt label=disable --device nvidia.com/gpu=all)
else
    GPU_FLAGS=(--gpus all)
fi

# 2. Inicializa o Backend Neural selecionado
if [ "$BACKEND" = "ollama" ] || [ "$BACKEND" = "all" ]; then
    echo "[2/3] Verificando container 'ollama'..."
    if $CONTAINER_CMD ps --format '{{.Names}}' 2>/dev/null | grep -q "^ollama$"; then
        echo "  • Container 'ollama' já está em execução na rede '$NETWORK'."
    else
        $CONTAINER_CMD rm -f ollama 2>/dev/null || true
        echo "  • Iniciando container 'ollama' com GPU NVIDIA (porta interna 11434)..."
        $CONTAINER_CMD run -d \
          --name ollama \
          --restart unless-stopped \
          --network "$NETWORK" \
          "${GPU_FLAGS[@]}" \
          -e OLLAMA_KEEP_ALIVE=24h \
          -v "ollama-models:/root/.ollama" \
          docker.io/ollama/ollama:latest
    fi
fi

if [ "$BACKEND" = "llamacpp" ] || [ "$BACKEND" = "all" ]; then
    echo "[2/3] Verificando container 'llamacpp'..."
    if $CONTAINER_CMD ps --format '{{.Names}}' 2>/dev/null | grep -q "^llamacpp$"; then
        echo "  • Container 'llamacpp' já está em execução na rede '$NETWORK'."
    else
        "$SCRIPT_DIR/llamacpp/start-llamacpp.sh"
    fi
fi

# 3. Inicializa o SearXNG em container isolado
echo "[3/3] Verificando container 'searxng'..."
if $CONTAINER_CMD ps --format '{{.Names}}' 2>/dev/null | grep -q "^searxng$"; then
    echo "  • Container 'searxng' já está em execução na rede '$NETWORK'."
else
    $CONTAINER_CMD rm -f searxng 2>/dev/null || true
    echo "  • Iniciando container 'searxng' (porta interna 8080)..."
    $CONTAINER_CMD run -d \
      --name searxng \
      --restart unless-stopped \
      --network "$NETWORK" \
      -v "$SEARX_SETTINGS:/etc/searxng/settings.yml:ro" \
      -e SEARXNG_BASE_URL=http://searxng:8080/ \
      docker.io/searxng/searxng:latest
fi

echo "------------------------------------------------------------------"
echo "Stack de serviços ativa com isolamento rigoroso:"
if [ "$BACKEND" = "ollama" ] || [ "$BACKEND" = "all" ]; then
    echo "  • Ollama:           http://ollama:11434 (acesso interno via '$NETWORK')"
fi
if [ "$BACKEND" = "llamacpp" ] || [ "$BACKEND" = "all" ]; then
    echo "  • llama.cpp:        http://llamacpp:8081/v1/chat/completions (acesso interno via '$NETWORK')"
fi
echo "  • SearXNG (Busca):  http://searxng:8080 (acesso interno via '$NETWORK')"
echo "  • Segurança Host:   NENHUMA porta exposta no host (protegido contra acessos externos)"
echo "  • Saída Externa:    Ambos containers possuem acesso à internet para downloads/consultas"
echo ""
echo "Para executar o agente nesta stack:"
if [ "$BACKEND" = "llamacpp" ]; then
    echo "  ./run-agent.sh --backend llamacpp -w exemplo-audit --web-search"
else
    echo "  ./run-agent.sh -w exemplo-audit --web-search"
fi
echo "=================================================================="
