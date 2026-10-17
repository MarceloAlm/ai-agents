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
- **Usuário:** não-root (`opencode`, uid/gid 1100), mapeado para o uid/gid 1000 do host via `--userns=keep-id:uid=1100,gid=1100`, com **`sudo` sem senha**.
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
- **Ferramentas recorrentes:** se algo for fundamental ao projeto de forma contínua, **não dependa de reinstalação a cada sessão** — proponha e ajude o usuário a criar uma **nova variante de container** no repositório (pasta, `Dockerfile` e `build.sh`, no formato das variantes `opencode:dotnet` e `opencode:ml`).
- `/etc/ssl/certs` vem do pacote `ca-certificates` da própria imagem.

## Proteção e Sigilo de Credenciais (Zero Secret Leak)

- **Nunca trafegar senhas para o modelo:** Não solicitar, exibir, ler ou trafegar senhas, tokens de API, chaves privadas, certificados ou segredos em texto puro.
- **Mascaramento obrigatório:** Substitua qualquer credencial ou segredo por placeholders (ex.: `<TOKEN_REDACTED>`, `[SENHA_OCULTA]`, `******`).
- **Arquivos sensíveis:** Antes de inspecionar arquivos de ambiente ou credenciais (como `.env`, `.htpasswd`, chaves SSH, arquivos de configuração com credenciais), alerte o usuário ou filtre apenas os nomes de variáveis/chaves sem vazar os valores.
- **Comandos no shell:** Não executar nem sugerir comandos que passem senhas diretamente em argumentos de linha de comando ou em texto puro no histórico (utilizar variáveis de ambiente ou leitura interativa oculta como `read -s`).

## Personalização de skills

- A skill `container-ambiente` é **gerenciada** pela imagem (reconstruída a cada build). **Não edite dentro de `container-ambiente/`**.
- Para **skills próprias** (runbooks, regras de negócio, especializações):
  - Global no usuário (persistido em `/home`): `~/.config/opencode/skills/<nome>/SKILL.md`
  - Do projeto (persistido em `/workspace`): `.opencode/skills/<nome>/SKILL.md`
  - Assim suas especializações ficam protegidas e o container continua recebendo atualizações da skill base.
