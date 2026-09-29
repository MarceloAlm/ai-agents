# Guia de Testes de Maturidade: Exemplo-Audit (Specialized Agent)

Este diretório contém a especialização de referência do **Specialized Agent**, projetada para validar todas as capacidades da arquitetura e avaliar o comportamento de modelos de linguagem (especialmente modelos locais **7B**) em três níveis crescentes de exigência cognitiva.

---

## 1. Visão Geral dos Quatro Níveis de Teste

| Etapa | Alvo(s) | Recursos Testados | Comportamento Esperado do Modelo 7B |
| :--- | :--- | :--- | :--- |
| **Etapa 1: Atômica** | `etapa1-ssh-audit`<br>`etapa1-db-auth` | Dossiê básico, leitura do baseline de segurança, parsing de configuração individual. | **Sucesso Consistente:** Modelos 7B acertam com facilidade, gerando apontamentos precisos e comandos diretos. |
| **Etapa 2: Integrada** | `etapa2-full-stack` | Dossiê multi-serviço (Nginx + Keycloak + UFW), **Grounding com SearXNG**, **Compact Context**, **Validação sintática em Sandbox (/tmp)** com auto-refinamento e **despacho por e-mail**. | **Sucesso Assistido:** O modelo lida bem com múltiplos serviços porque o contexto é filtrado cirurgicamente e a sandbox valida/corrige os comandos propostos. |
| **Etapa 3: Estresse (Complexidade Alta)** | `etapa3-forensic-killchain` | Análise forense avançada (MITRE ATT&CK), normalização de fusos horários misturados, distinção de distrator vs. ameaça real e múltiplas restrições negativas. | **Ponto de Falha Típico de 7B:** Modelos 7B costumam inverter a ordem cronológica, focar no distrator óbvio e violar restrições negativas (como sugerir reboot ou bloquear ranges críticos). |
| **Etapa 4: Threat Intelligence Multi-Fonte** | `etapa4-multi-cve-threat-intel` | **Múltiplas pesquisas web no SearXNG (4 consultas)**, triangulação cruzada de CVEs reais (Apache, OpenSSL, Redis), **detecção de falsos positivos via backport Debian** e plano priorizado de remediação. | **Triangulação Cognitiva:** Exige relacionar 4 blocos de inteligência de ameaças sem se perder, descartando falsos alarmes em pacotes Debian estáveis. |

---

## 2. Pré-requisitos de Execução

Certifique-se de que a infraestrutura compartilhada está ativa na pasta raiz:

```bash
# 1. Entrar na raiz do repositório
cd /workspace

# 2. Iniciar a infraestrutura (exemplo com llama.cpp acelerado por GPU + SearXNG)
cd ai-stack
./start-stack.sh llamacpp
cd ..
```

*(Ou, se preferir o backend Ollama: `./ai-stack/start-stack.sh ollama`)*

---

## 3. Como Executar Cada Etapa

### Etapa 1: Operações Simples por Componente (7B Amigável)

Executa a auditoria isolada de componentes de infraestrutura (OpenSSH e PostgreSQL):

```bash
cd specialized-agent

# Executar todos os alvos da Etapa 1:
./run-agent.sh --backend llamacpp -w exemplo-audit -d etapa1

# Ou executar um alvo específico:
./run-agent.sh --backend llamacpp -w exemplo-audit -d etapa1-ssh-audit
./run-agent.sh --backend llamacpp -w exemplo-audit -d etapa1-db-auth
```

> **O que observar:**
> - Respostas rápidas e concisas.
> - O modelo identifica imediatamente parâmetros como `PermitRootLogin yes` e `md5` sem alucinações.
> - Comandos de remediação simples e sem conflito de dependências.

---

### Etapa 2: Todos os Recursos Integrados (Pipeline Completo)

Executa a auditoria de um cluster integrado com **grounding web ativo via SearXNG** e **validador de sandbox com auto-refinamento**:

```bash
cd specialized-agent

# Executar com busca web e validação em sandbox ativas:
./run-agent.sh --backend llamacpp -w exemplo-audit -d etapa2 --web-search
```

> **Recursos acionados em cadeia:**
> 1. **Dossiê Multicamada:** Coleta evidências simultâneas de Nginx (TLS expira em 11 dias), Keycloak (/admin exposto) e Firewall.
> 2. **Metabusca Privada (SearXNG):** O agente dispara automaticamente uma consulta sobre boas práticas e riscos atuais, incorporando trechos refinados ao prompt.
> 3. **Compact Context:** O orquestrador injeta apenas `baseline-seguranca.md` e `norma-pci-dss-firewall.md`, economizando tokens de atenção.
> 4. **Validação Sandbox (`validator.py` / `bash -n`):** O script intermediário extrai o bloco de comandos gerado pelo modelo, valida sintaticamente em arquivo temporário em `/tmp` e garante rotinas de backup. Caso haja erro, aciona o modelo para auto-correção.
> 5. **(Opcional) Despacho SMTP:** Adicione `--send-email --email-to "seu-email@dominio.com"` para disparar o relatório consolidado.

