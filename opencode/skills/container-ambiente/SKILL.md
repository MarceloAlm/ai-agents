---
name: container-ambiente
description: Descreve o ambiente onde o opencode roda dentro de um container isolado (imagens opencode e opencode:dotnet). Use para saber quais ferramentas existem na imagem, que /workspace e /home são as únicas pastas persistentes, que /tmp tem escrita livre mas não persiste, que há acesso à internet e ao projeto, que o usuário tem sudo para instalações pontuais efêmeras e como sugerir variantes de container para ferramentas recorrentes.
---

# Ambiente de execução (container isolado)

O opencode roda **dentro de um container isolado** do restante do sistema (Podman),
não no host. Isso tem consequências diretas no que você pode e não pode fazer.

## Contexto

- **Isolado do host:** não há acesso aos arquivos, processos ou serviços do host, exceto pelos caminhos montados listados abaixo.
- **Acesso à internet:** disponível. Ferramentas de rede (`git`, `curl`, `wget`, `npx`, download de dependências de projeto...) funcionam normalmente.
- **Projeto atual:** o diretório de trabalho é `/workspace`, um bind mount do projeto do usuário no host. É onde estão os arquivos do projeto com os quais você deve trabalhar.
- **Usuário:** não-root (`node`, uid/gid 1000, `--userns=keep-id`), mas configurado com **`sudo` sem senha**.

## Instalação de Ferramentas e Restrições

- **Instalações em tempo de execução são efêmeras:** Você tem privilégios de `sudo` sem senha (`sudo apt-get update && sudo apt-get install -y <pacote>`, `sudo npm i -g <pacote>`). Use isso para suprir necessidades imediatas ou descartáveis durante a sessão de trabalho.
- **Atenção: o container é efêmero (`--rm`).** Nada que for instalado no sistema raiz sobreviverá ao encerramento do container.
- **Sugira novas variantes para ferramentas recorrentes:** Se você identificar que uma ferramenta, SDK, compilador ou conjunto de utilitários é fundamental para o projeto de forma contínua, **não dependa de reinstalações a cada sessão**. Proponha e ajude o usuário a criar uma **nova variante de container** dedicada no repositório (no mesmo formato das variantes `opencode:dotnet` e `opencode:ml`, criando pasta, `Dockerfile` e `build.sh`).
- `/etc/ssl/certs` vem do pacote `ca-certificates` **da própria imagem** — não é montado do host.

## Preferências do usuário

- **Criação de arquivos com `echo <<` (heredoc):** na criação de arquivos, o usuário prefere usar o comando bash com heredoc (`echo <<'EOF' ... EOF` / `cat <<'EOF' > arquivo`) em vez da ferramenta dedicada de escrita de arquivos.

## Pastas e persistência

| Caminho | Persistente? | Uso |
|---|---|---|
| `/workspace` | **Sim** | Projeto atual (bind mount do host). É onde vive o que importa. |
| `/home` (= `/home/node`) | **Sim** | Volume persistente `opencode-home` (config do opencode, credenciais, histórico, cache npm). |
| `/tmp` | **Não** | Escrita **sem restrições**, mas o conteúdo some quando o container encerra. |

Regra prática: o que precisar durar deve ir para `/workspace` ou `/home`; `/tmp` é para
trabalho descartável (downloads, arquivos temporários, testes) e nunca deve ser tratado
como dado importante persistente.

## Ferramentas disponíveis

**Garantidas em todas as variantes da imagem:**

| Ferramenta | O que faz |
|---|---|
| `node` / `npm` | Runtime JS; scripts e ferramentas npm locais |
| `opencode` | O próprio agente |
| `git` | Controle de versão |
| `rg` (ripgrep) | Busca textual rápida |
| `sudo` | Execução como superusuário para instalações pontuais efêmeras |
| `apt` / `apt-get` | Gerenciador de pacotes Debian para instalações em tempo de execução |
| `bash` | Shell padrão para os comandos |
| `ca-certificates` | Certificados HTTPS (read-only) |

**Extras na variante `opencode:dotnet`:**

| Ferramenta | O que faz |
|---|---|
| `dotnet` (SDK 10) | Compilar/rodar/testar código C#/.NET |
| `dotnet-trace` / `dotnet-counters` / `dotnet-dump` | Perfomance, contadores e dumps |
| `roslynator` | Análise estática e refactorings de C# |
| `roslyn-language-server` | Server LSP de C# (usado pelos built-ins `csharp` do opencode) |
| `curl` / `wget` | Clientes HTTP/FTP |
| `jq` | Processamento de JSON em pipelines |
| `unzip` / `zip` | Compactação |
| `tree` | Listar diretórios em árvore |
| `file` | Detectar tipo de arquivo |

**Diferença de comportamento entre variantes:**

- `opencode:dotnet`: LSP habilitado por padrão via config gerenciada em `/etc/opencode/opencode.json` (que também libera `read`, `edit`, `bash` e `external_directory`).
- `opencode` (base): sem LSP; valem as permissões padrão do opencode.

Se a lista real divergir daqui (ex.: nova versão da imagem), confirme no momento com
`command -v <nome>` antes de depender da ferramenta.