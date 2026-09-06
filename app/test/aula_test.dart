import 'dart:convert';

import 'package:devlingo/answer/sessao_questao.dart';
import 'package:devlingo/data/progresso.dart';
import 'package:devlingo/models/lesson.dart';
import 'package:devlingo/models/question.dart';
import 'package:devlingo/ui/fluxo_da_licao.dart';
import 'package:devlingo/ui/tela_aula.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const String _questao = '''
{
  "id": "python-beg-0101",
  "topic": "saida",
  "prompt": "Qual funcao exibe algo na tela?",
  "answerType": "multipleChoice",
  "options": [
    {"id": "a", "text": "write()", "correct": false},
    {"id": "b", "text": "print()", "correct": true},
    {"id": "c", "text": "echo()",  "correct": false},
    {"id": "d", "text": "show()",  "correct": false},
    {"id": "e", "text": "log()",   "correct": false}
  ],
  "hint": "Dica qualquer suficientemente longa.",
  "explanation": "Explicacao qualquer suficientemente longa."
}''';

const String _aula = '''
"aula": {
  "titulo": "O basico do Python",
  "secoes": [
    {
      "topico": "saida",
      "titulo": "Mostrar coisas na tela",
      "texto": "Primeiro paragrafo da secao, com tamanho suficiente.\\n\\nSegundo paragrafo da secao, tambem com tamanho suficiente.",
      "code": { "language": "python", "content": "print(\\"Oi\\")" }
    }
  ]
},''';

Lesson licao({bool comAula = true}) => Lesson.fromJson(
  json.decode('''
  {
    "schemaVersion": 1,
    "language": "python",
    "level": "beginner",
    "lessonId": "python-beg-01",
    "lessonTitle": "Licao de teste",
    ${comAula ? _aula : ''}
    "questions": [$_questao]
  }''')
      as Map<String, dynamic>,
);

/// Registro em memoria, para o teste de tela nao precisar de banco.
class ProgressoFalso implements RegistroDeProgresso {
  final Set<String> aulasVistas = {};

  @override
  Future<void> registrar({
    required Lesson licao,
    required Question questao,
    required SessaoQuestao sessao,
    DateTime? quando,
  }) async {}

  @override
  Future<void> salvarPosicao(String l, int i, {DateTime? quando}) async {}

  @override
  Future<int?> posicaoDe(String lessonId) async => null;

  @override
  Future<bool> aulaFoiVista(String lessonId) async =>
      aulasVistas.contains(lessonId);

  @override
  Future<void> marcarAulaVista(String lessonId, {DateTime? quando}) async {
    aulasVistas.add(lessonId);
  }

  @override
  Future<Map<String, int>> respondidasPorLicao() async => const {};

  bool som = true;

  @override
  Future<bool> somLigado() async => som;

  @override
  Future<void> definirSom({required bool ligado}) async => som = ligado;

  bool cenario = true;

  @override
  Future<bool> cenarioLigado() async => cenario;

  @override
  Future<void> definirCenario({required bool ligado}) async => cenario = ligado;
}

Future<void> montar(WidgetTester tester, Widget tela) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: tela));
  await tester.pumpAndSettle();
}

void main() {
  group('modelo da aula', () {
    test('as secoes e o codigo sao lidos', () {
      final aula = licao().aula!;
      expect(aula.titulo, 'O basico do Python');
      expect(aula.secoes, hasLength(1));
      expect(aula.secoes.first.topico, 'saida');
      expect(aula.secoes.first.code, isNotNull);
    });

    test('o texto vira paragrafos separados', () {
      final secao = licao().aula!.secoes.first;
      expect(secao.paragrafos, hasLength(2));
      expect(secao.paragrafos.first, startsWith('Primeiro'));
      expect(secao.paragrafos.last, startsWith('Segundo'));
    });

    test('licao sem aula fica com aula nula', () {
      expect(licao(comAula: false).aula, isNull);
    });
  });

  group('tela da aula', () {
    testWidgets('mostra titulo, secao, paragrafos e codigo', (tester) async {
      await montar(
        tester,
        TelaAula(licao: licao(), aoComecar: () {}),
      );

      expect(find.text('O basico do Python'), findsOneWidget);
      expect(find.text('Mostrar coisas na tela'), findsOneWidget);
      expect(find.textContaining('Primeiro paragrafo'), findsOneWidget);
      expect(find.textContaining('Segundo paragrafo'), findsOneWidget);
      expect(find.text('main.py'), findsOneWidget, reason: 'o exemplo em codigo');
      expect(find.byKey(TelaAula.chaveComecar), findsOneWidget);
    });
  });

  group('fluxo da licao', () {
    testWidgets('a aula aparece sozinha na primeira vez', (tester) async {
      await montar(tester, FluxoDaLicao(licao: licao()));

      expect(find.byKey(TelaAula.chaveComecar), findsOneWidget);
      expect(find.text('Começar as questões'), findsOneWidget);
      expect(find.text('Qual funcao exibe algo na tela?'), findsNothing);
    });

    testWidgets('quem ja viu a aula cai direto nas questoes', (tester) async {
      await montar(tester, FluxoDaLicao(licao: licao(), aulaJaVista: true));

      expect(find.byKey(TelaAula.chaveComecar), findsNothing);
      expect(find.text('Qual funcao exibe algo na tela?'), findsOneWidget);
    });

    testWidgets('licao sem aula nao mostra aula nem o icone de reler', (
      tester,
    ) async {
      await montar(tester, FluxoDaLicao(licao: licao(comAula: false)));

      expect(find.byKey(TelaAula.chaveComecar), findsNothing);
      expect(find.byKey(const Key('acao-reler-aula')), findsNothing);
      expect(find.text('Qual funcao exibe algo na tela?'), findsOneWidget);
    });

    testWidgets('comecar leva as questoes e marca a aula como vista', (
      tester,
    ) async {
      final progresso = ProgressoFalso();
      await montar(tester, FluxoDaLicao(licao: licao(), progresso: progresso));

      await tester.tap(find.byKey(TelaAula.chaveComecar));
      await tester.pumpAndSettle();

      expect(find.text('Qual funcao exibe algo na tela?'), findsOneWidget);
      expect(
        progresso.aulasVistas,
        contains('python-beg-01'),
        reason: 'a proxima abertura nao deve impor a aula de novo',
      );
    });

    testWidgets('o icone no topo reabre a aula para consulta', (tester) async {
      await montar(tester, FluxoDaLicao(licao: licao(), aulaJaVista: true));

      await tester.tap(find.byKey(const Key('acao-reler-aula')));
      await tester.pumpAndSettle();

      expect(find.text('O basico do Python'), findsOneWidget);
      expect(
        find.text('Voltar às questões'),
        findsOneWidget,
        reason: 'relendo, o botao devolve para onde o aluno estava',
      );
    });

    testWidgets('voltar da releitura nao remarca a aula como vista', (
      tester,
    ) async {
      // Releitura nao e primeira vez: marcar de novo mentiria sobre quando o
      // aluno viu a aula pela primeira vez.
      final progresso = ProgressoFalso();
      await montar(
        tester,
        FluxoDaLicao(
          licao: licao(),
          progresso: progresso,
          aulaJaVista: true,
        ),
      );

      await tester.tap(find.byKey(const Key('acao-reler-aula')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(TelaAula.chaveComecar));
      await tester.pumpAndSettle();

      expect(find.text('Qual funcao exibe algo na tela?'), findsOneWidget);
      expect(progresso.aulasVistas, isEmpty);
    });
  });
}
