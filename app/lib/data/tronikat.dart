/// Falar com o Tr∅nikAt a partir do app.
///
/// ## O que mora aqui, e o que NÃO mora
///
/// Aqui mora só o transporte: mandar a pergunta, receber texto e som. **Nenhuma
/// regra de porteiro** — qual ficha responde, se a pergunta passa do piso e o
/// que o modelo pode dizer continuam no Worker, o mesmo que atende o site e o
/// jogo do navegador. Três clientes, um porteiro.
///
/// ## Nenhuma dependência nova
///
/// `dart:io` já traz `HttpClient`, e `audioplayers` — que o app usa para a
/// fanfarra desde a versão do som — já sabe tocar bytes. Um pacote a mais no
/// `pubspec` por duas chamadas HTTP seria peso sem troco.
///
/// ## Ele exige internet, e o app não
///
/// O DevLingo funciona offline por desenho. Esta é a única peça que não, e por
/// isso a falha aqui **nunca** derruba nada: quem chama recebe uma resposta
/// dizendo que não deu, e a tela entra em standby — ver `JanelaTronikat`.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// O que volta de uma pergunta: o texto que se lê e, quando houver, o som.
///
/// [audio] é nulo quando a voz falhou — e isso **não** invalida a resposta: o
/// texto é o conteúdo, a fala é o tom. Som é conveniência, a mesma regra que
/// vale para a fanfarra de acerto.
class RespostaDoTronikat {
  const RespostaDoTronikat({required this.texto, this.audio});

  final String texto;
  final Uint8List? audio;
}

/// Quem sabe conversar com ele.
///
/// Existe como interface pela mesma razão de `RegistroDeProgresso`: teste de
/// widget roda em tempo falso e **I/O de verdade nunca avança nele**. A janela
/// recebe isto, e o teste passa uma implementação em memória.
abstract class ConsultorDoTronikat {
  /// [progresso] e o dossie montado por `montarDossie`, ou nulo.
  ///
  /// Opcional de proposito, e ele continua opcional ate o Worker: o site
  /// publico nao tem login e nunca manda um. A placa `meu-progresso` responde
  /// mandando entrar na conta, em vez de fingir que sabe.
  Future<RespostaDoTronikat> perguntar(String pergunta, {String? progresso});

  /// Uma fala curta de enrolação, para tocar ENQUANTO a resposta não chega.
  ///
  /// Devolve nulo quando não há — e aí a espera é só silêncio, que funciona,
  /// mas é pior.
  Future<Uint8List?> enrolacao();
}

/// O cliente de verdade, contra o Worker publicado.
class TronikatDaBorda implements ConsultorDoTronikat {
  TronikatDaBorda({HttpClient? cliente}) : _http = cliente ?? HttpClient() {
    // Sem teto, uma rede ruim deixa a janela pendurada para sempre, e o
    // usuário conclui que travou. Com teto, ela vira standby e diz por quê.
    _http.connectionTimeout = const Duration(seconds: 12);
  }

  static const _worker = 'https://tronikat.tronikat-busca.workers.dev';

  /// As falas gravadas moram no site publicado, e não dentro do APK.
  ///
  /// Empacotá-las custaria alguns megabytes por uma voz que só toca com
  /// internet — e quem tem internet consegue baixar. Elas também mudam sem o
  /// app mudar: regravar uma ficha não pode exigir uma release.
  static const _falas = 'https://gustavoanderson.github.io/DevLingo/falas/';

  static const _enrolar = [
    '_pensar-01', '_pensar-02', '_pensar-03', '_pensar-04', '_pensar-05',
  ];

  final HttpClient _http;
  final _sorte = Random();
  Map<String, dynamic>? _indice;

  Future<String> _postar(String caminho, Map<String, Object?> corpo) async {
    final req = await _http.postUrl(Uri.parse('$_worker$caminho'));
    req.headers.contentType = ContentType.json;
    req.write(jsonEncode(corpo));
    final resp = await req.close();
    if (resp.statusCode != 200) {
      throw HttpException('o servidor respondeu ${resp.statusCode}');
    }
    return resp.transform(utf8.decoder).join();
  }

  Future<Uint8List> _baixar(String url) async {
    final resp = await (await _http.getUrl(Uri.parse(url))).close();
    if (resp.statusCode != 200) {
      throw HttpException('$url respondeu ${resp.statusCode}');
    }
    final pedacos = <int>[];
    await for (final p in resp) {
      pedacos.addAll(p);
    }
    return Uint8List.fromList(pedacos);
  }

  Future<Map<String, dynamic>> _indiceDasFalas() async {
    return _indice ??= jsonDecode(utf8.decode(await _baixar('${_falas}indice.json')))
        as Map<String, dynamic>;
  }

  @override
  Future<RespostaDoTronikat> perguntar(String pergunta,
      {String? progresso}) async {
    final corpo = jsonDecode(await _postar('/perguntar', {
      'pergunta': pergunta,
      // Ausente, e nao vazio, quando nao ha: o Worker so liga a faixa do tutor
      // com dossie de verdade, e string vazia passaria pelo `typeof` dele.
      if (progresso != null && progresso.isNotEmpty) 'progresso': progresso,
    })) as Map<String, dynamic>;

    // Dois caminhos, e o Worker diz qual foi. Resposta GERADA na borda não tem
    // áudio gravado e passa pelo serviço de voz; ficha conhecida já tem texto e
    // som prontos, e toca em zero segundo.
    final texto = corpo['texto'] as String?;
    if (texto != null) {
      Uint8List? audio;
      try {
        final voz = jsonDecode(await _postar('/falar', {'texto': texto}))
            as Map<String, dynamic>;
        final b64 = voz['audio'] as String?;
        if (b64 != null) audio = base64Decode(b64);
      } on Object {
        // De propósito: sem voz a resposta ainda vale inteira.
      }
      return RespostaDoTronikat(texto: texto, audio: audio);
    }

    final indice = await _indiceDasFalas();
    final ficha = (corpo['ficha'] as String?) ?? '_recusa';
    final fala = indice[ficha] as Map<String, dynamic>?;
    if (fala == null) throw HttpException('fala desconhecida: $ficha');
    Uint8List? audio;
    try {
      audio = await _baixar('$_falas${fala['audio']}');
    } on Object {
      // idem
    }
    return RespostaDoTronikat(texto: fala['texto'] as String, audio: audio);
  }

  @override
  Future<Uint8List?> enrolacao() async {
    try {
      final indice = await _indiceDasFalas();
      // O sorteio escolhe uma fala, e o arquivo tem de ser o DELA. No navegador
      // eu sorteei e depois montei o caminho com o índice zero: tocava sempre a
      // mesma frase, com a boca de outra por cima.
      //
      // E AQUI ELE ERA `DateTime.now().microsecond % 5`, que PARECE sorteio e
      // não é. O Gustavo ouviu sempre a mesma frase, e a medição deu o número:
      // em 40 chamadas seguidas só apareceram **3 microssegundos distintos**,
      // 34 delas caíram na mesma fala, e três das cinco nunca saíram.
      //
      // A causa é que `DateTime.now()` não tem resolução de microssegundo — o
      // campo existe, e fica preso em poucos valores. Relógio não é gerador de
      // número aleatório, e o navegador nunca teve este defeito porque sempre
      // usou `Math.random`.
      final qual = _enrolar[_sorte.nextInt(_enrolar.length)];
      final fala = indice[qual] as Map<String, dynamic>?;
      if (fala == null) return null;
      return await _baixar('$_falas${fala['audio']}');
    } on Object {
      return null;
    }
  }
}
