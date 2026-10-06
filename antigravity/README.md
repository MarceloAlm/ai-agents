# Antigravity CLI (`agy`)

Container Podman para o agente de IA **Antigravity CLI** (`agy`), desenvolvido em binário nativo Go sobre base Debian 13 (`trixie-slim`), incluindo **.NET 10 SDK**, ferramentas de diagnóstico, linters e análise de logs.

O container vem pré-configurado com permissões para consultas autônomas de código e documentações, fuso horário oficial de Brasília (`America/Sao_Paulo`), suporte nativo a UTF-8 e autenticação via **OAuth com conta Google** (Google AI Pro/Ultra) persistida em volume.

---

## Build

A partir da raiz do repositório:

```bash
# Imagem base
./antigravity/build.sh

# Imagem com suporte a microfone e fala (:sound)
./antigravity/build-sound.sh
# ou
./antigravity/build.sh sound
```

Ou dentro do próprio diretório:

```bash
cd antigravity
./build.sh                     # detecta última versão upstream e reconstrói antigravity:latest
./build-sound.sh               # detecta última versão upstream e reconstrói antigravity:sound
# ou especificando versão ou variante manualmente:
./build.sh 1.3.0
./build.sh sound 1.3.0
```

O `build.sh` consulta automaticamente a versão mais recente disponível no manifesto oficial do Antigravity CLI e repassa como `--build-arg AGY_VERSION=<versão>`. Isso invalida apenas a camada de download do `agy` no Podman (preservando o cache pesado do .NET SDK e pacotes Debian), garantindo que a nova versão seja efetivamente baixada e instalada.

Além disso, os scripts `agy.sh` e `agy-sound.sh` verificam em tempo de execução se há uma nova versão disponível e exibem um aviso no terminal caso a imagem local esteja desatualizada (a verificação pode ser silenciada com `AGY_NO_UPDATE_CHECK=1`).


---

## Instalação e Execução

### 1. Instalação recomendada no host (comandos globais `agy` e `agy-sound`)

Copie os scripts wrappers para `/usr/local/bin`:

```bash
# Versão padrão
sudo cp antigravity/agy.sh /usr/local/bin/agy
sudo chmod +x /usr/local/bin/agy

# Versão com suporte a microfone e fala (:sound)
sudo cp antigravity/agy-sound.sh /usr/local/bin/agy-sound
sudo chmod +x /usr/local/bin/agy-sound
```

### 2. Executando em um projeto

Basta entrar na pasta do seu projeto e executar:

```bash
cd /caminho/do/projeto

# Versão padrão:
agy

# Versão com microfone ativado:
agy-sound
```

Ou diretamente via `podman`:

```bash
# Versão padrão:
podman run --rm -it --userns=keep-id:uid=1100,gid=1100 \
  --hostname antigravity \
  -v "antigravity-home:/home/antigravity" \
  -v "$PWD:/workspace" \
  -w /workspace \
  antigravity:latest "$@"

# Versão com som e microfone:
podman run --rm -it --userns=keep-id:uid=1100,gid=1100 \
  --hostname antigravity \
  --device /dev/snd --group-add audio \
  -v "${XDG_RUNTIME_DIR}/pulse/native:${XDG_RUNTIME_DIR}/pulse/native:ro" \
  -e "PULSE_SERVER=unix:${XDG_RUNTIME_DIR}/pulse/native" \
  -v "antigravity-home:/home/antigravity" \
  -v "$PWD:/workspace" \
  -w /workspace \
  antigravity:sound "$@"
```

> **Nota sobre `--hostname antigravity`**: O hostname fixo garante uma chave estável de criptografia para o `FileKeychain`, permitindo que o token OAuth seja descriptografado corretamente entre recriações do container.

### 3. Usando funções de voz e fala no CLI (`/voice` ou F5)

Na versão `antigravity:sound` (executada via `agy-sound`), as funções de áudio, gravação pelo microfone e reprodução de fala estão habilitadas:

- Pressione **F5** ou digite o comando de barra `/voice` no terminal do `agy` para iniciar/pausar a gravação pelo microfone.
- O áudio capturado é transcrito em tempo real diretamente na caixa de entrada de prompt do agente.
- O wrapper `agy-sound.sh` detecta e repassa automaticamente os dispositivos ALSA (`/dev/snd`) e os sockets de áudio do PulseAudio / PipeWire do host para o container sem necessidade de configurações manuais adicionais.

