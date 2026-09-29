"""
runner.py - Coletor de Fatos, Validador e Orquestrador de Evidências da Especialização 'exemplo-audit'
Implementa os pontos de extensão consumidos pelo agent.py:
  - check_connection()
  - collect_targets()
  - build_target_dossier()
  - format_user_prompt()
  - get_target_search_query()
  - build_system_prompt()
  - evaluate_and_refine()

Organizado em 3 ETAPAS DE TESTE DE MATURIDADE:
  - ETAPA 1 (Atômica): Operações simples com cada componente que modelos 7B realizam com facilidade.
  - ETAPA 2 (Integrada): Uso de todos os recursos de forma coordenada (Dossiê amplo, SearXNG,
                        compact context, validação sintática em sandbox /tmp e refinamento).
  - ETAPA 3 (Estresse / Alta Complexidade): Cenário forense onde modelos 7B costumam falhar
                        (fusos horários heterogêneos, distrator vs ataque real, restrições negativas).
"""

import os
import re
import sys
from datetime import datetime

# Importa o módulo utilitário local de validação
SCRIPTS_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "scripts")
if SCRIPTS_DIR not in sys.path:
    sys.path.insert(0, SCRIPTS_DIR)

try:
    import validator
except ImportError:
    validator = None


def check_connection():
    """Valida a conectividade com o backend de métricas/logs e telemetria."""
    # Simula status de banco de auditoria corporativo
    return True, 18450


def collect_targets(timeframe="now-24h", target_arg="all", max_targets=15):
    """
    Retorna lista de tuplas (nome_alvo, quantidade_eventos) a serem auditados.
    Permite filtrar por etapa ('etapa1', 'etapa2', 'etapa3') ou alvos individuais.
    """
    catalogo = [
        # --- ETAPA 1: Operações simples por componente (7B amigável) ---
        ("etapa1-ssh-audit", 4),
        ("etapa1-db-auth", 4),

        # --- ETAPA 2: Integração total de recursos (Dossiê + SearXNG + Sandbox + Refinamento) ---
        ("etapa2-full-stack", 12),

        # --- ETAPA 3: Alta complexidade / Estresse (Forense, fusos mistos, distratores e restrições) ---
        ("etapa3-forensic-killchain", 18),

        # --- ETAPA 4: Triangulação Multi-Fonte de Threat Intelligence e Validação Web ---
        ("etapa4-multi-cve-threat-intel", 10),
    ]

    # Mapeamento de retrocompatibilidade para nomes legados
    legacy_map = {
        "srv-web-prod01": "etapa1-ssh-audit",
        "srv-auth-identity": "etapa2-full-stack",
        "srv-db-cluster01": "etapa1-db-auth",
    }

    if target_arg and target_arg != "all":
        t_lower = target_arg.lower()
        if t_lower in legacy_map:
            t_lower = legacy_map[t_lower]

        # Filtragem por etapa ou correspondência de nome
        filtrados = [item for item in catalogo if t_lower in item[0].lower()]
        if filtrados:
            return filtrados[:max_targets]
        return [(target_arg, 1)]

    return catalogo[:max_targets]


