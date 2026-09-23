import 'package:devlingo/ui/botao_tronikat.dart';
import 'package:devlingo/ui/chamada_tronikat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _montar({bool comChamada = true, bool quieto = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: quieto),
        child: Scaffold(
          floatingActionButton: BotaoTronikat(comChamada: comChamada),
        ),
      ),
    );

/// Onde o primeiro pontinho está pintado AGORA.
///
/// `getRect` já passou pela transformação, ao contrário de `getSize` -- a
/// mesma distinção que o teste do cabeçalho da trilha precisou fazer, quando
/// eu medi altura achando que media encolhimento.
Rect _ponto(WidgetTester t) =>
    t.getRect(find.byKey(ChamadaTronikat.chavePonto));

/// O salto do pontinho DENTRO do balão.
///
/// Medir a posição absoluta não serve, e a sonda provou: congelando o salto
/// do pontinho, o teste continuou passando — porque o **balão inteiro** bóia,
/// e a posição absoluta se mexia por causa dele. O teste dizia medir os
/// pontinhos e media o balão.
///
/// É a mesma família do teste com `return` cedo que este repositório já
/// registra: ele passava sem provar nada.
double _saltoRelativo(WidgetTester t) =>
    _ponto(t).top - t.getRect(find.byKey(ChamadaTronikat.chave)).top;

void main() {
  group('a chamada de tres pontinhos', () {
    testWidgets('aparece acima do botao quando o app a liga', (tester) async {
      await tester.pumpWidget(_montar());
      await tester.pump();

      expect(find.byKey(ChamadaTronikat.chave), findsOneWidget);
      // ACIMA, e nao ao lado: o balao aponta para o botao.
      expect(_ponto(tester).center.dy,
          lessThan(tester.getRect(find.byKey(BotaoTronikat.chave)).top));
    });

    testWidgets('OS PONTINHOS SE MOVEM de verdade', (tester) async {
      // Medir o MOVIMENTO, e nao a existencia. Elemento que so existe para
      // pintar pode resolver para zero sem nada denunciar -- foi assim que a
      // barra de desfechos das estatisticas ficou invisivel com todos os
      // rotulos certos. Aqui o risco irmao e um balao que desenha parado.
      await tester.pumpWidget(_montar());
      await tester.pump();

      final posicoes = <double>{};
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 90));
        posicoes.add(_saltoRelativo(tester));
      }

      expect(posicoes.length, greaterThan(3),
          reason: 'o pontinho ficou parado em ${posicoes.length} posicao(oes)');
      // E ele tem tamanho: um ponto de altura zero tambem "se moveria".
      expect(_ponto(tester).height, greaterThan(4));
    });

    testWidgets('os tres pontinhos NAO saltam juntos', (tester) async {
      // O atraso escalonado e o que faz aquilo ler como "digitando". Com os
      // tres no mesmo tempo, seriam tres luzes piscando.
      await tester.pumpWidget(_montar());
      await tester.pump(const Duration(milliseconds: 120));

      final alturas = tester
          .widgetList<Transform>(find.descendant(
            of: find.byKey(ChamadaTronikat.chave),
            matching: find.byType(Transform),
          ))
          .map((t) => t.transform.getTranslation().y.toStringAsFixed(3))
          .toSet();

      expect(alturas.length, greaterThan(1),
          reason: 'os tres pontinhos estao na mesma altura');
    });

    testWidgets('some ao tocar, e nao volta ao fechar a janela',
        (tester) async {
      // Aviso que nao para de avisar vira ruido. Quem ja sabe que ele existe
      // nao precisa do balao pulsando para sempre.
      await tester.pumpWidget(_montar());
      await tester.pump();
      expect(find.byKey(ChamadaTronikat.chave), findsOneWidget);

      await tester.tap(find.byKey(BotaoTronikat.chave));
      await tester.pump();
      // Fecha a folha que o toque abriu.
      Navigator.of(tester.element(find.byKey(BotaoTronikat.chave))).pop();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byKey(ChamadaTronikat.chave), findsNothing);
    });

    testWidgets('com "reduzir animacoes" o balao FICA, so para de se mexer',
        (tester) async {
      // Sumir com ele tiraria a descoberta de quem ligou a opcao; o balao
      // parado continua dizendo o que tinha para dizer.
      await tester.pumpWidget(_montar(quieto: true));
      await tester.pump();

      expect(find.byKey(ChamadaTronikat.chave), findsOneWidget);

      final antes = _saltoRelativo(tester);
      await tester.pump(const Duration(milliseconds: 400));
      expect(_saltoRelativo(tester), antes);
    });

    testWidgets('desligada, ela nao existe -- e e assim nos testes',
        (tester) async {
      // Animacao em `repeat()` faz `pumpAndSettle` esperar para sempre, e isso
      // ja derrubou doze testes da tela de entrada de uma vez. Por isso o
      // padrao e falso, e quem liga e o app.
      await tester.pumpWidget(_montar(comChamada: false));
      await tester.pumpAndSettle();

      expect(find.byKey(ChamadaTronikat.chave), findsNothing);
      expect(find.byKey(BotaoTronikat.chave), findsOneWidget);
    });
  });
}
