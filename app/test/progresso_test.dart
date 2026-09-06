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
  migracaoParaMedicao();
  medicao();

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

/// Um relogio falso, que avanca so quando mandam.
///
/// Medir tempo com o relogio de verdade tornaria o teste ou lento (esperar
/// segundos) ou vazio (aceitar qualquer numero). Com este, a duracao esperada e
/// exata, e o teste falha se a medicao parar de funcionar.
class RelogioFalso {
  DateTime agora = DateTime(2026, 3, 1, 10, 0, 0);

  DateTime chamar() => agora;
  void avancar(Duration d) => agora = agora.add(d);
}

/// Responde acertando de primeira, levando [levou] para isso.
SessaoQuestao acertandoEm(Question q, Duration levou, {bool pedirDica = false}) {
  final relogio = RelogioFalso();
  final s = SessaoQuestao(q, sorteio: Random(1), relogio: relogio.chamar);
  if (pedirDica) s.abrirDica();
  relogio.avancar(levou);
  s.selecionar(s.correta);
  s.verificar();
  return s;
}

/// Prova que a medicao de tempo e de dica esta sendo COLETADA.
///
/// Esta parte tem prazo, e a tela que a exibe nao. Dado nao medido nao se
/// reconstroi: nenhuma tela futura descobre quanto tempo alguem levou numa
/// questao que ja respondeu. Por isso a coleta foi escrita antes da tela.
void medicao() {
  group('medicao de tempo e de dica', () {
    late Progresso progresso;

    setUp(() async {
      progresso = await Progresso.abrir(caminho: inMemoryDatabasePath);
    });
    tearDown(() => progresso.fechar());

    test('grava quanto tempo a questao levou', () async {
      final questao = licao.questions[0];
      await progresso.registrar(
        licao: licao,
        questao: questao,
        sessao: acertandoEm(questao, const Duration(seconds: 42)),
      );

      final gravada = await progresso.respostaDe('python-beg-0101');
      expect(gravada!.duracao, const Duration(seconds: 42));
    });

    test('tempo alem do teto vira NULO, e nao um numero absurdo', () async {
      // O aluno largou o celular no meio. Sem o teto, esta unica questao
      // entraria na media como duas horas e a estatistica passaria a mentir.
      final questao = licao.questions[0];
      await progresso.registrar(
        licao: licao,
        questao: questao,
        sessao: acertandoEm(questao, const Duration(hours: 2)),
      );

      final gravada = await progresso.respostaDe('python-beg-0101');
      expect(gravada!.duracao, isNull, reason: 'nulo quer dizer nao medido');
    });

    test('pedir a dica e diferente de a dica abrir sozinha', () async {
      // A dica abre sozinha no segundo erro de uma questao de escrita. Contar
      // isso como "usou a dica" viraria "errei duas vezes" na estatistica.
      final questao = licao.questions[0];

      await progresso.registrar(
        licao: licao,
        questao: questao,
        sessao: acertandoEm(questao, const Duration(seconds: 5)),
      );
      expect((await progresso.respostaDe('python-beg-0101'))!.usouDica, isFalse);

      await progresso.registrar(
        licao: licao,
        questao: questao,
        sessao: acertandoEm(
          questao,
          const Duration(seconds: 5),
          pedirDica: true,
        ),
      );
      expect((await progresso.respostaDe('python-beg-0101'))!.usouDica, isTrue);
    });

    test('a sessao so carimba a hora quando a questao termina', () {
      final s = SessaoQuestao(licao.questions[0], sorteio: Random(1));
      expect(s.duracao, isNull);
      s.selecionar(s.correta);
      s.verificar();
      expect(s.duracao, isNotNull);
    });
  });

  group('historico', () {
    late Progresso progresso;

    setUp(() async {
      progresso = await Progresso.abrir(caminho: inMemoryDatabasePath);
    });
    tearDown(() => progresso.fechar());

    test('refazer a questao NAO apaga a partida anterior', () async {
      // Este e o motivo de a tabela de eventos existir. Em `resposta` o
      // question_id e chave primaria, entao refazer sobrescreve -- correto para
      // o estado atual, e destruidor de qualquer nocao de evolucao.
      final questao = licao.questions[0];

      await progresso.registrar(
        licao: licao,
        questao: questao,
        sessao: ateRevelar(questao),
      );
      await progresso.registrar(
        licao: licao,
        questao: questao,
        sessao: acertandoEm(questao, const Duration(seconds: 8)),
      );

      final resumo = await progresso.resumoDoJogador();
      expect(resumo.respondidas, 1, reason: 'uma questao distinta');
      expect(resumo.partidas, 2, reason: 'mas jogada duas vezes');
      expect(
        (await progresso.respostaDe('python-beg-0101'))!.desfecho,
        Desfecho.acertou,
        reason: 'o estado atual e a ultima tentativa',
      );
    });

    test('o resumo responde as perguntas que motivaram guardar os dados',
        () async {
      await progresso.registrar(
        licao: licao,
        questao: licao.questions[0],
        sessao: acertandoEm(licao.questions[0], const Duration(seconds: 10)),
      );
      await progresso.registrar(
        licao: licao,
        questao: licao.questions[1],
        sessao: ateRevelar(licao.questions[1]),
      );

      final r = await progresso.resumoDoJogador();
      expect(r.respondidas, 2);
      expect(r.deCabeca, 1);
      expect(r.reveladas, 1);
      expect(r.taxaDeCabeca, 0.5);
      expect(r.diasEstudados, 1);
    });

    test('a media de tempo ignora o que nao foi medido', () async {
      // Uma questao medida em 10s e outra sem medicao dao media de 10s, nao de
      // 5s. Dividir pelo total trataria "nao medido" como zero, que e mentira.
      await progresso.registrar(
        licao: licao,
        questao: licao.questions[0],
        sessao: acertandoEm(licao.questions[0], const Duration(seconds: 10)),
      );
      await progresso.registrar(
        licao: licao,
        questao: licao.questions[1],
        sessao: acertandoEm(licao.questions[1], const Duration(hours: 3)),
      );

      final r = await progresso.resumoDoJogador();
      expect(r.respondidas, 2);
      expect(r.questoesComTempo, 1);
      expect(r.tempoMedioPorQuestao, const Duration(seconds: 10));
    });

    test('sem nada jogado, o resumo nao explode nem divide por zero', () async {
      final r = await progresso.resumoDoJogador();
      expect(r.respondidas, 0);
      expect(r.taxaDeCabeca, 0);
      expect(r.tentativasPorQuestao, 0);
      expect(r.tempoMedioPorQuestao, isNull);
    });
  });
}

