import 'dart:math';

import 'package:flutter/material.dart';

import 'paleta.dart';

/// A cena animada do topo da tela de entrada.
///
/// Em primeiro plano o Tr∅nikAt programando; ao fundo, **o mesmo** Tr∅nikAt
/// rodopiando em meio a um rastro de arco-íris.
///
/// ## Por que o mascote, e não o Nyan Cat
///
/// A ideia original era o Nyan Cat. Ele **não é meme de domínio público**: é
/// obra de 2011 de Christopher Torres, registrada e licenciada comercialmente.
/// Reproduzi-lo num app que é portfólio público, e candidato à loja, é risco
/// real.
///
/// O que produz o efeito, porém, não é protegido — gato voando, rastro de
/// arco-íris, estrelas passando. Protegido é aquele desenho específico. Então a
/// cena usa o **nosso** mascote, o que além de seguro é melhor: reforça a
/// identidade do projeto em vez de emprestar a de outro.
///
/// ## Um desenho só, dois gatos
///
/// [_tronikat] desenha o personagem inteiro, e os dois gatos da cena chamam a
/// mesma função. Isso não é economia de código: é o que **garante** que eles
/// sejam o mesmo personagem. A primeira versão tinha dois desenhos separados, e
/// o voador saiu sem olho, sem focinho, sem bigode e sem a divisa entre a
/// metade viva e a metálica — parecia outro bicho.
///
/// É a mesma regra já registrada no CLAUDE.md: traço de identidade se copia da
/// fonte da verdade, nunca se reinventa. Aqui a cópia é forçada pela estrutura.
///
/// ## O psicodélico fica DENTRO da cena
///
/// A rotação de matiz e o rastro vivem neste painel, e não na tela inteira.
/// Fundo mudando de cor atrás de campo de senha prejudica a leitura justamente
/// de quem está digitando — e esta é a porta do app, com login obrigatório.
class CenaDoLogin extends StatefulWidget {
  const CenaDoLogin({super.key, this.atenuada = false});

  /// Para o movimento sem tirar a cena da tela.
  ///
  /// Ligado quando o teclado abre. Sumir com ela faria o formulário saltar no
  /// meio da digitação, que é pior que o movimento.
  final bool atenuada;

  /// Altura do painel, e também a unidade do desenho: tudo é escalado por ela.
  ///
  /// Não há largura fixa de propósito. A cena se estica na horizontal e os
  /// elementos se ancoram sozinhos — a mesa acompanha a borda, o gato voador
  /// atravessa a largura que houver.
  static const double altura = 150;

  @override
  State<CenaDoLogin> createState() => _CenaDoLoginState();
}

class _CenaDoLoginState extends State<CenaDoLogin>
    with SingleTickerProviderStateMixin {
  /// Um relógio só, e ele mede o ciclo mais longo: a travessia do gato voador.
  ///
  /// O piscar do cursor, o bater das patas, a pirueta e a rotação de matiz saem
  /// deste mesmo valor por multiplicação. Vários controladores sairiam de
  /// sincronia ao longo dos minutos, e é a regra de performance registrada.
  late final AnimationController _relogio = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 7000),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ajustar();
  }

  @override
  void didUpdateWidget(CenaDoLogin anterior) {
    super.didUpdateWidget(anterior);
    _ajustar();
  }

  void _ajustar() {
    final animar = !widget.atenuada && !MediaQuery.disableAnimationsOf(context);
    if (animar) {
      if (!_relogio.isAnimating) _relogio.repeat();
    } else {
      _relogio.stop();
    }
  }

  @override
  void dispose() {
    _relogio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        height: CenaDoLogin.altura,
        width: double.infinity,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Escala.raio),
          child: AnimatedBuilder(
            animation: _relogio,
            builder: (_, _) =>
                CustomPaint(painter: _PintorDaCena(avanco: _relogio.value)),
          ),
        ),
      ),
    );
  }
}

