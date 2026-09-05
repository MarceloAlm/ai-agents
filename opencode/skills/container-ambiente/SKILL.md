---
name: container-ambiente
description: Descreve o ambiente onde o opencode roda dentro de um container isolado (imagens opencode e opencode:dotnet). Use para saber quais ferramentas existem na imagem, que /workspace e /home são as únicas pastas persistentes, que /tmp tem escrita livre mas não persiste, que há acesso à internet e ao projeto, e que não roda como root nem pode instalar pacotes. Consultar antes de assumir que há ferramentas, tentar instalar dependências ou gravar arquivos fora de /workspace e /home.
---

# Ambiente de execução (container isolado)

O opencode roda **dentro de um container isolado** do restante do sistema (Podman),
não no host. Isso tem consequências diretas no que você pode e não pode fazer.

## Contexto

- **Isolado do host:** não há acesso aos arquivos, processos ou serviços do host, exceto pelos caminhos montados listados abaixo.
- **Acesso à internet:** disponível. Ferramentas de rede (`git`, `curl`, `wget`, `npx`, download de dependências de projeto...) funcionam normalmente.
- **Projeto atual:** o diretório de trabalho é `/workspace`, um bind mount do projeto do usuário no host. É onde estão os arquivos do projeto com os quais você deve trabalhar.
- **Usuário:** não-root. O processo roda como `node` (uid/gid 1000, `--userns=keep-id`).

## Restrições

- **Não é possível instalar ferramentas/pacotes.** Sem `apt`/`apt-get`, sem `npm i -g`, sem `dotnet tool install`, sem qualquer instalação de sistema: você não tem root e a imagem é efêmera. Planeje o trabalho apenas com as ferramentas listadas na seção abaixo.
- Se faltar uma ferramenta, **não tente instalá-la**: adapte a abordagem com o que existe (ex.: `rg` no lugar de outra busca, scripts em node/git) ou avise o usuário.
- Execuções pontuais via `npx` (cache no `/home`) *podem* funcionar, mas não tratá-las como instalação persistente.
- `/etc/ssl/certs` é montado **read-only** do host — é de onde vêm os certificados HTTPS.

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