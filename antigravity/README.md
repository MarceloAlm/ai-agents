# Antigravity CLI (`agy`)

Container Podman para o agente de IA **Antigravity CLI** (`agy`), desenvolvido em binário nativo Go sobre base Debian 13 (`trixie-slim`), incluindo **.NET 10 SDK**, ferramentas de diagnóstico, linters e análise de logs.

O container vem pré-configurado com permissões para consultas autônomas de código e documentações, fuso horário oficial de Brasília (`America/Sao_Paulo`), suporte nativo a UTF-8 e autenticação via **OAuth com conta Google** (Google AI Pro/Ultra) persistida em volume.

---

## Build

A partir da raiz do repositório:

```bash
./antigravity/build.sh
```

Ou dentro do próprio diretório:

```bash
cd antigravity
./build.sh
# ou
podman build -t antigravity .
```

A imagem sempre baixa a versão mais recente oficial do executável `agy` durante o build.

---

## Instalação e Execução

### 1. Instalação recomendada no host (comando global `agy`)

Copie o script wrapper para `/usr/local/bin`:

```bash
sudo cp antigravity/agy.sh /usr/local/bin/agy
sudo chmod +x /usr/local/bin/agy
```

### 2. Executando em um projeto

Basta entrar na pasta do seu projeto e executar:

```bash
cd /caminho/do/projeto
agy
```

Ou diretamente via `podman`:

```bash
podman run --rm -it --userns=keep-id:uid=1100,gid=1100 \
  --hostname antigravity \
  -v "antigravity-home:/home/antigravity" \
  -v "$PWD:/workspace" \
  -w /workspace \
  antigravity:latest "$@"
```

> **Nota sobre `--hostname antigravity`**: O hostname fixo garante uma chave estável de criptografia para o `FileKeychain`, permitindo que o token OAuth seja descriptografado corretamente entre recriações do container.

---

## Autenticação (OAuth com Conta Google)

O método de autenticação padrão é **OAuth com conta Google** (Google AI Pro/Ultra).

1. No primeiro uso, execute:
   ```bash
   agy auth login
   # (ou simplesmente inicie 'agy' diretamente)
   ```
2. O terminal exibirá uma **URL de autorização**.
3. Abra a URL no seu navegador do host, faça login com a conta Google e autorize o acesso.
4. Copie o **código de autenticação** exibido e cole-o de volta no terminal.
5. O token é salvo e persistido automaticamente no volume `antigravity-home` em:  
   `~/.gemini/antigravity-cli/antigravity-oauth-token`

Nas próximas execuções, o login ocorre silenciosamente.

*(Opcional: Se desejar usar API Key do Gemini em vez de OAuth, passe a variável `GEMINI_API_KEY` no ambiente e configure `"modelProvider": "gemini"` no `settings.json`)*.

---

## Persistência de Dados

| Caminho no Container | Persiste? | Destino | Finalidade |
|---|---|---|---|
| `/workspace` | **Sim** | Pasta atual do host (`$PWD`) | Código-fonte e arquivos do projeto |
| `/home/antigravity` | **Sim** | Volume `antigravity-home` | Token OAuth, histórico, configurações e skills |
| `/tmp` | **Não** | Efêmero | Arquivos temporários da sessão |

---

## Ferramentas Disponíveis

| Ferramenta | Finalidade |
|---|---|
| `agy` | O próprio agente Antigravity CLI |
| `.NET 10 SDK` | Compilar, testar e executar aplicações C# e F# |
| `csharp-ls` | Servidor LSP de C# baseado em Roslyn |
| `roslynator` | Análise estática, refatorações e linters C# |
| `dotnet-dump`, `dotnet-trace`, `dotnet-counters` | Diagnóstico de performance, análise de dumps de memória e métricas |
| `shellcheck` | Linter e validador estático para scripts Bash/sh |
| `yq` | Parsing, extração e validação cirúrgica de arquivos YAML |
| `sqlfluff` | Linter e formatador de queries SQL (MySQL, T-SQL, etc.) |
| `vim` / `nano` | Editores de texto (Vim configurado com suporte UTF-8 nativo) |
| `dig` / `traceroute` / `ping` | Diagnóstico de rede e resolução DNS |
| `git`, `curl`, `jq`, `ripgrep` (`rg`), `gawk`, `sed` | Manipulação de arquivos, chamadas HTTP e análise de logs |
| `dos2unix`, `zstd`, `zcat`, `zgrep`, `file`, `procps` | Normalização de quebras de linha e inspeção de logs compactados |
| `sudo` | Acesso superusuário sem senha para instalações pontuais efêmeras via `apt-get` |

---

## Skills e Customizações do Usuário

O container vem com a skill `container-ambiente` atualizada automaticamente a cada inicialização pelo `entrypoint.sh`.

Para registrar runbooks, regras ou especializações próprias sem que sejam sobrescritas nos boots:
- **Global do usuário (persistida no volume):**  
  `~/.gemini/config/skills/<nome-da-skill>/SKILL.md`
- **Específica do projeto (versionada com seu repositório):**  
  `.agents/skills/<nome-da-skill>/SKILL.md`
