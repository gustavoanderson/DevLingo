import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_parsing/path_parsing.dart';

import 'cenario_gerado.dart';

/// A faixa de cenário animada, colada na borda de baixo da tela de exercício.
///
/// O Tr∅nikAt **caminha parado** e o cenário desliza atrás dele, no sentido
/// oposto ao que ele aponta. Cada camada é desenhada duas vezes, lado a lado, e
/// desliza exatamente a largura de um bloco — é isso que torna o loop invisível,
/// porque o quadro em que ela volta ao início é idêntico ao anterior.
///
/// A geometria e as cores vêm de `cenario_gerado.dart`, que é escrito pelo
/// mesmo script que escreve os SVGs em `assets/cenarios/`. Ver
/// `tools/gerar_faixas.py`.
///
/// ## As regras de performance, e o que cada uma evita
///
/// Estão no CLAUDE.md e todas custam pouco:
///
/// 1. **Um `AnimationController` só** para as duas camadas e para o passo do
///    gato. Vários relógios concorrentes engasgam e vazam
/// 2. **`RepaintBoundary`** isolando a faixa, senão cada quadro dela obrigaria
///    o card da pergunta a se redesenhar junto
/// 3. **Para em segundo plano.** Sem isso, anima com a tela desligada
/// 4. **Congela com o teclado aberto**, quando responder é o que importa
/// 5. **Respeita "reduzir animações"** do Android
/// 6. **Dá para desligar** nas preferências
/// 7. Véu escuro entre o fundo e o conteúdo — aqui é a própria borda da faixa
class FaixaCenario extends StatefulWidget {
  const FaixaCenario({
    super.key,
    this.faixa = 'noite',
    this.congelada = false,
  });

  /// Qual das três faixas desenhar: `dia`, `tarde` ou `noite`.
  final String faixa;

  /// Para o movimento sem tirar a faixa da tela.
  ///
  /// Usado quando o teclado abre: a faixa continua ali, o cenário fica parado.
  /// Sumir com ela faria o layout pular no meio da digitação.
  final bool congelada;

  static const double altura = alturaDaFaixa;

  @override
  State<FaixaCenario> createState() => _FaixaCenarioState();
}

class _FaixaCenarioState extends State<FaixaCenario>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  /// Um relógio só, e ele mede **o ciclo mais longo**: o da camada de trás.
  ///
  /// As outras duas velocidades saem deste mesmo valor por multiplicação. Com
  /// um controlador por camada, elas iriam saindo de sincronia ao longo dos
  /// minutos e o loop deixaria de fechar.
  late final AnimationController _relogio = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (segundosLonge * 1000).round()),
  );

  bool _emPrimeiroPlano = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    // App em segundo plano continua recebendo quadros em algumas situacoes, e
    // animar com a tela desligada e so gasto de bateria.
    final visivel = estado == AppLifecycleState.resumed;
    if (visivel == _emPrimeiroPlano) return;
    _emPrimeiroPlano = visivel;
    _ajustar();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ajustar();
  }

  @override
  void didUpdateWidget(FaixaCenario anterior) {
    super.didUpdateWidget(anterior);
    _ajustar();
  }

  bool get _deveAnimar =>
      _emPrimeiroPlano &&
      !widget.congelada &&
      !MediaQuery.disableAnimationsOf(context);

  void _ajustar() {
    if (_deveAnimar) {
      if (!_relogio.isAnimating) _relogio.repeat();
    } else {
      _relogio.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _relogio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // `_ajustar` NAO e chamado aqui de proposito. Ligar ou parar uma animacao
    // durante o `build` e mexer no estado no meio da construcao da arvore;
    // `didChangeDependencies`, `didUpdateWidget` e o retorno do ciclo de vida
    // ja cobrem todas as vezes em que a resposta pode ter mudado.
    final cenario = faixas[widget.faixa] ?? faixas['noite']!;

    // RepaintBoundary: a faixa repinta a cada quadro e o resto da tela nao.
    // Sem ele, o card da pergunta entraria na mesma camada e seria redesenhado
    // 60 vezes por segundo junto com o cenario.
    return RepaintBoundary(
      child: SizedBox(
        height: FaixaCenario.altura,
        width: double.infinity,
        child: AnimatedBuilder(
          animation: _relogio,
          builder: (_, _) => CustomPaint(
            painter: _PintorDaFaixa(cenario: cenario, avanco: _relogio.value),
          ),
        ),
      ),
    );
  }
}

