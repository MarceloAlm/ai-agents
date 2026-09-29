#!/bin/bash
# clean.sh - Limpeza completa da infraestrutura de containers, imagens, volumes e modelos baixados
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Detecta podman ou docker
CONTAINER_CMD="${CONTAINER_TOOL:-podman}"
if ! command -v "$CONTAINER_CMD" >/dev/null 2>&1; then
    if command -v docker >/dev/null 2>&1; then
        CONTAINER_CMD="docker"
    else
        CONTAINER_CMD="podman"
    fi
fi

FORCE=false
REMOVE_BASE_IMAGES=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -y|--yes|--force)
            FORCE=true
            shift
            ;;
        --all-images)
            REMOVE_BASE_IMAGES=true
            shift
            ;;
        *)
            echo "Parâmetro desconhecido: $1"
            echo "Uso: $0 [-y|--force] [--all-images]"
            exit 1
            ;;
    esac
done

echo "=================================================================="
echo "          AI-STACK & SPECIALIZED AGENT: LIMPEZA COMPLETA          "
echo "=================================================================="
echo "Gerenciador:        $CONTAINER_CMD"
echo "Diretório Raiz:     $ROOT_DIR"
echo "------------------------------------------------------------------"
echo "Esta operação irá:"
echo "  1. Parar e remover todos os containers (llamacpp, ollama, searxng, specialized-agent)"
echo "  2. Remover as redes privadas (ai-stack-net, specialized-net)"
echo "  3. Remover os volumes de dados persistentes (ollama-models)"
echo "  4. Remover imagens do agente (specialized-agent:standalone, specialized-agent)"
echo "  5. Excluir todos os modelos .gguf baixados em models/"
if [ "$REMOVE_BASE_IMAGES" = true ]; then
    echo "  6. Remover imagens base (llama.cpp, ollama, searxng)"
fi
echo "=================================================================="

if [ "$FORCE" = false ]; then
    read -p "Deseja realmente prosseguir com a limpeza total? [s/N]: " CONFIRM
    if [[ ! "$CONFIRM" =~ ^[sS](im)?$ ]]; then
        echo "Operação cancelada pelo usuário."
        exit 0
    fi
    echo ""
fi

# 1. Parar e remover containers
echo "[1/5] Parando e removendo containers..."
CONTAINERS=("llamacpp" "ollama" "searxng" "specialized-agent")
for c in "${CONTAINERS[@]}"; do
    if $CONTAINER_CMD ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^${c}$"; then
        echo "  • Removendo container '$c'..."
        $CONTAINER_CMD rm -f "$c" 2>/dev/null || true
    fi
done

# 2. Remover redes
echo "[2/5] Removendo redes privadas..."
NETWORKS=("ai-stack-net" "specialized-net")
for n in "${NETWORKS[@]}"; do
    if $CONTAINER_CMD network ls --format '{{.Name}}' 2>/dev/null | grep -q "^${n}$"; then
        echo "  • Removendo rede '$n'..."
        $CONTAINER_CMD network rm "$n" 2>/dev/null || true
    fi
done

# 3. Remover volumes
echo "[3/5] Removendo volumes de dados..."
VOLUMES=("ollama-models" "ai-stack_ollama-models" "specialized-agent_ollama-models")
for v in "${VOLUMES[@]}"; do
    if $CONTAINER_CMD volume ls --format '{{.Name}}' 2>/dev/null | grep -q "^${v}$"; then
        echo "  • Removendo volume '$v'..."
        $CONTAINER_CMD volume rm -f "$v" 2>/dev/null || true
    fi
done

# 4. Remover imagens locais do agente
echo "[4/5] Removendo imagens do specialized-agent..."
IMAGES=("specialized-agent:standalone" "specialized-agent:latest" "localhost/specialized-agent:standalone")
for img in "${IMAGES[@]}"; do
    if $CONTAINER_CMD images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | grep -q "^${img}$"; then
        echo "  • Removendo imagem '$img'..."
        $CONTAINER_CMD rmi -f "$img" 2>/dev/null || true
    fi
done

if [ "$REMOVE_BASE_IMAGES" = true ]; then
    echo "  • Removendo imagens base dos provedores..."
    BASE_IMAGES=(
        "ghcr.io/ggml-org/llama.cpp:server-cuda"
        "ghcr.io/ggml-org/llama.cpp:server"
        "docker.io/ollama/ollama:latest"
        "docker.io/searxng/searxng:latest"
        "docker.io/python:3.12-slim"
    )
    for bimg in "${BASE_IMAGES[@]}"; do
        $CONTAINER_CMD rmi -f "$bimg" 2>/dev/null || true
    done
fi

# 5. Excluir modelos .gguf baixados
echo "[5/5] Removendo arquivos de modelos .gguf baixados..."
MODEL_DIRS=(
    "$ROOT_DIR/ai-stack/models"
    "$ROOT_DIR/specialized-agent/models"
    "$ROOT_DIR/models"
)

TOTAL_REMOVED=0
for mdir in "${MODEL_DIRS[@]}"; do
    if [ -d "$mdir" ]; then
        FILES_COUNT=$(find "$mdir" -type f \( -name "*.gguf" -o -name "*.bin" -o -name "*.downloadInProgress" \) 2>/dev/null | wc -l)
        if [ "$FILES_COUNT" -gt 0 ]; then
            echo "  • Limpando $FILES_COUNT arquivo(s) em $mdir..."
            find "$mdir" -type f \( -name "*.gguf" -o -name "*.bin" -o -name "*.downloadInProgress" \) -delete 2>/dev/null || true
            TOTAL_REMOVED=$((TOTAL_REMOVED + FILES_COUNT))
        fi
        rm -rf "$mdir/hf-cache" 2>/dev/null || true
    fi
done

echo "------------------------------------------------------------------"
echo "LIMPEZA CONCLUÍDA COM SUCESSO!"
echo "  • Containers parados e removidos."
echo "  • Volumes e redes limpos."
echo "  • Imagens locais removidas."
echo "  • Modelos .gguf liberados do disco ($TOTAL_REMOVED arquivos)."
echo "=================================================================="
