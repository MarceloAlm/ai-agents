# Benchmark de Engenharia: AI-Stack & Specialized Agent em GPU Mobile
**Plataforma de Teste:** NVIDIA GeForce RTX 4050 Laptop GPU (6GB GDDR6, AD107M, Ada Lovelace)  
**Processador Host:** Intel Core (Raptor Lake, HM770 Chipset) | **SO:** Linux (Host `diana`, Kernel 6.x)  
**Gerenciador de Containers:** Podman (Rootless, Driver CDI / NVIDIA Container Toolkit)  
**Data da Avaliação:** Setembro de 2026

---

## 1. Sumário Executivo & Conclusões Principais

Este documento consolida os resultados empíricos coletados a partir de 12 baterias de testes automatizados com o **Specialized Agent** conectado aos motores neurais do **AI-Stack** (`llama.cpp` e `Ollama`) e ao metabuscador privado **SearXNG**.

### Principais Constatações:
1. **Soberania do `llama.cpp` em Janelas Longas na RTX 4050:**
   - Com contexto de **32k (`32768`)**, o `llama.cpp` executou a bateria completa em **148,00s (2,5 min)** a uma taxa de **34,3 a 37,2 tokens/s**.
   - O `Ollama` com os mesmos 32k levou **300,60s (5,0 min)** a **17,7 a 19,4 tokens/s**.
   - **O `llama.cpp` foi mais de 2x mais rápido (103% de ganho)** devido à combinação de **Flash Attention nativo** (`--flash-attn auto`) e **KV Cache quantizado em Q8_0** (`-ctk q8_0 -ctv q8_0`).
2. **O "Sweet Spot" de Contexto para 6GB de VRAM:**
   - A janela de **16.384 tokens (16k)** representa o ponto de equilíbrio perfeito para a RTX 4050 Mobile: consome apenas ~448 MiB adicionais de VRAM para o KV Cache, ingere mais de 8.200 tokens de logs brutos sem truncamento e mantém mais de **32 tokens/s**.
3. **Especialização de Modelos: Qwen 2.5 Coder vs. DeepSeek-R1:**
   - **Qwen 2.5 Coder 7B (Melhor para Automação SRE/DevOps):** Executa comandos cirúrgicos (`chmod 600`, `sed -i`, `iptables`), gera rotinas de verificação sintática prévia e encerra o turno com economia de tokens (3.800 a 5.000 tokens totais).
   - **DeepSeek-R1 7B (Melhor para Relatórios Explicativos):** Excelente capacidade de raciocínio investigativo e normalização temporal, mas **propenso a alucinações perigosas em comandos de sistema operacional** (sugeriu `sudo fdisk -o raw /mnt/db/` para corrigir autenticação de banco de dados e loops infinitos em `/proc/6000+t`).
4. **Eficácia da Metabusca Privada (SearXNG):**
   - O grounding multi-query eliminou alucinações na Etapa 4, permitindo identificar com precisão as CVEs reais (`CVE-2021-41773`, `CVE-2022-3602`, `CVE-2023-44487`) e reconhecer a política de backport do Debian 12 Bookworm, evitando falsos positivos.

---

## 2. Especificações do Hardware & Orçamento de Memória VRAM

### 2.1. Arquitetura da GPU
- **Chip:** NVIDIA AD107M (GeForce RTX 4050 Max-Q / Mobile)
- **Microarquitetura:** Ada Lovelace (TSMC 4N)
- **VRAM Dedicada:** 6.144 MiB (6 GB) GDDR6
- **Largura do Barramento:** 96-bit (~192 GB/s de largura de banda)
- **Tensor Cores:** 80 Núcleos Tensores de 4ª Geração (FP8/FP16 nativos)
- **CUDA Cores:** 2560

### 2.2. Orçamento Físico de VRAM na RTX 4050 (Modelos 7B Q4_K_M)

| Componente na VRAM | 8.192 tokens (8k) | 16.384 tokens (16k) | 32.768 tokens (32k) |
| :--- | :--- | :--- | :--- |
| **Pesos do Modelo (7B Q4_K_M)** | ~4.460 MiB (4,35 GB) | ~4.460 MiB (4,35 GB) | ~4.460 MiB (4,35 GB) |
| **Buffers de CUDA / Overhead do Driver** | ~220 MiB | ~220 MiB | ~220 MiB |
| **KV Cache FP16 (sem quantização)** | 448 MiB | 896 MiB | 1.792 MiB *(estoura 6GB!)* |
| **KV Cache Q8_0 (`llama.cpp`)** | **224 MiB** | **448 MiB** | **896 MiB** |
| **VRAM Total Ocupada (com Q8_0)** | **~4.904 MiB (4,78 GB)** | **~5.128 MiB (5,00 GB)** | **~5.576 MiB (5,44 GB)** |
| **Margem Livre na GPU (de 6.144 MiB)** | **+1.240 MiB (Folga)** | **+1.016 MiB (Seguro)** | **+568 MiB (Limite Seguro)** |

