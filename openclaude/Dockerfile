FROM node:lts-slim

# Executa instalações do sistema como ROOT
RUN apt-get update && \
    apt-get install -y --no-install-recommends ripgrep git ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* 

RUN npm install -g @gitlawb/openclaude
WORKDIR /workspace
USER node

CMD ["openclaude"]
