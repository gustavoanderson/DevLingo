import 'dart:convert';

import 'package:devlingo/answer/sessao_questao.dart';
import 'package:devlingo/data/progresso.dart';
import 'package:devlingo/models/lesson.dart';
import 'package:devlingo/models/question.dart';
import 'package:devlingo/ui/fluxo_da_licao.dart';
import 'package:devlingo/ui/tela_aula.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const String _questao = '''
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
}''';

const String _aula = '''
"aula": {
  "titulo": "O basico do Python",
  "secoes": [
    {
      "topico": "saida",
      "titulo": "Mostrar coisas na tela",
      "texto": "Primeiro paragrafo da secao, com tamanho suficiente.\\n\\nSegundo paragrafo da secao, tambem com tamanho suficiente.",
      "code": { "language": "python", "content": "print(\\"Oi\\")" }
    }
  ]
},''';

const String _questaoEscrita = '''
{
  "id": "python-beg-0199",
  "topic": "saida",
  "prompt": "Escreva a linha que exibe o valor da variavel nome.",
  "answerType": "freeWrite",
  "accepted": ["print(nome)"],
  "normalize": {"spaces": true, "quotes": true, "trailingSemicolon": true, "caseSensitive": true},
  "hint": "Chame a funcao de exibicao passando a variavel, sem aspas ao redor.",
  "explanation": "Sem aspas o Python busca o valor guardado na variavel."
}''';

Lesson licao({bool comAula = true, int quantas = 1, bool escrita = false}) =>
    Lesson.fromJson(
  json.decode('''
  {
    "schemaVersion": 1,
    "language": "python",
    "level": "beginner",
    "lessonId": "python-beg-01",
    "lessonTitle": "Licao de teste",
    ${comAula ? _aula : ''}
    "questions": [${escrita ? _questaoEscrita : List.generate(quantas, _questaoNumero).join(',')}]
  }''')
      as Map<String, dynamic>,
);

/// A mesma questao repetida, com id e enunciado proprios.
///
/// O enunciado precisa diferir para o teste conseguir dizer **em qual** delas
/// a tela esta; com o texto igual, voltar para a questao errada passaria
/// despercebido, que e exatamente o defeito sob teste.
String _questaoNumero(int i) => _questao
    .replaceFirst('python-beg-0101', 'python-beg-010${i + 1}')
    .replaceFirst(
      'Qual funcao exibe algo na tela?',
      'Questao numero ${i + 1}',
    );

/// Registro em memoria, para o teste de tela nao precisar de banco.
class ProgressoFalso implements RegistroDeProgresso {
  final Set<String> aulasVistas = {};

  /// Uma entrada por gravacao, na ordem em que aconteceram.
  ///
  /// E uma LISTA, e nao um conjunto: o que se quer provar e que a mesma questao
  /// nao e gravada duas vezes, e um conjunto engoliria a repeticao sob teste.
  ///
  /// Guarda as tentativas junto porque o resultado sozinho nao denuncia o
  /// defeito: uma sessao zerada pelo caminho grava "acertou", igual a uma
  /// inteira -- o que ela perde e **quanto custou**.
  final List<({String questao, int tentativas})> gravadas = [];

  @override
  Future<void> registrar({
    required Lesson licao,
    required Question questao,
    required SessaoQuestao sessao,
    DateTime? quando,
  }) async {
    gravadas.add((questao: questao.id, tentativas: sessao.tentativas));
  }

  @override
  Future<void> salvarPosicao(String l, int i, {DateTime? quando}) async {}

  @override
  Future<int?> posicaoDe(String lessonId) async => null;

  @override
  Future<bool> aulaFoiVista(String lessonId) async =>
      aulasVistas.contains(lessonId);

  @override
  Future<void> marcarAulaVista(String lessonId, {DateTime? quando}) async {
    aulasVistas.add(lessonId);
  }

  @override
  Future<Map<String, int>> respondidasPorLicao() async => const {};

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

  bool cenario = true;

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
  group('modelo da aula', () {
    test('as secoes e o codigo sao lidos', () {
      final aula = licao().aula!;
      expect(aula.titulo, 'O basico do Python');
      expect(aula.secoes, hasLength(1));
      expect(aula.secoes.first.topico, 'saida');
      expect(aula.secoes.first.code, isNotNull);
    });

    test('o texto vira paragrafos separados', () {
      final secao = licao().aula!.secoes.first;
      expect(secao.paragrafos, hasLength(2));
      expect(secao.paragrafos.first, startsWith('Primeiro'));
      expect(secao.paragrafos.last, startsWith('Segundo'));
    });

    test('licao sem aula fica com aula nula', () {
      expect(licao(comAula: false).aula, isNull);
    });
  });

  group('tela da aula', () {
    testWidgets('mostra titulo, secao, paragrafos e codigo', (tester) async {
      await montar(
        tester,
        TelaAula(licao: licao(), aoComecar: () {}),
      );

      expect(find.text('O basico do Python'), findsOneWidget);
      expect(find.text('Mostrar coisas na tela'), findsOneWidget);
      expect(find.textContaining('Primeiro paragrafo'), findsOneWidget);
      expect(find.textContaining('Segundo paragrafo'), findsOneWidget);
      expect(find.text('main.py'), findsOneWidget, reason: 'o exemplo em codigo');
      expect(find.byKey(TelaAula.chaveComecar), findsOneWidget);
    });
  });

  group('fluxo da licao', () {
    testWidgets('a aula aparece sozinha na primeira vez', (tester) async {
      await montar(tester, FluxoDaLicao(licao: licao()));

      expect(find.byKey(TelaAula.chaveComecar), findsOneWidget);
      expect(find.text('Começar as questões'), findsOneWidget);
      expect(find.text('Questao numero 1'), findsNothing);
    });

    testWidgets('quem ja viu a aula cai direto nas questoes', (tester) async {
      await montar(tester, FluxoDaLicao(licao: licao(), aulaJaVista: true));

      expect(find.byKey(TelaAula.chaveComecar), findsNothing);
      expect(find.text('Questao numero 1'), findsOneWidget);
    });

    testWidgets('licao sem aula nao mostra aula nem o icone de reler', (
      tester,
    ) async {
      await montar(tester, FluxoDaLicao(licao: licao(comAula: false)));

      expect(find.byKey(TelaAula.chaveComecar), findsNothing);
      expect(find.byKey(const Key('acao-reler-aula')), findsNothing);
      expect(find.text('Questao numero 1'), findsOneWidget);
    });

    testWidgets('comecar leva as questoes e marca a aula como vista', (
      tester,
    ) async {
      final progresso = ProgressoFalso();
      await montar(tester, FluxoDaLicao(licao: licao(), progresso: progresso));

      await tester.tap(find.byKey(TelaAula.chaveComecar));
      await tester.pumpAndSettle();

      expect(find.text('Questao numero 1'), findsOneWidget);
      expect(
        progresso.aulasVistas,
        contains('python-beg-01'),
        reason: 'a proxima abertura nao deve impor a aula de novo',
      );
    });

    testWidgets('o icone no topo reabre a aula para consulta', (tester) async {
      await montar(tester, FluxoDaLicao(licao: licao(), aulaJaVista: true));

      await tester.tap(find.byKey(const Key('acao-reler-aula')));
      await tester.pumpAndSettle();

      expect(find.text('O basico do Python'), findsOneWidget);
      expect(
        find.text('Voltar às questões'),
        findsOneWidget,
        reason: 'relendo, o botao devolve para onde o aluno estava',
      );
    });

    testWidgets('voltar da releitura nao remarca a aula como vista', (
      tester,
    ) async {
      // Releitura nao e primeira vez: marcar de novo mentiria sobre quando o
      // aluno viu a aula pela primeira vez.
      final progresso = ProgressoFalso();
      await montar(
        tester,
        FluxoDaLicao(
          licao: licao(),
          progresso: progresso,
          aulaJaVista: true,
        ),
      );

      await tester.tap(find.byKey(const Key('acao-reler-aula')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(TelaAula.chaveComecar));
      await tester.pumpAndSettle();

      expect(find.text('Questao numero 1'), findsOneWidget);
      expect(progresso.aulasVistas, isEmpty);
    });

    testWidgets('consultar a aula nao apaga o que ja foi digitado', (
      tester,
    ) async {
      // Relatado pelo Gustavo jogando: ele estava escrevendo uma resposta,
      // foi consultar o material, e voltou para um campo vazio. Mesma causa da
      // posicao perdida -- a tela e desmontada, e o TextEditingController morre
      // junto. Quem guarda o texto e o FluxoDaLicao, que sobrevive a troca.
      await montar(
        tester,
        FluxoDaLicao(licao: licao(escrita: true), aulaJaVista: true),
      );

      // Sem esta checagem o teste passaria mesmo sem campo nenhum na tela --
      // e um teste que sai cedo e passa nao prova coisa alguma.
      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'print(no');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('acao-reler-aula')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(TelaAula.chaveComecar));
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'print(no',
        reason: 'o que estava escrito tem que voltar com o aluno',
      );
    });

    testWidgets('consultar a aula no meio da licao nao devolve para tras', (
      tester,
    ) async {
      // Defeito relatado pelo Gustavo jogando: ele estava na questao 7, foi
      // consultar o material didatico, e ao voltar caiu na 5 -- tendo que
      // refazer o que ja tinha feito.
      //
      // A causa: abrir a aula desmonta a tela de exercicio, e ela renascia em
      // `indiceInicial`, o indice de quando a licao ABRIU. Gravar no banco nao
      // resolvia, porque quem remonta a tela e o FluxoDaLicao, que nao rele o
      // banco. A posicao precisa morar em quem sobrevive a troca de tela.
      await montar(
        tester,
        FluxoDaLicao(licao: licao(quantas: 3), aulaJaVista: true),
      );

      // Responde a primeira e avanca para a segunda.
      await tester.tap(find.text('print()'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('acao-verificar')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('acao-continuar')));
      await tester.pumpAndSettle();

      expect(find.text('Questao numero 2'), findsOneWidget);

      // Vai consultar a aula e volta.
      await tester.tap(find.byKey(const Key('acao-reler-aula')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(TelaAula.chaveComecar));
      await tester.pumpAndSettle();

      expect(
        find.text('Questao numero 2'),
        findsOneWidget,
        reason: 'voltar da aula tem que devolver para onde o aluno estava',
      );
      expect(
        find.text('Questao numero 1'),
        findsNothing,
        reason: 'mandar refazer o que ja foi feito e o defeito em si',
      );
    });

    testWidgets('consultar a aula nao apaga a resposta ja dada', (
      tester,
    ) async {
      // Terceiro defeito desta familia, relatado pelo Gustavo jogando:
      // acertar a questao, ir consultar a aula SEM AVANCAR, e voltar para a
      // questao zerada -- tendo que escolher a alternativa de novo.
      //
      // Mesma causa dos dois irmaos acima: a tela e desmontada, e a
      // `SessaoQuestao` renascia limpa. Quem sobrevive a troca e o
      // FluxoDaLicao, e e la que a sessao mora agora.
      await montar(
        tester,
        FluxoDaLicao(licao: licao(quantas: 2), aulaJaVista: true),
      );

      await tester.tap(find.text('print()'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('acao-verificar')));
      await tester.pumpAndSettle();

      // Controle: sem esta assercao o teste passaria mesmo se a questao nunca
      // tivesse terminado, e nao provaria nada.
      expect(
        find.byKey(const Key('acao-continuar')),
        findsOneWidget,
        reason: 'a questao precisa ter terminado antes de o teste comecar',
      );

      await tester.tap(find.byKey(const Key('acao-reler-aula')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(TelaAula.chaveComecar));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('acao-continuar')),
        findsOneWidget,
        reason: 'o acerto tem que voltar com o aluno',
      );
      expect(
        find.byKey(const Key('acao-verificar')),
        findsNothing,
        reason: 'pedir para responder de novo o que ja foi acertado e o defeito',
      );
    });

    testWidgets('consultar a aula no meio da questao preserva as tentativas', (
      tester,
    ) async {
      // A parte do defeito que NAO aparece na tela, e e a que corrompe dado.
      //
      // Consultar a aula no meio de uma questao zerava a sessao. Quem tinha
      // errado uma vez voltava com o contador em zero, e a gravacao final
      // dizia que a questao saiu de primeira. O custo real da questao -- que e
      // o que alimenta `custoPorTopico` e a revisao dirigida -- era perdido.
      //
      // Errar nao grava: a gravacao acontece so quando a questao TERMINA.
      // Entao o que este teste mede e uma gravacao unica, com o numero certo
      // dentro dela.
      final progresso = ProgressoFalso();
      await montar(
        tester,
        FluxoDaLicao(
          licao: licao(quantas: 2),
          progresso: progresso,
          aulaJaVista: true,
        ),
      );

      // Erra uma vez. Isso elimina a alternativa e devolve a vez.
      await tester.tap(find.text('write()'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('acao-verificar')));
      await tester.pumpAndSettle();

      // Controle: errar nao pode gravar, senao o resto do teste mede outra
      // coisa que nao o que ele diz medir.
      expect(
        progresso.gravadas,
        isEmpty,
        reason: 'errar nao termina a questao, entao nao grava',
      );

      await tester.tap(find.byKey(const Key('acao-reler-aula')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(TelaAula.chaveComecar));
      await tester.pumpAndSettle();

      // Acerta, agora na segunda tentativa.
      await tester.tap(find.text('print()'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('acao-verificar')));
      await tester.pumpAndSettle();

      expect(
        progresso.gravadas,
        [(questao: 'python-beg-0101', tentativas: 2)],
        reason:
            'uma gravacao so, e com as DUAS tentativas -- a sessao zerada '
            'gravaria 1, dizendo que a questao saiu de primeira',
      );
    });
  });
}
