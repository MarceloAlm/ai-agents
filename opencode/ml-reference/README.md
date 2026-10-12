# Referência de estudo — redes neurais em C#

Exemplos prontos para rodar dentro da imagem `opencode:ml`. Copie-os para
seu workspace antes de editar (a pasta `/opt/ml` é read-only):

```bash
cp -r /opt/ml/. /workspace/
```

## Como executar

| Exemplo | Como rodar |
|---|---|
| Perceptron (AND/OR) | `dotnet script perceptron.csx` |
| MLP + backpropagation (XOR) | `dotnet script mlp-xor.csx` |

Para projetos completos use `dotnet new console` e `dotnet run`.

## Roteiro sugerido

1. **Perceptron** (`perceptron.csx`) — o neurônio único: soma ponderada + ativação degrau + regra de aprendizado. Ele resolve AND/OR (linearmente separáveis).
2. **Prove o limite:** troque os rótulos do perceptron por XOR (`{0,1,1,0}`). Ele nunca converge — mostra por que uma única camada não basta.
3. **MLP + backprop** (`mlp-xor.csx`) — camada oculta com ativação não-linear (sigmoide) + descida de gradiente. Entenda forward, cálculo do erro e atualização dos pesos.
4. **Variações:** troque sigmoide por tanh ou ReLU; ajuste a taxa de aprendizado; aumente o nº de ocultos; veja o efeito no erro médio.
5. **Casos reais:** migre para um dos frameworks abaixo.

## Bibliotecas C# para ML (via NuGet, baixam no restore)

| Pacote | Uso | Exemplo de instalação |
|---|---|---|
| **TorchSharp** + `TorchSharp.Native.Linux.x64` | Tensores e redes estilo PyTorch com autograd (GPU/CPU) | `dotnet add package TorchSharp` |
| **Microsoft.ML** | Framework de ML da Microsoft (pipeline: dados → treino → inferência) | `dotnet add package Microsoft.ML` |
| **MathNet.Numerics** | Álgebra linear (matrizes/vetores) p/ implementar redes do zero | `dotnet add package MathNet.Numerics` |

## Plotando curvas (Python)

A imagem inclui `python3` + `numpy` + `matplotlib`. Para visualizar a curva
de perda do treino, o programa C# pode gravar um CSV e o Python gerar o gráfico:

```bash
# depois de gravar loss.csv (época,erro):
python3 -c "
import csv, matplotlib.pyplot as plt
ep, e = zip(*csv.reader(open('loss.csv'), delimiter=','))
e = [float(x) for x in e]
plt.plot(e); plt.xlabel('época'); plt.ylabel('erro médio')
plt.title('Curva de perda'); plt.savefig('loss.png')
"
```

Ou, mais simples: o C# já imprime o erro por época no terminal — o gráfico é
opcional, apenas para visualizar a convergência.