#!/bin/bash
set -e

echo "[1/3] Iniciando o servidor Ollama..."
ollama serve &
OLLAMA_PID=$!

echo "Aguardando Ollama responder na porta 11434..."
while ! curl -s http://127.0.0.1:11434/api/tags > /dev/null; do
    sleep 1
done

echo "[2/3] Verificando e garantindo o modelo frob/ornith-1.5:9b-coding-Q5_K_M..."
if ! ollama list | grep -q "frob/ornith-1.5:9b-coding-Q5_K_M"; then
    echo "Modelo frob/ornith-1.5:9b-coding-Q5_K_M não encontrado. Baixando..."
    ollama pull frob/ornith-1.5:9b-coding-Q5_K_M
fi

echo "[3/3] Gerando configuração do LiteLLM (via backend OpenAI) e iniciando..."
cat <<EOF > /tmp/litellm_config.yaml
model_list:
  - model_name: ornith-1.5:9b-coding
    litellm_params:
      model: openai/frob/ornith-1.5:9b-coding-Q5_K_M
      api_base: http://127.0.0.1:11434/v1
      api_key: ollama

litellm_settings:
  drop_params: true
EOF

litellm --config /tmp/litellm_config.yaml --port 4000 --host 0.0.0.0 &
LITELLM_PID=$!

echo "=== Stack AI totalmente operacional! ==="
echo " - Endpoint Ollama Direct: http://localhost:11434"
echo " - Endpoint LiteLLM Proxy (OpenAI Tool-Calls): http://localhost:4000/v1"

wait -n $OLLAMA_PID $LITELLM_PID