> [!IMPORTANT]
> Sem a quantização de KV cache (`q8_0`), uma janela de 32k em FP16 exigiria 1,79 GB apenas para o cache de contexto, totalizando ~6,47 GB e forçando o offload parcial para a RAM do sistema via PCIe, degradando o throughput. O `llama.cpp` com `-ctk q8_0 -ctv q8_0` mantém a alocação de 32k **100% contida dentro dos 6GB de VRAM**.

---

## 3. Matriz Consolidada de Resultados Empíricos

Os testes processaram os mesmos 5 alvos padronizados da suíte `exemplo-audit`:
1. `etapa1-ssh-audit` (Hardening de SSH)
2. `etapa1-db-auth` (Autenticação PostgreSQL & SCRAM)
3. `etapa2-full-stack` (Nginx + Keycloak + Sandbox Bash)
4. `etapa3-forensic-killchain` (Perícia Forense APT + Normalização UTC)
5. `etapa4-multi-cve-threat-intel` (Triangulação Multi-Query SearXNG)

### 3.1. Tabela Geral de Execuções

| # | Arquivo de Log | Backend | Modelo | Contexto | Web (SearXNG) | Tempo Total | Throughput Médio | Tokens Gerados |
| :-: | :--- | :--- | :--- | :-: | :-: | :-: | :-: | :-: |
| 1 | `teste_router_qwen.txt` | `llama.cpp` | `qwen2.5-coder:7b` | 8k | Ativo | **129,36s (2,2m)** | **31,3 ~ 32,3 t/s** | 3.858 |
| 2 | `teste_llamacpp_ctx16k_qwen.txt` | `llama.cpp` | `qwen2.5-coder:7b` | 16k | Ativo | **138,92s (2,3m)** | **29,2 ~ 32,8 t/s** | 4.176 |
| 3 | `teste_llamacpp_ctx32k_qwen.txt` | `llama.cpp` | `qwen2.5-coder:7b` | 32k | Ativo | **148,00s (2,5m)** | **34,3 ~ 37,2 t/s** | 4.880 |
| 4 | `teste3.txt` | `llama.cpp` | `qwen2.5-coder:7b` | 8k | Ativo | **158,84s (2,6m)** | **30,1 ~ 39,7 t/s** | 4.673 |
| 5 | `teste2.txt` | `llama.cpp` | `qwen2.5-coder:7b` | 8k | Ativo | **134,40s (2,2m)** | **33,0 ~ 37,0 t/s** | 3.991 |
| 6 | `teste_ollama_qwen_noweb.txt` | `Ollama` | `qwen2.5-coder:7b` | 8k | Offline | **157,23s (2,6m)** | **31,7 ~ 32,4 t/s** | 4.939 |
| 7 | `teste_ollama_qwen_web.txt` | `Ollama` | `qwen2.5-coder:7b` | 8k | Ativo | **189,91s (3,2m)** | **31,2 ~ 32,5 t/s** | 5.226 |
| 8 | `teste_ollama_ctx16k_qwen.txt` | `Ollama` | `qwen2.5-coder:7b` | 16k | Ativo | **215,89s (3,6m)** | **26,3 ~ 35,7 t/s** | 5.046 |
| 9 | `teste_ollama_ctx32k_qwen.txt` | `Ollama` | `qwen2.5-coder:7b` | 32k | Ativo | **300,60s (5,0m)** | **17,7 ~ 19,4 t/s** | 5.119 |
| 10 | `teste_router_deepseek.txt` | `llama.cpp` | `deepseek-r1:7b` | 8k | Ativo | **266,09s (4,4m)** | **18,2 ~ 26,1 t/s** | 6.016 |
| 11 | `teste_ollama_deepseek_web.txt` | `Ollama` | `deepseek-r1:7b` | 8k | Ativo | **297,72s (5,0m)** | **31,0 ~ 32,7 t/s** | 8.710 |
| 12 | `teste_ollama_deepseek_noweb.txt` | `Ollama` | `deepseek-r1:7b` | 8k | Offline | **398,63s (6,6m)** | **30,8 ~ 39,0 t/s** | 12.457 ⚠️ |

---

## 4. Comparativo de Engenharia: `llama.cpp` vs `Ollama`

### 4.1. Curva de Degradação de Desempenho por Janela de Contexto

