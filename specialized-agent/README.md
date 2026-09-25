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
├── Dockerfile                 # Imagem container com suporte modular
├── build.sh                   # Script de compilação da imagem
├── run.sh                     # Script de execução com montagem de volume
├── README.md                  # Este guia
│
└── <pasta-de-trabalho>/       # Subpasta especializada (ex.: analise-waf, syslog-audit, db-audit)
    ├── SKILL.md (ou skills/)  # Diretrizes técnicas da especialização
    ├── knowledge/             # Documentações e bases de conhecimento de suporte (*.md)
    ├── .env                   # (Opcional) Credenciais e parâmetros de ambiente
    ├── runner.py              # (Opcional) Coletor de dados, estatísticas e dossiês
    ├── scripts/               # (Opcional) Ferramentas e scripts auxiliares
    └── bin/                   # (Opcional) Executáveis locais
```

---

## 2. Como Funciona

1. **Descoberta Dinâmica:** O `agent.py` escaneia o diretório e descobre automaticamente todas as subpastas que possuem um `SKILL.md`.
2. **Carga Contextual:** Ao selecionar um trabalho, o orquestrador carrega o `SKILL.md` especializado, as bases de conhecimento em `knowledge/*.md`, as variáveis do `.env` e adiciona `bin/` e `scripts/` ao `PATH`.
3. **Coleta de Fatos (Runner):** Se houver um `runner.py` na subpasta, o agente valida conectividade, descobre alvos e extrai evidências em tempo real.
4. **Inferência Local Acelerada:** Os dados consolidados são submetidos ao modelo neural no Ollama local (ex.: `deepseek-r1:7b`, `qwen2.5-coder:7b`) com streaming direto no terminal.
5. **Governança:** Nenhuma alteração remota é aplicada automaticamente; o agente entrega um parecer estruturado pronto para validação humana.

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

### 3.5. Salvar Log Consolidado (Benchmark)
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
