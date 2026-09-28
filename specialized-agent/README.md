# Specialized Agent: Orquestrador Modular de Agentes e Skills

Container de **agente de IA autônomo e modular** executando sobre um motor de inferência local (**Ollama**) acelerado por **GPU NVIDIA** (via CUDA/CDI).

O projeto adota uma **arquitetura totalmente desacoplada e extensível**:
- **Skill Principal** (`SKILL.md`) e **Orquestrador Central** (`agent.py`) coordenam o ciclo de vida, a telemetria, o gerenciamento de modelos e a inferência;
- Novas especializações operacionais são adicionadas criando **subpastas de trabalho** que encapsulam suas próprias diretrizes (`SKILL.md`), bases de conhecimento (`knowledge/`), utilitários (`scripts/`, `bin/`) e coletores de dados (`runner.py`).

---

## 1. Arquitetura do Projeto

```text
specialized-agent/
├── SKILL.md                   # Skill Principal (Meta-Skill e governança central)
├── agent.py                   # Orquestrador central: descobre subpastas e executa inferência
├── entrypoint.sh              # Gestão do ciclo de vida: Ollama background, pull de modelo e shutdown limpo
├── Dockerfile                 # Imagem container com suporte modular (Python + Pip)
├── build.sh                   # Script de compilação da imagem
├── run.sh                     # Script de execução com montagem de volume e GPU
├── README.md                  # Este guia
│
├── exemplo-audit/             # Especialização de referência e template pronto
│   ├── SKILL.md               # Diretrizes de auditoria e conformidade técnica
│   ├── knowledge/             # Base de conhecimento (*.md)
│   ├── runner.py              # Coletor de evidências e formatador de prompt
│   ├── requirements.txt       # (Opcional) Dependências locais
│   └── .env.example           # Exemplo de variáveis e credenciais SMTP
│
└── <pasta-de-trabalho>/       # Novas especializações criadas por você
    ├── SKILL.md (ou skills/)  # Diretrizes técnicas da especialização
    ├── knowledge/             # Documentações e bases de conhecimento de suporte (*.md)
    ├── .env                   # (Opcional) Credenciais e parâmetros de ambiente
    ├── requirements.txt       # (Opcional) Dependências Python da especialização
    ├── runner.py              # (Opcional) Coletor de dados, estatísticas e dossiês
    ├── scripts/               # (Opcional) Ferramentas e scripts auxiliares
    └── bin/                   # (Opcional) Executáveis locais
```

---

## 2. Como Funciona

1. **Descoberta Dinâmica:** O `agent.py` escaneia o diretório e descobre automaticamente todas as subpastas que possuem um `SKILL.md`.
2. **Carga Contextual:** Ao selecionar um trabalho, o orquestrador carrega o `SKILL.md` especializado, as bases de conhecimento em `knowledge/*.md`, as variáveis do `.env`, instala eventuais pacotes em `requirements.txt` e adiciona `bin/` e `scripts/` ao `PATH`.
3. **Coleta de Fatos (Runner):** Se houver um `runner.py` na subpasta, o agente valida conectividade, descobre alvos e extrai evidências em tempo real.
4. **Inferência Local Acelerada:** Os dados consolidados são submetidos ao modelo neural no Ollama local (ex.: `deepseek-r1:7b`, `qwen2.5-coder:7b`) com streaming no terminal e controle de janela de contexto (`--num-ctx`).
5. **Governança Estrita (Fase de Testes):** Por se tratarem de **testes de maturidade e confiabilidade** com esses agentes autônomos, **nenhuma alteração remota ou mutação em ambientes de produção é aplicada automaticamente nesta fase**; o parecer técnico é entregue para validação humana prévia. **Essa restrição será removida assim que o processo se mostrar comprovadamente confiável.**
6. **Notificação por E-mail:** Envia o parecer consolidado e as métricas diretamente para os times de sustentação/SRE via SMTP.

---

## 3. Como Executar

### 3.1. Compilar a Imagem
```bash
./build.sh
```

### 3.2. Listar Trabalhos Disponíveis
```bash
./run.sh --list-works
```

### 3.3. Executar um Trabalho Específico
```bash
# Executa o trabalho com o modelo padrão (deepseek-r1:7b):
./run.sh -w meu-trabalho

# Ou definindo o modelo no primeiro argumento:
./run.sh qwen2.5-coder:7b -w meu-trabalho
```

