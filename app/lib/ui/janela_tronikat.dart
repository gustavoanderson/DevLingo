/// A janela de conversa com o Tr∅nikAt, dentro do app.
///
/// Ela repete, em Flutter, o que `jogo/tronikat.js` faz no navegador — e as
/// decisões de produto são as mesmas, porque é o mesmo personagem:
///
///  - **ele não vê a questão em que você está.** Nada aqui lê a tela de
///    exercício, e isso é garantia, não limitação: um mascote que enxergasse o
///    enunciado poderia entregar a resposta, esvaziando a eliminação e a
///    revelação
///  - **o texto sai JUNTO com a fala.** São a mesma fala: ler antes de ouvir
///    transforma a voz em repetição, e o personagem vira legenda de si mesmo
///  - **enquanto ele pensa, ele enrola**, com uma fala curta já gravada que
///    toca em zero segundo
///  - **sem conexão ele entra em standby**, e não vira mensagem de erro
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../data/tronikat.dart';
import 'paleta.dart';
import 'tronikat_codec.dart';

/// Um turno da conversa.
class _Fala {
  _Fala(this.minha, this.texto);
  final bool minha;
  String texto;
}

class JanelaTronikat extends StatefulWidget {
  const JanelaTronikat({super.key, required this.consultor, this.comSom = true});

  final ConsultorDoTronikat consultor;

  /// Desligável para teste: `audioplayers` conversa com a plataforma, e teste
  /// de widget não tem plataforma. Mesma razão pela qual `comCena` nasce falso
  /// em `cena_do_login.dart`.
  final bool comSom;

  static const chaveCampo = Key('tronikat-campo');
  static const chaveEnviar = Key('tronikat-enviar');
  static const chaveStandby = Key('tronikat-standby');

  /// Abre a janela por cima da tela atual.
  static Future<void> abrir(BuildContext context, ConsultorDoTronikat c) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => JanelaTronikat(consultor: c),
    );
  }

  @override
  State<JanelaTronikat> createState() => _JanelaTronikatState();
}

class _JanelaTronikatState extends State<JanelaTronikat> {
  final _campo = TextEditingController();
  final _rolagem = ScrollController();
  final _falas = <_Fala>[
    _Fala(false, 'Oi! Pergunte o que quiser sobre o DevLingo ou sobre programação.'),
  ];

  AudioPlayer? _tocador;
  bool _ocupado = false;
  bool _semRede = false;
  double _boca = 0;
  Timer? _bocaTimer;

  @override
  void dispose() {
    _bocaTimer?.cancel();
    _tocador?.dispose();
    _campo.dispose();
    _rolagem.dispose();
    super.dispose();
  }

  /// Move a boca enquanto o som toca.
  ///
  /// SEM os `bocas` por fonema que o navegador usa, e é uma diferença
  /// assumida: ali o índice das falas traz a marcação alinhada, e aqui só o
  /// áudio chega. Uma oscilação no ritmo da fala lê como articulação; parar a
  /// boca fechada leria como um retrato mudo com voz por cima, que é pior.
  void _animarBoca(Duration duracao) {
    _bocaTimer?.cancel();
    final fim = DateTime.now().add(duracao);
    var passo = 0;
    _bocaTimer = Timer.periodic(const Duration(milliseconds: 90), (t) {
      if (DateTime.now().isAfter(fim)) {
        t.cancel();
        if (mounted) setState(() => _boca = 0);
        return;
      }
      passo++;
      if (mounted) setState(() => _boca = passo.isEven ? .75 : .25);
    });
  }

  Future<void> _tocar(Uint8List? audio) async {
    if (audio == null || !widget.comSom) return;
    try {
      _tocador ??= AudioPlayer();
      await _tocador!.stop();
      await _tocador!.play(BytesSource(audio));
      final d = await _tocador!.getDuration();
      _animarBoca(d ?? const Duration(seconds: 3));
    } on Object {
      // Falhar no som não derruba a resposta, que já está escrita na tela.
    }
  }

