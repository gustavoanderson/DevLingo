/// Quebra um texto corrido em trechos com estilo, para enunciados e aulas.
///
/// É função pura, fora de qualquer widget, pelos mesmos dois motivos de
/// [realce.dart]: dá para testar sem montar tela, e existe uma **invariante**
/// que só um teste garante — a concatenação dos trechos tem que ser idêntica ao
/// texto original **sem os marcadores**. Um analisador que come um caractere é
/// pior que nenhum, e esse defeito passa despercebido a olho nu.
///
/// ## Duas fontes de destaque, e a ordem entre elas importa
///
/// 1. **Marcação explícita** no conteúdo: `` `assim` `` vira termo técnico,
///    `**assim**` vira negrito. É o autor decidindo, e ganha sempre
/// 2. **Léxico automático**: palavras técnicas conhecidas da linguagem, fora
///    de marcação, viram termo sozinhas
///
/// A marcação vem primeiro porque é a única forma de dizer "aqui é código" num
/// caso que o léxico erraria — e há casos assim, medidos no banco.
///
/// ## Por que o léxico não pode ser a lista do realce de sintaxe
///
/// Seria a escolha óbvia: `realce.dart` já tem as palavras reservadas de cada
/// linguagem. Mas ele classifica **código**, onde toda palavra é código. Aqui o
/// texto é português, e duas palavras reservadas **também são português**:
///
/// - `as` apareceu 6 vezes no banco, e **todas as 6 eram artigo** ("dispensa as
///   chaves", "atropelar as outras")
/// - `for` apareceu 4 vezes, e **2 eram o verbo** ("se for verdadeira")
///
/// Destacar essas como código ensinaria errado justamente onde o aluno está
/// aprendendo. Elas ficam de fora do léxico e dependem de crase quando forem
/// mesmo o comando. `do` sai pelo mesmo motivo.
library;

import 'package:flutter/material.dart';

import 'paleta.dart';

/// Como um pedaço de texto deve ser pintado.
enum EstiloDoTrecho {
  /// Corpo do texto, sem destaque.
  normal,

  /// Ênfase do autor, com `**dois asteriscos**`.
  negrito,

  /// Nome de função, tipo ou palavra reservada. Itálico e cor própria.
  termo,
}

class TrechoDeTexto {
  const TrechoDeTexto(this.texto, this.estilo);

  final String texto;
  final EstiloDoTrecho estilo;

  bool get vazio => texto.isEmpty;

  @override
  String toString() => '${estilo.name}(${texto.length}): $texto';

  @override
  bool operator ==(Object other) =>
      other is TrechoDeTexto &&
      other.texto == texto &&
      other.estilo == estilo;

  @override
  int get hashCode => Object.hash(texto, estilo);
}

/// Termos que o aluno precisa reconhecer como sendo da linguagem, e não do
/// português.
///
/// Só entram aqui palavras que **não existem em português**. Ver o comentário
/// da biblioteca: `as`, `for` e `do` ficaram de fora por colidirem, e o autor
/// as marca com crase quando forem mesmo o comando.
const Set<String> _termosPython = {
  'None', 'True', 'False', 'and', 'append', 'bool', 'break', 'capitalize',
  'class', 'continue', 'def', 'dict', 'elif', 'else', 'float', 'if', 'import',
  'in', 'input', 'int', 'is', 'lambda', 'len', 'list', 'lower', 'not', 'or',
  'pass', 'print', 'range', 'replace', 'return', 'split', 'str', 'strip',
  'try', 'tuple', 'type', 'upper', 'while',
};

const Set<String> _termosJs = {
  'Array', 'Boolean', 'Number', 'Object', 'String', 'array', 'boolean',
  'break', 'case', 'catch', 'class', 'console', 'const', 'default', 'else',
  'false', 'function', 'if', 'in', 'includes', 'indexOf', 'instanceof',
  'length', 'let', 'log', 'new', 'null', 'number', 'object', 'of', 'pop',
  'push', 'return', 'slice', 'split', 'string', 'switch', 'this', 'throw',
  'toLowerCase', 'toUpperCase', 'true', 'try', 'typeof', 'undefined', 'var',
  'while',
};

/// Vocabulario do curso de backend.
///
/// Aqui os termos sao quase todos siglas e substantivos ingleses, e nenhum
/// colide com o portugues -- ao contrario de `as` e `for` nas linguagens. Foi
/// o receio que nao se confirmou: o jargao de engenharia ja e todo ASCII, o
/// que tambem deixa as questoes de escrita viaveis neste curso.
///
/// `cache` fica de fora por um motivo especifico: virou palavra portuguesa
/// corrente ("o cache do navegador"), e destaca-la em todo paragrafo faria o
/// texto piscar. Ela entra por crase quando for o conceito sendo nomeado.
const Set<String> _termosBackend = {
  'ACID', 'API', 'APIs', 'CDN', 'CORS', 'CRUD', 'CSP', 'DELETE', 'DNS', 'GET',
  'GraphQL', 'HTTP', 'HTTPS', 'JSON', 'JWT', 'NoSQL', 'OAuth', 'PATCH', 'POST',
  'PUT', 'REST', 'SQL', 'SSL', 'TLS', 'URL', 'XML', 'backend', 'endpoint',
  'endpoints', 'frontend', 'header', 'headers', 'host', 'localhost', 'payload',
  'query', 'request', 'response', 'session', 'sharding', 'status', 'timeout',
  'token', 'tokens', 'webhook',
};

