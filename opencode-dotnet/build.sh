#!/bin/bash
podman build --build-arg OPENCODE_VERSION=1.18.28 -t opencode:dotnet ./opencode-dotnet
