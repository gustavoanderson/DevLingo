import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../answer/sessao_questao.dart';
import '../models/lesson.dart';
import '../models/question.dart';

/// Como a questao terminou.
enum Desfecho {
  /// O aluno chegou na resposta sozinho, com uma ou mais tentativas.
  acertou,

  /// As tentativas se esgotaram e a resposta foi revelada.
  revelada,
}

/// O registro de uma questao respondida.
class RespostaGravada {
  final String questionId;
  final String lessonId;
  final String language;
  final String level;
  final String topic;

  /// Quantas vezes o aluno apertou Verificar nesta questao.
  final int tentativas;

  final Desfecho desfecho;
  final DateTime respondidaEm;

  const RespostaGravada({
    required this.questionId,
    required this.lessonId,
    required this.language,
    required this.level,
    required this.topic,
    required this.tentativas,
    required this.desfecho,
    required this.respondidaEm,
  });

  /// Acertou de primeira, sem tropecos.
  bool get deCabeca => desfecho == Desfecho.acertou && tentativas == 1;
}

/// Quanto um topico custou ao aluno.
///
/// Existe para tornar revisao dirigida possivel mais tarde, que e o uso que o
/// campo `topic` do banco ja antecipa. Sem guardar tentativa, "revisar
/// condicionais" nao teria como saber que condicionais foi o que custou.
class CustoDoTopico {
  final String topic;
  final int questoes;
  final int tentativas;
  final int reveladas;

  const CustoDoTopico({
    required this.topic,
    required this.questoes,
    required this.tentativas,
    required this.reveladas,
  });

  /// Media de tentativas por questao. Quanto maior, mais o topico custou.
  double get tentativasPorQuestao => questoes == 0 ? 0 : tentativas / questoes;
}

/// O que a tela precisa saber sobre gravar progresso.
///
/// A tela depende desta interface, e nao de [Progresso], por um motivo pratico:
/// `testWidgets` roda numa zona de tempo falso, onde o I/O real do SQLite nunca
/// avanca e qualquer `await` no banco trava. Alem disso, o que o teste de tela
/// precisa provar e que a tela **chama** o repositorio com os dados certos; que
/// o SQLite funciona ja esta provado em `progresso_test.dart`.
abstract interface class RegistroDeProgresso {
  Future<void> registrar({
    required Lesson licao,
    required Question questao,
    required SessaoQuestao sessao,
    DateTime? quando,
  });

  Future<void> salvarPosicao(String lessonId, int indice, {DateTime? quando});

  Future<int?> posicaoDe(String lessonId);

  Future<bool> aulaFoiVista(String lessonId);

  Future<void> marcarAulaVista(String lessonId, {DateTime? quando});

  Future<Map<String, int>> respondidasPorLicao();
}

/// Guarda o progresso do aluno no aparelho.
///
/// SQLite em vez de chave-valor por dois motivos. O primeiro e que o dado de
/// tentativas so vira revisao dirigida se der para consultar, e consulta dentro
/// de um JSON guardado numa string nao e consulta. O segundo e que o CLAUDE.md
/// preve Firestore com cache local mais tarde: o formato local ja nasce
/// parecido com o que vai sincronizar.
class Progresso implements RegistroDeProgresso {
  Progresso(this._bd);

  final Database _bd;

  static const String arquivo = 'devlingo.db';

  /// Versao 1: tabelas `resposta` e `posicao`.
  /// Versao 2: tabela `aula_vista`.
  static const int versao = 2;

  static Future<Progresso> abrir({String? caminho, DatabaseFactory? fabrica}) async {
    final fab = fabrica ?? databaseFactory;
    final destino = caminho ?? p.join(await fab.getDatabasesPath(), arquivo);
    final bd = await fab.openDatabase(
      destino,
      options: OpenDatabaseOptions(
        version: versao,
        onConfigure: (bd) => bd.execute('PRAGMA foreign_keys = ON'),
        onCreate: _criar,
        onUpgrade: _migrar,
      ),
    );
    return Progresso(bd);
  }

  /// Leva um banco ja instalado no aparelho ate a versao atual.
  ///
  /// Migracao existe porque o aplicativo ja esta no celular de alguem com dados
  /// dentro. Recriar o banco do zero seria mais simples e apagaria o progresso
  /// do aluno, que e exatamente o que este arquivo existe para nao fazer.
  ///
  /// Cada degrau roda em sequencia, entao um aparelho parado na versao 1 chega
  /// na 3 passando pela 2, sem caminho especial.
  static Future<void> _migrar(Database bd, int de, int para) async {
    if (de < 2) {
      await _criarAulaVista(bd);
    }
  }

  static Future<void> _criar(Database bd, int _) async {
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
    // Os dois indices existem para as consultas que o app fara de verdade:
    // retomar uma licao, e um dia apontar em que topico o aluno mais tropeca.
    await bd.execute('CREATE INDEX idx_resposta_licao ON resposta(lesson_id)');
    await bd.execute('CREATE INDEX idx_resposta_topico ON resposta(topic)');

    await bd.execute('''
      CREATE TABLE posicao (
        lesson_id     TEXT PRIMARY KEY,
        indice        INTEGER NOT NULL,
        atualizada_em INTEGER NOT NULL
      )
    ''');

    await _criarAulaVista(bd);
  }

  /// Fica em funcao propria para o `onCreate` e o `onUpgrade` usarem a mesma
  /// definicao. Duas copias do mesmo CREATE TABLE divergem com o tempo, e a
  /// diferenca so aparece em quem instalou o app numa versao especifica.
  static Future<void> _criarAulaVista(Database bd) => bd.execute('''
    CREATE TABLE aula_vista (
      lesson_id TEXT PRIMARY KEY,
      vista_em  INTEGER NOT NULL
    )
  ''');