def build_target_dossier(target, timeframe="now-24h", sample_limit=6):
    """
    Constrói o dossiê detalhado com fatos e evidências de acordo com o nível da etapa.
    Retorna: (dossier_text, total_events, rule_file, app_type)
    """
    agora = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    # =========================================================================
    # ETAPA 1: Componentes Simples / Atômicos
    # =========================================================================
    if target == "etapa1-ssh-audit" or target == "srv-web-prod01":
        app_type = "OpenSSH Server Daemon (sshd)"
        rule_file = "/etc/ssh/sshd_config"
        events = [
            "Linha 32: 'PermitRootLogin yes' ativo sem restrição de rede.",
            "Linha 58: 'PasswordAuthentication yes' permitindo autenticação por senha.",
            "Linha 71: 'MaxAuthTries 10' (baseline exige máximo de 3).",
            "Linha 95: 'X11Forwarding yes' em servidor sem interface gráfica.",
        ]

    elif target == "etapa1-db-auth" or target == "srv-db-cluster01":
        app_type = "PostgreSQL 16 Database Cluster"
        rule_file = "/etc/postgresql/16/main/pg_hba.conf"
        events = [
            "Linha 89: 'host all all 0.0.0.0/0 md5' detectado (algoritmo vulnerável a colisão).",
            "Permissão do arquivo /etc/postgresql/16/main/pg_hba.conf configurada como 0666 (leitura e escrita global).",
            "Porta 5432 exposta publicamente na interface de rede externa sem filtro de firewall.",
            "Parâmetro 'password_encryption' configurado como 'md5' em vez de 'scram-sha-256'.",
        ]

    # =========================================================================
    # ETAPA 2: Integração Total de Recursos
    # =========================================================================
    elif target == "etapa2-full-stack" or target == "srv-auth-identity":
        app_type = "Cluster Integrado Web & IAM (Nginx + Keycloak + UFW)"
        rule_file = "/etc/nginx/sites-available/portal.conf"
        events = [
            "Nginx: Certificado TLS do domínio 'portal.corporativo.internal' expira em 11 dias (risco iminente de blackout).",
            "Nginx: Ausência completa de cabeçalhos de segurança 'Strict-Transport-Security' (HSTS) e 'X-Frame-Options'.",
            "Keycloak: Console administrativo em '/admin' acessível diretamente pela Internet aberta sem restrição de IP de VPN.",
            "Keycloak: Endpoint de tokens (/protocol/openid-connect/token) sem política de rate-limiting (sujeito a credential stuffing).",
            "Firewall UFW: Política padrão de INPUT configurada como 'ALLOW' na interface pública eth0.",
            "Permissões: Chave privada TLS '/etc/ssl/private/portal.key' com permissão 0644 (legível por qualquer usuário local).",
        ]

    # =========================================================================
    # ETAPA 3: Alta Complexidade / Stress Test Forense (Onde 7B costuma falhar)
    # =========================================================================
    elif target == "etapa3-forensic-killchain":
        app_type = "Perícia de Incidente APT / Evasão e Exfiltração de Dados"
        rule_file = "/var/log/audit/incident-evidence.log"
        events = [
            "[LOG WAF - UTC] 2026-09-29T14:15:30Z - IP 198.51.100.4 gerou 2.450 tentativas falhas de SQLi e brute force em /api/login (HTTP 401/403). [DISTRATOR / RUIDO BARULHENTO]",
            "[LOG SYSLOG - HORARIO DE BRASILIA UTC-3] 2026-09-29 11:12:05-03:00 - IP 203.0.113.88 efetuou login SSH bem-sucedido com a chave da conta de serviço 'deploy-svc' (ATENÇÃO: 11:12 UTC-3 corresponde a 14:12 UTC - OCORREU ANTES DO DISTRATOR).",
            "[LOG AUDITD - LINUX] 2026-09-29T14:13:22Z - Usuário 'deploy-svc' executou 'base64 -d' criando binário oculto em /dev/shm/.systemd-sync (PID 28914).",
            "[LOG NETFLOW - UNIX EPOCH] Timestamp 1790691240 (equivale a 2026-09-29T14:14:00Z) - Processo PID 28914 iniciou tráfego com 10.96.0.10:53 (CoreDNS interno).",
            "[LOG DNS QUERY] 2026-09-29T14:14:45Z - 840 consultas DNS do tipo TXT para subdomínios '*.data-pci.darkops-c2.net' com payload codificado em base64 (volume total estimado de 3.2 MB exfiltrados da base de pagamentos).",
            "[RESTRIÇÃO DE NEGÓCIO MANDATÓRIA 1] O servidor hospeda a fila de processamento crítico hospitalar. É ESTRITAMENTE PROIBIDO REINICIAR O SERVIDOR ('reboot', 'shutdown', 'init') ou derrubar conexões da VPN médica (10.200.0.0/16).",
            "[RESTRIÇÃO DE NEGÓCIO MANDATÓRIA 2] É PROIBIDO aplicar regras de firewall que bloqueiem a porta de telemetria do cluster Kubelet (10250) ou o DNS interno (10.96.0.10).",
            "[RESTRIÇÃO FORENSE RFC 3227] É PROIBIDO matar o processo malicioso (PID 28914) sem antes capturar a imagem da memória volátil (/proc/28914/ ou gcore), sob risco de perda irrevogável da chave de decriptação da C2.",
        ]

    # =========================================================================
    # ETAPA 4: Triangulação Multi-Fonte de Threat Intelligence e Validação Web
    # =========================================================================
    elif target == "etapa4-multi-cve-threat-intel":
        app_type = "Servidor Gateway de Borda (Apache + OpenSSL + Redis + Nginx)"
        rule_file = "/etc/security/package-manifest.lock"
        events = [
            "Inventário 1: Apache HTTP Server versão 2.4.49 ativo com 'mod_proxy' habilitado e diretiva '<Directory /> Require all granted </Directory>' exposta.",
            "Inventário 2: Biblioteca OpenSSL versão 3.0.6 em uso no sistema operacional (/usr/lib/x86_64-linux-gnu/libcrypto.so.3).",
            "Inventário 3: Serviço de cache Redis 7.0.4 ativo escutando em 0.0.0.0:6379 com 'protected-mode no' e sem senha configurada ('requirepass').",
            "Inventário 4: Pacote Nginx versão '1.24.0-2+deb12u1' instalado via APT oficial do Debian 12 Bookworm (Alerta de scanner apontando CVE-2023-44487).",
            "Diretriz de Patching: Manter o tempo de indisponibilidade mínimo e aplicar mitigação de configuração imediata antes de compilar ou atualizar pacotes de sistema.",
        ]

    else:
        app_type = "Servidor Linux Genérico"
        rule_file = "/etc/systemd/system.conf"
        events = [
            f"Alvo {target} coletado sob janela {timeframe}.",
            "Nenhuma evidência crítica encontrada nos filtros básicos.",
        ]

    amostra = events[:sample_limit]
    total_events = len(events)

    linhas = [
        f"ALVO SOB PERÍCIA: {target}",
        f"CLASSIFICAÇÃO DE SISTEMA: {app_type}",
        f"ARQUIVO BASE DE DIRETRIZES: {rule_file}",
        f"TOTAL DE APONTAMENTOS LISTADOS: {len(amostra)}",
        f"DATA/HORA DA EXTRAÇÃO DOS FATOS: {agora}",
        "",
        "EVIDÊNCIAS COLETADAS:",
    ]
    for idx, ev in enumerate(amostra, 1):
        linhas.append(f"  {idx}. {ev}")

    return "\n".join(linhas), total_events, rule_file, app_type


