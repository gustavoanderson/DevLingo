/// Realce de sintaxe: quebra uma linha de código em pedaços classificados.
///
/// É função pura, fora de qualquer widget, por dois motivos. O primeiro é que
/// dá para testá-la sem montar tela. O segundo é a invariante que o teste
/// precisa provar: **a concatenação dos tokens tem que ser idêntica à linha
/// original**. Um realce que come um caractere é pior que nenhum realce, e esse
/// tipo de defeito passa despercebido a olho nu.
///
/// A varredura é **linha a linha**, porque é assim que o bloco de código
/// desenha. Isso significa que texto ou comentário que atravesse mais de uma
/// linha não é reconhecido como tal. Nenhuma questão do banco usa isso, e
/// aceitar a limitação evita carregar estado entre linhas.
library;

import 'models_de_token.dart';

/// Palavras que a linguagem reserva para si.
const Set<String> _palavrasPython = {
  'False', 'None', 'True', 'and', 'as', 'assert', 'async', 'await', 'break',
  'class', 'continue', 'def', 'del', 'elif', 'else', 'except', 'finally',
  'for', 'from', 'global', 'if', 'import', 'in', 'is', 'lambda', 'nonlocal',
  'not', 'or', 'pass', 'raise', 'return', 'try', 'while', 'with', 'yield',
};

const Set<String> _palavrasJs = {
  'async', 'await', 'break', 'case', 'catch', 'class', 'const', 'continue',
  'default', 'delete', 'do', 'else', 'export', 'extends', 'false', 'finally',
  'for', 'function', 'if', 'import', 'in', 'instanceof', 'let', 'new', 'null',
  'of', 'return', 'super', 'switch', 'this', 'throw', 'true', 'try', 'typeof',
  'undefined', 'var', 'void', 'while', 'yield',
};

/// Marcador de lacuna. Vira pastilha na tela, e nunca aparece cru.
const String marcadorLacuna = '______';

Set<String> _palavrasDe(String linguagem) => switch (linguagem) {
  'python' => _palavrasPython,
  'javascript' || 'node' => _palavrasJs,
  _ => const {},
};

/// Como um comentário de uma linha começa, em cada linguagem.
String? _inicioDeComentario(String linguagem) => switch (linguagem) {
  'python' || 'ruby' => '#',
  'javascript' || 'node' || 'csharp' || 'golang' || 'cpp' => '//',
  'sql' => '--',
  _ => null,
};

bool _ehLetraDeNome(String c) {
  final u = c.codeUnitAt(0);
  return (u >= 0x41 && u <= 0x5A) || // A-Z
      (u >= 0x61 && u <= 0x7A) || // a-z
      u == 0x5F || // _
      (u >= 0x30 && u <= 0x39); // 0-9
}

bool _ehDigito(String c) {
  final u = c.codeUnitAt(0);
  return u >= 0x30 && u <= 0x39;
}

bool _ehAspas(String c) => c == '"' || c == "'" || c == '`';

/// Quebra uma linha em tokens classificados.
List<Token> tokenizar(String linha, String linguagem) {
  final palavras = _palavrasDe(linguagem);
  final comentario = _inicioDeComentario(linguagem);
  final tokens = <Token>[];
  final buffer = StringBuffer();

  void despejar(TipoDeToken tipo) {
    if (buffer.isEmpty) return;
    tokens.add(Token(buffer.toString(), tipo));
    buffer.clear();
  }

  var i = 0;
  while (i < linha.length) {
    final c = linha[i];

    // --- lacuna: reconhecida antes de tudo, senao os sublinhados virariam nome
    if (linha.startsWith(marcadorLacuna, i)) {
      tokens.add(const Token(marcadorLacuna, TipoDeToken.lacuna));
      i += marcadorLacuna.length;
      continue;
    }

    // --- comentario: engole o resto da linha
    if (comentario != null && linha.startsWith(comentario, i)) {
      tokens.add(Token(linha.substring(i), TipoDeToken.comentario));
      break;
    }

    // --- texto entre aspas, incluindo a aspa que abre e a que fecha
    if (_ehAspas(c)) {
      final aspa = c;
      buffer.write(c);
      i++;
      while (i < linha.length) {
        buffer.write(linha[i]);
        // Barra invertida protege o proximo caractere, inclusive outra aspa.
        if (linha[i] == r'\' && i + 1 < linha.length) {
          i++;
          buffer.write(linha[i]);
        } else if (linha[i] == aspa) {
          i++;
          break;
        }
        i++;
      }
      despejar(TipoDeToken.texto);
      continue;
    }

    // --- numero
    if (_ehDigito(c)) {
      while (i < linha.length && (_ehDigito(linha[i]) || linha[i] == '.')) {
        buffer.write(linha[i]);
        i++;
      }
      despejar(TipoDeToken.numero);
      continue;
    }

    // --- nome, palavra reservada ou funcao
    if (_ehLetraDeNome(c) && !_ehDigito(c)) {
      while (i < linha.length &&
          _ehLetraDeNome(linha[i]) &&
          !linha.startsWith(marcadorLacuna, i)) {
        buffer.write(linha[i]);
        i++;
      }
      final palavra = buffer.toString();
      if (palavras.contains(palavra)) {
        despejar(TipoDeToken.palavraChave);
      } else if (i < linha.length && linha[i] == '(') {
        // Nome colado num parentese de abertura e chamada de funcao.
        despejar(TipoDeToken.funcao);
      } else {
        despejar(TipoDeToken.nome);
      }
      continue;
    }

    // --- espaco em branco, preservado tal e qual: indentacao e sintaxe
    if (c == ' ' || c == '\t') {
      while (i < linha.length && (linha[i] == ' ' || linha[i] == '\t')) {
        buffer.write(linha[i]);
        i++;
      }
      despejar(TipoDeToken.espaco);
      continue;
    }

    // --- pontuacao e operadores
    buffer.write(c);
    i++;
    despejar(TipoDeToken.pontuacao);
  }

  return List.unmodifiable(tokens);
}
