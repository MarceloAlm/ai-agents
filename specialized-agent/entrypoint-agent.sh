#!/bin/bash
set -e

LLM_BACKEND="${LLM_BACKEND:-ollama}"
MODEL_NAME="${MODEL_NAME:-deepseek-r1:7b}"
OLLAMA_HOST="${OLLAMA_HOST:-http://ollama:11434}"
LLAMACPP_HOST="${LLAMACPP_HOST:-http://llamacpp:8081}"
SEARXNG_URL="${SEARXNG_URL:-http://searxng:8080}"

# Detecta backend nos argumentos passados na linha de comando
for ((i=1; i<=$#; i++)); do
    if [ "${!i}" = "--backend" ]; then
        next_idx=$((i + 1))
        LLM_BACKEND="${!next_idx}"
    elif [ "${!i}" = "llamacpp" ]; then
        LLM_BACKEND="llamacpp"
    fi
done

export LLM_BACKEND MODEL_NAME OLLAMA_HOST LLAMACPP_HOST SEARXNG_URL

echo "[Agent Boot] Conectando aos serviços internos na rede privada..."
echo "  • Backend Ativo:   $LLM_BACKEND"
echo "  • SearXNG Backend: $SEARXNG_URL"

if [ "$LLM_BACKEND" = "llamacpp" ]; then
    echo "  • llama.cpp Host:  $LLAMACPP_HOST"
    echo "[Agent Boot] Aguardando inicialização do llama-server em $LLAMACPP_HOST..."
    MAX_RETRIES=30
    COUNT=0
    while ! curl -s "$LLAMACPP_HOST/health" > /dev/null 2>&1 && ! curl -s "$LLAMACPP_HOST/v1/models" > /dev/null 2>&1; do
        sleep 1
        COUNT=$((COUNT + 1))
        if [ "$COUNT" -ge "$MAX_RETRIES" ]; then
            echo "[Agent Boot Erro] Tempo limite excedido ao aguardar llama.cpp em $LLAMACPP_HOST."
            exit 1
        fi
    done
    echo "[Agent Boot] llama-server conectado com sucesso."
else
    echo "  • Ollama Backend:  $OLLAMA_HOST"
    echo "[Agent Boot] Aguardando inicialização do Ollama em $OLLAMA_HOST..."
    MAX_RETRIES=30
    COUNT=0
    while ! curl -s "$OLLAMA_HOST/api/tags" > /dev/null 2>&1; do
        sleep 1
        COUNT=$((COUNT + 1))
        if [ "$COUNT" -ge "$MAX_RETRIES" ]; then
            echo "[Agent Boot Erro] Tempo limite excedido ao aguardar Ollama em $OLLAMA_HOST."
            exit 1
        fi
    done
    echo "[Agent Boot] Ollama conectado com sucesso."

    # Garante que o modelo desejado está disponível no Ollama via API REST
    if ! curl -s "$OLLAMA_HOST/api/tags" | grep -q "\"name\":\"${MODEL_NAME}\""; then
        echo "[Agent Boot] Modelo '$MODEL_NAME' não encontrado no Ollama. Efetuando pull via API..."
        curl -s -X POST "$OLLAMA_HOST/api/pull" \
             -H "Content-Type: application/json" \
             -d "{\"model\": \"$MODEL_NAME\", \"stream\": false}" >/dev/null || true
        echo "[Agent Boot] Pull do modelo '$MODEL_NAME' concluído."
    fi
fi

# Instala dependências Python adicionais se houver requirements.txt
if [ -f "/app/requirements.txt" ]; then
    echo "[Agent Boot] Instalando dependências em /app/requirements.txt..."
    pip3 install --no-cache-dir --break-system-packages -r /app/requirements.txt 2>/dev/null || pip3 install --no-cache-dir -r /app/requirements.txt || true
fi

# Executa o processo do agente especializado
exec python3 /app/agent.py "$@"
