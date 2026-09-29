#!/usr/bin/env python3
"""
agent.py - Orquestrador Modular do Specialized Agent
Descobre e executa dinamicamente subpastas de trabalho especializadas.
Carrega a SKILL.md de cada pasta, bases de conhecimento locais e runners dedicados,
processando os alvos sequencialmente com aceleração por GPU local (Ollama).
"""

import argparse
import glob
import importlib.util
import json
import os
import re
import smtplib
import ssl
import subprocess
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime
from email.message import EmailMessage

import web_search

# Configuração do Ollama
raw_host = os.environ.get("OLLAMA_HOST", "http://127.0.0.1:11434")
if not raw_host.startswith("http://") and not raw_host.startswith("https://"):
    OLLAMA_HOST = f"http://{raw_host}"
else:
    OLLAMA_HOST = raw_host

MODEL_NAME = os.environ.get("MODEL_NAME", "deepseek-r1:7b")
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# Configuração do llama.cpp (llama-server)
raw_llamacpp = os.environ.get("LLAMACPP_HOST", "http://127.0.0.1:8081")
if not raw_llamacpp.startswith("http://") and not raw_llamacpp.startswith("https://"):
    LLAMACPP_HOST = f"http://{raw_llamacpp}"
else:
    LLAMACPP_HOST = raw_llamacpp


def get_gpu_info():
    """Detecta informações da GPU disponíveis no ambiente."""
    try:
        res = subprocess.run(
            ["nvidia-smi", "--query-gpu=name,memory.total,driver_version", "--format=csv,noheader"],
            capture_output=True,
            text=True,
            timeout=3,
        )
        if res.returncode == 0 and res.stdout.strip():
            return res.stdout.strip()
    except Exception:
        pass
    return "GPU NVIDIA ativa via /dev/nvidia*"


def read_file_safe(path):
    """Lê o conteúdo de um arquivo com tratamento de erro."""
    if path and os.path.isfile(path):
        try:
            with open(path, "r", encoding="utf-8") as f:
                return f.read()
        except Exception as e:
            return f"[Erro ao ler {path}: {e}]"
    return ""


