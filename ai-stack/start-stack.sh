#!/bin/bash
# start-stack.sh - Inicializa o Hub Central de Provedores de IA (ai-stack)
# Serviços: Ollama, llama.cpp (llama-server com GPU/Flash Attention/KV Quant) e SearXNG (busca)
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SEARX_SETTINGS="$SCRIPT_DIR/searxng/settings.yml"
MODELS_DIR="$SCRIPT_DIR/models"
mkdir -p "$MODELS_DIR"

NETWORK="${CONTAINER_NETWORK:-ai-stack-net}"
CONTAINER_CMD="${CONTAINER_TOOL:-podman}"
LLAMA_PORT="${LLAMACPP_PORT:-8081}"
OLLAMA_PORT="${OLLAMA_PORT:-11434}"
SEARX_PORT="${SEARXNG_PORT:-8080}"
CTX_SIZE="${LLAMA_CTX_SIZE:-8192}"

# Processa parâmetros de linha de comando
BACKEND="llamacpp"
EXPOSE_MODE="host-local" # 'host-local' (127.0.0.1) ou 'isolated' (zero host exposure)

while [[ $# -gt 0 ]]; do
    case "$1" in
        ollama|llamacpp|all)
            BACKEND="$1"
            shift
            ;;
        --isolate|--isolated)
            EXPOSE_MODE="isolated"
            shift
            ;;
        --expose|--host-local)
            EXPOSE_MODE="host-local"
            shift
            ;;
        --ctx|-c)
            CTX_SIZE="$2"
            shift 2
            ;;
        *)
            echo "Parâmetro desconhecido: $1"
            echo "Uso: $0 [ollama|llamacpp|all] [--expose|--isolate] [--ctx 8192]"
            exit 1
            ;;
    esac
done

# Detecta podman ou docker
if ! command -v "$CONTAINER_CMD" >/dev/null 2>&1; then
    if command -v docker >/dev/null 2>&1; then
        CONTAINER_CMD="docker"
    else
        echo "Erro: nem 'podman' nem 'docker' foram encontrados no sistema."
        exit 1
    fi
fi

echo "=================================================================="
echo "    INICIANDO AI-STACK: HUB CENTRAL DE PROVEDORES DE IA           "
echo "=================================================================="
echo "Gerenciador:        $CONTAINER_CMD"
echo "Backend Principal:  ${BACKEND^^}"
echo "Rede Principal:     $NETWORK"
echo "Modo de Exposição:  $EXPOSE_MODE $([ "$EXPOSE_MODE" = "host-local" ] && echo "(127.0.0.1 seguro)" || echo "(Zero Host Exposure)")"
echo "Janela Contexto:    $CTX_SIZE tokens"
echo "------------------------------------------------------------------"

# 1. Configura as redes de containers compartilhadas
echo "[1/4] Configurando rede compartilhada '$NETWORK'..."
$CONTAINER_CMD network create "$NETWORK" 2>/dev/null || true
# Garante compatibilidade com scripts do specialized-net
$CONTAINER_CMD network create "specialized-net" 2>/dev/null || true

# Configura flags de aceleração GPU
GPU_FLAGS=()
if [ "$CONTAINER_CMD" = "podman" ]; then
    GPU_FLAGS=(--security-opt label=disable --device nvidia.com/gpu=all)
else
    GPU_FLAGS=(--gpus all)
fi

# Fallback se não houver GPU NVIDIA
HAS_GPU=true
if ! command -v nvidia-smi >/dev/null 2>&1 && [ ! -e "/dev/nvidia0" ]; then
    echo "[Aviso] GPU NVIDIA não detectada. Modo CPU ativado."
    HAS_GPU=false
    GPU_FLAGS=()
fi

# 2. Inicializa o Ollama se solicitado
if [ "$BACKEND" = "ollama" ] || [ "$BACKEND" = "all" ]; then
    echo "[2/4] Verificando container 'ollama'..."
    if $CONTAINER_CMD ps --format '{{.Names}}' 2>/dev/null | grep -q "^ollama$"; then
        echo "  • Container 'ollama' já está ativo."
    else
        $CONTAINER_CMD rm -f ollama 2>/dev/null || true
        PORT_MAP=()
        if [ "$EXPOSE_MODE" = "host-local" ]; then
            PORT_MAP=(-p "127.0.0.1:${OLLAMA_PORT}:11434")
        fi

        echo "  • Inicializando container 'ollama'..."
        $CONTAINER_CMD run -d \
          --name ollama \
          --restart unless-stopped \
          --network "$NETWORK" \
          "${PORT_MAP[@]}" \
          "${GPU_FLAGS[@]}" \
          -e OLLAMA_KEEP_ALIVE=24h \
          -v "ollama-models:/root/.ollama" \
          docker.io/ollama/ollama:latest
    fi
fi

