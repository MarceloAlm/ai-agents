#!/bin/bash
podman run --rm -it --userns=keep-id -v "opencode-home:/home/node" -v "$PWD:/workspace" -w /workspace opencode:dotnet opencode "$@"
