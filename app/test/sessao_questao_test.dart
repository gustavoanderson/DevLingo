import 'dart:convert';
import 'dart:math';

import 'package:devlingo/answer/sessao_questao.dart';
import 'package:devlingo/models/question.dart';
import 'package:flutter_test/flutter_test.dart';

Question ler(String cru) =>
    Question.fromJson(json.decode(cru) as Map<String, dynamic>);

/// Multipla escolha com 'why' em todas as erradas.
final questaoMC = ler('''
{
  "id": "python-beg-0101",
  "topic": "saida",
  "prompt": "Qual funcao exibe algo na tela?",
  "answerType": "multipleChoice",
  "options": [
    {"id": "a", "text": "write()",     "correct": false, "why": "Nao existe funcao com esse nome embutida."},
    {"id": "b", "text": "display()",   "correct": false, "why": "Esse nome nao pertence a linguagem."},
    {"id": "c", "text": "print()",     "correct": true},
    {"id": "d", "text": "echo()",      "correct": false, "why": "Essa forma vem do PHP."},
    {"id": "e", "text": "console.log()","correct": false, "why": "Essa forma vem do JavaScript."}
  ],
  "hint": "Pense no que voce digitaria num arquivo com extensao py.",
  "explanation": "A funcao embutida do Python para exibir na saida padrao e print()."
}''');

/// Multipla escolha sem 'why' nenhum: o app cai na linha neutra.
final questaoSemWhy = ler('''
{
  "id": "python-beg-0102",
  "topic": "saida",
  "prompt": "Enunciado qualquer",
  "answerType": "multipleChoice",
  "options": [
    {"id": "a", "text": "um",    "correct": false},
    {"id": "b", "text": "dois",  "correct": true},
    {"id": "c", "text": "tres",  "correct": false},
    {"id": "d", "text": "quatro","correct": false},
    {"id": "e", "text": "cinco", "correct": false}
  ],
  "hint": "Dica qualquer suficientemente longa.",
  "explanation": "Explicacao qualquer suficientemente longa."
}''');

final questaoEscrita = ler('''
{
  "id": "python-beg-0110",
  "topic": "variaveis",
  "prompt": "Escreva a linha que exibe o valor da variavel nome.",
  "answerType": "freeWrite",
  "accepted": ["print(nome)"],
  "normalize": {"spaces": true, "quotes": true, "trailingSemicolon": true, "caseSensitive": true},
  "hint": "Chame a funcao de exibicao passando a variavel, sem aspas ao redor.",
  "explanation": "Sem aspas o Python busca o valor guardado na variavel."
}''');

/// Erra de proposito, sempre escolhendo a primeira alternativa ainda viva.
void errarUmaVez(SessaoQuestao s) {
  final alvo = s.alternativas.firstWhere(
    (o) => !o.correct && !s.estaEliminada(o),
  );
  s.selecionar(alvo);
  s.verificar();
}

