# OpenCode Containers

Containers Podman para o agente de IA **OpenCode** (`opencode`), organizados em uma imagem base mínima e variantes incrementais, todas compartilhando o mesmo volume persistente `opencode-home`.

---

## Sumário

1. [Arquitetura das Imagens](#1-arquitetura-das-imagens)
2. [Marcação de Variante](#2-marcação-de-variante)
3. [Build](#3-build)
4. [Instalação e Execução no Host](#4-instalação-e-execução-no-host)
5. [Política de Zero Secret Leak](#5-política-de-zero-secret-leak)

---

## 1. Arquitetura das Imagens

As imagens são construídas de forma estritamente **incremental**, reutilizando as camadas anteriores:

```
opencode:latest (Base)
  |  Node.js LTS, npm, OpenCode 2 (@opencode/cli), ripgrep, git, curl, jq, sudo (escopo apt/npm)
  |
  +---> opencode:dotnet (Incremental sobre base)
          |  .NET 10 SDK, dotnet-trace/dump, roslynator, LSP C# (Roslyn)
          |
          +---> opencode:ml (Incremental sobre dotnet)
                 Python (numpy, matplotlib), dotnet-script (.csx), /opt/ml
```

| Imagem | Camada | Conteúdo |
|---|---|---|
| `opencode:latest` | Base | Node.js LTS, npm, OpenCode 2 (`@opencode/cli`), `ripgrep`, `git`, `curl`, `jq`, `sudo` (escopo apt/npm) |
| `opencode:dotnet` | Incremental | Base + .NET 10 SDK, `dotnet-trace`/`counters`/`dump`, `roslynator`, `roslyn-language-server` (LSP C#) |
| `opencode:ml` | Incremental | Dotnet + `python3`, `numpy`, `matplotlib`, `dotnet-script` (`.csx`), `/opt/ml` |

---

## 2. Marcação de Variante

Para que o agente e o ambiente saibam exatamente qual variante está sendo executada:

- Cada imagem possui a variável fixa `ENV OPENCODE_VARIANT` (`base`, `dotnet` ou `ml`).
- O entrypoint registra automaticamente essa informação no volume compartilhado:

```bash
cat ~/.config/opencode/variant
# Retorna: base, dotnet ou ml
```

O controle de versão do perfil vive na imagem: o Dockerfile grava o carimbo em `/etc/opencode/.image-version` e os scripts que atualizam o `/home` ficam em `/etc/opencode/update/`. A cada inicialização o `entrypoint.sh` chama `update/run.sh`, que:

- **sempre** regenera `~/.config/opencode/AGENTS.md` a partir de `/etc/opencode/AGENTS.md` (cópia imutável da imagem — o conteúdo aponta as regras canônicas em `/etc/opencode`; conteúdo pessoal deve ficar em skills, não no AGENTS.md);
- se o carimbo de `/etc/opencode/.image-version` já consta em `~/.config/opencode/.applied-version`, encerra (caminho rápido);
- senão aplica as atualizações pesadas — sincronização/remoção de skills (`update/skills.sh`) e limpeza de artefatos legados — e grava o carimbo no perfil.

Nada em `/etc/opencode` é escrito em runtime: só o Dockerfile atualiza a imagem.

---

## 3. Build

A partir da raiz do repositório:

```bash
# Imagem base mais simples (opencode:latest)
./opencode/build.sh

# Variante com .NET 10 SDK e LSP C# (opencode:dotnet)
./opencode/build-dotnet.sh
# ou
./opencode/build.sh dotnet

# Variante de Machine Learning em C# (opencode:ml)
./opencode/build-ml.sh
# ou
./opencode/build.sh ml

# Construir todas as variantes em ordem incremental
./opencode/build.sh all
```

O script detecta automaticamente a versão mais recente do **OpenCode 2** (`@opencode/cli`) no npm e constrói as camadas na ordem de dependência. Para fixar uma versão específica, passe-a como argumento (ex.: `./opencode/build.sh 2.0.31`).

Cada build recebe ainda um carimbo de versão da imagem (variável `IMAGE_VERSION`, data/hora UTC, sobrescrevível no momento do build — ex.: `IMAGE_VERSION=2026.10 ./opencode/build.sh`), gravado pelo Dockerfile em `/etc/opencode/.image-version`. É esse arquivo que dispara a atualização do perfil na primeira execução da imagem nova (ver [5.6](#56-referências-internas)).

---

## 4. Instalação e Execução no Host

### 4.1 Copiar os scripts para `/usr/local/bin`

```bash
# Agente base
sudo cp opencode/opencode.sh /usr/local/bin/opencode
sudo chmod +x /usr/local/bin/opencode

# Variante .NET 10 SDK + LSP
sudo cp opencode/opencode-dotnet.sh /usr/local/bin/opencode-dotnet
sudo chmod +x /usr/local/bin/opencode-dotnet

# Variante Machine Learning
sudo cp opencode/opencode-ml.sh /usr/local/bin/opencode-ml
sudo chmod +x /usr/local/bin/opencode-ml
```

### 4.2 Executar no projeto

```bash
cd /caminho/do/projeto

opencode          # base
opencode-dotnet   # com .NET e LSP
opencode-ml       # com Machine Learning
```

Todas as variantes montam o projeto em `/workspace` e compartilham o volume `opencode-home:/home/opencode`, mantendo histórico, credenciais e configurações unificadas.

---

## 5. Política de Zero Secret Leak

Política obrigatória e inegociável para todo o projeto. O sigilo prevalece sobre a conveniência: em caso de dúvida, não exponha.

### 5.1 Escopo

Aplica-se a código, documentação, logs, imagens, volumes e processos de build e CI/CD deste projeto.

### 5.2 Princípios

1. **Segredo não entra no contexto do modelo** em nenhuma hipótese.
2. **Segredo não é persistido** em repositório, imagem, log ou histórico de comandos.
3. **Credencial é injetada em tempo de execução**, nunca hardcode.

### 5.3 Recomendações

#### Injeção de credenciais

- Use variáveis de ambiente ou um gerenciador de segredos (ex.: HashiCorp Vault, secret store do sistema operacional).
- Nunca hardcode chaves em arquivos versionados.
- No OpenCode, provedores e credenciais são resolvidos em `~/.config/opencode` dentro do volume `opencode-home`, nunca na imagem.

#### Arquivos sensíveis

- Mantenha `.env` fora do controle de versão (`.gitignore`); o `.containerignore` deste projeto já o exclui do contexto de build.
- Nunca copie `.env`, `.htpasswd` ou chaves privadas para dentro de uma imagem.

#### Build de imagens (Podman/Docker)

- **Nunca** passe credenciais como `--build-arg`: elas persistem no histórico de camadas da imagem. Use `--secret id=<id>,src=<arquivo>` (Buildah/Docker BuildKit) ou injete em runtime.
- Não fixe chaves em instruções `ENV` ou `COPY` durante o build.

#### Comandos e logs

- Nunca passe senhas em argumentos de linha de comando (visíveis em `ps` e no histórico). Use `read -s` ou variáveis de ambiente.
- Evite `set -x` em scripts que lidadem com segredos; redija qualquer saída que possa conter credenciais.
- Mascare imediatamente qualquer credencial exibida inadvertidamente com um placeholder (ex.: `<TOKEN_REDACTED>`, `[SENHA_OCULTA]`, `******`) — o sigilo prevalece sobre a conveniência.

#### Versionamento e CI

- Adicione scanning de segredos no pre-commit e na CI (ex.: `gitleaks`, `trufflehog`).
- Utilize os secrets nativos da plataforma na CI (ex.: GitHub Actions secrets) e mascare saídas sensíveis nos logs.

#### Volumes persistentes

- O volume `opencode-home` armazena credenciais e histórico do agente. Trate-o como sensível: não exporte nem commite seu conteúdo.

### 5.4 Em caso de vazamento

1. Revogue ou rotacione a credencial exposta imediatamente.
2. Comunique o incidente às partes afetadas.
3. Audite o histórico (`git log`, logs de CI, histórico de camadas da imagem) para localizar o vazamento.
4. Inclua a regra ou o scanning correspondente para prevenir recorrência.

### 5.5 Gates de permissão (defesa em profundidade)

A política não depende apenas de instrução ao agente; há enforcement técnico no `opencode.json` do container. As regras de permissão têm `read` amplo (`*`), mas um conjunto de regras ao **final** do array — que vencem o match amplo, pois vale a última regra — força prompt na leitura de arquivos sensíveis:

```json
{ "action": "read", "resource": "*.env",        "effect": "ask" },
{ "action": "read", "resource": "*.env.*",      "effect": "ask" },
{ "action": "read", "resource": "*id_rsa",      "effect": "ask" },
{ "action": "read", "resource": "*id_ed25519",  "effect": "ask" },
{ "action": "read", "resource": "*.pem",        "effect": "ask" },
{ "action": "read", "resource": "*.key",        "effect": "ask" },
{ "action": "read", "resource": "*credentials*", "effect": "ask" },
{ "action": "read", "resource": "*.env.example", "effect": "allow" }
```

A última regra devolve a leitura de `*.env.example` (modelo de configuração, sem segredos reais — default nativo do OpenCode 2) sem afrouxar os prompts acima.

Isso restaura e estende o guarda nativo da V2 (que marcaria `*.env` como `ask`), alinhando a porta técnica à política.

### 5.6 Referências internas

- Regras canônicas: `rules/zero-secret-leak.md` e `AGENTS.md`, copiados **pelo Dockerfile** para `/etc/opencode/` (imutáveis em runtime). `update/run.sh` regenera `~/.config/opencode/AGENTS.md` a cada inicialização a partir de `/etc/opencode/AGENTS.md` — o perfil aponta as regras imutáveis em `/etc/opencode`; conteúdo pessoal não deve ser editado ali (sobrescrito a cada boot; use skills pessoais). Artefatos de versões antigas (`~/.config/opencode/rules/`) são removidos na atualização por versão. Não há cópia de `rules/` dentro do perfil.
- Gates de permissão: `scripts/setup-base.sh` (seção `permissions` do `opencode.json`, fonte única do bloco). A variante dotnet preserva essa configuração e apenas acrescenta `"lsp": true` via `jq`, sem duplicar as regras.
- Sincronização de skills: `update/run.sh` → `update/skills.sh` (instalados em `/etc/opencode/update/` pela imagem), somente na 1ª inicialização de cada carimbo (`/etc/opencode/.image-version` vs `~/.config/opencode/.applied-version`): manifesto de hashes, remoção do que saiu da fonte (skills pessoais nunca são tocadas) e limpeza de órfãs. Entre versões não há varredura — nem `find`, nem `sha256sum`, nem `sudo`; `/etc/opencode` nunca é escrito em runtime.
- Skill de ambiente: `skills/container-ambiente/SKILL.md` (aponta para a política no AGENTS.md; não a duplica).
- Testes: `tests/run.sh` — sintaxe (`bash -n`), JSON do `opencode.json`, diff R5 e suíte sandbox do fluxo de atualização (roda no host, sem Docker).
