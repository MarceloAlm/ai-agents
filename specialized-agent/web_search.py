#!/usr/bin/env python3
"""
web_search.py - Módulo de Busca Web e Refinamento de Resultados (SearXNG)
Projetado para enriquecer o contexto de LLMs locais (7B), mitigando o context stuffing
e mantendo alta densidade de informação com baixo consumo de tokens.
"""

import html
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from typing import Any, Dict, List, Optional, Tuple

DEFAULT_SEARXNG_URL = os.environ.get("SEARXNG_URL", "http://127.0.0.1:8080")


def clean_text_snippet(raw_html: str, max_chars: int = 400) -> str:
    """
    Remove tags HTML, decodifica entidades e normaliza espaços para manter
    o snippet limpo e conciso para a janela de contexto de modelos 7B.
    """
    if not raw_html:
        return ""
    # Remove tags HTML
    text = re.sub(r"<[^>]+>", " ", raw_html)
    # Decodifica entidades HTML (&amp;, &quot;, etc.)
    text = html.unescape(text)
    # Normaliza espaços múltiplos e quebras de linha
    text = re.sub(r"\s+", " ", text).strip()
    if len(text) > max_chars:
        text = text[:max_chars].rstrip() + "..."
    return text


def check_searxng_health(base_url: str = DEFAULT_SEARXNG_URL, timeout: float = 3.0) -> Tuple[bool, str]:
    """
    Verifica se a instância isolada do SearXNG está acessível e respondendo.
    """
    url = base_url.rstrip("/") + "/healthz"
    try:
        req = urllib.request.Request(
            url,
            headers={"User-Agent": "SpecializedAgent/1.0"},
            method="GET",
        )
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            if resp.status in (200, 204):
                return True, f"SearXNG online em {base_url}"
    except Exception:
        # Tenta fallback para query básica se /healthz não estiver mapeado
        fallback_url = base_url.rstrip("/") + "/search?q=ping&format=json"
        try:
            req = urllib.request.Request(
                fallback_url,
                headers={"User-Agent": "SpecializedAgent/1.0"},
                method="GET",
            )
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                if resp.status == 200:
                    return True, f"SearXNG online em {base_url}"
        except Exception as e:
            return False, f"Falha ao conectar no SearXNG em {base_url}: {e}"

    return False, f"SearXNG em {base_url} respondeu com status inesperado."


def query_searxng(
    query: str,
    base_url: str = DEFAULT_SEARXNG_URL,
    categories: str = "general",
    language: str = "auto",
    time_range: Optional[str] = None,
    timeout: float = 10.0,
) -> Dict[str, Any]:
    """
    Executa consulta à API JSON do SearXNG.
    Retorna o payload bruto decodificado em dicionário.
    """
    params = {
        "q": query,
        "format": "json",
        "categories": categories,
    }
    if language and language != "auto":
        params["language"] = language
    if time_range:
        params["time_range"] = time_range

    query_str = urllib.parse.urlencode(params)
    endpoint = f"{base_url.rstrip('/')}/search?{query_str}"

    req = urllib.request.Request(
        endpoint,
        headers={
            "User-Agent": "SpecializedAgent/1.0 (Local-LLM-Researcher)",
            "Accept": "application/json",
        },
        method="GET",
    )

    try:
        with urllib.request.urlopen(req, timeout=timeout) as response:
            if response.status != 200:
                return {"error": f"HTTP status {response.status}", "results": []}
            data = json.loads(response.read().decode("utf-8"))
            return data
    except urllib.error.URLError as e:
        return {"error": f"Erro de conexão com SearXNG ({endpoint}): {e}", "results": []}
    except json.JSONDecodeError as e:
        return {"error": f"Resposta inválida da API do SearXNG (não-JSON): {e}", "results": []}
    except Exception as e:
        return {"error": f"Erro inesperado na busca: {e}", "results": []}


