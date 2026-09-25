#!/bin/bash
set -e

MODEL_NAME="${MODEL_NAME:-deepseek-r1:7b}"
export MODEL_NAME

if [ "${VERBOSE:-0}" = "1" ]; then
    ollama serve &
else
    ollama serve > /tmp/ollama.log 2>&1 &
fi
OLLAMA_PID=$!

cleanup() {
    # shellcheck disable=SC2317
    echo "[Shutdown] Finalizando processos do container..."
    # shellcheck disable=SC2317
    kill -TERM "$OLLAMA_PID" 2>/dev/null || true
    # shellcheck disable=SC2317
    wait "$OLLAMA_PID" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# Aguarda o Ollama estar pronto
while ! curl -s http://127.0.0.1:11434/api/tags > /dev/null; do
    sleep 0.5
done

# Garante que o modelo desejado está disponível
if ! ollama show "$MODEL_NAME" >/dev/null 2>&1; then
    echo "[Boot] Modelo '$MODEL_NAME' não encontrado localmente. Efetuando pull..."
    ollama pull "$MODEL_NAME"
fi

# Executa o processo do agente especializado
python3 /app/agent.py "$@"
EXIT_CODE=$?

exit $EXIT_CODE
