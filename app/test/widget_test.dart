import 'package:devlingo/data/question_bank.dart';
import 'package:devlingo/models/lesson.dart';
import 'package:devlingo/models/question.dart';
import 'package:flutter_test/flutter_test.dart';

/// Carrega o banco real de `assets/content/` e confere o que o app vai receber.
///
/// Este teste falha se uma pasta de linguagem sumir do `pubspec.yaml`, porque o
/// manifesto de assets deixa de listar os arquivos dela. E a mesma falha que o
/// validador em Python reprova, pega aqui pelo outro lado.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late QuestionBank banco;

  setUpAll(() async {
    banco = await QuestionBank.carregar();
  });

  test('o banco carrega e tem conteudo', () {
    expect(banco.lessons, isNotEmpty);
    expect(banco.totalDeQuestoes, greaterThan(0));
  });

  test('as duas linguagens do pubspec chegaram', () {
    expect(banco.linguagens, containsAll(<String>['python', 'javascript']));
  });

  test('as trilhas vem na ordem sugerida, e nao na alfabetica', () {
    // A ordem alfabetica nao foi decidida por ninguem: saia do `..sort()`, e
    // punha Frameworks -- que DEPENDE de JavaScript -- acima dele, com Python
    // em quarto lugar. As duas comparacoes abaixo sao justamente as que a
    // ordem alfabetica inverteria (backend, frameworks, javascript, python).
    final ordem = banco.linguagens;

    expect(
      ordem.indexOf('python'),
      lessThan(ordem.indexOf('javascript')),
      reason: 'a primeira linguagem recomendada vem primeiro',
    );
    expect(
      ordem.indexOf('javascript'),
      lessThan(ordem.indexOf('frameworks')),
      reason: 'Frameworks assume JavaScript, entao nao pode vir antes dele',
    );
  });

  test('toda trilha do banco tem descricao no cartao', () {
    // Pega o esquecimento no dia em que a sexta trilha for escrita: sem esta
    // linha, ela apareceria na tela com o nome nu, que e o defeito de
    // descoberta que motivou as descricoes.
    for (final linguagem in banco.linguagens) {
      expect(
        descricaoDe(linguagem),
        isNotNull,
        reason:
            'a trilha "$linguagem" existe no banco e nao tem descricao. '
            'Acrescente uma linha em `descricaoDaLinguagem`.',
      );
    }
  });

  test('a trilha de Python iniciante tem 5 licoes e 50 questoes', () {
    final trilha = banco.trilha('python', Level.beginner);

    expect(trilha, hasLength(5));
    expect(
      trilha.map((licao) => licao.numero),
      [1, 2, 3, 4, 5],
      reason: 'as licoes precisam vir em ordem e sem buracos',
    );

    final total = trilha.fold<int>(0, (soma, l) => soma + l.questions.length);
    expect(total, 50, reason: 'a meta da linguagem e 50 questoes');
  });

  test('a licao de referencia existe e fica fora da trilha', () {
    expect(
      banco.lessons.where((licao) => licao.lessonId == 'python-beg-00'),
      hasLength(1),
    );
    expect(
      banco.licoesDaTrilha.where((licao) => licao.ehLicaoDeReferencia),
      isEmpty,
    );
  });

  test('nenhum id de questao se repete no banco inteiro', () {
    final ids = <String>[];
    for (final licao in banco.lessons) {
      ids.addAll(licao.questions.map((questao) => questao.id));
    }
    expect(ids.toSet(), hasLength(ids.length));
  });

  test('toda questao tem dica e explicacao', () {
    for (final licao in banco.lessons) {
      for (final questao in licao.questions) {
        expect(questao.hint, isNotEmpty, reason: '${questao.id} sem dica');
        expect(
          questao.explanation,
          isNotEmpty,
          reason: '${questao.id} sem explicacao',
        );
      }
    }
  });

  test('multipla escolha tem 5 alternativas e exatamente 1 correta', () {
    for (final licao in banco.lessons) {
      for (final questao in licao.questions) {
        if (questao.answerType != AnswerType.multipleChoice) continue;
        expect(questao.options, hasLength(5), reason: questao.id);
        expect(
          questao.options!.where((alternativa) => alternativa.correct),
          hasLength(1),
          reason: questao.id,
        );
      }
    }
  });

  test('toda lacuna tem o marcador no bloco de codigo', () {
    for (final licao in banco.lessons) {
      for (final questao in licao.questions) {
        if (questao.answerType != AnswerType.fillBlank) continue;
        expect(questao.code, isNotNull, reason: '${questao.id} sem codigo');
        expect(questao.code!.temLacuna, isTrue, reason: questao.id);
      }
    }
  });

  test('highlightLine aponta para uma linha que existe', () {
    for (final licao in banco.lessons) {
      for (final questao in licao.questions) {
        final code = questao.code;
        if (code?.highlightLine == null) continue;
        expect(
          code!.highlightLine,
          lessThanOrEqualTo(code.linhas.length),
          reason: questao.id,
        );
      }
    }
  });
}
