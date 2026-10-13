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

# Provisionamento completo do SO, .NET 10, usuário e CLI em passo único e limpo
COPY scripts/setup-base.sh /tmp/setup-base.sh
RUN bash /tmp/setup-base.sh --version "${AGY_VERSION}" && rm -f /tmp/setup-base.sh

# Configurações semeadas e skills
COPY settings.json /etc/antigravity/settings.json
COPY skills/container-ambiente/ /etc/antigravity/skills/container-ambiente/

# Entrypoint com permissão de execução
COPY --chmod=755 entrypoint.sh /usr/local/bin/antigravity-entrypoint.sh

WORKDIR /workspace
USER antigravity

ENTRYPOINT ["/usr/local/bin/antigravity-entrypoint.sh"]