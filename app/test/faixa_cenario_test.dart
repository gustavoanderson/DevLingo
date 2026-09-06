import 'package:devlingo/ui/cenario_gerado.dart';
import 'package:devlingo/ui/faixa_cenario.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Monta a faixa sozinha, com o tamanho de um celular.
Future<void> montar(
  WidgetTester tester, {
  String faixa = 'noite',
  bool congelada = false,
  bool reduzirAnimacoes = false,
}) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(disableAnimations: reduzirAnimacoes),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: FaixaCenario(faixa: faixa, congelada: congelada),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('o cenario gerado', () {
    // Estes testes olham o arquivo escrito por tools/gerar_faixas.py. Eles nao
    // provam que o desenho e bonito -- so um print prova isso -- mas provam que
    // o gerador nao emitiu um arquivo vazio ou truncado, que e o defeito
    // silencioso de qualquer geracao de codigo.

    test('as tres faixas existem, com as cores preenchidas', () {
      expect(faixas.keys, containsAll(['dia', 'tarde', 'noite']));
      for (final f in faixas.values) {
        expect(f.ceu.a, 1.0, reason: '${f.nome}: ceu opaco');
        expect(f.chao.a, 1.0, reason: '${f.nome}: chao opaco');
      }
    });

    test('so a faixa de noite tem neon, e so a de tarde tem sol', () {
      // A escolha e do gerador; o teste existe para a mudanca ser deliberada.
      expect(faixas['noite']!.temNeon, isTrue);
      expect(faixas['dia']!.temNeon, isFalse);
      expect(faixas['tarde']!.temSol, isTrue);
      expect(faixas['noite']!.temSol, isFalse);
    });

    test('a camada de tras e MAIS LENTA que a da frente', () {
      // A diferenca de velocidade e a unica coisa que produz profundidade. Se
      // as duas ficarem iguais, o parallax vira um fundo deslizante e ninguem
      // percebe o que se perdeu.
      expect(segundosLonge, greaterThan(segundosPerto));
    });

    test('o gato tem membros que se movem, e nao so formas paradas', () {
      final membros = gato.where((f) => f.tipo == TipoDeForma.membro);
      expect(membros, hasLength(4), reason: 'duas pernas e dois bracos');
      for (final m in membros) {
        expect(
          m.c,
          isNot(m.e),
          reason: 'membro com inicio e fim iguais nao se move',
        );
      }
    });

    test('nenhum caminho usa arco eliptico', () {
      // `A` num caminho ja custou uma rodada de depuracao no retrato do
      // mascote: quando a corda entre os pontos bate com o diametro, o arco
      // vira caso-limite. O gerador emite Bezier, e esta regra impede a
      // proxima pessoa de reintroduzir o problema sem perceber.
      final caminhos = [
        predioLonge,
        predioPerto,
        ...gato.map((f) => f.d).whereType<String>(),
      ];
      for (final d in caminhos) {
        expect(
          d.contains('A'),
          isFalse,
          reason: 'caminho com arco eliptico: $d',
        );
      }
    });
  });

  group('a faixa na tela', () {
    testWidgets('desenha e ocupa exatamente a altura prevista', (tester) async {
      await montar(tester);

      expect(find.byType(FaixaCenario), findsOneWidget);
      expect(
        tester.getSize(find.byType(FaixaCenario)).height,
        FaixaCenario.altura,
      );
    });

    testWidgets('isola a repintura do resto da tela', (tester) async {
      // Sem o RepaintBoundary, cada quadro do cenario arrastaria o card da
      // pergunta para a mesma camada e o redesenharia 60 vezes por segundo.
      await montar(tester);

      expect(
        find.descendant(
          of: find.byType(FaixaCenario),
          matching: find.byType(RepaintBoundary),
        ),
        findsWidgets,
      );
    });

    testWidgets('congelada, ela continua na tela e para de animar', (
      tester,
    ) async {
      // Sumir com ela quando o teclado abre faria o layout pular no meio da
      // digitacao, que e pior que o movimento.
      await montar(tester, congelada: true);

      expect(find.byType(FaixaCenario), findsOneWidget);
      // Com o relogio parado nao ha animacao pendente, entao isto retorna.
      // Com ele girando em `repeat()`, estouraria o limite de tempo.
      await tester.pumpAndSettle();
    });

    testWidgets('com reduzir animacoes, nao anima', (tester) async {
      await montar(tester, reduzirAnimacoes: true);

      expect(find.byType(FaixaCenario), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('faixa desconhecida cai na noturna em vez de quebrar', (
      tester,
    ) async {
      // O nome vem de fora e um dia pode vir errado. Tela em branco por causa
      // de uma string e pior que uma faixa diferente da esperada.
      await montar(tester, faixa: 'inexistente', congelada: true);

      expect(find.byType(FaixaCenario), findsOneWidget);
    });
  });
}
