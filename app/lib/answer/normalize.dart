/// Normalizacao de respostas escritas.
///
/// Espelha `normalize()` em `tools/validate_questions.py`. As duas
/// implementacoes sao verificadas contra o mesmo arquivo de casos,
/// `tools/normalize_cases.json`, para que nao possam divergir em silencio.
///
/// `spaces: true` ignora **apenas espacos irrelevantes**, os que tocam
/// pontuacao ou operador. O espaco obrigatorio entre duas palavras e sempre
/// exigido. Isso foi corrigido depois de um defeito real: a versao antiga
/// removia todos os espacos, e `consttotal=0` era aceito como resposta certa
/// para `const total = 0;`.
library;

import '../models/question.dart';

final RegExp _espacosRepetidos = RegExp(r'\s+');

/// Espaco encostado em pontuacao ou operador, para ser descartado.
///
/// A classe de caracteres e escrita a mao, com `unicode: true`, em vez de usar
/// `\w`. O motivo importa: em Python 3 o `\w` e ciente de Unicode e `á` conta
/// como letra, mas em Dart o `\w` e ASCII puro e `á` **nao** conta. Uma
/// traducao literal faria `café com leite` virar `cafécom leite` aqui e
/// continuar correto no validador, que e exatamente o tipo de divergencia
/// silenciosa que o arquivo de casos compartilhado existe para pegar.
final RegExp _emVoltaDePontuacao = RegExp(
  r'\s*([^\p{L}\p{N}_\s])\s*',
  unicode: true,
);

/// Remove os pontos e virgulas do fim, todos eles, como o `rstrip(';')` do Python.
String _semPontoEVirgulaFinal(String texto) {
  var fim = texto.length;
  while (fim > 0 && texto.codeUnitAt(fim - 1) == 0x3B) {
    fim--;
  }
  return texto.substring(0, fim);
}

/// Caractere que compoe nome ou valor: letra, digito ou sublinhado.
///
/// E a mesma classe usada em [_emVoltaDePontuacao], pelo mesmo motivo de
/// Unicode: `á` precisa contar como letra.
final RegExp _caractereDeNome = RegExp(r'[\p{L}\p{N}_]', unicode: true);

/// A forma da resposta, com os nomes escondidos e a pontuacao preservada.
///
/// ```
/// print(nome)        ->  ·····(····)
/// if saldo > 0:      ->  ·· ····· > ·:
/// notas = [7, 8, 9]  ->  ····· = [·, ·, ·]
/// ```
///
/// Serve como dica de ultimo nivel nas questoes de escrita. A divisao entre o
/// que esconder e o que mostrar nao e arbitraria: **sintaxe e o que a questao
/// ensina**, e nomes de variavel sao o que o enunciado ja disse. Mostrar a
/// forma revela quantas partes a resposta tem, onde vao os parenteses e se
/// existe dois pontos no fim, sem entregar a resposta.
String esqueletoDe(String resposta) =>
    resposta.replaceAll(_caractereDeNome, '·');

/// Aplica as mesmas regras que o validador aplica antes de comparar.
String normalize(String texto, [NormalizeRules? regras]) {
  final r = regras ?? const NormalizeRules();
  var saida = texto;

  if (r.quotes) {
    saida = saida.replaceAll('"', "'");
  }

  if (r.trailingSemicolon) {
    // A ordem espelha o Python: apara o espaco do fim, depois o ponto e virgula.
    saida = _semPontoEVirgulaFinal(saida.trimRight());
  }

  if (r.spaces) {
    saida = saida.replaceAll(_espacosRepetidos, ' ').trim();
    saida = saida.replaceAllMapped(
      _emVoltaDePontuacao,
      (achado) => achado.group(1)!,
    );
  } else {
    saida = saida.trim();
  }

  if (!r.caseSensitive) {
    saida = saida.toLowerCase();
  }

  return saida;
}

/// Decide se a resposta escrita pelo usuario conta como certa.
///
/// Normaliza os dois lados e procura correspondencia exata em alguma das
/// respostas aceitas. Nada de correspondencia parcial, nada de heuristica.
/// Determinismo e o ponto: sem falso negativo, sem falso positivo.
bool accepts(String resposta, List<String> aceitas, [NormalizeRules? regras]) {
  final alvo = normalize(resposta, regras);
  return aceitas.any((aceita) => normalize(aceita, regras) == alvo);
}

/// Conveniencia para uma questao do banco.
bool respondeuCerto(Question questao, String resposta) {
  final aceitas = questao.accepted;
  if (aceitas == null) {
    throw StateError(
      '${questao.id}: respondeuCerto so vale para lacuna e escrita livre.',
    );
  }
  return accepts(resposta, aceitas, questao.normalize);
}
