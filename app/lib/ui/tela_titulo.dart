import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'fundo_arcade.dart';
import 'paleta.dart';
import 'som.dart';

/// A tela de abertura, no formato de um fliperama: arte, logo e "Aperte START".
///
/// Ela existe por imersão, mas resolve um problema real de engenharia junto: o
/// app precisa abrir o banco de questões e o banco de progresso antes de mostrar
/// qualquer coisa, e antes desta tela esse tempo era uma roda de carregamento
/// num fundo vazio. Agora o mesmo tempo é ocupado por algo que o usuário quer
/// olhar. **A espera não diminuiu; ela deixou de ser uma espera.**
///
/// Duas decisões de comportamento que não são negociáveis:
///
/// - **O toque nunca é ignorado.** Se a carga ainda não terminou, a ficha toca
///   na mesma hora e a tela passa a dizer que está carregando. Botão que não
///   responde é lido como app travado, e o usuário toca de novo, mais forte.
/// - **Respeita "reduzir animações" do Android.** Com a opção ligada, a
///   respiração e o piscar param, e a tela continua inteira e funcional. É a
///   mesma regra do fundo em parallax, e vale porque movimento pulsante é
///   justamente o que incomoda quem liga essa opção.
class TelaTitulo extends StatefulWidget {
  const TelaTitulo({
    super.key,
    required this.pronto,
    required this.aoIniciar,
    this.sineta,
  });

  /// Se a carga do banco já terminou. Vem de fora porque quem carrega é o app,
  /// não a tela: a tela de título não deve saber o que é um banco de questões.
  final bool pronto;

  /// Chamado quando o START é aceito -- na hora, se já estava pronto, ou assim
  /// que a carga terminar, se o toque veio antes.
  final VoidCallback aoIniciar;

  final Sineta? sineta;

  @override
  State<TelaTitulo> createState() => _TelaTituloState();
}

