---
name: reverse-engineering
description: >-
  Metodologia e ferramentas para engenharia reversa de software usando REA
  (Reverse Engineer Anything), utilitários binários e decompiladores. Use ao
  analisar binários nativos, aplicativos Electron/JS, pacotes .NET ou bibliotecas.
---

# Engenharia Reversa com REA (Reverse Engineer Anything)

Este container possui o **REA (Reverse Engineer Anything)** configurado nativamente como servidor MCP e CLI (`rea`), além de utilitários como `binutils`, `binwalk`, `strace`, `ltrace`, `gdb`, `asar` e runtime Node.js/Java.

## Metodologia de Investigação

Siga sempre um fluxo guiado por evidências concretas:

### 1. Triagem e Reconhecimento do Alvo

Identifique o tipo e a arquitetura do artefato antes de escolher a ferramenta:

* **Inspeção de cabeçalhos e tipo de arquivo:**
  ```bash
  file <alvo>
  ```
* **Busca rápida de strings e URLs/rotas de interesse:**
  ```bash
  strings -a -n 8 <alvo> | grep -i "termo"
  ```
* **Verificação de dependências dinâmicas e bibliotecas linkadas:**
  ```bash
  readelf -d <alvo>   # Linux ELF
  objdump -p <alvo>   # Windows PE / outros
  ```

---

### 2. Fluxos por Tecnologia

#### A. Aplicativos JavaScript e Electron (.asar ou pastas)

O REA possui suporte nativo para desempacotar e analisar o grafo completo de módulos:

```bash
# Análise de aplicação JS/Electron gerando relatório de evidências:
rea analyze-javascript-application /caminho/do/app --json > /tmp/evidence.json

# Resumir a visualização dos módulos e canais IPC:
jq -c '{source: {kind: "inline", evidence: .}, view: {kind: "summary"}}' /tmp/evidence.json > /tmp/view.json
rea inspect-analysis-view /tmp/view.json
```

* Para inspecionar arquivos `.asar` diretamente com a CLI auxiliar:
  ```bash
  asar list app.asar
  asar extract app.asar /tmp/extracted_app
  ```

#### B. Artefatos Gerenciados .NET (.dll ou .exe CIL)

O REA inspeciona tipos, métodos e CIL sem executar o binário:

```bash
# Inspecionar identidade do assembly:
rea inspect-managed-artifact /caminho/Assembly.dll --json

# Inspecionar membros de uma classe específica:
rea inspect-managed-members /caminho/Assembly.dll --type NomeDoNamespace.NomeDaClasse --json
```

#### C. Binários Nativos (ELF / PE / Mach-O / Firmware)

1. Use as ferramentas expostas pelo **servidor MCP `rea`** diretamente na conversa (ex: descompilação de funções, mapeamento de símbolos e chamadas).
2. Se necessário análise dinâmica em runtime controlado:
   ```bash
   strace -f -e trace=network,file -s 2048 ./binario [args]
   ltrace -f -s 256 ./binario [args]
   ```
3. Se um motor de descompilação como o Ghidra estiver disponível, aponte a variável `GHIDRA_INSTALL_DIR` para habilitar a descompilação nativa em C/pseudocódigo via REA.

---

## Regras de Execução

1. **Evidência acima de suposições:** Baseie suas conclusões em instruções, símbolos, endpoints de IPC ou fluxos decompilados verificáveis.
2. **Resultados volumosos:** Análises completas do REA podem gerar saídas extensas. Sempre redirecione para arquivos temporários em `/tmp` e filtre usando `jq` ou projeções de visualização do REA (`inspect-analysis-view`).
3. **Reconstrução limpa:** Ao reconstruir um algoritmo ou funcionalidade para o usuário, escreva código idiomático e limpo com base no entendimento obtido, fornecendo testes unitários quando apropriado.
