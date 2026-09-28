---
name: specialized-agent-core
description: >-
  Meta-Agente Autônomo Modular para execução de trabalhos operacionais e perícias técnicas
  (SRE, Cibersegurança, Análise Forense de Logs e Auditoria). Descobre e carrega dinamicamente
  subpastas de trabalho especializadas, assimilando a SKILL.md de cada pasta, bases de conhecimento,
  ferramentas locais e coletores dedicados (runner.py). Conduz investigações aceleradas por GPU local (Ollama)
  e gera pareceres estruturados para validação humana.
version: 2.2.0
---

# Skill Principal: Meta-Agente Especializado Modular

Esta skill define o protocolo central de orquestração, descoberta e governança do **Specialized Agent**. O agente atua como um executor modular e desacoplado, descobrindo e delegando regras operacionais para subpastas de trabalho estruturadas dentro do projeto.

---

## 1. Padrão Estrutural de Pastas de Trabalho

O orquestrador identifica e assimila qualquer subpasta que siga a seguinte estrutura padronizada:

```text
specialized-agent/
├── SKILL.md                   # Esta Skill Principal (Meta-Skill e governança central)
├── agent.py                   # Orquestrador modular (descoberta dinâmica e inferência)
├── entrypoint.sh              # Gestão do ciclo de vida: Ollama background, pull e shutdown limpo
├── Dockerfile                 # Imagem container com suporte modular
├── build.sh                   # Script de compilação da imagem
├── run.sh                     # Script de execução com montagem de volume
├── README.md                  # Documentação completa da arquitetura
│
└── <pasta-de-trabalho>/       # Subpasta especializada (ex.: analise-waf, syslog-audit, db-health)
    ├── SKILL.md (ou skills/)  # Diretrizes técnicas da especialização
    ├── knowledge/             # Documentações e bases de conhecimento de suporte (*.md)
    ├── .env                   # (Opcional) Credenciais e parâmetros de ambiente
    ├── requirements.txt       # (Opcional) Dependências Python específicas do trabalho
    ├── runner.py              # (Opcional) Coletor de fatos, conectividade e dossiês de auditoria
    ├── scripts/               # (Opcional) Utilitários e scripts CLI
    └── bin/                   # (Opcional) Binários e atalhos executáveis
```

---

## 2. Ciclo de Vida da Execução

1. **Descoberta do Trabalho Ativo:**
   - O orquestrador escaneia o diretório raiz e identifica subpastas que possuem `SKILL.md` (ou `skills/*/SKILL.md`).
   - Se houver apenas uma pasta de trabalho, ela é selecionada automaticamente.
   - Caso existam múltiplas, o trabalho pode ser selecionado via argumento CLI (`-w, --work <nome>`).
   - Carrega as variáveis de ambiente do arquivo `.env` da subpasta correspondente, caso exista.

2. **Carga Contextual Rigorosa:**
   - Carrega a especificação da `SKILL.md` da subpasta selecionada.
   - Carrega todas as bases de conhecimento disponíveis em `knowledge/*.md`.
   - Adiciona os diretórios `bin/` e `scripts/` da pasta ao `PATH` e `sys.path`.

3. **Coleta de Fatos e Evidências:**
   - Executa o módulo `runner.py` da subpasta (se implementado) para extrair fatos reais do ambiente (APIs, logs, bases de dados).
   - Valida conectividade via `check_connection()` e recupera alvos via `collect_targets()`.

4. **Inferência Neural Acelerada por GPU:**
   - Submete os dados consolidados ao modelo local no Ollama com controle de contexto (`num_ctx: 8192` por padrão) e temperatura calibrada (`repeat_penalty: 1.15`).
   - Transmite a saída em streaming direto via `stdout`.

5. **Diretriz de Governança e Não-Intrusividade (Fase de Testes):**
   > [!IMPORTANT]
   > **RESTRIÇÃO OPERACIONAL EM FASE DE TESTES:**
   > Por se tratarem de testes e validação de maturidade com esses agentes autônomos, o agente **NÃO efetua alterações remotas nem abre Merge Requests/commits automaticamente**. Toda proposta de alteração técnica, regra ou correção deve ser apresentada exclusivamente de forma estruturada no parecer para revisão e validação humana.
   > **Esta restrição de não-mutação direta será removida assim que o processo e os pareceres dos agentes se mostrarem plenamente confiáveis e estáveis.**

6. **Telemetria e Observabilidade:**
   - Monitora o tempo decorrido, volume de tokens de entrada e saída e velocidade de geração (tokens/s) por alvo.
   - Exibe o painel consolidado com comparativo de métricas ao término da rodada.

7. **Notificação e Disparo por E-mail:**
   - Permite o envio automático do parecer e do resumo consolidado para equipes de engenharia/SRE via SMTP (`--send-email`, `--email-to` ou variáveis `EMAIL_TO`, `SMTP_HOST`).

---

## 3. Como Criar uma Nova Especialização

Para adicionar uma nova capacidade ao agente:

1. Crie a subpasta:
   ```bash
   mkdir -p specialized-agent/meu-trabalho
   ```

2. Crie o arquivo `meu-trabalho/SKILL.md` contendo:
   - A persona e especialização técnica;
   - Os critérios de análise e classificação;
   - O formato esperado de resposta.

3. (Opcional) Adicione `meu-trabalho/runner.py` implementando:
   - `check_connection()`: checagem de backend/serviço;
   - `collect_targets()`: listagem de alvos a auditar;
   - `build_target_dossier()`: extração de dados e evidências do alvo;
   - `format_user_prompt()`: personalização do prompt.

4. Execute:
   ```bash
   ./run.sh -w meu-trabalho
   ```

---

## 4. Diretriz de Calibração Conforme o Modelo Adotado

Como o `specialized-agent` atua como motor de execução genérico, as regras operacionais, bases de conhecimento e prompts de cada especialização devem ser refinados considerando as capacidades do modelo neural selecionado:

1. **Modelos de Fronteira (Cloud / Alta Capacidade):**
   - Toleram bases de conhecimento densas e documentos múltiplos sem perda de foco.
2. **Modelos Locais Menores (7B/8B):**
   - Exigem compactação de contexto por alvo (via `build_system_prompt` no `runner.py`), instruções explícitas de não-complacência (ex.: varreduras de arquivos sensíveis são sempre ataques) e templates de sintaxe diretos.
3. **Modelos Locais Intermediários (14B/32B):**
   - Oferecem raciocínio avançado com execução acelerada por GPU local, reduzindo significativamente a taxa de alucinação e mantendo alta fidelidade às diretrizes originais da Skill.