class _TelaTituloState extends State<TelaTitulo>
    with SingleTickerProviderStateMixin {
  /// Um controlador só para os dois movimentos.
  ///
  /// A respiração é o ciclo inteiro; o piscar é uma subdivisão dele. Dois
  /// controladores dariam dois relógios acordando o mesmo quadro, que é
  /// exatamente o que a regra de performance do CLAUDE.md manda evitar.
  late final AnimationController _pulso = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  );

  /// Quantas piscadas cabem num ciclo de respiração. 3600 / 4 = 900ms por
  /// piscada, que é o compasso de fliperama: rápido o bastante para chamar,
  /// lento o bastante para não parecer defeito.
  static const int _piscadasPorCiclo = 4;

  /// Fração da piscada em que o texto fica aceso. Aceso mais tempo que apagado,
  /// senão a frase vira estroboscópio e fica difícil de ler.
  static const double _acesoAte = 0.62;

  /// O usuário já pediu START enquanto a carga ainda rodava.
  bool _pedido = false;

  bool _animar = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Lido aqui, e não no build: `disableAnimations` pode mudar com o usuário
    // mexendo nas configurações do sistema com o app aberto.
    final reduzir = MediaQuery.disableAnimationsOf(context);
    _animar = !reduzir;
    if (_animar) {
      if (!_pulso.isAnimating) _pulso.repeat();
    } else {
      _pulso.stop();
      _pulso.value = 0;
    }
  }

  @override
  void didUpdateWidget(TelaTitulo anterior) {
    super.didUpdateWidget(anterior);
    // A carga terminou depois de o usuário ter pedido START: entra agora.
    if (_pedido && widget.pronto && !anterior.pronto) {
      // Fora do quadro atual. Navegar durante um build é erro de framework, e
      // `didUpdateWidget` roda dentro do build do pai.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.aoIniciar();
      });
    }
  }

  @override
  void dispose() {
    _pulso.dispose();
    super.dispose();
  }

  void _toque() {
    // A ficha toca sempre, antes de qualquer decisão. Ela é a confirmação de
    // que o toque foi recebido, e isso é verdade mesmo quando ainda não dá
    // para entrar.
    widget.sineta?.ficha();

    if (widget.pronto) {
      widget.aoIniciar();
      return;
    }
    if (!_pedido) setState(() => _pedido = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Paleta.veu,
      body: GestureDetector(
        // A tela inteira é o botão. Alvo de toque do tamanho da tela é o
        // oposto do problema de acessibilidade que alvos pequenos criam.
        onTap: _toque,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const FundoArcade(),
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 18),
                  const _Logo(),
                  const SizedBox(height: 6),
                  Text(
                    'APRENDA A PROGRAMAR',
                    style: TextStyle(
                      color: Paleta.destaque.withValues(alpha: 0.75),
                      fontFamily: fonteMono,
                      fontSize: 12,
                      letterSpacing: 4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Expanded(child: _Mascote(pulso: _pulso, animar: _animar)),
                  _Chamada(
                    pulso: _pulso,
                    animar: _animar,
                    carregando: _pedido && !widget.pronto,
                  ),
                  const SizedBox(height: 26),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// O logo, com aberração cromática em ciano e magenta.
///
/// O deslocamento é escrito com três cópias do mesmo texto, e não com uma fonte
/// baixada: o CLAUDE.md proíbe depender de fonte cyberpunk externa, que quebra
/// no aparelho que não a tem. Aqui o efeito vem da composição, então funciona
/// com a monoespaçada de sistema, qualquer que seja ela.
class _Logo extends StatelessWidget {
  const _Logo();

  static const TextStyle _base = TextStyle(
    fontFamily: fonteMono,
    fontSize: 44,
    fontWeight: FontWeight.w800,
    letterSpacing: 2,
    height: 1.1,
  );

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Transform.translate(
          offset: const Offset(-3, -2),
          child: Text(
            'DevLingo',
            style: _base.copyWith(color: Paleta.destaque),
          ),
        ),
        Transform.translate(
          offset: const Offset(3, 2),
          child: Text('DevLingo', style: _base.copyWith(color: Paleta.acerto)),
        ),
        Text('DevLingo', style: _base.copyWith(color: Paleta.texto)),
      ],
    );
  }
}

/// O Tr∅nikAt em close, respirando.
class _Mascote extends StatelessWidget {
  const _Mascote({required this.pulso, required this.animar});

  final AnimationController pulso;
  final bool animar;

  /// Dois por cento. Respiração é quase imperceptível; se dá para ver a escala
  /// mudando, virou zoom, e zoom em loop embrulha o estômago.
  static const double _amplitude = 0.02;

  @override
  Widget build(BuildContext context) {
    final arte = SvgPicture.asset(
      'assets/mascot/tronikat-retrato.svg',
      key: const Key('titulo-mascote'),
      fit: BoxFit.contain,
      alignment: Alignment.bottomCenter,
    );

    if (!animar) return _comBrilho(arte);

    return AnimatedBuilder(
      animation: pulso,
      // `child` passa a arte pronta: o SVG é construído uma vez e só a
      // transformação é refeita a cada quadro.
      child: _comBrilho(arte),
      builder: (context, child) {
        final fase = sin(pulso.value * 2 * pi);
        return Transform.scale(
          scale: 1 + _amplitude * fase,
          // Ancorado embaixo: peito subindo e descendo. Escalar pelo centro
          // faria a cabeça e os ombros se afastarem, que não é respirar.
          alignment: Alignment.bottomCenter,
          child: child,
        );
      },
    );
  }

  /// Halo atrás do mascote, para ele não se perder na grade do fundo.
  Widget _comBrilho(Widget arte) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.15),
          radius: 0.62,
          colors: [
            Paleta.destaque.withValues(alpha: 0.20),
            Paleta.acerto.withValues(alpha: 0.10),
            Colors.transparent,
          ],
          stops: const [0, 0.55, 1],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: arte,
      ),
    );
  }
}

/// "Aperte START para iniciar", piscando no compasso do fliperama.
class _Chamada extends StatelessWidget {
  const _Chamada({
    required this.pulso,
    required this.animar,
    required this.carregando,
  });

  final AnimationController pulso;
  final bool animar;
  final bool carregando;

  @override
  Widget build(BuildContext context) {
    final texto = carregando
        ? const _Frase(
            key: Key('titulo-carregando'),
            texto: 'CARREGANDO...',
            cor: Paleta.telemetria,
          )
        : const _Frase(
            key: Key('titulo-start'),
            texto: 'Aperte START para iniciar',
            cor: Paleta.texto,
          );

    if (!animar) return texto;

    return AnimatedBuilder(
      animation: pulso,
      child: texto,
      builder: (context, child) {
        final dentroDaPiscada =
            (pulso.value * _TelaTituloState._piscadasPorCiclo) % 1.0;
        final aceso = dentroDaPiscada < _TelaTituloState._acesoAte;
        // Liga e desliga seco, sem transição. Fliperama de 32 bits não tinha
        // canal alfa para desvanecer; o corte é o que soa como a época.
        //
        // Opacity, e não Visibility: sumindo do layout, o que está em volta
        // pularia de lugar a cada 900ms.
        return Opacity(opacity: aceso ? 1 : 0, child: child);
      },
    );
  }
}

class _Frase extends StatelessWidget {
  const _Frase({super.key, required this.texto, required this.cor});

  final String texto;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: cor,
        fontFamily: fonteMono,
        fontSize: 17,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
        shadows: const [
          Shadow(color: Paleta.acerto, blurRadius: 14),
          Shadow(color: Paleta.veu, blurRadius: 4),
        ],
      ),
    );
  }
}
