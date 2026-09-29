# AI Agents Containers

Containers Podman para uso de agentes de IA de forma **isolada e consistente**: como o agente roda dentro de uma imagem, não há diferenças de comportamento entre workstations — o agente enxerga sempre o mesmo ambiente, independente do host.

Estão disponíveis containers para o **OpenCode** (na variante base e na variante com .NET SDK) e para o **Antigravity CLI** (`agy`, binário nativo Go com login OAuth via Google). A stack local com Ollama + LiteLLM é **opcional** e está em construção (requer hardware dedicado para atender ao throughput de tokens).

## Estrutura

| Diretório | Descrição |
|-----------|-----------|
| [`opencode/`](opencode/) | Container **opencode** base: agente de IA em CLI, sem LSP, com skill de ambiente do container |
| [`opencode-dotnet/`](opencode-dotnet/) | Container **opencode** com **.NET SDK 10** e **LSP habilitado** (C#/F#), ferramentas de performance e análise estática |
| [`opencode-ml/`](opencode-ml/) | Container **opencode** focado em estudo de **Machine Learning em C#** (.NET 10, scripts `.csx`, Python para gráficos) |
| [`antigravity/`](antigravity/) | Container do **Antigravity CLI** (`agy`, binário nativo **Go** — base `debian:trixie-slim` / Debian 13) com **.NET 10 SDK**, linters (`shellcheck`, `sqlfluff`, `yq`, `roslynator`), diagnóstico de rede/logs e **login OAuth via conta Google** (Google AI Pro/Ultra) |
| [`specialized-agent/`](specialized-agent/) | Agente autônomo modular para **SRE, Cibersegurança, Auditoria e Análise Forense** com grounding em tempo real e orquestração de skills |
| [`ai-stack/`](ai-stack/) | **Hub Central de Provedores de IA:** infraestrutura neural desacoplada acelerada por GPU (**llama.cpp** com Flash Attention e KV quantizado, **Ollama** e **SearXNG**), servindo como backend local tanto para o OpenCode quanto para o Specialized Agent |

## Requisitos

- [Podman](https://podman.io/) (versão 4.4+ recomendada) ou Docker
- Git
- **Para inferência local acelerada (AI-Stack e Specialized Agent):**
  - Placa de vídeo **NVIDIA** com drivers proprietários instalados (`nvidia-smi`);
  - Suporte a CDI / NVIDIA Container Toolkit (`nvidia-ctk cdi generate` para Podman ou `nvidia-container-toolkit` para Docker);
  - VRAM recomendada: Mínimo 6 GB (para modelos 7B em `Q4_K_M`), ideal 8 GB a 12 GB+;
  - Mínimo 16 GB de RAM no host.

## Build

Os builds são feitos **a partir da raiz do projeto**, pois os scripts usam o diretório do componente como contexto da imagem:

```bash
./opencode/build.sh            # imagem "opencode"
./opencode-dotnet/build.sh     # imagem "opencode:dotnet"
./antigravity/build.sh         # imagem "antigravity" (CLI agy, OAuth conta Google)
./antigravity/build-sound.sh   # imagem "antigravity:sound" (com suporte a microfone e fala)
```

A versão dos agentes npm (`opencode`) é definida na hora do build. Os scripts `build.sh` aceitam a versão como argumento; sem ele, resolvem a **versão mais recente publicada no npm** consultando via um container efêmero de `node` (`podman run`), o que garante atualização e invalidação correta do cache quando uma nova versão é lançada. Só exige o Podman (sem npm no host); se a consulta falhar, cai para `latest`. O `antigravity` instala sempre a última versão oficial durante o build:

```bash
./opencode/build.sh           # última versão publicada no npm
./opencode/build.sh 1.18.29   # fixa uma versão específica no build
./opencode-dotnet/build.sh 1.18.28
./antigravity/build.sh sound  # cria imagem antigravity:sound
```

## Instalação recomendada (uso global)

Copie o script de execução para `/usr/local/bin` e torne-o executável. Como o script expõe a **pasta atual como `/workspace`**, isso permite invocar o agente em qualquer pasta de projeto:

```bash
sudo cp opencode/opencode.sh /usr/local/bin/opencode
sudo chmod +x /usr/local/bin/opencode

# idem, se quiser a variante com .NET SDK
sudo cp opencode-dotnet/opencode-dotnet.sh /usr/local/bin/opencode-dotnet
sudo chmod +x /usr/local/bin/opencode-dotnet

# idem, para o Antigravity CLI (agy) com login OAuth (conta do Google)
sudo cp antigravity/agy.sh /usr/local/bin/agy
sudo chmod +x /usr/local/bin/agy

# idem, para a versão do Antigravity com microfone ativado (:sound, comandos /voice e F5)
sudo cp antigravity/agy-sound.sh /usr/local/bin/agy-sound
sudo chmod +x /usr/local/bin/agy-sound
```

## Como usar

Entre na pasta do projeto que será trabalhado e rode o agente:

```bash
cd /caminho/do/projeto
opencode            # base
opencode-dotnet     # com .NET SDK + LSP
agy                 # Antigravity CLI (agy), login OAuth com conta do Google
agy-sound           # Antigravity com microfone ativado (gravação e reprodução de som, /voice e F5)
```

Cada container roda mapeando o UID/GID do host (`--userns=keep-id:uid=1100,gid=1100`), monta o projeto em `/workspace` e guarda os dados do agente em volumes persistentes dedicados (`opencode-home` e `antigravity-home`).

> Veja os guias específicos em [`opencode-dotnet/README.md`](opencode-dotnet/README.md) e [`antigravity/README.md`](antigravity/README.md) para detalhes de autenticação, ferramentas e permissões.

## Stack Local (AI-Stack: Hub de Provedores)

Para rodar agentes de forma totalmente offline e com aceleração por GPU local:

```bash
cd ai-stack

# 1. Baixar modelo GGUF otimizado (ex: Qwen 2.5 Coder 7B para OpenCode):
./download-model.sh qwen2.5-coder:7b

# 2. Iniciar a infraestrutura (llama.cpp com Flash Attention + SearXNG):
./start-stack.sh llamacpp
```

A stack disponibiliza:
- `http://127.0.0.1:8081/v1` — API compatível com OpenAI (llama-server com Flash Attention e KV Cache quantizado para o OpenCode ou clientes externos);
- `http://127.0.0.1:11434` — API do Ollama (caso iniciado com `./start-stack.sh ollama` ou `all`);
- `http://127.0.0.1:8080` — Metabuscador SearXNG com API JSON para grounding do `specialized-agent`.

> Veja o guia completo em [`ai-stack/README.md`](ai-stack/README.md) para detalhes de configuração, consumo pelo OpenCode e arquitetura de rede.

## Como funciona

- **Padronização de usuário e permissões:** os containers rodam com `--userns=keep-id:uid=1100,gid=1100` (usuário `opencode` nos containers OpenCode e `antigravity` no Antigravity CLI), com a pasta do host montada em `/workspace` e dados persistentes em volumes nomeados (`opencode-home` em `/home/opencode`, e `antigravity-home` em `/home/antigravity`).
- **Antigravity CLI (`agy`):** usa `--hostname antigravity` para garantir chave criptográfica estável no `FileKeychain` para persistência do token OAuth da conta Google. O entrypoint garante permissões de consulta pré-autorizadas (`read_file`, `read_url`, `command(git)`, `command(rg)`, `command(curl)`, `command(jq)` etc.) no `settings.json`, concedendo autonomia para inspecionar código e documentações sem prompts repetitivos de autorização.
- **OpenCode (.NET):** `opencode-dotnet` habilita LSP por padrão e pré-libera `read`, `edit` e `bash`.
- **Skill de ambiente e sudo:** as imagens incluem a skill `container-ambiente`, informando ao agente as ferramentas disponíveis, persistência (`/workspace` e `/home`), escrita efêmera em `/tmp` e privilégio de `sudo` sem senha para instalações pontuais em tempo de execução (com recomendação de criar novas variantes caso ferramentas sejam recorrentes).
- **Personalização de skills:**
  - No **OpenCode**, crie skills em `~/.config/opencode/skills/<nome>/SKILL.md` (volume persistente) ou `.opencode/skills/<nome>/SKILL.md` (no repositório do projeto).
  - No **Antigravity**, crie skills em `~/.gemini/config/skills/<nome>/SKILL.md` (volume persistente) ou `.agents/skills/<nome>/SKILL.md` (no repositório do projeto).
  - Isso garante que especializações e regras personalizadas não sejam sobrescritas pela sincronização automática da skill `container-ambiente` na inicialização do container.