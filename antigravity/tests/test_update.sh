#!/bin/bash
# Testes sandbox do fluxo de atualização do perfil:
# /etc (imagem) imutável + updates do home delegados a /etc/antigravity/update/
# com controle de versão em /etc/antigravity/.image-version.
set -u

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SB="$(mktemp -d "${TMPDIR:-/tmp}/antigravity-tests.XXXXXX")"
trap 'rm -rf "$SB"' EXIT

PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); printf '  OK  %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf 'FAIL  %s\n' "$1"; }
check(){ if eval "$2"; then ok "$1"; else bad "$1"; fi; }

mkdir -p "$SB/bin"
printf '#!/bin/bash\nif [ -f "$HOME/.gemini/config/skills/reverse-engineering/SKILL.md" ]; then echo rea-skill-active >> "$HOME/agy.log"; fi\nexit 0\n' > "$SB/bin/agy" && chmod +x "$SB/bin/agy"

# Simula a imagem: /etc/antigravity com AGENTS, skills, update/, settings.json e carimbo
ETC="$SB/etc/antigravity"
mkdir -p "$ETC"
cp "$REPO/AGENTS.md" "$ETC/AGENTS.md"
cp -a "$REPO/skills" "$ETC/skills"
cp -a "$REPO/update" "$ETC/update"
cp "$REPO/settings.json" "$ETC/settings.json"
printf '20261018-0001\n' > "$ETC/.image-version"

# Estado do /etc (exclui .image-version, que os testes alteram p/ simular builds)
sha_etc() { find "$ETC" -type f ! -name '.image-version' -print0 | sort -z | xargs -0 sha256sum | sha256sum | awk '{print $1}'; }

# run <home> <logfile> [atribuições de env...]
run() {
    local home="$1" logf="$2"
    shift 2
    env -u SKILLS_SOURCE -u SKILLS_REPO \
        HOME="$home" PATH="$SB/bin:$PATH" \
        ANTIGRAVITY_ETC="$ETC" \
        AGY_VARIANT=base \
        "$@" \
        bash "$REPO/entrypoint.sh" 2>"$logf"
}

CFG="$SB/home/.gemini/config"
SEED_DIR="$SB/home/.gemini/antigravity-cli"
AGENTS="$CFG/AGENTS.md"
SKILLS="$CFG/skills"
APPLIED="$CFG/.applied-version"
ETC_BEFORE=$(sha_etc)

echo "== T1: 1ª inicialização (versão 20261018-0001) =="
run "$SB/home" "$SB/t1.err" SKILLS_SOURCE="$ETC/skills"
check "AGENTS do perfil = AGENTS da imagem" "cmp -s '$AGENTS' '$ETC/AGENTS.md'"
check "AGENTS aponta regras canônicas Zero Secret Leak" "grep -q 'Proteção de Segredos (Zero Secret Leak)' '$AGENTS'"
check "skills sincronizadas no perfil" "cmp -s '$SKILLS/container-ambiente/SKILL.md' '$ETC/skills/container-ambiente/SKILL.md'"
check "carimbo aplicado no perfil" "[ \"\$(cat '$APPLIED')\" = 20261018-0001 ]"
check "variante registrada em config e agy-cli" "[ \"\$(cat '$CFG/variant')\" = base ] && [ \"\$(cat '$SEED_DIR/variant')\" = base ]"
check "log de aplicação" "grep -q 'atualizações da versão 20261018-0001 aplicadas' '$SB/t1.err'"
check "/etc intacto após T1" "[ \"\$(sha_etc)\" = '$ETC_BEFORE' ]"

