import 'package:devlingo/auth/autenticacao.dart';
import 'package:devlingo/auth/autenticacao_falsa.dart';
import 'package:devlingo/ui/tela_entrada.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<AutenticacaoFalsa> montar(
  WidgetTester tester, {
  Map<String, String>? contas,
  void Function(Usuario)? aoEntrar,
}) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final auth = AutenticacaoFalsa(contas: contas);
  addTearDown(auth.dispose);

  await tester.pumpWidget(
    MaterialApp(home: TelaEntrada(autenticacao: auth, aoEntrar: aoEntrar)),
  );
  await tester.pumpAndSettle();
  return auth;
}

Future<void> preencher(
  WidgetTester tester, {
  String? email,
  String? senha,
}) async {
  if (email != null) {
    await tester.enterText(find.byKey(TelaEntrada.chaveEmail), email);
  }
  if (senha != null) {
    await tester.enterText(find.byKey(TelaEntrada.chaveSenha), senha);
  }
  await tester.pump();
}

Future<void> enviar(WidgetTester tester) async {
  await tester.tap(find.byKey(TelaEntrada.chaveAcao));
  await tester.pumpAndSettle();
}

String erroNaTela(WidgetTester tester) {
  final painel = find.descendant(
    of: find.byKey(TelaEntrada.chaveErro),
    matching: find.byType(Text),
  );
  return tester.widget<Text>(painel).data!;
}