/// A migracao para a versao 4, e a prova de que as duas rotas convergem.
///
/// Um esquema pode ser alcancado por dois caminhos: o `CREATE TABLE` de quem
/// instala o app agora, e o `ALTER TABLE` de quem ja tinha o app e atualizou.
/// Se os dois divergirem, o defeito so aparece em quem instalou numa versao
/// especifica -- o tipo de bug que nao se reproduz na maquina de ninguem.
void migracaoParaMedicao() {
  group('migracao da versao 3 para a 4', () {
    late String arquivo;

    setUp(() async {
      arquivo = '${await databaseFactory.getDatabasesPath()}/mig4.db';
      await databaseFactory.deleteDatabase(arquivo);
    });

    tearDown(() => databaseFactory.deleteDatabase(arquivo));

    /// Cria um banco exatamente como a versao 3 o deixava, com dados dentro.
    Future<void> criarBancoV3() async {
      final bd = await databaseFactory.openDatabase(
        arquivo,
        options: OpenDatabaseOptions(version: 3),
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

    test('o progresso de quem ja jogava sobrevive', () async {
      await criarBancoV3();

      final progresso = await Progresso.abrir(caminho: arquivo);
      final gravada = await progresso.respostaDe('python-beg-0101');

      expect(gravada, isNotNull, reason: 'a resposta antiga continua la');
      expect(gravada!.tentativas, 2);
      expect(await progresso.posicaoDe('python-beg-01'), 4);
      await progresso.fechar();
    });

    test('as partidas antigas ficam com medicao NULA, e nao com zero', () async {
      // Elas realmente nao foram medidas. Inventar zero faria a media de tempo
      // despencar e ninguem saberia por que.
      await criarBancoV3();

      final progresso = await Progresso.abrir(caminho: arquivo);
      final gravada = await progresso.respostaDe('python-beg-0101');

      expect(gravada!.duracao, isNull);
      expect(gravada.usouDica, isNull);
      await progresso.fechar();
    });

    test('o historico nasce vazio, e passa a receber a partir de agora',
        () async {
      // Nao da para inventar historico do que ja foi jogado: existe uma linha
      // em `resposta` e nenhuma nocao de quando cada tentativa aconteceu.
      await criarBancoV3();

      final progresso = await Progresso.abrir(caminho: arquivo);
      final antes = await progresso.resumoDoJogador();
      expect(antes.respondidas, 1, reason: 'o estado atual veio da versao 3');
      expect(antes.partidas, 0, reason: 'mas o historico comeca agora');

      await progresso.registrar(
        licao: licao,
        questao: licao.questions[1],
        sessao: acertandoEm(licao.questions[1], const Duration(seconds: 3)),
      );

      final depois = await progresso.resumoDoJogador();
      expect(depois.partidas, 1);
      await progresso.fechar();
    });

    test('instalar do zero e atualizar chegam ao MESMO esquema', () async {
      Future<List<String>> colunasDe(String caminho) async {
        final bd = await databaseFactory.openDatabase(caminho);
        final info = await bd.rawQuery('PRAGMA table_info(resposta)');
        final tabelas = await bd.rawQuery(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name NOT LIKE 'sqlite_%' ORDER BY name",
        );
        await bd.close();
        return [
          ...info.map((c) => '${c['name']}:${c['type']}'),
          '--tabelas--',
          ...tabelas.map((t) => t['name'] as String),
        ];
      }

      // Rota A: quem instala o app agora.
      final novo = '${await databaseFactory.getDatabasesPath()}/rotaA.db';
      await databaseFactory.deleteDatabase(novo);
      await (await Progresso.abrir(caminho: novo)).fechar();

      // Rota B: quem tinha a versao 3 e atualizou.
      await criarBancoV3();
      await (await Progresso.abrir(caminho: arquivo)).fechar();

      expect(
        await colunasDe(arquivo),
        await colunasDe(novo),
        reason: 'as duas rotas precisam produzir o mesmo banco',
      );

      await databaseFactory.deleteDatabase(novo);
    });
  });
}
