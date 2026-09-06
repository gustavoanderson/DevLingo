import 'package:flutter/material.dart';

import 'paleta.dart';

/// Degradê no limite de uma área rolável, avisando que há conteúdo cortado.
///
/// Sem ele o usuário não descobre o que está abaixo: a tela parece terminar
/// onde o recorte termina.
///
/// O degradê termina num tom **mais fundo que o fundo da tela**. Terminar na
/// própria cor do fundo deixa a sombra invisível: ela só escurece o que estiver
/// por baixo, e no limite do recorte costuma haver apenas a borda fina de um
/// cartão. Isso já passou por testes verdes e só apareceu ao olhar o print.
class SombraDeRecorte extends StatelessWidget {
  const SombraDeRecorte({super.key});

  static const double altura = 44;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: altura,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Paleta.veu.withValues(alpha: 0),
            Paleta.veu.withValues(alpha: 0.75),
            Paleta.veu,
          ],
          stops: const [0, 0.55, 1],
        ),
      ),
    );
  }
}

/// Mistura que acompanha uma rolagem e diz quando ainda há conteúdo abaixo.
///
/// Vive fora dos widgets de tela porque a mesma pergunta aparece na tela de
/// exercício e na de aula, e a resposta depende de duas fontes: o listener do
/// controlador, para quando o usuário rola, e a notificação de métrica, para o
/// primeiro layout — quando o conteúdo ainda nem foi medido e o controlador não
/// tem clientes.
mixin AvisaConteudoCortado<T extends StatefulWidget> on State<T> {
  final ScrollController rolagem = ScrollController();

  bool temMaisAbaixo = false;

  void iniciarAvisoDeRecorte() {
    rolagem.addListener(conferirRecorte);
    WidgetsBinding.instance.addPostFrameCallback((_) => conferirRecorte());
  }

  void encerrarAvisoDeRecorte() {
    rolagem.removeListener(conferirRecorte);
    rolagem.dispose();
  }

  void conferirRecorte() {
    if (!rolagem.hasClients) return;
    final posicao = rolagem.position;
    final cortado = posicao.maxScrollExtent - posicao.pixels > 1;
    if (cortado != temMaisAbaixo) {
      setState(() => temMaisAbaixo = cortado);
    }
  }

  /// Envolve a lista rolável, sobrepondo a sombra quando ha o que revelar.
  Widget comSombraDeRecorte({required Widget rolavel, required Key chaveSombra}) {
    return Stack(
      children: [
        NotificationListener<ScrollMetricsNotification>(
          onNotification: (_) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => conferirRecorte(),
            );
            return false;
          },
          child: rolavel,
        ),
        if (temMaisAbaixo)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(child: SombraDeRecorte(key: chaveSombra)),
          ),
      ],
    );
  }
}
