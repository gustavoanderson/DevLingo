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

  final Map<String, int> contagem;
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
      expect(trilhas.map((t) => t.language), ['javascript', 'python']);
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

    testWidgets('o nome longo continua inteiro na tela', (tester) async {
      // Encolher e aceitavel; cortar com reticencias nao seria, porque o nome
      // da trilha e o unico rotulo que diz onde a pessoa esta.
      await alturaDoTitulo(tester, 'qa');
      expect(find.text('Qualidade de Software'), findsOneWidget);
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