# 3. Inicializa o llama.cpp (llama-server) se solicitado
if [ "$BACKEND" = "llamacpp" ] || [ "$BACKEND" = "all" ]; then
    echo "[3/4] Verificando container 'llamacpp'..."
    if $CONTAINER_CMD ps --format '{{.Names}}' 2>/dev/null | grep -q "^llamacpp$"; then
        echo "  • Container 'llamacpp' já está ativo."
    else
        # Localiza modelos .gguf na pasta models (Router Mode)
        LOCAL_MODELS="$(find "$MODELS_DIR" -maxdepth 2 -name "*.gguf" 2>/dev/null || true)"
        MODEL_ARGS=()

        if [ -n "$LOCAL_MODELS" ]; then
            TOTAL_MODELS=$(echo "$LOCAL_MODELS" | grep -c "\.gguf" || true)
            echo "  • Modo ROUTER ativo: $TOTAL_MODELS modelo(s) .gguf gerenciado(s) em $MODELS_DIR."
            MODEL_ARGS=(
                --models-dir "/models"
                --models-max 1
            )
        else
            echo "  • Nenhum modelo local .gguf encontrado em $MODELS_DIR."
            echo "  • O container baixará automaticamente na inicialização via Hugging Face (Qwen 2.5 Coder 7B Q4_K_M)..."
            MODEL_ARGS=(
                --hf-repo "Qwen/Qwen2.5-Coder-7B-Instruct-GGUF"
                --hf-file "qwen2.5-coder-7b-instruct-q4_k_m.gguf"
            )
        fi

        LLAMA_IMAGE="ghcr.io/ggml-org/llama.cpp:server-cuda"
        if [ "$HAS_GPU" = false ]; then
            LLAMA_IMAGE="ghcr.io/ggml-org/llama.cpp:server"
        fi

        PORT_MAP=()
        if [ "$EXPOSE_MODE" = "host-local" ]; then
            PORT_MAP=(-p "127.0.0.1:${LLAMA_PORT}:${LLAMA_PORT}")
        fi

        $CONTAINER_CMD rm -f llamacpp 2>/dev/null || true
        echo "  • Inicializando container 'llamacpp'..."
        $CONTAINER_CMD run -d \
          --name llamacpp \
          --restart unless-stopped \
          --network "$NETWORK" \
          "${PORT_MAP[@]}" \
          "${GPU_FLAGS[@]}" \
          -v "$MODELS_DIR:/models" \
          "$LLAMA_IMAGE" \
          "${MODEL_ARGS[@]}" \
          --host 0.0.0.0 \
          --port "$LLAMA_PORT" \
          -ngl 99 \
          --flash-attn auto \
          -c "$CTX_SIZE" \
          -ctk q8_0 \
          -ctv q8_0 \
          --parallel 1 \
          --metrics
    fi
fi

# 4. Inicializa o SearXNG
echo "[4/4] Verificando container 'searxng'..."
if $CONTAINER_CMD ps --format '{{.Names}}' 2>/dev/null | grep -q "^searxng$"; then
    echo "  • Container 'searxng' já está ativo."
else
    $CONTAINER_CMD rm -f searxng 2>/dev/null || true
    PORT_MAP=()
    if [ "$EXPOSE_MODE" = "host-local" ]; then
        PORT_MAP=(-p "127.0.0.1:${SEARX_PORT}:8080")
    fi

    echo "  • Inicializando container 'searxng'..."
    $CONTAINER_CMD run -d \
      --name searxng \
      --restart unless-stopped \
      --network "$NETWORK" \
      "${PORT_MAP[@]}" \
      -v "$SEARX_SETTINGS:/etc/searxng/settings.yml:ro" \
      -e SEARXNG_BASE_URL=http://searxng:8080/ \
      docker.io/searxng/searxng:latest
fi

echo "------------------------------------------------------------------"
echo "AI-STACK EM OPERAÇÃO COM SUCESSO!"
echo ""
echo "Endpoints Internos (dentro da rede '$NETWORK'):"
if [ "$BACKEND" = "llamacpp" ] || [ "$BACKEND" = "all" ]; then
    echo "  • llama.cpp OpenAI API: http://llamacpp:${LLAMA_PORT}/v1/chat/completions"
fi
if [ "$BACKEND" = "ollama" ] || [ "$BACKEND" = "all" ]; then
    echo "  • Ollama API:            http://ollama:${OLLAMA_PORT}"
    echo "  • Ollama OpenAI API:     http://ollama:${OLLAMA_PORT}/v1"
fi
echo "  • SearXNG Busca API:     http://searxng:8080 (formato JSON)"

if [ "$EXPOSE_MODE" = "host-local" ]; then
    echo ""
    echo "Endpoints Locais (Host e Podman host.containers.internal):"
    if [ "$BACKEND" = "llamacpp" ] || [ "$BACKEND" = "all" ]; then
        echo "  • llama.cpp (OpenCode):  http://127.0.0.1:${LLAMA_PORT}/v1 (ou host.containers.internal:${LLAMA_PORT}/v1)"
    fi
    if [ "$BACKEND" = "ollama" ] || [ "$BACKEND" = "all" ]; then
        echo "  • Ollama (OpenCode):     http://127.0.0.1:${OLLAMA_PORT}/v1 (ou host.containers.internal:${OLLAMA_PORT}/v1)"
    fi
    echo "  • SearXNG:               http://127.0.0.1:${SEARX_PORT}"
fi
echo "=================================================================="