void main() {
  group('validacao sem rede', () {
    // O que da para checar no aparelho e checado no aparelho: responde na hora,
    // sem gastar ida ao servidor, e sem deixar a pessoa esperando para
    // descobrir um erro de digitacao.

    test('e-mail sem arroba nao passa', () {
      expect(validarEmail('gustavo'), FalhaDeAutenticacao.emailInvalido);
      expect(validarEmail('gustavo@'), FalhaDeAutenticacao.emailInvalido);
      expect(validarEmail('gustavo@exemplo'), FalhaDeAutenticacao.emailInvalido);
      expect(validarEmail('a b@exemplo.com'), FalhaDeAutenticacao.emailInvalido);
    });

    test('e-mail comum passa, e a regra nao e exigente demais', () {
      // Falso negativo aqui e GRAVE: barrar um e-mail valido tranca a pessoa
      // fora de um app onde o login e obrigatorio.
      for (final bom in [
        'gustavo@exemplo.com',
        'gustavo.anderson@exemplo.com.br',
        'gustavo+devlingo@exemplo.com',
        'g@e.co',
        'nome_com_underline@sub.dominio.org',
      ]) {
        expect(validarEmail(bom), isNull, reason: '$bom deveria passar');
      }
    });

    test('senha curta e barrada antes de ir a rede', () {
      expect(
        validarCredenciais('a@b.com', '12345'),
        FalhaDeAutenticacao.senhaCurta,
      );
      expect(validarCredenciais('a@b.com', '123456'), isNull);
    });

    test('campo vazio tem mensagem propria, e nao "e-mail invalido"', () {
      expect(validarCredenciais('', ''), FalhaDeAutenticacao.campoVazio);
      expect(validarCredenciais('a@b.com', ''), FalhaDeAutenticacao.campoVazio);
    });

    test('toda falha tem mensagem, e nenhuma e so "erro"', () {
      // Com login obrigatorio, mensagem ruim nao e irritacao: e a pessoa
      // trancada do lado de fora do app inteiro.
      for (final falha in FalhaDeAutenticacao.values) {
        final m = ErroDeAutenticacao(falha).mensagem;
        expect(m.length, greaterThan(20), reason: '${falha.name} muito curta');
        expect(
          m.toLowerCase(),
          isNot(equals('erro')),
          reason: '${falha.name} nao explica nada',
        );
      }
    });
  });

  group('entrar', () {
    testWidgets('com credenciais certas, entra e avisa quem entrou', (
      tester,
    ) async {
      Usuario? entrou;
      await montar(
        tester,
        contas: {'gustavo@exemplo.com': 'segredo123'},
        aoEntrar: (u) => entrou = u,
      );

      await preencher(
        tester,
        email: 'gustavo@exemplo.com',
        senha: 'segredo123',
      );
      await enviar(tester);

      expect(entrou, isNotNull);
      expect(entrou!.email, 'gustavo@exemplo.com');
    });

    testWidgets('senha errada explica e oferece a saida', (tester) async {
      await montar(tester, contas: {'gustavo@exemplo.com': 'segredo123'});

      await preencher(tester, email: 'gustavo@exemplo.com', senha: 'errada123');
      await enviar(tester);

      expect(find.byKey(TelaEntrada.chaveErro), findsOneWidget);
      expect(erroNaTela(tester), contains('Esqueci minha senha'));
    });

    testWidgets('conta inexistente nao e confundida com senha errada', (
      tester,
    ) async {
      await montar(tester, contas: {'outro@exemplo.com': 'segredo123'});

      await preencher(tester, email: 'ninguem@exemplo.com', senha: 'segredo123');
      await enviar(tester);

      expect(erroNaTela(tester), contains('crie uma conta'));
    });

    testWidgets('sem rede, a mensagem diz que so o login precisa dela', (
      tester,
    ) async {
      // Se a pessoa achar que o app inteiro exige internet, ela desinstala.
      final auth = await montar(tester, contas: {'g@e.com': 'segredo123'});
      auth.falhaProgramada = FalhaDeAutenticacao.semRede;

      await preencher(tester, email: 'g@e.com', senha: 'segredo123');
      await enviar(tester);

      expect(erroNaTela(tester), contains('offline'));
    });

    testWidgets('e-mail malformado nem chega a chamar a autenticacao', (
      tester,
    ) async {
      final auth = await montar(tester);
      // Se a validacao local falhasse, esta falha programada seria consumida e
      // a mensagem na tela seria outra.
      auth.falhaProgramada = FalhaDeAutenticacao.desconhecida;

      await preencher(tester, email: 'gustavo', senha: 'segredo123');
      await enviar(tester);

      expect(erroNaTela(tester), contains('@'));
      expect(
        auth.falhaProgramada,
        FalhaDeAutenticacao.desconhecida,
        reason: 'a falha nao foi consumida: a rede nao chegou a ser tocada',
      );
    });
  });

  group('criar conta', () {
    testWidgets('troca de modo e cria a conta', (tester) async {
      Usuario? entrou;
      final auth = await montar(tester, aoEntrar: (u) => entrou = u);

      await tester.tap(find.byKey(TelaEntrada.chaveTrocarModo));
      await tester.pumpAndSettle();
      expect(find.text('Criar conta'), findsWidgets);

      await preencher(tester, email: 'novo@exemplo.com', senha: 'segredo123');
      await enviar(tester);

      expect(entrou, isNotNull);
      expect(auth.usuarioAtual!.email, 'novo@exemplo.com');
    });

    testWidgets('e-mail ja cadastrado manda entrar em vez de repetir', (
      tester,
    ) async {
      await montar(tester, contas: {'gustavo@exemplo.com': 'segredo123'});

      await tester.tap(find.byKey(TelaEntrada.chaveTrocarModo));
      await tester.pumpAndSettle();
      await preencher(
        tester,
        email: 'gustavo@exemplo.com',
        senha: 'outrasenha1',
      );
      await enviar(tester);

      expect(erroNaTela(tester), contains('Já existe uma conta'));
    });

    testWidgets('o minimo da senha aparece ANTES de a pessoa errar', (
      tester,
    ) async {
      // Regra escondida ate a falha e regra mal comunicada.
      await montar(tester);
      await tester.tap(find.byKey(TelaEntrada.chaveTrocarModo));
      await tester.pumpAndSettle();

      expect(find.textContaining('$minimoDaSenha caracteres'), findsOneWidget);
    });
  });

  group('esqueci minha senha', () {
    testWidgets('pede o e-mail e dispara a recuperacao', (tester) async {
      final auth = await montar(tester, contas: {'g@e.com': 'segredo123'});

      await tester.tap(find.byKey(TelaEntrada.chaveEsqueci));
      await tester.pumpAndSettle();
      expect(find.byKey(TelaEntrada.chaveSenha), findsNothing);

      await preencher(tester, email: 'g@e.com');
      await enviar(tester);

      expect(auth.recuperacoesPedidas, ['g@e.com']);
      expect(find.byKey(TelaEntrada.chaveAviso), findsOneWidget);
    });

    testWidgets('NAO revela se a conta existe', (tester) async {
      // Responder "nao achamos esse e-mail" entregaria a lista de quem tem
      // conta no app. A resposta e a mesma nos dois casos.
      final auth = await montar(tester, contas: {'existe@e.com': 'segredo123'});

      Future<String> respostaPara(String email) async {
        await tester.tap(find.byKey(TelaEntrada.chaveEsqueci));
        await tester.pumpAndSettle();
        await preencher(tester, email: email);
        await enviar(tester);
        final painel = find.descendant(
          of: find.byKey(TelaEntrada.chaveAviso),
          matching: find.byType(Text),
        );
        return tester.widget<Text>(painel).data!;
      }

      final comConta = await respostaPara('existe@e.com');
      final semConta = await respostaPara('naoexiste@e.com');

      expect(comConta, semConta);
      expect(auth.recuperacoesPedidas, hasLength(2));
    });

    testWidgets('e-mail invalido e barrado antes de ir a rede', (tester) async {
      final auth = await montar(tester);

      await tester.tap(find.byKey(TelaEntrada.chaveEsqueci));
      await tester.pumpAndSettle();
      await preencher(tester, email: 'sem-arroba');
      await enviar(tester);

      expect(find.byKey(TelaEntrada.chaveErro), findsOneWidget);
      expect(auth.recuperacoesPedidas, isEmpty);
    });
  });

  group('estado da tela', () {
    testWidgets('trocar de modo limpa o erro anterior', (tester) async {
      // Erro do modo anterior faz parecer que a acao recem-escolhida ja falhou.
      await montar(tester);

      await preencher(tester, email: 'x', senha: 'y');
      await enviar(tester);
      expect(find.byKey(TelaEntrada.chaveErro), findsOneWidget);

      await tester.tap(find.byKey(TelaEntrada.chaveTrocarModo));
      await tester.pumpAndSettle();

      expect(find.byKey(TelaEntrada.chaveErro), findsNothing);
    });

    testWidgets('sessao em cache: quem ja entrou continua entrado', (
      tester,
    ) async {
      // E o que permite login obrigatorio conviver com offline-first: so a
      // PRIMEIRA abertura precisa de rede.
      final auth = AutenticacaoFalsa(jaLogadoComo: 'gustavo@exemplo.com');
      addTearDown(auth.dispose);

      expect(auth.usuarioAtual, isNotNull);
      expect(auth.usuarioAtual!.email, 'gustavo@exemplo.com');
    });

    testWidgets('sair derruba a sessao e avisa quem escuta', (tester) async {
      final auth = AutenticacaoFalsa(jaLogadoComo: 'g@e.com');
      addTearDown(auth.dispose);

      final vistos = <Usuario?>[];
      auth.mudancas.listen(vistos.add);

      await auth.sair();
      await tester.pump();

      expect(auth.usuarioAtual, isNull);
      expect(vistos, [null]);
    });
  });
}
