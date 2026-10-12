FROM node:lts-slim

ARG OPENCODE_VERSION=latest
ENV OPENCODE_VARIANT=base

# Cria usuário, instala ferramentas básicas, opencode-ai e prepara diretórios em camada única
RUN mkdir -p /etc/sudoers.d /etc/opencode /workspace && \
    groupadd --gid 1100 opencode && \
    useradd --uid 1100 --gid opencode --shell /bin/bash --create-home opencode && \
    echo "opencode ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/opencode && \
    chmod 0440 /etc/sudoers.d/opencode && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        ripgrep git ca-certificates curl wget jq unzip zip tree file sudo && \
    npm i -g --no-fund --no-audit opencode-ai@${OPENCODE_VERSION} && \
    npm cache clean --force && \
    chown opencode:opencode /workspace && \
    printf '{\n  "$schema": "https://opencode.ai/config.json",\n  "skills": { "paths": ["/etc/opencode/skills"] },\n  "permission": {\n    "edit": "allow",\n    "bash": "allow",\n    "read": "allow",\n    "external_directory": { "*": "allow" }\n  }\n}\n' > /etc/opencode/opencode.json && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Configuração e skills do opencode
COPY skills/container-ambiente/ /etc/opencode/skills/container-ambiente/
COPY --chmod=755 entrypoint.sh /usr/local/bin/opencode-entrypoint.sh

WORKDIR /workspace
USER opencode

ENTRYPOINT ["/usr/local/bin/opencode-entrypoint.sh"]
CMD ["opencode"]
