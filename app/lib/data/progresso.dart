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

  /// Quanto tempo levou. **Nulo quando nao foi medido**, e nao zero.
  ///
  /// Duas situacoes produzem nulo, e as duas sao reais: a partida aconteceu
  /// antes de o app passar a medir (versao 3 do banco ou anterior), ou a
  /// medicao estourou o teto de [Progresso.tetoDeDuracao] e foi descartada.
  ///
  /// Guardar zero no lugar seria mais simples e mentiria nas medias: uma
  /// questao "respondida em 0 segundo" puxaria a media para baixo e ninguem
  /// saberia por que. Quem for exibir isso tem que tratar o nulo.
  final Duration? duracao;

  /// Se o aluno **pediu** a dica. Nulo quando a partida e anterior a medicao.
  ///
  /// Pedir e diferente de a dica ter aberto sozinha no segundo erro: so o
  /// primeiro e escolha dele. Ver `SessaoQuestao.dicaPedida`.
  final bool? usouDica;

  const RespostaGravada({
    required this.questionId,
    required this.lessonId,
    required this.language,
    required this.level,
    required this.topic,
    required this.tentativas,
    required this.desfecho,
    required this.respondidaEm,
    this.duracao,
    this.usouDica,
  });

  /// Acertou de primeira, sem tropecos.
  bool get deCabeca => desfecho == Desfecho.acertou && tentativas == 1;
}

/// O retrato do desempenho do aluno, para a tela de estatisticas.
///
/// Nenhuma tela usa isto ainda, pelo mesmo motivo de [CustoDoTopico]: existe
/// para **provar que o formato responde as perguntas** que motivaram guardar os
/// dados. Descobrir que falta uma coluna no dia de desenhar a tela seria tarde
/// demais, porque coluna que nao existia nao tem como ser preenchida no passado.
class ResumoDoJogador {
  /// Questoes distintas ja respondidas.
  final int respondidas;

  /// Dessas, quantas sairam de primeira.
  final int deCabeca;

  /// Dessas, quantas terminaram reveladas.
  final int reveladas;

  /// Soma de tentativas sobre [respondidas].
  final int tentativas;

  /// Em quantas o aluno pediu a dica.
  final int comDica;

  /// Tempo somado, e sobre quantas questoes ele foi medido.
  ///
  /// As duas andam juntas de proposito: dividir o tempo por [respondidas]
  /// daria uma media errada enquanto houver partidas sem medicao.
  final Duration tempoMedido;
  final int questoesComTempo;

  /// Quantas vezes uma questao foi respondida, contando as repetidas.
  ///
  /// Diferente de [respondidas]: refazer uma licao nao aumenta aquele numero,
  /// mas aumenta este. E o que permite falar em evolucao.
  final int partidas;

  /// Em quantos dias distintos o aluno jogou.
  final int diasEstudados;

  const ResumoDoJogador({
    required this.respondidas,
    required this.deCabeca,
    required this.reveladas,
    required this.tentativas,
    required this.comDica,
    required this.tempoMedido,
    required this.questoesComTempo,
    required this.partidas,
    required this.diasEstudados,
  });

  double get taxaDeCabeca => respondidas == 0 ? 0 : deCabeca / respondidas;
  double get tentativasPorQuestao =>
      respondidas == 0 ? 0 : tentativas / respondidas;

  /// Media so sobre o que foi medido. Nula quando nada foi.
  Duration? get tempoMedioPorQuestao => questoesComTempo == 0
      ? null
      : Duration(
          milliseconds: tempoMedido.inMilliseconds ~/ questoesComTempo,
        );
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

  Future<bool> somLigado();

  Future<void> definirSom({required bool ligado});
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
  /// Versao 3: tabela `preferencia`.
  /// Versao 4: medicao de tempo e de dica, e a tabela `evento_resposta`.
  static const int versao = 4;

  /// Acima disto a medicao de tempo e descartada e gravada como nula.
  ///
  /// O aluno pode largar o celular no meio de uma questao, e o app nao tem como
  /// saber a diferenca entre pensar e ir almocar. Sem teto, uma unica questao
  /// de seis horas destroi qualquer media, e a estatistica passa a mentir sem
  /// avisar -- pior do que nao existir.
  ///
  /// Dez minutos e um **chute** deliberadamente generoso: pensar seis minutos
  /// numa questao dificil e plausivel, dez ja e ter saido. Recalibrar quando
  /// houver dados reais de alguem jogando; ate la, e um numero escolhido sem
  /// evidencia, e esta escrito aqui que e.
  static const Duration tetoDeDuracao = Duration(minutes: 10);