---

## Autenticação (OAuth com Conta Google ou API Key)

### Padrão: OAuth com conta Google
O método padrão é **OAuth com conta Google** (Google AI Pro/Ultra):

1. No primeiro uso, execute:
   ```bash
   agy auth login
   # (ou simplesmente inicie 'agy' diretamente)
   ```
2. O terminal exibirá uma **URL de autorização**.
3. Abra a URL no seu navegador do host, faça login com a conta Google e autorize o acesso.
4. Copie o **código de autenticação** exibido e cole-o de volta no terminal.
5. O token é salvo e persistido automaticamente no volume `antigravity-home` em:  
   `~/.gemini/antigravity-cli/antigravity-oauth-token`

Nas próximas execuções, o login ocorre silenciosamente.

### Alternativa: API Key do Gemini (Headless / Chaveamento Dinâmico)
Se preferir usar uma chave de API direta em vez do OAuth, defina a variável `GEMINI_API_KEY` no seu host:

```bash
export GEMINI_API_KEY="AIzaSy..."
agy
```

O `entrypoint.sh` detecta a presença da variável automaticamente:
- Se `GEMINI_API_KEY` estiver definida: ativa `"modelProvider": "gemini"` no `settings.json`.
- Se a variável estiver ausente/desmarcada: remove `"modelProvider": "gemini"`, revertendo imediatamente para o fluxo OAuth da conta Google.

---

## Integração Dinâmica com Servidores e Gateways MCP

Você pode registrar servidores ou gateways MCP (*Model Context Protocol*) dinamicamente via variáveis de ambiente, sem precisar alterar arquivos de configuração manualmente:

```bash
export MCP_GATEWAY_URL="http://host.containers.internal:8000/mcp"
export MCP_TOKEN="meu-token-bearer-opcional" # opcional
agy
```

O container injeta e mescla essa definição automaticamente no arquivo `~/.gemini/config/mcp_config.json` durante o startup.

---

## Persistência de Dados

| Caminho no Container | Persiste? | Destino | Finalidade |
|---|---|---|---|
| `/workspace` | **Sim** | Pasta atual do host (`$PWD`) | Código-fonte e arquivos do projeto |
| `/home/antigravity` | **Sim** | Volume `antigravity-home` | Token OAuth, histórico, configurações e skills |
| `/tmp` | **Não** | Efêmero | Arquivos temporários da sessão |

---

## Ferramentas Disponíveis

| Ferramenta | Finalidade |
|---|---|
| `agy` | O próprio agente Antigravity CLI |
| `.NET 10 SDK` | Compilar, testar e executar aplicações C# e F# |
| `csharp-ls` | Servidor LSP de C# baseado em Roslyn |
| `roslynator` | Análise estática, refatorações e linters C# |
| `dotnet-dump`, `dotnet-trace`, `dotnet-counters` | Diagnóstico de performance, análise de dumps de memória e métricas |
| `shellcheck` | Linter e validador estático para scripts Bash/sh |
| `yq` | Parsing, extração e validação cirúrgica de arquivos YAML |
| `sqlfluff` | Linter e formatador de queries SQL (MySQL, T-SQL, etc.) |
| `vim` / `nano` | Editores de texto (Vim configurado com suporte UTF-8 nativo) |
| `dig` / `traceroute` / `ping` | Diagnóstico de rede e resolução DNS |
| `git`, `curl`, `jq`, `ripgrep` (`rg`), `gawk`, `sed` | Manipulação de arquivos, chamadas HTTP e análise de logs |
| `dos2unix`, `zstd`, `zcat`, `zgrep`, `file`, `procps` | Normalização de quebras de linha e inspeção de logs compactados |
| `arecord` / `parec` / `pw-record` | Captura de microfone e gravação de áudio (variante `:sound`, comandos `/voice` e F5) |
| `sudo` | Acesso superusuário sem senha para instalações pontuais efêmeras via `apt-get` |

---

## Skills e Customizações do Usuário

O container vem com a skill `container-ambiente` atualizada automaticamente a cada inicialização pelo `entrypoint.sh`.

