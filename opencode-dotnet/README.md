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
podman run --rm -it --userns=keep-id \
  -v "opencode-home:/home/node" \
  -v "$PWD:/workspace" \
  -w /workspace \
  opencode:dotnet
```

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
livre em `/tmp` (não persistente), acesso à internet e a impossibilidade de
instalar pacotes/rodar como root.

## LSP

- Habilitado por padrão via config gerenciada do opencode
  (`/etc/opencode/opencode.json` com `"lsp": true`).
- O server de C# inicia ao abrir `.cs`/`.csx` em projetos com `.sln`, `.slnx`,
  `.csproj` ou `global.json`; o de F# inicia ao abrir `.fs`/`.fsi`/`.fsx`.
- Como é config gerenciada, fica sempre ligado nesta imagem (não pode ser
  desligado pelo `opencode.json` do projeto). Para trabalhar sem LSP, use o
  container `opencode` base.
