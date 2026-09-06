import 'package:flutter/material.dart';

/// Paleta do DevLingo. O motivo de cada cor esta em `docs/paleta.md`.
///
/// **O verde e acento, nunca corpo de texto.** Verde saturado sobre fundo
/// escuro reprova em contraste quando usado em texto longo.
abstract final class Paleta {
  // --- base ---
  static const fundo = Color(0xFF170A31);
  static const superficie = Color(0xFF1E0F3E);
  static const linha = Color(0xFF3D2A66);
  static const texto = Color(0xFFF2F0FF);
  static const suave = Color(0xFF9B8FC7);

  /// Tom mais fundo que o fundo, para a sombra de recorte ter o que escurecer.
  ///
  /// Um degrade que termina na propria cor do fundo e invisivel: ele so
  /// escurece o que estiver por baixo, e no limite do miolo costuma haver
  /// apenas a borda fina de um cartao. Este tom vem do mockup, que usa
  /// `#0C0518` como fundo da pagina.
  static const veu = Color(0xFF0C0518);

  // --- acentos com funcao definida ---
  static const acerto = Color(0xFFFF2D95);

  /// Magenta rebaixado, para preencher sem competir com o texto por cima.
  static const acertoTenue = Color(0x33FF2D95);

  // --- retorno da resposta ---
  //
  // Verde para certo, vermelho para errado. Os dois entram apenas em **rotulo,
  // borda e preenchimento**, nunca no corpo do texto: verde saturado sobre
  // fundo escuro reprova em contraste quando usado em texto longo, que e a
  // regra registrada em docs/paleta.md. A explicacao continua em [texto].

  /// Verde do visor, reaproveitado como sinal de acerto.
  static const certo = visor;
  static const certoTenue = Color(0x3339FF14);

  /// Vermelho suave, o mesmo ja usado no pontinho da aba da IDE.
  static const erro = Color(0xFFFF5F57);
  static const erroTenue = Color(0x33FF5F57);
  static const destaque = Color(0xFF00E5FF);
  static const visor = Color(0xFF39FF14);
  static const telemetria = Color(0xFFFFE14D);

  // --- bloco de codigo ---
  static const ideFundo = Color(0xFF1B1235);
  static const ideAba = Color(0xFF241847);
  static const ideNumeroLinha = Color(0xFF5F4B8B);
  static const ideLinhaDestacada = Color(0xFF2E1D5C);

  /// Pastilha da lacuna: fundo ciano com texto escuro, para contraste.
  static const lacunaFundo = destaque;
  static const lacunaTexto = Color(0xFF062230);

  // --- estados de alternativa ---
  static const altSelecionadaBorda = destaque;
  static const altSelecionadaFundo = Color(0xFF1D2C4A);

  /// Texto sobre o botao primario preenchido de magenta.
  static const sobreAcerto = Color(0xFF3B0A24);

  /// Trilho da barra de progresso, atras do preenchimento.
  static const trilho = Color(0xFF2A1B4D);

  // --- pontinhos da aba da IDE ---
  static const pontoVermelho = Color(0xFFFF5F57);
  static const pontoAmarelo = telemetria;
  static const pontoVerde = visor;
}

/// Escala tipografica e de espacamento.
///
/// O mockup em `docs/mockup-tela-exercicio.html` desenha o aparelho com 300px
/// de largura; um celular real tem cerca de 390dp. Os tamanhos abaixo sao os do
/// mockup multiplicados por aproximadamente 1,3, o que preserva as proporcoes
/// entre os elementos e tira o codigo dos 11px, que num aparelho de verdade
/// ficaria abaixo do minimo legivel.
abstract final class Escala {
  static const double contador = 14;
  static const double chip = 14;
  static const double enunciado = 18;
  static const double codigo = 14;
  static const double alternativa = 15;
  static const double dica = 15;
  static const double verificar = 17;
  static const double nomeArquivo = 13;

  static const double raio = 10;
  static const double barraAltura = 10;

  /// O codigo usa entrelinha generosa: linhas grudadas atrapalham a leitura de
  /// indentacao, e indentacao em Python e sintaxe.
  static const double entrelinhaCodigo = 1.7;
}

/// Fonte monoespacada. `monospace` resolve para a fonte de sistema do aparelho,
/// em vez de depender de um arquivo embarcado que pode faltar.
const String fonteMono = 'monospace';
