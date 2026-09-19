FROM node:lts-slim

# A base node:lts-slim já traz o usuário/grupo "node" com uid/gid 1000
# (necessário para o Node/npm). Para não conflitar, o usuário padrão
# "opencode" é criado com uid/gid 1100, e os scripts de execução mapeiam no
# podman com --userns=keep-id:uid=1100,gid=1100 (container 1100 -> host 1000),
# mantendo o host dono de /workspace e /home/opencode. Dependências do agente
# (config, credenciais, histórico, cache npm e skills) vivem em /home/opencode,
# montado como volume persistente opencode-home.
RUN mkdir -p /etc/sudoers.d && \
    groupadd --gid 1100 opencode && \
    useradd --uid 1100 --gid opencode --shell /bin/bash --create-home opencode && \
    echo "opencode ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/opencode && \
    chmod 0440 /etc/sudoers.d/opencode

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ripgrep git ca-certificates curl wget jq unzip zip tree file sudo && \
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
    # O runtime (usuário opencode) precisa gravar o cache MEF do Roslyn ao lado
    # dos assemblies; em runtime o usuário é o opencode, então /dotnet-tools
    # (criado como root) era de leitura e o servidor LSP reclamava
    # 'Permission denied' ao criar .../tools/net10.0/linux-x64/cache a cada
    # inicialização.
RUN chown -R opencode:opencode /dotnet-tools
ENV PATH="/dotnet-tools:${PATH}"
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1 \
    DOTNET_NOLOGO=1

# Config gerenciada do opencode (/etc/opencode): LSP por padrão + acesso
# às pastas sem pedir permissão a cada operação (read/edit/bash/external)
# + registro da skill de ambiente do container (skills.paths)
RUN mkdir -p /etc/opencode && \
    printf '{\n  "$schema": "https://opencode.ai/config.json",\n  "lsp": true,\n  "skills": { "paths": ["/etc/opencode/skills"] },\n  "permission": {\n    "edit": "allow",\n    "bash": "allow",\n    "read": "allow",\n    "external_directory": { "*": "allow" }\n  }\n}\n' > /etc/opencode/opencode.json
COPY skills/container-ambiente/ /etc/opencode/skills/container-ambiente/

# Entrypoint: sincroniza as skills do projeto com o home do usuário a cada
# execução (preservando personalizações) e repassa para o opencode.
COPY entrypoint.sh /usr/local/bin/opencode-entrypoint.sh
RUN chmod +x /usr/local/bin/opencode-entrypoint.sh

ARG OPENCODE_VERSION=latest
RUN npm i -g opencode-ai@${OPENCODE_VERSION}
RUN mkdir -p /workspace && chown opencode:opencode /workspace
WORKDIR /workspace
USER opencode

ENTRYPOINT ["/usr/local/bin/opencode-entrypoint.sh"]
CMD ["opencode"]
