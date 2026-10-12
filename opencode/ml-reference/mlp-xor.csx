// =====================================================================
// MLP (Multilayer Perceptron) 2-2-1 com BACKPROPAGATION — resolve o XOR
// Rode com:  dotnet script mlp-xor.csx
//
// Por que duas camadas?
//   XOR não é linearmente separável: não dá para separar 0/1 com uma reta.
//   Uma camada oculta com ativação NÃO-LINEAR (sigmoide) transforma o
//   espaço em algo separável pela camada de saída.
//
// Backpropagation (coração do aprendizado):
//   1. Forward: calcula a saída propagando o sinal para frente.
//   2. Erro na saída: delta_saida = (saida - rotulo) * sig'(saida)
//   3. Erro na camada oculta: delta_oculto = sig'(oculto) * delta_saida * w_saida
//   4. Atualiza pesos: w -= taxa * delta * entrada (descida de gradiente)
//
// Arquitetura: 2 entradas -> 2 neurônios ocultos -> 1 saída.
// Cada neurônio tem um BIAS (tratado aqui como peso extra com entrada fixa 1).
// =====================================================================

using System;

double Sig(double z) => 1.0 / (1.0 + Math.Exp(-z));      // ativação
double SigDeriv(double a) => a * (1 - a);                 // derivada: sig' = sig*(1-sig)

const int NumEnt = 2;
const int NumOc  = 2;
const int NumSaida = 1;

// Pesos em vetor simples; cada neurônio ocupa (entradas + 1) posições,
// com o bias na 1ª posição. Ex.: Wsaida = [bias_o, w_h1, w_h2]
double[] Woculto = new double[NumOc * (NumEnt + 1)];
double[] Wsaida  = new double[NumSaida * (NumOc + 1)];
double[] Oculta  = new double[NumOc];                     // saída dos ocultos (cache p/ backprop)

void Inicializar() {
    var rnd = new Random(7);
    for (int i = 0; i < Woculto.Length; i++) Woculto[i] = rnd.NextDouble() * 2 - 1;   // [-1,1]
    for (int i = 0; i < Wsaida.Length;  i++) Wsaida[i]  = rnd.NextDouble() * 2 - 1;
}

double Forward(double[] x) {
    // camada oculta: Oculta[i] = sig(bias_i + w_i1*x0 + w_i2*x1)
    for (int i = 0; i < NumOc; i++) {
        int k = i * (NumEnt + 1);
        double z = Woculto[k];                            // bias
        for (int j = 0; j < NumEnt; j++) z += Woculto[k + j + 1] * x[j];
        Oculta[i] = Sig(z);
    }
    // camada de saída: saida = sig(bias_o + w_o1*h0 + w_o2*h1)
    double s = Wsaida[0];
    for (int j = 0; j < NumOc; j++) s += Wsaida[j + 1] * Oculta[j];
    return Sig(s);
}

void TreinarExemplo(double[] x, double rotulo, double taxa) {
    double saida = Forward(x);

    // ---- backward ----
    // erro na saída = (previsto - rotulo) * derivada da sigmoide
    double dSaida = (saida - rotulo) * SigDeriv(saida);

    // erros que "chegam" a cada oculto
    double[] dOculta = new double[NumOc];
    for (int i = 0; i < NumOc; i++)
        dOculta[i] = SigDeriv(Oculta[i]) * dSaida * Wsaida[i + 1];

    // ---- atualiza pesos (descida de gradiente: w -= taxa * delta * entrada) ----
    Wsaida[0] -= taxa * dSaida;                            // bias da saída (entrada fixa 1)
    for (int j = 0; j < NumOc; j++)
        Wsaida[j + 1] -= taxa * dSaida * Oculta[j];

    for (int i = 0; i < NumOc; i++) {
        int k = i * (NumEnt + 1);
        Woculto[k] -= taxa * dOculta[i];                   // bias do oculto
        for (int j = 0; j < NumEnt; j++)
            Woculto[k + j + 1] -= taxa * dOculta[i] * x[j];
    }
}

double[][] X = {
    new[] { 0.0, 0.0 },
    new[] { 0.0, 1.0 },
    new[] { 1.0, 0.0 },
    new[] { 1.0, 1.0 },
};
double[] Y = { 0, 1, 1, 0 };                              // XOR

double ErroMedio() {
    double soma = 0;
    for (int i = 0; i < X.Length; i++) {
        double d = Forward(X[i]) - Y[i];
        soma += d * d;                                     // erro quadrático
    }
    return soma / X.Length;
}

const double Taxa = 1.0;
const int Epocas = 5000;

Inicializar();
Console.WriteLine("=== MLP 2-2-1 resolvendo XOR ===");
Console.WriteLine($"época   erro médio");

for (int epoca = 1; epoca <= Epocas; epoca++) {
    for (int i = 0; i < X.Length; i++)
        TreinarExemplo(X[i], Y[i], Taxa);

    // imprime progresso a cada ~500 épocas
    if (epoca == 1 || epoca % 500 == 0)
        Console.WriteLine($"{epoca,5}   {ErroMedio():0.0000000}");
}

Console.WriteLine("\nvalidacao final:");
int acertos = 0;
for (int i = 0; i < X.Length; i++) {
    double o = Forward(X[i]);
    int binario = o >= 0.5 ? 1 : 0;
    bool certo = binario == Y[i];
    if (certo) acertos++;
    Console.WriteLine($"  [{string.Join(",", X[i])}] -> {o:0.###}  => {binario}   (esperado {Y[i]})  {(certo ? "OK" : "ERRADO")}");
}
Console.WriteLine($"acerto: {acertos}/4");