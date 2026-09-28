"""
runner.py - Coletor de Fatos e Evidências para a especialização 'exemplo-audit'
Implementa os pontos de extensão consumidos pelo agent.py:
  - check_connection()
  - collect_targets()
  - build_target_dossier()
  - format_user_prompt()
"""

import os
from datetime import datetime


def check_connection():
    """Valida a conectividade com o backend de métricas/logs."""
    # Exemplo: checagem de API ou banco local
    return True, 12500  # Conexão ok, 12500 documentos disponíveis


def collect_targets(timeframe="now-24h", target_arg="all", max_targets=15):
    """
    Retorna lista de tuplas (nome_alvo, quantidade_eventos) a serem auditados.
    """
    catalogo = [
        ("srv-web-prod01", 14),
        ("srv-auth-identity", 8),
        ("srv-db-cluster01", 22),
    ]

    if target_arg and target_arg != "all":
        filtrados = [item for item in catalogo if target_arg.lower() in item[0].lower()]
        return filtrados or [(target_arg, 1)]

    return catalogo[:max_targets]


def build_target_dossier(target, timeframe="now-24h", sample_limit=4):
    """
    Constrói o dossiê com fatos e evidências do alvo especificado.
    Retorna:
      (dossier_text, total_events, rule_file, app_type)
    """
    fatos = {
        "srv-web-prod01": {
            "app_type": "Nginx Reverse Proxy / Web Application",
            "rule_file": "/etc/ssh/sshd_config",
            "events": [
                "SSH: PermitRootLogin configurado como 'yes' em /etc/ssh/sshd_config.",
                "SSH: PasswordAuthentication habilitado ('yes') com 12 tentativas de login com falha para 'root'.",
                "Firewall: Porta 80 e 443 expostas abertas para a Internet (0.0.0.0/0).",
                "Certificado TLS expira em 18 dias.",
            ],
        },
        "srv-auth-identity": {
            "app_type": "Keycloak / OAuth2 Identity Provider",
            "rule_file": "/etc/security/limits.conf",
            "events": [
                "SSH: Autenticação exclusiva por chaves públicas (Ed25519).",
                "Firewall: Porta 22 restrita aos IPs da VPN de operação.",
                "Log: 3 falhas de autenticação de usuário administrativo em 5 minutos.",
            ],
        },
        "srv-db-cluster01": {
            "app_type": "PostgreSQL 16 High-Availability Node",
            "rule_file": "/etc/postgresql/16/main/pg_hba.conf",
            "events": [
                "pg_hba.conf: Permissão 'host all all 0.0.0.0/0 md5' detectada.",
                "Disco /var/lib/postgresql com 82% de ocupação.",
                "Permissões de /etc/shadow em 640 (root:shadow).",
            ],
        },
    }

    dados_alvo = fatos.get(target, {
        "app_type": "Servidor Genérico Linux",
        "rule_file": "/etc/sysctl.conf",
        "events": [
            f"Alvo {target} coletado sob a janela {timeframe}.",
            "Nenhuma inconsistência crítica pré-mapeada no catálogo de exemplo.",
        ],
    })

    eventos = dados_alvo["events"][:sample_limit]
    total_events = len(dados_alvo["events"])

    dossier_lines = [
        f"Alvo: {target}",
        f"Tipo de Aplicação: {dados_alvo['app_type']}",
        f"Arquivo de Configuração sob Auditoria: {dados_alvo['rule_file']}",
        f"Janela de Análise: {timeframe}",
        f"Timestamp da Coleta: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
        "",
        "EVIDÊNCIAS COLETADAS:",
    ]
    for idx, ev in enumerate(eventos, 1):
        dossier_lines.append(f"  {idx}. {ev}")

    return "\n".join(dossier_lines), total_events, dados_alvo["rule_file"], dados_alvo["app_type"]


def format_user_prompt(target, app_type, rule_file, dossier_text):
    """Monta a requisição formatada para o modelo LLM."""
    return (
        f"Conduza a auditoria do alvo '{target}' ({app_type}) com base no dossiê de evidências:\n\n"
        f"```text\n{dossier_text}\n```\n\n"
        f"Confronte os achados com o baseline de segurança e emita o parecer técnico estruturado."
    )
