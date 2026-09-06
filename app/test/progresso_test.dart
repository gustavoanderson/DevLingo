import 'dart:convert';
import 'dart:math';

import 'package:devlingo/answer/sessao_questao.dart';
import 'package:devlingo/data/progresso.dart';
import 'package:devlingo/models/lesson.dart';
import 'package:devlingo/models/question.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Lesson lerLicao(String cru) =>
    Lesson.fromJson(json.decode(cru) as Map<String, dynamic>);

final licao = lerLicao('''
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
        {"id": "a", "text": "write()",  "correct": false},
        {"id": "b", "text": "print()",  "correct": true},
        {"id": "c", "text": "echo()",   "correct": false},
        {"id": "d", "text": "show()",   "correct": false},
        {"id": "e", "text": "log()",    "correct": false}
      ],
      "hint": "Dica qualquer suficientemente longa.",
      "explanation": "Explicacao qualquer suficientemente longa."
    },
    {
      "id": "python-beg-0102",
      "topic": "condicionais",
      "prompt": "Segunda questao.",
      "answerType": "multipleChoice",
      "options": [
        {"id": "a", "text": "um",    "correct": true},
        {"id": "b", "text": "dois",  "correct": false},
        {"id": "c", "text": "tres",  "correct": false},
        {"id": "d", "text": "quatro","correct": false},
        {"id": "e", "text": "cinco", "correct": false}
      ],
      "hint": "Dica qualquer suficientemente longa.",
      "explanation": "Explicacao qualquer suficientemente longa."
    }
  ]
}''');

/// Responde acertando de primeira.
SessaoQuestao acertando(Question q) {
  final s = SessaoQuestao(q, sorteio: Random(1));
  s.selecionar(s.correta);
  s.verificar();
  return s;
}

/// Erra ate a resposta ser revelada.
SessaoQuestao ateRevelar(Question q) {
  final s = SessaoQuestao(q, sorteio: Random(2));
  while (!s.terminou) {
    final alvo = s.alternativas.firstWhere(
      (o) => !o.correct && !s.estaEliminada(o),
    );
    s.selecionar(alvo);
    s.verificar();
  }
  return s;
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  migracao();

  late Progresso progresso;

  setUp(() async {
    // Banco em memoria: cada teste comeca do zero, sem tocar em disco.
    progresso = await Progresso.abrir(caminho: inMemoryDatabasePath);
  });

  tearDown(() => progresso.fechar());

  group('registro de resposta', () {
    test('acertar de primeira grava tentativa 1 e desfecho de acerto', () async {
      final questao = licao.questions[0];
      await progresso.registrar(
        licao: licao,
        questao: questao,
        sessao: acertando(questao),
      );

      final gravada = await progresso.respostaDe('python-beg-0101');
      expect(gravada, isNotNull);
      expect(gravada!.tentativas, 1);
      expect(gravada.desfecho, Desfecho.acertou);
      expect(gravada.deCabeca, isTrue);
      expect(gravada.topic, 'saida');
      expect(gravada.language, 'python');
      expect(gravada.level, 'beginner');
    });

    test('resposta revelada grava quatro tentativas e o desfecho certo', () async {
      final questao = licao.questions[0];
      await progresso.registrar(
        licao: licao,
        questao: questao,
        sessao: ateRevelar(questao),
      );

      final gravada = await progresso.respostaDe('python-beg-0101');
      expect(gravada!.desfecho, Desfecho.revelada);
      expect(gravada.tentativas, 4);
      expect(gravada.deCabeca, isFalse);
    });

    test('questao ainda nao terminada nao e gravada', () async {
      final questao = licao.questions[0];
      final sessao = SessaoQuestao(questao, sorteio: Random(3));
      final errada = sessao.alternativas.firstWhere((o) => !o.correct);
      sessao.selecionar(errada);
      sessao.verificar();

      expect(sessao.terminou, isFalse);
      await progresso.registrar(
        licao: licao,
        questao: questao,
        sessao: sessao,
      );

      expect(await progresso.respostaDe('python-beg-0101'), isNull);
    });

    test('refazer a licao substitui o registro em vez de duplicar', () async {
      final questao = licao.questions[0];
      await progresso.registrar(
        licao: licao,
        questao: questao,
        sessao: ateRevelar(questao),
      );
      await progresso.registrar(
        licao: licao,
        questao: questao,
        sessao: acertando(questao),
      );

      final todas = await progresso.respostasDa('python-beg-01');
      expect(todas, hasLength(1));
      expect(todas.single.tentativas, 1);
      expect(todas.single.desfecho, Desfecho.acertou);
    });
  });

  group('retomar de onde parou', () {
    test('licao nunca aberta nao tem posicao', () async {
      expect(await progresso.posicaoDe('python-beg-01'), isNull);
    });

    test('a posicao salva e a posicao devolvida', () async {
      await progresso.salvarPosicao('python-beg-01', 4);
      expect(await progresso.posicaoDe('python-beg-01'), 4);
    });

    test('salvar de novo atualiza em vez de acumular', () async {
      await progresso.salvarPosicao('python-beg-01', 2);
      await progresso.salvarPosicao('python-beg-01', 7);
      expect(await progresso.posicaoDe('python-beg-01'), 7);
    });

    test('licoes diferentes guardam posicoes independentes', () async {
      await progresso.salvarPosicao('python-beg-01', 3);
      await progresso.salvarPosicao('python-beg-02', 8);

      expect(await progresso.posicaoDe('python-beg-01'), 3);
      expect(await progresso.posicaoDe('python-beg-02'), 8);
    });
  });

  group('o progresso sobrevive ao fechamento do app', () {
    test('reabrir o banco encontra o que foi gravado', () async {
      // Arquivo de verdade, nao memoria: e o unico jeito de provar que o dado
      // atravessa o fechamento do app.
      final arquivo = '${await databaseFactory.getDatabasesPath()}/teste.db';
      await databaseFactory.deleteDatabase(arquivo);

      final primeira = await Progresso.abrir(caminho: arquivo);
      final questao = licao.questions[0];
      await primeira.registrar(
        licao: licao,
        questao: questao,
        sessao: acertando(questao),
      );
      await primeira.salvarPosicao('python-beg-01', 5);
      await primeira.fechar();

      final segunda = await Progresso.abrir(caminho: arquivo);
      expect(await segunda.posicaoDe('python-beg-01'), 5);
      expect((await segunda.respostaDe('python-beg-0101'))!.tentativas, 1);
      await segunda.fechar();

      await databaseFactory.deleteDatabase(arquivo);
    });
  });

  group('custo por topico', () {
    // A razao de ser do SQLite em vez de chave-valor: sem consulta, o numero de
    // tentativas seria um dado guardado que nunca vira revisao dirigida.

    test('ordena do topico mais caro para o mais barato', () async {
      await progresso.registrar(
        licao: licao,
        questao: licao.questions[0],
        sessao: ateRevelar(licao.questions[0]),
      );
      await progresso.registrar(
        licao: licao,
        questao: licao.questions[1],
        sessao: acertando(licao.questions[1]),
      );

      final custo = await progresso.custoPorTopico();
      expect(custo, hasLength(2));

      expect(custo.first.topic, 'saida');
      expect(custo.first.tentativas, 4);
      expect(custo.first.reveladas, 1);
      expect(custo.first.tentativasPorQuestao, 4);

      expect(custo.last.topic, 'condicionais');
      expect(custo.last.tentativas, 1);
      expect(custo.last.reveladas, 0);
    });

    test('banco vazio devolve lista vazia em vez de quebrar', () async {
      expect(await progresso.custoPorTopico(), isEmpty);
    });
  });
}

