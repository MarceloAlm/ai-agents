# Ferramentas disponíveis no container (opencode:dotnet)

| Ferramenta | O que faz |
|---|---|
| `node` / `npm` | Runtime JS; scripts e ferramentas npm locais |
| `opencode` | O próprio agente |
| `git` | Controle de versão |
| `rg` (ripgrep) | Busca textual rápida |
| `sudo` | Execução como superusuário para instalações pontuais efêmeras |
| `apt` / `apt-get` | Gerenciador de pacotes Debian (instalação em runtime) |
| `dotnet` (SDK 10) | Compilar, rodar e testar código C#/.NET |
| `dotnet-trace` / `dotnet-counters` / `dotnet-dump` | Performance, contadores e dumps |
| `roslynator` | Análise estática e refactorings de C# |
| `roslyn-language-server` | Server LSP de C# (built-in `csharp` do opencode) |
| `curl` / `wget` | Clientes HTTP/FTP |
| `jq` | Processamento de JSON em pipelines |
| `unzip` / `zip` | Compactação |
| `tree` | Listar diretórios em árvore |
| `file` | Detectar tipo de arquivo |
| `bash` | Shell padrão |
| `ca-certificates` | Certificados HTTPS (read-only) |

Se a lista real divergir daqui (ex.: nova versão da imagem), confirme com
`command -v <nome>` antes de depender da ferramenta.

## LSP C# (built-in do opencode)

- O server `csharp` inicia ao abrir `.cs`/`.csx` em projetos com `.sln`, `.slnx`, `.csproj` ou `global.json`.
- Inicia via `roslyn-language-server --stdio --autoLoadProjects`; requer o binário no PATH (`/dotnet-tools`).
- O MEF cache do Roslyn fica em `/dotnet-tools/.store/roslyn-language-server/.../linux-x64/cache` — gravável pelo usuário `opencode` (fix via chown no Dockerfile). Se o stderr mostrar `Permission denied` no cache, é inofensivo: o server segue respondendo ao `initialize` normalmente.
- Comandos de diagnóstico: `opencode debug lsp symbols <query>`, `opencode debug lsp document-symbols <uri>`. Atenção: `document-symbols`/`diagnostics` podem retornar `[]`/`{}` porque a instância de debug é descartada em <1s antes de o Roslyn concluir o `initialize` — não significa LSP quebrado.
- Use `dotnet build` para diagnósticos da solução e `roslynator analyze` para análise estática da árvore sintática/semântica.

## Boas Práticas e Economia de Tokens

1. **C# / .NET:** prefira `dotnet build` (erros CS em texto) ou `roslynator analyze` em vez de ler arquivos inteiros.
2. **JSON / logs:** use `jq` para extrair campos específicos em vez de despejar arquivos grandes (`jq -r '.level' log.json`).
3. **Busca:** use `rg` para localizar trechos; leia apenas as linhas/arquivos relevantes.
4. **Config do opencode:** `opencode debug config`, `opencode debug skill` e `opencode debug lsp` são mais baratos que inspecionar configs manualmente.
