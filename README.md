# AI Agents Containers

Containers Podman para uso de agentes de IA de forma **isolada e consistente**: como o agente roda dentro de uma imagem, não há diferenças de comportamento entre workstations — o agente enxerga sempre o mesmo ambiente, independente do host.

Está disponível o agente **opencode** (na variante base e na variante com .NET). 
O `openclaude` depende de uma assinatura de modelo. Também está disponível o CLI do Google **Antigravity** (`agy`, binário Go). A stack local Ollama + LiteLLM é **opcional** e ainda está em construção, precisa de um hardware dedicado para conseguir atender ao desempenho de tokens.

## Estrutura

| Diretório | Descrição |
|-----------|-----------|
| [`opencode/`](opencode/) | Container **opencode** base: agente de IA em CLI, sem LSP, com skill de ambiente do container |
| [`opencode-dotnet/`](opencode-dotnet/) | Container **opencode** com **.NET SDK 10** e **LSP habilitado** (C#/F#), ferramentas de performance e análise estática |
| [`opencode-ml/`](opencode-ml/) | Container **opencode** para **estudo de redes neurais**: .NET SDK 10 + LSP + runner de scripts `.csx` (dotnet-script), Python com numpy/matplotlib para gráficos e exemplos de referência em `/opt/ml` |
| [`openclaude/`](openclaude/) | Container do agente **openclaude** (CLI) — requer assinatura de modelo |
| [`antigravity/`](antigravity/) | Container do **Antigravity CLI** (`agy`, binário nativo **Go** — base `debian:bookworm-slim`) com **.NET 10 SDK**, ferramentas de diagnóstico de rede/logs e **login OAuth via conta Google** (fluxo URL + código) |
| [`ai-stack-allinone/`](ai-stack-allinone/) | **Opcional / em construção:** imagem com **Ollama** (modelos locais) + **LiteLLM** (proxy OpenAI-compatible com tool-calls) para rodar o agente offline, sem assinatura |

## Requisitos

- [Podman](https://podman.io/)
- Git

## Build

Os builds são feitos **a partir da raiz do projeto**, pois os scripts usam o diretório do componente como contexto da imagem:

```bash
./opencode/build.sh            # imagem "opencode"
./opencode-dotnet/build.sh     # imagem "opencode:dotnet"
./opencode-ml/build.sh         # imagem "opencode:ml" (estudo de ML em C#)
./openclaude/build.sh          # imagem "openclaude"
./antigravity/build.sh         # imagem "antigravity" (CLI agy, OAuth conta Google)
```

A versão dos agentes npm (`opencode`) é definida na hora do build. Os scripts `build.sh` aceitam a versão como argumento; sem ele, resolvem a **versão mais recente publicada no npm** consultando via um container efêmero de `node` (`podman run`), o que garante atualização e invalidação correta do cache quando uma nova versão é lançada. Só exige o Podman (sem npm no host); se a consulta falhar, cai para `latest`. O `antigravity` instala sempre a última versão via script oficial de instalação:

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

# idem, se quiser também a variante com .NET
sudo cp opencode-dotnet/opencode-dotnet.sh /usr/local/bin/opencode-dotnet
sudo chmod +x /usr/local/bin/opencode-dotnet

# idem, se quiser também a variante de estudo de ML em C#
sudo cp opencode-ml/opencode-ml.sh /usr/local/bin/opencode-ml
sudo chmod +x /usr/local/bin/opencode-ml

# idem, para o Antigravity CLI com login OAuth (conta do Google)
sudo cp antigravity/antigravity.sh /usr/local/bin/antigravity
sudo chmod +x /usr/local/bin/antigravity
```

## Como usar

Entre na pasta do projeto que será trabalhado e rode o agente:

```bash
cd /caminho/do/projeto
opencode            # base
opencode-dotnet     # com .NET SDK + LSP
opencode-ml         # estudo de ML em C# (LSP + dotnet-script + gráficos Python)
antigravity         # Antigravity CLI (agy), login OAuth com conta do Google
```

Cada container roda com `--userns=keep-id`, monta o projeto em `/workspace` e guarda os dados do agente no seu volume próprio (ex.: `opencode-home`, `antigravity-home`).

> Veja o [`README.md`](opencode-dotnet/README.md) para detalhes de LSP, ferramentas e permissões da variante .NET.

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

- Os containers do opencode rodam como usuário `opencode` (`--userns=keep-id`; o Antigravity CLI usa o usuário `antigravity`), com as pastas do host montadas em `/workspace` e dados persistentes do agente em volumes nomeados (`opencode-home`, `openclaude-home`, `opencode-ml-home`, `antigravity-home` — montados em `/home/opencode`).
- As imagens incluem skill `container-ambiente` que informa ao agente as ferramentas disponíveis, as pastas persistentes (`/workspace`, `/home`), a disponibilidade de `sudo` sem senha para instalações pontuais e efêmeras em tempo de execução, e a diretriz para sugerir a criação de novas variantes de container quando ferramentas adicionais forem necessárias de forma recorrente.
- No `antigravity`, o entrypoint garante o login via OAuth com conta Google (removendo qualquer `modelProvider` residual) e pré-configura permissões de consulta (`read_file(*)`, `read_url(*)`, `command(git)`, `command(rg)`, `command(curl)`, `command(jq)` etc.) no `settings.json`. Isso concede autonomia ao agente para inspecionar o código, rodar buscas e consultar documentações externas na web sem pedir autorização a cada leitura.
- `opencode-dotnet` habilita LSP por padrão e permite `read`, `edit` e `bash` sem pedir permissão a cada operação.