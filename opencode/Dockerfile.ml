# Variante opencode:ml — Construída incrementalmente sobre a imagem opencode:dotnet
# Adiciona Python (numpy/matplotlib para gráficos), runner de scripts .csx (dotnet-script)
# e exemplos de referência em /opt/ml
FROM opencode:dotnet

USER root

ENV OPENCODE_VARIANT=ml

# Python, bibliotecas científicas e dotnet-script via script modular
COPY scripts/setup-ml.sh /tmp/setup-ml.sh
RUN bash /tmp/setup-ml.sh && rm -f /tmp/setup-ml.sh

# Exemplos de referência para estudo de redes neurais (read-only em /opt/ml)
COPY ml-reference /opt/ml

USER opencode
