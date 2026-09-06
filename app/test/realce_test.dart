import 'dart:convert';
import 'dart:io';

import 'package:devlingo/ui/models_de_token.dart';
import 'package:devlingo/ui/realce.dart';
import 'package:flutter_test/flutter_test.dart';

List<TipoDeToken> tiposDe(String linha, String lang) =>
    tokenizar(linha, lang).map((t) => t.tipo).toList();

String remontar(String linha, String lang) =>
    tokenizar(linha, lang).map((t) => t.texto).join();

void main() {
  group('a invariante que importa: nada se perde', () {
    // Um realce que come um caractere e pior que nenhum realce, e esse defeito
    // passa despercebido a olho nu. Por isso a checagem e mecanica.

    const amostras = [
      'print("Oi")',
      'nome = "Ada"',
      '    print(f"{nome} tem {idade} anos")',
      '# guarda o nome de quem vai jogar',
      'total = 47',
      'print(total ______ 2)',
      'if nota >= 9:',
      'nums = [1, 2, 3]',
      'preco = 19.90',
      'const cores = ["azul", "verde"];',
      'console.log(`Oi, \${nome}!`);',
      '// comentario com "aspas" dentro',
      'console.log("ela disse \\"oi\\"");',
      'palavra[0] = "m";',
      '',
      '   ',
      'for (let i = 0; i < 3; i++) {',
    ];

    for (final lang in ['python', 'javascript']) {
      for (final linha in amostras) {
        test('$lang: ${linha.isEmpty ? "(linha vazia)" : linha}', () {
          expect(remontar(linha, lang), linha);
        });
      }
    }

    test('vale para TODO o codigo do banco de questoes', () {
      final arquivos = Directory('assets/content')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'));

      var conferidas = 0;
      for (final f in arquivos) {
        final licao =
            json.decode(f.readAsStringSync(encoding: utf8))
                as Map<String, dynamic>;

        final blocos = <Map<String, dynamic>>[
          for (final q in licao['questions'] as List<dynamic>)
            if ((q as Map<String, dynamic>)['code'] != null)
              q['code'] as Map<String, dynamic>,
          if (licao['aula'] != null)
            for (final s in (licao['aula'] as Map<String, dynamic>)['secoes']
                as List<dynamic>)
              if ((s as Map<String, dynamic>)['code'] != null)
                s['code'] as Map<String, dynamic>,
        ];

        for (final bloco in blocos) {
          final lang = bloco['language'] as String;
          for (final linha in (bloco['content'] as String).split('\n')) {
            expect(
              remontar(linha, lang),
              linha,
              reason: 'o realce alterou uma linha de ${f.path}',
            );
            conferidas++;
          }
        }
      }

      expect(conferidas, greaterThan(100), reason: 'poucas linhas conferidas');
    });
  });

  group('classificacao em Python', () {
    test('funcao, texto e pontuacao', () {
      expect(tokenizar('print("Oi")', 'python'), [
        const Token('print', TipoDeToken.funcao),
        const Token('(', TipoDeToken.pontuacao),
        const Token('"Oi"', TipoDeToken.texto),
        const Token(')', TipoDeToken.pontuacao),
      ]);
    });

    test('palavra reservada e nome comum nao se confundem', () {
      final tipos = tokenizar('for n in nums:', 'python')
          .where((t) => t.tipo != TipoDeToken.espaco)
          .toList();
      expect(tipos[0].tipo, TipoDeToken.palavraChave); // for
      expect(tipos[1].tipo, TipoDeToken.nome); // n
      expect(tipos[2].tipo, TipoDeToken.palavraChave); // in
      expect(tipos[3].tipo, TipoDeToken.nome); // nums
    });

    test('True e False sao palavra reservada, nao nome', () {
      expect(tokenizar('True', 'python').single.tipo, TipoDeToken.palavraChave);
      expect(tokenizar('False', 'python').single.tipo, TipoDeToken.palavraChave);
    });

    test('decimal fica num token so, sem o ponto virar pontuacao', () {
      expect(tokenizar('19.90', 'python').single, const Token('19.90', TipoDeToken.numero));
    });

    test('comentario engole o resto da linha', () {
      final tokens = tokenizar('x = 1  # explica o x', 'python');
      expect(tokens.last.tipo, TipoDeToken.comentario);
      expect(tokens.last.texto, '# explica o x');
    });

    test('a indentacao vira token de espaco e sobrevive', () {
      final tokens = tokenizar('    print(n)', 'python');
      expect(tokens.first.tipo, TipoDeToken.espaco);
      expect(tokens.first.texto, '    ');
    });
  });

  group('classificacao em JavaScript', () {
    test('const e let sao palavra reservada', () {
      expect(tokenizar('const', 'javascript').single.tipo, TipoDeToken.palavraChave);
      expect(tokenizar('let', 'javascript').single.tipo, TipoDeToken.palavraChave);
    });

    test('const nao e palavra reservada em Python', () {
      expect(tokenizar('const', 'python').single.tipo, TipoDeToken.nome);
    });

    test('crase abre template string', () {
      final tokens = tokenizar('`Oi`', 'javascript');
      expect(tokens.single, const Token('`Oi`', TipoDeToken.texto));
    });

    test('comentario de duas barras', () {
      final tokens = tokenizar('// nota', 'javascript');
      expect(tokens.single.tipo, TipoDeToken.comentario);
    });

    test('cerquilha NAO e comentario em JavaScript', () {
      expect(
        tokenizar('# isto nao e comentario aqui', 'javascript')
            .any((t) => t.tipo == TipoDeToken.comentario),
        isFalse,
      );
    });
  });

  group('lacuna', () {
    test('vira token proprio, sem virar nome', () {
      final tokens = tokenizar('print(total ______ 2)', 'python');
      expect(tokens.any((t) => t.tipo == TipoDeToken.lacuna), isTrue);
      expect(
        tokens.where((t) => t.texto.contains('_')).every(
          (t) => t.tipo == TipoDeToken.lacuna,
        ),
        isTrue,
        reason: 'os sublinhados do marcador nao podem virar nome de variavel',
      );
    });

    test('sublinhado dentro de nome continua sendo nome', () {
      expect(
        tokenizar('tem_carteira = False', 'python').first,
        const Token('tem_carteira', TipoDeToken.nome),
      );
    });

    test('lacuna colada em nome nao engole o nome', () {
      final tokens = tokenizar('nome.______()', 'python');
      expect(tokens.first, const Token('nome', TipoDeToken.nome));
      expect(tokens.any((t) => t.tipo == TipoDeToken.lacuna), isTrue);
    });
  });

  group('linguagem desconhecida', () {
    test('nao quebra: tudo vira nome, pontuacao e espaco', () {
      const linha = 'SELECT * FROM tabela';
      expect(remontar(linha, 'linguagem-inexistente'), linha);
      expect(
        tokenizar(linha, 'linguagem-inexistente')
            .any((t) => t.tipo == TipoDeToken.palavraChave),
        isFalse,
      );
    });
  });
}
