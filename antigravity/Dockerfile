FROM node:lts-slim

# Instala ferramentas utilitárias que o agente usa no dia a dia (como ROOT)
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl jq git ripgrep ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Instala o CLI do Antigravity (binário nativo "agy", sempre a última versão).
# Instalado no PATH do sistema (/usr/local/bin) de propósito: em runtime o volume
# antigravity-home mascara /home/node, então nada do home sobrevive à 1ª execução.
# Com o binário fora do home, o auto-update em background falha em silêncio
# (user node não tem permissão de escrita em /usr/local/bin) — versão muda no rebuild.
RUN curl -fsSL https://antigravity.google/cli/install.sh | bash -s -- -d /usr/local/bin

# settings.json seedado como {}. A decisão de provedor acontece em runtime no
# entrypoint (nada é fixado na imagem):
#   - padrão (sem GEMINI_API_KEY) -> conta Google via OAuth (Google AI Pro/Ultra)
#   - com GEMINI_API_KEY          -> modelo via API (modelProvider gemini, headless/CI)
# A cópia em /etc/antigravity é usada pelo entrypoint para semear o volume na 1ª execução
# (o volume antigravity-home mascara /home/node, então a pasta chega vazia).
RUN mkdir -p /etc/antigravity/skills && \
    printf '{}\n' > /etc/antigravity/settings.json

# Skill informando o ambiente do container ao agente (path global de skills do CLI)
COPY skills/container-ambiente.md /etc/antigravity/skills/container-ambiente.md

COPY entrypoint.sh /usr/local/bin/antigravity-entrypoint.sh
RUN chmod +x /usr/local/bin/antigravity-entrypoint.sh

WORKDIR /workspace
USER node

ENTRYPOINT ["/usr/local/bin/antigravity-entrypoint.sh"]