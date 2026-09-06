import 'dart:convert';

import 'package:devlingo/models/question.dart';
import 'package:flutter_test/flutter_test.dart';

Question lerQuestao(String cru) =>
    Question.fromJson(json.decode(cru) as Map<String, dynamic>);

void main() {
  group('code e independente de answerType', () {
    // Este e o principio central do formato. Os quatro testes abaixo cobrem as
    // quatro combinacoes possiveis. Se algum deles precisar mudar, a separacao
    // entre "o que a questao mostra" e "como ela e respondida" foi quebrada.

    test('multipla escolha SEM codigo', () {
      final questao = lerQuestao('''
      {
        "id": "python-beg-0101",
        "topic": "saida",
        "prompt": "Qual funcao exibe algo na tela?",
        "answerType": "multipleChoice",
        "options": [
          {"id": "a", "text": "write()",  "correct": false},
          {"id": "b", "text": "print()",  "correct": true},
          {"id": "c", "text": "echo()",   "correct": false},
          {"id": "d", "text": "show()",   "correct": false},
          {"id": "e", "text": "log()",    "correct": false}
        ],
        "hint": "Pense no que voce digitaria num arquivo .py.",
        "explanation": "A funcao embutida do Python e print()."
      }''');

      expect(questao.code, isNull);
      expect(questao.answerType, AnswerType.multipleChoice);
      expect(questao.options, hasLength(5));
      expect(questao.alternativaCorreta.text, 'print()');
    });

    test('multipla escolha COM codigo', () {
      final questao = lerQuestao('''
      {
        "id": "python-beg-0201",
        "topic": "operadores",
        "prompt": "O que este codigo imprime?",
        "code": {"language": "python", "content": "print(7 // 2)", "highlightLine": 1},
        "answerType": "multipleChoice",
        "options": [
          {"id": "a", "text": "3.5", "correct": false},
          {"id": "b", "text": "3",   "correct": true},
          {"id": "c", "text": "4",   "correct": false},
          {"id": "d", "text": "1",   "correct": false},
          {"id": "e", "text": "35",  "correct": false}
        ],
        "hint": "A barra dupla guarda so a parte inteira.",
        "explanation": "Divisao inteira: 7 por 2 da 3."
      }''');

      expect(questao.code, isNotNull);
      expect(questao.code!.content, 'print(7 // 2)');
      expect(questao.code!.highlightLine, 1);
      expect(questao.answerType, AnswerType.multipleChoice);
    });

    test('lacuna COM codigo, e o codigo traz o marcador', () {
      final questao = lerQuestao('''
      {
        "id": "python-beg-0207",
        "topic": "operadores",
        "prompt": "Complete para obter o resto da divisao.",
        "code": {"language": "python", "content": "total = 47\\nprint(total ______ 2)", "highlightLine": 2},
        "answerType": "fillBlank",
        "accepted": ["%"],
        "hint": "O operador que devolve o que sobra da divisao.",
        "explanation": "O modulo devolve o resto."
      }''');

      expect(questao.answerType, AnswerType.fillBlank);
      expect(questao.answerType.ehEscrita, isTrue);
      expect(questao.code!.temLacuna, isTrue);
      expect(questao.code!.linhas, hasLength(2));
      expect(questao.accepted, ['%']);
      expect(questao.options, isNull);
    });

    test('escrita livre SEM codigo', () {
      final questao = lerQuestao('''
      {
        "id": "python-beg-0509",
        "topic": "listas",
        "prompt": "Escreva a linha que cria a variavel notas.",
        "answerType": "freeWrite",
        "accepted": ["notas = [7, 8, 9]"],
        "hint": "Nome, sinal de igual, e os numeros entre colchetes.",
        "explanation": "Os colchetes criam a lista."
      }''');

      expect(questao.code, isNull);
      expect(questao.answerType, AnswerType.freeWrite);
      expect(questao.answerType.ehEscrita, isTrue);
      expect(questao.accepted, hasLength(1));
    });
  });

  group('combinacoes invalidas falham alto', () {
    // Testes negativos. O validador em Python ja reprova isso antes de entrar no
    // repositorio, mas um asset editado a mao nao passa por ele, e renderizar
    // uma questao sem resposta possivel e pior que quebrar na hora de carregar.

    test('multipla escolha com accepted e recusada', () {
      expect(
        () => lerQuestao('''
        {
          "id": "python-beg-9901",
          "topic": "x",
          "prompt": "Enunciado qualquer",
          "answerType": "multipleChoice",
          "options": [
            {"id": "a", "text": "1", "correct": true},
            {"id": "b", "text": "2", "correct": false},
            {"id": "c", "text": "3", "correct": false},
            {"id": "d", "text": "4", "correct": false},
            {"id": "e", "text": "5", "correct": false}
          ],
          "accepted": ["1"],
          "hint": "Dica qualquer suficientemente longa.",
          "explanation": "Explicacao qualquer suficientemente longa."
        }'''),
        throwsFormatException,
      );
    });

    test('lacuna sem accepted e recusada', () {
      expect(
        () => lerQuestao('''
        {
          "id": "python-beg-9902",
          "topic": "x",
          "prompt": "Enunciado qualquer",
          "code": {"language": "python", "content": "print(______)"},
          "answerType": "fillBlank",
          "hint": "Dica qualquer suficientemente longa.",
          "explanation": "Explicacao qualquer suficientemente longa."
        }'''),
        throwsFormatException,
      );
    });

    test('answerType desconhecido e recusado', () {
      expect(
        () => lerQuestao('''
        {
          "id": "python-beg-9903",
          "topic": "x",
          "prompt": "Enunciado qualquer",
          "answerType": "arrastarESoltar",
          "accepted": ["x"],
          "hint": "Dica qualquer suficientemente longa.",
          "explanation": "Explicacao qualquer suficientemente longa."
        }'''),
        throwsFormatException,
      );
    });
  });

  group('normalize', () {
    test('sem o campo, usa os mesmos padroes do esquema JSON', () {
      final questao = lerQuestao('''
      {
        "id": "python-beg-9904",
        "topic": "x",
        "prompt": "Enunciado qualquer",
        "answerType": "freeWrite",
        "accepted": ["total = 10"],
        "hint": "Dica qualquer suficientemente longa.",
        "explanation": "Explicacao qualquer suficientemente longa."
      }''');

      expect(questao.normalize.spaces, isTrue);
      expect(questao.normalize.quotes, isTrue);
      expect(questao.normalize.trailingSemicolon, isTrue);
      expect(questao.normalize.caseSensitive, isFalse);
    });

    test('respeita o que a questao declara', () {
      final questao = lerQuestao('''
      {
        "id": "python-beg-9905",
        "topic": "x",
        "prompt": "Enunciado qualquer",
        "answerType": "freeWrite",
        "accepted": ["print(nome)"],
        "normalize": {"spaces": true, "quotes": true, "trailingSemicolon": true, "caseSensitive": true},
        "hint": "Dica qualquer suficientemente longa.",
        "explanation": "Explicacao qualquer suficientemente longa."
      }''');

      expect(questao.normalize.caseSensitive, isTrue);
    });
  });
}
