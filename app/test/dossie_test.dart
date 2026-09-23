import 'package:devlingo/data/dossie.dart';
import 'package:flutter_test/flutter_test.dart';

/// Uma trilha na forma que [montarDossie] le -- a mesma que `_trilhas` entrega
/// a ponte do navegador.
Map<String, Object?> trilha(String nome, List<(String, int, int)> licoes) => {
      'nome': nome,
      'licoes': [
        for (final (id, numero, questoes) in licoes)
          {
            'id': id,
            'titulo': 'Licao $numero',
            'numero': numero,
            'nivel': 'iniciante',
            'questoes': questoes,
          },
      ],
    };

void main() {
  group('o dossie de progresso', () {
    test('conta as respondidas contra o total da trilha', () {
      final texto = montarDossie(
        [trilha('Python', [('python-beg-01', 1, 10), ('python-beg-02', 2, 10)])],
        {'python-beg-01': 10, 'python-beg-02': 4},
      );

      expect(texto, contains('trilha Python iniciante: 14 de 20'));
    });

    test('so a licao INTEIRA conta como concluida', () {
      // Licao concluida = todas as questoes respondidas. E a mesma definicao
      // que a trilha usa na tela, e o mascote nao pode contradizer a tela.
      final texto = montarDossie(
        [trilha('Python', [('python-beg-01', 1, 10), ('python-beg-02', 2, 10)])],
        {'python-beg-01': 10, 'python-beg-02': 9},
      );

      final concluidas =
          texto.split('\n').firstWhere((l) => l.contains('concluidas'));
      expect(concluidas, contains('1 Licao 1'));
      // 9 de 10 nao e concluida, por mais perto que esteja.
      expect(concluidas, isNot(contains('2 Licao 2')));
    });

    test('a licao COMECADA aparece, e e ela que diz o tema', () {
      // Faltava, e o Gustavo encontrou usando: 2 questoes de Frameworks,
      // nenhuma licao fechada, e ele perguntou sobre o que eram. O dossie so
      // listava concluidas, entao a unica linha sobre tema dizia "nenhuma
      // ainda" -- e o modelo nao tinha o que responder.
      //
      // Quem comeca uma trilha passa muito tempo com zero licoes fechadas:
      // este e o caso COMUM, nao a borda.
      final texto = montarDossie(
        [trilha('Frameworks', [('frameworks-beg-01', 1, 10)])],
        {'frameworks-beg-01': 2},
      );

      expect(texto, contains('em andamento'));
      expect(texto, contains('1 Licao 1 (2 de 10)'));
    });

    test('licao concluida NAO reaparece como em andamento', () {
      final texto = montarDossie(
        [trilha('Python', [('python-beg-01', 1, 10)])],
        {'python-beg-01': 10},
      );

      expect(texto, contains('1 Licao 1'));
      expect(texto, isNot(contains('em andamento')));
    });

    test('trilha nunca tocada fica de FORA', () {
      // Com cinco trilhas no banco e nove previstas, listar as intocadas
      // gastaria o orcamento dizendo "zero" cinco vezes -- e enterraria a
      // unica linha que sustenta um conselho.
      final texto = montarDossie(
        [
          trilha('Python', [('python-beg-01', 1, 10)]),
          trilha('JavaScript', [('javascript-beg-01', 1, 10)]),
        ],
        {'python-beg-01': 3},
      );

      expect(texto, contains('Python'));
      expect(texto, isNot(contains('JavaScript')));
    });

    test('quem comecou e nao terminou nenhuma licao diz isso em voz alta', () {
      // O silencio aqui seria lido como "nao sei", e quem comecou precisa de
      // um conselho diferente de quem terminou tres licoes.
      final texto = montarDossie(
        [trilha('Python', [('python-beg-01', 1, 10)])],
        {'python-beg-01': 3},
      );

      expect(texto, contains('nenhuma ainda'));
    });

    test('quem nao respondeu NADA produz dossie vazio', () {
      // Vazio, e nao um texto de zeros: quem chama entende isto como "nao
      // pergunte", e a ficha `meu-progresso` responde mandando entrar na
      // conta. Mandar zeros faria o modelo dar conselho sobre nada.
      final texto = montarDossie(
        [trilha('Python', [('python-beg-01', 1, 10)])],
        const {},
      );

      expect(texto, isEmpty);
    });

    test('os acertos de primeira entram quando ha, e somem quando nao', () {
      final trilhas = [trilha('Python', [('python-beg-01', 1, 10)])];
      final feitas = {'python-beg-01': 10};

      expect(montarDossie(trilhas, feitas, deCabeca: 7),
          contains('acertos de primeira: 7'));
      expect(montarDossie(trilhas, feitas), isNot(contains('acertos')));
    });

    test('o corte respeita o limite e NUNCA parte uma linha no meio', () {
      // Meia linha de progresso e um numero pela metade: o modelo leria
      // "38 de 5" e nada denunciaria. Por isso o corte e por linha inteira.
      final muitas = [
        for (var t = 0; t < 40; t++)
          trilha('Trilha numero $t que tem um nome comprido de proposito',
              [('t$t-beg-01', 1, 10)]),
      ];
      final feitas = {for (var t = 0; t < 40; t++) 't$t-beg-01': 5};

      final texto = montarDossie(muitas, feitas);

      expect(texto.length, lessThanOrEqualTo(limiteDoDossie));
      // Toda linha de contagem precisa ter chegado inteira ao fim.
      for (final linha in texto.split('\n')) {
        if (linha.startsWith('trilha ')) {
          expect(linha, endsWith('questoes respondidas'),
              reason: 'linha cortada no meio: "$linha"');
        }
      }
    });
  });
}
