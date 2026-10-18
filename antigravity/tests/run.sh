#!/bin/bash
# Bateria de verificações do antigravity/ (host, sem Docker):
# sintaxe, JSON das configurações, diff R5, validação de sudoers e sandbox de updates.
set -u

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$DIR/.." && pwd)"
FAIL=0

echo "== bash -n =="
for f in "$REPO/entrypoint.sh" "$REPO"/update/*.sh "$REPO"/scripts/*.sh \
         "$REPO"/build*.sh "$REPO"/agy*.sh "$DIR"/*.sh; do
    if bash -n "$f"; then
        echo "  ok   ${f#"$REPO"/}"
    else
        echo "  FAIL ${f#"$REPO"/}"
        FAIL=1
    fi
done

echo "== JSON (settings.json e mcp_config.rea.json) =="
JSON_OK=1
for jf in "$REPO/settings.json" "$REPO/mcp_config.rea.json"; do
    if [ -f "$jf" ]; then
        if jq empty "$jf" 2>/dev/null; then
            echo "  ok   ${jf#"$REPO"/}"
        else
            echo "  FAIL ${jf#"$REPO"/}"
            JSON_OK=0
        fi
    fi
done
[ "$JSON_OK" = 1 ] || FAIL=1

echo "== R5 (rules/zero-secret-leak.md ≡ seção do AGENTS.md) =="
if diff <(sed 's/^#/##/' "$REPO/rules/zero-secret-leak.md") \
        <(awk '/^## Proteção de Segredos \(Zero Secret Leak\)/,0' "$REPO/AGENTS.md"); then
    echo "  ok"
else
    echo "  FAIL"
    FAIL=1
fi

echo "== sudo (escopo mínimo) =="
SNIPPET="$(mktemp)"
awk '/<< .EOF. > \/tmp\/antigravity.sudoers/{f=1;next} /^EOF$/{f=0} f' "$REPO/scripts/setup-base.sh" > "$SNIPPET"
SUDO_OK=1
if grep -q 'NOPASSWD:ALL' "$REPO/scripts/setup-base.sh"; then
    echo "  FAIL NOPASSWD:ALL presente no setup-base"
    SUDO_OK=0
fi
if ! grep -q 'NOPASSWD: APTGET, APT' "$SNIPPET"; then
    echo "  FAIL allowlist apt ausente"
    SUDO_OK=0
fi
VLINE="$(grep -n '/usr/sbin/visudo -cf' "$REPO/scripts/setup-base.sh" | cut -d: -f1)"
SLINE="$(grep -n 'procps' "$REPO/scripts/setup-base.sh" | cut -d: -f1)"
if [ -z "$VLINE" ] || [ -z "$SLINE" ] || [ "$VLINE" -le "$SLINE" ]; then
    echo "  FAIL visudo sem caminho completo ou antes da instalação do pacote sudo"
    SUDO_OK=0
fi
if command -v visudo >/dev/null 2>&1; then
    if ! visudo -cf "$SNIPPET"; then
        echo "  FAIL gramática do sudoers"
        SUDO_OK=0
    fi
else
    echo "  (visudo indisponível — gramática não validada)"
fi
rm -f "$SNIPPET"
if [ "$SUDO_OK" = 1 ]; then
    echo "  ok"
else
    FAIL=1
fi

echo "== Dockerfiles (scripts montados por bind, sem camada temporária) =="
DOCKER_OK=1
if grep -Hn 'COPY scripts/' "$REPO"/Dockerfile* 2>/dev/null; then
    echo "  FAIL COPY de script temporário presente"
    DOCKER_OK=0
fi
if [ "$(grep -ho 'RUN --mount=type=bind,source=scripts/' "$REPO"/Dockerfile* | wc -l)" != "3" ]; then
    echo "  FAIL esperados 3 RUN --mount=type=bind de scripts"
    DOCKER_OK=0
fi
if [ "$DOCKER_OK" = 1 ]; then
    echo "  ok"
else
    FAIL=1
fi

echo "== sandbox: fluxo de atualização =="
if ! bash "$DIR/test_update.sh"; then
    FAIL=1
fi

echo
if [ "$FAIL" = 0 ]; then
    echo "BATERIA OK"
else
    echo "BATERIA COM FALHAS"
fi
[ "$FAIL" = 0 ]
