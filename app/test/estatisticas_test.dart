import 'package:devlingo/data/progresso.dart';
import 'package:devlingo/ui/tela_estatisticas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Um resumo com os campos que o teste quiser, e o resto zerado.
ResumoDoJogador resumo({
  int respondidas = 0,
  int deCabeca = 0,
  int reveladas = 0,
  int tentativas = 0,
  int comDica = 0,
  Duration tempoMedido = Duration.zero,
  int questoesComTempo = 0,
  int partidas = 0,
  int diasEstudados = 0,
}) => ResumoDoJogador(
  respondidas: respondidas,
  deCabeca: deCabeca,
  reveladas: reveladas,
  tentativas: tentativas,
  comDica: comDica,
  tempoMedido: tempoMedido,
  questoesComTempo: questoesComTempo,
  partidas: partidas,
  diasEstudados: diasEstudados,
);

Future<void> montar(
  WidgetTester tester,
  ResumoDoJogador r, {
  List<CustoDoTopico> topicos = const [],
}) async {
  await tester.pumpWidget(
    MaterialApp(home: TelaEstatisticas(resumo: r, topicos: topicos)),
  );
  await tester.pumpAndSettle();
}

/// Altura da barra de desfechos. Espelha `_Desfechos.altura`, que e privada.
const double alturaDaBarra = 12;

