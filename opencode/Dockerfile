FROM node:lts-slim

ARG OPENCODE_VERSION=latest
ENV OPENCODE_VARIANT=base

# Skills do container
COPY skills/container-ambiente/ /etc/opencode/skills/container-ambiente/

# Provisionamento completo da base e entrypoint em passo único
COPY entrypoint.sh scripts/setup-base.sh /tmp/setup/
RUN bash /tmp/setup/setup-base.sh "${OPENCODE_VERSION}" && rm -rf /tmp/setup

WORKDIR /workspace
USER opencode

ENTRYPOINT ["/usr/local/bin/opencode-entrypoint.sh"]
CMD ["opencode"]