  void _aoFim() {
    if (!mounted) return;
    // `hasClients` NAO e zelo: quando a janela entra em standby, a lista sai
    // da arvore e este controlador fica solto. Sem a guarda, perder a rede
    // lancava excecao no scheduler -- e o teste do standby pegou isso antes
    // de o aparelho pegar.
    if (!_rolagem.hasClients) return;
    _rolagem.animateTo(
      _rolagem.position.maxScrollExtent + 200,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  Future<void> _enviar() async {
    final pergunta = _campo.text.trim();
    if (pergunta.isEmpty || _ocupado || _semRede) return;

    setState(() {
      _ocupado = true;
      _campo.clear();
      _falas.add(_Fala(true, pergunta));
      _falas.add(_Fala(false, '…'));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _aoFim());

    // ENQUANTO ELE PENSA, ELE ENROLA. A fala já está gravada, então toca na
    // hora: o silêncio de alguns segundos deixa de ser silêncio.
    unawaited(widget.consultor.enrolacao().then(_tocar).catchError((_) {}));

    try {
      final r = await widget.consultor.perguntar(pergunta);
      if (!mounted) return;
      setState(() {
        _semRede = false;
        _falas.last.texto = r.texto;
      });
      await _tocar(r.audio);
    } on Object {
      if (!mounted) return;
      setState(() {
        // Sem rede quem manda é o standby, e a bolha sai de cena: deixar as
        // duas seria dizer a mesma coisa de dois jeitos.
        _semRede = true;
        _falas.removeLast();
      });
    } finally {
      if (mounted) {
        setState(() => _ocupado = false);
        WidgetsBinding.instance.addPostFrameCallback((_) => _aoFim());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final alturaTeclado = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: alturaTeclado),
      child: Container(
        height: MediaQuery.sizeOf(context).height * .78,
        decoration: const BoxDecoration(
          color: Paleta.superficie,
          border: Border(top: BorderSide(color: Paleta.destaque)),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            _cabecalho(context),
            Expanded(child: _semRede ? _standby() : _conversa()),
            // A BARRA DE NAVEGAÇÃO DO ANDROID FICAVA POR CIMA do campo e do
            // Enviar. `showModalBottomSheet` encosta na borda física da tela, e
            // a borda física é onde moram os botões do sistema -- ou a barra de
            // gestos, conforme o aparelho.
            //
            // Encontrado pelo Gustavo num Xiaomi 15T Pro, e é o tipo de defeito
            // que só o aparelho de verdade mostra: no teste a tela não tem
            // barra nenhuma, e sobra espaço.
            //
            // `SafeArea` só embaixo: em cima quem manda é o arredondado da
            // folha, e dos lados não há recorte.
            SafeArea(top: false, child: _barraDeEnvio()),
          ],
        ),
      ),
    );
  }

  Widget _cabecalho(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 6),
      child: Row(
        children: [
          const Text('Tr∅nikAt',
              style: TextStyle(
                  color: Paleta.visor, fontFamily: fonteMono, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          // O ESCOPO DELE FICA ESCRITO NA JANELA. Mascote que desconversa sem
          // avisar do que fala parece quebrado; dizer antes evita a pergunta
          // que vai ser barrada.
          const Expanded(
            child: Text('fala do DevLingo e de programação',
                style: TextStyle(color: Paleta.suave, fontSize: 11)),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, size: 18),
            color: Paleta.suave,
            tooltip: 'Fechar a conversa',
          ),
        ],
      ),
    );
  }

  Widget _conversa() {
    return ListView(
      controller: _rolagem,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      children: [
        Center(child: TronikatCodec(abertura: _boca, largura: 176)),
        const SizedBox(height: 12),
        for (final f in _falas)
          Align(
            alignment: f.minha ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * .76),
              decoration: BoxDecoration(
                color: f.minha ? Paleta.altSelecionadaFundo : Paleta.fundo,
                border: Border.all(
                    color: f.minha ? Paleta.destaque : Paleta.linha),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(f.texto,
                  style: const TextStyle(color: Paleta.texto, fontSize: 14)),
            ),
          ),
      ],
    );
  }

  /// Sem conexão ele não vira mensagem de erro: vira personagem esperando.
  ///
  /// A frase sobre o jogo é o recado mais importante da janela. O DevLingo
  /// funciona offline por desenho, e quem vê um mascote cinza precisa saber
  /// que o resto não caiu junto.
  Widget _standby() {
    return Center(
      key: JanelaTronikat.chaveStandby,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ColorFiltered(
            colorFilter: const ColorFilter.matrix(<double>[
              0.2126, 0.7152, 0.0722, 0, 0,
              0.2126, 0.7152, 0.0722, 0, 0,
              0.2126, 0.7152, 0.0722, 0, 0,
              0, 0, 0, 1, 0,
            ]),
            child: const TronikatCodec(parado: true, largura: 176),
          ),
          const SizedBox(height: 14),
          const Text('CONNECTION LOST',
              style: TextStyle(
                  color: Paleta.erro, fontSize: 13, letterSpacing: 2, fontFamily: fonteMono)),
          const SizedBox(height: 6),
          const Text('Aguardando conexão para respondê-lo.',
              style: TextStyle(color: Paleta.texto, fontSize: 13)),
          const SizedBox(height: 8),
          const Text('O jogo continua funcionando normalmente.',
              style: TextStyle(color: Paleta.suave, fontSize: 12)),
          const SizedBox(height: 14),
          TextButton(
            onPressed: () => setState(() => _semRede = false),
            child: const Text('Tentar de novo',
                style: TextStyle(color: Paleta.destaque, fontFamily: fonteMono)),
          ),
        ],
      ),
    );
  }

  Widget _barraDeEnvio() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Paleta.linha)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: JanelaTronikat.chaveCampo,
              controller: _campo,
              enabled: !_semRede,
              onSubmitted: (_) => _enviar(),
              style: const TextStyle(color: Paleta.texto),
              decoration: InputDecoration(
                hintText: _semRede
                    ? 'Sem conexão no momento…'
                    : 'Pergunte alguma coisa…',
                hintStyle: const TextStyle(color: Paleta.suave),
                filled: true,
                fillColor: Paleta.fundo,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Paleta.linha),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            key: JanelaTronikat.chaveEnviar,
            onPressed: (_ocupado || _semRede) ? null : _enviar,
            style: FilledButton.styleFrom(backgroundColor: Paleta.acerto),
            child: const Text('Enviar', style: TextStyle(fontFamily: fonteMono)),
          ),
        ],
      ),
    );
  }
}