---

### Etapa 3: Alta Complexidade e Estresse (Onde Modelos 7B Costumam Falhar)

Executa um cenário de perícia forense com **armadilhas cognitivas intencionais** projetadas para testar os limites do modelo:

```bash
cd specialized-agent

# Executar a perícia avançada:
./run-agent.sh --backend llamacpp -w exemplo-audit -d etapa3 --web-search
```

> **Armadilhas Cognitivas e Critérios de Avaliação:**
>
> 1. **Fusos Horários Heterogêneos & Causalidade Reversa:**
>    - O dossiê apresenta logs em **UTC** (`14:15:30Z`), **Horário de Brasília UTC-3** (`11:12:05-03:00`) e **Unix Epoch** (`1790691240` = 14:14:00Z).
>    - *Onde o 7B costuma errar:* Assume a ordem em que os logs aparecem no texto e diz que o ataque no WAF causou a invasão, sem perceber que `11:12 UTC-3` corresponde a `14:12 UTC` e ocorreu **antes** das falhas do WAF.
>
> 2. **Ataque de Distração vs. Infiltração Real (Needle in a Haystack):**
>    - Há um ataque ruidoso e mal-sucedido de força bruta no IP `198.51.100.4` e, simultaneamente, um acesso furtivo com credencial roubada no IP `203.0.113.88` exfiltrando dados via consultas DNS TXT (`data-pci.darkops-c2.net`).
>    - *Onde o 7B costuma errar:* Gasta quase todo o parecer focado no ataque de força bruta do WAF e esquece ou subestima a exfiltração de dados por DNS.
>
> 3. **Restrições Negativas Rígidas (Lost in the Middle):**
>    - O dossiê impõe proibições estritas: não reiniciar servidores (`reboot`/`shutdown`), não bloquear a sub-rede da VPN médica (`10.200.0.0/16`), não bloquear a porta do Kubelet (`10250`) e não matar processos (`kill -9`) sem antes capturar a memória volátil (`/proc/$PID/` ou `gcore`).
>    - *Onde o 7B costuma errar:* Recomenda `systemctl reboot` ou sugere comandos `iptables -P INPUT DROP` sem exceções, ou mata o processo perdendo a chave de criptografia do incidente.

---

### Etapa 4: Threat Intelligence Multi-Fonte e Validação Cruzada Web

Executa a auditoria de um inventário de borda com **4 consultas web simultâneas no SearXNG** e análise de falsos positivos:

```bash
cd specialized-agent

# Executar a Etapa 4 com grounding multi-query:
./run-agent.sh --backend llamacpp -w exemplo-audit -d etapa4 --web-search | tee teste_etapa4.txt
```

> **Desafios Cognitivos e Validações:**
> 1. **Triangulação de Múltiplos CVEs Reais:**
>    - Consulta 1 (Apache 2.4.49): CVE-2021-41773 / CVE-2021-42013 (RCE Crítico por Path Traversal).
>    - Consulta 2 (OpenSSL 3.0.6): CVE-2022-3602 (Buffer Overflow em X.509).
>    - Consulta 3 (Redis 7.0.4): `bind 0.0.0.0` e `protected-mode no` sem autenticação.
> 2. **Detecção de Falso Positivo (Debian Backport):**
>    - O scanner alerta sobre o Nginx 1.24.0, mas o pacote instalado é `1.24.0-2+deb12u1` (Debian Bookworm oficial), que já incorpora a correção do CVE-2023-44487. O modelo deve reconhecer a política de backport e classificar como **CONFORME**.
> 3. **Plano Priorizado de Remediação:**
>    - Mitigação de configuração imediata do Redis antes da atualização dos binários do Apache e OpenSSL via APT com backup prévio (`.bak`).

---

## 4. Matriz de Execução e Comparação de Modelos

> [!NOTE]
> A busca web (**SearXNG**) é **ativa por padrão**. Não é necessário passar a flag `--web-search`.
> Caso deseje realizar o teste em modo totalmente isolado/offline, utilize a flag `--no-web-search`.

---

### 4.1. Testes com Motor `llama.cpp` (Modo Router Ativo)

O servidor `llama.cpp` gerencia múltiplos modelos em `/models` sob demanda (política LRU, `--models-max 1`).

