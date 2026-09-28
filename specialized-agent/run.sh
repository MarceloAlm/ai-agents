#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Se o 1º argumento não começar com '-' e for informado, assume que é o MODEL_NAME.
# Exemplos de uso:
#   ./run.sh                                    -> executa com deepseek-r1:7b
#   ./run.sh qwen2.5-coder:7b                   -> executa com outro modelo
#   ./run.sh --list-works                       -> lista os trabalhos disponíveis
#   ./run.sh deepseek-r1:7b -w meu-trabalho -d alvo.com
#   MODELO="deepseek-r1:7b"; SITE="inb.gov.br"; ./specialized-agent/run.sh "$MODELO" -w modsec-analise-waf -d "$SITE" | tee "${MODELO}_${SITE}.txt"
MODEL="${MODEL_NAME:-deepseek-r1:7b}"
NUM_CTX="${OLLAMA_NUM_CTX:-8192}"
if [ $# -gt 0 ] && [[ "$1" != -* ]]; then
    MODEL="$1"
    shift
fi

echo "Executando specialized-agent com o modelo: $MODEL (contexto: ${NUM_CTX} tokens, GPU NVIDIA)..."
podman run --rm -it \
  --security-opt label=disable \
  --device nvidia.com/gpu=all \
  ${CONTAINER_NETWORK:+--network "$CONTAINER_NETWORK"} \
  -e MODEL_NAME="$MODEL" \
  -e OLLAMA_NUM_CTX="$NUM_CTX" \
  -v "ollama-models:/root/.ollama" \
  -v "$SCRIPT_DIR:/app" \
  specialized-agent -m "$MODEL" --num-ctx "$NUM_CTX" "$@"