```text
TEMPO TOTAL DE EXECUÇÃO (5 ALVOS) EM SEGUNDOS - MENOR É MELHOR

Janela  8k | [llama.cpp] 129s  █████
           | [Ollama]    189s  ███████
           |
Janela 16k | [llama.cpp] 138s  █████▏
           | [Ollama]    215s  ████████▏
           |
Janela 32k | [llama.cpp] 148s  ██████
           | [Ollama]    300s  ████████████  (2x mais lento)
```

### 4.2. Eficiência de Atenção e Throughput
- **`llama.cpp`**: O tempo total cresceu apenas **14,4%** ao quadruplicar a janela de contexto de 8k para 32k (de 129s para 148s). O Flash Attention processa blocos esparsos em SRAM na arquitetura Ada Lovelace sem recalcular toda a matriz densa de atenção.
- **`Ollama`**: O tempo total subiu **58,2%** de 8k para 32k (de 189s para 300s), com a velocidade de geração despencando de ~32 t/s para ~18 t/s devido à alocação de buffers não quantizados.

---

## 5. Avaliação Comparativa dos Modelos: Qwen 2.5 Coder vs. DeepSeek-R1

### 5.1. Qwen 2.5 Coder 7B Instruct (Recomendado para Automação)
- **Perfil Comportamental:** Conciso, pragmático e rigoroso com a sintaxe de scripts.
- **Comandos Gerados:**
  - `chmod 600 /etc/postgresql/16/main/pg_hba.conf`
  - `sed -i '/^host all all 0.0.0.0\/0 md5/c\host all all 127.0.0.1\/32 scram-sha-256' ...`
  - `iptables -A INPUT -s 203.0.113.88 -j DROP`
  - Validação sintática antes do reload: `apache2ctl configtest` e `nginx -t`.
- **Triangulação de CVEs:** Identificou perfeitamente `CVE-2021-41773` (Apache), `CVE-2022-3602` (OpenSSL) e classificou `nginx 1.24.0-2+deb12u1` como **CONFORME** (reconhecendo o modelo de backport do Debian 12 Bookworm).

### 5.2. DeepSeek-R1 7B Distill Qwen (Recomendado para Auditoria Teórica)
- **Perfil Comportamental:** Altamente discursivo, excelente encadeamento de raciocínio (*Chain-of-Thought* via tags `<think>`), forte capacidade de inferência de causalidade.
- **Fragilidades Operacionais (Alucinações Perigosas):**
  - No `llama.cpp` (`teste_router_deepseek.txt`): Sugeriu executar `sudo fdisk -o raw /mnt/db/` para tentar remediar uma falha de autenticação do PostgreSQL.
  - No `Ollama` (`teste_ollama_deepseek_web.txt`): Sugeriu criar scripts que escrevem em `/proc/6000+t` e rodar `gcore` em loop contínuo num `while`.
  - **Volume Excessivo:** No teste sem web, gerou 12.457 tokens, estourando o teto de 3.072 tokens por alvo.

---

## 6. Papel da Metabusca Privada (SearXNG)

1. **Eliminação de Falsos Positivos:** Sem o SearXNG, os modelos 7B tendem a marcar qualquer versão antiga de software como vulnerável. Com a busca web, o agente consultou o banco de vulnerabilidades do Debian e verificou que `+deb12u1` já continha o patch para a falha HTTP/2 Rapid Reset (`CVE-2023-44487`).
2. **Custo Temporal:** A busca adiciona cerca de **15 a 30 segundos** ao turno global (realizando 4 consultas independentes e refinamento de snippets).
3. **Equilíbrio:** Por padrão, a busca deve permanecer ativa (`default=True`), utilizando `--no-web-search` apenas em auditorias de ambientes totalmente isolados (*air-gapped*).

---

## 7. Recomendações de Configuração para a RTX 4050 (6GB VRAM)

Para extrair a máxima performance e confiabilidade operacional neste hardware:

1. **Motor de Inferência:** Utilize o **`llama.cpp` no Modo Router**:
   ```bash
   ./ai-stack/start-stack.sh llamacpp -c 16384
   ```
2. **Janela de Contexto Recomendada:** **16k (`16384`)**. Oferece absorção massiva de logs com overhead mínimo de tempo (apenas 9 segundos a mais que 8k).
3. **Modelo Padrão:** **`qwen2.5-coder:7b`** para execução e remediação automatizada; **`deepseek-r1:7b`** exclusivamente para emissão de laudos discursivos supervisionados.
4. **Comando de Produção:**
   ```bash
   ./specialized-agent/run-agent.sh --backend llamacpp -m qwen2.5-coder:7b -c 16384 -w exemplo-audit -d all | tee laudo_final.txt
   ```
