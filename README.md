# AI Agents Containers

Containers Podman para uso de agentes de IA de forma **isolada e consistente**: como o agente roda dentro de uma imagem, não há diferenças de comportamento entre workstations — o agente enxerga sempre o mesmo ambiente, independente do host.

Estão disponíveis containers para o **OpenCode** (na variante base e na variante com .NET SDK) e para o **Antigravity CLI** (`agy`, binário nativo Go com login OAuth via Google). A stack local com Ollama + LiteLLM é **opcional** e está em construção (requer hardware dedicado para atender ao throughput de tokens).

## Estrutura

| Diretório | Descrição |
|-----------|-----------|
| [`opencode/`](opencode/) | Container **opencode** base: agente de IA em CLI, sem LSP, com skill de ambiente do container |
| [`opencode-dotnet/`](opencode-dotnet/) | Container **opencode** com **.NET SDK 10** e **LSP habilitado** (C#/F#), ferramentas de performance e análise estática |
| [`antigravity/`](antigravity/) | Container do **Antigravity CLI** (`agy`, binário nativo **Go** — base `debian:trixie-slim` / Debian 13) com **.NET 10 SDK**, linters (`shellcheck`, `sqlfluff`, `yq`, `roslynator`), diagnóstico de rede/logs e **login OAuth via conta Google** (Google AI Pro/Ultra) |
| [`ai-stack-allinone/`](ai-stack-allinone/) | **Opcional / em construção:** imagem com **Ollama** (modelos locais) + **LiteLLM** (proxy OpenAI-compatible com tool-calls) para rodar o agente offline, sem assinatura |

## Requisitos

- [Podman](https://podman.io/)
- Git

## Build

Os builds são feitos **a partir da raiz do projeto**, pois os scripts usam o diretório do componente como contexto da imagem:

```bash
./opencode/build.sh            # imagem "opencode"
./opencode-dotnet/build.sh     # imagem "opencode:dotnet"
./antigravity/build.sh         # imagem "antigravity" (CLI agy, OAuth conta Google)
```

A versão dos agentes npm (`opencode`) é definida na hora do build. Os scripts `build.sh` aceitam a versão como argumento; sem ele, resolvem a **versão mais recente publicada no npm** consultando via um container efêmero de `node` (`podman run`), o que garante atualização e invalidação correta do cache quando uma nova versão é lançada. Só exige o Podman (sem npm no host); se a consulta falhar, cai para `latest`. O `antigravity` instala sempre a última versão oficial durante o build:

```bash
./opencode/build.sh           # última versão publicada no npm
./opencode/build.sh 1.18.29   # fixa uma versão específica no build
./opencode-dotnet/build.sh 1.18.28
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
```

## Como usar

Entre na pasta do projeto que será trabalhado e rode o agente:

```bash
cd /caminho/do/projeto
opencode            # base
opencode-dotnet     # com .NET SDK + LSP
agy                 # Antigravity CLI (agy), login OAuth com conta do Google
```

Cada container roda mapeando o UID/GID do host (`--userns=keep-id:uid=1100,gid=1100`), monta o projeto em `/workspace` e guarda os dados do agente em volumes persistentes dedicados (`opencode-home` e `antigravity-home`).

> Veja os guias específicos em [`opencode-dotnet/README.md`](opencode-dotnet/README.md) e [`antigravity/README.md`](antigravity/README.md) para detalhes de autenticação, ferramentas e permissões.

## Stack local (opcional, em construção)

```bash
cd ai-stack-allinone
./run-ai-stack.sh
```

O primeiro boot baixa o modelo `frob/ornith-1.5:9b-coding-Q5_K_M` (~7,4 GB) e publica:
- `11434` — API nativa do Ollama
- `4000` — proxy LiteLLM (OpenAI-compatible `/v1`, com tool-calls)

> Veja o [`readme.txt`](ai-stack-allinone/readme.txt) para detalhes de teste, configuração de rede entre containers e ajustes de contexto/tokens, além de instruções para o opencode consumir o modelo local.

## Como funciona

- **Padronização de usuário e permissões:** os containers rodam com `--userns=keep-id:uid=1100,gid=1100` (usuário `opencode` nos containers OpenCode e `antigravity` no Antigravity CLI), com a pasta do host montada em `/workspace` e dados persistentes em volumes nomeados (`opencode-home` em `/home/opencode`, e `antigravity-home` em `/home/antigravity`).
- **Antigravity CLI (`agy`):** usa `--hostname antigravity` para garantir chave criptográfica estável no `FileKeychain` para persistência do token OAuth da conta Google. O entrypoint garante permissões de consulta pré-autorizadas (`read_file`, `read_url`, `command(git)`, `command(rg)`, `command(curl)`, `command(jq)` etc.) no `settings.json`, concedendo autonomia para inspecionar código e documentações sem prompts repetitivos de autorização.
- **OpenCode (.NET):** `opencode-dotnet` habilita LSP por padrão e pré-libera `read`, `edit` e `bash`.
- **Skill de ambiente e sudo:** as imagens incluem a skill `container-ambiente`, informando ao agente as ferramentas disponíveis, persistência (`/workspace` e `/home`), escrita efêmera em `/tmp` e privilégio de `sudo` sem senha para instalações pontuais em tempo de execução (com recomendação de criar novas variantes caso ferramentas sejam recorrentes).
- **Personalização de skills:**
  - No **OpenCode**, crie skills em `~/.config/opencode/skills/<nome>/SKILL.md` (volume persistente) ou `.opencode/skills/<nome>/SKILL.md` (no repositório do projeto).
  - No **Antigravity**, crie skills em `~/.gemini/config/skills/<nome>/SKILL.md` (volume persistente) ou `.agents/skills/<nome>/SKILL.md` (no repositório do projeto).
  - Isso garante que especializações e regras personalizadas não sejam sobrescritas pela sincronização automática da skill `container-ambiente` na inicialização do container.