def format_user_prompt(target, app_type, rule_file, dossier_text):
    """Monta a requisição para o LLM adaptada ao nível de exigência do alvo."""
    if "etapa1" in target.lower():
        instrucao_adicional = (
            "Esta é uma análise atômica de componente. Seja extremamente direto, aponte a inconformidade "
            "com o baseline de segurança e forneça o bloco ```bash com os comandos exatos de correção. "
            "Atenção: Os fatos da Seção 2 são extraídos do dossiê local. Não atribua fontes de busca web aos fatos locais."
        )
    elif "etapa2" in target.lower():
        instrucao_adicional = (
            "Esta é uma auditoria de arquitetura integrada. Confronte as evidências com as melhores práticas de mercado, "
            "utilize os dados da busca web incorporados para fundamentar seu parecer na Seção 3, aponte a causa raiz dos riscos "
            "e forneça um script bash seguro, com rotina de backup dos arquivos antes da modificação. "
            "Não invente arquivos extras que não constem no dossiê fornecido acima."
        )
    elif "etapa3" in target.lower():
        instrucao_adicional = (
            "ATENÇÃO MÁXIMA - PERÍCIA FORENSE CRÍTICA:\n"
            "1. RECONSTRUA A LINHA DO TEMPO CRONOLÓGICA REAL: Normalize os fusos horários (converta UTC, UTC-3 e Epoch para um referencial único) e demonstre que o distrator WAF ocorreu DEPOIS do comprometimento real da conta.\n"
            "2. IDENTIFIQUE O ATAQUE REAL VS DISTRATOR: Explique por que o IP 198.51.100.4 foi apenas distração e detalhe a exfiltração stealth por DNS feita pelo IP 203.0.113.88.\n"
            "3. RESPEITE RIGOROSAMENTE AS RESTRIÇÕES DE GOVERNANÇA: NUNCA sugira 'reboot', 'shutdown' ou 'kill' prematuro. O plano de remediação deve primeiro preservar a memória do processo (PID 28914), conter o domínio C2 no DNS/Firewall sem afetar o Kubelet 10250, nem a VPN médica 10.200.0.0/16."
        )
    elif "etapa4" in target.lower():
        instrucao_adicional = (
            "ATENÇÃO - TRIANGULAÇÃO MULTI-FONTE DE THREAT INTELLIGENCE (SEARXNG):\n"
            "1. TRIANGULAÇÃO DE CVES: Para cada um dos componentes (Apache 2.4.49, OpenSSL 3.0.6 e Redis 7.0.4), "
            "identifique o código CVE exato, a pontuação CVSS estimada e a versão mínima corrigida utilizando as fontes de busca web fornecidas.\n"
            "2. DETECÇÃO DE FALSO POSITIVO: Avalie criteriosamente o Nginx '1.24.0-2+deb12u1'. Com base no modelo de backport do Debian, "
            "determine se este pacote está vulnerável ao CVE-2023-44487 ou se já possui a correção oficial incorporada pelo Debian Security Team.\n"
            "3. PLANO PRIORIZADO DE REMEDIAÇÃO: Forneça um script ```bash estruturado com as ações prioritárias: mitigação de configuração imediata "
            "(ex.: bind e protected-mode no Redis), seguida pela atualização de pacotes afetados e rotina de backup prévio (.bak)."
        )
    else:
        instrucao_adicional = "Analise as evidências contra os baselines e emita o parecer técnico."

    return (
        f"Conduza a investigação técnica do alvo '{target}' ({app_type}) com base no dossiê de evidências:\n\n"
        f"```text\n{dossier_text}\n```\n\n"
        f"{instrucao_adicional}\n\n"
        f"Estruture seu parecer estritamente conforme as seções exigidas pela Skill."
    )