Set<String> termosDe(String linguagem) => switch (linguagem) {
  'python' => _termosPython,
  'javascript' || 'node' => _termosJs,
  'backend' => _termosBackend,
  _ => const {},
};

bool _ehLetraDeNome(int u) =>
    (u >= 0x41 && u <= 0x5A) || // A-Z
    (u >= 0x61 && u <= 0x7A) || // a-z
    (u >= 0x30 && u <= 0x39) || // 0-9
    u == 0x5F; // _

/// Quebra [texto] em trechos estilizados.
///
/// Passar `linguagem` vazia desliga o léxico automático, mas **não** a
/// marcação: uma linguagem sem tokenizador continua com o negrito e as crases
/// do autor funcionando. Isso importa porque o banco prevê nove linguagens que
/// ainda não têm léxico nenhum.
List<TrechoDeTexto> analisarTexto(String texto, {String linguagem = ''}) {
  final marcados = _separarMarcacao(texto);
  final termos = termosDe(linguagem);
  if (termos.isEmpty) return _juntarVizinhos(marcados);

  final saida = <TrechoDeTexto>[];
  for (final trecho in marcados) {
    if (trecho.estilo != EstiloDoTrecho.normal) {
      saida.add(trecho);
      continue;
    }
    saida.addAll(_aplicarLexico(trecho.texto, termos));
  }
  return _juntarVizinhos(saida);
}

/// Tira `**negrito**` e `` `termo` `` do texto, virando trechos.
///
/// Marcador sem par fecha **não** é erro aqui: ele fica como texto comum, e o
/// aluno vê o asterisco em vez de perder metade do parágrafo. Quem reprova
/// marcador desbalanceado é o validador do banco, antes de o conteúdo existir
/// no app — errar em silêncio na tela seria pior que a crase aparecendo.
List<TrechoDeTexto> _separarMarcacao(String texto) {
  final saida = <TrechoDeTexto>[];
  final buffer = StringBuffer();
  var i = 0;

  void despejar() {
    if (buffer.isNotEmpty) {
      saida.add(TrechoDeTexto(buffer.toString(), EstiloDoTrecho.normal));
      buffer.clear();
    }
  }

  while (i < texto.length) {
    final negrito = texto.startsWith('**', i);
    final crase = texto[i] == '`';

    if (negrito || crase) {
      final abertura = negrito ? '**' : '`';
      final fim = texto.indexOf(abertura, i + abertura.length);
      // Fechamento colado na abertura (`` ou ****) nao delimita nada.
      if (fim > i + abertura.length) {
        despejar();
        saida.add(
          TrechoDeTexto(
            texto.substring(i + abertura.length, fim),
            negrito ? EstiloDoTrecho.negrito : EstiloDoTrecho.termo,
          ),
        );
        i = fim + abertura.length;
        continue;
      }
    }

    buffer.write(texto[i]);
    i++;
  }

  despejar();
  return saida;
}

/// Marca as palavras do léxico dentro de um trecho sem marcação.
List<TrechoDeTexto> _aplicarLexico(String texto, Set<String> termos) {
  final saida = <TrechoDeTexto>[];
  var inicioComum = 0;
  var i = 0;

  while (i < texto.length) {
    if (!_ehLetraDeNome(texto.codeUnitAt(i))) {
      i++;
      continue;
    }

    final inicio = i;
    while (i < texto.length && _ehLetraDeNome(texto.codeUnitAt(i))) {
      i++;
    }
    final palavra = texto.substring(inicio, i);

    // `console.log` e uma coisa so, e nao duas palavras coladas num ponto.
    // Sem esta juncao, o ponto ficaria em cor de texto no meio do termo.
    var fim = i;
    while (fim < texto.length &&
        texto[fim] == '.' &&
        fim + 1 < texto.length &&
        _ehLetraDeNome(texto.codeUnitAt(fim + 1))) {
      var j = fim + 1;
      while (j < texto.length && _ehLetraDeNome(texto.codeUnitAt(j))) {
        j++;
      }
      if (!termos.contains(texto.substring(fim + 1, j))) break;
      fim = j;
    }

    if (!termos.contains(palavra)) continue;

    if (inicio > inicioComum) {
      saida.add(
        TrechoDeTexto(
          texto.substring(inicioComum, inicio),
          EstiloDoTrecho.normal,
        ),
      );
    }
    saida.add(
      TrechoDeTexto(texto.substring(inicio, fim), EstiloDoTrecho.termo),
    );
    inicioComum = fim;
    i = fim;
  }

  if (inicioComum < texto.length) {
    saida.add(
      TrechoDeTexto(texto.substring(inicioComum), EstiloDoTrecho.normal),
    );
  }
  return saida;
}

/// Funde trechos vizinhos de mesmo estilo, e descarta os vazios.
///
/// Sem isto, um parágrafo comum viraria dezenas de trechos idênticos, e cada um
/// vira um `TextSpan` na tela — trabalho de layout em troca de nada.
List<TrechoDeTexto> _juntarVizinhos(List<TrechoDeTexto> trechos) {
  final saida = <TrechoDeTexto>[];
  for (final t in trechos) {
    if (t.vazio) continue;
    if (saida.isNotEmpty && saida.last.estilo == t.estilo) {
      saida[saida.length - 1] = TrechoDeTexto(
        saida.last.texto + t.texto,
        t.estilo,
      );
      continue;
    }
    saida.add(t);
  }
  return saida;
}

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
