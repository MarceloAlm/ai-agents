FROM node:lts-slim

# A base node:lts-slim já traz o usuário/grupo "node" com uid/gid 1000.
# Usuário opencode criado com uid/gid 1100 mapeado para o host com
# --userns=keep-id:uid=1100,gid=1100.
RUN mkdir -p /etc/sudoers.d && \
    groupadd --gid 1100 opencode && \
    useradd --uid 1100 --gid opencode --shell /bin/bash --create-home opencode && \
    echo "opencode ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/opencode && \
    chmod 0440 /etc/sudoers.d/opencode

# Ferramentas básicas de terminal
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ripgrep git ca-certificates curl wget jq unzip zip tree file sudo && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Configuração gerenciada do opencode
RUN mkdir -p /etc/opencode
COPY skills/container-ambiente/ /etc/opencode/skills/container-ambiente/
RUN printf '{\n  "$schema": "https://opencode.ai/config.json",\n  "skills": { "paths": ["/etc/opencode/skills"] },\n  "permission": {\n    "edit": "allow",\n    "bash": "allow",\n    "read": "allow",\n    "external_directory": { "*": "allow" }\n  }\n}\n' > /etc/opencode/opencode.json

# Entrypoint padrão com suporte a sincronização e marcação de variante
COPY entrypoint.sh /usr/local/bin/opencode-entrypoint.sh
RUN chmod +x /usr/local/bin/opencode-entrypoint.sh

ARG OPENCODE_VERSION=latest
RUN npm i -g opencode-ai@${OPENCODE_VERSION}

# Marcação da imagem base
ENV OPENCODE_VARIANT=base

RUN mkdir -p /workspace && chown opencode:opencode /workspace
WORKDIR /workspace
USER opencode

ENTRYPOINT ["/usr/local/bin/opencode-entrypoint.sh"]
CMD ["opencode"]