/// Transforma a string `d` de um caminho SVG num [Path] do Flutter.
///
/// O `path_parsing` empurra os comandos para um destino; este é o destino.
class _DestinoDoCaminho extends PathProxy {
  final Path path = Path();

  @override
  void close() => path.close();

  @override
  void cubicTo(
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3,
  ) => path.cubicTo(x1, y1, x2, y2, x3, y3);

  @override
  void lineTo(double x, double y) => path.lineTo(x, y);

  @override
  void moveTo(double x, double y) => path.moveTo(x, y);
}

/// Converte e guarda em cache.
///
/// As mesmas cinco ou seis strings são desenhadas a cada quadro; reconverter
/// texto em geometria 60 vezes por segundo seria trabalho jogado fora. As
/// strings vêm de um arquivo gerado, então o mapa é limitado e não cresce.
final Map<String, Path> _cache = {};

Path _caminho(String d) => _cache.putIfAbsent(d, () {
  final destino = _DestinoDoCaminho();
  writeSvgPathDataToPath(d, destino);
  return destino.path;
});

class _PintorDaFaixa extends CustomPainter {
  const _PintorDaFaixa({required this.cenario, required this.avanco});

  final FaixaDoCenario cenario;

  /// Volta de 0 a 1 ao longo do ciclo da camada de trás.
  final double avanco;

  @override
  void paint(Canvas canvas, Size size) {
    // O desenho foi feito para 680x58. A tela tem outra largura, então a faixa
    // e escalada pela ALTURA e repetida na horizontal quantas vezes couberem.
    // Escalar pela largura deformaria os prédios em telas largas.
    final escala = size.height / alturaDaFaixa;
    final larguraVisivel = size.width / escala;

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(escala);

    _pintarCeu(canvas, larguraVisivel);
    if (cenario.temSol) _pintarSol(canvas);

    // A camada de trás anda menos que a da frente no mesmo tempo, e é só isso
    // que produz profundidade. O olho lê diferença de velocidade como distância.
    _pintarCamada(
      canvas,
      larguraVisivel,
      caminho: predioLonge,
      deslocamentoY: predioLongeY,
      cor: cenario.longe,
      fracao: avanco,
    );
    _pintarCamada(
      canvas,
      larguraVisivel,
      caminho: predioPerto,
      deslocamentoY: predioPertoY,
      cor: cenario.perto,
      // A da frente completa mais voltas no mesmo ciclo do relógio.
      fracao: (avanco * segundosLonge / segundosPerto) % 1.0,
      neons: cenario.temNeon,
    );

    canvas.drawRect(
      Rect.fromLTWH(0, chaoY, larguraVisivel, chaoAltura),
      Paint()..color = cenario.chao,
    );

    _pintarGato(canvas, larguraVisivel);
    canvas.restore();
  }

