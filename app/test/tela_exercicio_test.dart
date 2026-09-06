import 'dart:convert';

import 'package:devlingo/models/lesson.dart';
import 'package:devlingo/ui/tela_exercicio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Testes da tela de exercicio.
///
/// Cobrem o que um print de tela nao prova: a sombra que avisa sobre conteudo
/// cortado, a pastilha da lacuna, e o fato de o codigo nunca quebrar linha.

Lesson licaoCom(String questoesJson) => Lesson.fromJson(
  json.decode('''
  {
    "schemaVersion": 1,
    "language": "python",
    "level": "beginner",
    "lessonId": "python-beg-01",
    "lessonTitle": "Licao de teste",
    "questions": [$questoesJson]
  }''')
      as Map<String, dynamic>,
);

const String _curta = '''
{
  "id": "python-beg-0101",
  "topic": "saida",
  "prompt": "Qual funcao exibe algo na tela?",
  "answerType": "multipleChoice",
  "options": [
    {"id": "a", "text": "write()", "correct": false},
    {"id": "b", "text": "print()", "correct": true},
    {"id": "c", "text": "echo()", "correct": false},
    {"id": "d", "text": "show()", "correct": false},
    {"id": "e", "text": "log()", "correct": false}
  ],
  "hint": "Pense no que voce digitaria num arquivo .py.",
  "explanation": "A funcao embutida do Python e print()."
}''';

/// Nove linhas de codigo mais cinco alternativas: nao cabe numa tela de celular.
const String _longa = '''
{
  "id": "python-beg-0106",
  "topic": "condicionais",
  "prompt": "O que este codigo imprime?",
  "code": {
    "language": "python",
    "content": "nota = 7\\nif nota >= 9:\\n    print(\\"Excelente\\")\\nelif nota >= 7:\\n    print(\\"Bom\\")\\nelif nota >= 5:\\n    print(\\"Regular\\")\\nelse:\\n    print(\\"Insuficiente\\")",
    "highlightLine": 4
  },
  "answerType": "multipleChoice",
  "options": [
    {"id": "a", "text": "Excelente", "correct": false},
    {"id": "b", "text": "Regular", "correct": false},
    {"id": "c", "text": "Insuficiente", "correct": false},
    {"id": "d", "text": "Bom", "correct": true},
    {"id": "e", "text": "Bom Regular", "correct": false}
  ],
  "hint": "Percorra os testes de cima para baixo e pare no primeiro que der certo.",
  "explanation": "A cadeia para no primeiro teste verdadeiro."
}''';

const String _comLacuna = '''
{
  "id": "python-beg-0107",
  "topic": "operadores",
  "prompt": "Complete a linha para obter o resto da divisao.",
  "code": {
    "language": "python",
    "content": "total = 47\\nprint(total ______ 2)",
    "highlightLine": 2
  },
  "answerType": "fillBlank",
  "accepted": ["%"],
  "hint": "O operador que devolve o que sobra da divisao.",
  "explanation": "O modulo devolve o resto."
}''';

Future<void> montar(WidgetTester tester, Lesson licao, {Size? tela}) async {
  if (tela != null) {
    tester.view.physicalSize = tela;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }
  await tester.pumpWidget(
    MaterialApp(home: TelaExercicio(licao: licao)),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('estrutura da tela', () {
    testWidgets('topo, chip, enunciado e barra de acoes aparecem', (
      tester,
    ) async {
      await montar(tester, licaoCom(_curta), tela: const Size(390, 844));

      expect(find.text('✕'), findsOneWidget);
      expect(find.text('1/1'), findsOneWidget);
      expect(find.text('python · iniciante · saida'), findsOneWidget);
      expect(find.text('Qual funcao exibe algo na tela?'), findsOneWidget);
      expect(find.text('Dica'), findsOneWidget);
      expect(find.text('Verificar'), findsOneWidget);
    });

    testWidgets('as cinco alternativas sao renderizadas', (tester) async {
      await montar(tester, licaoCom(_curta), tela: const Size(390, 844));

      for (final texto in ['write()', 'print()', 'echo()', 'show()', 'log()']) {
        expect(find.text(texto), findsOneWidget);
      }
    });

    testWidgets('questao sem codigo nao desenha o bloco de IDE', (
      tester,
    ) async {
      await montar(tester, licaoCom(_curta), tela: const Size(390, 844));
      expect(find.text('main.py'), findsNothing);
    });
  });

  group('sombra de recorte', () {
    // Sem essa sombra o usuario nao descobre a quinta alternativa: a tela
    // parece terminar onde o recorte termina.

    testWidgets('aparece quando ha conteudo abaixo do visivel', (tester) async {
      await montar(tester, licaoCom(_longa), tela: const Size(390, 700));
      expect(find.byKey(TelaExercicio.chaveSombra), findsOneWidget);
    });

    testWidgets('some ao chegar no fim da rolagem', (tester) async {
      await montar(tester, licaoCom(_longa), tela: const Size(390, 700));
      expect(find.byKey(TelaExercicio.chaveSombra), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pumpAndSettle();

      expect(find.byKey(TelaExercicio.chaveSombra), findsNothing);
    });

    testWidgets('nao aparece quando tudo cabe na tela', (tester) async {
      await montar(tester, licaoCom(_curta), tela: const Size(390, 1600));
      expect(find.byKey(TelaExercicio.chaveSombra), findsNothing);
    });
  });

  group('bloco de codigo', () {
    testWidgets('desenha aba, nome do arquivo e numeros de linha', (
      tester,
    ) async {
      await montar(tester, licaoCom(_longa), tela: const Size(390, 844));

      expect(find.text('main.py'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('9'), findsOneWidget);
    });

    testWidgets('nenhuma linha de codigo pode quebrar', (tester) async {
      await montar(tester, licaoCom(_longa), tela: const Size(390, 844));

      final textos = tester.widgetList<Text>(find.byType(Text));
      final linhasDeCodigo = textos.where(
        (t) => (t.data ?? '').contains('print(') || (t.data ?? '').contains('elif'),
      );

      expect(linhasDeCodigo, isNotEmpty);
      for (final linha in linhasDeCodigo) {
        expect(
          linha.softWrap,
          isFalse,
          reason:
              'quebra automatica destroi a indentacao, e indentacao em Python '
              'e sintaxe: "${linha.data}"',
        );
      }
    });

    testWidgets('a lacuna vira pastilha, e o marcador nao aparece cru', (
      tester,
    ) async {
      await montar(tester, licaoCom(_comLacuna), tela: const Size(390, 844));

      expect(find.text('main.py'), findsOneWidget);

      final textos = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '');
      expect(
        textos.any((t) => t.contains('______')),
        isFalse,
        reason: 'o marcador cru nao deve chegar a tela',
      );

      // O texto da linha vira Text.rich com a pastilha no meio.
      final ricos = tester.widgetList<Text>(find.byType(Text)).where(
        (t) => t.textSpan != null,
      );
      expect(ricos, isNotEmpty, reason: 'a linha com lacuna deve virar rich text');
    });
  });
}
