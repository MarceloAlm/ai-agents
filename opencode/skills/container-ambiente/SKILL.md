---
name: container-ambiente
description: >-
  Descreve o ambiente onde o opencode roda dentro de um container isolado
  (imagem opencode, sem LSP). Use para saber quais ferramentas existem na
  imagem, que /workspace e /home são as únicas pastas persistentes, que /tmp
  tem escrita livre mas não persiste, que há acesso à internet e ao projeto,
  que o usuário tem sudo para instalações pontuais efêmeras, e como
  personalizar skills sem perder atualizações e como sugerir variantes de
  container para ferramentas recorrentes.
---

# Ambiente de execução (container isolado)

O opencode roda **dentro de um container isolado** do restante do sistema (Podman),
não no host.

## Contexto

- **Isolado do host:** sem acesso aos arquivos, processos ou serviços do host, exceto pelos caminhos montados abaixo.
- **Acesso à internet:** disponível (`git`, `curl`, `wget`, `npx`, downloads de dependências funcionam normalmente).
- **Projeto atual:** `/workspace` é o bind mount do projeto do usuário no host.
- **Usuário:** não-root (`opencode`, uid/gid 1100), mapeado para o uid/gid 1000 do host via `--userns=keep-id:uid=1100,gid=1100`, com **`sudo` sem senha restrito a `apt-get`/`apt` e `npm -g`** (instalações efêmeras; qualquer outro comando com sudo é negado — a conta não tem senha).
- **Variante ativa:** Informada na variável `$OPENCODE_VARIANT` e registrada em `~/.config/opencode/variant` (`base`, `dotnet` ou `ml`).

## Pastas e persistência

| Caminho | Persistente? | Uso |
|---|---|---|
| `/workspace` | **Sim** | Projeto atual (bind mount do host). |
| `/home` (= `/home/opencode`) | **Sim** | Volume `opencode-home`: config do opencode, credenciais, histórico, cache npm e skills. |
| `/tmp` | **Não** | Escrita livre, mas o conteúdo some quando o container encerra. |

Regra prática: o que precisar durar vai para `/workspace` ou `/home`; `/tmp` é descartável.

## Ferramentas disponíveis por variante

- **Base (`opencode:latest`):** `node`/`npm`, `opencode`, `git`, `rg`, `curl`, `wget`, `jq`, `unzip`/`zip`, `tree`, `file`, `bash`, `sudo`.
- **Dotnet (`opencode:dotnet`):** base + **`.NET SDK 10`**, `dotnet-trace/counters/dump`, `roslynator`, `roslyn-language-server` (LSP C#).
- **Machine Learning (`opencode:ml`):** dotnet + `python3`, `numpy`, `matplotlib`, `dotnet-script` (.csx) e `/opt/ml`.

Consulte a [lista completa](references/ferramentas.md) e confirme no momento com `command -v <nome>`.

## Instalação de Ferramentas e Restrições

- **Instalações em tempo de execução são efêmeras:** `sudo apt-get install -y <pacote>`, `sudo npm i -g <pacote>`. Não sobrevivem ao encerramento do container (`--rm`).
- **Escopo do sudo:** passam sem senha só `apt-get`/`apt` (`install`, `update`, `upgrade`, `autoremove`, `autoclean`, `clean`) e `npm -g` (`install`/`i`/`uninstall`/`remove`) — com o subcomando **primeiro** (ex.: `sudo apt-get install -y rg`; `sudo apt-get -y install rg` é negado). Todo o resto falha por senha inexistente. Para algo fora do escopo (ex.: `chown` de arquivo criado por root), peça ao usuário para rodar `podman exec -u root <container>` no host.
- **Ferramentas recorrentes:** se algo for fundamental ao projeto de forma contínua, **não dependa de reinstalação a cada sessão** — proponha e ajude o usuário a criar uma **nova variante de container** no repositório (pasta, `Dockerfile` e `build.sh`, no formato das variantes `opencode:dotnet` e `opencode:ml`).
- `/etc/ssl/certs` vem do pacote `ca-certificates` da própria imagem.

## Proteção de Segredos (Zero Secret Leak)

O agente deve seguir a política **Zero Secret Leak**, que é sempre carregada nas instruções globais (`~/.config/opencode/AGENTS.md`, regenerada a cada inicialização de `/etc/opencode/AGENTS.md` — cópia imutável da imagem; as regras canônicas ficam em `/etc/opencode/rules/zero-secret-leak.md`). Resumo: nunca solicitar/exibir/transmitir segredos; mascarar credenciais (`<TOKEN_REDACTED>`); inspecionar arquivos sensíveis (`.env`, chaves) apenas com alerta e sem valores; nunca passar senhas em argumentos de comando; nunca versionar credenciais nem usá-las como `--build-arg`. O texto integral e vinculante está no AGENTS.md.

## Personalização de skills

- A skill `container-ambiente` é **gerenciada** pela imagem (reconstruída a cada build). **Não edite dentro de `container-ambiente/`**. Edições são detectadas na primeira inicialização de cada nova versão da imagem: a versão editada é preservada em `~/.config/opencode/skills-custom/` e a oficial é reinstalada.
- Para **skills próprias** (runbooks, regras de negócio, especializações):
  - Global no usuário (persistido em `/home`): `~/.config/opencode/skills/<nome>/SKILL.md`
  - Do projeto (persistido em `/workspace`): `.opencode/skills/<nome>/SKILL.md`
  - Assim suas especializações ficam protegidas e o container continua recebendo atualizações da skill base.
- **Regras e preferências pessoais:** quando solicitado a criar uma regra, preferência ou diretriz pessoal, grave-a no repositório do perfil pelas rotas acima — nunca dentro de `container-ambiente/`. Inclua `description` no frontmatter para que o agente enxergue a skill.
