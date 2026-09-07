import 'dart:convert';

import 'package:devlingo/answer/sessao_questao.dart';
import 'package:devlingo/models/lesson.dart';
import 'package:devlingo/models/question.dart';
import 'package:devlingo/ui/tela_exercicio.dart';
import 'package:flutter/material.dart';
import 'package:devlingo/data/progresso.dart';
import 'package:flutter_test/flutter_test.dart';

/// Testes da fiacao entre a tela e a maquina de estados.
///
/// A regra em si esta coberta em `sessao_questao_test.dart`. Aqui o que se
/// verifica e que o toque chega la, e que o resultado volta para a tela.

Lesson licaoCom(List<String> questoes) => Lesson.fromJson(
  json.decode('''
  {
    "schemaVersion": 1,
    "language": "python",
    "level": "beginner",
    "lessonId": "python-beg-01",
    "lessonTitle": "Licao de teste",
    "questions": [${questoes.join(',')}]
  }''')
      as Map<String, dynamic>,
);

const String _mc = '''
{
  "id": "python-beg-0101",
  "topic": "saida",
  "prompt": "Qual funcao exibe algo na tela?",
  "answerType": "multipleChoice",
  "options": [
    {"id": "a", "text": "write()",      "correct": false, "why": "Esse nome nao existe embutido."},
    {"id": "b", "text": "print()",      "correct": true},
    {"id": "c", "text": "echo()",       "correct": false, "why": "Essa forma vem do PHP."},
    {"id": "d", "text": "display()",    "correct": false, "why": "Esse nome nao pertence a linguagem."},
    {"id": "e", "text": "console.log()","correct": false, "why": "Essa forma vem do JavaScript."}
  ],
  "hint": "Pense no que voce digitaria num arquivo com extensao py.",
  "explanation": "A funcao embutida do Python para exibir na saida padrao e print()."
}''';

const String _segunda = '''
{
  "id": "python-beg-0102",
  "topic": "tipos",
  "prompt": "Segunda questao da licao.",
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
}''';

const String _escrita = '''
{
  "id": "python-beg-0110",
  "topic": "variaveis",
  "prompt": "Escreva a linha que exibe o valor da variavel nome.",
  "answerType": "freeWrite",
  "accepted": ["print(nome)"],
  "normalize": {"spaces": true, "quotes": true, "trailingSemicolon": true, "caseSensitive": true},
  "hint": "Chame a funcao de exibicao passando a variavel, sem aspas ao redor.",
  "explanation": "Sem aspas o Python busca o valor guardado na variavel."
}''';

Future<void> montar(WidgetTester tester, Lesson licao) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: TelaExercicio(licao: licao)));
  await tester.pumpAndSettle();
}

/// Toca numa alternativa errada qualquer que ainda esteja na lista.
Future<void> errar(WidgetTester tester) async {
  const erradas = ['write()', 'echo()', 'display()', 'console.log()'];
  for (final texto in erradas) {
    final alvo = find.text(texto);
    if (alvo.evaluate().isEmpty) continue;
    final widget = tester.widget<Text>(alvo);
    if (widget.style?.decoration == TextDecoration.lineThrough) continue;
    await tester.tap(alvo);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('acao-verificar')));
    await tester.pumpAndSettle();
    return;
  }
  fail('nenhuma alternativa errada disponivel para tocar');
}

