FROM node:lts-slim

# Executa instalações do sistema como ROOT
RUN apt-get update && \
    apt-get install -y --no-install-recommends ripgrep git ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* 

# Skill informando o ambiente do container ao opencode + config gerenciada
# registrando a pasta de skills (/etc/opencode é o local de configs gerenciadas no Linux)
RUN mkdir -p /etc/opencode
COPY skills/container-ambiente/SKILL.md /etc/opencode/skills/container-ambiente/SKILL.md
RUN printf '{\n  "$schema": "https://opencode.ai/config.json",\n  "skills": { "paths": ["/etc/opencode/skills"] }\n}\n' > /etc/opencode/opencode.json

ARG OPENCODE_VERSION=latest
RUN npm i -g opencode-ai@${OPENCODE_VERSION}
WORKDIR /workspace
USER node

CMD ["opencode"]