def load_env_file(env_path):
    """Carrega variáveis de ambiente a partir de um arquivo .env se existir."""
    if env_path and os.path.isfile(env_path):
        with open(env_path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    k, v = line.split("=", 1)
                    k = k.strip()
                    v = v.strip().strip("'\"")
                    if k and k not in os.environ:
                        os.environ[k] = v


def find_skill_file(folder_path):
    """Localiza o arquivo SKILL.md principal de uma pasta de trabalho."""
    # 1. Busca direta na raiz da subpasta
    direct = os.path.join(folder_path, "SKILL.md")
    if os.path.isfile(direct):
        return direct

    # 2. Busca recursiva em subpastas skills/
    skills_sub = os.path.join(folder_path, "skills")
    if os.path.isdir(skills_sub):
        candidates = sorted(glob.glob(os.path.join(skills_sub, "**", "SKILL.md"), recursive=True))
        base_name = os.path.basename(folder_path).lower()
        # Primeiro tenta correspondência exata do nome da pasta da skill
        for c in candidates:
            if os.path.basename(os.path.dirname(c)).lower() == base_name:
                return c
        # Depois tenta correspondência no caminho relativo dentro de skills/
        for c in candidates:
            rel = os.path.relpath(c, skills_sub).lower()
            if base_name in rel:
                return c
        if candidates:
            return candidates[0]

    return None


def discover_work_folders(base_dir):
    """Descobre dinamicamente todas as subpastas de trabalho com SKILL.md."""
    ignored = {".git", "__pycache__", "node_modules", ".gemini", ".vscode", "scratch"}
    candidate_roots = [base_dir]
    if os.path.isdir("/app") and "/app" != base_dir:
        candidate_roots.append("/app")

    works = {}
    for c_root in candidate_roots:
        if not os.path.isdir(c_root):
            continue
        for entry in os.listdir(c_root):
            if entry in ignored or entry.startswith("."):
                continue
            full_path = os.path.join(c_root, entry)
            if not os.path.isdir(full_path):
                continue

            skill_path = find_skill_file(full_path)
            if skill_path:
                content = read_file_safe(skill_path)
                desc_match = re.search(r"description:\s*>?-?\s*(.*?)(?:\n\w+:|\n---)", content, re.DOTALL)
                desc = desc_match.group(1).strip().replace("\n", " ") if desc_match else "Trabalho especializado"
                if len(desc) > 85:
                    desc = desc[:82] + "..."

                works[entry] = {
                    "name": entry,
                    "path": full_path,
                    "skill_path": skill_path,
                    "description": desc,
                }

    return works


def load_module_from_file(module_name, file_path):
    """Carrega dinamicamente um arquivo Python como módulo."""
    if not os.path.isfile(file_path):
        return None
    spec = importlib.util.spec_from_file_location(module_name, file_path)
    if not spec or not spec.loader:
        return None
    module = importlib.util.module_from_spec(spec)
    sys.modules[module_name] = module
    spec.loader.exec_module(module)
    return module


def send_email_report(subject, body, to_addrs=None, from_addr=None, smtp_host=None, smtp_port=None, smtp_user=None, smtp_pass=None, use_tls=None, use_ssl=None):
    """
    Envia parecer e relatório consolidado por e-mail via SMTP.
    Utiliza variáveis de ambiente como fallback caso os argumentos não sejam fornecidos.
    """
    to_addrs = to_addrs or os.environ.get("EMAIL_TO", "")
    if not to_addrs:
        print("\033[1;33m[E-mail]\033[0m Nenhum destinatário informado (--email-to ou EMAIL_TO). Disparo cancelado.")
        return False

    from_addr = from_addr or os.environ.get("EMAIL_FROM", "specialized-agent@local.domain")
    host = smtp_host or os.environ.get("SMTP_HOST", "localhost")
    port_str = smtp_port or os.environ.get("SMTP_PORT", "")
    if port_str:
        port = int(port_str)
    else:
        port = 587 if host != "localhost" else 25

    user = smtp_user or os.environ.get("SMTP_USER", "")
    password = smtp_pass or os.environ.get("SMTP_PASSWORD", "")

    if use_ssl is None:
        use_ssl = os.environ.get("SMTP_SSL", "0").lower() in ("1", "true", "yes") or port == 465
    if use_tls is None:
        use_tls = os.environ.get("SMTP_TLS", "1" if port == 587 else "0").lower() in ("1", "true", "yes")

    msg = EmailMessage()
    msg["Subject"] = subject
    msg["From"] = from_addr

    if isinstance(to_addrs, str):
        recipients = [addr.strip() for addr in to_addrs.split(",") if addr.strip()]
    else:
        recipients = list(to_addrs)
    msg["To"] = ", ".join(recipients)
    msg.set_content(body)

    print(f"\033[1;34m[E-mail]\033[0m Conectando a {host}:{port} para envio a {recipients}...")
    try:
        if use_ssl:
            ctx = ssl.create_default_context()
            with smtplib.SMTP_SSL(host, port, context=ctx, timeout=15) as server:
                if user and password:
                    server.login(user, password)
                server.send_message(msg)
        else:
            with smtplib.SMTP(host, port, timeout=15) as server:
                if use_tls:
                    ctx = ssl.create_default_context()
                    server.starttls(context=ctx)
                if user and password:
                    server.login(user, password)
                server.send_message(msg)
        print(f"\033[1;32m[E-mail]\033[0m Relatório enviado com sucesso para: {', '.join(recipients)}")
        return True
    except Exception as e:
        print(f"\033[1;31m[E-mail Erro]\033[0m Falha ao enviar e-mail: {e}", file=sys.stderr)
        return False


def check_ollama_status(model=None):
    """Verifica se o backend Ollama está acessível e se o modelo está pronto."""
    try:
        req = urllib.request.Request(f"{OLLAMA_HOST}/api/tags", method="GET")
        with urllib.request.urlopen(req, timeout=5) as response:
            if response.status == 200:
                data = json.loads(response.read().decode("utf-8"))
                models = [m.get("name", "") for m in data.get("models", [])]
                if model:
                    has_model = any(m == model or m.startswith(f"{model}:") or model.startswith(f"{m}:") for m in models)
                    return True, has_model
                return True, True
    except Exception:
        return False, False
    return False, False


def pull_model_if_missing(model):
    """Solicita o download do modelo via API do Ollama se ainda não estiver presente."""
    is_online, has_model = check_ollama_status(model)
    if not is_online:
        print(f"\033[1;31m[Erro Ollama]\033[0m Backend Ollama em {OLLAMA_HOST} inacessível.", file=sys.stderr)
        print("Certifique-se de que o container 'ollama' está ativo na rede privada (./start-stack.sh).", file=sys.stderr)
        sys.exit(1)
    if not has_model:
        print(f"\033[1;33m[Ollama API]\033[0m Modelo '{model}' não encontrado no Ollama. Efetuando pull via API...")
        try:
            payload = {"model": model, "stream": False}
            req = urllib.request.Request(
                f"{OLLAMA_HOST}/api/pull",
                data=json.dumps(payload).encode("utf-8"),
                headers={"Content-Type": "application/json"},
                method="POST"
            )
            with urllib.request.urlopen(req, timeout=600) as resp:
                print(f"\033[1;32m[Ollama API]\033[0m Download do modelo '{model}' concluído com sucesso.")
        except Exception as e:
            print(f"\033[1;31m[Erro Pull]\033[0m Falha ao obter modelo '{model}': {e}", file=sys.stderr)
            sys.exit(1)


def query_llm(model, system_prompt, user_prompt, num_ctx=8192):
    """Envia requisição para inferência neural no Ollama local com streaming."""
    payload = {
        "model": model,
        "system": system_prompt,
        "prompt": user_prompt,
        "stream": True,
        "options": {
            "temperature": 0.25,
            "repeat_penalty": 1.15,
            "num_predict": 3072,
            "num_ctx": num_ctx,
        },
    }

    req = urllib.request.Request(
        f"{OLLAMA_HOST}/api/generate",
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )

    full_output = []
    final_meta = {}
    try:
        with urllib.request.urlopen(req) as response:
            for line in response:
                if line:
                    data = json.loads(line.decode("utf-8"))
                    chunk = data.get("response", "")
                    sys.stdout.write(chunk)
                    sys.stdout.flush()
                    full_output.append(chunk)
                    if data.get("done"):
                        final_meta = data
        print("\n")
    except urllib.error.URLError as e:
        print(f"\n\033[1;31m[Erro]\033[0m Falha ao se comunicar com o Ollama em {OLLAMA_HOST}: {e}", file=sys.stderr)
        sys.exit(1)

    return "".join(full_output), final_meta


def check_llamacpp_health(host=LLAMACPP_HOST, timeout=5):
    """Verifica se o servidor llama.cpp (llama-server) está ativo e respondendo."""
    try:
        url = f"{host.rstrip('/')}/health"
        req = urllib.request.Request(url, method="GET")
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            if resp.status in (200, 204):
                return True, f"llama-server online em {host}"
    except Exception:
        # Tenta endpoint alternativo de models
        try:
            url = f"{host.rstrip('/')}/v1/models"
            req = urllib.request.Request(url, method="GET")
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                if resp.status == 200:
                    return True, f"llama-server online em {host}"
        except Exception as e:
            return False, f"Falha ao conectar no llama-server em {host}: {e}"
    return False, f"llama-server em {host} inacessível."


def resolve_llamacpp_model(host, requested_model):
    """
    Resolve o identificador de modelo mais compatível disponível no llama-server.
    Permite usar aliases simples (ex: 'qwen2.5-coder:7b' ou 'deepseek-r1:7b')
    mapeando automaticamente para os arquivos .gguf gerenciados pelo Router Mode.
    """
    try:
        url = f"{host.rstrip('/')}/v1/models"
        req = urllib.request.Request(url, method="GET")
        with urllib.request.urlopen(req, timeout=5) as resp:
            if resp.status == 200:
                data = json.loads(resp.read().decode("utf-8"))
                models = [m.get("id") for m in data.get("data", []) if m.get("id")]
                if not models:
                    return requested_model
                # Prioriza modelos locais da pasta models (sem '/' ou ':') sobre cache de download
                models.sort(key=lambda x: (1 if "/" in x else 0))
                if requested_model in models:
                    return requested_model
                req_lower = requested_model.lower().replace(".gguf", "")
                for m in models:
                    m_clean = m.lower().replace(".gguf", "")
                    if m_clean == req_lower or req_lower in m_clean or m_clean in req_lower:
                        return m
                req_terms = set(re.split(r"[-_:\s/.]+", req_lower)) - {"", "latest", "instruct", "chat"}
                best_match = None
                best_score = 0
                for m in models:
                    m_terms = set(re.split(r"[-_:\s/.]+", m.lower().replace(".gguf", "")))
                    score = len(req_terms.intersection(m_terms))
                    if score > best_score:
                        best_score = score
                        best_match = m
                if best_match and best_score > 0:
                    return best_match
                if len(models) == 1:
                    return models[0]
    except Exception:
        pass
    return requested_model


def query_llamacpp(host, model, system_prompt, user_prompt, num_ctx=8192):
    """Envia requisição para inferência neural no llama-server via API OpenAI compatível."""
    active_model = resolve_llamacpp_model(host, model)
    payload = {
        "model": active_model,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ],
        "stream": True,
        "temperature": 0.25,
        "max_tokens": 2048,
        "presence_penalty": 0.1,
        "frequency_penalty": 0.1,
        "repeat_penalty": 1.15,
    }

    endpoint = f"{host.rstrip('/')}/v1/chat/completions"
    req = urllib.request.Request(
        endpoint,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )

    full_output = []
    total_eval_tokens = 0
    start_eval = time.perf_counter()

    try:
        with urllib.request.urlopen(req) as response:
            for raw_line in response:
                line = raw_line.decode("utf-8").strip()
                if not line or not line.startswith("data:"):
                    continue
                data_str = line[5:].strip()
                if data_str == "[DONE]":
                    break
                try:
                    data = json.loads(data_str)
                    choices = data.get("choices", [])
                    if choices:
                        delta = choices[0].get("delta", {})
                        chunk = delta.get("content", "")
                        if chunk:
                            sys.stdout.write(chunk)
                            sys.stdout.flush()
                            full_output.append(chunk)
                            total_eval_tokens += 1
                except json.JSONDecodeError:
                    continue
        print("\n")
    except urllib.error.URLError as e:
        print(f"\n\033[1;31m[Erro llama.cpp]\033[0m Falha ao se comunicar com llama-server em {host}: {e}", file=sys.stderr)
        sys.exit(1)

    eval_duration_ns = int((time.perf_counter() - start_eval) * 1e9)
    meta = {
        "prompt_eval_count": max(1, int(len(system_prompt + user_prompt) / 4)),
        "prompt_eval_duration": 1,
        "eval_count": total_eval_tokens,
        "eval_duration": eval_duration_ns,
    }
    return "".join(full_output), meta


