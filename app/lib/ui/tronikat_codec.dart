/// O Tr∅nikAt em estilo codec, desenhado no app.
///
/// ## Por que existe uma SEGUNDA implementação do rosto
///
/// O desenho original é `site/codec.js`, um canvas 2D em JavaScript que o site
/// e o jogo do navegador compartilham. Ele não roda no Flutter.
///
/// **O Gustavo escolheu portá-lo**, em 22 de setembro de 2026, com as três
/// saídas na mesa e o custo declarado: WebView (zero duplicação, mas dependência
/// nova), retrato SVG nativo (leve, mas sem o codec), ou este porte. Fica
/// registrado que **é escolha, e não descuido** — a próxima sessão não deve
/// "corrigir" isto achando que alguém não percebeu a duplicação.
///
/// ## O que protege a identidade, já que o desenho é duplo
///
/// O risco real não é o código divergir: é **o personagem divergir**. Um gato
/// de olho âmbar é outro gato, e este repositório já pagou por isso.
///
/// Por isso as constantes de identidade — cores, a elipse da cabeça e os
/// ângulos das orelhas — ficam isoladas em [Codec], e um teste
/// (`codec_paridade_test.dart`) **lê `site/codec.js` e compara uma a uma**.
/// Mudar o verde do visor de um lado só reprova a suíte.
///
/// O que continua podendo divergir é o motor de desenho: a ordem das camadas,
/// a curva do ombro, o tamanho do bigode. Isso é o preço da escolha, e ele
/// está declarado aqui em vez de escondido.
///
/// ## Uma diferença assumida
///
/// O JavaScript sorteia uma fatia da imagem e a desloca com `putImageData`,
/// que lê os pixels já desenhados. O Flutter não dá esse acesso durante a
/// pintura sem custo real. Aqui a interferência é uma faixa clara deslocada
/// sobre o desenho — lê como transmissão do mesmo jeito, e não custa leitura
/// de pixel.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Os números que dizem QUEM ELE É.
///
/// Copiados de `site/codec.js`, e travados contra aquele arquivo por teste.
/// Mexer aqui sem mexer lá — ou o contrário — reprova.
class Codec {
  const Codec._();

  // O metal é ESCURO de propósito. Na primeira versão do retrato ele saiu
  // quase branco e o gato virou um gato branco comum. Com o pelo em #F4F2FA,
  // o aço precisa cair para a casa dos #8x para a divisa aparecer.
  static const pelo = Color(0xFFF4F2FA);
  static const peloSombra = Color(0xFFC9C3E0);
  static const metal = Color(0xFF7E8498);
  static const metalLuz = Color(0xFFA9AFC1);
  static const metalSombra = Color(0xFF575C6B);
  static const escuro = Color(0xFF17092E);
  static const ciano = Color(0xFF00E5FF);
  static const visor = Color(0xFF39FF14);
  static const rosa = Color(0xFFFF7ABF);
  static const rosaForte = Color(0xFFFF2D95);
  static const moletom = Color(0xFF321E63);

  /// O quadro do codec, em unidades de desenho.
  static const largura = 128.0;
  static const altura = 96.0;

  /// A elipse da cabeça, numa fonte só. As orelhas LEEM estes números para
  /// achar onde a superfície está; enquanto viviam soltos, a base da orelha
  /// era palpite — e palpite foi o que a deixou descolada.
  static const cx = 64.0, cy = 45.0, rx = 25.0, ry = 22.0;

  /// Os ângulos das orelhas, e eles são identidade.
  ///
  /// O CLAUDE.md mede 8,1° da vertical na arte canônica e registra que
  /// desenhar a olho já saiu a 36° — *"ficou parecendo outro bicho"*. E a
  /// direita **não é o espelho da esquerda**: é um pouco maior e mais
  /// inclinada nas duas artes canônicas.
  static const orelhaEsqA1 = -58.0, orelhaEsqA2 = -20.0;
  static const orelhaEsqAlt = 16.0, orelhaEsqInclina = -8.1;
  static const orelhaDirA1 = 20.0, orelhaDirA2 = 60.0;
  static const orelhaDirAlt = 17.0, orelhaDirInclina = 9.9;
}

