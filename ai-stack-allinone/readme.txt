STACK AI - Ollama + LiteLLM + opencode
=======================================

Stack contida nos arquivos deste diretorio:
  Dockerfile       - imagem com Ollama + LiteLLM proxy
  entrypoint.sh    - sobe Ollama, garante o modelo e configura o LiteLLM
  run-ai-stack.sh  - build e execucao do container via podman
  ai-stack         - config de acesso do opencode ao modelo (fonte)
  opencode.json    - copia do ai-stack, auto-descoberta pelo opencode

Modelo utilizado: frob/ornith-1.5:9b-coding-Q5_K_M (variante de codificacao,
temp 0.6 / presence_penalty 0, ~7.4GB). No proxy LiteLLM ele e exposto pelo
alias ornith-1.5:9b-coding; no opencode o id e ollama/ornith-1.5:9b-coding.


1) SUBIR O CONTAINER DO OLLAMA/LITELLM
--------------------------------------
  ./run-ai-stack.sh

  O primeiro boot baixa o modelo frob/ornith-1.5:9b-coding-Q5_K_M (~7.4GB).
  Para remover o modelo antigo ornith-1.5:9b (6.6GB) da imagem, se ainda
  estiver instalado: podman exec ollama ollama rm ornith-1.5:9b

  Acompanhe o boot:
  podman logs -f ai-stack-container

  O container publica:
    - 11434 -> API nativa do Ollama
    - 4000  -> LiteLLM proxy (OpenAI-compatible /v1, com tool-calls)

  Testar o proxy (use -4: o pasta do podman descarta conexoes IPv6 na 4000;
  pelo proxy use o alias sem barra):
  curl -4 http://localhost:4000/v1/chat/completions \
    -H "Content-Type: application/json" \
    -d '{"model":"ornith-1.5:9b-coding","messages":[{"role":"user","content":"oi"}]}'

  Testar o Ollama direto (nome real, com namespace frob/):
  curl http://localhost:11434/api/tags


2) CONFIGURAR O OPENCODE (container separado)
---------------------------------------------
  O arquivo "opencode.json" e a config do opencode. Ele ja esta na raiz do
  projeto, onde o opencode descobre automaticamente quando roda a partir
  deste diretorio (baseURL host.containers.internal:4000/v1, que ja foi
  testado e funciona de dentro do container do opencode). Modelo:
  ollama/ornith-1.5:9b-coding.

  Manter "ai-stack" sincronizado como fonte: e a mesma config.

  Rede entre os containers:
    - Rede padrao: host.containers.internal:4000 (testado OK por dentro).
    - Se o opencode rodar com --network host, troque para
      http://localhost:4000/v1.

  IMPORTANTE: reinicie o opencode apos mudar a config (nao ha hot-reload).


3) TESTAR COM O OPENCODE
-----------------------
  opencode --model ollama/ornith-1.5:9b-coding run "crie um arquivo ola.txt"

  Nota de contexto: o Dockerfile define OLLAMA_CONTEXT_LENGTH=16384 para
  testes agentic (o default de 4k estoura rapido). Ajuste se necessario.

  Nota de tokens: este modelo razoa antes de responder e e lento (~17 tok/s).
  Use max_tokens alto (2048-4096) para codigo, senao ele gasta o orcamento
  "pensando" e retorna resposta vazia. Streaming via LiteLLM nao entrega
  reasoning (buffer ate o fim) - em C# prefira chamadas nao-streaming.