def main():
    parser = argparse.ArgumentParser(
        description="Specialized Agent - Orquestrador Modular de Trabalhos e Skills",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "-w", "--work",
        default=os.environ.get("AGENT_WORK", ""),
        help="Nome da subpasta de trabalho a executar"
    )
    parser.add_argument(
        "--list-works",
        action="store_true",
        help="Lista as pastas de trabalho disponíveis e encerra"
    )
    parser.add_argument(
        "-d", "--domain",
        default="all",
        help="Domínio ou alvo específico a processar (ou 'all' para todos)"
    )
    parser.add_argument(
        "-t", "--timeframe",
        default="now-24h",
        help="Janela temporal de auditoria (ex: now-24h, now-7d)"
    )
    parser.add_argument(
        "-m", "--model",
        default=MODEL_NAME,
        help=f"Modelo LLM no Ollama (padrão: {MODEL_NAME})"
    )
    parser.add_argument(
        "--limit-samples",
        type=int,
        default=4,
        help="Quantidade de amostras detalhadas por alvo"
    )
    parser.add_argument(
        "--max-targets",
        type=int,
        default=15,
        help="Quantidade máxima de alvos a processar no modo 'all'"
    )
    parser.add_argument(
        "-c", "--ctx", "--num-ctx",
        dest="num_ctx",
        type=int,
        default=int(os.environ.get("OLLAMA_NUM_CTX", os.environ.get("LLAMA_CTX_SIZE", "8192"))),
        help="Janela de contexto em tokens (padrão: 8192, suporta 16384 ou 32768)"
    )
    parser.add_argument(
        "--send-email",
        action="store_true",
        default=os.environ.get("SEND_EMAIL", "0").lower() in ("1", "true", "yes"),
        help="Dispara relatório e parecer consolidado por e-mail após a execução"
    )
    parser.add_argument(
        "--email-to",
        default=os.environ.get("EMAIL_TO", ""),
        help="Destinatário(s) do e-mail (separados por vírgula)"
    )
    parser.add_argument(
        "--email-subject",
        default=os.environ.get("EMAIL_SUBJECT", ""),
        help="Assunto personalizado para o e-mail"
    )
    parser.add_argument(
        "--compact-context",
        action="store_true",
        default=True,
        help="Compacta o contexto por alvo mantendo apenas o essencial para a tarefa (padrão: ativo)"
    )
    parser.add_argument(
        "--full-context",
        action="store_true",
        default=False,
        help="Desativa compactação e injeta todas as bases de conhecimento em todos os alvos"
    )
    parser.add_argument(
        "--web-search",
        action="store_true",
        default=os.environ.get("ENABLE_WEB_SEARCH", "1").lower() not in ("0", "false", "no"),
        help="Habilita busca na web via SearXNG para enriquecer o contexto dos alvos (padrão: ativo)"
    )
    parser.add_argument(
        "--no-web-search",
        dest="web_search",
        action="store_false",
        help="Desativa a busca na web via SearXNG"
    )
    parser.add_argument(
        "--searxng-url",
        default=os.environ.get("SEARXNG_URL", "http://127.0.0.1:8080"),
        help="URL da instância isolada do SearXNG (padrão: http://127.0.0.1:8080 ou SEARXNG_URL)"
    )
    parser.add_argument(
        "--search-query",
        default="",
        help="Consulta de busca web específica (se omitida, o alvo gera dinamicamente)"
    )
    parser.add_argument(
        "--max-web-results",
        type=int,
        default=3,
        help="Quantidade máxima de resultados refinados da busca por alvo (padrão: 3)"
    )
    parser.add_argument(
        "--backend",
        choices=["ollama", "llamacpp"],
        default=os.environ.get("LLM_BACKEND", "ollama").lower(),
        help="Motor de inferência neural (ollama ou llamacpp, padrão: ollama)"
    )
    parser.add_argument(
        "--llamacpp-host",
        default=os.environ.get("LLAMACPP_HOST", LLAMACPP_HOST),
        help="Endpoint do llama-server (padrão: http://127.0.0.1:8081 ou LLAMACPP_HOST)"
    )
    args = parser.parse_args()
    if args.full_context:
        args.compact_context = False

    # 1. Descoberta de pastas de trabalho disponíveis
    available_works = discover_work_folders(BASE_DIR)

    if args.list_works:
        print("\n==================================================================")
        print("          TRABALHOS / SKILLS DISPONÍVEIS NO PROJETO               ")
        print("==================================================================")
        if not available_works:
            print("  Nenhuma pasta de trabalho encontrada com SKILL.md.")
            print("  Para adicionar um trabalho, crie uma subpasta com um arquivo SKILL.md.")
        else:
            for k, w in sorted(available_works.items()):
                print(f"  • {k:<22} : {w['description']}")
                print(f"    Pasta: {w['path']}")
                print(f"    Skill: {w['skill_path']}\n")
        print("==================================================================\n")
        sys.exit(0)

    # 2. Seleção e Validação do Trabalho
    selected_name = args.work
    if not selected_name:
        if len(available_works) == 1:
            selected_name = list(available_works.keys())[0]
        elif len(available_works) > 1:
            print("\n\033[1;33m[Aviso]\033[0m Múltiplos trabalhos disponíveis. Especifique com -w <nome>:")
            for k in available_works:
                print(f"  - {k}")
            print()
            sys.exit(1)
        else:
            print("\n\033[1;33m[Aviso]\033[0m Nenhuma subpasta de trabalho encontrada com SKILL.md.")
            print("Para iniciar um trabalho especializado:")
            print("  1. Crie uma subpasta (ex: ./meu-trabalho)")
            print("  2. Adicione o arquivo de diretrizes ./meu-trabalho/SKILL.md")
            print("  3. Execute: ./run.sh -w meu-trabalho\n")
            sys.exit(0)

    if selected_name not in available_works:
        direct_path = os.path.join(BASE_DIR, selected_name)
        if os.path.isdir(direct_path):
            available_works[selected_name] = {
                "name": selected_name,
                "path": direct_path,
                "skill_path": find_skill_file(direct_path) or os.path.join(direct_path, "SKILL.md"),
                "description": f"Pasta de trabalho em {direct_path}"
            }
        else:
            print(f"\033[1;31m[Erro]\033[0m Trabalho '{selected_name}' não encontrado.", file=sys.stderr)
            print(f"Trabalhos disponíveis: {list(available_works.keys())}", file=sys.stderr)
            sys.exit(1)

    work_info = available_works[selected_name]
    work_dir = work_info["path"]
    work_skill_file = work_info["skill_path"]

    # 3. Carregar configurações do trabalho
    load_env_file(os.path.join(work_dir, ".env"))

    # Configurar PATH e sys.path para ferramentas da subpasta
    work_bin = os.path.join(work_dir, "bin")
    work_scripts = os.path.join(work_dir, "scripts")
    if os.path.isdir(work_bin) and work_bin not in os.environ.get("PATH", ""):
        os.environ["PATH"] = f"{work_bin}:{os.environ.get('PATH', '')}"
    if os.path.isdir(work_scripts) and work_scripts not in sys.path:
        sys.path.insert(0, work_scripts)
    if work_dir not in sys.path:
        sys.path.insert(0, work_dir)

    # Se a pasta de trabalho contiver requirements.txt, garante instalação de dependências locais
    work_reqs = os.path.join(work_dir, "requirements.txt")
    if os.path.isfile(work_reqs):
        try:
            print(f"\033[1;34m[Dependências]\033[0m Verificando requisitos de '{work_info['name']}'...")
            subprocess.run(
                [sys.executable, "-m", "pip", "install", "--no-cache-dir", "--break-system-packages", "-r", work_reqs],
                capture_output=True,
                check=False,
            )
        except Exception:
            pass

    # Carregar Skill específica e Bases de Conhecimento
    work_skill_text = read_file_safe(work_skill_file)
    knowledge_docs = []
    knowledge_dir = os.path.join(work_dir, "knowledge")
    if os.path.isdir(knowledge_dir):
        for k_file in sorted(glob.glob(os.path.join(knowledge_dir, "*.md"))):
            knowledge_docs.append(f"--- Documento: {os.path.basename(k_file)} ---\n" + read_file_safe(k_file))

    # Carregar Skills complementares da subpasta (ex: skills/seguranca-agentica)
    skills_dir = os.path.join(work_dir, "skills")
    if os.path.isdir(skills_dir):
        for s_file in sorted(glob.glob(os.path.join(skills_dir, "**", "SKILL.md"), recursive=True)):
            if os.path.abspath(s_file) != os.path.abspath(work_skill_file):
                skill_folder_name = os.path.basename(os.path.dirname(s_file))
                knowledge_docs.append(f"--- Skill Complementar ({skill_folder_name}) ---\n" + read_file_safe(s_file))

    knowledge_combined = "\n\n".join(knowledge_docs)

    # 4. Validar disponibilidade do motor neural selecionado
    if args.backend == "llamacpp":
        llama_ok, llama_msg = check_llamacpp_health(args.llamacpp_host)
        if not llama_ok:
            print(f"\033[1;31m[Erro llama.cpp]\033[0m {llama_msg}", file=sys.stderr)
            print("Certifique-se de que o container 'llamacpp' está ativo na rede privada (./start-stack.sh llamacpp).", file=sys.stderr)
            sys.exit(1)
        print(f"\033[1;32m[Backend llama.cpp]\033[0m Conectado com sucesso em {args.llamacpp_host}")
    else:
        pull_model_if_missing(args.model)

    # 5. Inicialização do Runner do Trabalho
    runner_file = os.path.join(work_dir, "runner.py")
    runner_mod = load_module_from_file(f"work_{work_info['name']}_runner", runner_file)

    global_start_dt = datetime.now()
    global_wall_start = time.perf_counter()
    gpu_info = get_gpu_info()

    print("\033[1;36m==================================================================\033[0m")
    print("\033[1;36m      SPECIALIZED AGENT: EXECUTOR MODULAR DE TRABALHOS            \033[0m")
    print("\033[1;36m==================================================================\033[0m")
    print(f"\033[1;33m[Início Global]\033[0m       {global_start_dt.strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"\033[1;33m[Hardware]\033[0m           GPU: {gpu_info}")
    print(f"\033[1;33m[Modelo]\033[0m             LLM: {args.model}")
    print(f"\033[1;33m[Trabalho Ativo]\033[0m     {work_info['name']} ({work_dir})")
    print(f"\033[1;33m[Skill Especializada]\033[0m{work_skill_file}")
    print(f"\033[1;33m[Janela Temporal]\033[0m    {args.timeframe}")
    print(f"\033[1;33m[Janela Contexto]\033[0m    {args.num_ctx} tokens")

    # Verificar conectividade via runner se disponível
    targets = []
    if runner_mod and hasattr(runner_mod, "check_connection"):
        print("\033[1;32m------------------------------------------------------------------\033[0m")
        print(f"\033[1;34m[Status do Alvo]\033[0m Validando conectividade do trabalho '{work_info['name']}'...")
        conn_ok, conn_info = runner_mod.check_connection()
        if conn_ok:
            print(f"\033[1;32m[Conexão Online]\033[0m Backend conectado com sucesso. Documentos: {conn_info:,}")
        else:
            print(f"\033[1;33m[Aviso de Conexão]\033[0m Backend offline ou inacessível ({conn_info}).")

    # Verificar conectividade com o SearXNG se busca web estiver ativada
    if args.web_search:
        print("\033[1;32m------------------------------------------------------------------\033[0m")
        print(f"\033[1;34m[SearXNG]\033[0m Validando conectividade com o metabuscador em {args.searxng_url}...")
        searx_ok, searx_msg = web_search.check_searxng_health(args.searxng_url)
        if searx_ok:
            print(f"\033[1;32m[Conexão Online]\033[0m {searx_msg}")
        else:
            print(f"\033[1;33m[Aviso de Conexão]\033[0m {searx_msg} (verifique se o container isolado searxng está ativo).")

    if runner_mod and hasattr(runner_mod, "collect_targets"):
        targets = runner_mod.collect_targets(
            timeframe=args.timeframe,
            target_arg=args.domain,
            max_targets=args.max_targets
        )

    if not targets:
        targets = [("default", 0)]

    total_targets = len(targets)
    print("\033[1;32m------------------------------------------------------------------\033[0m")
    print(f"\033[1;36m>>> Iniciando processamento sequencial de {total_targets} alvo(s) para '{work_info['name']}' <<<\033[0m\n")

    system_prompt = (
        f"Você é um Especialista Sênior encarregado da execução do seguinte trabalho: '{work_info['name']}'.\n"
        "Você segue estritamente a especificação e as diretrizes da skill e do conhecimento abaixo:\n\n"
        "=== ESPECIFICAÇÃO TÉCNICA DA SKILL ===\n"
        f"{work_skill_text}\n\n"
        "=== BASES DE CONHECIMENTO E INFRAESTRUTURA ===\n"
        f"{knowledge_combined}\n\n"
        "DIRETRIZES FUNDAMENTAIS:\n"
        "1. Linguagem técnica, concisa e estritamente formal. Sem emojis ou saudações informais.\n"
        "2. Formatação em Markdown estruturado conforme exigido pela especificação da Skill.\n"
        "3. Proteja todas as variáveis, comandos, parâmetros e expressões regulares com crases.\n"
        "4. GOVERNANÇA E CONTROLE (FASE DE TESTES): O agente opera atualmente em regime estrito de testes e validação de maturidade. Nenhuma alteração remota, mutação em infraestrutura ou Merge Request/commit será executado automaticamente nesta fase. Toda ação corretiva proposta deve ser entregue em formato de parecer técnico estruturado para validação humana. ESTA RESTRIÇÃO DE MUTAÇÃO DIRETA SERÁ REMOVIDA ASSIM QUE O PROCESSO SE MOSTRAR TOTALMENTE CONFIÁVEL E ESTÁVEL.\n"
    )

    target_metrics = []
    target_reports = []

    for idx, (target_name, count) in enumerate(targets, 1):
        target_start = time.perf_counter()

        print("\033[1;35m==================================================================\033[0m")
        print(f"\033[1;35m[{idx}/{total_targets}] PROCESSANDO ALVO: {target_name} ({count} eventos)\033[0m")
        print("\033[1;35m==================================================================\033[0m")

        # Obter dossiê do alvo
        if runner_mod and hasattr(runner_mod, "build_target_dossier"):
            dossier_text, total_events, rule_file, app_type = runner_mod.build_target_dossier(
                target_name, timeframe=args.timeframe, sample_limit=args.limit_samples
            )
            if hasattr(runner_mod, "format_user_prompt"):
                user_prompt = runner_mod.format_user_prompt(target_name, app_type, rule_file, dossier_text)
            else:
                user_prompt = f"Analise o seguinte dossiê para o alvo '{target_name}':\n\n```text\n{dossier_text}\n```"
        else:
            user_prompt = f"Realize o diagnóstico do alvo '{target_name}' conforme as diretrizes da sua skill."

        # Enriquecimento contextual via busca web (SearXNG) para o modelo neural
        if args.web_search:
            queries = []
            if args.search_query:
                queries = [args.search_query]
            elif runner_mod and hasattr(runner_mod, "get_target_search_queries"):
                queries = runner_mod.get_target_search_queries(target_name)
            elif runner_mod and hasattr(runner_mod, "get_target_search_query"):
                single_q = runner_mod.get_target_search_query(target_name)
                if single_q:
                    queries = [single_q]
            else:
                queries = [f"{target_name} security hardening best practices"]

            total_q = len(queries)
            collected_web_ctx = []
            total_refined = 0

            for q_idx, q_item in enumerate(queries, 1):
                if isinstance(q_item, (list, tuple)) and len(q_item) == 2:
                    q_label, q_str = q_item
                else:
                    q_label, q_str = f"Consulta {q_idx}", str(q_item)

                prefix = f"[{q_idx}/{total_q}] " if total_q > 1 else ""
                print(f"\033[1;34m[SearXNG]\033[0m {prefix}Consultando: '{q_str}'...")

                per_query_limit = args.max_web_results if total_q == 1 else max(2, min(args.max_web_results, 3))
                refined_items, web_ctx, search_err = web_search.search_and_refine(
                    query=q_str,
                    base_url=args.searxng_url,
                    max_results=per_query_limit,
                    max_snippet_chars=320,
                )
                if search_err:
                    print(f"\033[1;33m[SearXNG Aviso]\033[0m {prefix}{search_err}")
                elif refined_items:
                    total_refined += len(refined_items)
                    print(f"\033[1;32m[SearXNG Sucesso]\033[0m {prefix}{len(refined_items)} evidência(s) refinada(s).")
                    collected_web_ctx.append(f"### Inteligência de Ameaça Web ({q_label})\n{web_ctx}")
                else:
                    print(f"\033[1;33m[SearXNG]\033[0m {prefix}Nenhum resultado relevante retornado.")

            if collected_web_ctx:
                full_web_block = "\n\n".join(collected_web_ctx)
                user_prompt += f"\n\n=== EVIDÊNCIAS EXTERNAS DE THREAT INTELLIGENCE (SEARXNG) ===\n{full_web_block}"

        # Montar system prompt (compacto focado no alvo ou completo geral)
        if args.compact_context and runner_mod and hasattr(runner_mod, "build_system_prompt"):
            target_system_prompt = runner_mod.build_system_prompt(
                target_name, work_skill_text, knowledge_combined
            )
        else:
            target_system_prompt = system_prompt

        backend_label = "llama.cpp" if args.backend == "llamacpp" else "Ollama"
        print(f"\033[1;34m[Raciocínio Neural]\033[0m Submetendo dossiê de '{target_name}' ao {args.model} via {backend_label}...\n")
        if args.backend == "llamacpp":
            report_text, meta = query_llamacpp(args.llamacpp_host, args.model, target_system_prompt, user_prompt, num_ctx=args.num_ctx)
        else:
            report_text, meta = query_llm(args.model, target_system_prompt, user_prompt, num_ctx=args.num_ctx)

        p_tokens = meta.get("prompt_eval_count", 0)
        p_dur_ns = meta.get("prompt_eval_duration", 0)
        e_tokens = meta.get("eval_count", 0)
        e_dur_ns = meta.get("eval_duration", 0)

        # Gancho genérico de avaliação e auto-correção da recomendação em /tmp
        if runner_mod and hasattr(runner_mod, "evaluate_and_refine"):
            def query_refine_fn(prompt):
                if args.backend == "llamacpp":
                    return query_llamacpp(args.llamacpp_host, args.model, target_system_prompt, prompt, num_ctx=args.num_ctx)
                else:
                    return query_llm(args.model, target_system_prompt, prompt, num_ctx=args.num_ctx)

            report_text, extra_metrics = runner_mod.evaluate_and_refine(
                target_name, report_text, query_refine_fn
            )
            for em in extra_metrics:
                p_tokens += em.get("prompt_tokens", 0)
                e_tokens += em.get("eval_tokens", 0)

        target_reports.append((target_name, report_text))

        target_duration = time.perf_counter() - target_start

        # Métricas do turno
        p_speed = (p_tokens / (p_dur_ns / 1e9)) if p_dur_ns > 0 else 0.0
        e_speed = (e_tokens / (e_dur_ns / 1e9)) if e_dur_ns > 0 else 0.0

        target_metrics.append({
            "target": target_name,
            "duration": target_duration,
            "prompt_tokens": p_tokens,
            "eval_tokens": e_tokens,
            "prompt_speed": p_speed,
            "eval_speed": e_speed,
        })

        print(f"\033[1;33m[Telemetria do Alvo]\033[0m Tempo: {target_duration:.2f}s | Prompt: {p_tokens} tok ({p_speed:.1f} t/s) | Geração: {e_tokens} tok ({e_speed:.1f} t/s)\n")

    global_wall_end = time.perf_counter()
    global_end_dt = datetime.now()
    global_total_time = global_wall_end - global_wall_start

    total_prompt_tokens = sum(m["prompt_tokens"] for m in target_metrics)
    total_eval_tokens = sum(m["eval_tokens"] for m in target_metrics)
    total_all_tokens = total_prompt_tokens + total_eval_tokens

    print("\033[1;36m==================================================================\033[0m")
    print(f"\033[1;36m         PAINEL CONSOLIDADO: TRABALHO '{work_info['name'].upper()}'          \033[0m")
    print("\033[1;36m==================================================================\033[0m")
    print(f"\033[1;32mInício da Execução:\033[0m        {global_start_dt.strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"\033[1;32mConclusão da Execução:\033[0m     {global_end_dt.strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"\033[1;32mTempo Total Decorrido:\033[0m     {global_total_time:.2f}s ({global_total_time / 60:.1f} min)")
    print(f"\033[1;32mTrabalho Executado:\033[0m        {work_info['name']}")
    print(f"\033[1;32mModelo Utilizado:\033[0m          {args.model}")
    print(f"\033[1;32mBackend de Inferência:\033[0m     {args.backend.upper()} ({args.llamacpp_host if args.backend == 'llamacpp' else OLLAMA_HOST})")
    print(f"\033[1;32mHardware Ativo:\033[0m            {gpu_info}")
    print(f"\033[1;32mTotal de Alvos Processados:\033[0m{len(target_metrics)} alvo(s)")
    if args.web_search:
        print(f"\033[1;32mBusca Web (SearXNG):\033[0m       Ativa ({args.searxng_url})")
    print("------------------------------------------------------------------")
    print(f"{'Alvo':<32} {'Tempo':<9} {'Prompt':<14} {'Geração':<14} {'Velocidade':<12}")
    print("-" * 81)
    for m in target_metrics:
        print(f"{m['target']:<32} {m['duration']:>6.1f}s   {m['prompt_tokens']:>5} tok      {m['eval_tokens']:>5} tok      {m['eval_speed']:>5.1f} t/s")
    print("------------------------------------------------------------------")
    print(f"\033[1;33mTokens Globais de Entrada:\033[0m  {total_prompt_tokens} tokens")
    print(f"\033[1;33mTokens Globais Gerados:\033[0m    {total_eval_tokens} tokens")
    print(f"\033[1;33mTotal de Tokens no Turno:\033[0m  {total_all_tokens} tokens")
    print(f"\033[1;32m[Agente]\033[0m Execução do trabalho '{work_info['name']}' concluída com sucesso.")

    # 5. Disparo de E-mail com Relatório Consolidado (se configurado)
    if args.send_email or args.email_to:
        print("\n\033[1;34m[E-mail]\033[0m Preparando envio do relatório consolidado...")
        subject = args.email_subject or f"[Specialized Agent] Parecer Técnico: {work_info['name']} ({global_end_dt.strftime('%d/%m/%Y %H:%M')})"
        email_lines = [
            "SPECIALIZED AGENT - RELATÓRIO TÉCNICO CONSOLIDADO",
            "=" * 65,
            f"Trabalho Executado:   {work_info['name']}",
            f"Início:               {global_start_dt.strftime('%Y-%m-%d %H:%M:%S')}",
            f"Conclusão:            {global_end_dt.strftime('%Y-%m-%d %H:%M:%S')}",
            f"Tempo Total:          {global_total_time:.2f}s ({global_total_time / 60:.1f} min)",
            f"Modelo Neural:        {args.model}",
            f"Hardware / GPU:       {gpu_info}",
            f"Janela de Contexto:   {args.num_ctx} tokens",
            f"Alvos Processados:    {len(target_metrics)}",
            f"Tokens Prompt:        {total_prompt_tokens}",
            f"Tokens Geração:       {total_eval_tokens}",
            f"Total de Tokens:      {total_all_tokens}",
            "=" * 65,
            "",
            "RESUMO DA TELEMETRIA POR ALVO:",
            "-" * 65,
        ]
        for m in target_metrics:
            email_lines.append(
                f"• {m['target']:<28} | Tempo: {m['duration']:>5.1f}s | Prompt: {m['prompt_tokens']:>5} tok | Geração: {m['eval_tokens']:>5} tok ({m['eval_speed']:>5.1f} t/s)"
            )
        email_lines.append("-" * 65)
        email_lines.append("")
        email_lines.append("PARECERES TÉCNICOS DETALHADOS POR ALVO:")
        email_lines.append("=" * 65)
        for t_name, rep_txt in target_reports:
            email_lines.append(f"\n[ALVO: {t_name}]\n")
            email_lines.append(rep_txt)
            email_lines.append("\n" + "-" * 65)

        email_body = "\n".join(email_lines)
        send_email_report(subject, email_body, to_addrs=args.email_to)


if __name__ == "__main__":
    main()