### 3.4. Filtrar Alvo ou Janela Temporal
```bash
# Processar apenas um alvo específico:
./run.sh deepseek-r1:7b -w meu-trabalho -d alvo-especifico

# Ajustar janela temporal de coleta:
./run.sh deepseek-r1:7b -w meu-trabalho -t now-7d
```

### 3.5. Ajustar Janela de Contexto (Tokens)
```bash
# Aumentar contexto para 16384 tokens para dossiês volumosos:
./run.sh deepseek-r1:7b -w meu-trabalho --num-ctx 16384
```

### 3.6. Envio de Parecer por E-mail (SMTP)
```bash
# Disparar relatório consolidado diretamente para destinatários:
./run.sh deepseek-r1:7b -w meu-trabalho --send-email --email-to "sre@empresa.com,secops@empresa.com"
```

As configurações de servidor SMTP podem ser passadas via `.env` na subpasta ou no ambiente:
```ini
SMTP_HOST=smtp.exemplo.com
SMTP_PORT=587
SMTP_USER=usuario@exemplo.com
SMTP_PASSWORD=segredo
SMTP_TLS=1
EMAIL_FROM=specialized-agent@empresa.com
EMAIL_TO=sre@empresa.com
```

### 3.7. Salvar Log Consolidado (Benchmark)
```bash
./run.sh deepseek-r1:7b -w meu-trabalho | tee resultado_deepseek-r1-7b.txt
```

---

## 4. Como Adicionar uma Nova Especialização

Para adicionar uma nova frente de trabalho, basta criar uma pasta com um `SKILL.md`:

1. **Crie a pasta:**
   ```bash
   mkdir -p specialized-agent/minha-especializacao
   ```

2. **Crie o arquivo de Skill (`minha-especializacao/SKILL.md`):**
   ```markdown
   ---
   name: minha-especializacao
   description: Perito em análise e diagnóstico de logs
   version: 1.0.0
   ---
   # Diretrizes Técnicas
   ...
   ```

3. **(Opcional) Crie o coletor (`minha-especializacao/runner.py`):**
   ```python
   def check_connection():
       return True, "Conectado"

   def collect_targets(timeframe="now-24h", target_arg="all", max_targets=15):
       return [("servidor-01", 10), ("servidor-02", 5)]

   def build_target_dossier(target, timeframe="now-24h", sample_limit=4):
       return f"Dossiê de {target}...", 10, "rules.conf", "Servidor Web"
   ```

4. **Execute:**
   ```bash
   ./run.sh -w minha-especializacao
   ```

---

## 5. Calibração da Especialização Conforme o Modelo Adotado

O `specialized-agent` é uma arquitetura **100% genérica e agnóstica**, atuando estritamente como motor de orquestração e execução. Por essa razão, **o conteúdo de cada especialização (skills, bases de conhecimento e coletores de evidências) precisa ser refinado e calibrado de acordo com a capacidade do modelo de linguagem adotado**:

- **Modelos de Fronteira (Claude 3.5 Sonnet, GPT-4o):**
  - Possuem altíssima fidelidade de seguimento de instruções sob contextos extensos (4.000+ tokens).
  - Conseguem processar manuais enciclopédicos, múltiplas bases de conhecimento e seguir dezenas de restrições implícitas de segurança simultaneamente.

- **Modelos Locais Menores (7B / 8B - ex.: `deepseek-r1:7b`, `qwen2.5-coder:7b`):**
  - Possuem orçamento de atenção mais restrito e sofrem com diluição contextual (*Lost in the Middle*) se alimentados com documentações muito densas.
  - Têm viés de complacência (tentar liberar acessos indevidos como `.env` para "resolver" o erro 403).
  - **Refinamento recomendado:** Compactar o contexto via `runner.py`, fornecer templates de sintaxe explícitos e definir regras mandatórias claras de ataque vs. falso positivo.

- **Modelos Locais Intermediários (14B / 32B - ex.: `qwen2.5-coder:14b`, `deepseek-r1:14b`):**
  - Oferecem o equilíbrio ideal para execução local com GPU dedicada (RTX 4050/3060+).
  - Retêm alta capacidade de raciocínio de segurança, compreendem regras complexas com menor necessidade de simplificação e mantêm sintaxe rigorosa.

> [!TIP]
> Ao criar ou portar um projeto/skill testado previamente em modelos de nuvem para o `specialized-agent`, valide e refine os prompts no `runner.py` especificamente para o modelo local que será executado na infraestrutura.

