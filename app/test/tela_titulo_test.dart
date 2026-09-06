import 'package:devlingo/ui/som.dart';
import 'package:devlingo/ui/tela_titulo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Monta a tela de titulo isolada.
///
/// Nao ha banco nem progresso aqui: a tela recebe `pronto` como bandeira e
/// `aoIniciar` como callback justamente para poder ser testada sem I/O. Foi
/// esse desenho que evitou repetir o teste de widget que travou dez minutos
/// esperando o sqflite avancar dentro da zona de tempo falso.
Future<void> montar(
  WidgetTester tester, {
  required bool pronto,
  Sineta? sineta,
  VoidCallback? aoIniciar,
  bool reduzirAnimacoes = false,
}) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduzirAnimacoes),
        child: TelaTitulo(
          pronto: pronto,
          sineta: sineta,
          aoIniciar: aoIniciar ?? () {},
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('a tela de titulo', () {
    testWidgets('mostra a chamada de START e a arte do mascote', (
      tester,
    ) async {
      await montar(tester, pronto: true);

      expect(find.byKey(const Key('titulo-start')), findsOneWidget);
      expect(find.byKey(const Key('titulo-mascote')), findsOneWidget);
      expect(find.text('DevLingo'), findsNWidgets(3));
    });

    testWidgets('tocar com a carga pronta entra na hora', (tester) async {
      var entrou = 0;
      await montar(tester, pronto: true, aoIniciar: () => entrou++);

      await tester.tap(find.byType(TelaTitulo));
      await tester.pump();

      expect(entrou, 1);
    });

    testWidgets('tocar toca a ficha, e nao a fanfarra', (tester) async {
      // Contadores separados por som: um contador so passaria neste teste
      // mesmo se a tela tocasse a fanfarra de acerto por engano.
      final sineta = SinetaMuda();
      await montar(tester, pronto: true, sineta: sineta);

      await tester.tap(find.byType(TelaTitulo));
      await tester.pump();

      expect(sineta.fichas, 1);
      expect(sineta.toques, 0);
    });

    testWidgets('a tela inteira e o alvo do toque', (tester) async {
      // Nao ha botao: o usuario toca em qualquer lugar. Este teste bate no
      // canto superior esquerdo, longe da frase.
      var entrou = 0;
      await montar(tester, pronto: true, aoIniciar: () => entrou++);

      await tester.tapAt(const Offset(12, 12));
      await tester.pump();

      expect(entrou, 1);
    });
  });

  group('quando a carga ainda nao terminou', () {
    testWidgets('o toque nunca e ignorado: a ficha toca mesmo assim', (
      tester,
    ) async {
      final sineta = SinetaMuda();
      var entrou = 0;
      await montar(
        tester,
        pronto: false,
        sineta: sineta,
        aoIniciar: () => entrou++,
      );

      await tester.tap(find.byType(TelaTitulo));
      await tester.pump();

      expect(sineta.fichas, 1, reason: 'o toque foi recebido');
      expect(entrou, 0, reason: 'mas ainda nao ha o que mostrar');
      expect(find.byKey(const Key('titulo-carregando')), findsOneWidget);
      expect(find.byKey(const Key('titulo-start')), findsNothing);
    });

    testWidgets('quando a carga termina, entra sozinho', (tester) async {
      var entrou = 0;
      final sineta = SinetaMuda();

      await montar(
        tester,
        pronto: false,
        sineta: sineta,
        aoIniciar: () => entrou++,
      );
      await tester.tap(find.byType(TelaTitulo));
      await tester.pump();
      expect(entrou, 0);

      // O pai reconstroi com a carga pronta, como faz o FutureBuilder.
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(),
            child: TelaTitulo(
              pronto: true,
              sineta: sineta,
              aoIniciar: () => entrou++,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(entrou, 1, reason: 'o START pedido antes da hora foi honrado');
      expect(sineta.fichas, 1, reason: 'sem tocar a ficha uma segunda vez');
    });

    testWidgets('sem toque nenhum, a carga terminar NAO entra sozinho', (
      tester,
    ) async {
      // A porta do fliperama nao se abre sozinha: quem entra e quem aperta.
      var entrou = 0;
      await montar(tester, pronto: false, aoIniciar: () => entrou++);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(),
            child: TelaTitulo(pronto: true, aoIniciar: () => entrou++),
          ),
        ),
      );
      await tester.pump();

      expect(entrou, 0);
      expect(find.byKey(const Key('titulo-start')), findsOneWidget);
    });
  });

  group('reduzir animacoes', () {
    testWidgets('para a respiracao e o piscar, e a tela continua inteira', (
      tester,
    ) async {
      var entrou = 0;
      await montar(
        tester,
        pronto: true,
        reduzirAnimacoes: true,
        aoIniciar: () => entrou++,
      );

      // Sem animacao em curso, `pumpAndSettle` retorna. Com a respiracao
      // rodando em `repeat()` ele estouraria o limite de tempo -- e e por isso
      // que este teste prova o desligamento sem precisar espiar o controlador.
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('titulo-start')), findsOneWidget);
      expect(find.byKey(const Key('titulo-mascote')), findsOneWidget);

      await tester.tap(find.byType(TelaTitulo));
      await tester.pump();
      expect(entrou, 1, reason: 'sem animacao, o START continua funcionando');
    });

    testWidgets('a frase fica sempre visivel, nunca apagada', (tester) async {
      await montar(tester, pronto: true, reduzirAnimacoes: true);

      // Nao ha Opacity piscando entre a frase e a tela: o texto e desenhado
      // direto. Se a piscada tivesse ficado ligada, haveria um Opacity com
      // valor 0 em algum quadro, e o usuario que pediu para reduzir animacoes
      // veria exatamente o que pediu para nao ver.
      final piscando = find.ancestor(
        of: find.byKey(const Key('titulo-start')),
        matching: find.byType(Opacity),
      );
      expect(piscando, findsNothing);
    });
  });
}
