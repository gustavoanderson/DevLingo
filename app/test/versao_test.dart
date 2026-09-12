import 'dart:io';

import 'package:devlingo/versao.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('a versão exibida não pode divergir do pubspec', () {
    // Duas cópias do mesmo número divergem, e este repositório já pagou esse
    // preço três vezes: a normalização em Python e Dart, a geometria dos
    // cenários, e os badges do README que envelheceram sem ninguém ver.
    //
    // `versaoDoApp` existe porque ler o pubspec em execução exigiria
    // `package_info_plus` — uma dependência com código nativo dos dois lados,
    // para mostrar seis caracteres numa tela que quase ninguém abre. O preço
    // dessa escolha é este teste.
    test('bate com o version: do pubspec.yaml', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final linha = pubspec
          .split('\n')
          .firstWhere((l) => l.startsWith('version:'), orElse: () => '');

      // Controle: sem isto, um pubspec sem `version:` faria o teste passar
      // comparando duas strings vazias.
      expect(
        linha,
        isNotEmpty,
        reason: 'o pubspec.yaml precisa declarar version:',
      );

      // O `+N` é o versionCode do Android. Ele sobe a cada publicação e não
      // diz nada a quem usa o app, então fica de fora da tela.
      final doPubspec = linha.split(':')[1].trim().split('+')[0];

      expect(
        versaoDoApp,
        doPubspec,
        reason:
            'subiu a versão no pubspec e esqueceu de app/lib/versao.dart — '
            'a tela de licenças mostraria a versão anterior',
      );
    });
  });
}
