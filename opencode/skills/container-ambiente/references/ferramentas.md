# Ferramentas disponíveis no container (opencode base)

| Ferramenta | O que faz |
|---|---|
| `node` / `npm` | Runtime JS; scripts e ferramentas npm locais |
| `opencode` | O próprio agente |
| `git` | Controle de versão |
| `rg` (ripgrep) | Busca textual rápida |
| `sudo` | Execução como superusuário para instalações pontuais efêmeras |
| `apt` / `apt-get` | Gerenciador de pacotes Debian (instalação em runtime) |
| `bash` | Shell padrão |
| `ca-certificates` | Certificados HTTPS (read-only) |

Nota: as variantes `opencode:dotnet` e `opencode:ml` adicionam `.NET SDK 10`,
`roslynator`, `roslyn-language-server` (LSP), `dotnet-trace/counters/dump`,
`curl`, `wget`, `jq`, `unzip`/`zip`, `tree` e `file`.

Se a lista real divergir daqui (ex.: nova versão da imagem), confirme com
`command -v <nome>` antes de depender da ferramenta.

## Boas Práticas e Economia de Tokens

1. **Busca:** use `rg` para localizar trechos; leia apenas linhas/arquivos relevantes.
2. **Config do opencode:** `opencode debug config` e `opencode debug skill` são mais baratos que inspecionar configs manualmente.
3. **Instalações:** prefira resolver no `Dockerfile` da variante (persistente) a reinstalar a cada sessão.