#### Modelo 1: `qwen2.5-coder:7b` (Especialista em Código e Hardening)
```bash
# Com Busca Web SearXNG (Padrão):
./specialized-agent/run-agent.sh --backend llamacpp -m qwen2.5-coder:7b -w exemplo-audit -d all | tee teste_llamacpp_qwen_web.txt

# Modo Offline (Sem Busca Web):
./specialized-agent/run-agent.sh --backend llamacpp -m qwen2.5-coder:7b -w exemplo-audit -d all --no-web-search | tee teste_llamacpp_qwen_noweb.txt
```

#### Modelo 2: `deepseek-r1:7b` (Especialista em Raciocínio Puro / Chain-of-Thought)
```bash
# Com Busca Web SearXNG (Padrão):
./specialized-agent/run-agent.sh --backend llamacpp -m deepseek-r1:7b -w exemplo-audit -d all | tee teste_llamacpp_deepseek_web.txt

# Modo Offline (Sem Busca Web):
./specialized-agent/run-agent.sh --backend llamacpp -m deepseek-r1:7b -w exemplo-audit -d all --no-web-search | tee teste_llamacpp_deepseek_noweb.txt
```

---

### 4.2. Testes com Motor `ollama` (Gestão Automática de Modelos)

O motor Ollama baixa modelos automaticamente via API e gerencia o swap de memória na GPU.

#### Passo 1: Inicializar a infraestrutura com suporte ao Ollama
```bash
# Iniciar o container Ollama (ou ambos via 'all'):
./ai-stack/start-stack.sh ollama

# Ou subir stack unificada (llamacpp + ollama + searxng):
./ai-stack/start-stack.sh all
```

#### Modelo 1: `qwen2.5-coder:7b` no Ollama
```bash
# Com Busca Web SearXNG (Padrão):
./specialized-agent/run-agent.sh --backend ollama -m qwen2.5-coder:7b -w exemplo-audit -d all | tee teste_ollama_qwen_web.txt

# Modo Offline (Sem Busca Web):
./specialized-agent/run-agent.sh --backend ollama -m qwen2.5-coder:7b -w exemplo-audit -d all --no-web-search | tee teste_ollama_qwen_noweb.txt
```

#### Modelo 2: `deepseek-r1:7b` no Ollama
```bash
# Com Busca Web SearXNG (Padrão):
./specialized-agent/run-agent.sh --backend ollama -m deepseek-r1:7b -w exemplo-audit -d all | tee teste_ollama_deepseek_web.txt

# Modo Offline (Sem Busca Web):
./specialized-agent/run-agent.sh --backend ollama -m deepseek-r1:7b -w exemplo-audit -d all --no-web-search | tee teste_ollama_deepseek_noweb.txt
```

#### Modelo 3: `llama3.1:8b` no Ollama (Análise Comparativa Geral)
```bash
# Com Busca Web SearXNG (Padrão):
./specialized-agent/run-agent.sh --backend ollama -m llama3.1:8b -w exemplo-audit -d all | tee teste_ollama_llama3_web.txt

# Modo Offline (Sem Busca Web):
./specialized-agent/run-agent.sh --backend ollama -m llama3.1:8b -w exemplo-audit -d all --no-web-search | tee teste_ollama_llama3_noweb.txt
```

---

## 5. Matriz Comparativa de Resultados Empíricos

Resultados obtidos nos testes recentes em GPU NVIDIA local:

| Teste | Motor | Modelo | Modo Web | Tempo Total | Throughput Médio | Tokens Gerados | Comportamento Principal |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `teste_router_qwen.txt` | `llamacpp` | `qwen2.5-coder:7b` | SearXNG | **129.36s (2.2m)** | **31.3 ~ 32.3 t/s** | 3.858 tok | Comandos Bash cirúrgicos (`chmod 600`, `sed`), auto-refinamento rápido, detecção de backport Debian. |
| `teste_router_deepseek.txt` | `llamacpp` | `deepseek-r1:7b` | SearXNG | **266.09s (4.4m)** | **18.2 ~ 26.1 t/s** | 6.016 tok | Raciocínio discursivo profundo; alucinação em comandos OS (`sudo fdisk` para PostgreSQL); maior verbosidade. |
| `teste3.txt` | `llamacpp` | `qwen2.5-coder:7b` | SearXNG | **158.84s (2.6m)** | **30.1 ~ 39.7 t/s** | 4.673 tok | Validação de sandbox acionada em erro de aspas; self-healing bem-sucedido. |
| `teste2.txt` | `llamacpp` | `qwen2.5-coder:7b` | SearXNG | **134.40s (2.2m)** | **33.0 ~ 37.0 t/s** | 3.991 tok | 4 alvos processados sem loop de repetição. |
