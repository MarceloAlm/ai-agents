FROM node:lts-slim

# Executa instalações do sistema e pacote npm em camada única
RUN apt-get update && \
    apt-get install -y --no-install-recommends ripgrep git ca-certificates && \
    npm install -g --no-fund --no-audit @gitlawb/openclaude && \
    npm cache clean --force && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR /workspace
USER node

CMD ["openclaude"]
