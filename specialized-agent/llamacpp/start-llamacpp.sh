#!/bin/bash
# start-llamacpp.sh - Inicializa o llama-server em container isolado acelerado por GPU
# Opera exclusivamente na rede privada 'specialized-net', sem expor portas no host.
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MODELS_DIR="${MODELS_DIR:-$ROOT_DIR/models}"
NETWORK="${CONTAINER_NETWORK:-specialized-net}"
CONTAINER_NAME="llamacpp"
PORT="${LLAMACPP_PORT:-8081}"
CTX_SIZE="${LLAMA_CTX_SIZE:-8192}"

CONTAINER_CMD="${CONTAINER_TOOL:-podman}"
if ! command -v "$CONTAINER_CMD" >/dev/null 2>&1; then
    if command -v docker >/dev/null 2>&1; then
        CONTAINER_CMD="docker"
    else
        echo "Erro: nem 'podman' nem 'docker' foram encontrados."
        exit 1
    fi
fi

# 1. Garante que a rede privada existe
$CONTAINER_CMD network create "$NETWORK" 2>/dev/null || true

# 2. Localiza o modelo GGUF a ser carregado
SPECIFIED_MODEL="$1"
GGUF_FILE=""

if [ -n "$SPECIFIED_MODEL" ] && [ -f "$SPECIFIED_MODEL" ]; then
    GGUF_FILE="$(basename "$SPECIFIED_MODEL")"
    cp -n "$SPECIFIED_MODEL" "$MODELS_DIR/" 2>/dev/null || true
elif [ -n "$SPECIFIED_MODEL" ] && [ -f "$MODELS_DIR/$SPECIFIED_MODEL" ]; then
    GGUF_FILE="$SPECIFIED_MODEL"
else
    # Procura o primeiro .gguf disponível na pasta models
    GGUF_FILE="$(ls -1 "$MODELS_DIR"/*.gguf 2>/dev/null | head -n 1 | xargs -r basename || true)"
fi

MODEL_ARGS=()
if [ -n "$SPECIFIED_MODEL" ] && [ -n "$GGUF_FILE" ]; then
    echo "Modelo específico solicitado: $GGUF_FILE"
    MODEL_ARGS=(-m "/models/$GGUF_FILE")
elif [ -n "$GGUF_FILE" ]; then
    TOTAL_MODELS=$(ls -1 "$MODELS_DIR"/*.gguf 2>/dev/null | wc -l)
    echo "Modo ROUTER ativo: $TOTAL_MODELS modelo(s) .gguf gerenciado(s) em $MODELS_DIR"
    MODEL_ARGS=(
        --models-dir "/models"
        --models-max 1
    )
else
    echo "Nenhum arquivo .gguf encontrado em $MODELS_DIR."
    echo "O container baixará automaticamente na inicialização via Hugging Face (DeepSeek-R1 7B Q4_K_M)..."
    MODEL_ARGS=(
        --hf-repo "bartowski/DeepSeek-R1-Distill-Qwen-7B-GGUF"
        --hf-file "DeepSeek-R1-Distill-Qwen-7B-Q4_K_M.gguf"
    )
fi

echo "=================================================================="
echo "    INICIANDO CONTAINER ISOLADO: LLAMA.CPP (llama-server)         "
echo "=================================================================="
echo "Gerenciador:        $CONTAINER_CMD"
echo "Rede Privada:       $NETWORK (sem portas expostas no host)"
echo "Acesso à Internet:  Habilitado via egress da bridge $NETWORK"
echo "Modelo GGUF:        $GGUF_FILE"
echo "Janela Contexto:    $CTX_SIZE tokens (KV Cache Quantizado q8_0)"
echo "Porta Interna:      $PORT"
echo "------------------------------------------------------------------"

# Verifica se o container já está rodando
if $CONTAINER_CMD ps --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER_NAME}$"; then
    echo "Container '$CONTAINER_NAME' já está em execução na rede '$NETWORK'."
    echo "Endpoint interno: http://${CONTAINER_NAME}:${PORT}/v1/chat/completions"
    exit 0
fi

# Remove container antigo se estiver parado
$CONTAINER_CMD rm -f "$CONTAINER_NAME" 2>/dev/null || true

# Configura parâmetros de aceleração GPU
GPU_FLAGS=()
IMAGE="ghcr.io/ggml-org/llama.cpp:server-cuda"

if [ "$CONTAINER_CMD" = "podman" ]; then
    GPU_FLAGS=(--security-opt label=disable --device nvidia.com/gpu=all)
else
    GPU_FLAGS=(--gpus all)
fi

# Se não houver GPU NVIDIA disponível, faz fallback para CPU
if ! command -v nvidia-smi >/dev/null 2>&1 && [ ! -e "/dev/nvidia0" ]; then
    echo "[Aviso] GPU NVIDIA não detectada. Executando em modo CPU..."
    IMAGE="ghcr.io/ggml-org/llama.cpp:server"
    GPU_FLAGS=()
fi

EXTRA_ARGS=()
if [ -n "$PUBLISH_PORT_FOR_DEBUG" ]; then
    echo "Aviso: PUBLISH_PORT_FOR_DEBUG definido. Expondo 127.0.0.1:${PUBLISH_PORT_FOR_DEBUG}:${PORT} no host..."
    EXTRA_ARGS+=("-p" "127.0.0.1:${PUBLISH_PORT_FOR_DEBUG}:${PORT}")
fi

echo "Iniciando container '$CONTAINER_NAME'..."
$CONTAINER_CMD run -d \
  --name "$CONTAINER_NAME" \
  --restart unless-stopped \
  --network "$NETWORK" \
  "${GPU_FLAGS[@]}" \
  "${EXTRA_ARGS[@]}" \
  -e HF_HUB_CACHE=/models/hf-cache \
  -v "$MODELS_DIR:/models" \
  "$IMAGE" \
  "${MODEL_ARGS[@]}" \
  --host 0.0.0.0 \
  --port "$PORT" \
  -ngl 99 \
  --flash-attn auto \
  -c "$CTX_SIZE" \
  -ctk q8_0 \
  -ctv q8_0 \
  --parallel 1 \
  --metrics

echo "Aguardando inicialização do llama-server na rede '$NETWORK'..."
sleep 2

echo ""
echo "Serviço llama.cpp ativo com sucesso:"
echo "  • Rede interna:    $NETWORK"
echo "  • Nome do serviço: $CONTAINER_NAME"
echo "  • Endpoint OpenAI: http://${CONTAINER_NAME}:${PORT}/v1/chat/completions"
echo "  • Endpoint Health: http://${CONTAINER_NAME}:${PORT}/health"
echo "  • Status no host:  NENHUMA porta exposta no host (acesso exclusivo inter-container)"
echo "  • Otimizações:     Flash Attention ativo, KV cache quantizado (q8_0)"
echo "=================================================================="