void main() {
  progressoNaTela();

  group('multipla escolha', () {
    testWidgets('Verificar comeca desabilitado e habilita ao selecionar', (
      tester,
    ) async {
      await montar(tester, licaoCom([_mc]));

      Opacity opacidadeDoBotao() => tester.widget<Opacity>(
        find.descendant(
          of: find.byKey(const Key('acao-verificar')),
          matching: find.byType(Opacity),
        ),
      );

      expect(opacidadeDoBotao().opacity, lessThan(1));

      await tester.tap(find.text('print()'));
      await tester.pumpAndSettle();

      expect(opacidadeDoBotao().opacity, 1);
    });

    testWidgets('errar risca a alternativa e mostra o why dela', (
      tester,
    ) async {
      await montar(tester, licaoCom([_mc]));

      await tester.tap(find.text('echo()'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('acao-verificar')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('retorno-erro')), findsOneWidget);
      expect(find.text('Essa forma vem do PHP.'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('echo()')).style?.decoration,
        TextDecoration.lineThrough,
      );
      // A explicacao completa entregaria a resposta na primeira tentativa.
      expect(
        find.text(
          'A funcao embutida do Python para exibir na saida padrao e print().',
        ),
        findsNothing,
      );
    });

    testWidgets('acertar mostra a explicacao e troca o botao por Continuar', (
      tester,
    ) async {
      await montar(tester, licaoCom([_mc]));

      await tester.tap(find.text('print()'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('acao-verificar')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('retorno-acerto')), findsOneWidget);
      expect(find.text('CERTO'), findsOneWidget);
      expect(
        find.text(
          'A funcao embutida do Python para exibir na saida padrao e print().',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('acao-continuar')), findsOneWidget);
      expect(find.byKey(const Key('acao-verificar')), findsNothing);
      // Dica some depois de responder: nao ha mais o que dicar.
      expect(find.byKey(const Key('acao-dica')), findsNothing);
    });

    testWidgets('quatro erros revelam sem pedir o toque cerimonial', (
      tester,
    ) async {
      await montar(tester, licaoCom([_mc]));

      for (var i = 0; i < 4; i++) {
        await errar(tester);
      }

      expect(find.byKey(const Key('retorno-revelado')), findsOneWidget);
      expect(find.text('VAMOS JUNTOS'), findsOneWidget);
      expect(find.byKey(const Key('acao-continuar')), findsOneWidget);
    });

    testWidgets('Continuar avanca para a proxima questao', (tester) async {
      await montar(tester, licaoCom([_mc, _segunda]));

      expect(find.text('1/2'), findsOneWidget);

      await tester.tap(find.text('print()'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('acao-verificar')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('acao-continuar')));
      await tester.pumpAndSettle();

      expect(find.text('2/2'), findsOneWidget);
      expect(find.text('Segunda questao da licao.'), findsOneWidget);
      // O estado da questao anterior nao pode vazar para a seguinte.
      expect(find.byKey(const Key('retorno-acerto')), findsNothing);
      expect(find.byKey(const Key('acao-verificar')), findsOneWidget);
    });

    testWidgets('Continuar na ultima questao encerra a licao', (tester) async {
      await montar(tester, licaoCom([_mc]));

      await tester.tap(find.text('print()'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('acao-verificar')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('acao-continuar')));
      await tester.pumpAndSettle();

      expect(find.byKey(TelaExercicio.chaveFimDaLicao), findsOneWidget);
      expect(find.text('LIÇÃO CONCLUÍDA'), findsOneWidget);
    });
  });

  group('dica', () {
    testWidgets('o botao abre o painel com o texto da questao', (tester) async {
      await montar(tester, licaoCom([_mc]));

      expect(
        find.text(
          'Pense no que voce digitaria num arquivo com extensao py.',
        ),
        findsNothing,
      );

      await tester.tap(find.byKey(const Key('acao-dica')));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Pense no que voce digitaria num arquivo com extensao py.',
        ),
        findsOneWidget,
      );
    });
  });

  group('resposta escrita', () {
    testWidgets('sem teclado virtual, a regua nao ocupa espaco', (tester) async {
      // No emulador se digita com teclado fisico, entao o teclado virtual nao
      // sobe e a regua so atrapalharia.
      await montar(tester, licaoCom([_escrita]));

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('('), findsNothing);
    });

    testWidgets('com teclado virtual aberto, a regua aparece e insere', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1.0;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(home: TelaExercicio(licao: licaoCom([_escrita]))),
      );
      await tester.pumpAndSettle();

      for (final simbolo in ['(', ')', '[', ']', ':', '*', '=']) {
        expect(find.text(simbolo), findsOneWidget);
      }

      await tester.tap(find.text('('));
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '(',
      );
    });

    testWidgets('acertar escrevendo termina a questao', (tester) async {
      await montar(tester, licaoCom([_escrita]));

      await tester.enterText(find.byType(TextField), 'print(nome)');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('acao-verificar')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('retorno-acerto')), findsOneWidget);
      expect(find.byKey(const Key('acao-continuar')), findsOneWidget);
    });

    testWidgets('o segundo erro abre a dica sozinho', (tester) async {
      await montar(tester, licaoCom([_escrita]));
      final campo = find.byType(TextField);

      await tester.enterText(campo, 'errado');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('acao-verificar')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Chame a funcao de exibicao passando a variavel, sem aspas ao redor.',
        ),
        findsNothing,
      );

      await tester.enterText(campo, 'errado de novo');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('acao-verificar')));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Chame a funcao de exibicao passando a variavel, sem aspas ao redor.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('o terceiro erro mostra a forma da resposta', (tester) async {
      await montar(tester, licaoCom([_escrita]));
      final campo = find.byType(TextField);

      for (final tentativa in ['a', 'b', 'c']) {
        await tester.enterText(campo, tentativa);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('acao-verificar')));
        await tester.pumpAndSettle();
      }

      expect(find.text('·····(····)'), findsOneWidget);
      expect(find.text('A RESPOSTA ERA'), findsNothing);
      expect(find.byKey(const Key('acao-verificar')), findsOneWidget);
    });

    testWidgets('o quarto erro revela a resposta', (tester) async {
      await montar(tester, licaoCom([_escrita]));
      final campo = find.byType(TextField);

      for (final tentativa in ['a', 'b', 'c', 'd']) {
        await tester.enterText(campo, tentativa);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('acao-verificar')));
        await tester.pumpAndSettle();
      }

      expect(find.text('A RESPOSTA ERA'), findsOneWidget);
      expect(find.text('print(nome)'), findsOneWidget);
      expect(find.byKey(const Key('acao-continuar')), findsOneWidget);
      // A regua some quando nao ha mais o que escrever.
      expect(find.byType(TextField), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).enabled,
        isFalse,
      );
    });
  });
}


