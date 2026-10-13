FROM node:lts-slim

ARG OPENCODE_VERSION=latest
ENV OPENCODE_VARIANT=base

# Executa provisionamento da base via script modular em camada única
COPY scripts/setup-base.sh /tmp/setup-base.sh
RUN bash /tmp/setup-base.sh "${OPENCODE_VERSION}" && rm -f /tmp/setup-base.sh

# Configurações e skills do opencode
COPY skills/container-ambiente/ /etc/opencode/skills/container-ambiente/
COPY --chmod=755 entrypoint.sh /usr/local/bin/opencode-entrypoint.sh

WORKDIR /workspace
USER opencode

ENTRYPOINT ["/usr/local/bin/opencode-entrypoint.sh"]
CMD ["opencode"]
