import 'dart:convert';
import 'dart:math';

import 'package:devlingo/answer/sessao_questao.dart';
import 'package:devlingo/data/progresso.dart';
import 'package:devlingo/models/lesson.dart';
import 'package:devlingo/models/question.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Progresso POR USUARIO, e o estado derivado do historico.
///
/// Arquivo proprio porque a versao 5 do banco e o degrau mais delicado ate
/// agora: o SQLite **nao permite** trocar a chave primaria de uma tabela
/// existente, e a chave precisava mudar de `question_id` para
/// `(uid, question_id)`. Sem isso, duas contas no mesmo aparelho
/// sobrescreveriam o progresso uma da outra.
///
/// A saida e o padrao do proprio SQLite: cria a tabela nova ao lado, COPIA os
/// dados, derruba a antiga e renomeia. E onde mais se perde dado sem perceber
/// -- o CREATE novo roda, o app abre, e so semanas depois alguem nota que o
/// progresso sumiu. Por isso estes testes insistem em conferir que o dado
/// atravessou.

final licao = Lesson.fromJson(
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
        {"id": "a", "text": "write()",  "correct": false},
        {"id": "b", "text": "print()",  "correct": true},
        {"id": "c", "text": "echo()",   "correct": false},
        {"id": "d", "text": "show()",   "correct": false},
        {"id": "e", "text": "log()",    "correct": false}
      ],
      "hint": "Dica qualquer suficientemente longa.",
      "explanation": "Explicacao qualquer suficientemente longa."
    }
  ]
}''')
      as Map<String, dynamic>,
);

Question get questao => licao.questions[0];

SessaoQuestao acertando() {
  final s = SessaoQuestao(questao, sorteio: Random(1));
  s.selecionar(s.correta);
  s.verificar();
  return s;
}

SessaoQuestao ateRevelar() {
  final s = SessaoQuestao(questao, sorteio: Random(2));
  while (!s.terminou) {
    final alvo = s.alternativas.firstWhere(
      (o) => !o.correct && !s.estaEliminada(o),
    );
    s.selecionar(alvo);
    s.verificar();
  }
  return s;
}

/// Cria um banco exatamente como a versao 4 o deixava, com dados dentro.
Future<void> criarBancoV4(String arquivo) async {
  final bd = await databaseFactory.openDatabase(
    arquivo,
    options: OpenDatabaseOptions(version: 4),
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
      respondida_em INTEGER NOT NULL,
      duracao_ms    INTEGER,
      usou_dica     INTEGER
    )
  ''');
  await bd.execute('''
    CREATE TABLE posicao (
      lesson_id     TEXT PRIMARY KEY,
      indice        INTEGER NOT NULL,
      atualizada_em INTEGER NOT NULL
    )
  ''');
  await bd.execute('''
    CREATE TABLE aula_vista (
      lesson_id TEXT PRIMARY KEY,
      vista_em  INTEGER NOT NULL
    )
  ''');
  await bd.execute('''
    CREATE TABLE preferencia (
      chave TEXT PRIMARY KEY,
      valor TEXT NOT NULL
    )
  ''');
  await bd.execute('''
    CREATE TABLE evento_resposta (
      id            INTEGER PRIMARY KEY AUTOINCREMENT,
      question_id   TEXT    NOT NULL,
      lesson_id     TEXT    NOT NULL,
      language      TEXT    NOT NULL,
      level         TEXT    NOT NULL,
      topic         TEXT    NOT NULL,
      tentativas    INTEGER NOT NULL,
      desfecho      TEXT    NOT NULL,
      usou_dica     INTEGER NOT NULL,
      duracao_ms    INTEGER,
      respondida_em INTEGER NOT NULL
    )
  ''');

  const dados = {
    'question_id': 'python-beg-0101',
    'lesson_id': 'python-beg-01',
    'language': 'python',
    'level': 'beginner',
    'topic': 'saida',
    'tentativas': 2,
    'desfecho': 'acertou',
    'usou_dica': 0,
    'duracao_ms': 4200,
    'respondida_em': 1700000000000,
  };
  await bd.insert('resposta', dados);
  await bd.insert('evento_resposta', dados);
  await bd.insert('posicao', {
    'lesson_id': 'python-beg-01',
    'indice': 6,
    'atualizada_em': 1700000000000,
  });
  await bd.insert('aula_vista', {
    'lesson_id': 'python-beg-01',
    'vista_em': 1700000000000,
  });
  await bd.insert('preferencia', {'chave': 'som', 'valor': '0'});
  await bd.close();
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('migracao da versao 4 para a 5', () {
    late String arquivo;

    setUp(() async {
      arquivo = '${await databaseFactory.getDatabasesPath()}/mig5.db';
      await databaseFactory.deleteDatabase(arquivo);
    });

    tearDown(() => databaseFactory.deleteDatabase(arquivo));

    test('o progresso de quem ja jogava atravessa a troca de chave', () async {
      await criarBancoV4(arquivo);

      final progresso = await Progresso.abrir(caminho: arquivo);
      await progresso.entrarComo('uid-do-gustavo');

      final gravada = await progresso.respostaDe('python-beg-0101');
      expect(gravada, isNotNull, reason: 'a resposta antiga continua la');
      expect(gravada!.tentativas, 2);
      expect(gravada.duracao, const Duration(milliseconds: 4200));
      expect(await progresso.posicaoDe('python-beg-01'), 6);
      expect(await progresso.aulaFoiVista('python-beg-01'), isTrue);
      expect(await progresso.somLigado(), isFalse, reason: 'a preferencia veio');
      await progresso.fechar();
    });

    test('a PRIMEIRA conta a entrar adota o progresso sem dono', () async {
      // Combinado com o Gustavo: o app rodou um tempo sem login, e aquele
      // progresso e real. Apagar seria a saida facil.
      await criarBancoV4(arquivo);

      final progresso = await Progresso.abrir(caminho: arquivo);
      final adotadas = await progresso.adotarProgressoOrfao('uid-do-gustavo');

      expect(adotadas, greaterThan(0));
      await progresso.entrarComo('uid-do-gustavo');
      expect(await progresso.respostaDe('python-beg-0101'), isNotNull);
      await progresso.fechar();
    });

    test('a SEGUNDA conta no mesmo aparelho comeca do zero', () async {
      // Se o orfao fosse adotado por todo mundo, duas pessoas no mesmo celular
      // veriam o progresso uma da outra -- o defeito que a versao 5 corrige.
      await criarBancoV4(arquivo);

      final progresso = await Progresso.abrir(caminho: arquivo);
      await progresso.entrarComo('uid-do-gustavo');
      expect(await progresso.respostaDe('python-beg-0101'), isNotNull);

      await progresso.entrarComo('uid-de-outra-pessoa');
      expect(
        await progresso.respostaDe('python-beg-0101'),
        isNull,
        reason: 'o progresso do primeiro nao vaza para o segundo',
      );
      expect(await progresso.respondidasPorLicao(), isEmpty);
      await progresso.fechar();
    });
  });

  group('duas contas no mesmo aparelho', () {
    late Progresso progresso;

    setUp(() async {
      progresso = await Progresso.abrir(caminho: inMemoryDatabasePath);
    });
    tearDown(() => progresso.fechar());

    test('gravam a MESMA questao sem se atropelar', () async {
      await progresso.entrarComo('conta-a');
      await progresso.registrar(
        licao: licao,
        questao: questao,
        sessao: acertando(),
      );

      await progresso.entrarComo('conta-b');
      await progresso.registrar(
        licao: licao,
        questao: questao,
        sessao: ateRevelar(),
      );
      expect(
        (await progresso.respostaDe('python-beg-0101'))!.desfecho,
        Desfecho.revelada,
      );

      await progresso.entrarComo('conta-a');
      expect(
        (await progresso.respostaDe('python-beg-0101'))!.desfecho,
        Desfecho.acertou,
        reason: 'a conta A continua com o resultado dela',
      );
    });

    test('preferencias nao vazam entre contas', () async {
      await progresso.entrarComo('conta-a');
      await progresso.definirSom(ligado: false);

      await progresso.entrarComo('conta-b');
      expect(
        await progresso.somLigado(),
        isTrue,
        reason: 'a conta B nasce com o padrao, e nao com a escolha da A',
      );

      await progresso.entrarComo('conta-a');
      expect(await progresso.somLigado(), isFalse);
    });
  });

  group('estado derivado do historico', () {
    // A decisao que ELIMINA o conflito de sincronizacao, em vez de resolve-lo:
    // o historico so cresce e nunca conflita, e o estado atual deixa de ser um
    // dado disputado para virar um resumo calculado.

    late Progresso progresso;

    setUp(() async {
      progresso = await Progresso.abrir(caminho: inMemoryDatabasePath);
      await progresso.entrarComo('uid-teste');
    });
    tearDown(() => progresso.fechar());

    test('recalcular e IDEMPOTENTE', () async {
      // Rodar duas vezes tem que dar o mesmo resultado, senao sincronizar duas
      // vezes produziria progressos diferentes -- e sincronizacao repete o
      // tempo todo, por queda de conexao e por reenvio.
      await progresso.registrar(
        licao: licao,
        questao: questao,
        sessao: ateRevelar(),
        quando: DateTime(2026, 1, 1),
      );
      await progresso.registrar(
        licao: licao,
        questao: questao,
        sessao: acertando(),
        quando: DateTime(2026, 2, 1),
      );

      final antes = await progresso.resumoDoJogador();
      await progresso.recalcularEstado();
      await progresso.recalcularEstado();
      final depois = await progresso.resumoDoJogador();

      expect(depois.respondidas, antes.respondidas);
      expect(depois.partidas, antes.partidas);
      expect(depois.deCabeca, antes.deCabeca);
    });

    test('o estado reflete a partida MAIS RECENTE da questao', () async {
      await progresso.registrar(
        licao: licao,
        questao: questao,
        sessao: ateRevelar(),
        quando: DateTime(2026, 1, 1),
      );
      await progresso.registrar(
        licao: licao,
        questao: questao,
        sessao: acertando(),
        quando: DateTime(2026, 2, 1),
      );

      await progresso.recalcularEstado();
      expect(
        (await progresso.respostaDe('python-beg-0101'))!.desfecho,
        Desfecho.acertou,
      );
    });

    test('refazer acumula no historico e substitui no estado', () async {
      await progresso.registrar(
        licao: licao,
        questao: questao,
        sessao: ateRevelar(),
        quando: DateTime(2026, 1, 1),
      );
      await progresso.registrar(
        licao: licao,
        questao: questao,
        sessao: acertando(),
        quando: DateTime(2026, 2, 1),
      );

      final r = await progresso.resumoDoJogador();
      expect(r.respondidas, 1, reason: 'uma questao distinta');
      expect(r.partidas, 2, reason: 'jogada duas vezes');
    });

    test('o id do evento e o mesmo em qualquer aparelho', () async {
      // Com AUTOINCREMENT, o celular e o tablet gerariam o id 1 para partidas
      // diferentes, e juntar os historicos perderia uma delas.
      final a = Progresso.idDoEvento('uid-1', 'python-beg-0101', 1700000000000);
      final b = Progresso.idDoEvento('uid-1', 'python-beg-0101', 1700000000000);
      final c = Progresso.idDoEvento('uid-2', 'python-beg-0101', 1700000000000);

      expect(a, b, reason: 'mesma partida, mesmo id, em qualquer aparelho');
      expect(a, isNot(c), reason: 'donos diferentes, ids diferentes');
    });

    test('gravar a MESMA partida duas vezes nao duplica o historico', () async {
      // Idempotencia na gravacao: e o que torna seguro reenviar um evento que
      // talvez tenha chegado. Sem isso, a primeira queda de conexao infla o
      // historico e as estatisticas passam a contar partidas que nao houve.
      final quando = DateTime(2026, 3, 1);
      await progresso.registrar(
        licao: licao,
        questao: questao,
        sessao: acertando(),
        quando: quando,
      );
      await progresso.registrar(
        licao: licao,
        questao: questao,
        sessao: acertando(),
        quando: quando,
      );

      expect((await progresso.resumoDoJogador()).partidas, 1);
    });
  });
}
