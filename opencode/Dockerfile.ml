# Variante opencode:ml — Construída incrementalmente sobre a imagem opencode:dotnet
# Adiciona Python (numpy/matplotlib para gráficos), runner de scripts .csx (dotnet-script)
# e exemplos de referência em /opt/ml
FROM opencode:dotnet

USER root

# Hash do script de setup: invalidação de cache do RUN (ver Dockerfile base)
ARG SETUP_HASH=

ENV OPENCODE_VARIANT=ml

# Python, bibliotecas científicas e dotnet-script via script modular,
# montado por bind: sem camada COPY temporária com o script na história
RUN --mount=type=bind,source=scripts/setup-ml.sh,target=/tmp/setup-ml.sh \
    echo "setup:${SETUP_HASH}" && bash /tmp/setup-ml.sh

# Exemplos de referência para estudo de redes neurais (read-only em /opt/ml)
COPY ml-reference /opt/ml

USER opencode
