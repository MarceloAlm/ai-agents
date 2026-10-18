# O agy é um binário NATIVO (Go), instalado via script — não usa Node.
# A base indicada é uma imagem mínima de SO (debian slim), sem runtime de Node.
FROM debian:trixie-slim

ARG AGY_VERSION=latest
ARG IMAGE_VERSION=dev
# Hash do script de setup para controle de invalidação de cache do RUN
ARG SETUP_HASH=

LABEL org.opencontainers.image.version="${AGY_VERSION}"

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

# Provisionamento completo do SO, ferramentas e assets em passo único.
# O script é montado por bind em vez de COPY: nenhuma camada temporária com o script na imagem.
RUN --mount=type=bind,source=scripts/setup-base.sh,target=/tmp/setup-base.sh \
    echo "setup:${SETUP_HASH}" && bash /tmp/setup-base.sh "${AGY_VERSION}"

# Estado imutável do /etc/antigravity e entrypoint — camadas baratas, após o provisionamento
COPY entrypoint.sh /usr/local/bin/antigravity-entrypoint.sh
COPY settings.json /etc/antigravity/settings.json
COPY skills/container-ambiente/ /etc/antigravity/skills/container-ambiente/
COPY rules/ /etc/antigravity/rules/
COPY AGENTS.md /etc/antigravity/AGENTS.md
COPY update/ /etc/antigravity/update/

# Carimbo da versão: fonte de verdade das atualizações do perfil em runtime
RUN printf '%s\n' "${IMAGE_VERSION}" > /etc/antigravity/.image-version \
    && chmod 755 /usr/local/bin/antigravity-entrypoint.sh /etc/antigravity/update/*.sh \
    && chmod -R 755 /etc/antigravity \
    && find /etc/antigravity -type f -exec chmod 644 {} + \
    && chmod 755 /etc/antigravity/update/*.sh

WORKDIR /workspace
USER antigravity

ENTRYPOINT ["/usr/local/bin/antigravity-entrypoint.sh"]