void main() {
  group('quem ainda nao jogou', () {
    testWidgets('ve um convite, e nenhum numero', (tester) async {
      await montar(tester, resumo());

      expect(find.byKey(TelaEstatisticas.chaveVazio), findsOneWidget);

      // Um "0%" aqui pareceria um resultado ruim quando nao ha resultado
      // nenhum. Este teste existe porque essa e a forma mais facil de a tela
      // cobrar de alguem que ainda nao teve chance.
      expect(find.textContaining('0%'), findsNothing);
      expect(find.textContaining('0 de 0'), findsNothing);
    });

    testWidgets('numa tela alta, o recado nao afunda para o meio', (
      tester,
    ) async {
      // Defeito visto num Xiaomi 15T Pro, de 2772 pixels de altura: com
      // `Center`, sobravam quase mil pixels de nada entre o titulo e a
      // mensagem, e a tela lia como travada carregando. No emulador, de tela
      // curta, o mesmo codigo ficava bem -- por isso a suite nao pegou.
      //
      // A proporcao abaixo imita aquele aparelho em dp.
      tester.view.physicalSize = const Size(440, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await montar(tester, resumo());

      final meio = tester.getCenter(find.text('Ainda não há o que mostrar')).dy;
      expect(
        meio,
        lessThan(1000 / 3),
        reason: 'o recado tem que ficar no terco de cima, perto do titulo; '
            'centralizado ele afunda quanto mais alta for a tela',
      );
    });
  });

  group('os numeros de topo', () {
    testWidgets('mostram respondidas, taxa e dias', (tester) async {
      await montar(
        tester,
        resumo(
          respondidas: 20,
          deCabeca: 15,
          reveladas: 2,
          tentativas: 28,
          partidas: 20,
          diasEstudados: 4,
          questoesComTempo: 20,
          tempoMedido: const Duration(seconds: 20 * 42),
        ),
      );

      expect(find.byKey(TelaEstatisticas.chaveVazio), findsNothing);
      expect(find.text('20'), findsOneWidget);
      expect(find.text('75%'), findsOneWidget); // 15 de 20
      expect(find.text('4'), findsOneWidget);
      expect(find.text('42s'), findsOneWidget);
    });

    testWidgets('dizem que o tempo nao foi medido, em vez de mostrar zero', (
      tester,
    ) async {
      // Partidas anteriores a versao 4 do banco nao tem tempo. Gravar zero
      // seria mais simples e mentiria na media; a tela tem que dizer o nulo em
      // voz alta, que e a unica maneira de ela nao mentir.
      await montar(
        tester,
        resumo(respondidas: 6, deCabeca: 4, partidas: 6, questoesComTempo: 0),
      );

      expect(find.text('tempo ainda não medido'), findsOneWidget);
      expect(find.text('0s'), findsNothing);
      expect(find.text('—'), findsOneWidget);
    });

    testWidgets('o dia no singular nao vira "1 dias"', (tester) async {
      await montar(tester, resumo(respondidas: 3, deCabeca: 3, diasEstudados: 1));
      expect(find.text('dia de estudo'), findsOneWidget);
    });
  });

  group('como as questoes terminaram', () {
    testWidgets('reparte o total em tres, e o que sobra e a insistencia', (
      tester,
    ) async {
      await montar(
        tester,
        resumo(respondidas: 10, deCabeca: 6, reveladas: 1, tentativas: 15),
      );

      expect(find.text('6 de primeira'), findsOneWidget);
      expect(find.text('3 insistindo'), findsOneWidget); // 10 - 6 - 1
      expect(find.text('1 vimos juntos'), findsOneWidget);
    });

    testWidgets('as fatias tem altura de verdade, e nao zero', (tester) async {
      // Defeito visto num Xiaomi 15T Pro: a barra estava INVISIVEL. Onde
      // deviam estar tres faixas coloridas havia 105 mil pixels da cor do
      // fundo, e a legenda logo abaixo desenhava normalmente.
      //
      // A causa e sutil: `ColoredBox` sem filho resolve para
      // `constraints.smallest`. O `Expanded` torna a largura obrigatoria, mas
      // o alinhamento padrao do `Row` passa a ALTURA frouxa -- e `smallest`
      // escolhe zero. A barra existia, ocupava espaco no layout, e nao tinha
      // altura nenhuma.
      //
      // Nenhum teste de texto pegaria isso: os rotulos continuavam certos.
      await montar(
        tester,
        resumo(respondidas: 10, deCabeca: 7, reveladas: 1, tentativas: 14),
      );

      final caixas = find.descendant(
        of: find.byKey(TelaEstatisticas.chaveBarra),
        matching: find.byType(ColoredBox),
      );
      expect(caixas, findsNWidgets(3));

      for (var i = 0; i < 3; i++) {
        final tamanho = tester.getSize(caixas.at(i));
        expect(
          tamanho.height,
          alturaDaBarra,
          reason: 'a fatia $i tem altura ${tamanho.height}; zero a torna '
              'invisivel sem quebrar teste de texto nenhum',
        );
        expect(tamanho.width, greaterThan(0), reason: 'fatia $i sem largura');
      }
    });

    testWidgets('a fatia vazia nao aparece', (tester) async {
      await montar(tester, resumo(respondidas: 5, deCabeca: 5, tentativas: 5));

      expect(find.text('5 de primeira'), findsOneWidget);
      expect(find.textContaining('insistindo'), findsNothing);
      expect(find.textContaining('vimos juntos'), findsNothing);
    });

    testWidgets('nunca escreve que o aluno errou', (tester) async {
      // A mecanica inteira foi desenhada para nao punir -- a tela de exercicio
      // diz AINDA NAO e VAMOS JUNTOS, nunca ERRADO. Estatistica que cobra e a
      // mesma punicao em forma de numero, e este teste tranca isso.
      await montar(
        tester,
        resumo(
          respondidas: 10,
          deCabeca: 2,
          reveladas: 5,
          tentativas: 30,
          comDica: 4,
          partidas: 14,
        ),
        topicos: const [
          CustoDoTopico(
            topic: 'condicionais',
            questoes: 4,
            tentativas: 12,
            reveladas: 3,
          ),
        ],
      );

      for (final palavra in ['errou', 'erros', 'errado', 'falhou', 'pior']) {
        expect(
          find.textContaining(palavra, findRichText: true),
          findsNothing,
          reason: 'a tela nao pode cobrar: encontrou "$palavra"',
        );
      }
    });
  });

  group('onde mais insistiu', () {
    testWidgets('lista os topicos que custaram mais de uma tentativa', (
      tester,
    ) async {
      await montar(
        tester,
        resumo(respondidas: 9, deCabeca: 4, tentativas: 16),
        topicos: const [
          CustoDoTopico(
            topic: 'condicionais',
            questoes: 4,
            tentativas: 10,
            reveladas: 1,
          ),
          CustoDoTopico(
            topic: 'strings',
            questoes: 5,
            tentativas: 6,
            reveladas: 0,
          ),
        ],
      );

      expect(find.text('condicionais'), findsOneWidget);
      expect(find.text('2.5'), findsOneWidget);
      expect(find.text('strings'), findsOneWidget);
      expect(find.text('1.2'), findsOneWidget);
    });

    testWidgets('esconde o topico que saiu de primeira todas as vezes', (
      tester,
    ) async {
      // Media 1,0 significa "aqui voce foi bem". Listar isso encheria a tela
      // de linhas que nao ajudam a escolher o que revisar, que e a unica
      // pergunta que esta lista responde.
      await montar(
        tester,
        resumo(respondidas: 5, deCabeca: 5, tentativas: 5),
        topicos: const [
          CustoDoTopico(
            topic: 'saida',
            questoes: 5,
            tentativas: 5,
            reveladas: 0,
          ),
        ],
      );

      expect(find.text('saida'), findsNothing);
      expect(
        find.text('Nenhum tópico exigiu mais de uma tentativa até agora.'),
        findsOneWidget,
      );
    });

    testWidgets('corta a lista, e mantem os mais caros', (tester) async {
      final muitos = [
        for (var i = 0; i < 10; i++)
          CustoDoTopico(
            topic: 'topico$i',
            questoes: 2,
            // O primeiro e o mais caro: `custoPorTopico` ja devolve ordenado.
            tentativas: 40 - i * 2,
            reveladas: 0,
          ),
      ];
      await montar(
        tester,
        resumo(respondidas: 20, deCabeca: 5, tentativas: 310),
        topicos: muitos,
      );

      expect(find.text('topico0'), findsOneWidget);
      expect(find.text('topico5'), findsOneWidget);
      expect(find.text('topico6'), findsNothing);
    });
  });

  group('o rodape diz o que os numeros escondem', () {
    testWidgets('avisa que refazer conta como partida', (tester) async {
      await montar(
        tester,
        resumo(respondidas: 10, deCabeca: 7, tentativas: 13, partidas: 17),
      );

      expect(
        find.textContaining('17 vezes em 10 questões'),
        findsOneWidget,
      );
    });

    testWidgets('avisa quantas ficam fora da media de tempo', (tester) async {
      await montar(
        tester,
        resumo(
          respondidas: 10,
          deCabeca: 7,
          tentativas: 13,
          partidas: 10,
          questoesComTempo: 6,
          tempoMedido: const Duration(seconds: 6 * 30),
        ),
      );

      expect(find.textContaining('4 questões são de antes'), findsOneWidget);
    });

    testWidgets('some quando nao ha nada a esclarecer', (tester) async {
      await montar(
        tester,
        resumo(
          respondidas: 8,
          deCabeca: 8,
          tentativas: 8,
          partidas: 8,
          questoesComTempo: 8,
          tempoMedido: const Duration(seconds: 8 * 12),
        ),
      );

      expect(find.byKey(TelaEstatisticas.chaveRodape), findsNothing);
      expect(find.textContaining('fora da média'), findsNothing);
      expect(find.textContaining('refazer'), findsNothing);
      expect(find.textContaining('pediu a dica'), findsNothing);
    });
  });

  group('voltar', () {
    testWidgets('a seta so aparece quando ha para onde voltar', (tester) async {
      await montar(tester, resumo());
      expect(find.byKey(TelaEstatisticas.chaveVoltar), findsNothing);

      var voltou = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: TelaEstatisticas(
            resumo: resumo(),
            topicos: const [],
            aoVoltar: () => voltou++,
          ),
        ),
      );
      await tester.tap(find.byKey(TelaEstatisticas.chaveVoltar));
      expect(voltou, 1);
    });
  });
}
