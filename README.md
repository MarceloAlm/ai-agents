# AI Agents Containers

Containers Podman para uso de agentes de IA de forma **isolada e consistente**: como o agente roda dentro de uma imagem, não há diferenças de comportamento entre workstations — o agente enxerga sempre o mesmo ambiente, independente do host.

O objetivo principal deste projeto é o agente **opencode** (na variante base e na variante com .NET). O `openclaude` segue o mesmo princípio, mas recebeu menos trabalho por depender de uma assinatura de modelo. A stack local Ollama + LiteLLM é **opcional** e ainda está em construção.

## Estrutura

| Diretório | Descrição |
|-----------|-----------|
| [`opencode/`](opencode/) | Container **opencode** base: agente de IA em CLI, sem LSP, com skill de ambiente do container |
| [`opencode-dotnet/`](opencode-dotnet/) | Container **opencode** com **.NET SDK 10** e **LSP habilitado** (C#/F#), ferramentas de performance e análise estática |
| [`openclaude/`](openclaude/) | Container do agente **openclaude** (CLI) — requer assinatura de modelo |
| [`ai-stack-allinone/`](ai-stack-allinone/) | **Opcional / em construção:** imagem com **Ollama** (modelos locais) + **LiteLLM** (proxy OpenAI-compatible com tool-calls) para rodar o agente offline, sem assinatura |

## Requisitos

- [Podman](https://podman.io/)
- Git

## Build

Os builds são feitos **a partir da raiz do projeto**, pois os scripts usam o diretório do componente como contexto da imagem:

```bash
./opencode/build.sh            # imagem "opencode"
./opencode-dotnet/build.sh     # imagem "opencode:dotnet"
./openclaude/build.sh          # imagem "openclaude"
```

A versão do agente é definida na hora do build. Os scripts `build.sh` aceitam a versão como argumento; sem ele, resolvem a **versão mais recente publicada no npm** consultando via um container efêmero de `node` (`podman run`), o que garante atualização e invalidação correta do cache quando uma nova versão é lançada. Só exige o Podman (sem npm no host); se a consulta falhar, cai para `latest`:

```bash
./opencode/build.sh           # última versão publicada no npm
./opencode/build.sh 2.0.0     # fixa uma versão específica no build
./opencode-dotnet/build.sh 2.0.0
```

## Instalação recomendada (uso global)

Copie o script de execução para `/usr/local/bin` e torne-o executável. Como o script expõe a **pasta atual como `/workspace`**, isso permite invocar o agente em qualquer pasta de projeto:

```bash
sudo cp opencode/opencode.sh /usr/local/bin/opencode
sudo chmod +x /usr/local/bin/opencode

# idem, se quiser também a variante com .NET
sudo cp opencode-dotnet/opencode-dotnet.sh /usr/local/bin/opencode-dotnet
sudo chmod +x /usr/local/bin/opencode-dotnet
```

## Como usar

Entre na pasta do projeto que será trabalhado e rode o agente:

```bash
cd /caminho/do/projeto
opencode            # base
opencode-dotnet     # com .NET SDK + LSP
```

O container roda como usuário `node` (`--userns=keep-id`) e monta o projeto em `/workspace`, guardando dados do agente no volume `opencode-home`.

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

- Os agentes rodam como usuário `node` (`--userns=keep-id`), com as pastas do host montadas em `/workspace` e dados persistentes do agente em volumes nomeados (`opencode-home`, `openclaude-home`).
- As imagens incluem skill `container-ambiente` que informa ao agente as ferramentas disponíveis, as pastas persistentes (`/workspace`, `/home`) e as restrições do container (sem root, sem instalação de pacotes).
- `opencode-dotnet` habilita LSP por padrão e permite `read`, `edit` e `bash` sem pedir permissão a cada operação.