def refine_results(
    raw_response: Dict[str, Any],
    max_results: int = 3,
    max_snippet_chars: int = 400,
) -> List[Dict[str, str]]:
    """
    Refina os resultados brutos da busca para uso otimizado por LLMs 7B:
    1. Remove duplicatas de URL;
    2. Descarta resultados sem título ou sem conteúdo;
    3. Higieniza e encurta snippets para evitar context stuffing;
    4. Seleciona apenas os top N mais relevantes.
    """
    results = raw_response.get("results", [])
    if not results:
        return []

    seen_urls = set()
    refined = []

    for item in results:
        url = item.get("url", "").strip()
        title = item.get("title", "").strip()
        content = item.get("content", "") or item.get("snippet", "") or ""
        engine = item.get("engine", "web")

        if not url or url in seen_urls:
            continue
        if not title:
            continue

        clean_snippet = clean_text_snippet(content, max_chars=max_snippet_chars)
        clean_title = clean_text_snippet(title, max_chars=120)

        # Se não há snippet útil, pula a menos que seja link oficial relevante
        if not clean_snippet and len(clean_title) < 10:
            continue

        seen_urls.add(url)
        refined.append({
            "title": clean_title,
            "url": url,
            "snippet": clean_snippet or "[Sem descrição disponível na página]",
            "engine": engine,
        })

        if len(refined) >= max_results:
            break

    return refined


def format_web_context(
    query: str,
    refined_items: List[Dict[str, str]],
    source_label: str = "SearXNG (Busca Web em Tempo Real)",
) -> str:
    """
    Estrutura os resultados refinados em formato Markdown pronto para ser
    injetado diretamente no dossiê ou prompt do modelo local.
    """
    if not refined_items:
        return ""

    lines = [
        f"=== CONTEXTO ADICIONAL DA WEB ({source_label}) ===",
        f"Consulta realizada: \"{query}\"",
        f"Resultados refinados ({len(refined_items)} fontes selecionadas):",
        "",
    ]

    for idx, item in enumerate(refined_items, 1):
        lines.append(f"[{idx}] {item['title']}")
        lines.append(f"    URL: {item['url']}")
        lines.append(f"    Fonte/Motor: `{item['engine']}`")
        lines.append(f"    Evidência/Resumo: {item['snippet']}")
        lines.append("")

    lines.append(
        "DIRETRIZ DE APLICAÇÃO (MODELO 7B):\n"
        "- Utilize as evidências acima exclusivamente para esclarecer normas, parâmetros ou CVEs citadas.\n"
        "- Cite a URL ou número da fonte sempre que fundamentar uma recomendação técnica nesses dados.\n"
        "- Não adicione informações externas além das evidências verificadas."
    )
    lines.append("=" * 60)

    return "\n".join(lines)


def search_and_refine(
    query: str,
    base_url: str = DEFAULT_SEARXNG_URL,
    max_results: int = 3,
    max_snippet_chars: int = 400,
    categories: str = "general",
    language: str = "auto",
    time_range: Optional[str] = None,
) -> Tuple[List[Dict[str, str]], str, Optional[str]]:
    """
    Função de alto nível:
    Executa busca, refina os itens e gera a string de contexto pronta.
    Retorna: (lista_refinada, texto_markdown_formatado, erro_se_houver)
    """
    raw_data = query_searxng(
        query=query,
        base_url=base_url,
        categories=categories,
        language=language,
        time_range=time_range,
    )

    err = raw_data.get("error")
    if err:
        return [], "", err

    refined = refine_results(raw_data, max_results=max_results, max_snippet_chars=max_snippet_chars)
    context_text = format_web_context(query, refined)
    return refined, context_text, None


def main():
    """Testa busca manual e exibe o contexto refinado."""
    if len(sys.argv) < 2:
        print("Uso: python3 web_search.py \"<termo de busca>\" [searxng_url]")
        print("Exemplo: python3 web_search.py \"PostgreSQL pg_hba md5 vs scram-sha-256\"")
        sys.exit(1)

    term = sys.argv[1]
    url = sys.argv[2] if len(sys.argv) > 2 else DEFAULT_SEARXNG_URL

    print(f"[Checagem] Validando conexão com SearXNG em {url}...")
    ok, msg = check_searxng_health(url)
    print(f"[{'OK' if ok else 'Aviso'}] {msg}")

    print(f"\n[Busca] Executando consulta: '{term}'...")
    refined, ctx, err = search_and_refine(term, base_url=url, max_results=3)

    if err:
        print(f"\033[1;31m[Erro]\033[0m {err}")
        sys.exit(1)

    print(f"\n[Sucesso] {len(refined)} resultado(s) refinado(s):\n")
    print(ctx)


if __name__ == "__main__":
    main()
