---
name: container-ambiente
description: Descreve o ambiente onde o agente Antigravity (CLI agy) roda dentro de um container isolado (imagem antigravity). Use para saber quais ferramentas existem na imagem, que /workspace e /home são as únicas pastas persistentes, que /tmp tem escrita livre mas não persiste, que há acesso à internet e ao projeto, e que não roda como root nem pode instalar pacotes. Consultar antes de assumir que há ferramentas, tentar instalar dependências ou gravar arquivos fora de /workspace e /home.
---

# Ambiente de execução (container isolado)

O agente Antigravity (CLI `agy`) roda **dentro de um container isolado** do
restante do sistema (Podman), não no host. Isso tem consequências diretas no que
você pode e não pode fazer.

## Contexto

- **Isolado do host:** não há acesso aos arquivos, processos ou serviços do host, exceto pelos caminhos montados listados abaixo.
- **Acesso à internet:** disponível. Ferramentas de rede (`git`, `curl`, `wget`, downloads de dependências de projeto...) funcionam normalmente.
- **Projeto atual:** o diretório de trabalho é `/workspace`, um bind mount do projeto do usuário no host. É onde estão os arquivos do projeto com os quais você deve trabalhar.
- **Usuário:** não-root. O processo roda como `node` (uid/gid 1000, `--userns=keep-id`).

## Autenticação

- Você usa a **API do Google (Gemini)** via `GEMINI_API_KEY`, injetada por variável de ambiente pelo script `antigravity.sh`. Não há sessão de conta logada (`/logout` não tem efeito).

## Restrições

- **Não é possível instalar ferramentas/pacotes.** Sem `apt`/`apt-get`, sem qualquer instalação de sistema: você não tem root e a imagem é efêmera. Planeje o trabalho apenas com as ferramentas listadas na seção abaixo.
- Se faltar uma ferramenta, **não tente instalá-la**: adapte a abordagem com o que existe (ex.: `rg` no lugar de outra busca, scripts em bash/git) ou avise o usuário.
- `/etc/ssl/certs` é montado **read-only** do host — é de onde vêm os certificados HTTPS.

## Pastas e persistência

| Caminho | Persistente? | Uso |
|---|---|---|
| `/workspace` | **Sim** | Projeto atual (bind mount do host). É onde vive o que importa. |
| `/home` (= `/home/node`) | **Sim** | Volume persistente `antigravity-home` (settings, skills, histórico e cache do agy). |
| `/tmp` | **Não** | Escrita **sem restrições**, mas o conteúdo some quando o container encerra. |

Regra prática: o que precisar durar deve ir para `/workspace` ou `/home`; `/tmp` é para
trabalho descartável (downloads, arquivos temporários, testes) e nunca deve ser tratado
como dado importante persistente.

## Ferramentas disponíveis

| Ferramenta | O que faz |
|---|---|
| `agy` | O próprio agente Antigravity CLI |
| `git` | Controle de versão |
| `curl` | Cliente HTTP (testes de API, downloads) |
| `jq` | Processamento de JSON em pipelines |
| `rg` (ripgrep) | Busca textual rápida |
| `bash` | Shell padrão para os comandos |
| `ca-certificates` | Certificados HTTPS (read-only) |

Se a lista real divergir daqui (ex.: nova versão da imagem), confirme no momento com
`command -v <nome>` antes de depender da ferramenta.