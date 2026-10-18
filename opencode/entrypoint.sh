#!/bin/bash
# Entrypoint do container: delega as atualizações do perfil aos scripts de
# update da imagem (/etc/opencode/update/, versionados por
# /etc/opencode/.image-version) e inicia o opencode.
# /etc/opencode é somente-leitura em runtime — só o Dockerfile o atualiza.
set -u

log() { printf '[entrypoint] %s\n' "$*" >&2; }

HOME_DIR="${HOME:?HOME não definida}"
mkdir -p "$HOME_DIR/.config/opencode"

UPDATE="${OPENCODE_UPDATE:-/etc/opencode/update/run.sh}"
if [ -f "$UPDATE" ]; then
    bash "$UPDATE" || log "atualizações do perfil com falha (continua mesmo assim)"
else
    log "script de atualização não encontrado: $UPDATE"
fi

if [ "$#" -gt 0 ] && [ "$1" = "opencode" ]; then
    shift
fi

exec opencode "$@"
