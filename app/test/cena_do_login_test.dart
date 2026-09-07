import 'package:devlingo/auth/autenticacao_falsa.dart';
import 'package:devlingo/ui/cena_do_login.dart';
import 'package:devlingo/ui/tela_entrada.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> montarCena(
  WidgetTester tester, {
  bool atenuada = false,
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
        // O `Align` nao e decoracao: o filho de `pumpWidget` recebe restricoes
        // APERTADAS do tamanho da tela, e sob elas o `SizedBox` da cena e
        // ignorado -- o teste mediria 900 em vez de 150. Na tela de verdade ela
        // vive dentro de um `ListView`, que da altura livre, e por isso a
        // altura vale la. O `Align` reproduz essa condicao.
        child: Align(
          alignment: Alignment.topCenter,
          child: CenaDoLogin(atenuada: atenuada),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('a cena da tela de entrada', () {
    testWidgets('desenha e ocupa a altura prevista', (tester) async {
      await montarCena(tester);

      expect(find.byType(CenaDoLogin), findsOneWidget);
      expect(
        tester.getSize(find.byType(CenaDoLogin)).height,
        CenaDoLogin.altura,
      );
    });

    testWidgets('isola a repintura do resto da tela', (tester) async {
      // Sem o RepaintBoundary, cada quadro da cena arrastaria o formulario
      // inteiro para a mesma camada e o redesenharia junto.
      await montarCena(tester);

      expect(
        find.descendant(
          of: find.byType(CenaDoLogin),
          matching: find.byType(RepaintBoundary),
        ),
        findsWidgets,
      );
    });

    testWidgets('atenuada, continua na tela e para de animar', (tester) async {
      await montarCena(tester, atenuada: true);

      expect(find.byType(CenaDoLogin), findsOneWidget);
      // Com o relogio parado nao ha animacao pendente, entao isto retorna.
      // Com ele em `repeat()`, estouraria o limite de tempo.
      await tester.pumpAndSettle();
    });

    testWidgets('com reduzir animacoes, nao anima', (tester) async {
      await montarCena(tester, reduzirAnimacoes: true);

      expect(find.byType(CenaDoLogin), findsOneWidget);
      await tester.pumpAndSettle();
    });
  });

  group('a cena dentro da tela de entrada', () {
    testWidgets('aparece no topo do formulario', (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final auth = AutenticacaoFalsa();
      addTearDown(auth.dispose);

      await tester.pumpWidget(
        MaterialApp(home: TelaEntrada(autenticacao: auth, comCena: true)),
      );
      await tester.pump();

      expect(find.byType(CenaDoLogin), findsOneWidget);
      // O formulario continua utilizavel: a cena nao pode ter empurrado os
      // campos para fora da tela.
      expect(find.byKey(TelaEntrada.chaveEmail), findsOneWidget);
      expect(find.byKey(TelaEntrada.chaveAcao), findsOneWidget);
    });

    testWidgets('a cena tem descricao para leitor de tela', (tester) async {
      // Desenho decorativo sem rotulo e um buraco de acessibilidade numa tela
      // que ninguem pode pular.
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final auth = AutenticacaoFalsa();
      addTearDown(auth.dispose);

      await tester.pumpWidget(
        MaterialApp(home: TelaEntrada(autenticacao: auth, comCena: true)),
      );
      await tester.pump();

      expect(
        find.bySemanticsLabel(RegExp('arco-íris')),
        findsOneWidget,
      );
    });
  });
}
