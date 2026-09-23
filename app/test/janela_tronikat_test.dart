/// A janela do Tr∅nikAt no app.
///
/// O consultor é falso, e isso é a regra de "Testes de widget não enxergam I/O
/// real": `testWidgets` roda em tempo falso, e rede de verdade **nunca avança**
/// nele — um `await` em HTTP aqui travaria o arquivo inteiro em vez de falhar.
/// Já aconteceu neste repositório, e derrubou dezesseis testes junto.
///
/// O que se prova aqui é o comportamento da TELA. Que o Worker responde é
/// provado contra o Worker no ar, à mão, como o cross-play.
library;

import 'dart:typed_data';

import 'package:devlingo/data/tronikat.dart';
import 'package:devlingo/ui/botao_tronikat.dart';
import 'package:devlingo/ui/janela_tronikat.dart';
import 'package:devlingo/ui/tronikat_codec.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _ConsultorFalso implements ConsultorDoTronikat {
  _ConsultorFalso({this.resposta = 'Uma variável guarda um valor.', this.falha = false});

  final String resposta;
  final bool falha;
  final perguntas = <String>[];
  int enrolacoes = 0;

  @override
  Future<RespostaDoTronikat> perguntar(String pergunta) async {
    perguntas.add(pergunta);
    if (falha) throw Exception('sem rede');
    return RespostaDoTronikat(texto: resposta);
  }

  @override
  Future<Uint8List?> enrolacao() async {
    enrolacoes++;
    return null;
  }
}

Widget _montar(ConsultorDoTronikat c) => MaterialApp(
      home: Scaffold(body: JanelaTronikat(consultor: c, comSom: false)),
    );

