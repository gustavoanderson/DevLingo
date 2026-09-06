import 'package:audioplayers/audioplayers.dart';

/// Toca a fanfarra de acerto.
///
/// Três regras, todas do CLAUDE.md, e todas com motivo:
///
/// - **Só no acerto.** Errar não tem som. Som de erro é punição sonora, e a
///   mecânica inteira foi desenhada para não punir.
/// - **Nunca é o único retorno.** O verde e a explicação continuam funcionando
///   com o som mudo, então desligar não tira informação nenhuma de ninguém.
/// - **Dá para desligar.** A preferência mora no banco, junto do progresso.
///
/// O arquivo é uma onda quadrada sintetizada, não um trompete gravado. Chiptune
/// combina com um gato ciborgue de visor neon melhor que orquestra.
abstract interface class Sineta {
  Future<void> acerto();
  void dispose();
}

class SinetaDeVerdade implements Sineta {
  SinetaDeVerdade({required this.estaLigado});

  /// Consultado a cada toque, direto da fonte, e nunca guardado em cache.
  ///
  /// Guardar o valor exigiria mantê-lo em sincronia com o botão que o altera,
  /// e sincronizar duas cópias de um mesmo dado é onde nascem defeitos que só
  /// aparecem numa ordem específica de toques. Ler de novo é barato: acontece
  /// uma vez por questão respondida, não por quadro.
  final Future<bool> Function() estaLigado;

  static const String arquivo = 'som/acerto.wav';

  /// Criado só no primeiro acerto, nunca antes.
  ///
  /// O construtor do tocador conversa com a plataforma de áudio, e criá-lo no
  /// construtor da sineta punha essa conversa **dentro do `build` da tela** —
  /// onde ela pode travar a thread principal se o serviço de áudio do aparelho
  /// estiver indisponível. Nada relacionado a som deve tocar a plataforma antes
  /// de alguém realmente merecer uma fanfarra.
  AudioPlayer? _tocador;

  Future<AudioPlayer> _preparar() async {
    final existente = _tocador;
    if (existente != null) return existente;

    final tocador = AudioPlayer();
    _tocador = tocador;
    // O contexto de notificação faz o áudio seguir o canal que o modo
    // silencioso do aparelho silencia, em vez do canal de mídia, que não é
    // silenciado. É o comportamento certo para um efeito curto de retorno.
    await tocador.setAudioContext(
      AudioContext(
        android: const AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: false,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.notification,
          audioFocus: AndroidAudioFocus.none,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.ambient,
          options: const {AVAudioSessionOptions.mixWithOthers},
        ),
      ),
    );
    await tocador.setReleaseMode(ReleaseMode.stop);
    return tocador;
  }

  @override
  Future<void> acerto() async {
    try {
      if (!await estaLigado()) return;
      final tocador = await _preparar();
      await tocador.stop();
      await tocador.play(AssetSource(arquivo));
    } on Object {
      // Som é camada, não requisito. Se o áudio falhar por qualquer motivo —
      // aparelho sem saída, permissão, formato — a questão continua
      // respondida e o retorno visual continua na tela. Falhar em silêncio
      // aqui é a decisão certa, e é diferente de falhar em silêncio no
      // conteúdo, que é o que o validador existe para impedir.
    }
  }

  @override
  void dispose() => _tocador?.dispose();
}

/// Sineta que não toca nada, e conta quantas vezes foi chamada.
///
/// O contador é de instância, e não estático: contador global vazaria de um
/// teste para o seguinte, e o teste que falhasse não seria o que tem o defeito.
class SinetaMuda implements Sineta {
  int toques = 0;

  @override
  Future<void> acerto() async => toques++;

  @override
  void dispose() {}
}