/// Em que pose o Tr∅nikAt está.
///
/// A pose muda quais membros aparecem. Na primeira versão o voador simplesmente
/// **não tinha braço nem perna** — o desenho só sabia fazer braços indo ao
/// teclado, e o gato do arco-íris saiu como um tronco girando.
enum _Pose {
  /// Sentado ao computador: dois braços indo ao teclado, pernas escondidas
  /// atrás da mesa.
  digitando,

  /// Rodopiando no ar: braços e pernas esticados para fora, como quem gira.
  girando,
}

// --------------------------------------------------------------- cores
//
// As mesmas de `tronikat.svg` e de `tools/gerar_faixas.py`. Estao nomeadas
// aqui porque o personagem e desenhado a mao neste arquivo; se divergirem
// daquelas, e este arquivo que esta errado.

const Color _pelo = Color(0xFFF2F0FF);
const Color _metal = Color(0xFFC9CBE0);
const Color _metalEscuro = Color(0xFF7E8299);
const Color _escuro = Color(0xFF17092E);
/// As juntas da metade metalica, como as dos bracos na arte canonica.
const Color _junta = Color(0xFF8A8FA6);

/// A moldura do arco-iris, que antes emprestava a cor do moletom.
const Color _molduraDoRastro = Color(0xFF7E5FC0);
const Color _visorMoldura = Color(0xFF3A3E52);
const Color _rosaClaro = Color(0xFFFF7AD9);
const Color _focinho = Color(0xFFFF4FD8);

class _PintorDaCena extends CustomPainter {
  const _PintorDaCena({required this.avanco});

  /// Volta de 0 a 1 a cada travessia do gato voador.
  final double avanco;

  /// As seis faixas do rastro. Ordem fixa: arco-íris fora de ordem não lê como
  /// arco-íris, lê como listra colorida qualquer.
  static const List<Color> _arcoIris = [
    Color(0xFFFF2D55),
    Color(0xFFFF9500),
    Color(0xFFFFE14D),
    Color(0xFF39FF14),
    Color(0xFF00E5FF),
    Color(0xFFBF5AF2),
  ];

  static const double _alturaFaixa = 5.0;

  @override
  void paint(Canvas canvas, Size size) {
    final escala = size.height / CenaDoLogin.altura;
    final larguraVisivel = size.width / escala;

    canvas.save();
    canvas.scale(escala);

    _pintarFundo(canvas, larguraVisivel);
    _pintarEstrelas(canvas, larguraVisivel);
    _pintarVoador(canvas, larguraVisivel);
    _pintarMesaEComputador(canvas, larguraVisivel);

    canvas.restore();
  }

  /// Fundo com matiz girando devagar. É o "psicodélico", contido no painel.
  void _pintarFundo(Canvas canvas, double largura) {
    final area = Rect.fromLTWH(0, 0, largura, CenaDoLogin.altura);
    final matiz = (avanco * 360) % 360;
    final topo = HSVColor.fromAHSV(1, matiz, 0.55, 0.22).toColor();
    final base = HSVColor.fromAHSV(1, (matiz + 60) % 360, 0.70, 0.10).toColor();

    canvas.drawRect(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [topo, base],
        ).createShader(area),
    );