void main() {
  testWidgets('a janela abre com a saudação e diz do que ele fala',
      (tester) async {
    await tester.pumpWidget(_montar(_ConsultorFalso()));
    expect(find.textContaining('Pergunte o que quiser'), findsOneWidget);
    // O ESCOPO FICA ESCRITO. Mascote que desconversa sem avisar do que fala
    // parece quebrado; dizer antes evita a pergunta que vai ser barrada.
    expect(find.text('fala do DevLingo e de programação'), findsOneWidget);
  });

  testWidgets('perguntar manda a pergunta e mostra a resposta', (tester) async {
    final c = _ConsultorFalso(resposta: 'LangChain é uma biblioteca.');
    await tester.pumpWidget(_montar(c));

    await tester.enterText(find.byKey(JanelaTronikat.chaveCampo), 'o que e LangChain?');
    await tester.tap(find.byKey(JanelaTronikat.chaveEnviar));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(c.perguntas, ['o que e LangChain?']);
    expect(find.text('LangChain é uma biblioteca.'), findsOneWidget);
    // A pergunta fica na conversa: sem ela, a resposta flutua sem o que
    // responde, e reler a conversa não faz sentido.
    expect(find.text('o que e LangChain?'), findsOneWidget);
  });

  testWidgets('ENQUANTO ele pensa, ele enrola', (tester) async {
    // A fala de enrolação é pedida ANTES de a resposta chegar, e é isso que
    // faz o silêncio de alguns segundos deixar de ser silêncio.
    final c = _ConsultorFalso();
    await tester.pumpWidget(_montar(c));
    await tester.enterText(find.byKey(JanelaTronikat.chaveCampo), 'oi');
    await tester.tap(find.byKey(JanelaTronikat.chaveEnviar));
    await tester.pump();
    expect(c.enrolacoes, 1);
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('campo vazio não chega a perguntar', (tester) async {
    final c = _ConsultorFalso();
    await tester.pumpWidget(_montar(c));
    await tester.tap(find.byKey(JanelaTronikat.chaveEnviar));
    await tester.pump(const Duration(milliseconds: 50));
    expect(c.perguntas, isEmpty);
  });

  group('sem conexão', () {
    testWidgets('ele entra em STANDBY, e não vira mensagem de erro',
        (tester) async {
      await tester.pumpWidget(_montar(_ConsultorFalso(falha: true)));
      await tester.enterText(find.byKey(JanelaTronikat.chaveCampo), 'oi');
      await tester.tap(find.byKey(JanelaTronikat.chaveEnviar));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byKey(JanelaTronikat.chaveStandby), findsOneWidget);
      expect(find.text('CONNECTION LOST'), findsOneWidget);
    });

    testWidgets('e avisa que o JOGO não caiu junto', (tester) async {
      // O recado mais importante da janela. O DevLingo funciona offline por
      // desenho, e quem vê um mascote cinza precisa saber que o resto está de
      // pé -- senão o standby de uma peça lê como o app inteiro quebrado.
      await tester.pumpWidget(_montar(_ConsultorFalso(falha: true)));
      await tester.enterText(find.byKey(JanelaTronikat.chaveCampo), 'oi');
      await tester.tap(find.byKey(JanelaTronikat.chaveEnviar));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('O jogo continua funcionando normalmente.'), findsOneWidget);
    });

    testWidgets('o campo desliga, e diz por quê', (tester) async {
      await tester.pumpWidget(_montar(_ConsultorFalso(falha: true)));
      await tester.enterText(find.byKey(JanelaTronikat.chaveCampo), 'oi');
      await tester.tap(find.byKey(JanelaTronikat.chaveEnviar));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final campo = tester.widget<TextField>(find.byKey(JanelaTronikat.chaveCampo));
      expect(campo.enabled, isFalse);
      expect(find.text('Sem conexão no momento…'), findsOneWidget);
    });

    testWidgets('dá para tentar de novo, e o standby sai', (tester) async {
      // Sem isto, quem perdeu o sinal no elevador ficaria preso na tela cinza
      // até fechar a janela.
      await tester.pumpWidget(_montar(_ConsultorFalso(falha: true)));
      await tester.enterText(find.byKey(JanelaTronikat.chaveCampo), 'oi');
      await tester.tap(find.byKey(JanelaTronikat.chaveEnviar));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.text('Tentar de novo'));
      await tester.pump();
      expect(find.byKey(JanelaTronikat.chaveStandby), findsNothing);
    });
  });

  testWidgets('a janela NÃO recebe nada da questão em que a pessoa está',
      (tester) async {
    // Isto trava uma garantia, e não um detalhe. O Gustavo escolheu a janela
    // que fala do DevLingo e de programação em vez do tutor que veria o
    // enunciado -- e o motivo foi o risco de ENTREGAR A RESPOSTA.
    //
    // O construtor só aceita o consultor e a chave de som. No dia em que
    // alguém acrescentar `questaoAtual` aqui, este teste reprova e obriga a
    // conversa a acontecer de novo.
    final c = _ConsultorFalso();
    await tester.pumpWidget(_montar(c));
    await tester.enterText(find.byKey(JanelaTronikat.chaveCampo), 'me ajuda');
    await tester.tap(find.byKey(JanelaTronikat.chaveEnviar));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // O que chega ao Worker é EXATAMENTE o que a pessoa digitou, sem enunciado,
    // sem alternativas e sem gabarito grudados.
    expect(c.perguntas.single, 'me ajuda');
  });

  /// ------------------------------------------------------------- o BOTÃO
  ///
  /// Na v1.9.0 eu pus um ícone discreto na barra de cima da escolha de trilha,
  /// e o Gustavo -- que tinha pedido a IA "no cantinho" -- instalou e relatou:
  /// "não apareceu o popup do tronikat no app". O botão ESTAVA lá; estava onde
  /// ninguém procura, e só numa das duas telas.
  ///
  /// **Não havia teste nenhum de que ele aparecia.** A suíte ficou verde
  /// porque ninguém tinha perguntado. Estes perguntam.
  group('o botão do Tr∅nikAt', () {
    testWidgets('é um FLUTUANTE, e não um ícone perdido na barra de cima',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          floatingActionButton: BotaoTronikat(),
          body: SizedBox(),
        ),
      ));
      expect(find.byKey(BotaoTronikat.chave), findsOneWidget);
      // O TIPO importa: é ele que põe o botão no canto, acima do conteúdo, em
      // vez de espremido entre os controles de sistema.
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('fica no canto INFERIOR direito', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          floatingActionButton: BotaoTronikat(),
          body: SizedBox.expand(),
        ),
      ));
      final tela = tester.getSize(find.byType(Scaffold));
      final r = tester.getRect(find.byKey(BotaoTronikat.chave));
      expect(r.center.dx, greaterThan(tela.width * .6),
          reason: 'ele tem que estar à direita, não no meio');
      expect(r.center.dy, greaterThan(tela.height * .6),
          reason: 'e embaixo -- "no cantinho" foi o pedido, e a barra de cima '
              'é onde ele não foi encontrado');
    });

    testWidgets('leva o ROSTO, e não um ícone genérico', (tester) async {
      // Quem vê o gato sabe com quem vai falar; um balãozinho de chat seria
      // qualquer aplicativo.
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(floatingActionButton: BotaoTronikat(), body: SizedBox()),
      ));
      expect(find.byType(TronikatCodec), findsOneWidget);
    });

    testWidgets('tocar nele abre a conversa', (tester) async {
      final c = _ConsultorFalso();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          floatingActionButton: BotaoTronikat(consultor: c),
          body: const SizedBox(),
        ),
      ));
      await tester.tap(find.byKey(BotaoTronikat.chave));
      // `pump` com duração, e nunca `pumpAndSettle`: o codec da janela anima em
      // `repeat()` e a árvore nunca fica parada. A primeira versão deste teste
      // estourou por isso -- mesma família do que a faixa de cenário já causou.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(JanelaTronikat), findsOneWidget);
      expect(find.textContaining('Pergunte o que quiser'), findsOneWidget);
    });
  });
}
