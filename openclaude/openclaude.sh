#!/bin/bash
#podman run --rm -it --userns=keep-id --env-file "$HOME/Projetos/secrets.env" -v "$PWD:/workspace" -w /workspace openclaude:latest
podman run --rm -it --userns=keep-id -v "openclaude-home:/home/node" -v "$PWD:/workspace" -w /workspace openclaude:latest openclaude "$@"