    final linha = Paint()
      ..color = Paleta.destaque.withValues(alpha: 0.12)
      ..strokeWidth = 1;
    for (var y = 118.0; y < CenaDoLogin.altura; y += 8) {
      canvas.drawLine(Offset(0, y), Offset(largura, y), linha);
    }
  }

  /// Estrelas em três profundidades, com velocidades diferentes.
  void _pintarEstrelas(Canvas canvas, double largura) {
    final tinta = Paint();
    for (var camada = 0; camada < 3; camada++) {
      final sorteio = Random(11 + camada);
      final velocidade = 1.0 + camada * 1.6;
      final raio = 0.8 + camada * 0.5;
      final opacidade = 0.25 + camada * 0.2;

      for (var i = 0; i < 14; i++) {
        final base = sorteio.nextDouble() * largura;
        final y = sorteio.nextDouble() * 105;
        final x = (base - avanco * largura * velocidade) % largura;
        canvas.drawCircle(
          Offset(x, y),
          raio,
          tinta..color = Paleta.texto.withValues(alpha: opacidade),
        );
      }
    }
  }

  /// O Tr∅nikAt rodopiando **em meio** ao arco-íris.
  ///
  /// Ele fica dentro do fluxo, e não na frente dele: o rastro é desenhado
  /// atrás, ele por cima, e depois as faixas voltam com transparência sobre o
  /// corpo. Sem essa terceira passada ele parecia um adesivo colado na frente
  /// da fita, em vez de estar viajando dentro dela.
  void _pintarVoador(Canvas canvas, double largura) {
    final x = -30 + avanco * (largura + 60);
    final y = 34 + sin(avanco * 2 * pi * 2) * 8;

    final topoRastro = y - (_arcoIris.length * _alturaFaixa) / 2;

    void faixas(double opacidade, double ate) {
      for (var i = 0; i < _arcoIris.length; i++) {
        final area = Rect.fromLTWH(
          -30,
          topoRastro + i * _alturaFaixa,
          ate + 30,
          _alturaFaixa,
        );
        if (area.width <= 0) continue;
        canvas.drawRect(
          area,
          Paint()..color = _arcoIris[i].withValues(alpha: opacidade),
        );
      }
    }

    // 1. O rastro inteiro, atras dele.
    faixas(0.9, x);

    // 2. O gato, rodando.
    canvas.save();
    canvas.translate(x, y);
    // Tres voltas por travessia: uma pirueta lenta o bastante para o rosto ser
    // reconhecido no caminho. Mais rapido que isso vira borrao.
    canvas.rotate(avanco * 2 * pi * 3);
    canvas.scale(0.42);
    _tronikat(canvas, tonto: true, pose: _Pose.girando);
    canvas.restore();

    // 3. As faixas de novo, transparentes, POR CIMA -- e o que o poe dentro
    //    do fluxo de cor em vez de na frente dele.
    faixas(0.28, x);
  }

  /// A cena de primeiro plano: mesa, computador e o Tr∅nikAt programando.
  void _pintarMesaEComputador(Canvas canvas, double largura) {
    final centro = largura / 2;

    canvas.save();
    canvas.translate(centro - 160, 0);

    // --- mesa ---
    canvas.drawRect(
      const Rect.fromLTWH(30, 117, 270, 3),
      Paint()..color = _molduraDoRastro,
    );
    canvas.drawRect(
      const Rect.fromLTWH(30, 120, 270, 8),
      Paint()..color = const Color(0xFF3D2A66),
    );
    canvas.drawRect(
      const Rect.fromLTWH(30, 128, 270, 22),
      Paint()..color = const Color(0xFF1B1235),
    );

    // --- monitor ---
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(200, 48, 90, 60),
        const Radius.circular(5),
      ),
      Paint()..color = _visorMoldura,
    );
    canvas.drawRect(
      const Rect.fromLTWH(238, 108, 12, 7),
      Paint()..color = _visorMoldura,
    );
    canvas.drawRect(
      const Rect.fromLTWH(226, 115, 36, 3),
      Paint()..color = const Color(0xFF5C6178),
    );

    // --- tela, com codigo rolando ---
    const tela = Rect.fromLTWH(206, 54, 78, 48);
    canvas.drawRect(tela, Paint()..color = const Color(0xFF0A1F06));
    canvas.save();
    canvas.clipRect(tela);

    const larguras = [44.0, 28.0, 52.0, 20.0, 38.0, 32.0, 48.0, 24.0];
    const alturaLinha = 4.0;
    const espaco = 8.0;
    final ciclo = larguras.length * espaco;
    final deslocamento = (avanco * 4 * ciclo) % ciclo;
    for (var i = 0; i < larguras.length * 2; i++) {
      final y = tela.top + 4 + i * espaco - deslocamento;
      if (y < tela.top || y > tela.bottom - alturaLinha) continue;
      final indentado = i % 3 == 1;
      canvas.drawRect(
        Rect.fromLTWH(
          tela.left + 4 + (indentado ? 8 : 0),
          y,
          larguras[i % larguras.length],
          alturaLinha,
        ),
        Paint()..color = Paleta.visor.withValues(alpha: 0.55),
      );
    }

    // Cursor piscando. Liga e desliga seco: terminal nao desvanece.
    if ((avanco * 8) % 1 < 0.5) {
      canvas.drawRect(
        Rect.fromLTWH(tela.left + 4, tela.bottom - 10, 6, alturaLinha),
        Paint()..color = Paleta.visor,
      );
    }
    canvas.restore();

    // Brilho do monitor batendo na mesa.
    canvas.drawRect(
      const Rect.fromLTWH(200, 112, 90, 5),
      Paint()..color = Paleta.visor.withValues(alpha: 0.16),
    );

    // --- teclado ---
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(152, 111, 44, 7),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFF5C6178),
    );

    // --- o Tr0nikAt, o MESMO desenho do voador ---
    canvas.save();
    // O corpo termina em +39, e a mesa esta em 117: 78 + 39 = 117.
    canvas.translate(118, 78);
    _tronikat(
      canvas,
      tonto: false,
      // Quatro batidas por ciclo: o compasso de quem digita.
      batida: sin(avanco * 2 * pi * 4),
      pose: _Pose.digitando,
    );
    canvas.restore();

    canvas.restore();
  }

  /// Desenha o Tr∅nikAt inteiro, com a origem no centro da cabeça.
  ///
  /// Cabeça de raio 15, corpo descendo até +55. Escale o canvas para mudar o
  /// tamanho; **não** mexa nestas medidas para isso, senão os dois gatos da
  /// cena deixam de ser o mesmo.
  ///
  /// Fidelidade à arte canônica, item por item:
  ///
  /// - orelhas quase retas, a **6 graus** da vertical. Orelha inclinada lê como
  ///   outro bicho, e isso já custou uma correção no retrato
  /// - metade esquerda de pelo, metade direita metálica, com a costura ciano
  ///   entre elas descendo pela cabeça e pelo corpo
  /// - olho preto redondo com brilho branco, do lado vivo
  /// - visor verde do lado metálico
  /// - focinho rosa, boca e bigodes dos dois lados
  /// - **cauda com a luz verde na ponta** — está em `tronikat.svg` e em
  ///   `gerar_faixas.py`, e faltava aqui
  void _tronikat(
    Canvas canvas, {
    required bool tonto,
    double batida = 0,
    _Pose pose = _Pose.digitando,
  }) {
    final traco = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // --- cauda, atras de tudo, com a luzinha verde na ponta ---
    //
    // Na arte de corpo inteiro ela sai pela direita. Aqui sai pela esquerda
    // porque o computador ocupa a direita; e o mesmo desenho espelhado.
    //
    // Ela subia ate y=20, que e a altura do ROSTO, e a luz verde na ponta
    // ficava ao lado da cabeca -- lia como um braco erguido segurando uma
    // bolinha, e o Gustavo apontou o mesmo efeito na faixa dos exercicios.
    // Agora ela sai da base e desce, que e o que nao pode ser confundido com
    // braco nenhum.
    canvas.drawPath(
      Path()
        ..moveTo(-12, 36)
        ..quadraticBezierTo(-26, 37, -29, 43 + batida * 2),
      traco
        ..color = _metal
        ..strokeWidth = 3.2,
    );
    canvas.drawCircle(
      Offset(-29.5, 45.5 + batida * 2),
      2.8,
      Paint()..color = Paleta.visor,
    );

    // --- membros do lado metalico, antes do corpo ---
    //
    // O lado direito do personagem e o metalico, e ele fica atras no
    // enquadramento: por isso vem antes. Ordem de desenho e o que da
    // profundidade num desenho chapado.
    void membro(Offset de, Offset ate, Color cor) {
      canvas.drawLine(
        de,
        ate,
        traco
          ..color = cor
          ..strokeWidth = 4,
      );
      // Patinha na ponta, como na arte de corpo inteiro.
      canvas.drawCircle(ate, 2.6, Paint()..color = cor);
    }

    switch (pose) {
      case _Pose.digitando:
        membro(const Offset(6, 19), Offset(36, 34 - batida * 2), _metal);
      case _Pose.girando:
        membro(const Offset(10, 16), const Offset(27, 7), _metal);
        membro(const Offset(9, 37), const Offset(22, 52), _metal);
    }

    // --- orelhas, atras da cabeca ---
    void orelha(List<Offset> fora, List<Offset> dentro, Color a, Color b) {
      Path emPath(List<Offset> p) => Path()
        ..moveTo(p[0].dx, p[0].dy)
        ..lineTo(p[1].dx, p[1].dy)
        ..lineTo(p[2].dx, p[2].dy)
        ..close();
      canvas.drawPath(emPath(fora), Paint()..color = a);
      canvas.drawPath(emPath(dentro), Paint()..color = b);
    }

    // Base e apice medidos: 6,1 graus da vertical, dos dois lados.
    orelha(
      const [Offset(-12.5, -9), Offset(-8.5, -23), Offset(-2, -13.5)],
      const [Offset(-10.5, -11), Offset(-8.6, -19.5), Offset(-5, -13.5)],
      _pelo,
      _rosaClaro,
    );
    orelha(
      const [Offset(2, -13.5), Offset(8.5, -23), Offset(12.5, -9)],
      const [Offset(5, -13.5), Offset(8.6, -19.5), Offset(10.5, -11)],
      _metal,
      _metalEscuro,
    );

    // --- corpo ---
    // Medidas tiradas de `tronikat.svg`, e nao do olho:
    //   corpo topo   = 0,73 da largura da cabeca
    //   corpo base   = 0,85 da largura da cabeca
    //   corpo altura = 0,88 da largura da cabeca
    // A primeira versao acertou as larguras e errou a ALTURA em 63% -- 1,43 em
    // vez de 0,88 -- e o corpo virou um tubo. O Gustavo leu isso como "gordo
    // demais"; medindo, era comprido demais.
    final corpo = Path()
      ..moveTo(-11, 12)
      ..lineTo(11, 12)
      ..lineTo(12.7, 39)
      ..lineTo(-12.7, 39)
      ..close();
    // O corpo e o proprio personagem: pelo de um lado, metal do outro, com a
    // MESMA divisa da cabeca. A assimetria pelo/metal e identidade, e o
    // CLAUDE.md a lista ao lado do olho e do visor.
    //
    // Ate 11 de setembro de 2026 havia aqui um moletom roxo com gola rosa. O
    // Gustavo pediu para tira-lo -- "esta estranha a roupa dele, e se ele
    // tiver so o corpo branco meio robotizado?" -- e ele tinha razao por um
    // motivo que so aparece comparando com a arte canonica: a roupa cobria a
    // divisa, que e justamente o que conta a historia do personagem. Debaixo
    // dela ele era um gato de camiseta.
    canvas.drawPath(corpo, Paint()..color = _pelo);
    canvas.drawPath(
      Path()
        ..moveTo(0, 12)
        ..lineTo(11, 12)
        ..lineTo(12.7, 39)
        ..lineTo(0, 39)
        ..close(),
      Paint()..color = _metal,
    );
    // Duas juntas na metade metalica, como as dos bracos na arte canonica.
    for (final y in const [22.0, 31.0]) {
      canvas.drawCircle(Offset(6.5, y), 1.6, Paint()..color = _junta);
    }
    // Remendo de terminal no peito.
    const remendo = Rect.fromLTWH(-5.5, 21, 11, 7);
    canvas.drawRRect(
      RRect.fromRectAndRadius(remendo, const Radius.circular(1.5)),
      Paint()..color = const Color(0xFF170A31),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(remendo, const Radius.circular(1.5)),
      traco
        ..color = Paleta.visor
        ..strokeWidth = 1,
    );
    canvas.drawLine(
      const Offset(-3.5, 25.5),
      const Offset(-1, 25.5),
      traco
        ..color = Paleta.visor
        ..strokeWidth = 1.2,
    );

    // --- cabeca ---
    canvas.drawCircle(Offset.zero, 15, Paint()..color = _pelo);
    // Metade metalica, em Bezier. Arco eliptico aqui e caso-limite: a corda
    // entre os polos bate com o diametro, e ja custou depuracao no retrato.
    canvas.drawPath(
      Path()
        ..moveTo(0, -15)
        ..cubicTo(8.28, -15, 15, -8.28, 15, 0)
        ..cubicTo(15, 8.28, 8.28, 15, 0, 15)
        ..close(),
      Paint()..color = _metal,
    );
    // Costura ciano, a divisa entre o gato e a maquina.
    canvas.drawLine(
      const Offset(0, -15),
      const Offset(0, 15),
      traco
        ..color = Paleta.destaque
        ..strokeWidth = 1.6,
    );
    canvas.drawLine(
      const Offset(0, 14),
      const Offset(0, 39),
      traco
        ..color = Paleta.destaque.withValues(alpha: 0.4)
        ..strokeWidth = 1,
    );

    // --- bigodes, dos dois lados ---
    void bigodes(double sinal, Color cor) {
      canvas.drawLine(
        Offset(11 * sinal, 1),
        Offset(22 * sinal, -1),
        traco
          ..color = cor
          ..strokeWidth = 1.2,
      );
      canvas.drawLine(
        Offset(11.5 * sinal, 3.5),
        Offset(23 * sinal, 3.5),
        traco..color = cor,
      );
      canvas.drawLine(
        Offset(11 * sinal, 6),
        Offset(22 * sinal, 8),
        traco..color = cor,
      );
    }

    bigodes(-1, _pelo);
    bigodes(1, _metal);

    // --- olho vivo, do lado do pelo ---
    if (tonto) {
      // Cara de tonto: o olho vira um anel, o classico @ de quem rodopiou.
      canvas.drawCircle(const Offset(-7, -1.5), 4.4, Paint()..color = _escuro);
      canvas.drawCircle(const Offset(-7, -1.5), 2.7, Paint()..color = _pelo);
      canvas.drawCircle(const Offset(-7, -1.5), 1.1, Paint()..color = _escuro);
    } else {
      canvas.drawOval(
        Rect.fromCenter(
          center: const Offset(-7, -1.5),
          width: 7.2,
          height: 8.4,
        ),
        Paint()..color = _escuro,
      );
      canvas.drawCircle(
        const Offset(-8.4, -3.4),
        1.5,
        Paint()..color = const Color(0xFFFFFFFF),
      );
    }

    // --- visor, do lado metalico ---
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(1.5, -6, 14.5, 8),
        const Radius.circular(2),
      ),
      Paint()..color = _visorMoldura,
    );
    canvas.drawRect(
      const Rect.fromLTWH(3, -4.5, 11.5, 5),
      Paint()..color = Paleta.visor.withValues(alpha: tonto ? 0.55 : 0.9),
    );
    if (tonto) {
      // A tela do visor tambem rodopia: dois aneis escuros sobre o verde.
      for (final cx in [6.0, 11.5]) {
        canvas.drawCircle(
          Offset(cx, -2),
          1.9,
          traco
            ..color = const Color(0xFF0A1F06)
            ..strokeWidth = 1.1,
        );
      }
    }

    // --- focinho e boca ---
    canvas.drawPath(
      Path()
        ..moveTo(-2.6, 3.5)
        ..lineTo(2.6, 3.5)
        ..lineTo(0, 6.5)
        ..close(),
      Paint()..color = _focinho,
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, 6.5)
        ..quadraticBezierTo(-3, 9.6, -6, 7)
        ..moveTo(0, 6.5)
        ..quadraticBezierTo(3, 9.6, 6, 7),
      traco
        ..color = _escuro
        ..strokeWidth = 1.3,
    );

    // --- membros do lado vivo, por ultimo: ficam na frente ---
    switch (pose) {
      case _Pose.digitando:
        membro(const Offset(9, 23), Offset(30, 34 + batida * 2), _pelo);
      case _Pose.girando:
        membro(const Offset(-10, 16), const Offset(-27, 7), _pelo);
        membro(const Offset(-9, 37), const Offset(-22, 52), _pelo);
    }
  }

  @override
  bool shouldRepaint(_PintorDaCena anterior) => anterior.avanco != avanco;
}
