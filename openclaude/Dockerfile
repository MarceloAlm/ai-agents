FROM node:lts-slim

# Executa provisionamento em passo único limpo via script dedicado
COPY scripts/setup-openclaude.sh /tmp/setup-openclaude.sh
RUN bash /tmp/setup-openclaude.sh && rm -f /tmp/setup-openclaude.sh

WORKDIR /workspace
USER node

CMD ["openclaude"]