def get_target_search_queries(target):
    """
    Retorna lista de tuplas (rótulo, consulta) para busca web via SearXNG.
    Permite múltiplas pesquisas para alvos que exigem triangulação de inteligência de ameaças.
    """
    if "etapa4" in target.lower():
        return [
            ("Apache HTTPD RCE", "Apache 2.4.49 mod_proxy path traversal remote code execution CVE-2021-41773 CVE-2021-42013"),
            ("OpenSSL Buffer Overflow", "OpenSSL 3.0.6 buffer overflow vulnerability CVE-2022-3602 fixed version"),
            ("Redis Hardening", "Redis 7.0.4 protected-mode bind remote code execution security advisory"),
            ("Debian Backport Nginx", "Debian package nginx 1.24.0-2+deb12u1 CVE-2023-44487 security patch fixed"),
        ]

    # Para alvos das etapas 1, 2 e 3, retorna a consulta única
    return [("Geral", get_target_search_query(target))]


def get_target_search_query(target):
    """
    Gera consultas otimizadas para grounding via SearXNG para cada tecnologia específica.
    """
    consultas = {
        "etapa1-ssh-audit": "OpenSSH 9 sshd_config security hardening PermitRootLogin PasswordAuthentication best practices",
        "etapa1-db-auth": "PostgreSQL 16 pg_hba.conf host all all md5 vs scram-sha-256 security advisory",
        "etapa2-full-stack": "Nginx reverse proxy Keycloak HSTS TLS certificate expiration rate limit hardening",
        "etapa3-forensic-killchain": "MITRE ATT&CK T1071.004 DNS tunneling exfiltration incident response timeline",
        "etapa4-multi-cve-threat-intel": "Apache 2.4.49 CVE-2021-41773 OpenSSL 3.0.6 CVE-2022-3602 Redis 7.0.4 advisory",
    }
    return consultas.get(target, f"{target} security vulnerability advisory best practices")


