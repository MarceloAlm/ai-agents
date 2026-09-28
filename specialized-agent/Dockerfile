FROM docker.io/ollama/ollama:latest

ENV DEBIAN_FRONTEND=noninteractive
ENV OLLAMA_HOST=127.0.0.1:11434

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-venv \
    git \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copia os arquivos do projeto para o container
COPY . /app

# Configura o entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh /app/agent.py /app/*.sh 2>/dev/null || true

ENTRYPOINT ["/entrypoint.sh"]
