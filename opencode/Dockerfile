FROM node:lts-slim

ARG OPENCODE_VERSION=latest
ARG IMAGE_VERSION=dev
# Hash do script de setup: dá ao RUN a mesma invalidação de cache que o COPY
# tinha (engines antigas não hasheavam o conteúdo de RUN --mount; o build.sh
# calcula o valor)
ARG SETUP_HASH=
ENV OPENCODE_VARIANT=base

# Provisionamento (apt/npm) isolado: mudanças no /etc ou no entrypoint não
# devem invalidar esta camada cara. O script é montado por bind em vez de
# COPY: nenhuma camada temporária com o script nem resíduo na história
RUN --mount=type=bind,source=scripts/setup-base.sh,target=/tmp/setup-base.sh \
    echo "setup:${SETUP_HASH}" && bash /tmp/setup-base.sh "${OPENCODE_VERSION}"

# Estado imutável do /etc/opencode (atualização do /etc em runtime não existe;
# só o Dockerfile o atualiza) — camadas baratas, após o provisionamento
COPY entrypoint.sh /usr/local/bin/opencode-entrypoint.sh
COPY skills/container-ambiente/ /etc/opencode/skills/container-ambiente/
COPY rules/ /etc/opencode/rules/
COPY AGENTS.md /etc/opencode/AGENTS.md
COPY update/ /etc/opencode/update/

# Carimbo da versão: fonte de verdade das atualizações do perfil em runtime
RUN printf '%s\n' "${IMAGE_VERSION}" > /etc/opencode/.image-version \
    && chmod 755 /usr/local/bin/opencode-entrypoint.sh /etc/opencode/update/*.sh

WORKDIR /workspace
USER opencode

ENTRYPOINT ["/usr/local/bin/opencode-entrypoint.sh"]
CMD ["opencode"]
