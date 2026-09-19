#!/bin/bash
podman run --rm -it --userns=keep-id:uid=1100,gid=1100 -v "opencode-ml-home:/home/opencode" -v "$PWD:/workspace" -w /workspace opencode:ml opencode "$@"
