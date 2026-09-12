#!/bin/bash
podman run --rm -it --userns=keep-id -v "opencode-ml-home:/home/node" -v "$PWD:/workspace" -v "/etc/ssl/certs:/etc/ssl/certs:ro" -w /workspace opencode:ml opencode "$@"
