#!/bin/bash
# run-agent.sh - Executa o agente especializado conectado à stack desacoplada (Ollama ou llama.cpp)
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NETWORK="${CONTAINER_NETWORK:-specialized-net}"
OLLAMA_HOST="${OLLAMA_HOST:-http://ollama:11434}"
LLAMACPP_HOST="${LLAMACPP_HOST:-http://llamacpp:8081}"
SEARXNG_URL="${SEARXNG_URL:-http://searxng:8080}"
MODEL="${MODEL_NAME:-qwen2.5-coder:7b}"
NUM_CTX="${OLLAMA_NUM_CTX:-8192}"

# Detecta backend e modelo nos argumentos
BACKEND="${LLM_BACKEND:-ollama}"
for ((i=1; i<=$#; i++)); do
    case "${!i}" in
        llamacpp|--llamacpp)
            BACKEND="llamacpp"
            ;;
        -m|--model)
            next_idx=$((i + 1))
            MODEL="${!next_idx}"
            ;;
        --num-ctx|--ctx|-c)
            next_idx=$((i + 1))
            NUM_CTX="${!next_idx}"
            ;;
    esac
done

if [ $# -gt 0 ] && [[ "$1" != -* ]] && [ "$1" != "llamacpp" ] && [ "$1" != "ollama" ]; then
    MODEL="$1"
    shift
fi

CONTAINER_CMD="${CONTAINER_TOOL:-podman}"
if ! command -v "$CONTAINER_CMD" >/dev/null 2>&1; then
    CONTAINER_CMD="docker"
fi

# Garante que os serviços necessários da stack estão em execução
if [ "$BACKEND" = "llamacpp" ]; then
    REQUIRED_CONTAINER="llamacpp"
else
    REQUIRED_CONTAINER="ollama"
fi

if $CONTAINER_CMD ps --format '{{.Names}}' 2>/dev/null | grep -q "^${REQUIRED_CONTAINER}$"; then
    # Detecta a rede em que o container já está rodando
    DETECTED_NET="$($CONTAINER_CMD inspect "$REQUIRED_CONTAINER" --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}}{{end}}' 2>/dev/null || true)"
    if [ -n "$DETECTED_NET" ]; then
        NETWORK="$DETECTED_NET"
    fi
else
    echo "[Aviso] Container '${REQUIRED_CONTAINER}' não está ativo na rede '$NETWORK'."
    echo "Iniciando a infraestrutura de serviços via ./start-stack.sh $BACKEND..."
    "$SCRIPT_DIR/start-stack.sh" "$BACKEND"
fi

# Se a imagem standalone não existir, constrói automaticamente
if ! $CONTAINER_CMD image inspect specialized-agent:standalone >/dev/null 2>&1; then
    echo "[Boot] Imagem specialized-agent:standalone não encontrada. Compilando..."
    "$SCRIPT_DIR/build-agent.sh"
fi

echo "Executando specialized-agent conectado à rede privada '$NETWORK'..."
echo "  • Backend: $BACKEND"
echo "  • Ollama:  $OLLAMA_HOST"
echo "  • llama:   $LLAMACPP_HOST"
echo "  • SearXNG: $SEARXNG_URL"
echo "  • Modelo:  $MODEL"

$CONTAINER_CMD run --rm -it \
  --network "$NETWORK" \
  -e MODEL_NAME="$MODEL" \
  -e LLM_BACKEND="$BACKEND" \
  -e OLLAMA_HOST="$OLLAMA_HOST" \
  -e LLAMACPP_HOST="$LLAMACPP_HOST" \
  -e SEARXNG_URL="$SEARXNG_URL" \
  -e ENABLE_WEB_SEARCH="${ENABLE_WEB_SEARCH:-1}" \
  -e OLLAMA_NUM_CTX="$NUM_CTX" \
  -v "$SCRIPT_DIR:/app" \
  -v "$SCRIPT_DIR/entrypoint-agent.sh:/entrypoint-agent.sh:ro" \
  specialized-agent:standalone -m "$MODEL" --num-ctx "$NUM_CTX" --backend "$BACKEND" "$@"
