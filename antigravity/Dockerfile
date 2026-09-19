# O agy é um binário NATIVO (Go), instalado via script — não usa Node.
# A base indicada é uma imagem mínima de SO (debian slim), sem runtime de Node.
FROM debian:bookworm-slim

# Instala ferramentas utilitárias, de rede e de análise de logs (como ROOT)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl jq git ripgrep ca-certificates file procps \
        tzdata dnsutils traceroute iputils-ping \
        unzip zip dos2unix gawk less zstd sudo && \
    ln -snf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime && \
    echo "America/Sao_Paulo" > /etc/timezone && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Instalação do .NET 10 SDK (repositório oficial Microsoft para Debian 12)
RUN curl -fsSL https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb -o packages-microsoft-prod.deb && \
    dpkg -i packages-microsoft-prod.deb && \
    rm packages-microsoft-prod.deb && \
    apt-get update && \
    apt-get install -y --no-install-recommends dotnet-sdk-10.0 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Ferramentas globais .NET para diagnóstico e análise de dumps/métricas de servidores
RUN dotnet tool install --tool-path /dotnet-tools dotnet-trace \
    && dotnet tool install --tool-path /dotnet-tools dotnet-counters \
    && dotnet tool install --tool-path /dotnet-tools dotnet-dump
ENV PATH="/dotnet-tools:${PATH}" \
    DOTNET_CLI_TELEMETRY_OPTOUT=1 \
    DOTNET_NOLOGO=1 \
    DOTNET_RUNNING_IN_CONTAINER=true

# Autenticação OAuth do agy em container headless (sempre conta Google, sem API key):
#  - GEMINI_FORCE_FILE_STORAGE=true -> token em arquivo (FileKeychain) em vez do keyring
#    nativo (dbus/keytar), que falha em silêncio num container sem GUI.
#  - TZ=America/Sao_Paulo          -> Fuso horário oficial de Brasília (BRT, UTC-3).
#  - SSH_CLIENT/SSH_CONNECTION/SSH_TTY -> agy detecta ambiente "remoto" e usa o fluxo
#    manual (URL de autorização + código), sem depender de navegador.
ENV GEMINI_FORCE_FILE_STORAGE=true
ENV TZ=America/Sao_Paulo
ENV SSH_CLIENT="203.0.113.1 50000 22"
ENV SSH_CONNECTION="203.0.113.1 50000 203.0.113.2 22"
ENV SSH_TTY="/dev/pts/0"

# Usuário antigravity (uid 1000): mantém --userns=keep-id e o volume
# antigravity-home montado em /home/antigravity (debian slim não traz usuário).
RUN groupadd --gid 1000 antigravity && \
    useradd --uid 1000 --gid antigravity --shell /bin/bash --create-home antigravity && \
    echo "antigravity ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/antigravity && \
    chmod 0440 /etc/sudoers.d/antigravity

# Instala o CLI do Antigravity (binário nativo "agy", sempre a última versão).
# Instalado no PATH do sistema (/usr/local/bin) de propósito: em runtime o volume
# antigravity-home mascara /home/antigravity, então nada do home sobrevive à 1ª execução.
# Com o binário fora do home, o auto-update em background falha em silêncio
# (user antigravity não tem permissão de escrita em /usr/local/bin) — versão muda no rebuild.
RUN curl -fsSL https://antigravity.google/cli/install.sh | bash -s -- -d /usr/local/bin

# settings.json seedado com permissões de consulta, modelo e toolPermission da sessão.
# Este agente usa SEMPRE OAuth com conta do Google (Google AI Pro/Ultra) — nunca GEMINI_API_KEY.
# A cópia em /etc/antigravity é usada pelo entrypoint para semear o volume na 1ª execução
# (o volume antigravity-home mascara /home/antigravity, então a pasta chega vazia).
RUN mkdir -p /etc/antigravity/skills
COPY settings.json /etc/antigravity/settings.json

# Skill informando o ambiente do container ao agente (path global de skills do CLI)
COPY skills/container-ambiente.md /etc/antigravity/skills/container-ambiente.md

COPY entrypoint.sh /usr/local/bin/antigravity-entrypoint.sh
RUN chmod +x /usr/local/bin/antigravity-entrypoint.sh

WORKDIR /workspace
USER antigravity

ENTRYPOINT ["/usr/local/bin/antigravity-entrypoint.sh"]