echo "== T2: mesma versão → caminho rápido, AGENTS sempre regenerado =="
echo "CONTEUDO PESSOAL - deve sumir do AGENTS" >> "$AGENTS"
echo "EDICAO NA SKILL - persiste ate o proximo bump" >> "$SKILLS/container-ambiente/SKILL.md"
run "$SB/home" "$SB/t2.err" SKILLS_SOURCE="$ETC/skills"
check "AGENTS regenerado a cada boot (pessoal removido)" "! grep -q 'CONTEUDO PESSOAL' '$AGENTS'"
check "AGENTS = imagem novamente" "cmp -s '$AGENTS' '$ETC/AGENTS.md'"
check "edição na skill persiste no caminho rápido" "grep -q 'EDICAO NA SKILL' '$SKILLS/container-ambiente/SKILL.md'"
check "sem sync de skills no caminho rápido" "! grep -Eq 'instalada:|atualizada:|aplicadas ao perfil' '$SB/t2.err'"

echo "== T2b: entrypoint sem script de atualização executa fallback limpo =="
run "$SB/home-fallback" "$SB/t2b.err" ANTIGRAVITY_ETC="/nao/existe"
check "AGENTS criado no fallback" "[ -f '$SB/home-fallback/.gemini/config/AGENTS.md' ] || [ -f '$SB/home-fallback/.gemini/antigravity-cli/variant' ]"

echo "== T3: bump de versão → atualizações pesadas =="
printf '20261018-0002\n' > "$ETC/.image-version"
mkdir -p "$CFG/rules"; echo "legado" > "$CFG/rules/zero-secret-leak.md"
mkdir -p "$SEED_DIR/skills"; echo "redundante" > "$SEED_DIR/skills/antigo.txt"
# manifesto anterior: hash corrompido em SKILL.md + artefatos que saíram da fonte
{
    grep 'container-ambiente/SKILL.md' "$CFG/.skill-manifest.txt" | awk '{printf "%064d  %s\n", 0, $2}'
    printf '%064d  %s\n' 0 'velha-skill/SKILL.md'
} > "$CFG/.skill-manifest.new" && mv "$CFG/.skill-manifest.new" "$CFG/.skill-manifest.txt"
echo "minha preferencia pessoal" > "$SKILLS/container-ambiente/preferences.md"
mkdir -p "$SKILLS/velha-skill"; echo x > "$SKILLS/velha-skill/SKILL.md"
run "$SB/home" "$SB/t3.err" SKILLS_SOURCE="$ETC/skills"
check "carimbo avança p/ 20261018-0002" "[ \"\$(cat '$APPLIED')\" = 20261018-0002 ]"
check "log de migração" "grep -q 'atualizações da versão 20261018-0002 aplicadas' '$SB/t3.err'"
check "artefato rules/ legado removido" "[ ! -d '$CFG/rules' ]"
check "cópia redundante em agy-cli/skills removida" "[ ! -d '$SEED_DIR/skills' ]"
check "arquivo pessoal preservado (nunca em manifesto)" "grep -q 'minha preferencia pessoal' '$SKILLS/container-ambiente/preferences.md'"
check "skill que saiu da fonte removida com o diretório" "[ ! -d '$SKILLS/velha-skill' ]"
check "skill editada: backup em skills-custom" "ls '$CFG/skills-custom/container-ambiente/'*.custom >/dev/null 2>&1"
check "skill editada: oficial restaurada" "cmp -s '$SKILLS/container-ambiente/SKILL.md' '$ETC/skills/container-ambiente/SKILL.md'"
check "/etc intacto após T3" "[ \"\$(sha_etc)\" = '$ETC_BEFORE' ]"

echo "== T3b: mesma versão → caminho rápido =="
run "$SB/home" "$SB/t3b.err" SKILLS_SOURCE="$ETC/skills"
check "sem reaplicação" "! grep -q 'aplicadas ao perfil' '$SB/t3b.err'"

echo "== T4: carimbo 'dev' → aplica sempre =="
printf 'dev\n' > "$ETC/.image-version"
run "$SB/home" "$SB/t4a.err" SKILLS_SOURCE="$ETC/skills"
run "$SB/home" "$SB/t4b.err" SKILLS_SOURCE="$ETC/skills"
check "1ª execução dev aplica" "grep -q 'aplicadas ao perfil' '$SB/t4a.err'"
check "2ª execução dev aplica de novo" "grep -q 'aplicadas ao perfil' '$SB/t4b.err'"
printf '20261018-0002\n' > "$ETC/.image-version"
run "$SB/home" "$SB/t4c.err" SKILLS_SOURCE="$ETC/skills"

