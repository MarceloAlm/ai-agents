# OpenCode .NET

Container para desenvolvimento C# com OpenCode + .NET SDK 10, com **LSP habilitado**.

O LSP do opencode é habilitado por padrão via config gerenciada em
`/etc/opencode/opencode.json` (`"lsp": true`). Os servers C#/F# são
pré-instalados como dotnet tools em `/dotnet-tools` (no PATH), então não há
download em runtime.

Por padrão, essa config também **permite acesso às pastas sem pedir permissão**
a cada operação: `read`, `edit` e `bash` são `allow`, e o `external_directory`
é todo liberado (`*`). Isso evita o agente perguntar o tempo todo ao ler/editar
arquivos e rodar comandos.

## Build

```bash
./build.sh
# ou
podman build -t opencode:dotnet ./opencode-dotnet
```

## Executar

```bash
podman run --rm -it --userns=keep-id:uid=1100,gid=1100 \
  -v "opencode-home:/home/opencode" \
  -v "$PWD:/workspace" \
  -w /workspace \
  opencode:dotnet
```

O agente roda como usuário **`opencode`** (uid/gid 1100) e o volume
`opencode-home` é montado em `/home/opencode`. O `--userns=keep-id:uid=1100,gid=1100`
mapeia o usuário do host (uid 1000) para o uid/gid 1100 do container, mantendo
o host dono de `/workspace` e `/home`.

## Ferramentas

| Ferramenta | Descrição |
|------------|-----------|
| .NET SDK 10.0 | Compilar, rodar e testar C# |
| dotnet-trace | Coletar traces de performance |
| dotnet-counters | Monitorar contadores em tempo real |
| dotnet-dump | Coletar e analisar core dumps |
| roslynator | Análise estática + refactorings |
| roslyn-language-server | Server LSP de C# (built-in `csharp` do opencode) |
| fsautocomplete | Server LSP de F# (built-in `fsharp` do opencode) |
| ripgrep | Busca textual |
| git | Controle de versão |
| curl / wget | Clientes HTTP/FTP |
| jq | Processamento de JSON (parse/filtros em pipelines com curl) |
| unzip / zip | Compactação/descompactação |
| tree | Listar diretórios em árvore |
| file | Detectar tipo de arquivo |

## Skill de ambiente do container

A imagem inclui a skill `container-ambiente`, instalada em
`/etc/opencode/skills/` e registrada no config gerenciado (`skills.paths`).
Ela informa ao agente que ele roda num container isolado: ferramentas
disponíveis na imagem, pastas persistentes (`/workspace` e `/home`), escrita
livre em `/tmp` (não persistente), acesso à internet, privilégios de `sudo`
sem senha para instalações pontuais efêmeras e a orientação para sugerir
novas variantes de container para ferramentas recorrentes.

## LSP

- Habilitado por padrão via config gerenciada do opencode
  (`/etc/opencode/opencode.json` com `"lsp": true`).
- O server de C# inicia ao abrir `.cs`/`.csx` em projetos com `.sln`, `.slnx`,
  `.csproj` ou `global.json`; o de F# inicia ao abrir `.fs`/`.fsi`/`.fsx`.
- Como é config gerenciada, fica sempre ligado nesta imagem (não pode ser
  desligado pelo `opencode.json` do projeto). Para trabalhar sem LSP, use o
  container `opencode` base.
- O cache MEF do Roslyn é gravado ao lado dos assemblies em `/dotnet-tools`
  (que é `chown` para o usuário `opencode` no build), evitando erros de
  `Permission denied` no log do LSP a cada inicialização.

## Sincronização de skills (entrypoint)

O container roda um `entrypoint` que, **a cada execução**, sincroniza os
arquivos de `skills/` do projeto para o home do usuário:

1. **Fonte:** `skills/` do repositório de containers quando ele está montado em
   `/workspace` (ou `/workspace/skills`), senão as skills embutidas na imagem
   (`/etc/opencode/skills`).
2. **Destino persistente:** `~/.config/opencode/skills/`, controlado por um
   manifest de hash. Arquivos que você **não alterou** são atualizados para a
   nova versão do projeto; arquivos **personalizados** são movidos para
   `~/.config/opencode/skills-custom/` (com timestamp — nada se perde) e a
   versão oficial é reinstalada.
3. **Estado efetivo:** o resultado é instalado (via `sudo`) em
   `/etc/opencode/skills/`, que é o local com maior precedência de carregamento
   no opencode.

### Preferências pessoais

Suas preferências ficam num **arquivo separado**, criado uma única vez e que
nunca é sobrescrito:

```bash
~/.config/opencode/skills/container-ambiente/preferences.md
```

A skill `container-ambiente` instrui o agente a ler esse arquivo. Edite-o para
ajustar o comportamento (comportamento heredoc na criação de arquivos, idioma,
convenções) sem mexer na skill gerenciada.

### Skills próprias

Para registros e especializações do usuário, crie sempre uma skill em
**diretório separado** — nunca dentro de `container-ambiente/`:
`~/.config/opencode/skills/<nome>/SKILL.md` (global em `/home`) ou
`.opencode/skills/<nome>/SKILL.md` (no projeto em `/workspace`).