def build_system_prompt(target, work_skill_text, knowledge_combined):
    """
    Constrói um system prompt cirúrgico (compact context) selecionando
    apenas o conhecimento necessário para o alvo, preservando tokens de atenção.
    """
    docs_selecionados = []
    knowledge_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "knowledge")

    def ler_doc(nome):
        caminho = os.path.join(knowledge_dir, nome)
        if os.path.isfile(caminho):
            with open(caminho, "r", encoding="utf-8") as f:
                return f"--- Documento: {nome} ---\n" + f.read()
        return ""

    # Injeção direcionada conforme a etapa
    if "etapa1" in target.lower():
        docs_selecionados.append(ler_doc("baseline-seguranca.md"))
    elif "etapa2" in target.lower():
        docs_selecionados.append(ler_doc("baseline-seguranca.md"))
        docs_selecionados.append(ler_doc("norma-pci-dss-firewall.md"))
    elif "etapa3" in target.lower():
        docs_selecionados.append(ler_doc("baseline-seguranca.md"))
        docs_selecionados.append(ler_doc("analise-forense-killchain.md"))
    elif "etapa4" in target.lower():
        docs_selecionados.append(ler_doc("baseline-seguranca.md"))
        docs_selecionados.append(ler_doc("threat-intel-cve-triage.md"))
    else:
        return (
            f"Você é um Auditor Especialista Sênior encarregado do trabalho 'exemplo-audit'.\n\n"
            f"=== SKILL ===\n{work_skill_text}\n\n"
            f"=== CONHECIMENTO ===\n{knowledge_combined}"
        )

    contexto_refinado = "\n\n".join([d for d in docs_selecionados if d])

    return (
        f"Você é um Perito Sênior de Segurança e Auditoria de Sistemas (SRE/SecOps) encarregado da auditoria de: '{target}'.\n"
        f"Você segue estritamente a especificação e as restrições abaixo:\n\n"
        f"=== ESPECIFICAÇÃO DA SKILL ===\n{work_skill_text}\n\n"
        f"=== BASE DE CONHECIMENTO CIRÚRGICA ===\n{contexto_refinado}\n\n"
        "DIRETRIZES FUNDAMENTAIS:\n"
        "1. Linguagem puramente técnica, concisa e estritamente formal. Sem introduções vazias ou emojis.\n"
        "2. Formatação rigorosa em Markdown conforme a estrutura solicitada na Skill.\n"
        "3. Proteja todas as variáveis, caminhos de arquivo e comandos em blocos de código com crases.\n"
        "4. GOVERNANÇA: Nenhuma ação corretiva será executada de imediato; suas propostas serão avaliadas previamente por engenheiros humanos e validadas sintaticamente em sandbox."
    )


def evaluate_and_refine(target, report_text, query_refine_fn):
    """
    Gancho de auto-avaliação e refinamento em sandbox:
    1. Extrai comandos ```bash sugeridos pelo modelo.
    2. Testa sintaxe com 'bash -n' em arquivo temporário em /tmp.
    3. Verifica conformidade com as restrições proibidas (ex.: 'reboot', bloqueio indevido de VPN/Kubelet).
    4. Se houver falha, aciona 'query_refine_fn' para auto-correção pelo modelo LLM.
    """
    if not validator:
        return report_text, []

    approved, issues = validator.validate_remediation_snippet(report_text, target_name=target)
    if approved:
        print(f"\033[1;32m[Sandbox Validação]\033[0m Comandos de remediação para '{target}' validados com sucesso (Sintaxe e Regras OK).")
        return report_text, []

    print(f"\033[1;33m[Sandbox Aviso]\033[0m Foram detectadas inconsistências nas recomendações para '{target}':")
    for issue in issues:
        print(f"  \033[1;31m•\033[0m {issue}")

    # Monta solicitação de refinamento para o modelo
    issues_prompt = "\n".join([f"- {iss}" for iss in issues])
    refine_prompt = (
        f"O seu parecer técnico para o alvo '{target}' apresentou os seguintes apontamentos durante a validação em sandbox:\n\n"
        f"{issues_prompt}\n\n"
        "Por favor, reescreva a seção '4. Recomendações e Propostas de Remediação', corrigindo os erros de sintaxe bash "
        "e removendo/ajustando qualquer comando proibido pelas regras de governança e restrições operacionais. "
        "Entregue apenas o bloco corrigido e o resumo das alterações efetuadas."
    )

    print(f"\033[1;34m[Auto-Refinamento]\033[0m Submetendo apontamentos ao modelo neural para reavaliação...")
    try:
        refined_snippet, meta = query_refine_fn(refine_prompt)
        print(f"\033[1;32m[Auto-Refinamento]\033[0m Correção obtida com sucesso.")

        # Substitui ou anexa a versão refinada
        consolidado = (
            f"{report_text}\n\n"
            f"--- \n"
            f"> [!TIP]\n"
            f"> **Revisão Técnica Pós-Validação em Sandbox (/tmp):**\n"
            f"{refined_snippet}\n"
        )
        extra_metrics = [{
            "prompt_tokens": meta.get("prompt_eval_count", 0),
            "eval_tokens": meta.get("eval_count", 0),
        }]
        return consolidado, extra_metrics
    except Exception as e:
        print(f"\033[1;31m[Erro Refinamento]\033[0m Não foi possível concluir o refinamento automático: {e}")
        return report_text, []
