import 'dart:convert';

import 'package:devlingo/answer/sessao_questao.dart';
import 'package:devlingo/data/progresso.dart';
import 'package:devlingo/data/question_bank.dart';
import 'package:devlingo/models/lesson.dart';
import 'package:devlingo/models/question.dart';
import 'package:devlingo/ui/tela_exercicio.dart';
import 'package:devlingo/ui/tela_linguagens.dart';
import 'package:devlingo/ui/tela_trilha.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Lesson licao({
  required String lessonId,
  required String language,
  String level = 'beginner',
  String titulo = 'Licao de teste',
  int quantas = 2,
}) {
  final questoes = List.generate(quantas, (i) {
    final numero = (i + 1).toString().padLeft(2, '0');
    final licaoNum = lessonId.split('-').last;
    return '''
    {
      "id": "$language-${lessonId.split('-')[1]}-$licaoNum$numero",
      "topic": "saida",
      "prompt": "Questao $numero de $lessonId",
      "answerType": "multipleChoice",
      "options": [
        {"id": "a", "text": "um$numero",    "correct": true},
        {"id": "b", "text": "dois$numero",  "correct": false},
        {"id": "c", "text": "tres$numero",  "correct": false},
        {"id": "d", "text": "quatro$numero","correct": false},
        {"id": "e", "text": "cinco$numero", "correct": false}
      ],
      "hint": "Dica qualquer suficientemente longa.",
      "explanation": "Explicacao qualquer suficientemente longa."
    }''';
  }).join(',');

  return Lesson.fromJson(
    json.decode('''
    {
      "schemaVersion": 1,
      "language": "$language",
      "level": "$level",
      "lessonId": "$lessonId",
      "lessonTitle": "$titulo",
      "questions": [$questoes]
    }''')
        as Map<String, dynamic>,
  );
}

final bancoPython = QuestionBank([
  licao(lessonId: 'python-beg-00', language: 'python', titulo: 'Referencia'),
  licao(lessonId: 'python-beg-01', language: 'python', titulo: 'Primeira'),
  licao(lessonId: 'python-beg-02', language: 'python', titulo: 'Segunda'),
]);

final bancoDuasLinguagens = QuestionBank([
  ...bancoPython.lessons,
  licao(lessonId: 'javascript-beg-01', language: 'javascript', titulo: 'JS um'),
]);

/// Registro em memória com contagens combinadas para o teste.
class ProgressoFalso implements RegistroDeProgresso {
  ProgressoFalso([this.contagem = const {}]);

  final Map<String, int> contagem;
  final Map<String, int> posicoes = {};

  @override
  Future<void> registrar({
    required Lesson licao,
    required Question questao,
    required SessaoQuestao sessao,
    DateTime? quando,
  }) async {}

  @override
  Future<void> salvarPosicao(String l, int i, {DateTime? quando}) async {
    posicoes[l] = i;
  }

  @override
  Future<int?> posicaoDe(String lessonId) async => posicoes[lessonId];

  @override
  Future<bool> aulaFoiVista(String lessonId) async => true;

  @override
  Future<void> marcarAulaVista(String lessonId, {DateTime? quando}) async {}

  @override
  Future<Map<String, int>> respondidasPorLicao() async => contagem;
}

Future<void> montar(WidgetTester tester, Widget tela) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: tela));
  await tester.pumpAndSettle();
}

