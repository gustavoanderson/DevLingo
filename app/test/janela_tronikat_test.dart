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
import 'package:devlingo/ui/janela_tronikat.dart';
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
}
