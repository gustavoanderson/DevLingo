import 'dart:math';

import 'package:flutter/material.dart';

import 'paleta.dart';

/// O fundo da tela de título: horizonte neon com grade em perspectiva.
///
/// Pintado com [CustomPainter], e não desenhado como SVG, porque grade em fuga
/// é **geometria calculada**: as linhas se espaçam por uma progressão, e um
/// arquivo com as coordenadas escritas à mão não se adapta a tela nenhuma.
///
/// Nada aqui se move. O movimento da tela de título é a respiração do mascote e
/// o piscar do texto; um fundo animado atrás disso brigaria com os dois e
/// custaria bateria numa tela onde ninguém fica.
class FundoArcade extends StatelessWidget {
  const FundoArcade({super.key});

  @override
  Widget build(BuildContext context) {
    // RepaintBoundary porque o fundo é estático e o que está por cima anima:
    // sem ele, cada quadro da respiração repintaria a grade inteira.
    return const RepaintBoundary(
      child: CustomPaint(size: Size.infinite, painter: _PintorArcade()),
    );
  }
}

class _PintorArcade extends CustomPainter {
  const _PintorArcade();

  /// Onde o chão encontra o céu, em fração da altura.
  static const double _horizonte = 0.62;

  @override
  void paint(Canvas canvas, Size size) {
    final linhaDoHorizonte = size.height * _horizonte;

    _pintarCeu(canvas, size, linhaDoHorizonte);
    _pintarSol(canvas, size, linhaDoHorizonte);
    _pintarChao(canvas, size, linhaDoHorizonte);
    _pintarGrade(canvas, size, linhaDoHorizonte);
    _pintarBrilhoDoHorizonte(canvas, size, linhaDoHorizonte);
  }

  void _pintarCeu(Canvas canvas, Size size, double horizonte) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, horizonte),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Paleta.veu, Paleta.fundo, Color(0xFF3A1B52)],
          stops: [0, 0.55, 1],
        ).createShader(Rect.fromLTWH(0, 0, size.width, horizonte)),
    );

    // Estrelas: posições de uma semente fixa, para a tela ser sempre a mesma.
    final sorteio = Random(7);
    final estrela = Paint()..color = Paleta.texto;
    for (var i = 0; i < 60; i++) {
      final x = sorteio.nextDouble() * size.width;
      final y = sorteio.nextDouble() * horizonte * 0.8;
      // Estrela mais alta brilha mais: sugere profundidade sem desenhar nada.
      final forca = 1 - (y / (horizonte * 0.8));
      canvas.drawCircle(
        Offset(x, y),
        sorteio.nextDouble() * 1.3 + 0.4,
        estrela..color = Paleta.texto.withValues(alpha: 0.15 + forca * 0.5),
      );
    }
  }

  /// O disco fatiado atrás do horizonte. É a assinatura visual do gênero.
  void _pintarSol(Canvas canvas, Size size, double horizonte) {
    final centro = Offset(size.width / 2, horizonte);
    final raio = size.width * 0.30;

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, horizonte));

    canvas.drawCircle(
      centro,
      raio,
      Paint()
        ..shader =
            const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFE14D), Color(0xFFFF2D95)],
            ).createShader(
              Rect.fromCircle(center: centro, radius: raio),
            ),
    );

    // Fatias: mais largas embaixo, como nos cartazes dos anos 80.
    //
    // O recorte no disco e obrigatorio. Sem ele as fatias sao retangulos da
    // largura INTEIRA do sol, e no topo -- onde o circulo e estreito -- elas
    // sobram para os lados e viram tracos escuros soltos no ceu. Isso apareceu
    // na tela do aparelho como se fossem falhas de renderizacao.
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: centro, radius: raio)),
    );
    final fatia = Paint()..color = Paleta.veu;
    var y = centro.dy - raio * 0.12;
    var altura = 3.0;
    while (y > centro.dy - raio) {
      canvas.drawRect(
        Rect.fromLTWH(centro.dx - raio, y, raio * 2, altura),
        fatia,
      );
      y -= altura + 7;
      altura *= 0.86;
    }
    canvas.restore();
  }

  void _pintarChao(Canvas canvas, Size size, double horizonte) {
    canvas.drawRect(
      Rect.fromLTWH(0, horizonte, size.width, size.height - horizonte),
      Paint()
        ..shader =
            const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1A0B3A), Paleta.veu],
            ).createShader(
              Rect.fromLTWH(0, horizonte, size.width, size.height - horizonte),
            ),
    );
  }

  /// Grade em fuga: verticais convergindo e horizontais se adensando ao longe.
  void _pintarGrade(Canvas canvas, Size size, double horizonte) {
    final fuga = Offset(size.width / 2, horizonte);
    final tinta = Paint()
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(0, horizonte, size.width, size.height - horizonte),
    );

    // Verticais: saem do ponto de fuga e abrem até a borda de baixo.
    for (var i = -14; i <= 14; i++) {
      final x = fuga.dx + i * size.width * 0.14;
      canvas.drawLine(
        fuga,
        Offset(x, size.height),
        tinta..color = Paleta.destaque.withValues(alpha: 0.22),
      );
    }

    // Horizontais: o espaçamento cresce conforme se aproxima, o que e o que
    // produz a sensacao de profundidade.
    var distancia = 0.012;
    while (distancia < 1.2) {
      final y = horizonte + (size.height - horizonte) * distancia;
      if (y > size.height) break;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        tinta..color = Paleta.acerto.withValues(alpha: 0.10 + distancia * 0.22),
      );
      distancia *= 1.42;
    }
    canvas.restore();
  }

  void _pintarBrilhoDoHorizonte(Canvas canvas, Size size, double horizonte) {
    canvas.drawRect(
      Rect.fromLTWH(0, horizonte - 26, size.width, 52),
      Paint()
        ..shader =
            LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Paleta.acerto.withValues(alpha: 0),
                Paleta.acerto.withValues(alpha: 0.5),
                Paleta.acerto.withValues(alpha: 0),
              ],
            ).createShader(
              Rect.fromLTWH(0, horizonte - 26, size.width, 52),
            ),
    );
    canvas.drawLine(
      Offset(0, horizonte),
      Offset(size.width, horizonte),
      Paint()
        ..color = Paleta.acerto
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_PintorArcade oldDelegate) => false;
}
