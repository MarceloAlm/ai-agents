# OpenCode ML (.NET + Python)

Container para **estudo de redes neurais** com OpenCode, prioridade em **C#**:
. NET SDK 10 + LSP habilitado + runner de scripts `.csx` (exemplos rápidos) +
**Python disponível apenas para gerar gráficos** (curva de perda/acurácia).
Tem tudo para **gerar e executar código**: .NET, Node, git, busca, HTTP e teste.

Baseado no `opencode:dotnet`, com os mesmos servidores LSP C# pré-instalados
(sem download em runtime) e a mesma config gerenciada que permite `read`,
`edit`, `bash` e `external_directory` sem pedir permissão a cada operação.

## Build

```bash
./build.sh
# ou, fixando a versão do opencode:
./build.sh 2.0.0
# ou manualmente:
podman build --build-arg OPENCODE_VERSION=latest -t opencode:ml ./opencode-ml
```

## Executar

```bash
./opencode-ml.sh
# ou manualmente:
podman run --rm -it --userns=keep-id \
  -v "opencode-ml-home:/home/node" \
  -v "$PWD:/workspace" \
  -v "/etc/ssl/certs:/etc/ssl/certs:ro" \
  -w /workspace \
  opencode:ml
```

> O volume `opencode-ml-home` é separado do `opencode-home` usado pelas outras
> imagens, então credenciais/config do opencode não se misturam com os outros
> containers. Use o mesmo volume para reaproveitar histórico.

## Ferramentas

| Ferramenta | Descrição |
|------------|-----------|
| .NET SDK 10.0 | Compilar, rodar e testar C# (`dotnet new` / `dotnet run`) |
| dotnet-script | Executa scripts `.csx` — ótimo para experimentos curtos de estudo |
| dotnet-trace | Coletar traces de performance |
| dotnet-counters | Monitorar contadores em tempo real |
| dotnet-dump | Coletar e analisar core dumps |
| roslynator | Análise estática + refactorings |
| roslyn-language-server | Server LSP de C# (built-in `csharp` do opencode) |
| python3 / numpy / matplotlib | Geração de gráficos (curva de perda, acurácia, fronteiras) |
| node / npm | Runtime JS e ferramentas npm locais |
| ripgrep | Busca textual |
| git | Controle de versão |
| curl / wget | Clientes HTTP/FTP |
| jq | Processamento de JSON (parse/filtros em pipelines) |
| unzip / zip | Compactação/descompactação |
| tree | Listar diretórios em árvore |
| file | Detectar tipo de arquivo |

Pacotes NuGet úteis (restauram via internet no projeto): `TorchSharp`,
`Microsoft.ML`, `MathNet.Numerics` — veja `ml-reference/README.md`.

## Exemplos de referência

A imagem já vem com um ponto de partida para o estudo em `/opt/ml`:

- `perceptron.csx` — perceptron treinando AND/OR
- `mlp-xor.csx` — MLP 2-2-1 com backpropagation resolvendo XOR
- `README.md` — roteiro do estudo e bibliotecas C#

Copie para o workspace com `cp -r /opt/ml/. /workspace/` antes de editar
(`/opt/ml` é read-only).

## Skill de ambiente do container

A imagem inclui a skill `container-ambiente` em `/etc/opencode/skills/`,
registrada no config gerenciado (`skills.paths`). Ela informa ao opencode que
roda num container isolado: ferramentas da imagem, exemplos em `/opt/ml`,
pastas persistentes (`/workspace` e `/home`), escrita livre em `/tmp` (não
persistente), acesso à internet e a impossibilidade de instalar pacotes/rodar
como root.

## LSP

Habilitado por padrão via config gerenciada (`"lsp": true`). O server de C#
inicia ao abrir `.cs`/`.csx` em projetos com `.sln`, `.slnx`, `.csproj` ou
`global.json`. Como é config gerenciada, fica sempre ligado nesta imagem.