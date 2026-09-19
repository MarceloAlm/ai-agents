---
name: container-ambiente
description: Descreve o ambiente onde o agente Antigravity (CLI agy) roda dentro de um container isolado (imagem antigravity). Use para saber quais ferramentas existem na imagem, que o agente tem liberdade total para fazer consultas e leituras (read_file, read_url, ferramentas de busca/inspeção), que /workspace e /home são as únicas pastas persistentes, que /tmp tem escrita livre mas não persiste, que há acesso à internet e ao projeto, e que não roda como root nem pode instalar pacotes.
---

# Ambiente de execução (container isolado)

O agente Antigravity (CLI `agy`) roda **dentro de um container isolado** do
restante do sistema (Podman), não no host. Isso tem consequências diretas no que
você pode e não pode fazer.

## Contexto

- **Finalidade do container:** Atuar como agente no desenvolvimento de sistemas com **.NET 10 SDK** em ambientes Windows e Linux, além da análise e diagnóstico de **logs de servidores** (arquivos de texto, compactados ou obtidos via requisições `curl`).
- **Isolado do host e sem acesso a fontes externas via SSH:** Não há cliente SSH instalado nem permissão de acesso a fontes Git remotas privadas ou servidores via SSH. O código com o qual você trabalha é montado localmente em `/workspace`.
- **Acesso à internet:** disponível para consultas web e requisições HTTP (`curl`) para obtenção de logs ou consultas de API.
- **Projeto atual:** o diretório de trabalho é `/workspace`, um bind mount do projeto do usuário no host.
- **Usuário:** não-root. O processo roda como `antigravity` (uid/gid 1000, `--userns=keep-id`).

## Autonomia e Consultas

- **Liberdade total para consultas:** Você tem total liberdade e autonomia para inspecionar e ler arquivos do projeto (`read_file`), consultar referências e documentações na web (`read_url`), analisar arquivos de log e executar comandos de compilação, teste e diagnóstico (`dotnet`, `git`, `rg`, `curl`, `jq`, `gawk`, `zgrep`, `dos2unix`).
- **Não hesite nem peça autorização para leituras:** Explore proativamente a base de código e fontes externas para obter todo o contexto necessário antes de responder ou propor alterações.

## Autenticação

- Você usa **OAuth sempre, com uma conta do Google** (Google AI Pro/Ultra) — nunca `GEMINI_API_KEY`. Não há modo "chave de API": sem sessão logada o `agy` solicita login.
- **1º login:** rode `agy auth login` (ou apenas `agy`). Em ambiente headless o `agy` usa o fluxo manual: imprime uma URL de autorização, você abre no navegador do host, autoriza e cola o código de volta no terminal.
- **Persistência:** o token fica em `~/.gemini/antigravity-cli/antigravity-oauth-token` (arquivo no volume `antigravity-home`, via `GEMINI_FORCE_FILE_STORAGE=true`). Login feito uma vez vale para as próximas execuções; `agy -p "..."` (headless mode) também respeita a sessão já autenticada.

## Restrições

- **Não é possível instalar ferramentas/pacotes.** Sem `apt`/`apt-get`, sem qualquer instalação de sistema: você não tem root e a imagem é efêmera. Planeje o trabalho apenas com as ferramentas listadas na seção abaixo.
- **Sem acesso SSH a servidores/Git:** Não tente operações de rede via SSH (`git@...`). Trabalhe apenas com o workspace local e requisições HTTP/curl.
- `/etc/ssl/certs` vem do pacote `ca-certificates` **da própria imagem** — não é montado do host.

## Pastas e persistência

| Caminho | Persistente? | Uso |
|---|---|---|
| `/workspace` | **Sim** | Projeto atual (bind mount do host). É onde vive o que importa. |
| `/home` (= `/home/antigravity`) | **Sim** | Volume persistente `antigravity-home` (settings, skills, histórico e cache do agy). |
| `/tmp` | **Não** | Escrita **sem restrições**, mas o conteúdo some quando o container encerra. |

Regra prática: o que precisar durar deve ir para `/workspace` ou `/home`; `/tmp` é para
trabalho descartável (downloads, arquivos temporários, testes) e nunca deve ser tratado
como dado importante persistente.

## Ferramentas disponíveis

| Ferramenta | O que faz |
|---|---|
| `agy` | O próprio agente Antigravity CLI |
| `dotnet` (SDK 10) | Compilação, execução, testes e gerenciamento de projetos .NET 10 (C#/F#) |
| `dotnet-dump` / `dotnet-trace` / `dotnet-counters` | Diagnóstico de processos, coleta de traces, dumps de memória e métricas de servidores .NET |
| `git` | Controle de versão local no repositório montado em `/workspace` |
| `curl` | Cliente HTTP (obtenção de logs de servidores via API, testes de endpoints) |
| `jq` | Processamento e formatação de JSON em pipelines (ex.: logs JSON/Serilog) |
| `rg` (ripgrep) | Busca textual ultrarrápida em código e grandes arquivos de log |
| `gawk` / `sed` / `grep` | Filtragem, extração de colunas e parsing avançado de logs |
| `dos2unix` | Normalização de quebras de linha (CRLF -> LF) em arquivos de log originados no Windows |
| `unzip` / `zip` | Extração e empacotamento de arquivos compactados (ex.: zips de logs) |
| `zcat` / `zgrep` / `zstd` | Leitura direta de logs compactados (.gz, .zst) sem descompactação manual |
| `less` | Visualização paginada de logs e diffs |
| `file` | Detectar tipo, codificação (UTF-8, ISO, UTF-16) e formato de arquivos de log |
| `ps` / `top` / `uptime` | Inspeção de processos e status do sistema (procps) |
| `dig` / `nslookup` | Consulta DNS e diagnóstico de resolução de nomes (dnsutils) |
| `traceroute` / `ping` | Rastreamento de rotas de rede e verificação de latência de servidores |
| `bash` | Shell padrão para os comandos |
| `ca-certificates` | Certificados HTTPS |

Se a lista real divergir daqui (ex.: nova versão da imagem), confirme no momento com
`command -v <nome>` antes de depender da ferramenta.