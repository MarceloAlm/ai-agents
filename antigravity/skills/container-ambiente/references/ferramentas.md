# Ferramentas disponíveis no container

| Ferramenta | O que faz |
|---|---|
| `agy` | O próprio agente Antigravity CLI |
| `vim` / `vi` | **Editor de texto padrão** do sistema (`$EDITOR`, `$VISUAL` e `/usr/bin/editor`) |
| `nano` | Editor de texto simples alternativo |
| `sudo` | Superusuário para instalações pontuais efêmeras |
| `apt` / `apt-get` | Gerenciador de pacotes Debian (instalação em runtime) |
| `dpkg` / `apt-cache` | Consulta de pacotes instalados e disponíveis |
| `dotnet` (SDK 10) | Compilação, execução, testes e gerenciamento de projetos .NET 10 (C#/F#) |
| `csharp-ls` | Servidor LSP C# baseado em Roslyn para análise semântica e navegação |
| `roslynator` | Análise estática, linting e refatorações de código C# (.NET) |
| `dotnet-dump` / `dotnet-trace` / `dotnet-counters` | Diagnóstico: dumps de memória, traces de execução e métricas em tempo real |
| `shellcheck` | Análise estática e detecção de bugs em scripts Bash/sh |
| `yq` | Processamento, filtros e validação de arquivos YAML (estilo `jq`) |
| `sqlfluff` | Linter e validador de sintaxe SQL com suporte a dialetos (MySQL, T-SQL) |
| `git` | Controle de versão local no repositório em `/workspace` |
| `curl` | Cliente HTTP (obtenção de logs, testes de endpoints, consultas de API) |
| `jq` | Processamento e formatação de JSON (ex.: logs JSON/Serilog) |
| `rg` (ripgrep) | Busca textual ultrarrápida em código e grandes arquivos de log |
| `gawk` / `sed` / `grep` | Filtragem, extração de colunas e parsing avançado de logs |
| `dos2unix` | Normalização de quebras de linha (CRLF → LF) em arquivos Windows |
| `unzip` / `zip` | Extração e empacotamento de arquivos compactados |
| `zcat` / `zgrep` / `zstd` | Leitura direta de logs compactados (.gz, .zst) sem descompactação manual |
| `less` | Visualização paginada de logs e diffs |
| `file` | Detectar tipo, codificação (UTF-8, ISO, UTF-16) e formato de arquivos |
| `ps` / `top` / `uptime` | Inspeção de processos e status do sistema |
| `dig` | Consulta DNS e diagnóstico de resolução de nomes (**preferido** sobre `nslookup`) |
| `nslookup` | Consulta DNS simples (disponível, mas prefira `dig` para diagnósticos detalhados) |
| `traceroute` / `ping` | Rastreamento de rotas de rede e verificação de latência |
| `bash` | Shell padrão |
| `ca-certificates` | Certificados HTTPS |

---

## Boas Práticas e Economia de Tokens

1. **Bash (`.sh`):** Use `shellcheck <script.sh>` para validar sintaxe, boas práticas e evitar armadilhas de quoting antes de propor mudanças.
2. **YAML (`.yml`, `.yaml`):** Em vez de ler arquivos YAML inteiros de centenas de linhas, use `yq '.caminho.chave' arquivo.yml` para extrair valores específicos com precisão cirúrgica.
3. **SQL (MySQL e SQL Server):** Valide queries e migrations com `sqlfluff lint <arquivo.sql> --dialect mysql` ou `--dialect tsql` para evitar misturar dialetos proprietários.
4. **C# / .NET:** Use `roslynator analyze` e `csharp-ls` para obter diagnósticos semânticos estruturados do compilador Roslyn.
5. **DNS:** Prefira sempre `dig` sobre `nslookup`. O `dig` oferece saída estruturada, controle granular de flags e é o padrão de referência para troubleshooting de rede.
6. **Editores:** O `vim` está configurado como editor padrão do ambiente (`EDITOR=vim`, `VISUAL=vim` e link prioritário `/usr/bin/editor`). O `nano` também está disponível para quem preferir um editor mais simples.

Se a lista real divergir daqui (ex.: nova versão da imagem), confirme com
`command -v <nome>` antes de depender da ferramenta.
