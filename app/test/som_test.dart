import 'dart:convert';

import 'package:devlingo/data/progresso.dart';
import 'package:devlingo/models/lesson.dart';
import 'package:devlingo/ui/som.dart';
import 'package:devlingo/ui/tela_exercicio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Lesson licao() => Lesson.fromJson(
  json.decode('''
  {
    "schemaVersion": 1,
    "language": "python",
    "level": "beginner",
    "lessonId": "python-beg-01",
    "lessonTitle": "Licao de teste",
    "questions": [
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
      }
    ]
  }''')
      as Map<String, dynamic>,
);

Future<void> montar(WidgetTester tester, Sineta sineta) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(home: TelaExercicio(licao: licao(), sineta: sineta)),
  );
  await tester.pumpAndSettle();
}

Future<void> responder(WidgetTester tester, String texto) async {
  await tester.tap(find.text(texto));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('acao-verificar')));
  await tester.pumpAndSettle();
}

void main() {
  group('quando a fanfarra toca', () {
    testWidgets('acertar toca uma vez', (tester) async {
      final sineta = SinetaMuda();
      await montar(tester, sineta);

      await responder(tester, 'print()');

      expect(sineta.toques, 1);
    });

    testWidgets('errar NAO toca nada', (tester) async {
      // Som de erro seria punicao sonora, e a mecanica inteira foi desenhada
      // para nao punir. O silencio aqui e deliberado.
      final sineta = SinetaMuda();
      await montar(tester, sineta);

      await responder(tester, 'echo()');

      expect(sineta.toques, 0);
      expect(find.byKey(const Key('retorno-erro')), findsOneWidget);
    });

    testWidgets('resposta revelada NAO toca nada', (tester) async {
      // Revelar nao e conquista: nao ha o que comemorar.
      final sineta = SinetaMuda();
      await montar(tester, sineta);

      for (final errada in ['write()', 'echo()', 'show()', 'log()']) {
        await responder(tester, errada);
      }

      expect(find.byKey(const Key('retorno-revelado')), findsOneWidget);
      expect(sineta.toques, 0);
    });

    testWidgets('errar antes de acertar toca so no acerto', (tester) async {
      final sineta = SinetaMuda();
      await montar(tester, sineta);

      await responder(tester, 'echo()');
      expect(sineta.toques, 0);

      await responder(tester, 'print()');
      expect(sineta.toques, 1);
    });

    testWidgets('sem sineta, responder continua funcionando', (tester) async {
      // Som e camada, nao requisito.
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: TelaExercicio(licao: licao())));
      await tester.pumpAndSettle();

      await responder(tester, 'print()');

      expect(find.byKey(const Key('retorno-acerto')), findsOneWidget);
    });
  });

  group('a preferencia de som', () {
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    late Progresso progresso;

    setUp(() async {
      progresso = await Progresso.abrir(caminho: inMemoryDatabasePath);
    });

    tearDown(() => progresso.fechar());

    test('vem ligada por padrao', () async {
      expect(await progresso.somLigado(), isTrue);
    });

    test('desligar e ligar de novo grava os dois estados', () async {
      await progresso.definirSom(ligado: false);
      expect(await progresso.somLigado(), isFalse);

      await progresso.definirSom(ligado: true);
      expect(await progresso.somLigado(), isTrue);
    });

    test('sobrevive ao fechamento do app', () async {
      final arquivo = '${await databaseFactory.getDatabasesPath()}/som.db';
      await databaseFactory.deleteDatabase(arquivo);

      final primeira = await Progresso.abrir(caminho: arquivo);
      await primeira.definirSom(ligado: false);
      await primeira.fechar();

      final segunda = await Progresso.abrir(caminho: arquivo);
      expect(await segunda.somLigado(), isFalse);
      await segunda.fechar();

      await databaseFactory.deleteDatabase(arquivo);
    });

    test('a migracao para a versao 3 nao apaga o progresso', () async {
      // Mesmo cuidado da migracao anterior: o app ja esta no celular de alguem.
      final arquivo = '${await databaseFactory.getDatabasesPath()}/mig3.db';
      await databaseFactory.deleteDatabase(arquivo);

      final antigo = await databaseFactory.openDatabase(
        arquivo,
        options: OpenDatabaseOptions(version: 2),
      );
      await antigo.execute('''
        CREATE TABLE resposta (
          question_id TEXT PRIMARY KEY, lesson_id TEXT NOT NULL,
          language TEXT NOT NULL, level TEXT NOT NULL, topic TEXT NOT NULL,
          tentativas INTEGER NOT NULL, desfecho TEXT NOT NULL,
          respondida_em INTEGER NOT NULL)
      ''');
      await antigo.execute('''
        CREATE TABLE posicao (
          lesson_id TEXT PRIMARY KEY, indice INTEGER NOT NULL,
          atualizada_em INTEGER NOT NULL)
      ''');
      await antigo.execute('''
        CREATE TABLE aula_vista (
          lesson_id TEXT PRIMARY KEY, vista_em INTEGER NOT NULL)
      ''');
      await antigo.insert('posicao', {
        'lesson_id': 'python-beg-01',
        'indice': 6,
        'atualizada_em': 1700000000000,
      });
      await antigo.insert('aula_vista', {
        'lesson_id': 'python-beg-01',
        'vista_em': 1700000000000,
      });
      await antigo.close();

      final novo = await Progresso.abrir(caminho: arquivo);
      expect(await novo.posicaoDe('python-beg-01'), 6);
      expect(await novo.aulaFoiVista('python-beg-01'), isTrue);
      expect(await novo.somLigado(), isTrue, reason: 'a tabela nova nasce vazia');
      await novo.fechar();

      await databaseFactory.deleteDatabase(arquivo);
    });
  });
}