/// Migracao de esquema.
///
/// O app ja esta no celular de alguem com dados dentro. Recriar o banco do zero
/// seria mais simples e apagaria o progresso do aluno, que e exatamente o que
/// este arquivo existe para nao fazer.
void migracao() {
  group('migracao da versao 1 para a 2', () {
    late String arquivo;

    setUp(() async {
      arquivo = '${await databaseFactory.getDatabasesPath()}/migracao.db';
      await databaseFactory.deleteDatabase(arquivo);
    });

    tearDown(() => databaseFactory.deleteDatabase(arquivo));

    /// Cria um banco exatamente como a versao 1 o deixava.
    Future<void> criarBancoAntigo() async {
      final bd = await databaseFactory.openDatabase(
        arquivo,
        options: OpenDatabaseOptions(version: 1),
      );
      await bd.execute('''
        CREATE TABLE resposta (
          question_id   TEXT PRIMARY KEY,
          lesson_id     TEXT NOT NULL,
          language      TEXT NOT NULL,
          level         TEXT NOT NULL,
          topic         TEXT NOT NULL,
          tentativas    INTEGER NOT NULL,
          desfecho      TEXT NOT NULL,
          respondida_em INTEGER NOT NULL
        )
      ''');
      await bd.execute('''
        CREATE TABLE posicao (
          lesson_id     TEXT PRIMARY KEY,
          indice        INTEGER NOT NULL,
          atualizada_em INTEGER NOT NULL
        )
      ''');
      await bd.insert('resposta', {
        'question_id': 'python-beg-0101',
        'lesson_id': 'python-beg-01',
        'language': 'python',
        'level': 'beginner',
        'topic': 'saida',
        'tentativas': 2,
        'desfecho': 'acertou',
        'respondida_em': 1700000000000,
      });
      await bd.insert('posicao', {
        'lesson_id': 'python-beg-01',
        'indice': 4,
        'atualizada_em': 1700000000000,
      });
      await bd.close();
    }

    test('o progresso do aluno sobrevive a atualizacao do app', () async {
      await criarBancoAntigo();

      final progresso = await Progresso.abrir(caminho: arquivo);

      expect(
        (await progresso.respostaDe('python-beg-0101'))!.tentativas,
        2,
        reason: 'a resposta gravada na versao antiga nao pode se perder',
      );
      expect(await progresso.posicaoDe('python-beg-01'), 4);

      await progresso.fechar();
    });

    test('a tabela nova existe depois de migrar', () async {
      await criarBancoAntigo();

      final progresso = await Progresso.abrir(caminho: arquivo);

      expect(await progresso.aulaFoiVista('python-beg-01'), isFalse);
      await progresso.marcarAulaVista('python-beg-01');
      expect(await progresso.aulaFoiVista('python-beg-01'), isTrue);

      await progresso.fechar();
    });
  });
}
