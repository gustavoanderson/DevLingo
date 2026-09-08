import 'dart:convert';
import 'dart:io';

import 'package:devlingo/answer/normalize.dart';
import 'package:devlingo/models/question.dart';
import 'package:flutter_test/flutter_test.dart';

/// Prova que a normalizacao em Dart cumpre o mesmo contrato que a em Python.
///
/// Os casos vem de `tools/normalize_cases.json`, o mesmo arquivo que
/// `tools/test_normalize.py` le. As duas implementacoes precisam produzir
/// exatamente os mesmos resultados; se uma divergir, um dos dois lados reprova.
///
/// O arquivo e lido do disco, nao dos assets, de proposito: ele e material de
/// teste do repositorio e nao deve ir dentro do APK.
void main() {
  final arquivo = File('../tools/normalize_cases.json');

  test('o arquivo de casos compartilhado existe', () {
    expect(
      arquivo.existsSync(),
      isTrue,
      reason:
          'esperado em ${arquivo.absolute.path}. '
          'Rode os testes a partir da pasta app/.',
    );
  });

  final dados =
      json.decode(arquivo.readAsStringSync(encoding: utf8))
          as Map<String, dynamic>;

  NormalizeRules? regrasDe(Object? cru) => cru == null
      ? null
      : NormalizeRules.fromJson(cru as Map<String, dynamic>);

  group('normalizacao', () {
    for (final cru in dados['normalizacao'] as List<dynamic>) {
      final caso = cru as Map<String, dynamic>;
      test(caso['nome'] as String, () {
        expect(
          normalize(caso['entrada'] as String, regrasDe(caso['regras'])),
          caso['saida'] as String,
        );
      });
    }
  });

  group('aceitacao', () {
    for (final cru in dados['aceitacao'] as List<dynamic>) {
      final caso = cru as Map<String, dynamic>;
      test(caso['nome'] as String, () {
        final aceitas = (caso['aceitas'] as List<dynamic>).cast<String>();
        expect(
          accepts(
            caso['resposta'] as String,
            aceitas,
            regrasDe(caso['regras']),
          ),
          caso['aceita'] as bool,
        );
      });
    }
  });

  group('as respostas do banco sao aceitas pela propria normalizacao', () {
    // Uma resposta listada em "accepted" que a normalizacao recusasse seria uma
    // questao impossivel de acertar. Isto varre o banco inteiro procurando isso.
    test('toda resposta aceita responde a propria questao', () async {
      final banco = File('assets/content');
      expect(banco.existsSync() || Directory('assets/content').existsSync(), isTrue);

      final arquivos = Directory('assets/content')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'));

      var conferidas = 0;
      for (final f in arquivos) {
        final licao =
            json.decode(f.readAsStringSync(encoding: utf8))
                as Map<String, dynamic>;
        for (final q in licao['questions'] as List<dynamic>) {
          final questao = q as Map<String, dynamic>;
          final aceitas = (questao['accepted'] as List<dynamic>?)
              ?.cast<String>();
          if (aceitas == null) continue;

          final regras = regrasDe(questao['normalize']);
          for (final resposta in aceitas) {
            expect(
              accepts(resposta, aceitas, regras),
              isTrue,
              reason:
                  '${questao['id']}: a resposta "$resposta" esta listada como '
                  'aceita mas a normalizacao a recusaria',
            );
            conferidas++;
          }
        }
      }

      expect(conferidas, greaterThan(0), reason: 'nenhuma resposta conferida');
    });
  });

  group('quando vale mostrar o molde da resposta', () {
    // O molde resolve UM problema: nao saber onde a resposta termina. Ele so
    // faz sentido quando ha estrutura em volta -- e o banco mostrou que a
    // maioria das respostas de escrita nao tem.
    test('mostra em resposta com estrutura de codigo', () {
      expect(valeMostrarMolde('if (saldo > 0) {'), isTrue);
      expect(valeMostrarMolde('console.log("Oi");'), isTrue);
      expect(valeMostrarMolde('const total = 0;'), isTrue);
      expect(valeMostrarMolde('idade >= 18'), isTrue);
    });

    test('nao mostra em palavra ou sigla solta', () {
      // Aqui o molde vira contador de letras: entrega o tamanho de graca e
      // nao esclarece nada, porque nao ha ambiguidade de escopo.
      for (final r in ['WHERE', 'DNS', 'POST', 'https', 'JSON', 'livros']) {
        expect(
          valeMostrarMolde(r),
          isFalse,
          reason: '$r nao tem estrutura: o molde seria so pontos',
        );
      }
    });

    test('nao mostra quando o molde seria a propria resposta', () {
      // `===` e `!=` nao tem letra nenhuma para esconder. Exibir o molde
      // deles seria entregar o gabarito com nome de ajuda.
      for (final r in ['===', '!=']) {
        expect(esqueletoDe(r), r, reason: 'nao ha o que esconder em $r');
        expect(valeMostrarMolde(r), isFalse);
      }
    });

    test('hifen e espaco sozinhos nao contam como estrutura', () {
      // O enunciado dessas ja diz o formato -- "duas palavras unidas por
      // hifen" --, entao o molde so repetiria o que ja foi dito.
      expect(valeMostrarMolde('Content-Type'), isFalse);
      expect(valeMostrarMolde('request response'), isFalse);
      expect(valeMostrarMolde('NOT NULL'), isFalse);
    });
  });
}