/// Grava progresso em memoria, de forma sincrona.
///
/// O teste de tela usa isto em vez do SQLite porque `testWidgets` roda numa
/// zona de tempo falso, onde I/O real nunca avanca e qualquer espera no banco
/// trava o arquivo inteiro. O que se prova aqui e que a tela **chama** o
/// registro com os dados certos; que o SQLite funciona esta em
/// `progresso_test.dart`.
class ProgressoFalso implements RegistroDeProgresso {
  final Map<String, ({int tentativas, Desfecho desfecho, String topic})> gravadas = {};
  final Map<String, int> posicoes = {};

  @override
  Future<void> registrar({
    required Lesson licao,
    required Question questao,
    required SessaoQuestao sessao,
    DateTime? quando,
  }) async {
    if (!sessao.terminou) return;
    gravadas[questao.id] = (
      tentativas: sessao.tentativas,
      desfecho: sessao.fase == FaseResposta.acertou
          ? Desfecho.acertou
          : Desfecho.revelada,
      topic: questao.topic,
    );
  }

  @override
  Future<void> salvarPosicao(String lessonId, int indice, {DateTime? quando}) async {
    posicoes[lessonId] = indice;
  }

  @override
  Future<int?> posicaoDe(String lessonId) async => posicoes[lessonId];

