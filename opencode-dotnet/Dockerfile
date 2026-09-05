FROM node:lts-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ripgrep git ca-certificates curl wget jq unzip zip tree file && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# .NET SDK 10
RUN wget -q https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb -O packages-microsoft-prod.deb && \
    dpkg -i packages-microsoft-prod.deb && rm packages-microsoft-prod.deb && \
    apt-get update && \
    apt-get install -y --no-install-recommends dotnet-sdk-10.0 && \
    rm -rf /var/lib/apt/lists/*

# Ferramentas .NET
RUN dotnet tool install --tool-path /dotnet-tools dotnet-trace \
    && dotnet tool install --tool-path /dotnet-tools dotnet-counters \
    && dotnet tool install --tool-path /dotnet-tools dotnet-dump \
    && dotnet tool install --tool-path /dotnet-tools roslynator.dotnet.cli \
    # Server LSP C# usado pelo built-in do opencode
    && dotnet tool install --tool-path /dotnet-tools roslyn-language-server --prerelease \
    # O pacote roslyn-language-server extrai os binários nativos com modo 744
    # (sem bit de execução), impedindo o lançamento do processo filho
    # Microsoft.CodeAnalysis.LanguageServer. Corrigir para 755.
    && find /dotnet-tools/.store/roslyn-language-server -type f \
       \( -name 'roslyn-language-server' -o -name 'Microsoft.CodeAnalysis.LanguageServer' \) \
       -exec chmod +x {} +
ENV PATH="/dotnet-tools:${PATH}"
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1 \
    DOTNET_NOLOGO=1

# Config gerenciada do opencode (/etc/opencode): LSP por padrão + acesso
# às pastas sem pedir permissão a cada operação (read/edit/bash/external)
# + registro da skill de ambiente do container (skills.paths)
RUN mkdir -p /etc/opencode && \
    printf '{\n  "$schema": "https://opencode.ai/config.json",\n  "lsp": true,\n  "skills": { "paths": ["/etc/opencode/skills"] },\n  "permission": {\n    "edit": "allow",\n    "bash": "allow",\n    "read": "allow",\n    "external_directory": { "*": "allow" }\n  }\n}\n' > /etc/opencode/opencode.json
COPY skills/container-ambiente/SKILL.md /etc/opencode/skills/container-ambiente/SKILL.md

ARG OPENCODE_VERSION=latest
RUN npm i -g opencode-ai@${OPENCODE_VERSION}
WORKDIR /workspace
USER node

CMD ["opencode"]
