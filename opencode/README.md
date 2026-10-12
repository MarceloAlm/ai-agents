# OpenCode Containers

Containers Podman para o agente de IA **OpenCode** (`opencode`), organizados em uma **imagem base mínima** e **variantes incrementais**, todas compartilhando o mesmo volume persistente `opencode-home`.

---

## 🏗️ Arquitetura das Imagens

As imagens são construídas de forma estritamente **incremental**, reutilizando as camadas anteriores:

```
opencode:latest (Base)
  │  Node.js LTS, npm, opencode-ai, ripgrep, git, curl, jq, sudo
  │
  └───► opencode:dotnet (Incremental sobre base)
          │  .NET 10 SDK, dotnet-trace/dump, roslynator, LSP C# (Roslyn)
          │
          └───► opencode:ml (Incremental sobre dotnet)
                 Python (numpy, matplotlib), dotnet-script (.csx), /opt/ml
```

---

## 🏷️ Marcação de Variante

Para que o agente e o ambiente saibam exatamente qual variante está sendo executada:
* Cada imagem possui a variável fixa: `ENV OPENCODE_VARIANT=base` (ou `dotnet`, `ml`).
* O entrypoint registra automaticamente essa informação no volume compartilhado em:
  ```bash
  cat ~/.config/opencode/variant
  # Retorna: base, dotnet ou ml
  ```

---

## 🛠️ Build

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

# Construir todas as variantes em ordem incremental:
./opencode/build.sh all
```

*(O script detecta automaticamente a versão mais recente do `opencode-ai` no npm e constrói as camadas na ordem de dependência).*

---

## 🚀 Instalação e Execução no Host

### 1. Copiar os scripts para `/usr/local/bin`:

```bash
# Agente base:
sudo cp opencode/opencode.sh /usr/local/bin/opencode
sudo chmod +x /usr/local/bin/opencode

# Variante .NET 10 SDK + LSP:
sudo cp opencode/opencode-dotnet.sh /usr/local/bin/opencode-dotnet
sudo chmod +x /usr/local/bin/opencode-dotnet

# Variante Machine Learning:
sudo cp opencode/opencode-ml.sh /usr/local/bin/opencode-ml
sudo chmod +x /usr/local/bin/opencode-ml
```

### 2. Executar no projeto:

```bash
cd /caminho/do/projeto

# Base:
opencode

# Com .NET e LSP:
opencode-dotnet

# Com Machine Learning:
opencode-ml
```

Todas as variantes montam o projeto em `/workspace` e compartilham o volume `opencode-home:/home/opencode`, mantendo histórico, credenciais e configurações unificadas.
