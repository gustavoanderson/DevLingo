/// O rosto do Tr∅nikAt existe em DOIS desenhos, e este teste impede que virem
/// dois personagens.
///
/// `site/codec.js` desenha o retrato em canvas 2D, para o site e para o jogo do
/// navegador; `app/lib/ui/tronikat_codec.dart` desenha o mesmo retrato no app.
/// A duplicação é escolha registrada do Gustavo, de 22 de setembro de 2026,
/// feita com o custo na mesa.
///
/// **O que este teste protege não é o código — é o personagem.** Ordem de
/// camadas, curva do ombro e tamanho do bigode podem divergir sem que ninguém
/// deixe de reconhecer o gato. O que NÃO pode divergir é quem ele é: a cor do
/// olho, o verde do visor, o ângulo das orelhas, a proporção da cabeça. Este
/// repositório tem a cicatriz — um olho âmbar inventado, e o Gustavo pegou na
/// hora: *"um gato de olho âmbar é outro gato"*.
///
/// É a mesma forma de `tools/normalize_cases.json`: duas implementações da
/// mesma regra, e um portão que prova que concordam. Lá o arquivo é lido pelos
/// dois lados; aqui o Dart lê o JavaScript, porque é o JavaScript que veio
/// primeiro e é dele que a arte canônica foi copiada.
library;

import 'dart:io';

import 'package:devlingo/ui/tronikat_codec.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lê `const NOME = '#RRGGBB'` do JavaScript, aceitando várias por linha.
Map<String, String> _coresDoJs(String js) {
  final achadas = <String, String>{};
  final re = RegExp(r"\b([A-Z_]+)\s*=\s*'(#[0-9A-Fa-f]{6})'");
  for (final m in re.allMatches(js)) {
    achadas[m.group(1)!] = m.group(2)!.toUpperCase();
  }
  return achadas;
}

/// Lê `const CX = 64, CY = 45, ...` do JavaScript.
Map<String, double> _numerosDoJs(String js) {
  final achados = <String, double>{};
  final re = RegExp(r'\b(CX|CY|RX|RY)\s*=\s*(-?[\d.]+)');
  for (final m in re.allMatches(js)) {
    achados[m.group(1)!] = double.parse(m.group(2)!);
  }
  return achados;
}

String _hex(Color c) {
  final v = c.toARGB32() & 0xFFFFFF;
  return '#${v.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

void main() {
  // O teste roda a partir de `app/`, e o JavaScript mora na raiz do
  // repositório. Se este caminho quebrar, o teste FALHA em vez de passar
  // calado -- arquivo de contrato que some é pior que contrato violado.
  final arquivo = File('../site/codec.js');

  test('o desenho do rosto existe nos dois lados', () {
    expect(arquivo.existsSync(), isTrue,
        reason: 'site/codec.js sumiu, e é a fonte da arte canônica do retrato. '
            'Se ele mudou de lugar, este teste precisa apontar para o novo.');
  });

  group('as cores de identidade batem com site/codec.js', () {
    late Map<String, String> js;

    setUpAll(() => js = _coresDoJs(arquivo.readAsStringSync()));

    // Cada par aqui é um traço que define o personagem. O nome à esquerda é o
    // do JavaScript; o valor à direita, o do Dart.
    final pares = <String, Color>{
      'PELO': Codec.pelo,
      'PELO_SOMBRA': Codec.peloSombra,
      'METAL': Codec.metal,
      'METAL_LUZ': Codec.metalLuz,
      'METAL_SOMBRA': Codec.metalSombra,
      'ESCURO': Codec.escuro,
      'CIANO': Codec.ciano,
      'VISOR': Codec.visor,
      'ROSA': Codec.rosa,
      'ROSA_FORTE': Codec.rosaForte,
      'MOLETOM': Codec.moletom,
    };

    for (final e in pares.entries) {
      test(e.key, () {
        expect(js, contains(e.key),
            reason: '${e.key} sumiu do codec.js. Se foi renomeada lá, renomeie '
                'aqui também -- senão este portão passa a guardar nada.');
        expect(_hex(e.value), js[e.key],
            reason: 'O ${e.key} do app e o do site deixaram de ser a mesma cor. '
                'Um gato de olho âmbar é outro gato: conserte os dois lados.');
      });
    }

    test('o ESCURO do olho não virou outra coisa', () {
      // Redundante de propósito. O olho é o traço que já foi inventado uma vez
      // neste projeto, e merece uma linha só dele.
      expect(_hex(Codec.escuro), '#17092E');
    });
  });

  test('a elipse da cabeça bate com site/codec.js', () {
    final n = _numerosDoJs(arquivo.readAsStringSync());
    expect(n['CX'], Codec.cx);
    expect(n['CY'], Codec.cy);
    expect(n['RX'], Codec.rx, reason: 'a largura da cabeça define a silhueta');
    expect(n['RY'], Codec.ry);
  });

  test('os ângulos das orelhas batem com site/codec.js', () {
    final js = arquivo.readAsStringSync();
    // As duas chamadas de `orelha(...)` no JavaScript, com os números crus.
    final re = RegExp(r'orelha\(\s*(-?[\d.]+),\s*(-?[\d.]+),\s*(-?[\d.]+),\s*(-?[\d.]+)');
    final ms = re.allMatches(js).toList();
    expect(ms.length, 2,
        reason: 'esperava duas orelhas desenhadas no codec.js, achei ${ms.length}');

    final esq = ms[0], dir = ms[1];
    expect(double.parse(esq.group(1)!), Codec.orelhaEsqA1);
    expect(double.parse(esq.group(2)!), Codec.orelhaEsqA2);
    expect(double.parse(esq.group(3)!), Codec.orelhaEsqAlt);
    expect(double.parse(esq.group(4)!), Codec.orelhaEsqInclina);

    expect(double.parse(dir.group(1)!), Codec.orelhaDirA1);
    expect(double.parse(dir.group(2)!), Codec.orelhaDirA2);
    expect(double.parse(dir.group(3)!), Codec.orelhaDirAlt);
    expect(double.parse(dir.group(4)!), Codec.orelhaDirInclina);
  });

  test('a direita NÃO é o espelho da esquerda', () {
    // Está nas duas artes canônicas, e o CLAUDE.md registra: ela é um pouco
    // maior e tem a base mais inclinada. Espelhar seria "simplificar" o
    // personagem até ele virar outro.
    expect(Codec.orelhaDirAlt, greaterThan(Codec.orelhaEsqAlt));
    expect(Codec.orelhaDirInclina.abs(), isNot(Codec.orelhaEsqInclina.abs()));
  });

  test('orelha de gato é quase reta', () {
    // Poucos graus a mais já leem como orelha caída, que é outro animal. O
    // retrato do mascote já saiu a 36 graus uma vez.
    expect(Codec.orelhaEsqInclina.abs(), lessThan(15));
    expect(Codec.orelhaDirInclina.abs(), lessThan(15));
  });

  testWidgets('o retrato desenha, e respeita "reduzir animações"',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: TronikatCodec())),
    ));
    expect(find.byType(TronikatCodec), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 120));

    // Com "reduzir animações" ligado ele continua na tela, parado -- some
    // seria tirar o personagem de quem tem menos pistas visuais.
    await tester.pumpWidget(const MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: Scaffold(body: Center(child: TronikatCodec())),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.byType(TronikatCodec), findsOneWidget);
  });
}
