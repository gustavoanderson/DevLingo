/// Os pedaços em que uma linha de código é quebrada para o realce.
///
/// Vive em arquivo próprio para o tokenizador não depender do Flutter: assim
/// ele é Dart puro, testável sem montar tela e sem carregar a biblioteca de
/// widgets.
enum TipoDeToken {
  palavraChave,
  texto,
  numero,
  funcao,
  comentario,
  nome,
  pontuacao,
  espaco,

  /// O marcador de lacuna. Não é código: vira pastilha na tela.
  lacuna,
}

class Token {
  final String texto;
  final TipoDeToken tipo;

  const Token(this.texto, this.tipo);

  @override
  String toString() => '${tipo.name}(${texto.replaceAll(' ', '·')})';

  @override
  bool operator ==(Object other) =>
      other is Token && other.texto == texto && other.tipo == tipo;

  @override
  int get hashCode => Object.hash(texto, tipo);
}
