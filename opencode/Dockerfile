FROM node:lts-slim

ARG OPENCODE_VERSION=latest
ENV OPENCODE_VARIANT=base

# Skills e regras base do container
COPY skills/container-ambiente/ /etc/opencode/skills/container-ambiente/
COPY rules/ /etc/opencode/rules/
COPY AGENTS.md /etc/opencode/AGENTS.md

# Provisionamento completo da base e entrypoint em passo único
COPY entrypoint.sh scripts/setup-base.sh /tmp/setup/
RUN bash /tmp/setup/setup-base.sh "${OPENCODE_VERSION}" && rm -rf /tmp/setup

WORKDIR /workspace
USER opencode

ENTRYPOINT ["/usr/local/bin/opencode-entrypoint.sh"]
CMD ["opencode"]
