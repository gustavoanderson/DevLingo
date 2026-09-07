import 'dart:convert';
import 'dart:math';

import 'package:devlingo/answer/sessao_questao.dart';
import 'package:devlingo/data/nuvem.dart';
import 'package:devlingo/data/progresso.dart';
import 'package:devlingo/data/sincronizador.dart';
import 'package:devlingo/models/lesson.dart';
import 'package:devlingo/models/question.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// A logica da sincronizacao, exercitada SEM REDE.
///
/// Sincronizar e a parte de um app offline-first onde mais se erra, e onde os
/// erros aparecem tarde: no elevador, no metro, no aparelho da outra pessoa.
/// Testar so o caminho feliz e nao testar.
///
/// Estes testes usam `NuvemFalsa`, que reproduz o que a sincronizacao precisa
/// distinguir -- e nada alem disso. O relogio dela e um contador, e nao o de
/// verdade, porque teste que depende de tempo real falha sozinho de madrugada.

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
      "prompt": "Primeira",
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
      "topic": "variaveis",
      "prompt": "Segunda",
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
}''')
      as Map<String, dynamic>,
);

SessaoQuestao acertando(Question q) {
  final s = SessaoQuestao(q, sorteio: Random(1));
  s.selecionar(s.correta);
  s.verificar();
  return s;
}

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

/// Um aparelho: banco proprio, mesma nuvem.
Future<Progresso> aparelho(String nome, String uid) async {
  final arquivo = '${await databaseFactory.getDatabasesPath()}/$nome.db';
  await databaseFactory.deleteDatabase(arquivo);
  final p = await Progresso.abrir(caminho: arquivo);
  await p.entrarComo(uid);
  return p;
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('subir e descer', () {
    late NuvemFalsa nuvem;
    late Sincronizador sinc;
    late Progresso progresso;

    setUp(() async {
      nuvem = NuvemFalsa();
      sinc = Sincronizador(nuvem);
      progresso = await Progresso.abrir(caminho: inMemoryDatabasePath);
      await progresso.entrarComo('uid-a');
    });
    tearDown(() => progresso.fechar());

    test('o que foi jogado sobe', () async {
      await progresso.registrar(
        licao: licao,
        questao: licao.questions[0],
        sessao: acertando(licao.questions[0]),
      );

      final r = await sinc.sincronizar(progresso);

      expect(r.enviados, 1);
      expect(r.falhou, isFalse);
      expect(nuvem.guardados['uid-a'], hasLength(1));
    });

    test('sincronizar de novo NAO reenvia o que ja subiu', () async {
      await progresso.registrar(
        licao: licao,
        questao: licao.questions[0],
        sessao: acertando(licao.questions[0]),
      );
      await sinc.sincronizar(progresso);

      final segunda = await sinc.sincronizar(progresso);
      expect(segunda.enviados, 0, reason: 'nada pendente na segunda rodada');
    });

    test('sem nada para fazer, nao toca na rede', () async {
      final r = await sinc.sincronizar(progresso);

      expect(r.mudouAlgo, isFalse);
      expect(nuvem.enviosFeitos, 0, reason: 'nao subiu lista vazia');
    });

    test('sem conta, nao sobe nada', () async {
      // Progresso orfao subindo para a nuvem o daria a uma conta que talvez
      // nem seja a de quem jogou.
      final semConta = await Progresso.abrir(caminho: inMemoryDatabasePath);
      addTearDown(semConta.fechar);
      await semConta.registrar(
        licao: licao,
        questao: licao.questions[0],
        sessao: acertando(licao.questions[0]),
      );

      final r = await sinc.sincronizar(semConta);
      expect(r.enviados, 0);
      expect(nuvem.enviosFeitos, 0);
    });
  });

  group('quando a rede cai', () {
    // O caso COMUM, nao o excepcional: elevador, metro, aviao.

    late NuvemFalsa nuvem;
    late Sincronizador sinc;
    late Progresso progresso;

    setUp(() async {
      nuvem = NuvemFalsa();
      sinc = Sincronizador(nuvem);
      progresso = await Progresso.abrir(caminho: inMemoryDatabasePath);
      await progresso.entrarComo('uid-a');
      await progresso.registrar(
        licao: licao,
        questao: licao.questions[0],
        sessao: acertando(licao.questions[0]),
      );
    });
    tearDown(() => progresso.fechar());

    test('o app nao quebra, e a falha e relatada', () async {
      nuvem.falhaProgramada = Exception('sem conexao');

      final r = await sinc.sincronizar(progresso);

      expect(r.falhou, isTrue);
      expect(r.motivo, isNotNull);
    });

    test('NADA se perde: o evento continua pendente', () async {
      // Marcar como enviado antes de a rede confirmar perderia a partida para
      // sempre -- ela ficaria como sincronizada sem nunca ter chegado.
      nuvem.falhaProgramada = Exception('sem conexao');
      await sinc.sincronizar(progresso);

      expect(await progresso.eventosPendentes(), hasLength(1));
    });

    test('a proxima rodada sobe o que ficou para tras', () async {
      nuvem.falhaProgramada = Exception('sem conexao');
      await sinc.sincronizar(progresso);

      final depois = await sinc.sincronizar(progresso);
      expect(depois.enviados, 1);
      expect(depois.falhou, isFalse);
    });
  });

  group('dois aparelhos, uma conta', () {
    // O cenario que motivou a decisao: jogar no celular sem internet e no
    // tablet em casa. Cada um gravou uma versao do mesmo progresso.

    late NuvemFalsa nuvem;
    late Sincronizador sinc;
    late Progresso celular;
    late Progresso tablet;

    setUp(() async {
      nuvem = NuvemFalsa();
      sinc = Sincronizador(nuvem);
      celular = await aparelho('celular', 'uid-a');
      tablet = await aparelho('tablet', 'uid-a');
    });
    tearDown(() async {
      await celular.fechar();
      await tablet.fechar();
    });

    test('o que foi jogado num aparece no outro', () async {
      await celular.registrar(
        licao: licao,
        questao: licao.questions[0],
        sessao: acertando(licao.questions[0]),
      );
      await sinc.sincronizar(celular);

      expect(await tablet.respostaDe('python-beg-0101'), isNull);
      final r = await sinc.sincronizar(tablet);

      expect(r.recebidos, 1);
      expect(await tablet.respostaDe('python-beg-0101'), isNotNull);
    });

    test('questoes DIFERENTES nos dois somam, nao se substituem', () async {
      await celular.registrar(
        licao: licao,
        questao: licao.questions[0],
        sessao: acertando(licao.questions[0]),
      );
      await tablet.registrar(
        licao: licao,
        questao: licao.questions[1],
        sessao: acertando(licao.questions[1]),
      );

      await sinc.sincronizar(celular);
      await sinc.sincronizar(tablet);
      await sinc.sincronizar(celular);

      expect((await celular.resumoDoJogador()).respondidas, 2);
      expect((await tablet.resumoDoJogador()).respondidas, 2);
    });

    test('a MESMA questao nos dois: o historico guarda as duas partidas',
        () async {
      // Aqui estaria o conflito, se o estado atual fosse a verdade. Como ele e
      // derivado de um historico que so cresce, as duas partidas coexistem e o
      // estado sai da mais recente.
      final q = licao.questions[0];
      await celular.registrar(
        licao: licao,
        questao: q,
        sessao: ateRevelar(q),
        quando: DateTime(2026, 1, 1),
      );
      await tablet.registrar(
        licao: licao,
        questao: q,
        sessao: acertando(q),
        quando: DateTime(2026, 2, 1),
      );

      await sinc.sincronizar(celular);
      await sinc.sincronizar(tablet);
      await sinc.sincronizar(celular);

      for (final (nome, p) in [('celular', celular), ('tablet', tablet)]) {
        final resumo = await p.resumoDoJogador();
        expect(resumo.partidas, 2, reason: '$nome: as duas partidas existem');
        expect(resumo.respondidas, 1, reason: '$nome: uma questao distinta');
        expect(
          (await p.respostaDe('python-beg-0101'))!.desfecho,
          Desfecho.acertou,
          reason: '$nome: o estado sai da partida mais recente',
        );
      }
    });

    test('os dois aparelhos convergem para o MESMO estado', () async {
      // A promessa da decisao: nao importa a ordem em que sincronizam, os dois
      // acabam iguais. E o que "eliminar o conflito" significa na pratica.
      await celular.registrar(
        licao: licao,
        questao: licao.questions[0],
        sessao: acertando(licao.questions[0]),
        quando: DateTime(2026, 1, 5),
      );
      await tablet.registrar(
        licao: licao,
        questao: licao.questions[1],
        sessao: ateRevelar(licao.questions[1]),
        quando: DateTime(2026, 1, 3),
      );

      // Ordem embaralhada de proposito.
      await sinc.sincronizar(tablet);
      await sinc.sincronizar(celular);
      await sinc.sincronizar(tablet);
      await sinc.sincronizar(celular);

      final a = await celular.resumoDoJogador();
      final b = await tablet.resumoDoJogador();

      expect(a.respondidas, b.respondidas);
      expect(a.partidas, b.partidas);
      expect(a.deCabeca, b.deCabeca);
      expect(a.reveladas, b.reveladas);
    });

    test('a conta de OUTRA pessoa nao recebe nada', () async {
      await celular.registrar(
        licao: licao,
        questao: licao.questions[0],
        sessao: acertando(licao.questions[0]),
      );
      await sinc.sincronizar(celular);

      final deOutro = await aparelho('outro', 'uid-b');
      addTearDown(deOutro.fechar);

      final r = await sinc.sincronizar(deOutro);
      expect(r.recebidos, 0);
      expect(await deOutro.respostaDe('python-beg-0101'), isNull);
    });
  });

  group('a marca d\'agua', () {
    test('evita baixar de novo o que ja veio', () async {
      final nuvem = NuvemFalsa();
      final sinc = Sincronizador(nuvem);
      final celular = await aparelho('marca-a', 'uid-a');
      final tablet = await aparelho('marca-b', 'uid-a');
      addTearDown(celular.fechar);
      addTearDown(tablet.fechar);

      await celular.registrar(
        licao: licao,
        questao: licao.questions[0],
        sessao: acertando(licao.questions[0]),
      );
      await sinc.sincronizar(celular);

      final primeira = await sinc.sincronizar(tablet);
      expect(primeira.recebidos, 1);

      final segunda = await sinc.sincronizar(tablet);
      expect(segunda.recebidos, 0, reason: 'nada novo desde a marca');
      expect(await tablet.marcaDeSincronizacao(), greaterThan(0));
    });
  });
}
