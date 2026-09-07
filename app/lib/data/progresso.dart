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

  /// Quem ainda nao jogou nada.
  ///
  /// Existe para a tela de estatisticas ter um estado inicial sem inventar
  /// zeros espalhados, e para os falsos de teste nao repetirem nove campos.
  static const ResumoDoJogador vazio = ResumoDoJogador(
    respondidas: 0,
    deCabeca: 0,
    reveladas: 0,
    tentativas: 0,
    comDica: 0,
    tempoMedido: Duration.zero,
    questoesComTempo: 0,
    partidas: 0,
    diasEstudados: 0,
  );

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

  /// O retrato do desempenho, para a tela de estatisticas.
  ///
  /// Esta aqui, e nao so em [Progresso], porque a trilha -- que e quem abre a
  /// tela -- so enxerga esta interface. Ver [RegistroDeProgresso].
  Future<ResumoDoJogador> resumoDoJogador();

  /// Quanto cada topico custou, do mais caro para o mais barato.
  Future<List<CustoDoTopico>> custoPorTopico();

  Future<bool> somLigado();

  Future<void> definirSom({required bool ligado});

  Future<bool> cenarioLigado();

  Future<void> definirCenario({required bool ligado});
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
  /// Versao 5: progresso por usuario, e estado derivado do historico.
  static const int versao = 5;

  /// Dono das linhas gravadas ANTES de existir conta.
  ///
  /// O app rodou um tempo sem login, e o progresso daquela epoca nao tem dono.
  /// Apagar seria a saida facil e destruiria o que a pessoa ja jogou, que e
  /// exatamente o que este arquivo existe para nao fazer.
  ///
  /// Combinado com o Gustavo: **a primeira conta que autenticar no aparelho
  /// adota esse progresso**. Ver [adotarProgressoOrfao].
  static const String semDono = '';

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

  /// Chaves da tabela `preferencia`.
  ///
  /// Ela nasceu generica -- chave e valor, em vez de uma coluna por opcao --
  /// justamente porque o CLAUDE.md ja previa a segunda chave, a do fundo
  /// animado. Ela chegou, e nao custou migracao nenhuma.
  static const String prefSom = 'som';
  static const String prefCenario = 'cenario';

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
    if (de < 5) {
      await _migrarParaPorUsuario(bd);
    }
  }

  /// Degrau 5: cada linha passa a ter dono, e o historico ganha id estavel.
  ///
  /// **Por que recriar as tabelas em vez de usar ALTER.** O SQLite nao permite
  /// alterar a chave primaria de uma tabela existente, e a chave precisa mudar:
  /// de `question_id` para `(uid, question_id)`. Sem isso, duas contas no mesmo
  /// aparelho sobrescreveriam o progresso uma da outra.
  ///
  /// O caminho e o padrao do proprio SQLite: cria a tabela nova ao lado, COPIA
  /// os dados, derruba a antiga e renomeia. Em nenhum momento os dados deixam
  /// de existir -- e um teste prova que o progresso sobrevive.
  ///
  /// As linhas antigas ficam com [semDono], e nao com um uid inventado. Elas
  /// realmente nao tinham dono, e fingir o contrario impediria [adotarProgressoOrfao]
  /// de encontra-las depois.
  static Future<void> _migrarParaPorUsuario(Database bd) async {
    await bd.transaction((txn) async {
      // Os indices vem PRIMEIRO, e por um motivo que custou uma rodada de
      // testes: no SQLite, renomear uma tabela **nao renomeia os indices dela**.
      // Eles continuam existindo com o nome antigo, apontando para a tabela
      // renomeada -- e ai o `CREATE INDEX` da tabela nova falha com "index
      // already exists", derrubando a migracao inteira no meio.
      for (final indice in [
        'idx_resposta_licao',
        'idx_resposta_topico',
        'idx_evento_quando',
        'idx_evento_questao',
        'idx_evento_pendente',
      ]) {
        await txn.execute('DROP INDEX IF EXISTS $indice');
      }

      // --- resposta ---
      await txn.execute('ALTER TABLE resposta RENAME TO resposta_antiga');
      await _criarResposta(txn);
      await txn.execute('''
        INSERT INTO resposta (uid, question_id, lesson_id, language, level,
                              topic, tentativas, desfecho, usou_dica,
                              duracao_ms, respondida_em)
        SELECT '$semDono', question_id, lesson_id, language, level, topic,
               tentativas, desfecho, usou_dica, duracao_ms, respondida_em
          FROM resposta_antiga
      ''');
      await txn.execute('DROP TABLE resposta_antiga');

      // --- posicao ---
      await txn.execute('ALTER TABLE posicao RENAME TO posicao_antiga');
      await _criarPosicao(txn);
      await txn.execute('''
        INSERT INTO posicao (uid, lesson_id, indice, atualizada_em)
        SELECT '$semDono', lesson_id, indice, atualizada_em FROM posicao_antiga
      ''');
      await txn.execute('DROP TABLE posicao_antiga');

      // --- aula_vista ---
      await txn.execute('ALTER TABLE aula_vista RENAME TO aula_vista_antiga');
      await _criarAulaVista(txn);
      await txn.execute('''
        INSERT INTO aula_vista (uid, lesson_id, vista_em)
        SELECT '$semDono', lesson_id, vista_em FROM aula_vista_antiga
      ''');
      await txn.execute('DROP TABLE aula_vista_antiga');

      // --- preferencia ---
      await txn.execute('ALTER TABLE preferencia RENAME TO preferencia_antiga');
      await _criarPreferencia(txn);
      await txn.execute('''
        INSERT INTO preferencia (uid, chave, valor)
        SELECT '$semDono', chave, valor FROM preferencia_antiga
      ''');
      await txn.execute('DROP TABLE preferencia_antiga');

      // --- evento_resposta ---
      //
      // O id passa de INTEGER AUTOINCREMENT para um TEXTO deterministico.
      // O motivo e a sincronizacao: dois aparelhos gerariam o id 1 para
      // partidas diferentes, e ao juntar os historicos um sobrescreveria o
      // outro. O id novo e derivado do proprio conteudo, entao a mesma partida
      // produz o mesmo id em qualquer aparelho -- e reenviar nao duplica.
      await txn.execute(
        'ALTER TABLE evento_resposta RENAME TO evento_resposta_antiga',
      );
      await _criarEventoResposta(txn);
      await txn.execute('''
        INSERT OR IGNORE INTO evento_resposta
              (evento_id, uid, question_id, lesson_id, language, level, topic,
               tentativas, desfecho, usou_dica, duracao_ms, respondida_em,
               sincronizado)
        SELECT '$semDono' || '|' || question_id || '|' || respondida_em,
               '$semDono', question_id, lesson_id, language, level, topic,
               tentativas, desfecho, usou_dica, duracao_ms, respondida_em, 0
          FROM evento_resposta_antiga
      ''');
      await txn.execute('DROP TABLE evento_resposta_antiga');
    });
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
    await _criarResposta(bd);
    await _criarPosicao(bd);
    await _criarAulaVista(bd);
    await _criarPreferencia(bd);
    await _criarEventoResposta(bd);
  }

  /// O ESTADO ATUAL, derivado do historico.
  ///
  /// Uma linha por questao **por usuario**: a chave e `(uid, question_id)`, e
  /// nao mais so `question_id`. Sem o `uid` na chave, duas contas no mesmo
  /// aparelho sobrescreveriam o progresso uma da outra -- o defeito que a
  /// versao 5 existe para corrigir.
  ///
  /// **Esta tabela e um cache.** A verdade mora em `evento_resposta`, e daqui
  /// ela pode ser reconstruida a qualquer momento por [recalcularEstado]. Ela
  /// existe porque a trilha precisa contar questoes respondidas toda vez que
  /// abre, e varrer o historico inteiro para isso ficaria lento conforme o
  /// aluno joga.
  static Future<void> _criarResposta(DatabaseExecutor bd) async {
    await bd.execute('''
      CREATE TABLE resposta (
        uid           TEXT NOT NULL,
        question_id   TEXT NOT NULL,
        lesson_id     TEXT NOT NULL,
        language      TEXT NOT NULL,
        level         TEXT NOT NULL,
        topic         TEXT NOT NULL,
        tentativas    INTEGER NOT NULL,
        desfecho      TEXT NOT NULL,
        ${_colunasDeMedicao.join(',\n        ')},
        respondida_em INTEGER NOT NULL,
        PRIMARY KEY (uid, question_id)
      )
    ''');
    await bd.execute(
      'CREATE INDEX idx_resposta_licao ON resposta(uid, lesson_id)',
    );
    await bd.execute(
      'CREATE INDEX idx_resposta_topico ON resposta(uid, topic)',
    );
  }

  static Future<void> _criarPosicao(DatabaseExecutor bd) => bd.execute('''
    CREATE TABLE posicao (
      uid           TEXT NOT NULL,
      lesson_id     TEXT NOT NULL,
      indice        INTEGER NOT NULL,
      atualizada_em INTEGER NOT NULL,
      PRIMARY KEY (uid, lesson_id)
    )
  ''');

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
  static Future<void> _criarEventoResposta(DatabaseExecutor bd) async {
    await bd.execute('''
      CREATE TABLE evento_resposta (
        evento_id     TEXT    PRIMARY KEY,
        uid           TEXT    NOT NULL,
        question_id   TEXT    NOT NULL,
        lesson_id     TEXT    NOT NULL,
        language      TEXT    NOT NULL,
        level         TEXT    NOT NULL,
        topic         TEXT    NOT NULL,
        tentativas    INTEGER NOT NULL,
        desfecho      TEXT    NOT NULL,
        usou_dica     INTEGER NOT NULL,
        duracao_ms    INTEGER,
        respondida_em INTEGER NOT NULL,
        sincronizado  INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await bd.execute(
      'CREATE INDEX idx_evento_quando ON evento_resposta(uid, respondida_em)',
    );
    await bd.execute(
      'CREATE INDEX idx_evento_questao ON evento_resposta(uid, question_id)',
    );
    // A sincronizacao pergunta "o que ainda nao subiu?" a cada gravacao.
    await bd.execute(
      'CREATE INDEX idx_evento_pendente ON evento_resposta(uid, sincronizado)',
    );
  }

  /// O identificador de uma partida, igual em qualquer aparelho.
  ///
  /// Derivado do proprio conteudo -- dono, questao e instante -- em vez de um
  /// contador local. Isso resolve dois problemas de uma vez:
  ///
  /// - **Nao colide entre aparelhos.** Com `AUTOINCREMENT`, o celular e o
  ///   tablet gerariam o id 1 para partidas diferentes, e ao juntar os
  ///   historicos uma sobrescreveria a outra
  /// - **Reenviar nao duplica.** A mesma partida produz sempre o mesmo id,
  ///   entao mandar de novo para a nuvem e inofensivo. Sincronizacao que nao e
  ///   idempotente vira historico inflado na primeira queda de conexao
  static String idDoEvento(String uid, String questionId, int quando) =>
      '$uid|$questionId|$quando';

  /// Fica em funcao propria para o `onCreate` e o `onUpgrade` usarem a mesma
  /// definicao. Duas copias do mesmo CREATE TABLE divergem com o tempo, e a
  /// diferenca so aparece em quem instalou o app numa versao especifica.
  static Future<void> _criarAulaVista(DatabaseExecutor bd) => bd.execute('''
    CREATE TABLE aula_vista (
      uid       TEXT NOT NULL,
      lesson_id TEXT NOT NULL,
      vista_em  INTEGER NOT NULL,
      PRIMARY KEY (uid, lesson_id)
    )
  ''');

  static Future<void> _criarPreferencia(DatabaseExecutor bd) => bd.execute('''
    CREATE TABLE preferencia (
      uid   TEXT NOT NULL,
      chave TEXT NOT NULL,
      valor TEXT NOT NULL,
      PRIMARY KEY (uid, chave)
    )
  ''');

  /// De quem e o progresso que este objeto le e grava.
  ///
  /// Comeca em [semDono], que e o estado de quem ainda nao entrou. Com login
  /// obrigatorio isso dura pouco: o `main.dart` chama [entrarComo] assim que a
  /// autenticacao devolve um usuario.
  ///
  /// Guardado aqui, e nao passado em cada chamada, porque as telas dependem de
  /// [RegistroDeProgresso] e nao tem -- nem deveriam ter -- nocao de uid. A
  /// tela de exercicio pergunta "grave esta resposta"; de quem ela e, e assunto
  /// desta camada.
  String _uid = semDono;

  String get usuarioAtual => _uid;

  /// Passa a ler e gravar o progresso desta conta.
  ///
  /// **Adota o progresso orfao na primeira vez**, e so na primeira: se houver
  /// linhas sem dono no aparelho, elas passam a pertencer a esta conta. Foi o
  /// combinado com o Gustavo, e existe porque o app rodou um tempo sem login e
  /// aquele progresso e real.
  ///
  /// A segunda conta a entrar no mesmo aparelho **nao** encontra nada orfao,
  /// entao comeca do zero -- que e o comportamento certo.
  Future<void> entrarComo(String uid) async {
    _uid = uid;
    await adotarProgressoOrfao(uid);
  }

  /// Da dono ao progresso gravado antes de existir conta.
  ///
  /// Usa `INSERT OR IGNORE` seguido de `DELETE` em vez de um `UPDATE` direto:
  /// se a conta ja tiver respondido a mesma questao, o `UPDATE` violaria a
  /// chave primaria e a migracao inteira falharia. Assim, o que ja e da conta
  /// prevalece, e o orfao que sobra e descartado.
  Future<int> adotarProgressoOrfao(String uid) async {
    if (uid == semDono) return 0;
    var adotadas = 0;
    await _bd.transaction((txn) async {
      for (final tabela in ['resposta', 'posicao', 'aula_vista',
                            'preferencia', 'evento_resposta']) {
        final antes = Sqflite.firstIntValue(
              await txn.rawQuery(
                'SELECT COUNT(*) FROM $tabela WHERE uid = ?',
                [semDono],
              ),
            ) ??
            0;
        if (antes == 0) continue;

        final colunas = (await txn.rawQuery('PRAGMA table_info($tabela)'))
            .map((c) => c['name'] as String)
            .toList();
        final lista = colunas.join(', ');
        final selecao = colunas
            .map((c) => c == 'uid' ? '?' : c)
            .join(', ');

        // O evento tem id derivado do uid, entao ele PRECISA ser recalculado:
        // manter o id antigo deixaria o historico com identificadores que nao
        // batem com o dono, e a sincronizacao os trataria como de outra pessoa.
        if (tabela == 'evento_resposta') {
          await txn.rawInsert(
            'INSERT OR IGNORE INTO evento_resposta ($lista) '
            "SELECT ? || '|' || question_id || '|' || respondida_em, ?, "
            '${colunas.where((c) => c != 'evento_id' && c != 'uid').join(', ')} '
            'FROM evento_resposta WHERE uid = ?',
            [uid, uid, semDono],
          );
        } else {
          await txn.rawInsert(
            'INSERT OR IGNORE INTO $tabela ($lista) '
            'SELECT $selecao FROM $tabela WHERE uid = ?',
            [uid, semDono],
          );
        }
        await txn.delete(tabela, where: 'uid = ?', whereArgs: [semDono]);
        adotadas += antes;
      }
    });
    return adotadas;
  }

  /// Reconstroi o ESTADO ATUAL a partir do historico.
  ///
  /// Esta e a decisao central da sincronizacao, e o Gustavo escolheu ela: em
  /// vez de resolver conflito entre duas versoes do mesmo progresso, o app
  /// **elimina a possibilidade dele**. O historico so cresce e nunca conflita
  /// -- juntar o de dois aparelhos e juntar duas listas -- e o estado atual
  /// deixa de ser um dado disputado para virar um resumo calculado.
  ///
  /// A regra de agregacao e "a partida mais recente de cada questao", com
  /// desempate pelo id do evento. O desempate importa: sem ele, duas partidas
  /// no mesmo milissegundo dariam resultados diferentes conforme a ordem em que
  /// os eventos chegassem, e a promessa de determinismo cairia por terra.
  ///
  /// Rodar isto duas vezes produz o mesmo resultado. Rodar depois de receber
  /// eventos novos produz o estado certo. E o que torna a sincronizacao segura
  /// para repetir.
  Future<void> recalcularEstado([String? deQuem]) async {
    final uid = deQuem ?? _uid;
    await _bd.transaction((txn) async {
      await txn.delete('resposta', where: 'uid = ?', whereArgs: [uid]);
      await txn.rawInsert('''
        INSERT INTO resposta (uid, question_id, lesson_id, language, level,
                              topic, tentativas, desfecho, usou_dica,
                              duracao_ms, respondida_em)
        SELECT uid, question_id, lesson_id, language, level, topic,
               tentativas, desfecho, usou_dica, duracao_ms, respondida_em
          FROM evento_resposta e
         WHERE uid = ?
           AND evento_id = (
             SELECT evento_id FROM evento_resposta
              WHERE uid = e.uid AND question_id = e.question_id
              ORDER BY respondida_em DESC, evento_id DESC
              LIMIT 1
           )
      ''', [uid]);
    });
  }

  // ------------------------------------------------------------ sincronizacao
  //
  // O Progresso nao conhece o Firestore, e nao deve conhecer. Ele expoe o que
  // a sincronizacao precisa -- o que falta subir, o que chegou, ate onde ja
  // fomos -- e quem fala com a nuvem e o `Sincronizador`.

  /// Chave da marca d'agua: ate quando ja baixamos da nuvem.
  static const String _marcaDeSincronizacao = 'sync_ate';

  /// Os eventos que ainda nao subiram.
  ///
  /// O limite existe para uma primeira sincronizacao nao tentar subir mil
  /// documentos numa tacada e estourar tempo ou cota. O que sobrar vai na
  /// proxima rodada -- e como o envio e idempotente, repetir nao custa nada.
  Future<List<Map<String, Object?>>> eventosPendentes({int limite = 400}) {
    return _bd.query(
      'evento_resposta',
      where: 'uid = ? AND sincronizado = 0',
      whereArgs: [_uid],
      orderBy: 'respondida_em',
      limit: limite,
    );
  }

  /// Marca eventos como ja enviados.
  Future<void> marcarSincronizados(Iterable<String> ids) async {
    if (ids.isEmpty) return;
    final lista = ids.toList();
    final vagas = List.filled(lista.length, '?').join(', ');
    await _bd.rawUpdate(
      'UPDATE evento_resposta SET sincronizado = 1 WHERE evento_id IN ($vagas)',
      lista,
    );
  }

  /// Guarda eventos que vieram da nuvem, e recalcula o estado.
  ///
  /// `INSERT OR IGNORE`: o que ja existe localmente fica como esta. Isso e o
  /// que torna a operacao segura para repetir -- e sincronizacao repete o tempo
  /// todo, por queda de conexao e por reenvio.
  ///
  /// Os eventos chegam marcados como **ja sincronizados**, porque vieram de la:
  /// devolve-los seria trafego a toa.
  ///
  /// Devolve quantos eram novos de verdade.
  Future<int> receberEventos(List<Map<String, Object?>> remotos) async {
    if (remotos.isEmpty) return 0;

    var novos = 0;
    await _bd.transaction((txn) async {
      for (final evento in remotos) {
        final inseriu = await txn.insert(
          'evento_resposta',
          {...evento, 'sincronizado': 1},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        if (inseriu != 0) novos++;
      }
    });

    // So recalcula se algo mudou. Recalcular a toa nao quebra nada -- a
    // operacao e idempotente -- mas varre o historico inteiro sem motivo.
    if (novos > 0) await recalcularEstado();
    return novos;
  }

  /// Ate quando ja baixamos da nuvem, em milissegundos do relogio do SERVIDOR.
  ///
  /// A marca e sobre quando o evento **chegou ao servidor**, e nao sobre quando
  /// a questao foi respondida. A diferenca importa: um aparelho que ficou uma
  /// semana offline sobe partidas antigas hoje, e uma marca baseada em
  /// `respondida_em` as consideraria ja vistas e nunca as baixaria no outro
  /// aparelho.
  Future<int> marcaDeSincronizacao() async {
    final linhas = await _bd.query(
      'preferencia',
      columns: ['valor'],
      where: 'uid = ? AND chave = ?',
      whereArgs: [_uid, _marcaDeSincronizacao],
      limit: 1,
    );
    if (linhas.isEmpty) return 0;
    return int.tryParse(linhas.first['valor'] as String) ?? 0;
  }

  Future<void> definirMarcaDeSincronizacao(int quando) {
    return _bd.insert('preferencia', {
      'uid': _uid,
      'chave': _marcaDeSincronizacao,
      'valor': '$quando',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Apaga o estado atual sem tocar no historico. Existe para o teste provar
  /// que `resposta` e mesmo um cache reconstruivel.
  Future<void> apagarEstadoParaTeste() =>
      _bd.delete('resposta', where: 'uid = ?', whereArgs: [_uid]);

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

    final instante = (quando ?? DateTime.now()).millisecondsSinceEpoch;
    final dados = {
      'uid': _uid,
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
      'respondida_em': instante,
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
      await txn.insert('evento_resposta', {
        ...dados,
        'evento_id': idDoEvento(_uid, questao.id, instante),
        'sincronizado': 0,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    });
  }

  Future<RespostaGravada?> respostaDe(String questionId) async {
    final linhas = await _bd.query(
      'resposta',
      where: 'uid = ? AND question_id = ?',
      whereArgs: [_uid, questionId],
      limit: 1,
    );
    return linhas.isEmpty ? null : _lerResposta(linhas.first);
  }

  Future<List<RespostaGravada>> respostasDa(String lessonId) async {
    final linhas = await _bd.query(
      'resposta',
      where: 'uid = ? AND lesson_id = ?',
      whereArgs: [_uid, lessonId],
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
      where: 'uid = ? AND lesson_id = ?',
      whereArgs: [_uid, lessonId],
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
      'uid': _uid,
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
      where: 'uid = ? AND lesson_id = ?',
      whereArgs: [_uid, lessonId],
      limit: 1,
    );
    return linhas.isNotEmpty;
  }

  @override
  Future<void> marcarAulaVista(String lessonId, {DateTime? quando}) {
    return _bd.insert('aula_vista', {
      'uid': _uid,
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
      'SELECT lesson_id, COUNT(*) AS total FROM resposta '
      'WHERE uid = ? GROUP BY lesson_id',
      [_uid],
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
  Future<bool> somLigado() => _preferencia(prefSom);

  @override
  Future<void> definirSom({required bool ligado}) =>
      _definirPreferencia(prefSom, ligado);

  /// Se o cenario animado da tela de exercicio esta ligado. Ligado por padrao.
  ///
  /// E a chave manual prevista nas regras de performance do fundo animado.
  /// Movimento constante no canto da tela incomoda parte das pessoas, e nem
  /// todo aparelho tem bateria de sobra para animar a 60 quadros por segundo.
  @override
  Future<bool> cenarioLigado() => _preferencia(prefCenario);

  @override
  Future<void> definirCenario({required bool ligado}) =>
      _definirPreferencia(prefCenario, ligado);

  /// Toda preferencia e booleana e **ligada por padrao**: ausencia de linha
  /// significa "nunca mexeram nisto", nao "desligado".
  Future<bool> _preferencia(String chave) async {
    final linhas = await _bd.query(
      'preferencia',
      columns: ['valor'],
      where: 'uid = ? AND chave = ?',
      whereArgs: [_uid, chave],
      limit: 1,
    );
    if (linhas.isEmpty) return true;
    return linhas.first['valor'] == '1';
  }

  Future<void> _definirPreferencia(String chave, bool ligado) {
    return _bd.insert('preferencia', {
      'uid': _uid,
      'chave': chave,
      'valor': ligado ? '1' : '0',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Quanto cada topico custou, do mais caro para o mais barato.
  ///
  /// Nao e usado por nenhuma tela ainda. Existe para provar que o formato
  /// escolhido responde a pergunta que motivou guardar tentativas.
  /// ATENCAO a ordem dos `?`: ela segue a posicao no TEXTO da consulta, nao a
  /// ordem logica dos argumentos. Ao acrescentar `WHERE uid = ?` no fim, o
  /// `_uid` tambem tem que ir para o fim da lista -- posto no comeco, ele
  /// alimentava o `desfecho = ?` e a consulta virava `WHERE uid = 'revelada'`,
  /// devolvendo zero linhas em silencio. Um teste pegou; o analisador nao pega.
  @override
  Future<List<CustoDoTopico>> custoPorTopico() async {
    final linhas = await _bd.rawQuery('''
      SELECT topic,
             COUNT(*)          AS questoes,
             SUM(tentativas)   AS tentativas,
             SUM(CASE WHEN desfecho = ? THEN 1 ELSE 0 END) AS reveladas
        FROM resposta
       WHERE uid = ?
       GROUP BY topic
       ORDER BY (CAST(SUM(tentativas) AS REAL) / COUNT(*)) DESC, topic
    ''', [Desfecho.revelada.name, _uid]);

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
  @override
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
       WHERE uid = ?
    ''', [Desfecho.acertou.name, Desfecho.revelada.name, _uid])).first;

    // `date(..., 'unixepoch', 'localtime')` agrupa por dia no fuso do aparelho:
    // agrupar em UTC contaria como dois dias uma noite de estudo que virou.
    final historico = (await _bd.rawQuery('''
      SELECT COUNT(*)                                            AS partidas,
             COUNT(DISTINCT date(respondida_em / 1000,
                                 'unixepoch', 'localtime'))      AS dias
        FROM evento_resposta
       WHERE uid = ?
    ''', [_uid])).first;

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