/// O retrato, com a boca acompanhando a fala.
///
/// [abertura] vai de 0 a 1 e [arredondamento] fecha os cantos da boca, como no
/// site: "o" e "u" projetam o lábio — menos largura, mais altura.
///
/// [parado] desliga todo movimento, para respeitar "reduzir animações" do
/// sistema e para o estado offline.
class TronikatCodec extends StatefulWidget {
  const TronikatCodec({
    super.key,
    this.abertura = 0,
    this.arredondamento = 0,
    this.parado = false,
    this.largura = 168,
  });

  final double abertura;
  final double arredondamento;
  final bool parado;
  final double largura;

  @override
  State<TronikatCodec> createState() => _TronikatCodecState();
}

class _TronikatCodecState extends State<TronikatCodec>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  // A boca persegue o alvo em vez de saltar até ele, como no JavaScript: o
  // valor caminha 70% do que falta a cada quadro. Sem isso a boca pisca entre
  // fonemas em vez de articular.
  double _abertura = 0;
  double _arredonda = 0;

  @override
  void initState() {
    super.initState();
    // Um ciclo longo serve de relógio; os 12 quadros por segundo do codec
    // saem da própria taxa de repintura, que é o que o `Listenable` entrega.
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // "Reduzir animações" do sistema vale aqui como vale na faixa de cenário e
    // na tela de título.
    final reduzir = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final parado = widget.parado || reduzir;

    return RepaintBoundary(
      child: SizedBox(
        width: widget.largura,
        height: widget.largura * Codec.altura / Codec.largura,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            _abertura += (widget.abertura - _abertura) * .7;
            _arredonda += (widget.arredondamento - _arredonda) * .5;
            return CustomPaint(
              painter: _PintorDoCodec(
                t: _ctrl.value * 20,
                abertura: _abertura,
                arredonda: _arredonda,
                parado: parado,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PintorDoCodec extends CustomPainter {
  _PintorDoCodec({
    required this.t,
    required this.abertura,
    required this.arredonda,
    required this.parado,
  });

  final double t;
  final double abertura;
  final double arredonda;
  final bool parado;

  void _elipse(Canvas c, double x, double y, double rx, double ry, Color cor) {
    c.drawOval(
      Rect.fromCenter(center: Offset(x, y), width: rx * 2, height: ry * 2),
      Paint()..color = cor,
    );
  }

  /// Uma orelha.
  ///
  /// A BASE NÃO É UMA RETA, e essa correção custou uma rodada no site: a base
  /// reta ficava em y=30, mas a cabeça é curva, e o canto externo flutuava
  /// 3,2px acima dela. Aqui os dois cantos são pontos SOBRE a elipse da
  /// cabeça, dados por ângulo e afundados 7% em direção ao centro — assim a
  /// orelha nasce da cabeça em vez de pousar nela.
  void _orelha(Canvas c, double ang1, double ang2, double alt, double inclina,
      Color fora, Color dentro) {
    const afunda = .93;
    Offset naCabeca(double a) {
      final r = a * math.pi / 180;
      return Offset(
        Codec.cx + math.sin(r) * Codec.rx * afunda,
        Codec.cy - math.cos(r) * Codec.ry * afunda,
      );
    }

    final p1 = naCabeca(ang1), p2 = naCabeca(ang2);
    final m = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
    final rad = inclina * math.pi / 180;
    final apice = Offset(m.dx + math.sin(rad) * alt, m.dy - math.cos(rad) * alt);

    c.drawPath(
      Path()
        ..moveTo(p1.dx, p1.dy)
        ..lineTo(apice.dx, apice.dy)
        ..lineTo(p2.dx, p2.dy)
        ..close(),
      Paint()..color = fora,
    );
    // Rosa por dentro: está na arte canônica, e é o que impede a orelha de ler
    // como um triângulo chapado.
    c.drawPath(
      Path()
        ..moveTo(p1.dx + (m.dx - p1.dx) * .40, p1.dy + (m.dy - p1.dy) * .40)
        ..lineTo(m.dx + (apice.dx - m.dx) * .62, m.dy + (apice.dy - m.dy) * .62)
        ..lineTo(p2.dx + (m.dx - p2.dx) * .40, p2.dy + (m.dy - p2.dy) * .40)
        ..close(),
      Paint()..color = dentro,
    );
  }

  @override
  void paint(Canvas c, Size size) {
    c.scale(size.width / Codec.largura, size.height / Codec.altura);
    const l = Codec.largura, a = Codec.altura;

    // --- fundo da transmissão ---
    // Degradê VERTICAL, e não radial: o radial da primeira versão se fechava
    // em elipse e lia como um CHÃO embaixo do gato, um cenário que não existe.
    c.drawRect(
      const Rect.fromLTWH(0, 0, l, a),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0B0520), Color(0xFF040109)],
        ).createShader(const Rect.fromLTWH(0, 0, l, a)),
    );
    c.drawRect(
      const Rect.fromLTWH(0, 14, l, 58),
      Paint()..color = Codec.visor.withValues(alpha: .05),
    );

    final bx = parado ? 0.0 : math.sin(t * .62).roundToDouble();
    final by = parado ? 0.0 : math.sin(t * 1.05).roundToDouble();

    c.save();
    // O busto inteiro sobe 5px: sem isso o painel `>_` do peito encostava na
    // borda de baixo e saía cortado ao meio.
    c.translate(bx, by - 5);

    // --- ombros e moletom, SANGRANDO pelas bordas ---
    // Enquadramento que cabe inteiro no quadro lê como bonequinho, e não como
    // close. Então os ombros saem da tela.
    c.drawPath(
      Path()
        ..moveTo(-14, a + 6)
        ..lineTo(-14, 88)
        ..quadraticBezierTo(20, 79, 42, 77) // ombro tem quina; o moletom suaviza
        ..lineTo(86, 77)
        ..quadraticBezierTo(108, 79, 142, 88)
        ..lineTo(142, a + 6)
        ..close(),
      Paint()..color = Codec.moletom,
    );

    // pescoço: ALARGA para baixo, senão vira balde
    c.drawPath(
      Path()
        ..moveTo(57, 62)
        ..lineTo(71, 62)
        ..lineTo(76, 79)
        ..lineTo(52, 79)
        ..close(),
      Paint()..color = Codec.peloSombra,
    );

    // --- painel `>_` no peito ---
    c.drawRect(const Rect.fromLTWH(53, 84, 24, 12),
        Paint()..color = const Color(0xFF0A2607));
    c.drawRect(
      const Rect.fromLTWH(53.5, 84.5, 23, 11),
      Paint()
        ..color = Codec.visor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final tp = TextPainter(
      text: const TextSpan(
        text: '>_',
        style: TextStyle(color: Codec.visor, fontSize: 8, fontFamily: 'monospace'),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, const Offset(57, 85));

    // --- orelhas, ANTES da cabeça para nascerem atrás dela ---
    // Uma treme de vez em quando. É o tipo de movimento que o codec tem:
    // pouco, e sem avisar. O tremor entra na INCLINAÇÃO, e não na posição: a
    // orelha gira em torno da própria base, que continua presa na cabeça.
    final treme = !parado && (t % 7.3) > 7.05 ? 2.5 : 0.0;
    _orelha(c, Codec.orelhaEsqA1, Codec.orelhaEsqA2, Codec.orelhaEsqAlt,
        Codec.orelhaEsqInclina - treme, Codec.pelo, Codec.rosa);
    _orelha(c, Codec.orelhaDirA1, Codec.orelhaDirA2, Codec.orelhaDirAlt,
        Codec.orelhaDirInclina + treme, Codec.metal, Codec.metalSombra);

    // --- cabeça: ~12% mais larga que alta, como a referência (rx52/ry46) ---
    _elipse(c, Codec.cx, Codec.cy, Codec.rx, Codec.ry, Codec.pelo);

    // metade metálica: RECORTE no meio, e não uma segunda elipse por cima,
    // senão a emenda vira um degrau visível depois da ampliação.
    c.save();
    c.clipRect(const Rect.fromLTWH(64, 0, l - 64, a));
    _elipse(c, Codec.cx, Codec.cy, Codec.rx, Codec.ry, Codec.metal);
    c.save();
    c.clipPath(Path()
      ..addOval(Rect.fromCenter(
          center: const Offset(Codec.cx, Codec.cy),
          width: Codec.rx * 2,
          height: Codec.ry * 2)));
    // Volume por tons CHAPADOS, nunca gradiente: é a regra que o CLAUDE.md
    // tirou de um gradiente que o flutter_svg simplesmente não aplicou.
    c.drawRect(const Rect.fromLTWH(64, 27, 9, 40), Paint()..color = Codec.metalLuz);
    c.drawRect(const Rect.fromLTWH(82, 32, 8, 30), Paint()..color = Codec.metalSombra);
    c.restore();
    c.restore();

    // --- a costura ciano da divisa ---
    c.drawLine(
      const Offset(64, 24),
      const Offset(64, 67),
      Paint()
        ..color = Codec.ciano
        ..strokeWidth = 1,
    );

    // --- bigodes: saem das BOCHECHAS para fora, sem atravessar o rosto ---
    // Finos e curtos. Na primeira versão eram retas longas e grossas, e o gato
    // ficou com cara de antena.
    final pincelBigode = Paint()
      ..color = const Color(0xFFF2F0FF).withValues(alpha: .55)
      ..strokeWidth = .7;
    for (final b in const [
      [45.0, 51.0, 33.0, 48.0],
      [45.0, 54.0, 32.0, 55.0],
      [83.0, 51.0, 95.0, 48.0],
      [83.0, 54.0, 96.0, 55.0],
    ]) {
      c.drawLine(Offset(b[0], b[1]), Offset(b[2], b[3]), pincelBigode);
    }

    // --- olho, no lado do PELO, que é a esquerda ---
    // Preto, redondo, com um brilho branco em cima. Foi aqui que eu já
    // inventei um olho âmbar de pupila em fenda, e o Gustavo pegou na hora:
    // "um gato de olho âmbar é outro gato".
    final piscando = !parado && (t % 4.9) > 4.76;
    if (piscando) {
      c.drawLine(
        const Offset(48, 44),
        const Offset(58, 44),
        Paint()
          ..color = Codec.escuro
          ..strokeWidth = 2,
      );
    } else {
      _elipse(c, 53, 43, 5, 5.8, Codec.escuro);
      _elipse(c, 54.6, 40.8, 1.7, 1.7, const Color(0xFFFFFFFF));
    }

    // --- visor, no lado do METAL ---
    c.drawRect(const Rect.fromLTWH(69, 37, 20, 11),
        Paint()..color = const Color(0xFF23283A));
    c.drawRect(const Rect.fromLTWH(70, 38, 18, 9), Paint()..color = Codec.visor);
    // A varredura: uma linha clara que desce. É o único movimento que o
    // personagem tem enquanto está calado.
    if (!parado) {
      final linha = 38 + ((t * 9) % 12).floorToDouble();
      if (linha < 47) {
        c.drawRect(Rect.fromLTWH(70, linha, 18, 1),
            Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: .5));
      }
    }
    c.drawRect(const Rect.fromLTWH(70, 38, 18, 2),
        Paint()..color = const Color(0xFF000000).withValues(alpha: .28));

    // --- focinho rosa ---
    c.drawPath(
      Path()
        ..moveTo(61, 53)
        ..lineTo(67, 53)
        ..lineTo(64, 56.5)
        ..close(),
      Paint()..color = Codec.rosaForte,
    );

    // --- boca: é ela que carrega a fala ---
    // "o" e "u" fecham os cantos e projetam o lábio: menos largura, mais
    // altura.
    final ab = math.max(0.0, abertura);
    final larg = 11 * (1 - arredonda * .34);
    final alt = 1.3 + ab * 7;
    _elipse(c, 64, 60 + alt * .3, larg / 2, alt / 2 + .6, Codec.escuro);
    if (ab > .3) {
      _elipse(c, 64, 61 + alt * .34, larg / 3.6, alt / 3.8, const Color(0xFF8E2A5E));
    }

    c.restore();

    // --- interferência: uma fatia deslocada, um quadro a cada tanto ---
    // É o que faz a imagem parecer TRANSMITIDA, e não desenhada.
    //
    // DIFERENTE DO JAVASCRIPT, e de propósito: lá a fatia é recortada dos
    // pixels já pintados (`putImageData`), e o Flutter não dá esse acesso
    // durante a pintura sem custo real. Aqui é uma faixa clara deslocada, que
    // lê como transmissão do mesmo jeito.
    if (!parado && (t * 12).floor() % 37 == 0) {
      final y = ((t * 53) % (a - 12)).floorToDouble();
      final h = 3 + ((t * 31) % 6).floorToDouble();
      c.drawRect(
        Rect.fromLTWH((t * 17) % 2 < 1 ? -2 : 2, y, l, h),
        Paint()..color = Codec.ciano.withValues(alpha: .10),
      );
    }
  }

  @override
  bool shouldRepaint(_PintorDoCodec o) =>
      o.t != t || o.abertura != abertura || o.arredonda != arredonda || o.parado != parado;
}
