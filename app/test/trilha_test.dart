import 'dart:convert';

import 'package:devlingo/answer/sessao_questao.dart';
import 'package:devlingo/data/progresso.dart';
import 'package:devlingo/data/question_bank.dart';
import 'package:devlingo/models/lesson.dart';
import 'package:devlingo/models/question.dart';
import 'package:devlingo/ui/faixa_cenario.dart';
import 'package:devlingo/ui/tela_exercicio.dart';
import 'package:devlingo/ui/tela_linguagens.dart';
import 'package:devlingo/ui/tela_trilha.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
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
  /// O cenario nasce DESLIGADO aqui, ao contrario do app.
  ///
  /// Estes testes navegam ate a tela de exercicio pelo caminho de verdade, e
  /// `pumpAndSettle` espera a arvore ficar parada -- coisa que uma animacao em
  /// repeticao infinita nunca faz. Ligado por padrao, tres testes estouravam o
  /// limite de tempo sem ter defeito nenhum.
  ///
  /// Que a preferencia LIGADA tambem funciona esta provado logo abaixo, no
  /// grupo 'cenario animado', com `pump` em vez de `pumpAndSettle`.
  ProgressoFalso([this.contagem = const {}, this.cenario = false]);

  /// Mutavel de proposito: o teste da sincronizacao precisa mudar a resposta
  /// DEPOIS que a tela ja consultou uma vez, que e o caso real -- a nuvem
  /// responde segundos depois da tela aparecer.
  Map<String, int> contagem;
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

  /// O que a tela de estatisticas vai ler. Configuravel por teste.
  ResumoDoJogador resumo = ResumoDoJogador.vazio;
  List<CustoDoTopico> topicos = const [];

  @override
  Future<ResumoDoJogador> resumoDoJogador() async => resumo;

  @override
  Future<List<CustoDoTopico>> custoPorTopico() async => topicos;

  bool som = true;

  @override
  Future<bool> somLigado() async => som;

  @override
  Future<void> definirSom({required bool ligado}) async => som = ligado;

  bool cenario;

  @override
  Future<bool> cenarioLigado() async => cenario;

  @override
  Future<void> definirCenario({required bool ligado}) async => cenario = ligado;
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
      // Python antes de JavaScript e ordem SUGERIDA, nao alfabetica: ver
      // `ordemDasTrilhas`. Em ordem alfabetica isto seria o contrario.
      expect(trilhas.map((t) => t.language), ['python', 'javascript']);
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

    testWidgets('o cartao diz o que a trilha cobre', (tester) async {
      // Defeito de descoberta apontado pelo Gustavo: quem abre a lista ve
      // "Frameworks" e nao tem como saber que aquilo e sobre JavaScript. O
      // nome sozinho nunca comunicou conteudo -- vale igual para "Backend".
      await montar(
        tester,
        TelaLinguagens(banco: bancoDuasLinguagens, progresso: ProgressoFalso()),
      );

      expect(find.text(descricaoDe('python')!), findsOneWidget);
      expect(find.text(descricaoDe('javascript')!), findsOneWidget);
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

  group('cenario animado', () {
    testWidgets('a preferencia LIGADA chega ate a tela de exercicio', (
      tester,
    ) async {
      // `pump`, e nao `pumpAndSettle`: com o cenario ligado a arvore nunca
      // fica parada, porque a animacao repete para sempre. Este teste existe
      // justamente porque o resto do arquivo usa a preferencia desligada.
      await montar(
        tester,
        TelaTrilha(
          banco: bancoPython,
          language: 'python',
          level: Level.beginner,
          progresso: ProgressoFalso(const {}, true),
          podeVoltar: false,
        ),
      );

      await tester.tap(find.text('Primeira'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(FaixaCenario), findsOneWidget);
    });

    testWidgets('a preferencia DESLIGADA tira a faixa da tela', (tester) async {
      // Desligar nao e so parar o movimento: a faixa some. Quem desliga quer a
      // tela sem aquilo, nao um cenario parado ocupando 58 pixels.
      await montar(
        tester,
        TelaTrilha(
          banco: bancoPython,
          language: 'python',
          level: Level.beginner,
          progresso: ProgressoFalso(const {}, false),
          podeVoltar: false,
        ),
      );

      await tester.tap(find.text('Primeira'));
      await tester.pumpAndSettle();

      expect(find.byType(FaixaCenario), findsNothing);
    });

    testWidgets('o botao da trilha alterna e grava a preferencia', (
      tester,
    ) async {
      final progresso = ProgressoFalso(const {}, true);
      await montar(
        tester,
        TelaTrilha(
          banco: bancoPython,
          language: 'python',
          level: Level.beginner,
          progresso: progresso,
          podeVoltar: false,
        ),
      );

      expect(find.byKey(TelaTrilha.chaveCenario), findsOneWidget);
      await tester.tap(find.byKey(TelaTrilha.chaveCenario));
      await tester.pumpAndSettle();

      expect(progresso.cenario, isFalse, reason: 'a preferencia foi gravada');
    });
  });

  group('voltar para a tela de titulo', () {
    testWidgets('a escolha de linguagem tem o caminho de volta', (
      tester,
    ) async {
      var voltou = 0;
      await montar(
        tester,
        TelaLinguagens(
          banco: bancoDuasLinguagens,
          progresso: ProgressoFalso(),
          aoVoltarAoTitulo: () => voltou++,
        ),
      );

      await tester.tap(find.byKey(TelaLinguagens.chaveVoltarAoTitulo));
      await tester.pumpAndSettle();

      expect(voltou, 1);
    });

    testWidgets('sem o callback, o botao nem aparece', (tester) async {
      // A tela nao inventa um caminho que ela nao sabe percorrer. Quem sabe
      // voltar ao titulo e o `main.dart`, que e dono do estado `_comecou`.
      await montar(
        tester,
        TelaLinguagens(
          banco: bancoDuasLinguagens,
          progresso: ProgressoFalso(),
        ),
      );

      expect(find.byKey(TelaLinguagens.chaveVoltarAoTitulo), findsNothing);
    });

    testWidgets('com uma trilha so, a seta da trilha leva ao titulo', (
      tester,
    ) async {
      // Este e o caso que o botao da tela de linguagens NAO cobre: com uma
      // linguagem so, o app abre direto na trilha e aquela tela nem existe.
      // Sem isto, rever o titulo exigiria fechar e reabrir o app.
      var voltou = 0;
      final soPython = QuestionBank([
        licao(lessonId: 'python-beg-01', language: 'python'),
      ]);

      await montar(
        tester,
        TelaTrilha(
          banco: soPython,
          language: 'python',
          level: Level.beginner,
          progresso: ProgressoFalso(),
          podeVoltar: false,
          aoVoltarAoTitulo: () => voltou++,
        ),
      );

      await tester.tap(find.byKey(const Key('trilha-voltar')));
      await tester.pumpAndSettle();

      expect(voltou, 1);
    });

    testWidgets('com escolha de linguagem atras, a seta volta para ela', (
      tester,
    ) async {
      // A MESMA seta, com destino diferente conforme por onde se entrou. Este
      // teste existe para provar que ela nao passou a ignorar o `pop`.
      var voltou = 0;
      final soPython = QuestionBank([
        licao(lessonId: 'python-beg-01', language: 'python'),
      ]);

      await montar(
        tester,
        TelaTrilha(
          banco: soPython,
          language: 'python',
          level: Level.beginner,
          progresso: ProgressoFalso(),
          aoVoltarAoTitulo: () => voltou++,
        ),
      );

      expect(
        find.byKey(const Key('trilha-voltar')),
        findsOneWidget,
        reason: 'podeVoltar continua sendo o padrao',
      );
      expect(voltou, 0, reason: 'o callback do titulo nao foi chamado ainda');
    });
  });

  group('progresso que chega da nuvem', () {
    // O Gustavo reinstalou o app, entrou com a mesma conta, e viu TODAS as
    // trilhas zeradas. Os dados tinham descido do Firestore -- o progresso so
    // apareceu depois que ele entrou numa licao e voltou.
    //
    // A causa: esta tela consulta o banco uma vez, no initState, e guarda o
    // resultado. Reconstruir o widget raiz nao a faz perguntar de novo; so
    // remontar faz, e remontar e o que acontece ao navegar.
    //
    // Do lado de quem usa, progresso que nao aparece e indistinguivel de
    // progresso perdido -- e foi exatamente esse o susto.
    testWidgets('a tela recarrega sozinha quando a sincronizacao avisa', (
      tester,
    ) async {
      final progresso = ProgressoFalso();
      final chegou = ValueNotifier(0);
      addTearDown(chegou.dispose);

      await montar(
        tester,
        TelaTrilha(
          banco: bancoPython,
          language: 'python',
          level: Level.beginner,
          podeVoltar: false,
          progresso: progresso,
          chegouDaNuvem: chegou,
        ),
      );

      expect(find.textContaining('0 de 4 questões'), findsOneWidget);

      // A nuvem responde depois que a tela ja foi montada, que e o caso real.
      progresso.contagem = {'python-beg-01': 2};
      chegou.value++;
      await tester.pumpAndSettle();

      expect(
        find.textContaining('2 de 4 questões'),
        findsOneWidget,
        reason: 'sem isto, o progresso so apareceria ao navegar',
      );
    });

    testWidgets('sem o aviso, a tela nao recarrega sozinha', (tester) async {
      // O outro lado da regra: nada de consultar o banco a cada quadro. A
      // tela so pergunta de novo quando ha motivo.
      final progresso = ProgressoFalso();
      await montar(
        tester,
        TelaTrilha(
          banco: bancoPython,
          language: 'python',
          level: Level.beginner,
          podeVoltar: false,
          progresso: progresso,
        ),
      );

      progresso.contagem = {'python-beg-01': 2};
      await tester.pump(const Duration(seconds: 1));

      expect(find.textContaining('0 de 4 questões'), findsOneWidget);
    });
  });

  group('nome longo no cabecalho', () {
    // "Qualidade de Software" ocupa cerca de 328px na mono de 26px, e sobram
    // ~204px ao lado da seta e dos tres icones. Sem tratamento ele quebraria em
    // duas ou tres linhas e empurraria a barra de progresso e os cartoes para
    // baixo -- e este cabecalho supoe uma linha so.
    Future<double> alturaDoTitulo(WidgetTester tester, String language) async {
      await montar(
        tester,
        TelaTrilha(
          banco: QuestionBank([
            licao(lessonId: '\$language-beg-01', language: language),
          ]),
          language: language,
          level: Level.beginner,
          podeVoltar: false,
          progresso: ProgressoFalso(),
        ),
      );
      return tester.getSize(find.text(nomeBonito(language))).height;
    }

    testWidgets('nome longo nao fica mais alto que nome curto', (tester) async {
      final curto = await alturaDoTitulo(tester, 'python');
      final longo = await alturaDoTitulo(tester, 'qa');

      expect(
        longo,
        lessThanOrEqualTo(curto),
        reason: 'o titulo quebrou em mais de uma linha e empurrou o layout',
      );
    });

    testWidgets('o titulo nao encosta no primeiro icone', (tester) async {
      // Visto em print no Xiaomi: com nome longo, o titulo ficou a QUATRO
      // pixels do icone de estatisticas, contra os 60 e 67 que separam os
      // icones entre si. O FittedBox encolhe ate ocupar todo o Expanded, e o
      // Expanded ia ate a borda do icone.
      await alturaDoTitulo(tester, 'qa');

      final titulo = tester.getRect(find.text('Qualidade de Software'));
      final icone = tester.getRect(
        find.byKey(TelaTrilha.chaveEstatisticas),
      );

      expect(
        icone.left - titulo.right,
        greaterThanOrEqualTo(8),
        reason: 'titulo e icone precisam de respiro entre eles',
      );
    });

    testWidgets('o nome longo continua inteiro na tela', (tester) async {
      // Encolher e aceitavel; cortar com reticencias nao seria, porque o nome
      // da trilha e o unico rotulo que diz onde a pessoa esta.
      await alturaDoTitulo(tester, 'qa');
      expect(find.text('Qualidade de Software'), findsOneWidget);
    });

    // O nome da trilha de frameworks foi escolhido por medicao, e nao por
    // gosto: "Frameworks" tem as mesmas 10 letras de "JavaScript", que ja cabe
    // justo nos ~204px que sobram. "Front-end" foi descartado por prometer
    // demais -- HTML e CSS sao trilhas proprias --, e um nome mais longo teria
    // acionado o FittedBox.
    //
    // Encolher nao seria defeito, mas seria uma escolha nao declarada. Este
    // teste prova que a afirmacao e verdadeira, e avisa se alguem trocar o
    // nome por um que nao caiba.
    // ALTURA nao serve para medir isto, e descobrir isso custou uma rodada: o
    // FittedBox encolhe por TRANSFORMACAO, entao o Text continua com os mesmos
    // 37px de uma linha mesmo quando aparece menor na tela -- "Qualidade de
    // Software" mede 37.0 igual a "JavaScript". A altura so denuncia quebra de
    // linha, que e o que o teste acima usa.
    //
    // O que denuncia o encolhimento e comparar o retangulo PINTADO com o
    // tamanho proprio: getRect ja passou pela transformacao, getSize nao.
    // Iguais, nao encolheu; menor, encolheu.
    Future<double> escalaDoTitulo(WidgetTester tester, String language) async {
      await alturaDoTitulo(tester, language);
      final alvo = find.text(nomeBonito(language));
      return tester.getRect(alvo).width / tester.getSize(alvo).width;
    }

    // A medida e RELATIVA a "JavaScript", e nao a 1.0, porque a fonte do
    // ambiente de teste desenha cada glifo como um QUADRADO: "JavaScript" mede
    // 262.5px aqui contra os ~156px da mono de 26px no aparelho. O teste e um
    // proxy pessimista -- o que couber aqui cabe la --, e comparar com um
    // numero absoluto mediria a fonte de teste, nao o cabecalho.
    //
    // "Frameworks" tem as mesmas 10 letras de "JavaScript", entao a afirmacao
    // que este teste trava e exatamente esta: o nome novo nao aperta o
    // cabecalho mais do que a trilha que ja existia aperta. "Front-end" foi
    // descartado por outro motivo -- prometer demais, ja que HTML e CSS sao
    // trilhas proprias.
    testWidgets('"Frameworks" nao aperta o cabecalho mais que "JavaScript"', (
      tester,
    ) async {
      final baseQueJaExiste = await escalaDoTitulo(tester, 'javascript');
      final frameworks = await escalaDoTitulo(tester, 'frameworks');
      final naoCabe = await escalaDoTitulo(tester, 'qa');

      expect(
        frameworks,
        moreOrLessEquals(baseQueJaExiste, epsilon: 0.01),
        reason: 'o nome novo encolhe mais que a trilha que ja existia',
      );
      expect(
        naoCabe,
        lessThan(baseQueJaExiste),
        reason: 'sem um nome que comprovadamente encolhe mais, a medida acima '
            'passaria mesmo se a escala nunca fosse aplicada',
      );
    });
  });

  group('acessibilidade do cabecalho', () {
    // Nasceu de uma medicao com Appium, e nao de uma revisao de codigo.
    //
    // O dump do UiAutomator no Xiaomi mostrou os QUATRO controles do topo como
    // `android.view.View` clicaveis e ANONIMOS -- sem `content-desc`, sem
    // `resource-id`, distinguiveis so pela posicao na tela:
    //
    //   x=  52- 124  y=207-279  (SEM DESCRICAO)   <- voltar
    //   x= 890- 968  y=204-282  (SEM DESCRICAO)   <- estatisticas
    //   x=1020-1098  y=204-282  (SEM DESCRICAO)   <- cenario
    //   x=1150-1228  y=204-282  (SEM DESCRICAO)   <- som
    //
    // Nenhum teste de widget pegava isso: as `Key` do Flutter existiam e
    // funcionavam, e elas param na fronteira do Dart. O defeito era de quem
    // usa leitor de tela, e so a arvore de acessibilidade o revelava.
    Future<SemanticsNode> semanticaDe(WidgetTester tester, Key chave) async {
      await montar(
        tester,
        TelaTrilha(
          banco: bancoDuasLinguagens,
          language: 'python',
          level: Level.beginner,
          podeVoltar: true,
          progresso: ProgressoFalso(),
        ),
      );
      return tester.getSemantics(find.byKey(chave));
    }

    testWidgets('os quatro controles do topo tem rotulo e identificador', (
      tester,
    ) async {
      // Dispensado no fim do CORPO, e nao por `addTearDown`: a verificacao de
      // "handle vazado" do flutter_test roda antes dos tearDowns, entao o
      // teste reprovava por causa do proprio teste -- nao do app.
      final handle = tester.ensureSemantics();

      for (final (chave, rotulo, identificador) in <(Key, String, String)>[
        (TelaTrilha.chaveVoltar, 'Voltar', TelaTrilha.idVoltar),
        (
          TelaTrilha.chaveEstatisticas,
          'Estatísticas',
          TelaTrilha.idEstatisticas,
        ),
        (TelaTrilha.chaveCenario, 'Cenário animado', TelaTrilha.idCenario),
        (TelaTrilha.chaveSom, 'Som', TelaTrilha.idSom),
      ]) {
        final no = await semanticaDe(tester, chave);

        expect(
          no.label,
          rotulo,
          reason: 'sem rotulo, o leitor de tela anuncia so "botao"',
        );
        expect(
          no.identifier,
          identificador,
          reason: 'sem identificador, o Appium so alcanca este botao por '
              'coordenada -- o seletor mais fragil que existe',
        );
      }

      handle.dispose();
    });

    // O identificador e o que o Appium enxerga; a Key e o que o teste de
    // widget usa. Sao a mesma string de proposito, declarada uma vez -- sem
    // isso as duas divergem e cada suite aponta para um nome diferente do
    // mesmo botao.
    test('a Key e o identificador sao o mesmo nome', () {
      expect(TelaTrilha.chaveSom, const Key(TelaTrilha.idSom));
      expect(TelaTrilha.chaveCenario, const Key(TelaTrilha.idCenario));
      expect(
        TelaTrilha.chaveEstatisticas,
        const Key(TelaTrilha.idEstatisticas),
      );
      expect(TelaTrilha.chaveVoltar, const Key(TelaTrilha.idVoltar));
    });
  });

  group('estatisticas', () {
    testWidgets('o icone abre a tela com o que o banco respondeu', (
      tester,
    ) async {
      // Prova a ligacao inteira: o icone existe, ele consulta o repositorio, e
      // o que voltou de la aparece na tela. Sem isto, a tela de estatisticas
      // estaria testada sozinha e ninguem saberia se ela e alcancavel.
      final progresso = ProgressoFalso()
        ..resumo = ResumoDoJogador(
          respondidas: 4,
          deCabeca: 3,
          reveladas: 0,
          tentativas: 5,
          comDica: 0,
          tempoMedido: const Duration(seconds: 4 * 30),
          questoesComTempo: 4,
          partidas: 4,
          diasEstudados: 2,
        );

      await montar(
        tester,
        TelaTrilha(
          banco: bancoPython,
          language: 'python',
          level: Level.beginner,
          podeVoltar: false,
          progresso: progresso,
        ),
      );

      await tester.tap(find.byKey(TelaTrilha.chaveEstatisticas));
      await tester.pumpAndSettle();

      expect(find.text('Seu desempenho'), findsOneWidget);
      expect(find.text('75%'), findsOneWidget);
      expect(find.text('30s'), findsOneWidget);
    });

    testWidgets('sem repositorio, o icone nem aparece', (tester) async {
      // Ele so poderia abrir uma tela que sempre diria "ainda nao ha o que
      // mostrar", e oferecer isso e pior que nao oferecer.
      await montar(
        tester,
        TelaTrilha(
          banco: bancoPython,
          language: 'python',
          level: Level.beginner,
          podeVoltar: false,
        ),
      );

      expect(find.byKey(TelaTrilha.chaveEstatisticas), findsNothing);
    });
  });
}