  /// A duracao que deve ser gravada: a medida, ou nulo se implausivel.
  static int? duracaoGravavel(Duration? medida) {
    if (medida == null) return null;
    if (medida.isNegative || medida > tetoDeDuracao) return null;
    return medida.inMilliseconds;
  }

  /// Chave da preferencia de som. Tabela generica em vez de coluna propria
  /// porque o CLAUDE.md ja preve outra chave, a do fundo animado.
  static const String prefSom = 'som';

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
    if (de < 3) {
      await _criarPreferencia(bd);
    }
    if (de < 4) {
      // ALTER em vez de recriar: a tabela `resposta` tem o progresso do aluno
      // dentro. Colunas novas nascem nulas nas linhas antigas, que e exatamente
      // o que se quer -- aquelas partidas realmente nao foram medidas.
      for (final coluna in _colunasDeMedicao) {
        await bd.execute('ALTER TABLE resposta ADD COLUMN $coluna');
      }
      await _criarEventoResposta(bd);
    }
  }

  /// As colunas de medicao, numa lista so.
  ///
  /// Existem em duas rotas -- o `CREATE TABLE` de quem instala agora e o `ALTER
  /// TABLE` de quem atualiza -- e as duas precisam chegar ao mesmo esquema.
  /// Escrever a definicao aqui e o que impede as rotas de divergirem; um teste
  /// compara o `PRAGMA table_info` das duas para provar que nao divergiram.
  static const List<String> _colunasDeMedicao = [
    'duracao_ms INTEGER',
    'usou_dica INTEGER',
  ];

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
        respondida_em INTEGER NOT NULL,
        ${_colunasDeMedicao.join(',\n        ')}
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
    await _criarPreferencia(bd);
    await _criarEventoResposta(bd);
  }

  /// O historico, uma linha por vez que uma questao foi respondida.
  ///
  /// Existe porque `resposta` tem `question_id` como chave primaria: refazer
  /// uma licao **sobrescreve** o registro de la. Isso e correto para o estado
  /// atual, que e o que a trilha desenha, e destroi qualquer nocao de passado.
  /// Sem passado nao ha evolucao, nem ofensiva, nem "voce melhorou nisto".
  ///
  /// Por isso sao duas tabelas com papeis distintos, e nao uma so:
  ///
  /// - `resposta` e o **estado atual**, consultado a cada abertura da trilha.
  ///   Precisa continuar pequeno, com uma linha por questao existente
  /// - `evento_resposta` e o **historico**, so cresce, e e lido apenas quando
  ///   alguem abrir estatisticas
  ///
  /// Uma tabela unica obrigaria a escolher entre as duas coisas: ou a trilha
  /// passa a varrer o historico inteiro para contar quantas questoes foram
  /// respondidas, ou o historico e jogado fora a cada refazimento.
  static Future<void> _criarEventoResposta(Database bd) async {
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
    // A consulta de estatisticas percorre o historico por data e por questao.
    await bd.execute(
      'CREATE INDEX idx_evento_quando ON evento_resposta(respondida_em)',
    );
    await bd.execute(
      'CREATE INDEX idx_evento_questao ON evento_resposta(question_id)',
    );
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

  static Future<void> _criarPreferencia(Database bd) => bd.execute('''
    CREATE TABLE preferencia (
      chave TEXT PRIMARY KEY,
      valor TEXT NOT NULL
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

    final dados = {
      'question_id': questao.id,
      'lesson_id': licao.lessonId,
      'language': licao.language,
      'level': licao.level.name,
      'topic': questao.topic,
      'tentativas': sessao.tentativas,
      'desfecho': sessao.fase == FaseResposta.acertou
          ? Desfecho.acertou.name
          : Desfecho.revelada.name,
      'usou_dica': sessao.dicaPedida ? 1 : 0,
      'duracao_ms': duracaoGravavel(sessao.duracao),
      'respondida_em': (quando ?? DateTime.now()).millisecondsSinceEpoch,
    };

    // Numa transacao so: o estado atual e o historico contam a mesma coisa, e
    // gravar um sem o outro produziria um banco que se contradiz -- uma questao
    // respondida sem partida nenhuma, ou o contrario.
    await _bd.transaction((txn) async {
      await txn.insert(
        'resposta',
        dados,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      // Sem `question_id` como chave: aqui cada resposta e um evento novo, e
      // repetir a mesma questao e justamente o que se quer registrar.
      await txn.insert('evento_resposta', dados);
    });
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

  /// Se o som de acerto esta ligado. Ligado por padrao.
  ///
  /// O som nunca e o unico retorno: o verde e a explicacao continuam
  /// funcionando com ele mudo. Por isso desligar nao tira informacao nenhuma.
  @override
  Future<bool> somLigado() async {
    final linhas = await _bd.query(
      'preferencia',
      columns: ['valor'],
      where: 'chave = ?',
      whereArgs: [prefSom],
      limit: 1,
    );
    if (linhas.isEmpty) return true;
    return linhas.first['valor'] == '1';
  }

  @override
  Future<void> definirSom({required bool ligado}) {
    return _bd.insert('preferencia', {
      'chave': prefSom,
      'valor': ligado ? '1' : '0',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
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

  /// O retrato do desempenho do aluno.
  ///
  /// Lê das duas tabelas porque elas respondem perguntas diferentes: `resposta`
  /// diz como o aluno está **agora**, `evento_resposta` diz o que ele já fez.
  ///
  /// Nao e usado por nenhuma tela ainda, do mesmo jeito que [custoPorTopico].
  /// Existe para provar que o formato responde as perguntas que motivaram
  /// guardar os dados -- e essa prova tem que vir **antes** de alguem jogar,
  /// porque coluna que nao existia nao tem como ser preenchida no passado.
  Future<ResumoDoJogador> resumoDoJogador() async {
    final atual = (await _bd.rawQuery('''
      SELECT COUNT(*)                                            AS respondidas,
             SUM(CASE WHEN desfecho = ? AND tentativas = 1
                      THEN 1 ELSE 0 END)                         AS de_cabeca,
             SUM(CASE WHEN desfecho = ? THEN 1 ELSE 0 END)       AS reveladas,
             SUM(tentativas)                                     AS tentativas,
             SUM(CASE WHEN usou_dica = 1 THEN 1 ELSE 0 END)      AS com_dica,
             SUM(COALESCE(duracao_ms, 0))                        AS tempo_ms,
             SUM(CASE WHEN duracao_ms IS NOT NULL
                      THEN 1 ELSE 0 END)                         AS com_tempo
        FROM resposta
    ''', [Desfecho.acertou.name, Desfecho.revelada.name])).first;

    // `date(..., 'unixepoch', 'localtime')` agrupa por dia no fuso do aparelho:
    // agrupar em UTC contaria como dois dias uma noite de estudo que virou.
    final historico = (await _bd.rawQuery('''
      SELECT COUNT(*)                                            AS partidas,
             COUNT(DISTINCT date(respondida_em / 1000,
                                 'unixepoch', 'localtime'))      AS dias
        FROM evento_resposta
    ''')).first;

    int n(Map<String, Object?> linha, String coluna) =>
        (linha[coluna] as int?) ?? 0;

    return ResumoDoJogador(
      respondidas: n(atual, 'respondidas'),
      deCabeca: n(atual, 'de_cabeca'),
      reveladas: n(atual, 'reveladas'),
      tentativas: n(atual, 'tentativas'),
      comDica: n(atual, 'com_dica'),
      tempoMedido: Duration(milliseconds: n(atual, 'tempo_ms')),
      questoesComTempo: n(atual, 'com_tempo'),
      partidas: n(historico, 'partidas'),
      diasEstudados: n(historico, 'dias'),
    );
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
    // Nulo aqui significa "nao medido", e continua nulo ate a tela. Ver o
    // comentario em RespostaGravada.duracao.
    duracao: switch (l['duracao_ms']) {
      final int ms => Duration(milliseconds: ms),
      _ => null,
    },
    usouDica: switch (l['usou_dica']) {
      final int v => v == 1,
      _ => null,
    },
  );
}
