/// O balão de três pontinhos que anuncia a IA, no app.
///
/// Pedido do Gustavo em 23 de setembro de 2026, depois de instalar a v1.10.0:
/// *"o ícone da IA do Tr∅nikAt no app não está com os três pontinhos em
/// movimento"*. Ele existia só no navegador, e a razão de existir é a mesma
/// nos dois lugares.
///
/// **O problema é descoberta.** O botão é um gato de 52px num canto, e nada
/// nele diz "converse comigo" — num app que é portfólio, recurso que ninguém
/// descobre é igual a recurso que não existe. Foi exatamente isso que já
/// aconteceu uma vez, quando o botão nasceu na barra de cima e ele relatou
/// *"não apareceu o popup do Tr∅nikAt no app"*.
///
/// ## Três decisões copiadas do navegador, e o motivo de cada uma
///
/// - **Os pontinhos saltam em tempos diferentes** (0, 160 e 320 ms). É o
///   atraso escalonado que faz aquilo ler como *digitando*; juntos, seriam
///   três luzes piscando
/// - **Some ao primeiro toque, e não volta ao fechar a janela.** Quem já sabe
///   que ele existe não precisa de um balão pulsando para sempre — aviso que
///   não para de avisar vira ruído
/// - **Volta na abertura seguinte**, porque o estado não é guardado: quem
///   abre o app de novo é, para efeito de descoberta, alguém chegando
library;

import 'package:flutter/material.dart';

import 'paleta.dart';

/// Quanto dura uma volta dos pontinhos.
const _ciclo = Duration(milliseconds: 1100);

/// O atraso de cada pontinho dentro do ciclo, como fração dele.
///
/// 160 ms e 320 ms sobre 1100 — os mesmos do navegador, convertidos. Se o
/// ciclo mudar, estes seguem junto, que é o que mantém os dois iguais.
const _atrasos = [0.0, 160 / 1100, 320 / 1100];

class ChamadaTronikat extends StatefulWidget {
  const ChamadaTronikat({super.key});

  static const String id = 'tronikat-chamada';
  static const Key chave = Key(id);
  static const Key chavePonto = Key('tronikat-chamada-ponto');

  @override
  State<ChamadaTronikat> createState() => _ChamadaTronikatState();
}

class _ChamadaTronikatState extends State<ChamadaTronikat>
    with SingleTickerProviderStateMixin {
  // UM CONTROLADOR SÓ, e os três pontinhos saem dele por defasagem. Três
  // controladores seriam três relógios acordando o mesmo quadro -- a mesma
  // regra que a tela de título e a faixa de cenário já seguem.
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: _ciclo,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // RESPEITA "REDUZIR ANIMAÇÕES" do Android. Aqui pesa: um balão pulsando
    // no canto é justamente o tipo de movimento periférico que incomoda quem
    // é sensível a ele. Sem o movimento o balão continua inteiro, e continua
    // dizendo o que tinha para dizer.
    final quieto = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (quieto) {
      if (_ctrl.isAnimating) _ctrl.stop();
    } else if (!_ctrl.isAnimating) {
      _ctrl.repeat();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: ChamadaTronikat.id,
      // Para quem usa leitor de tela o balão não é o convite -- o rótulo do
      // botão é. Repetir aqui faria o TalkBack anunciar a mesma coisa duas
      // vezes, então ele é decorativo de propósito.
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          // O balão bóia 3px, como no navegador: é o que o separa de um
          // adesivo colado na tela.
          final boia = -3 * _onda(_ctrl.value);
          return Transform.translate(
            offset: Offset(0, boia),
            child: _balao(),
          );
        },
      ),
    );
  }

  /// Um salto suave entre 0 e 1 e de volta.
  double _onda(double t) {
    final meio = t < .5 ? t * 2 : (1 - t) * 2;
    return Curves.easeInOut.transform(meio.clamp(0.0, 1.0));
  }

  Widget _balao() {
    return Container(
      key: ChamadaTronikat.chave,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: Paleta.superficie,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Paleta.destaque, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _atrasos.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            _ponto(i),
          ],
        ],
      ),
    );
  }

  Widget _ponto(int i) {
    // Cada pontinho lê o MESMO relógio, deslocado. `% 1` faz a volta.
    final t = (_ctrl.value + 1 - _atrasos[i]) % 1;
    final salto = _onda(t);
    return Transform.translate(
      offset: Offset(0, -5 * salto),
      child: Container(
        key: i == 0 ? ChamadaTronikat.chavePonto : null,
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          // Verde do visor: é a cor que o projeto reserva para acento, e o
          // pontinho é acento puro -- não há texto aqui para reprovar em
          // contraste.
          color: Paleta.visor.withValues(alpha: .55 + .45 * salto),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
