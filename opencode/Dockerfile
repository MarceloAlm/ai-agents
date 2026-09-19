FROM node:lts-slim

# A base node:lts-slim já traz o usuário/grupo "node" com uid/gid 1000
# (necessário para o Node/npm). Para não conflitar, o usuário padrão
# "opencode" é criado com uid/gid 1100, e os scripts de execução mapeiam no
# podman com --userns=keep-id:uid=1100,gid=1100 (container 1100 -> host 1000),
# mantendo o host dono de /workspace e /home/opencode. Dependências do agente
# (config, credenciais, histórico, cache npm) vivem em /home/opencode, montado
# como volume persistente opencode-home.
RUN mkdir -p /etc/sudoers.d && \
    groupadd --gid 1100 opencode && \
    useradd --uid 1100 --gid opencode --shell /bin/bash --create-home opencode && \
    echo "opencode ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/opencode && \
    chmod 0440 /etc/sudoers.d/opencode

# Executa instalações do sistema como ROOT
RUN apt-get update && \
    apt-get install -y --no-install-recommends ripgrep git ca-certificates sudo && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* 

# Skill informando o ambiente do container ao opencode + config gerenciada
# registrando a pasta de skills (/etc/opencode é o local de configs gerenciadas no Linux)
RUN mkdir -p /etc/opencode
COPY skills/container-ambiente/ /etc/opencode/skills/container-ambiente/
RUN printf '{\n  "$schema": "https://opencode.ai/config.json",\n  "skills": { "paths": ["/etc/opencode/skills"] }\n}\n' > /etc/opencode/opencode.json

ARG OPENCODE_VERSION=latest
RUN npm i -g opencode-ai@${OPENCODE_VERSION}
RUN mkdir -p /workspace && chown opencode:opencode /workspace
WORKDIR /workspace
USER opencode

CMD ["opencode"]
