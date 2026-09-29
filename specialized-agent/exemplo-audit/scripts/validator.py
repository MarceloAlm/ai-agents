#!/usr/bin/env python3
"""
validator.py - Validador de Sintaxe e Regras de Segurança para Scripts de Remediação
Utilizado pelo gancho 'evaluate_and_refine' para avaliar se os comandos sugeridos
pelo modelo neural são sintaticamente válidos e respeitam as restrições de governança.
"""

import os
import re
import subprocess
import tempfile


PROHIBITED_PATTERNS = [
    (r"\b(reboot|shutdown|init\s+0|halt|poweroff)\b", "Comando de desligamento/reboot não permitido em ambiente de perícia."),
    (r"rm\s+-rf\s+(/|/\*|/etc|/var|/usr)", "Comando de deleção destrutiva global proibido."),
    (r"mkfs\.", "Formatação de sistema de arquivos não permitida."),
    (r"dd\s+if=/dev/(zero|urandom)\s+of=/dev/", "Sobrescrita de blocos de disco proibida."),
    (r":\(\)\s*\{\s*:\s*\|\s*:\s*&\s*\}\s*;\s*:", "Fork bomb detectada."),
]


def extract_bash_code_blocks(text):
    """Extrai todos os blocos de código markdown delimitados por ```bash ... ```."""
    pattern = r"```(?:bash|sh)\n(.*?)```"
    matches = re.findall(pattern, text, re.DOTALL)
    return matches


def validate_bash_syntax(script_content):
    """
    Salva o conteúdo em arquivo temporário em /tmp e valida com 'bash -n'.
    Retorna (is_valid: bool, error_message: str).
    """
    with tempfile.NamedTemporaryFile(mode="w", suffix=".sh", delete=False) as tmp:
        tmp.write(script_content)
        tmp_path = tmp.name

    try:
        res = subprocess.run(
            ["bash", "-n", tmp_path],
            capture_output=True,
            text=True,
            timeout=5,
        )
        if res.returncode == 0:
            return True, ""
        return False, res.stderr.strip()
    except Exception as e:
        return False, f"Falha ao executar validador bash: {e}"
    finally:
        if os.path.exists(tmp_path):
            os.remove(tmp_path)


def check_security_constraints(script_content, target_name=""):
    """
    Verifica restrições de segurança proibidas e regras específicas por alvo.
    Retorna lista de violações encontradas.
    """
    violations = []
    
    # Checagem de padrões destrutivos globais
    for pattern, msg in PROHIBITED_PATTERNS:
        if re.search(pattern, script_content, re.IGNORECASE):
            violations.append(f"[VIOLAÇÃO DE SEGURANÇA] {msg}")

    # Restrições específicas da Etapa 3 (Forense de Incidente)
    if "etapa3" in target_name.lower():
        # Restrição 1: Não derrubar conexões da VPN da diretoria 10.200.0.0/16
        if re.search(r"iptables.*-s\s+10\.200\..*-j\s+DROP", script_content) or \
           re.search(r"ufw\s+deny.*from\s+10\.200\.", script_content):
            violations.append("[RESTRIÇÃO VIOLADA] Proibido bloquear a sub-rede da VPN médica/diretoria (10.200.0.0/16).")

        # Restrição 2: Não bloquear porta 10250 do kubelet ou DNS interno 10.96.0.10
        if re.search(r"10250.*DROP", script_content) or re.search(r"10\.96\.0\.10.*DROP", script_content):
            violations.append("[RESTRIÇÃO VIOLADA] Proibido bloquear tráfego de infraestrutura interna do cluster (Kubelet 10250 ou CoreDNS 10.96.0.10).")

        # Restrição 3: Não matar processos sem antes capturar artefatos de memória volátil
        if re.search(r"\b(killall|pkill|kill\s+-9)\b", script_content) and not re.search(r"(gcore|memdump|dump|procfs|/proc/\$)", script_content, re.IGNORECASE):
            violations.append("[RESTRIÇÃO FORENSE] Processos suspeitos não podem ser finalizados sem antes registrar cópia de memória volátil (/proc/$PID/ ou dump).")

    return violations


def validate_remediation_snippet(text, target_name=""):
    """
    Função principal que analisa o texto de resposta do modelo.
    Retorna (approved: bool, issues: list[str]).
    """
    code_blocks = extract_bash_code_blocks(text)
    if not code_blocks:
        return True, []  # Sem blocos bash para validar

    all_issues = []
    for idx, block in enumerate(code_blocks, 1):
        # Validação sintática
        syntax_ok, syntax_err = validate_bash_syntax(block)
        if not syntax_ok:
            all_issues.append(f"Bloco Bash #{idx} possui erro sintático: {syntax_err}")

        # Validação de regras e restrições
        constraints = check_security_constraints(block, target_name=target_name)
        all_issues.extend(constraints)

    return len(all_issues) == 0, all_issues


if __name__ == "__main__":
    import sys
    test_code = sys.stdin.read() if not sys.stdin.isatty() else "echo 'Hello World'"
    ok, errors = validate_remediation_snippet(test_code)
    if ok:
        print("Validação sintática e de segurança: APROVADA.")
        sys.exit(0)
    else:
        print("Validação FALHOU:")
        for err in errors:
            print(f" - {err}")
        sys.exit(1)
