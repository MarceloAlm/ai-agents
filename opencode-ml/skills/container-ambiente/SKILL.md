---
name: container-ambiente
description: >-
  Descreve o ambiente onde o opencode roda dentro de um container isolado
  (imagem opencode:ml — .NET SDK 10 + LSP + Python/numpy/matplotlib). Use para
  saber quais ferramentas existem na imagem, que /workspace e /home são as
  únicas pastas persistentes, que /tmp tem escrita livre mas não persiste, que
  há acesso à internet e ao projeto, que o usuário tem sudo para instalações
  pontuais efêmeras, que o LSP de C# fica habilitado, e como personalizar
  preferências/skills sem perder atualizações e como sugerir variantes de
  container para ferramentas recorrentes.
---

# Ambiente de execução (container isolado)

O opencode roda **dentro de um container isolado** do restante do sistema (Podman),
não no host.

## Contexto

- **Finalidade:** estudo de redes neurais com **.NET (C#/F#)** + scripts `.csx` (`dotnet-script`) e gráficos com **Python** (`numpy`, `matplotlib`); exemplos de referência read-only em `/opt/ml`.
- **Isolado do host:** sem acesso aos arquivos, processos ou serviços do host, exceto pelos caminhos montados abaixo.
- **Acesso à internet:** disponível (`git`, `curl`, `wget`, `npx`, downloads de dependências funcionam normalmente).
- **Projeto atual:** `/workspace` é o bind mount do projeto do usuário no host.
- **Usuário:** não-root (`opencode`, uid/gid 1100), mapeado para o uid/gid 1000 do host via `--userns=keep-id:uid=1100,gid=1100`, com **`sudo` sem senha**.

## Pastas e persistência

| Caminho | Persistente? | Uso |
|---|---|---|
| `/workspace` | **Sim** | Projeto atual (bind mount do host). |
| `/home` (= `/home/opencode`) | **Sim** | Volume persistente (config, credenciais, histórico, cache npm). |
| `/tmp` | **Não** | Escrita livre, mas o conteúdo some quando o container encerra. |

Regra prática: o que precisar durar vai para `/workspace` ou `/home`; `/tmp` é descartável.

## Ferramentas

- `node`/`npm`, `opencode`, `git`, `rg`, `bash`, `sudo`, `apt`, `curl`, `wget`, `jq`, `unzip`/`zip`, `tree`, `file`, `ca-certificates`.
- **`.NET SDK 10`**, `dotnet-script`, `dotnet-trace/counters/dump`, `roslynator`, `roslyn-language-server` (LSP), **`python3`** com `numpy`/`matplotlib`.

Consulte a [lista completa](references/ferramentas.md) e confirme no momento
com `command -v <nome>`.

## Instalação de Ferramentas e Restrições

- **Instalações em tempo de execução são efêmeras:** `sudo apt-get install -y <pacote>`, `sudo npm i -g <pacote>`, `dotnet tool install`. Não sobrevivem ao encerramento do container (`--rm`).
- **Ferramentas recorrentes:** se algo for fundamental ao projeto de forma contínua, **não dependa de reinstalação a cada sessão** — proponha e ajude o usuário a criar uma **nova variante de container** no repositório (pasta, `Dockerfile` e `build.sh`).
- `/etc/ssl/certs` vem do pacote `ca-certificates` da própria imagem.

## LSP

- Habilitado por padrão (`/etc/opencode/opencode.json` com `"lsp": true`).
- O built-in `csharp` do opencode inicia o `roslyn-language-server --stdio --autoLoadProjects` ao abrir `.cs`/`.csx` em projetos com `.sln`, `.slnx`, `.csproj` ou `global.json`.
- Servers detectados via PATH (`/dotnet-tools`). Mensagens `Permission denied` de cache MEF são inofensivas se o server responder ao `initialize`.
- Para validar: `opencode debug skill`, `opencode debug config`.

## Personalização de skills

- A skill `container-ambiente` é **gerenciada** pela imagem (reconstruída a cada build). **Não edite dentro de `container-ambiente/`**.
- Para **skills próprias** (runbooks, regras de negócio, especializações):
  - Global no usuário (persistido em `/home`): `~/.config/opencode/skills/<nome>/SKILL.md`
  - Do projeto (persistido em `/workspace`): `.opencode/skills/<nome>/SKILL.md`
  - Assim suas especializações ficam protegidas e o container continua recebendo atualizações da skill base.
