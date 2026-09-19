# Ferramentas disponíveis no container (opencode:ml)

| Ferramenta | O que faz |
|---|---|
| `node` / `npm` | Runtime JS; scripts e ferramentas npm locais |
| `opencode` | O próprio agente |
| `git` | Controle de versão |
| `rg` (ripgrep) | Busca textual rápida |
| `sudo` | Execução como superusuário para instalações pontuais efêmeras |
| `apt` / `apt-get` | Gerenciador de pacotes Debian (instalação em runtime) |
| `dotnet` (SDK 10) | Compilar, rodar e testar código C#/.NET |
| `dotnet-script` | Executar arquivos `.csx` de estudo (sem projeto) |
| `dotnet-trace` / `dotnet-counters` / `dotnet-dump` | Performance, contadores e dumps |
| `roslynator` | Análise estática e refactorings de C# |
| `roslyn-language-server` | Server LSP de C# (built-in `csharp` do opencode) |
| `python3` | Runtime Python com `numpy` e `matplotlib` (gráficos de perda/acurácia) |
| `curl` / `wget` | Clientes HTTP/FTP |
| `jq` | Processamento de JSON em pipelines |
| `unzip` / `zip` | Compactação |
| `tree` | Listar diretórios em árvore |
| `file` | Detectar tipo de arquivo |
| `bash` | Shell padrão |
| `ca-certificates` | Certificados HTTPS (read-only) |

Se a lista real divergir daqui (ex.: nova versão da imagem), confirme com
`command -v <nome>` antes de depender da ferramenta.

## Boas Práticas e Economia de Tokens

1. **C# / .NET:** prefira `dotnet build` ou `roslynator analyze` a ler arquivos inteiros.
2. **Scripts .csx:** rode direto com `dotnet-script <arquivo>.csx`.
3. **Gráficos Python:** salve `.png` com `matplotlib` em `/workspace` (persistente), não em `/tmp`.
4. **Busca:** use `rg`; leia apenas linhas/arquivos relevantes.
5. **Config do opencode:** `opencode debug config` e `opencode debug skill` são mais baratos que inspecionar configs manualmente.
