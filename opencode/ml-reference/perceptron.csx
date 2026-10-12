// =====================================================================
// PERCEPTRON em C# — o neurônio mais simples (Rosenblatt, 1958)
// Rode com:  dotnet script perceptron.csx
//
// Ideia:
//   soma ponderada das entradas (com bias) + função de ativação DEGRAU:
//     saida = 1 se (w0*x0 + w1*x1 + ... + bias) > 0, senão 0
//
// Regra de aprendizado:
//     w_i  += taxa * (esperado - saida) * x_i
//     bias += taxa * (esperado - saida)
//
// O perceptron aprende só problemas LINEARMENTE SEPARÁVEIS.
// Por isso acerta AND e OR, mas falha no XOR (veja mlp-xor.csx).
// =====================================================================

using System;
using System.Linq;

class Perceptron {
    private readonly double[] _pesos;
    private readonly double _taxa;
    private double _bias;

    public Perceptron(int numEntradas, double taxa = 0.1, int seed = 42) {
        var rnd = new Random(seed);
        _pesos = Enumerable.Range(0, numEntradas).Select(_ => rnd.NextDouble() - 0.5).ToArray();
        _bias = rnd.NextDouble() - 0.5;
        _taxa = taxa;
    }

    private double Soma(double[] x) => _pesos.Zip(x, (w, v) => w * v).Sum() + _bias;
    private int Ativacao(double z) => z > 0 ? 1 : 0;         // degrau
    public int Predizer(double[] x) => Ativacao(Soma(x));

    // Treina com UM exemplo; retorna true se errou (ainda há o que aprender)
    public bool Treinar(double[] x, int esperado) {
        int saida = Predizer(x);
        int erro = esperado - saida;                          // 0, +1 ou -1
        for (int i = 0; i < _pesos.Length; i++)
            _pesos[i] += _taxa * erro * x[i];                 // w += eta * erro * x
        _bias += _taxa * erro;
        return erro != 0;
    }

    public void ImprimirPesos() =>
        Console.WriteLine($"  pesos: [{string.Join(", ", _pesos.Select(w => w.ToString("0.000")))}]  bias: {_bias:0.000}");
}

// dados de treino: todas as combinações de 2 entradas binárias
double[][] Entradas = {
    new[] { 0.0, 0.0 },
    new[] { 0.0, 1.0 },
    new[] { 1.0, 0.0 },
    new[] { 1.0, 1.0 },
};
int[] AndEsperado = { 0, 0, 0, 1 };
int[] OrEsperado  = { 0, 1, 1, 1 };

void TreinarEValidar(string nome, int[] rotulos) {
    var p = new Perceptron(numEntradas: 2);
    Console.WriteLine($"\n=== PORTA {nome} ===");
    Console.WriteLine("  pesos iniciais (aleatórios):");
    p.ImprimirPesos();

    int epoca = 0;
    bool houveErro;
    do {
        houveErro = false;
        for (int i = 0; i < Entradas.Length; i++)
            if (p.Treinar(Entradas[i], rotulos[i])) houveErro = true;
        epoca++;
    } while (houveErro && epoca < 1000);

    Console.WriteLine($"  convergiu em {epoca} épocas");
    p.ImprimirPesos();

    int acertos = 0;
    for (int i = 0; i < Entradas.Length; i++) {
        int obtido = p.Predizer(Entradas[i]);
        int certo = obtido == rotulos[i] ? 1 : 0;
        acertos += certo;
        Console.WriteLine($"  [{string.Join(",", Entradas[i])}] -> {obtido}   (esperado {rotulos[i]})  {(certo == 1 ? "OK" : "ERRADO")}");
    }
    Console.WriteLine($"  acerto: {acertos}/{Entradas.Length}");
}

TreinarEValidar("AND", AndEsperado);
TreinarEValidar("OR",  OrEsperado);

// Desafio: troque os rótulos acima por { 0, 1, 1, 0 } (XOR) e veja o
// perceptron NUNCA convergir — XOR não é linearmente separável.
// A solução está em mlp-xor.csx.