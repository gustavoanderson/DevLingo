/// A versão do app, para exibir na tela.
///
/// ## Por que não vem do `pubspec.yaml` em tempo de execução
///
/// Ler o `pubspec` do app rodando exigiria `package_info_plus` — uma
/// dependência nova, com código nativo dos dois lados, para mostrar seis
/// caracteres numa tela que quase ninguém abre.
///
/// ## E por que isso não vira divergência silenciosa
///
/// Duas cópias do mesmo número divergem — é a lição que este repositório já
/// pagou três vezes: a normalização em Python e Dart, a geometria dos
/// cenários, e os badges do README que envelheceram sem ninguém ver.
///
/// A defesa aqui é a mesma das outras: **um teste compara esta constante com
/// o `pubspec.yaml`** e reprova se elas se separarem. Quem subir a versão e
/// esquecer daqui descobre na suíte, não na loja.
library;

/// Igual ao `version:` do `pubspec.yaml`, sem o `+N` do `versionCode`.
///
/// O `+N` fica de fora porque é número de build para o Android, e não diz nada
/// a quem usa o app.
const String versaoDoApp = '1.6.0';
