---
name: container-ambiente
description: >-
  Descreve a infraestrutura técnica e o catálogo de ferramentas do container
  isolado do Antigravity CLI (agy). Use para consultar as ferramentas
  disponíveis, variáveis de variante e o mapeamento de volumes persistentes.
---

# Ambiente de Execução (Container Antigravity)

O agente Antigravity (CLI `agy`) roda **dentro de um container isolado** do host (Debian 13 / Trixie).

## Contexto Técnico

- **Finalidade:** Desenvolvimento com **.NET 10 SDK** (C#/F#), linters, análise de código e diagnóstico de rede/logs.
- **Usuário:** `antigravity` (UID/GID 1100, `--userns=keep-id:uid=1100,gid=1100`), com `sudo` sem senha.
- **Variante ativa:** Definida em `$AGY_VARIANT` e registrada em `~/.gemini/antigravity-cli/variant` (`base`, `sound` ou `rea`).
- **Autenticação:** Padrão OAuth Google (Google AI Pro/Ultra) persistido no `FileKeychain` (`antigravity-oauth-token`) via volume persistente. Aceita `GEMINI_API_KEY` opcional.
- **Diretrizes e Segurança:** Consulte o arquivo global [`AGENTS.md`](file:///workspace/antigravity/AGENTS.md) para políticas permanentes de autonomia, sigilo de credenciais (Zero Secret Leak), localização de código e restrições.

## Persistência de Dados

| Caminho | Persiste? | Uso |
|---|---|---|
| `/workspace` | **Sim** | Código do projeto (montado do host) |
| `/home/antigravity` | **Sim** | Volume persistente `antigravity-home` (settings, tokens, skills de usuário) |
| `/tmp` | **Não** | Diretório efêmero para arquivos temporários de análise |

## Catálogo de Ferramentas Disponíveis

Consulte a [lista detalhada de utilitários](references/ferramentas.md) para especificações completas de cada ferramenta instalada.

- **Desenvolvimento & Diagnóstico .NET:** `dotnet` (.NET 10 SDK), `csharp-ls`, `roslynator`, `dotnet-dump`, `dotnet-trace`, `dotnet-counters`.
- **Linters & Qualidade de Código:** `shellcheck` (Shell/Bash), `sqlfluff` (SQL), `yq` (YAML/JSON processador Go).
- **Inspeção & Manipulação de Arquivos:** `vim` (editor padrão), `ripgrep` (`rg`), `jq`, `gawk`, `sed`, `grep`, `file`, `dos2unix`, `zip`/`unzip`, `zstd`, `zcat`/`zgrep`.
- **Rede & Diagnóstico de Servidor:** `curl`, `git`, `dig` (bind9-dnsutils), `traceroute`, `ping` (iputils-ping), `procps` (`ps`, `top`).