  Future<void> fechar() => _bd.close();

  /// Grava o resultado de uma questao respondida.
  ///
  /// Sobrescreve se ja existir: refazer uma licao substitui o registro
  /// anterior, e o `question_id` e chave primaria justamente por isso. Como o
  /// id da questao e imutavel no banco de conteudo, o registro do aluno
  /// continua apontando para a mesma questao entre versoes do app.
  @override
  Future<void> registrar({
    required Lesson licao,
    required Question questao,
    required SessaoQuestao sessao,
    DateTime? quando,
  }) async {
    if (!sessao.terminou) return;

    await _bd.insert('resposta', {
      'question_id': questao.id,
      'lesson_id': licao.lessonId,
      'language': licao.language,
      'level': licao.level.name,
      'topic': questao.topic,
      'tentativas': sessao.tentativas,
      'desfecho': sessao.fase == FaseResposta.acertou
          ? Desfecho.acertou.name
          : Desfecho.revelada.name,
      'respondida_em': (quando ?? DateTime.now()).millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<RespostaGravada?> respostaDe(String questionId) async {
    final linhas = await _bd.query(
      'resposta',
      where: 'question_id = ?',
      whereArgs: [questionId],
      limit: 1,
    );
    return linhas.isEmpty ? null : _lerResposta(linhas.first);
  }

  Future<List<RespostaGravada>> respostasDa(String lessonId) async {
    final linhas = await _bd.query(
      'resposta',
      where: 'lesson_id = ?',
      whereArgs: [lessonId],
      orderBy: 'respondida_em',
    );
    return linhas.map(_lerResposta).toList(growable: false);
  }

  /// Onde o aluno parou nesta licao. Nulo se ele nunca a abriu.
  @override
  Future<int?> posicaoDe(String lessonId) async {
    final linhas = await _bd.query(
      'posicao',
      columns: ['indice'],
      where: 'lesson_id = ?',
      whereArgs: [lessonId],
      limit: 1,
    );
    return linhas.isEmpty ? null : linhas.first['indice'] as int;
  }

  /// Guarda em que questao o aluno esta.
  ///
  /// E o que faz o botao sair nao precisar perguntar "tem certeza": se o
  /// progresso e salvo a cada questao, perguntar seria ruido.
  @override
  Future<void> salvarPosicao(String lessonId, int indice, {DateTime? quando}) {
    return _bd.insert('posicao', {
      'lesson_id': lessonId,
      'indice': indice,
      'atualizada_em': (quando ?? DateTime.now()).millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Se o aluno ja viu a aula desta licao.
  ///
  /// A aula aparece sozinha na primeira vez. Depois disso ela continua
  /// acessivel, mas nao se impoe: quem ja leu nao precisa passar por ela de
  /// novo para chegar nas questoes.
  @override
  Future<bool> aulaFoiVista(String lessonId) async {
    final linhas = await _bd.query(
      'aula_vista',
      columns: ['lesson_id'],
      where: 'lesson_id = ?',
      whereArgs: [lessonId],
      limit: 1,
    );
    return linhas.isNotEmpty;
  }

  @override
  Future<void> marcarAulaVista(String lessonId, {DateTime? quando}) {
    return _bd.insert('aula_vista', {
      'lesson_id': lessonId,
      'vista_em': (quando ?? DateTime.now()).millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Quantas questoes ja foram respondidas em cada licao.
  ///
  /// Uma consulta so, agrupada, em vez de uma por licao: a trilha mostra todas
  /// de uma vez, e cinco idas ao banco para desenhar uma lista seriam
  /// desperdicio que cresce com o numero de licoes.
  ///
  /// E aqui o progresso gravado deixa de ser dado guardado e vira algo que o
  /// aluno enxerga.
  @override
  Future<Map<String, int>> respondidasPorLicao() async {
    final linhas = await _bd.rawQuery(
      'SELECT lesson_id, COUNT(*) AS total FROM resposta GROUP BY lesson_id',
    );
    return {
      for (final l in linhas) l['lesson_id'] as String: l['total'] as int,
    };
  }

  /// Quanto cada topico custou, do mais caro para o mais barato.
  ///
  /// Nao e usado por nenhuma tela ainda. Existe para provar que o formato
  /// escolhido responde a pergunta que motivou guardar tentativas.
  Future<List<CustoDoTopico>> custoPorTopico() async {
    final linhas = await _bd.rawQuery('''
      SELECT topic,
             COUNT(*)          AS questoes,
             SUM(tentativas)   AS tentativas,
             SUM(CASE WHEN desfecho = ? THEN 1 ELSE 0 END) AS reveladas
        FROM resposta
       GROUP BY topic
       ORDER BY (CAST(SUM(tentativas) AS REAL) / COUNT(*)) DESC, topic
    ''', [Desfecho.revelada.name]);

    return linhas
        .map(
          (l) => CustoDoTopico(
            topic: l['topic'] as String,
            questoes: l['questoes'] as int,
            tentativas: (l['tentativas'] as int?) ?? 0,
            reveladas: (l['reveladas'] as int?) ?? 0,
          ),
        )
        .toList(growable: false);
  }

  static RespostaGravada _lerResposta(Map<String, Object?> l) => RespostaGravada(
    questionId: l['question_id'] as String,
    lessonId: l['lesson_id'] as String,
    language: l['language'] as String,
    level: l['level'] as String,
    topic: l['topic'] as String,
    tentativas: l['tentativas'] as int,
    desfecho: l['desfecho'] == Desfecho.acertou.name
        ? Desfecho.acertou
        : Desfecho.revelada,
    respondidaEm: DateTime.fromMillisecondsSinceEpoch(
      l['respondida_em'] as int,
    ),
  );
}
