import 'package:audioplayers/audioplayers.dart';

/// Toca os efeitos sonoros do app.
///
/// Três regras, todas do CLAUDE.md, e todas com motivo:
///
/// - **Só no acerto.** Errar não tem som. Som de erro é punição sonora, e a
///   mecânica inteira foi desenhada para não punir.
/// - **Nunca é o único retorno.** O verde e a explicação continuam funcionando
///   com o som mudo, então desligar não tira informação nenhuma de ninguém.
/// - **Dá para desligar.** A preferência mora no banco, junto do progresso.
///
/// Os arquivos são ondas quadradas sintetizadas, não instrumentos gravados.
/// Chiptune combina com um gato ciborgue de visor neon melhor que orquestra.
abstract interface class Sineta {
  /// Fanfarra de quem acertou uma questão.
  Future<void> acerto();

  /// Ficha caindo no fliperama, no START da tela de título.
  ///
  /// Divide a mesma chave de preferência da fanfarra, e não uma chave própria.
  /// Duas chaves obrigariam o usuário a desligar som em dois lugares para ficar
  /// em silêncio, e "desliguei o som e ainda apitou" é um defeito de produto.
  Future<void> ficha();

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

  static const String arquivoAcerto = 'som/acerto.wav';
  static const String arquivoFicha = 'som/ficha.wav';

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
    // Canal de JOGO, e nao o de notificacao.
    //
    // A primeira versao usava `notification`, para o modo silencioso do
    // aparelho calar o app sozinho. Parecia certo, e a experiencia real
    // reprovou: os botoes de volume ajustam o canal de MIDIA, entao apertar
    // volume durante o jogo nao mudava nada. O Gustavo baixou o volume no
    // celular e o som continuou estridente igual -- o controle mais obvio do
    // aparelho simplesmente nao funcionava neste app.
    //
    // `game` roteia para o mesmo canal da midia, entao o volume passa a
    // responder. O preco e que o modo silencioso deixa de calar o app
    // sozinho; em troca, a chave de mudo agora existe na trilha E na tela de
    // exercicio, que e um controle explicito em vez de um efeito colateral.
    await tocador.setAudioContext(
      AudioContext(
        android: const AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: false,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.game,
          // Nao pede foco: o efeito dura menos de um segundo, e roubar o foco
          // pausaria a musica de quem estuda ouvindo alguma coisa.
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
  Future<void> acerto() => _tocar(arquivoAcerto);

  @override
  Future<void> ficha() => _tocar(arquivoFicha);

  /// Um tocador só, reaproveitado pelos dois sons.
  ///
  /// Não há risco de sobreposição: os dois efeitos vivem em telas diferentes e
  /// nunca disputam a saída. Um tocador por som seria uma segunda conversa com
  /// a plataforma de áudio em troca de nada.
  Future<void> _tocar(String arquivo) async {
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
/// Os contadores são de instância, e não estáticos: contador global vazaria de
/// um teste para o seguinte, e o teste que falhasse não seria o que tem o
/// defeito.
///
/// Cada som tem seu próprio contador. Um contador só provaria que *algum* som
/// tocou, e o teste passaria se a tela de título tocasse a fanfarra por engano.
class SinetaMuda implements Sineta {
  int toques = 0;
  int fichas = 0;

  @override
  Future<void> acerto() async => toques++;

  @override
  Future<void> ficha() async => fichas++;

  @override
  void dispose() {}
}