void main() {
  group('embaralhamento', () {
    test('as alternativas mudam de ordem entre exibicoes', () {
      // Sem embaralhar, refazer a licao viraria decoreba de posicao.
      final ordens = <String>{};
      for (var semente = 0; semente < 30; semente++) {
        final s = SessaoQuestao(questaoMC, sorteio: Random(semente));
        ordens.add(s.alternativas.map((o) => o.id).join());
      }
      expect(ordens.length, greaterThan(1));
    });

    test('nenhuma alternativa se perde nem se duplica', () {
      final s = SessaoQuestao(questaoMC, sorteio: Random(7));
      expect(s.alternativas, hasLength(5));
      expect(s.alternativas.map((o) => o.id).toSet(), {'a', 'b', 'c', 'd', 'e'});
      expect(s.alternativas.where((o) => o.correct), hasLength(1));
    });

    test('a marca de correta viaja junto com o objeto', () {
      for (var semente = 0; semente < 20; semente++) {
        final s = SessaoQuestao(questaoMC, sorteio: Random(semente));
        expect(s.correta.text, 'print()');
      }
    });
  });

  group('multipla escolha: acerto', () {
    test('acertar de primeira termina e libera a explicacao', () {
      final s = SessaoQuestao(questaoMC, sorteio: Random(1));
      s.selecionar(s.correta);
      s.verificar();

      expect(s.fase, FaseResposta.acertou);
      expect(s.terminou, isTrue);
      expect(s.tentativas, 1);
      expect(s.explicacao, isNotNull);
      expect(s.eliminadas, isEmpty);
    });

    test('acertar depois de errar tambem termina em acerto', () {
      final s = SessaoQuestao(questaoMC, sorteio: Random(2));
      errarUmaVez(s);
      errarUmaVez(s);
      s.selecionar(s.correta);
      s.verificar();

      expect(s.fase, FaseResposta.acertou);
      expect(s.tentativas, 3, reason: 'o numero de tentativas fica registrado');
      expect(s.eliminadas, hasLength(2));
    });
  });

  group('multipla escolha: erro elimina e devolve a vez', () {
    test('errar elimina a escolhida e limpa a selecao', () {
      final s = SessaoQuestao(questaoMC, sorteio: Random(3));
      final alvo = s.alternativas.firstWhere((o) => !o.correct);

      s.selecionar(alvo);
      s.verificar();

      expect(s.fase, FaseResposta.respondendo);
      expect(s.estaEliminada(alvo), isTrue);
      expect(s.selecionada, isNull, reason: 'a vez volta para o aluno');
      expect(s.terminou, isFalse);
    });

    test('alternativa eliminada nao pode ser selecionada de novo', () {
      final s = SessaoQuestao(questaoMC, sorteio: Random(4));
      final alvo = s.alternativas.firstWhere((o) => !o.correct);

      s.selecionar(alvo);
      s.verificar();
      s.selecionar(alvo);

      expect(s.selecionada, isNull);
    });

    test('o recado usa o why da alternativa escolhida', () {
      final s = SessaoQuestao(questaoMC, sorteio: Random(5));
      final alvo = s.alternativas.firstWhere((o) => o.id == 'd');

      s.selecionar(alvo);
      s.verificar();

      expect(s.recado, 'Essa forma vem do PHP.');
    });

    test('sem why, cai numa linha neutra em vez de silencio', () {
      final s = SessaoQuestao(questaoSemWhy, sorteio: Random(6));
      errarUmaVez(s);

      expect(s.recado, isNotNull);
      expect(s.recado, contains('saiu da lista'));
    });

    test('a explicacao NAO aparece durante as tentativas', () {
      // Mostra-la no primeiro erro entregaria a resposta e esvaziaria a
      // eliminacao progressiva.
      final s = SessaoQuestao(questaoMC, sorteio: Random(8));
      errarUmaVez(s);

      expect(s.explicacao, isNull);
    });
  });

  group('multipla escolha: o quarto erro revela', () {
    test('quatro erros revelam em vez de pedir o toque cerimonial', () {
      final s = SessaoQuestao(questaoMC, sorteio: Random(9));
      for (var i = 0; i < 4; i++) {
        errarUmaVez(s);
      }

      expect(s.fase, FaseResposta.revelado);
      expect(s.terminou, isTrue);
      expect(s.eliminadas, hasLength(4));
      expect(s.explicacao, isNotNull);
      expect(s.tentativas, 4);
    });

    test('depois de revelado, nada mais muda o estado', () {
      final s = SessaoQuestao(questaoMC, sorteio: Random(10));
      for (var i = 0; i < 4; i++) {
        errarUmaVez(s);
      }
      final tentativasNoFim = s.tentativas;

      s.selecionar(s.correta);
      s.verificar();

      expect(s.fase, FaseResposta.revelado);
      expect(s.tentativas, tentativasNoFim);
    });
  });

  group('escrita: ajuda cresce a cada erro', () {
    test('acertar de primeira termina', () {
      final s = SessaoQuestao(questaoEscrita);
      s.verificarEscrita('print(nome)');

      expect(s.fase, FaseResposta.acertou);
      expect(s.tentativas, 1);
      expect(s.dicaAberta, isFalse);
    });

    test('espacamento diferente ainda e acerto', () {
      final s = SessaoQuestao(questaoEscrita);
      s.verificarEscrita('  print( nome )  ');
      expect(s.fase, FaseResposta.acertou);
    });

    test('primeiro erro so avisa', () {
      final s = SessaoQuestao(questaoEscrita);
      s.verificarEscrita('print nome');

      expect(s.fase, FaseResposta.respondendo);
      expect(s.dicaAberta, isFalse);
      expect(s.recado, contains('Não é isso ainda'));
    });

    test('segundo erro abre a dica sozinho', () {
      final s = SessaoQuestao(questaoEscrita);
      s.verificarEscrita('print nome');
      s.verificarEscrita('print("nome")');

      expect(s.fase, FaseResposta.respondendo);
      expect(s.dicaAberta, isTrue);
    });

    test('terceiro erro aponta para a forma, em vez de repeti-la', () {
      // A forma ficava aqui, no terceiro erro. Hoje ela e o molde exibido
      // desde o comeco da questao -- mostra-la de novo poria a mesma coisa
      // duas vezes na tela. O recado passou a apontar para o que ja esta la.
      final s = SessaoQuestao(questaoEscrita);
      s.verificarEscrita('a');
      s.verificarEscrita('b');
      s.verificarEscrita('c');

      expect(s.fase, FaseResposta.respondendo);
      expect(s.esqueleto, isNull, reason: 'nao se mostra a forma duas vezes');
      expect(s.recado, contains('formato'));
      expect(s.respostaRevelada, isNull);
    });

    test('quarto erro revela a resposta', () {
      final s = SessaoQuestao(questaoEscrita);
      for (final tentativa in ['a', 'b', 'c', 'd']) {
        s.verificarEscrita(tentativa);
      }

      expect(s.fase, FaseResposta.revelado);
      expect(s.respostaRevelada, 'print(nome)');
      expect(s.explicacao, isNotNull);
      expect(s.esqueleto, isNull, reason: 'a forma sai de cena quando a resposta aparece');
    });

    test('acertar limpa o recado dos erros anteriores', () {
      final s = SessaoQuestao(questaoEscrita);
      s.verificarEscrita('a');
      s.verificarEscrita('b');
      s.verificarEscrita('c');
      expect(s.recado, isNotNull);

      s.verificarEscrita('print(nome)');
      expect(s.fase, FaseResposta.acertou);
      expect(s.esqueleto, isNull);
    });

    test('texto vazio nao gasta tentativa', () {
      final s = SessaoQuestao(questaoEscrita);
      s.verificarEscrita('   ');

      expect(s.tentativas, 0);
      expect(s.fase, FaseResposta.respondendo);
    });
  });

  group('dica', () {
    test('pode ser aberta a qualquer momento antes do fim', () {
      final s = SessaoQuestao(questaoMC, sorteio: Random(11));
      expect(s.dicaAberta, isFalse);
      s.abrirDica();
      expect(s.dicaAberta, isTrue);
    });
  });
}
