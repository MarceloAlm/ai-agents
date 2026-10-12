# Variante opencode:ml — Construída incrementalmente sobre a imagem opencode:dotnet
# Adiciona Python (numpy/matplotlib para gráficos), runner de scripts .csx (dotnet-script)
# e exemplos de referência em /opt/ml
FROM opencode:dotnet

USER root

# Python + bibliotecas científicas para plotagem de curvas de perda/acurácia
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        python3 python3-numpy python3-matplotlib && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Runner de scripts C# (.csx)
RUN dotnet tool install --tool-path /dotnet-tools dotnet-script
RUN chown -R opencode:opencode /dotnet-tools

# Exemplos de referência para estudo de redes neurais (read-only em /opt/ml)
COPY ml-reference /opt/ml

# Marcação da variante ml
ENV OPENCODE_VARIANT=ml

USER opencode