void main() {
  group('trilha', () {
    testWidgets('lista as licoes e deixa a de referencia de fora', (
      tester,
    ) async {
      await montar(
        tester,
        TelaTrilha(
          banco: bancoPython,
          language: 'python',
          level: Level.beginner,
          podeVoltar: false,
        ),
      );

      expect(find.text('Primeira'), findsOneWidget);
      expect(find.text('Segunda'), findsOneWidget);
      expect(
        find.text('Referencia'),
        findsNothing,
        reason: 'a licao -00 e referencia de formato, ninguem a joga',
      );
      expect(find.text('Python'), findsOneWidget);
    });

    testWidgets('mostra quanto de cada licao ja foi respondido', (tester) async {
      await montar(
        tester,
        TelaTrilha(
          banco: bancoPython,
          language: 'python',
          level: Level.beginner,
          progresso: ProgressoFalso(const {'python-beg-01': 1}),
          podeVoltar: false,
        ),
      );

      expect(find.text('1 de 2'), findsOneWidget);
      expect(find.text('0 de 2'), findsOneWidget);
      expect(find.textContaining('1 de 4 questões'), findsOneWidget);
    });

    testWidgets('licao com tudo respondido aparece como concluida', (
      tester,
    ) async {
      await montar(
        tester,
        TelaTrilha(
          banco: bancoPython,
          language: 'python',
          level: Level.beginner,
          progresso: ProgressoFalso(const {'python-beg-01': 2}),
          podeVoltar: false,
        ),
      );

      expect(find.text('concluída'), findsOneWidget);
    });

    testWidgets('nenhuma licao fica trancada: qualquer uma abre', (
      tester,
    ) async {
      // Trancar puniria, e atrapalharia quem quer revisar uma licao antiga ou
      // espiar a seguinte.
      await montar(
        tester,
        TelaTrilha(
          banco: bancoPython,
          language: 'python',
          level: Level.beginner,
          progresso: ProgressoFalso(),
          podeVoltar: false,
        ),
      );

      await tester.tap(find.text('Segunda'));
      await tester.pumpAndSettle();

      expect(find.text('Questao 01 de python-beg-02'), findsOneWidget);
    });

    testWidgets('sair da licao pelo X devolve para a trilha', (tester) async {
      await montar(
        tester,
        TelaTrilha(
          banco: bancoPython,
          language: 'python',
          level: Level.beginner,
          progresso: ProgressoFalso(),
          podeVoltar: false,
        ),
      );

      await tester.tap(find.text('Primeira'));
      await tester.pumpAndSettle();
      expect(find.text('Questao 01 de python-beg-01'), findsOneWidget);

      await tester.tap(find.byKey(const Key('acao-sair')));
      await tester.pumpAndSettle();

      expect(find.text('Primeira'), findsOneWidget);
      expect(find.text('Segunda'), findsOneWidget);
    });

    testWidgets('terminar a licao volta para a trilha', (tester) async {
      await montar(
        tester,
        TelaTrilha(
          banco: bancoPython,
          language: 'python',
          level: Level.beginner,
          progresso: ProgressoFalso(),
          podeVoltar: false,
        ),
      );

      await tester.tap(find.text('Primeira'));
      await tester.pumpAndSettle();

      // Duas questoes: acerta as duas e avanca.
      for (final texto in ['um01', 'um02']) {
        await tester.tap(find.text(texto));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('acao-verificar')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('acao-continuar')));
        await tester.pumpAndSettle();
      }

      expect(find.byKey(TelaExercicio.chaveFimDaLicao), findsOneWidget);

      await tester.tap(find.byKey(TelaExercicio.chaveVoltarDaLicao));
      await tester.pumpAndSettle();

      expect(find.text('Primeira'), findsOneWidget);
      expect(find.text('Segunda'), findsOneWidget);
    });
  });

  group('escolha de linguagem', () {
    test('so lista trilhas que existem de verdade', () {
      final trilhas = TelaLinguagens.trilhasDe(bancoDuasLinguagens);

      expect(trilhas, hasLength(2));
      expect(trilhas.map((t) => t.language), ['javascript', 'python']);
      expect(
        trilhas.every((t) => t.level == Level.beginner),
        isTrue,
        reason: 'nao existe trilha intermediaria nem avancada ainda',
      );
    });

    test('a licao de referencia nao conta como trilha', () {
      final soReferencia = QuestionBank([
        licao(lessonId: 'python-beg-00', language: 'python'),
      ]);
      expect(TelaLinguagens.trilhasDe(soReferencia), isEmpty);
    });

    testWidgets('mostra as duas linguagens e entra numa delas', (tester) async {
      await montar(
        tester,
        TelaLinguagens(
          banco: bancoDuasLinguagens,
          progresso: ProgressoFalso(const {'javascript-beg-01': 2}),
        ),
      );

      expect(find.text('Python'), findsOneWidget);
      expect(find.text('JavaScript'), findsOneWidget);

      await tester.tap(find.byKey(const Key('trilha-javascript-beg')));
      await tester.pumpAndSettle();

      expect(find.text('JS um'), findsOneWidget);
      expect(find.text('concluída'), findsOneWidget);
    });

    testWidgets('da trilha da para voltar a escolha de linguagem', (
      tester,
    ) async {
      await montar(
        tester,
        TelaLinguagens(banco: bancoDuasLinguagens, progresso: ProgressoFalso()),
      );

      await tester.tap(find.byKey(const Key('trilha-python-beg')));
      await tester.pumpAndSettle();
      expect(find.text('Primeira'), findsOneWidget);

      await tester.tap(find.byKey(const Key('trilha-voltar')));
      await tester.pumpAndSettle();

      expect(find.text('Escolha por onde começar.'), findsOneWidget);
    });
  });
}
