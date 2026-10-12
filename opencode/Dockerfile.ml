# Variante opencode:ml — Construída incrementalmente sobre a imagem opencode:dotnet
# Adiciona Python (numpy/matplotlib para gráficos), runner de scripts .csx (dotnet-script)
# e exemplos de referência em /opt/ml
FROM opencode:dotnet

USER root

ENV OPENCODE_VARIANT=ml

# Python, bibliotecas científicas e runner de scripts C# (.csx) em camada única
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        python3 python3-numpy python3-matplotlib && \
    dotnet tool install --tool-path /dotnet-tools dotnet-script && \
    chown -R opencode:opencode /dotnet-tools && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Exemplos de referência para estudo de redes neurais (read-only em /opt/ml)
COPY ml-reference /opt/ml

USER opencode