echo "== T5: falha no skills.sh não avança o carimbo =="
printf '20261018-0003\n' > "$ETC/.image-version"
mv "$ETC/update/skills.sh" "$ETC/update/skills.sh.bak"
printf '#!/bin/bash\necho "[update:skills] erro simulado" >&2\nexit 1\n' > "$ETC/update/skills.sh"
run "$SB/home" "$SB/t5.err"
mv "$ETC/update/skills.sh.bak" "$ETC/update/skills.sh"
check "carimbo não avança" "[ \"\$(cat '$APPLIED')\" != 20261018-0003 ]"
check "log de reexecução" "grep -q 'reexecutadas no próximo boot' '$SB/t5.err'"
run "$SB/home" "$SB/t5b.err"
check "próximo boot completa" "[ \"\$(cat '$APPLIED')\" = 20261018-0003 ] && grep -q 'aplicadas ao perfil' '$SB/t5b.err'"

echo "== F1a: projeto montado SEM marcador não vira fonte =="
mkdir -p "$SB/repo-nomark/skills/peixinho"
echo "skill de projeto qualquer" > "$SB/repo-nomark/skills/peixinho/SKILL.md"
run "$SB/home-f1a" "$SB/f1a.err" SKILLS_REPO="$SB/repo-nomark"
check "fonte foi a cópia da imagem (container-ambiente presente)" \
    "[ -f '$SB/home-f1a/.gemini/config/skills/container-ambiente/SKILL.md' ]"
check "skills do projeto NÃO vazaram p/ o perfil" \
    "[ ! -e '$SB/home-f1a/.gemini/config/skills/peixinho' ]"

echo "== F1b: repositório COM marcador Dockerfile é a fonte =="
mkdir -p "$SB/repo-mark/skills/peixinho"
echo "skill do repo de dev" > "$SB/repo-mark/skills/peixinho/SKILL.md"
touch "$SB/repo-mark/Dockerfile"
run "$SB/home-f1b" "$SB/f1b.err" SKILLS_REPO="$SB/repo-mark"
check "skills do repositório sincronizadas" \
    "[ -f '$SB/home-f1b/.gemini/config/skills/peixinho/SKILL.md' ]"

echo "== T7: ciclo de vida e isolamento da variante rea =="
run "$SB/home-rea" "$SB/rea1.err" AGY_VARIANT=rea
check "rea 1: skill ativa durante execução" "grep -q 'rea-skill-active' '$SB/home-rea/agy.log'"
check "rea 1: skill limpa do perfil após saída" "[ ! -d '$SB/home-rea/.gemini/config/skills/reverse-engineering' ]"
run "$SB/home-rea" "$SB/rea2.err" AGY_VARIANT=rea
check "rea 2: skill reinjetada mesmo na mesma versão da imagem" "[ \"\$(grep -c 'rea-skill-active' '$SB/home-rea/agy.log')\" = 2 ]"
check "rea 2: skill limpa novamente após saída" "[ ! -d '$SB/home-rea/.gemini/config/skills/reverse-engineering' ]"
run "$SB/home-rea" "$SB/rea3.err" AGY_VARIANT=base
check "base: skill rea não injetada" "[ \"\$(grep -c 'rea-skill-active' '$SB/home-rea/agy.log')\" = 2 ] && [ ! -d '$SB/home-rea/.gemini/config/skills/reverse-engineering' ]"

echo "== T6: /etc nunca escrito em runtime =="
check "nenhum sudo nos scripts de update/entrypoint" "! grep -rq 'sudo' '$REPO/entrypoint.sh' '$REPO/update/'"
check "/etc byte-idêntico ao longo de todos os testes" "[ \"\$(sha_etc)\" = '$ETC_BEFORE' ]"

echo
echo "sandbox: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" = 0 ]
