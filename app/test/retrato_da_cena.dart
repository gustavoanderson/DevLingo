// Renderiza a cena da tela de entrada num PNG, para revisar a arte.
//
// NAO e um teste: nao afirma nada e nao entra na suite (o nome nao termina em
// `_test.dart`, entao `flutter test` o ignora).
//
// Existe porque a alternativa para ver esta tela e compilar o app inteiro,
// instalar, DESLOGAR -- ela so aparece para quem nao tem sessao -- e navegar
// ate ela. Sao uns quatro minutos para olhar um desenho.
//
//     flutter test test/retrato_da_cena.dart
//
// O PNG sai em `build/retrato-da-cena.png`.
//
// **Ele grava o arquivo e depois falha ao encerrar**, e o arquivo esta certo.
// A cena mantem trabalho pendente que nem `disableAnimations` nem
// `atenuada: true` zeraram, e perseguir isso custou mais que o utilitario
// vale. Olhe o PNG e ignore a falha.
//
// `atenuada: true` faria o teste terminar mais rapido e NAO serve: o nome ja
// diz o que ela faz, e um retrato atenuado nao representa a arte que o app
// desenha -- seria aprovar um desenho olhando outro.
//
// A fonte do ambiente de teste desenha cada glifo como um quadrado, entao
// texto sai errado aqui de proposito -- ver o CLAUDE.md. Para ARTE desenhada
// em Canvas, que e o caso, isso nao atrapalha.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:devlingo/ui/cena_do_login.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('retrato da cena', (tester) async {
    final chave = GlobalKey();
    tester.view.physicalSize = const Size(760, 620);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF170A31),
          // A cena roda em `repeat()` e nao para sozinha: sem isto o teste
          // fica com um timer pendente, estoura o limite de 10 minutos e
          // falha DEPOIS de ja ter gravado o PNG -- confuso para quem vier
          // olhar o resultado.
          //
          // `disableAnimations` e o mesmo sinal do "reduzir animacoes" do
          // Android, que a cena ja respeita por acessibilidade. Ela desenha
          // inteira, parada no repouso -- que e exatamente o quadro que se
          // quer revisar.
          body: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Center(
            child: RepaintBoundary(
              key: chave,
              // `comCena: false` deixa a animacao parada. Com ela em
              // `repeat()`, `pumpAndSettle` esperaria para sempre -- o mesmo
              // motivo pelo qual o padrao do widget e falso.
              child: const SizedBox(
                width: 360,
                height: 300,
                child: CenaDoLogin(),
              ),
            ),
          ),
        ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    final limite =
        chave.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final imagem = await limite.toImage(pixelRatio: 3.0);
    final bytes = await imagem.toByteData(format: ui.ImageByteFormat.png);
    File('build/retrato-da-cena.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
    // ignore: avoid_print
    print('retrato salvo em build/retrato-da-cena.png');

  });
}