Para registrar runbooks, regras ou especializações próprias sem que sejam sobrescritas nos boots:
- **Global do usuário (persistida no volume):**  
  `~/.gemini/config/skills/<nome-da-skill>/SKILL.md`
- **Específica do projeto (versionada com seu repositório):**  
  `.agents/skills/<nome-da-skill>/SKILL.md`

---

## Rede Corporativa, Proxy e Firewall (Allowlist de Endpoints)

Se o container for executado em redes corporativas com inspeção SSL ou bloqueio de saída de rede (*egress*), certifique-se de que os seguintes domínios estejam liberados no proxy/firewall:

### 1. Allowlist de Domínios Oficiais

| Categoria | Domínios / Endpoints |
|---|---|
| **Autenticação (OAuth Google)** | `accounts.google.com`, `oauth2.googleapis.com`, `www.googleapis.com` |
| **APIs de Modelos (Gemini / Code)** | `generativelanguage.googleapis.com`, `aicode.googleapis.com`, `cloudcode-pa.googleapis.com`, `daily-cloudcode-pa.googleapis.com` |
| **Plataforma Antigravity & Flags** | `antigravity.google`, `antigravity.google.com`, `antigravity-unleash.goog` |
| **Instalação, Auto-updater e CDN** | `antigravity-cli-auto-updater-974169037036.us-central1.run.app`, `storage.googleapis.com`, `www.gstatic.com`, `safebrowsing.googleapis.com` |
| **Dependências & Skills Upstream** | `raw.githubusercontent.com` |
| **Repositórios de Pacotes (Build)** | `deb.debian.org`, `packages.microsoft.com`, `api.nuget.org` |

---

### 2. Como Modificar o `Dockerfile` para Redes com Proxy ou CA Customizada

Para construir a imagem em ambientes corporativos restritos, você pode adaptar o [`Dockerfile`](Dockerfile) em dois cenários:

#### Cenário A: Passando argumentos de proxy no build (sem alterar o Dockerfile)
O Podman e o Docker suportam `--build-arg` diretamente:

```bash
podman build \
  --build-arg HTTP_PROXY="http://proxy.empresa.com:8080" \
  --build-arg HTTPS_PROXY="http://proxy.empresa.com:8080" \
  --build-arg NO_PROXY="localhost,127.0.0.1,host.containers.internal" \
  -t antigravity:latest .
```

#### Cenário B: Modificando o `Dockerfile` para embutir CA corporativa e Proxy de APT

Adicione o seguinte bloco logo após a linha `FROM debian:trixie-slim`:

```dockerfile
# ==============================================================================
# Suporte a Proxy Corporativo e Certificados SSL Internos (Opcional)
# ==============================================================================
ARG HTTP_PROXY
ARG HTTPS_PROXY
ARG NO_PROXY
ENV http_proxy=${HTTP_PROXY} \
    https_proxy=${HTTPS_PROXY} \
    no_proxy=${NO_PROXY}

# 1. Configurar proxy estático para o gerenciador de pacotes apt (se necessário):
# RUN echo 'Acquire::http::Proxy "http://proxy.empresa.com:8080";' > /etc/apt/apt.conf.d/01proxy && \
#     echo 'Acquire::https::Proxy "http://proxy.empresa.com:8080";' >> /etc/apt/apt.conf.d/01proxy

# 2. Injetar Autoridade Certificadora (CA) raiz corporativa (para inspeção SSL):
# COPY meucertificado-corporativo.crt /usr/local/share/ca-certificates/corp-ca.crt
# RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates && \
#     update-ca-certificates
# ==============================================================================
```

#### Cenário C: Proxy em tempo de execução (`runtime`)
Para que o `agy` acesse os serviços externos através do proxy do host, exporte as variáveis antes de chamar o `agy`:

```bash
export HTTP_PROXY="http://proxy.empresa.com:8080"
export HTTPS_PROXY="http://proxy.empresa.com:8080"
export NO_PROXY="localhost,127.0.0.1,host.containers.internal"
agy
```
*(O Podman repassará as variáveis de ambiente ativas ou você pode adicioná-las aos `ARGS+=(-e HTTP_PROXY -e HTTPS_PROXY -e NO_PROXY)` no [`agy.sh`](agy.sh)).*
