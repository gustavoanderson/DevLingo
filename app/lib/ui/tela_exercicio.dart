import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../answer/normalize.dart';
import '../answer/sessao_questao.dart';
import '../data/progresso.dart';
import '../models/lesson.dart';
import '../models/question.dart';
import 'bloco_codigo.dart';
import 'faixa_cenario.dart';
import 'paleta.dart';
import 'texto_rico.dart';
import 'som.dart';
import 'sombra_de_recorte.dart';

/// A tela de exercicio.
///
/// - **Fixo no topo:** sair, barra de progresso da licao, contador
/// - **Rola no meio:** chip de topico, enunciado, codigo, dica, alternativas
/// - **Fixo no rodape:** painel de retorno, regua de simbolos e barra de acoes
///
/// O mockup desenha a barra de acoes rolando junto porque e HTML estatico e nao
/// consegue demonstrar a divisao. O CLAUDE.md e a autoridade: a barra fica fixa.
///
/// A logica de tentativas, eliminacao e revelacao mora em [SessaoQuestao], fora
/// daqui, para ser testavel sem montar tela.
class TelaExercicio extends StatefulWidget {
  const TelaExercicio({
    super.key,
    required this.licao,
    this.progresso,
    this.indiceInicial = 0,
    this.aoRelerAula,
    this.aoMudarQuestao,
    this.textoInicial = '',
    this.aoMudarTexto,
    this.sessaoInicial,
    this.aoMudarSessao,
    this.sineta,
    this.comCenario = false,
  });

  final Lesson licao;

  /// Onde o progresso e gravado. Nulo nos testes que nao se importam com isso.
  final RegistroDeProgresso? progresso;

  final int indiceInicial;

  /// Reabre a aula da licao. Nulo quando a licao nao tem aula.
  final VoidCallback? aoRelerAula;

  /// O que ja estava digitado quando esta tela foi montada.
  ///
  /// Existe pelo mesmo motivo de [aoMudarQuestao], e o defeito era irmao:
  /// abrir a aula desmonta esta tela, e o `TextEditingController` morre junto
  /// -- quem estava no meio de uma resposta perdia o que tinha escrito. Quem
  /// guarda o texto e o [FluxoDaLicao], que sobrevive a troca.
  final String textoInicial;

  /// Avisa o que esta escrito, a cada tecla.
  final ValueChanged<String>? aoMudarTexto;

  /// Avisa em que questao o aluno esta, a cada virada.
  ///
  /// Existe por causa de um defeito real: abrir a aula pelo icone do livro
  /// **desmonta esta tela**, e ao voltar ela renascia em [indiceInicial] -- o
  /// indice de quando a licao abriu, nao o de onde a pessoa estava. Quem
  /// consultava o material na questao 7 voltava para a 5.
  ///
  /// Gravar no banco nao resolvia: quem remonta a tela e o [FluxoDaLicao], que
  /// nao le o banco de novo. A posicao precisa subir para quem sobrevive a
  /// troca de tela.
  final ValueChanged<int>? aoMudarQuestao;

  /// A sessao em andamento quando esta tela foi montada, ou nulo para comecar
  /// uma nova.
  ///
  /// Terceiro campo desta familia, e o defeito era o mais grave dos tres: quem
  /// acertava uma questao, consultava a aula e voltava **sem avancar**
  /// encontrava a questao zerada, e tinha que responder de novo.
  ///
  /// E nao era so incomodo. A gravacao acontece quando a questao TERMINA, e o
  /// id do evento e `uid|questao|instante` -- responder de novo carimba outro
  /// instante e grava uma **segunda partida que nunca houve**, inflando as
  /// estatisticas. Pior: errar na segunda vez reescreve o estado atual daquela
  /// questao para "errou", apagando um acerto legitimo.
  ///
  /// Guardar a sessao inteira, e nao campo a campo, e de proposito: ela e
  /// mutavel e esta tela muta o proprio objeto, entao o [FluxoDaLicao] so
  /// precisa da referencia. Um campo novo em [SessaoQuestao] passa a sobreviver
  /// sozinho, sem ninguem lembrar de propaga-lo.
  final SessaoQuestao? sessaoInicial;

  /// Avisa que uma sessao nova comecou, para o [FluxoDaLicao] guardar.
  final ValueChanged<SessaoQuestao>? aoMudarSessao;

  /// Toca a fanfarra de acerto. Nulo em teste que nao se importa com som.
  final Sineta? sineta;