  void _pintarCeu(Canvas canvas, double largura) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, largura, alturaDaFaixa),
      Paint()..color = cenario.ceu,
    );
  }

  /// O sol listrado da faixa de fim de tarde. Não desliza: está no infinito.
  void _pintarSol(Canvas canvas) {
    const centro = Offset(520, 34);
    canvas.drawCircle(centro, 32, Paint()..color = const Color(0xFFFF9E6B));
    final fatia = Paint()..color = cenario.ceu;
    for (final (y, altura) in [(22.0, 3.0), (31.0, 4.0), (42.0, 5.0)]) {
      canvas.drawRect(Rect.fromLTWH(484, y, 72, altura), fatia);
    }
  }

  /// Uma camada de prédios, repetida até cobrir a tela.
  void _pintarCamada(
    Canvas canvas,
    double largura, {
    required String caminho,
    required double deslocamentoY,
    required Color cor,
    required double fracao,
    bool neons = false,
  }) {
    // O cenario desliza para a DIREITA, que e o sentido oposto ao lado para
    // onde o gato aponta -- e ele aponta para a ESQUERDA: o olho, o focinho e
    // a boca estao todos naquele lado.
    //
    // Ate 11 de setembro de 2026 ele deslizava para a esquerda, e o comentario
    // aqui dizia, corretamente, que o cenario anda no sentido oposto ao que o
    // gato aponta. A regra estava certa; a leitura de para onde ele aponta e
    // que estava errada. O resultado e que o gato andava **de re**, e a cauda,
    // que sai pela direita, ficava na direcao do movimento -- ou seja, na
    // frente. O Gustavo viu jogando: "parece um terceiro braco".
    //
    // Espelhar o gato resolveria o movimento e quebraria o personagem: a
    // metade metalica fica a DIREITA na arte canonica, e a assimetria
    // pelo/metal e identidade. Entao quem vira e o cenario.
    //
    // O inicio e -larguraDaFaixa para a copia que entra pela esquerda ja estar
    // posicionada; sem isso sobraria um vao naquele lado a cada volta.
    final x = (fracao - 1) * larguraDaFaixa;

    // Quantas cópias cabem, mais uma para cobrir a que está saindo.
    final copias = (largura / larguraDaFaixa).ceil() + 2;
    final tinta = Paint()..color = cor;
    final predios = _caminho(caminho);

    for (var i = 0; i < copias; i++) {
      canvas.save();
      canvas.translate(x + i * larguraDaFaixa, deslocamentoY);
      canvas.drawPath(predios, tinta);
      if (neons) {
        for (final (area, corNeon) in neonsDaFaixa) {
          canvas.drawRect(
            area.translate(0, -deslocamentoY),
            Paint()..color = corNeon,
          );
        }
      }
      canvas.restore();
    }
  }

  /// O Tr∅nikAt, parado no lugar, movendo as pernas.
  void _pintarGato(Canvas canvas, double largura) {
    // Ele fica onde couber: em tela estreita, `gatoX` cairia fora.
    final x = min(gatoX, largura * 0.4);

    canvas.save();
    canvas.translate(x, gatoY);

    // Um passo completo dura `passoSegundos`, e o relógio dura `segundosLonge`.
    // O vaivém sai de um cosseno: 0 na ponta de trás, 1 na da frente, e volta.
    final passo = (avanco * segundosLonge / passoSegundos) % 1.0;
    final balanco = (1 - cos(passo * 2 * pi)) / 2;

    for (final forma in gato) {
      final tinta = Paint()..color = Color(forma.cor);
      switch (forma.tipo) {
        case TipoDeForma.oval:
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(forma.a, forma.b),
              width: forma.c * 2,
              height: forma.e * 2,
            ),
            tinta,
          );
        case TipoDeForma.disco:
          canvas.drawCircle(Offset(forma.a, forma.b), forma.c, tinta);
        case TipoDeForma.forma:
          canvas.drawPath(_caminho(forma.d!), tinta);
        case TipoDeForma.traco:
          canvas.drawPath(
            _caminho(forma.d!),
            tinta
              ..style = PaintingStyle.stroke
              ..strokeWidth = forma.largura
              ..strokeCap = StrokeCap.round,
          );
        case TipoDeForma.caixa:
          final area = Rect.fromLTWH(forma.a, forma.b, forma.c, forma.e);
          canvas.drawRRect(
            RRect.fromRectAndRadius(area, Radius.circular(forma.raio)),
            tinta,
          );
        case TipoDeForma.membro:
          // A ponta vai de `c` até `e` e volta, no ritmo do passo.
          final ponta = ui.lerpDouble(forma.c, forma.e, balanco)!;
          canvas.drawLine(
            Offset(forma.a, forma.b),
            Offset(ponta, forma.raio),
            tinta
              ..strokeWidth = forma.largura
              ..strokeCap = StrokeCap.round,
          );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PintorDaFaixa anterior) =>
      anterior.avanco != avanco || anterior.cenario != cenario;
}
