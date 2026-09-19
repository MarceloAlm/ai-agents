---
name: container-ambiente
description: >-
  Descreve o ambiente onde o agente Antigravity (CLI agy) roda dentro de um
  container isolado (imagem antigravity). Use para saber quais ferramentas
  existem na imagem, autonomia de consultas e leituras, permissão de sudo
  para instalações efêmeras, pastas persistentes (/workspace e /home), como
  criar skills personalizadas em diretórios separados para manter especializações
  dos usuários sem ser sobrescrito pelos updates de boot, e como sugerir
  criação de variantes quando ferramentas forem recorrentes.
---

# Ambiente de execução (container isolado)

O agente Antigravity (CLI `agy`) roda **dentro de um container isolado** do
restante do sistema (Podman), não no host.

## Contexto

- **Finalidade:** Desenvolvimento de sistemas com **.NET 10 SDK** (C#/F#) e análise/diagnóstico de **logs de servidores**.
- **Isolado do host:** Sem cliente SSH. O código é montado localmente em `/workspace`.
- **Acesso à internet:** disponível para consultas web e requisições HTTP (`curl`).
- **Usuário:** `antigravity` (uid/gid 1100, `--userns=keep-id:uid=1100,gid=1100`), com **`sudo` sem senha**.

## Autonomia

- **Liberdade total para consultas.** Explore proativamente código (`read_file`), web (`read_url`), logs e ferramentas de diagnóstico sem pedir autorização.

## Autenticação

- **Padrão: OAuth** com conta do Google (Google AI Pro/Ultra). Sem sessão → `agy auth login` (URL + código).
- **API key (opcional):** Se `GEMINI_API_KEY` for passada via ambiente e `"modelProvider": "gemini"` estiver no `settings.json`, usará chave de API.
- **Persistência:** token em `~/.gemini/antigravity-cli/antigravity-oauth-token` (volume `antigravity-home`, `GEMINI_FORCE_FILE_STORAGE=true`).

## Persistência

| Caminho | Persiste? | Uso |
|---|---|---|
| `/workspace` | **Sim** | Projeto atual (bind mount do host) |
| `/home/antigravity` | **Sim** | Volume `antigravity-home` (settings, skills, histórico) |
| `/tmp` | **Não** | Escrita livre, conteúdo efêmero |

## Skills Personalizadas e Atualizações de Boot

- **Atualizações automáticas no boot:** A skill oficial `container-ambiente` é mantida pela imagem do container e atualizada a cada inicialização (`entrypoint.sh`). **Nunca altere ou adicione customizações pessoais dentro de `container-ambiente/`**, pois essa pasta é sobrescrita pelo entrypoint a cada boot do container.
- **Como criar skills do usuário:** Para registrar procedimentos, regras de negócio, runbooks ou especializações próprias:
  - Crie sempre uma **nova skill em diretório separado**:
    - **Global no usuário (persistida no `/home`):**  
      `~/.gemini/config/skills/<nome-da-skill>/SKILL.md`
    - **Específica do projeto (persistida no `/workspace`):**  
      `.agents/skills/<nome-da-skill>/SKILL.md`
  - Dessa forma, as especializações do usuário ficam protegidas e persistidas permanentemente, ao mesmo tempo em que o container continua recebendo atualizações da skill base do projeto sem conflitos.

## Instalação de ferramentas

- **`sudo` sem senha** para instalações efêmeras durante a sessão (`sudo apt-get install -y <pacote>`).
- **Container efêmero (`--rm`):** instalações no sistema raiz não sobrevivem ao encerramento.
- **Ferramentas recorrentes?** Proponha uma **nova variante de container** (Dockerfile + build.sh próprios).

## Restrições

- Sem acesso SSH a servidores/Git (`git@...`). Apenas workspace local e HTTP/curl.
- `/etc/ssl/certs` vem do pacote `ca-certificates` da imagem, não do host.

## Ferramentas disponíveis

Consulte a [lista completa de ferramentas](references/ferramentas.md) para
detalhes de cada utilitário instalado na imagem.

Resumo rápido: `vim` (editor padrão), `nano`, `dotnet` (SDK 10),
`csharp-ls`, `roslynator`, `shellcheck`, `yq`, `sqlfluff`, `git`, `curl`,
`jq`, `rg`, `gawk`, `sed`, `grep`, `dig`, `dotnet-dump/trace/counters`,
`dos2unix`, `zip/unzip`, `zcat/zgrep/zstd`, `file`, `ps`, `top`, `ping`,
`traceroute`.
