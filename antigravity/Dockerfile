# O agy é um binário NATIVO (Go), instalado via script — não usa Node.
# A base indicada é uma imagem mínima de SO (debian slim), sem runtime de Node.
FROM debian:trixie-slim

# Variáveis de ambiente consolidadas
ENV PATH="/dotnet-tools:${PATH}" \
    DOTNET_CLI_TELEMETRY_OPTOUT=1 \
    DOTNET_NOLOGO=1 \
    DOTNET_RUNNING_IN_CONTAINER=true \
    GEMINI_FORCE_FILE_STORAGE=true \
    TZ=America/Sao_Paulo \
    LANG=pt_BR.UTF-8 \
    LANGUAGE=pt_BR:pt:en \
    LC_ALL=pt_BR.UTF-8 \
    EDITOR=vim \
    VISUAL=vim \
    AGY_VARIANT=base

ARG AGY_VERSION=latest
LABEL org.opencontainers.image.version="${AGY_VERSION}"

# Skills do container
COPY skills/container-ambiente/ /etc/antigravity/skills/container-ambiente/

# Provisionamento completo do SO, ferramentas e assets em passo único
COPY settings.json entrypoint.sh scripts/setup-base.sh /tmp/setup/
RUN bash /tmp/setup/setup-base.sh "${AGY_VERSION}" && rm -rf /tmp/setup

WORKDIR /workspace
USER antigravity

ENTRYPOINT ["/usr/local/bin/antigravity-entrypoint.sh"]