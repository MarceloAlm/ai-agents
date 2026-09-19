#!/bin/bash
podman run --rm -it --userns=keep-id -v "opencode-ml-home:/home/node" -v "$PWD:/workspace" -w /workspace opencode:ml opencode "$@"
