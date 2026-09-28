/// Pinta o texto que `analise_texto.dart` quebrou em trechos.
///
/// A regra -- o que e termo, o que e negrito, o lexico de cada trilha -- mora
/// em `analise_texto.dart`, que e Dart puro e compila para o navegador. Este
/// arquivo so decide a APARENCIA de cada trecho, e reexporta o analisador para
/// quem ja importava tudo daqui continuar funcionando.
library;

import 'package:flutter/material.dart';

import 'analise_texto.dart';
import 'paleta.dart';

export 'analise_texto.dart';


/// Desenha [texto] com os termos técnicos destacados.
///
/// Devolve um `Text.rich`, e não um widget próprio: assim ele herda quebra de
/// linha, seleção e acessibilidade sem nada a mais.
///
/// O destaque é **itálico e cor**, nunca fonte monoespaçada. Trocar a família
/// no meio de um parágrafo muda a altura da linha e faz o texto ondular — e o
/// que se quer aqui é a palavra saltar, não o parágrafo se desmontar.
Widget textoComTermos(
  String texto, {
  required TextStyle estilo,
  String linguagem = '',
  TextAlign? alinhamento,
}) {
  final trechos = analisarTexto(texto, linguagem: linguagem);

  // Sem nenhum destaque, devolve o texto simples: um `Text.rich` de um span so
  // seria o mesmo desenho por um caminho mais caro.
  if (trechos.length == 1 && trechos.first.estilo == EstiloDoTrecho.normal) {
    return Text(texto, style: estilo, textAlign: alinhamento);
  }

  return Text.rich(
    TextSpan(
      children: [
        for (final t in trechos)
          TextSpan(text: t.texto, style: _estiloDe(t.estilo, estilo)),
      ],
    ),
    style: estilo,
    textAlign: alinhamento,
  );
}

TextStyle? _estiloDe(EstiloDoTrecho estilo, TextStyle base) => switch (estilo) {
  EstiloDoTrecho.normal => null,
  EstiloDoTrecho.negrito => const TextStyle(fontWeight: FontWeight.w700),
  EstiloDoTrecho.termo => const TextStyle(
    color: Paleta.termo,
    fontStyle: FontStyle.italic,
  ),
};