  /// Desenha o cenario animado colado na borda de baixo.
  ///
  /// Falso desliga a faixa por completo, e nao apenas a animacao: e a chave
  /// manual prevista no CLAUDE.md, para quem prefere a tela sem movimento
  /// nenhum ou precisa poupar bateria. Os testes tambem passam falso, porque
  /// uma animacao em repeticao infinita faz `pumpAndSettle` estourar o limite
  /// de tempo esperando por um repouso que nunca chega.
  final bool comCenario;

  static const Key chaveSombra = Key('sombra-de-recorte');
  static const Key chaveFimDaLicao = Key('fim-da-licao');
  static const Key chaveVoltarDaLicao = Key('voltar-da-licao');

  @override
  State<TelaExercicio> createState() => _TelaExercicioState();
}

class _TelaExercicioState extends State<TelaExercicio>
    with AvisaConteudoCortado<TelaExercicio> {
  late final TextEditingController _texto = TextEditingController(
    text: widget.textoInicial,
  );
  final FocusNode _foco = FocusNode();

  late int _indice = widget.indiceInicial;
  late SessaoQuestao _sessao = _sessaoDeEntrada();

  /// Aproveita a sessao que veio de fora, ou comeca uma.
  ///
  /// A conferencia do `id` nao e paranoia: [sessaoInicial] e [indiceInicial]
  /// chegam por caminhos separados, e uma sessao da questao errada mostraria
  /// o resultado de uma pergunta sobre o enunciado de outra. Divergiram, esta
  /// tela comeca limpa -- perder o andamento e ruim, mostrar resposta trocada
  /// e pior.
  SessaoQuestao _sessaoDeEntrada() {
    final herdada = widget.sessaoInicial;
    if (herdada != null && herdada.questao.id == _questaoAtual.id) {
      return herdada;
    }
    return _sessaoNova();
  }

  /// Cria a sessao da questao atual e avisa quem a guarda.
  SessaoQuestao _sessaoNova() {
    final sessao = SessaoQuestao(_questaoAtual);
    widget.aoMudarSessao?.call(sessao);
    return sessao;
  }

  bool _licaoConcluida = false;

  /// Só desenha o ícone; quem decide se toca é a [Sineta], que relê o banco a
  /// cada som. São duas leituras do mesmo dado, e é de propósito: manter uma
  /// cópia em sincronia com a outra é onde nascem defeitos de ordem de toque.
  ///
  /// Nasce ligado porque é o padrão do app, e se corrige sozinho assim que a
  /// leitura volta — um ícone errado por um quadro não engana ninguém.
  bool _som = true;

  Question get _questaoAtual => widget.licao.questions[_indice];

  @override
  void initState() {
    super.initState();
    iniciarAvisoDeRecorte();
    unawaited(_lerSom());
    // Sem isto o botao Verificar nao sairia do estado desabilitado ao digitar:
    // o texto muda dentro do controlador, sem passar por setState.
    _texto.addListener(_aoDigitar);
    _texto.addListener(_avisarTexto);
  }

  @override
  void dispose() {
    encerrarAvisoDeRecorte();
    _texto.removeListener(_aoDigitar);
    _texto.removeListener(_avisarTexto);
    _texto.dispose();
    _foco.dispose();
    super.dispose();
  }

  void _aoDigitar() => setState(() {});

  void _verificar() {
    final questao = _questaoAtual;
    setState(() {
      if (_sessao.ehEscrita) {
        _sessao.verificarEscrita(_texto.text);
      } else {
        _sessao.verificar();
      }
    });
    if (!_sessao.terminou) return;

    _foco.unfocus();

    // So o acerto tem som. Errar em silencio e deliberado: som de erro seria
    // punicao sonora, e a mecanica foi desenhada para nao punir.
    if (_sessao.fase == FaseResposta.acertou) {
      unawaited(widget.sineta?.acerto() ?? Future<void>.value());
    }

    // Gravado no momento em que a questao termina, nao no Continuar: se o app
    // fechar entre uma coisa e outra, o que ja foi respondido nao se perde.
    unawaited(
      widget.progresso?.registrar(
            licao: widget.licao,
            questao: questao,
            sessao: _sessao,
          ) ??
          Future<void>.value(),
    );
  }

  void _continuar() {
    _foco.unfocus();
    final proximo = _indice + 1;

    if (proximo >= widget.licao.questions.length) {
      // Licao terminada: a proxima abertura recomeca do inicio, ja que ainda
      // nao existe tela de escolha de licao.
      unawaited(_salvarPosicao(0));
      widget.aoMudarQuestao?.call(0);
      setState(() => _licaoConcluida = true);
      return;
    }

    unawaited(_salvarPosicao(proximo));
    widget.aoMudarQuestao?.call(proximo);
    // O texto guardado pertence a questao que acabou de sair. Sem zerar aqui,
    // a resposta da anterior reapareceria na proxima.
    widget.aoMudarTexto?.call('');
    setState(() {
      _indice = proximo;
      // Depois de `_indice`, senao a sessao nasceria para a questao que saiu.
      _sessao = _sessaoNova();
      _texto.clear();
      temMaisAbaixo = false;
    });
    if (rolagem.hasClients) rolagem.jumpTo(0);
    WidgetsBinding.instance.addPostFrameCallback((_) => conferirRecorte());
  }

  Future<void> _salvarPosicao(int indice) async {
    await widget.progresso?.salvarPosicao(widget.licao.lessonId, indice);
  }

  void _avisarTexto() => widget.aoMudarTexto?.call(_texto.text);

  Future<void> _lerSom() async {
    final ligado = await widget.progresso?.somLigado();
    if (!mounted || ligado == null) return;
    setState(() => _som = ligado);
  }

  /// Desliga o som sem sair da questão.
  ///
  /// Antes a única chave ficava na trilha, e silenciar o app no meio de uma
  /// lição exigia sair dela. Pior: sair e voltar era justamente o caminho que
  /// caía no defeito da posição perdida — o Gustavo encontrou os dois de uma
  /// vez, e um levou ao outro.
  Future<void> _alternarSom() async {
    final novo = !_som;
    setState(() => _som = novo);
    await widget.progresso?.definirSom(ligado: novo);
  }

  void _inserirSimbolo(String simbolo) {
    final selecao = _texto.selection;
    final base = _texto.text;
    final inicio = selecao.isValid ? selecao.start : base.length;
    final fim = selecao.isValid ? selecao.end : base.length;
    final novo = base.replaceRange(inicio, fim, simbolo);
    _texto.value = TextEditingValue(
      text: novo,
      selection: TextSelection.collapsed(offset: inicio + simbolo.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_licaoConcluida) {
      return _FimDaLicao(licao: widget.licao);
    }

    final questao = _questaoAtual;
    final total = widget.licao.questions.length;
    final tecladoAberto = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: Paleta.fundo,
      body: SafeArea(
        child: Column(
          children: [
            _Topo(
              atual: _indice + 1,
              total: total,
              aoRelerAula: widget.aoRelerAula,
              somLigado: _som,
              aoAlternarSom: widget.progresso == null ? null : _alternarSom,
            ),
            Expanded(
              child: comSombraDeRecorte(
                chaveSombra: TelaExercicio.chaveSombra,
                rolavel: ListView(
                      controller: rolagem,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      children: [
                        _Chip(licao: widget.licao, questao: questao),
                        const SizedBox(height: 12),
                        // O enunciado destaca nome de funcao e tipo, para o
                        // aluno separar o que e da linguagem do que e
                        // portugues. Ver texto_rico.dart.
                        textoComTermos(
                          questao.prompt,
                          linguagem: widget.licao.language,
                          estilo: const TextStyle(
                            color: Paleta.texto,
                            fontSize: Escala.enunciado,
                            height: 1.4,
                          ),
                        ),
                        if (questao.code != null) ...[
                          const SizedBox(height: 14),
                          BlocoCodigo(code: questao.code!),
                        ],
                        if (_sessao.dicaAberta) ...[
                          const SizedBox(height: 14),
                          _PainelDica(texto: questao.hint),
                        ],
                        const SizedBox(height: 16),
                        // O molde da resposta, visivel ANTES do primeiro erro.
                        //
                        // O Gustavo escreveu a linha inteira -- `if (saldo > 0)
                        // { console.log(...) }` -- numa questao que pedia so
                        // ate a chave de abertura. O codigo estava certo, e foi
                        // marcado errado. O enunciado nao tinha como comunicar
                        // ONDE PARAR, e descobrir isso errando e frustracao sem
                        // aprendizado -- o contrario do que este app se propoe.
                        if (_sessao.ehEscrita &&
                            !_sessao.terminou &&
                            valeMostrarMolde(questao.accepted!.first)) ...[
                          _Molde(resposta: questao.accepted!.first),
                          const SizedBox(height: 12),
                        ],
                        if (_sessao.ehEscrita)
                          _CampoResposta(
                            controlador: _texto,
                            foco: _foco,
                            habilitado: !_sessao.terminou,
                            aoEnviar: _verificar,
                          )
                        else
                          _Alternativas(
                            sessao: _sessao,
                            aoTocar: (opcao) =>
                                setState(() => _sessao.selecionar(opcao)),
                          ),
                    if (_sessao.respostaRevelada != null) ...[
                      const SizedBox(height: 12),
                      _RespostaRevelada(texto: _sessao.respostaRevelada!),
                    ],
                  ],
                ),
              ),
            ),
            _PainelRetorno(sessao: _sessao),
            // A regua so aparece com o teclado virtual aberto. Ela existe para
            // poupar a troca de pagina do teclado do celular; quando se digita
            // com teclado fisico, como no emulador, ela so ocupa espaco.
            if (_sessao.ehEscrita && !_sessao.terminou && tecladoAberto)
              _ReguaDeSimbolos(aoTocar: _inserirSimbolo),
            _BarraAcoes(
              sessao: _sessao,
              temTexto: _texto.text.trim().isNotEmpty,
              aoAbrirDica: () => setState(_sessao.abrirDica),
              aoVerificar: _verificar,
              aoContinuar: _continuar,
            ),
            // Colada na borda, abaixo da barra de acoes. Congela com o teclado
            // aberto: nessa hora o que importa e o campo de resposta, e
            // movimento no canto do olho atrapalha quem esta digitando.
            // Some-la em vez de congelar faria o layout pular no meio da
            // digitacao, que e pior que o movimento.
            if (widget.comCenario)
              FaixaCenario(congelada: tecladoAberto),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- topo

class _Topo extends StatelessWidget {
  const _Topo({
    required this.atual,
    required this.total,
    this.aoRelerAula,
    this.somLigado = true,
    this.aoAlternarSom,
  });

  final int atual;
  final int total;
  final VoidCallback? aoRelerAula;

  final bool somLigado;

  /// Nulo quando não há repositório onde gravar a preferência: aí o ícone some,
  /// em vez de virar um botão que muda de desenho e não muda nada.
  final VoidCallback? aoAlternarSom;

  static const Key chaveReler = Key('acao-reler-aula');
  static const Key chaveSair = Key('acao-sair');
  static const Key chaveSom = Key('acao-som');

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Row(
        children: [
          // Sair nao pergunta "tem certeza": o progresso e salvo a cada
          // questao, entao perguntar seria ruido. maybePop em vez de pop
          // porque em teste de widget nao ha rota atras para voltar.
          GestureDetector(
            key: chaveSair,
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).maybePop(),
            child: const Text(
              '✕',
              style: TextStyle(color: Paleta.suave, fontSize: 22, height: 1),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Escala.barraAltura / 2),
              child: LinearProgressIndicator(
                // A barra mede a licao, nao a linguagem: barra que nao sai do
                // lugar desmotiva.
                value: atual / total,
                minHeight: Escala.barraAltura,
                backgroundColor: Paleta.trilho,
                valueColor: const AlwaysStoppedAnimation(Paleta.acerto),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Text(
            '$atual/$total',
            style: const TextStyle(
              color: Paleta.suave,
              fontFamily: fonteMono,
              fontSize: Escala.contador,
            ),
          ),
          // A aula fica a um toque durante o exercicio. Consultar o material no
          // meio da questao e estudo, nao cola: a explicacao continua so
          // aparecendo depois de responder.
          if (aoRelerAula != null) ...[
            const SizedBox(width: 12),
            GestureDetector(
              key: chaveReler,
              behavior: HitTestBehavior.opaque,
              onTap: aoRelerAula,
              child: const Icon(
                Icons.menu_book_outlined,
                color: Paleta.suave,
                size: 22,
              ),
            ),
          ],
          // O som se desliga aqui, sem sair da licao. A mesma chave da trilha,
          // e a mesma preferencia: sao dois botoes para um dado so.
          if (aoAlternarSom != null) ...[
            const SizedBox(width: 12),
            GestureDetector(
              key: chaveSom,
              behavior: HitTestBehavior.opaque,
              onTap: aoAlternarSom,
              child: Icon(
                somLigado
                    ? Icons.volume_up_outlined
                    : Icons.volume_off_outlined,
                color: somLigado ? Paleta.destaque : Paleta.suave,
                size: 22,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.licao, required this.questao});

  final Lesson licao;
  final Question questao;

  @override
  Widget build(BuildContext context) {
    return Text(
      [licao.language, licao.level.rotulo.toLowerCase(), questao.topic].join(' · '),
      style: const TextStyle(
        color: Paleta.destaque,
        fontFamily: fonteMono,
        fontSize: Escala.chip,
      ),
    );
  }
}

// ------------------------------------------------------- alternativas

class _Alternativas extends StatelessWidget {
  const _Alternativas({required this.sessao, required this.aoTocar});

  final SessaoQuestao sessao;
  final void Function(Option) aoTocar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final opcao in sessao.alternativas)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _Alternativa(
              opcao: opcao,
              sessao: sessao,
              aoTocar: () => aoTocar(opcao),
            ),
          ),
      ],
    );
  }
}

class _Alternativa extends StatelessWidget {
  const _Alternativa({
    required this.opcao,
    required this.sessao,
    required this.aoTocar,
  });

  final Option opcao;
  final SessaoQuestao sessao;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final eliminada = sessao.estaEliminada(opcao);
    final selecionada = sessao.selecionada?.id == opcao.id;
    final revelarCerta = sessao.terminou && opcao.correct;

    final (Color borda, Color? fundo) = switch (true) {
      _ when revelarCerta => (Paleta.certo, Paleta.certoTenue),
      _ when eliminada => (Paleta.erro, Paleta.erroTenue),
      _ when selecionada => (Paleta.destaque, Paleta.altSelecionadaFundo),
      _ => (Paleta.linha, null),
    };

    final conteudo = Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: fundo,
        border: Border.all(
          color: borda,
          width: revelarCerta || selecionada ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(Escala.raio),
      ),
      child: Text(
        opcao.text,
        style: TextStyle(
          color: Paleta.texto,
          fontFamily: fonteMono,
          fontSize: Escala.alternativa,
          height: 1.35,
          // Riscar deixa claro que a alternativa saiu da lista, sem apaga-la:
          // ver o que ja foi descartado faz parte do raciocinio por exclusao.
          decoration: eliminada ? TextDecoration.lineThrough : null,
          decorationColor: Paleta.erro,
        ),
      ),
    );

    if (eliminada) {
      return Opacity(opacity: 0.38, child: conteudo);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: sessao.terminou ? null : aoTocar,
      child: conteudo,
    );
  }
}

// -------------------------------------------------- resposta escrita

class _CampoResposta extends StatelessWidget {
  const _CampoResposta({
    required this.controlador,
    required this.foco,
    required this.habilitado,
    required this.aoEnviar,
  });

  final TextEditingController controlador;
  final FocusNode foco;
  final bool habilitado;
  final VoidCallback aoEnviar;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controlador,
      focusNode: foco,
      enabled: habilitado,
      autocorrect: false,
      enableSuggestions: false,
      // Codigo nao se escreve com a primeira letra maiuscula automatica.
      textCapitalization: TextCapitalization.none,
      inputFormatters: [FilteringTextInputFormatter.singleLineFormatter],
      onSubmitted: (_) => aoEnviar(),
      style: const TextStyle(
        color: Paleta.texto,
        fontFamily: fonteMono,
        fontSize: Escala.alternativa,
      ),
      cursorColor: Paleta.destaque,
      decoration: InputDecoration(
        hintText: 'Escreva aqui',
        hintStyle: const TextStyle(
          color: Paleta.suave,
          fontFamily: fonteMono,
          fontSize: Escala.alternativa,
        ),
        filled: true,
        fillColor: Paleta.ideFundo,
        contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Escala.raio),
          borderSide: const BorderSide(color: Paleta.linha),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Escala.raio),
          borderSide: const BorderSide(color: Paleta.destaque, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Escala.raio),
          borderSide: const BorderSide(color: Paleta.linha),
        ),
      ),
    );
  }
}