  final Set<String> aulasVistas = {};

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

void progressoNaTela() {
  group('a tela grava o progresso', () {
    late ProgressoFalso progresso;

    setUp(() => progresso = ProgressoFalso());

    Future<void> montarCom(WidgetTester tester, Lesson licao, {int inicial = 0}) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: TelaExercicio(
            licao: licao,
            progresso: progresso,
            indiceInicial: inicial,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> acertar(WidgetTester tester, String texto) async {
      await tester.tap(find.text(texto));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('acao-verificar')));
      await tester.pumpAndSettle();
    }

    testWidgets('responder grava a questao antes mesmo do Continuar', (tester) async {
      await montarCom(tester, licaoCom([_mc]));
      await acertar(tester, 'print()');

      final gravada = progresso.gravadas['python-beg-0101'];
      expect(
        gravada,
        isNotNull,
        reason:
            'a gravacao acontece ao terminar a questao, nao ao avancar: se o '
            'app fechar entre uma coisa e outra, o que ja foi respondido nao '
            'pode se perder',
      );
      expect(gravada!.tentativas, 1);
      expect(gravada.desfecho, Desfecho.acertou);
      expect(gravada.topic, 'saida');
    });

    testWidgets('errar antes de acertar fica registrado nas tentativas', (tester) async {
      await montarCom(tester, licaoCom([_mc]));
      await errar(tester);
      await acertar(tester, 'print()');

      expect(progresso.gravadas['python-beg-0101']!.tentativas, 2);
    });

    testWidgets('quatro erros gravam o desfecho de resposta revelada', (tester) async {
      await montarCom(tester, licaoCom([_mc]));
      for (var i = 0; i < 4; i++) {
        await errar(tester);
      }

      final gravada = progresso.gravadas['python-beg-0101']!;
      expect(gravada.desfecho, Desfecho.revelada);
      expect(gravada.tentativas, 4);
    });

    testWidgets('Continuar salva a posicao da proxima questao', (tester) async {
      await montarCom(tester, licaoCom([_mc, _segunda]));
      expect(progresso.posicoes['python-beg-01'], isNull);

      await acertar(tester, 'print()');
      await tester.tap(find.byKey(const Key('acao-continuar')));
      await tester.pumpAndSettle();

      expect(progresso.posicoes['python-beg-01'], 1);
    });

    testWidgets('indiceInicial abre na questao certa', (tester) async {
      await montarCom(tester, licaoCom([_mc, _segunda]), inicial: 1);

      expect(find.text('2/2'), findsOneWidget);
      expect(find.text('Segunda questao da licao.'), findsOneWidget);
    });

    testWidgets('terminar a licao volta a posicao para o inicio', (tester) async {
      await montarCom(tester, licaoCom([_mc]));
      await acertar(tester, 'print()');
      await tester.tap(find.byKey(const Key('acao-continuar')));
      await tester.pumpAndSettle();

      expect(find.byKey(TelaExercicio.chaveFimDaLicao), findsOneWidget);
      expect(progresso.posicoes['python-beg-01'], 0);
    });
  });

  group('mutar sem sair da licao', () {
    Future<void> montarComProgresso(
      WidgetTester tester,
      ProgressoFalso progresso,
    ) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: TelaExercicio(licao: licaoCom([_mc]), progresso: progresso),
        ),
      );
      await tester.pumpAndSettle();
    }

    // Antes a unica chave de som ficava na trilha, e silenciar o app no meio
    // de uma licao exigia sair dela. O Gustavo pediu depois de tropecar nisso
    // jogando -- e sair e voltar era justamente o caminho que caia no defeito
    // da posicao perdida. Um problema levava ao outro.
    testWidgets('o botao de som aparece e alterna a preferencia', (
      tester,
    ) async {
      final progresso = ProgressoFalso()..som = true;
      await montarComProgresso(tester, progresso);

      expect(find.byKey(const Key('acao-som')), findsOneWidget);
      expect(find.byIcon(Icons.volume_up_outlined), findsOneWidget);

      await tester.tap(find.byKey(const Key('acao-som')));
      await tester.pumpAndSettle();

      expect(progresso.som, isFalse, reason: 'a preferencia tem que ir ao banco');
      expect(
        find.byIcon(Icons.volume_off_outlined),
        findsOneWidget,
        reason: 'o icone tem que refletir o novo estado na hora',
      );
    });

    testWidgets('sem repositorio, o botao de som nem aparece', (tester) async {
      // Ele so poderia mudar de desenho sem mudar nada, ja que nao ha onde
      // gravar a preferencia.
      await montar(tester, licaoCom([_mc]));
      expect(find.byKey(const Key('acao-som')), findsNothing);
    });

    testWidgets('a tela nasce com a preferencia que esta no banco', (
      tester,
    ) async {
      final progresso = ProgressoFalso()..som = false;
      await montarComProgresso(tester, progresso);

      expect(find.byIcon(Icons.volume_off_outlined), findsOneWidget);
    });
  });
}
