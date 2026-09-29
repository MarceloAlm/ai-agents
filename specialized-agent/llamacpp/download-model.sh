#!/bin/bash
# download-model.sh - Utilitário para download de modelos GGUF do Hugging Face
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODELS_DIR="${MODELS_DIR:-$SCRIPT_DIR/../models}"
mkdir -p "$MODELS_DIR"

# Catálogo de modelos pré-configurados recomendados para o Specialized Agent
declare -A MODEL_MAP
MODEL_MAP["deepseek-r1:7b"]="https://huggingface.co/bartowski/DeepSeek-R1-Distill-Qwen-7B-GGUF/resolve/main/DeepSeek-R1-Distill-Qwen-7B-Q4_K_M.gguf"
MODEL_MAP["qwen2.5-coder:7b"]="https://huggingface.co/Qwen/Qwen2.5-Coder-7B-Instruct-GGUF/resolve/main/qwen2.5-coder-7b-instruct-q4_k_m.gguf"
MODEL_MAP["deepseek-r1:7b-q5"]="https://huggingface.co/bartowski/DeepSeek-R1-Distill-Qwen-7B-GGUF/resolve/main/DeepSeek-R1-Distill-Qwen-7B-Q5_K_M.gguf"

TARGET_MODEL="${1:-deepseek-r1:7b}"

echo "=================================================================="
echo "          DOWNLOAD DE MODELO GGUF PARA O LLAMA.CPP                "
echo "=================================================================="
echo "Diretório de destino: $MODELS_DIR"

if [[ -n "${MODEL_MAP[$TARGET_MODEL]}" ]]; then
    DOWNLOAD_URL="${MODEL_MAP[$TARGET_MODEL]}"
    FILENAME="$(basename "$DOWNLOAD_URL")"
elif [[ "$TARGET_MODEL" == http* ]]; then
    DOWNLOAD_URL="$TARGET_MODEL"
    FILENAME="$(basename "$DOWNLOAD_URL" | cut -d? -f1)"
else
    echo "Modelo '$TARGET_MODEL' não encontrado no catálogo pré-configurado."
    echo ""
    echo "Modelos conhecidos:"
    for k in "${!MODEL_MAP[@]}"; do
        echo "  • $k"
    done
    echo ""
    echo "Ou forneça uma URL direta do Hugging Face para o arquivo .gguf:"
    echo "  $0 https://huggingface.co/.../modelo.gguf"
    exit 1
fi

DEST_PATH="$MODELS_DIR/$FILENAME"

if [ -f "$DEST_PATH" ]; then
    echo "O arquivo '$FILENAME' já existe em $DEST_PATH."
    ls -lh "$DEST_PATH"
    echo ""
    echo "Para forçar novo download, remova o arquivo existente."
    exit 0
fi

echo "Iniciando download de:"
echo "  $DOWNLOAD_URL"
echo "Destino:"
echo "  $DEST_PATH"
echo "------------------------------------------------------------------"

curl -L -C - --progress-bar -o "$DEST_PATH" "$DOWNLOAD_URL"

echo ""
echo "Download concluído com sucesso!"
ls -lh "$DEST_PATH"
echo "=================================================================="