/// Regua de simbolos acima do teclado.
///
/// Parenteses, colchetes, dois pontos, asterisco e igual sao os caracteres que
/// mais aparecem no codigo das questoes e os mais escondidos no teclado do
/// celular, atras de troca de pagina.
class _ReguaDeSimbolos extends StatelessWidget {
  const _ReguaDeSimbolos({required this.aoTocar});

  final void Function(String) aoTocar;

  static const List<String> simbolos = ['(', ')', '[', ']', ':', '*', '='];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          for (final simbolo in simbolos)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => aoTocar(simbolo),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: Paleta.ideAba,
                      border: Border.all(color: Paleta.linha),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      simbolo,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Paleta.texto,
                        fontFamily: fonteMono,
                        fontSize: Escala.alternativa,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RespostaRevelada extends StatelessWidget {
  const _RespostaRevelada({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: Paleta.certoTenue,
        border: Border.all(color: Paleta.certo, width: 2),
        borderRadius: BorderRadius.circular(Escala.raio),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'A RESPOSTA ERA',
            style: TextStyle(
              color: Paleta.certo,
              fontFamily: fonteMono,
              fontSize: 11,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            texto,
            style: const TextStyle(
              color: Paleta.texto,
              fontFamily: fonteMono,
              fontSize: Escala.alternativa,
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------ paineis

/// O formato esperado da resposta, com as letras escondidas.
///
/// Usa a mesma `esqueletoDe` que a sessao ja mostrava no terceiro erro: ela
/// troca letra e numero por `·` e preserva pontuacao, espacos e simbolos. Para
/// `if (saldo > 0) {` sai `·· (····· > ·) {`.
///
/// **O que ele entrega, e o que nao entrega.** Entrega o tamanho de cada nome e
/// a estrutura -- e portanto onde a resposta termina, que era o problema.
/// Continua sem dizer QUAIS sao os nomes nem qual funcao chamar, que e o que a
/// questao cobra. Um aluno que nao sabe `console.log` nao acerta olhando pontos.
///
/// Fonte monoespacada e obrigatoria aqui: os `·` precisam alinhar com o que a
/// pessoa digita para a comparacao ser possivel a olho.
class _Molde extends StatelessWidget {
  const _Molde({required this.resposta});

  final String resposta;

  static const Key chave = Key('molde-da-resposta');

  @override
  Widget build(BuildContext context) {
    return Container(
      key: chave,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Paleta.superficie,
        borderRadius: BorderRadius.circular(Escala.raio),
        border: Border.all(color: Paleta.linha),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'A resposta tem este formato:',
            style: TextStyle(color: Paleta.suave, fontSize: 12),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            // O molde nao quebra linha, pelo mesmo motivo do bloco de codigo:
            // quebrar destroi o alinhamento, e alinhamento e a informacao.
            scrollDirection: Axis.horizontal,
            child: Text(
              esqueletoDe(resposta),
              style: const TextStyle(
                color: Paleta.destaque,
                fontFamily: fonteMono,
                fontSize: Escala.codigo,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PainelDica extends StatelessWidget {
  const _PainelDica({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: Paleta.telemetria, width: 3)),
        color: Paleta.superficie,
      ),
      child: Text(
        texto,
        style: const TextStyle(
          color: Paleta.texto,
          fontSize: Escala.alternativa,
          height: 1.45,
        ),
      ),
    );
  }
}

/// Painel fixo acima da barra de acoes, com o retorno da tentativa.
///
/// Fica fixo porque e o pagamento do exercicio: a explicacao nao pode depender
/// de o aluno rolar a tela para descobrir que ela existe.
class _PainelRetorno extends StatelessWidget {
  const _PainelRetorno({required this.sessao});

  final SessaoQuestao sessao;

  static const Key chaveAcerto = Key('retorno-acerto');
  static const Key chaveErro = Key('retorno-erro');
  static const Key chaveRevelado = Key('retorno-revelado');

  @override
  Widget build(BuildContext context) {
    final explicacao = sessao.explicacao;
    final recado = sessao.recado;

    if (explicacao == null && recado == null) {
      return const SizedBox.shrink();
    }

    // Verde para certo, vermelho para errado, so em rotulo e borda. O corpo da
    // explicacao continua em Paleta.texto: verde saturado em texto longo sobre
    // fundo escuro reprova em contraste, e essa regra nao se negocia.
    //
    // O vermelho pinta a cor, nao o tom: o titulo continua sendo "AINDA NÃO", e
    // ao revelar continua "VAMOS JUNTOS". A mecanica nao pune, e a escrita
    // acompanha isso mesmo com a cor de alerta.
    final cor = switch (sessao.fase) {
      FaseResposta.acertou => Paleta.certo,
      FaseResposta.revelado => Paleta.certo,
      FaseResposta.respondendo => Paleta.erro,
    };
    final titulo = switch (sessao.fase) {
      FaseResposta.acertou => 'CERTO',
      FaseResposta.revelado => 'VAMOS JUNTOS',
      FaseResposta.respondendo => 'AINDA NÃO',
    };
    final chave = switch (sessao.fase) {
      FaseResposta.acertou => chaveAcerto,
      FaseResposta.revelado => chaveRevelado,
      FaseResposta.respondendo => chaveErro,
    };

    return Container(
      key: chave,
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: Paleta.superficie,
        border: Border(left: BorderSide(color: cor, width: 3)),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(Escala.raio),
          bottomRight: Radius.circular(Escala.raio),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            titulo,
            style: TextStyle(
              color: cor,
              fontFamily: fonteMono,
              fontSize: 11,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 168),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    explicacao ?? recado!,
                    style: const TextStyle(
                      color: Paleta.texto,
                      fontSize: Escala.alternativa,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------ barra de acoes

class _BarraAcoes extends StatelessWidget {
  const _BarraAcoes({
    required this.sessao,
    required this.temTexto,
    required this.aoAbrirDica,
    required this.aoVerificar,
    required this.aoContinuar,
  });

  final SessaoQuestao sessao;
  final bool temTexto;
  final VoidCallback aoAbrirDica;
  final VoidCallback aoVerificar;
  final VoidCallback aoContinuar;

  static const Key chaveVerificar = Key('acao-verificar');
  static const Key chaveContinuar = Key('acao-continuar');
  static const Key chaveDica = Key('acao-dica');

  @override
  Widget build(BuildContext context) {
    final terminou = sessao.terminou;

    // Verificar so habilita quando ha o que verificar: alternativa marcada, ou
    // texto digitado.
    final podeVerificar = sessao.ehEscrita ? temTexto : sessao.selecionada != null;
    final habilitado = terminou || podeVerificar;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: Row(
        children: [
          // Dica e acao secundaria: contornada, amarela. Se tivesse o mesmo peso
          // do Verificar, viraria o caminho de menor resistencia.
          if (!terminou)
            GestureDetector(
              key: chaveDica,
              behavior: HitTestBehavior.opaque,
              onTap: sessao.dicaAberta ? null : aoAbrirDica,
              child: Opacity(
                opacity: sessao.dicaAberta ? 0.4 : 1,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Paleta.telemetria),
                    borderRadius: BorderRadius.circular(Escala.raio),
                  ),
                  child: const Text(
                    'Dica',
                    style: TextStyle(
                      color: Paleta.telemetria,
                      fontSize: Escala.dica,
                    ),
                  ),
                ),
              ),
            ),
          if (!terminou) const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              key: terminou ? chaveContinuar : chaveVerificar,
              behavior: HitTestBehavior.opaque,
              onTap: habilitado ? (terminou ? aoContinuar : aoVerificar) : null,
              child: Opacity(
                opacity: habilitado ? 1 : 0.35,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Paleta.acerto,
                    borderRadius: BorderRadius.circular(Escala.raio),
                  ),
                  child: Text(
                    terminou ? 'Continuar' : 'Verificar',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Paleta.sobreAcerto,
                      fontSize: Escala.verificar,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FimDaLicao extends StatelessWidget {
  const _FimDaLicao({required this.licao});

  final Lesson licao;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: TelaExercicio.chaveFimDaLicao,
      backgroundColor: Paleta.fundo,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'LIÇÃO CONCLUÍDA',
                  style: TextStyle(
                    color: Paleta.visor,
                    fontFamily: fonteMono,
                    fontSize: 12,
                    letterSpacing: 2.4,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  licao.lessonTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Paleta.texto,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${licao.questions.length} questões',
                  style: const TextStyle(
                    color: Paleta.suave,
                    fontFamily: fonteMono,
                    fontSize: Escala.chip,
                  ),
                ),
                const SizedBox(height: 28),
                GestureDetector(
                  key: TelaExercicio.chaveVoltarDaLicao,
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).maybePop(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Paleta.acerto,
                      borderRadius: BorderRadius.circular(Escala.raio),
                    ),
                    child: const Text(
                      'Voltar à trilha',
                      style: TextStyle(
                        color: Paleta.sobreAcerto,
                        fontSize: Escala.verificar,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
