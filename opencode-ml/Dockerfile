FROM node:lts-slim

# A base node:lts-slim já traz o usuário/grupo "node" com uid/gid 1000
# (necessário para o Node/npm). Para não conflitar, o usuário padrão
# "opencode" é criado com uid/gid 1100, e os scripts de execução mapeiam no
# podman com --userns=keep-id:uid=1100,gid=1100 (container 1100 -> host 1000),
# mantendo o host dono de /workspace e /home/opencode.
RUN mkdir -p /etc/sudoers.d && \
    groupadd --gid 1100 opencode && \
    useradd --uid 1100 --gid opencode --shell /bin/bash --create-home opencode && \
    echo "opencode ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/opencode && \
    chmod 0440 /etc/sudoers.d/opencode

# Base + ferramentas de linha de comando + Python (numpy/matplotlib) para
# gerar gráficos de curva de perda/acurácia durante o estudo de ML
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ripgrep git ca-certificates curl wget jq unzip zip tree file \
        python3 python3-numpy python3-matplotlib sudo && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# .NET SDK 10 (mesma base do opencode:dotnet)
RUN wget -q https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb -O packages-microsoft-prod.deb && \
    dpkg -i packages-microsoft-prod.deb && rm packages-microsoft-prod.deb && \
    apt-get update && \
    apt-get install -y --no-install-recommends dotnet-sdk-10.0 && \
    rm -rf /var/lib/apt/lists/*

# Ferramentas .NET: perf, análise estática, LSP C# e runner de scripts .csx
# (dotnet-script 2.x tem build net10.0, roda no SDK 10)
RUN dotnet tool install --tool-path /dotnet-tools dotnet-trace \
    && dotnet tool install --tool-path /dotnet-tools dotnet-counters \
    && dotnet tool install --tool-path /dotnet-tools dotnet-dump \
    && dotnet tool install --tool-path /dotnet-tools dotnet-script \
    && dotnet tool install --tool-path /dotnet-tools roslynator.dotnet.cli \
    && dotnet tool install --tool-path /dotnet-tools roslyn-language-server --prerelease \
    # O pacote roslyn-language-server extrai os binários nativos com modo 744
    # (sem bit de execução), impedindo o lançamento do processo filho.
    # Corrigir para 755 e dar escrita do cache MEF ao usuário opencode.
    && find /dotnet-tools/.store/roslyn-language-server -type f \
       \( -name 'roslyn-language-server' -o -name 'Microsoft.CodeAnalysis.LanguageServer' \) \
       -exec chmod +x {} +
RUN chown -R opencode:opencode /dotnet-tools
ENV PATH="/dotnet-tools:${PATH}"
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1 \
    DOTNET_NOLOGO=1

# Exemplos de referência para estudo de redes neurais (read-only; copie para /workspace)
COPY ml-reference /opt/ml

# Config gerenciada do opencode: LSP habilitado por padrão + acesso às pastas
# sem pedir permissão a cada operação + registro da skill de ambiente
RUN mkdir -p /etc/opencode && \
    printf '{\n  "$schema": "https://opencode.ai/config.json",\n  "lsp": true,\n  "skills": { "paths": ["/etc/opencode/skills"] },\n  "permission": {\n    "edit": "allow",\n    "bash": "allow",\n    "read": "allow",\n    "external_directory": { "*": "allow" }\n  }\n}\n' > /etc/opencode/opencode.json
COPY skills/container-ambiente/ /etc/opencode/skills/container-ambiente/

ARG OPENCODE_VERSION=latest
RUN npm i -g opencode-ai@${OPENCODE_VERSION}
RUN mkdir -p /workspace && chown opencode:opencode /workspace
WORKDIR /workspace
USER opencode

CMD ["opencode"]