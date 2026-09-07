import 'package:flutter/material.dart';

import '../data/progresso.dart';
import '../data/question_bank.dart';
import '../models/lesson.dart';
import 'fluxo_da_licao.dart';
import 'paleta.dart';
import 'som.dart';
import 'tela_estatisticas.dart';
import 'sombra_de_recorte.dart';

/// A trilha de uma linguagem e nível: as lições em ordem, com o progresso.
///
/// **As lições não trancam.** Trancar puniria, e a mecânica inteira foi
/// desenhada para não punir — além de atrapalhar quem quer revisar uma lição
/// antiga ou espiar a seguinte. A trilha mostra onde o aluno está; não decide
/// por ele.
///
/// É também o primeiro lugar onde o progresso gravado a cada questão deixa de
/// ser dado guardado e vira algo que o aluno enxerga.
class TelaTrilha extends StatefulWidget {
  const TelaTrilha({
    super.key,
    required this.banco,
    required this.language,
    required this.level,
    this.progresso,
    this.podeVoltar = true,
    this.aoVoltarAoTitulo,
    this.sineta,
  });

  final QuestionBank banco;
  final String language;
  final Level level;
  final RegistroDeProgresso? progresso;

  /// Falso quando a trilha é a primeira tela, sem escolha de linguagem atrás.
  final bool podeVoltar;

  /// Volta para a tela de título. Só é usado quando [podeVoltar] é falso.
  ///
  /// Com uma linguagem só no banco, o app abre direto na trilha e não há
  /// escolha de linguagem atrás — então, sem isto, a seta de voltar sumiria e
  /// **rever a tela de título exigiria fechar e reabrir o app**. Em vez de um
  /// segundo botão, a seta que já existe muda de destino: ela sempre volta um
  /// passo, e qual é esse passo depende de por onde se entrou.
  final VoidCallback? aoVoltarAoTitulo;

  final Sineta? sineta;

  static const Key chaveSombra = Key('sombra-da-trilha');
  static const Key chaveSom = Key('trilha-som');
  static const Key chaveCenario = Key('trilha-cenario');
  static const Key chaveEstatisticas = Key('trilha-estatisticas');

  @override
  State<TelaTrilha> createState() => _TelaTrilhaState();
}

class _TelaTrilhaState extends State<TelaTrilha>
    with AvisaConteudoCortado<TelaTrilha> {
  /// Quantas questões já foram respondidas em cada lição.
  Map<String, int> _respondidas = const {};

  /// Ligado por padrão. Nunca é o único retorno: o verde e a explicação
  /// continuam funcionando com ele mudo.
  bool _som = true;

  /// O cenário animado da tela de exercício. Ligado por padrão.
  ///
  /// A chave fica aqui, ao lado da do som, porque são a mesma decisão do ponto
  /// de vista de quem joga: quanto de estímulo eu quero. Enterrá-la numa tela
  /// de configurações que ainda não existe seria escondê-la de quem precisa.
  bool _cenario = true;

  List<Lesson> get _licoes => widget.banco.trilha(widget.language, widget.level);

  @override
  void initState() {
    super.initState();
    iniciarAvisoDeRecorte();
    _recarregar();
  }

  @override
  void dispose() {
    encerrarAvisoDeRecorte();
    super.dispose();
  }

  Future<void> _recarregar() async {
    final progresso = widget.progresso;
    if (progresso == null) return;
    final contagem = await progresso.respondidasPorLicao();
    final som = await progresso.somLigado();
    final cenario = await progresso.cenarioLigado();
    if (!mounted) return;
    setState(() {
      _respondidas = contagem;
      _som = som;
      _cenario = cenario;
    });
  }

  Future<void> _alternarSom() async {
    final novo = !_som;
    setState(() => _som = novo);
    await widget.progresso?.definirSom(ligado: novo);
  }

  Future<void> _alternarCenario() async {
    final novo = !_cenario;
    setState(() => _cenario = novo);
    await widget.progresso?.definirCenario(ligado: novo);
  }

  Future<void> _abrir(Lesson licao) async {
    final progresso = widget.progresso;
    final indice = (await progresso?.posicaoDe(licao.lessonId) ?? 0).clamp(
      0,
      licao.questions.length - 1,
    );
    final aulaVista = await progresso?.aulaFoiVista(licao.lessonId) ?? false;
    if (!mounted) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => FluxoDaLicao(
          licao: licao,
          progresso: progresso,
          indiceInicial: indice,
          aulaJaVista: aulaVista,
          sineta: widget.sineta,
          comCenario: _cenario,
        ),
      ),
    );
    // Voltar da lição atualiza a trilha: o progresso mudou enquanto se jogava.
    await _recarregar();
  }

  /// Abre as estatísticas.
  ///
  /// Sem repositório não há o que medir, e por isso o ícone nem aparece: ele
  /// abriria uma tela que só saberia dizer "ainda não há o que mostrar", o que
  /// é pior que não oferecê-la. É o caso dos testes que montam a trilha sem
  /// progresso — ver [_Cabecalho.aoVerEstatisticas].
  Future<void> _verEstatisticas() async {
    await TelaEstatisticas.abrir(context, widget.progresso!);
  }

  @override
  Widget build(BuildContext context) {
    final licoes = _licoes;
    final totalQuestoes = licoes.fold<int>(
      0,
      (soma, l) => soma + l.questions.length,
    );
    final totalRespondidas = licoes.fold<int>(
      0,
      (soma, l) => soma + (_respondidas[l.lessonId] ?? 0),
    );

    return Scaffold(
      backgroundColor: Paleta.fundo,
      body: SafeArea(
        child: Column(
          children: [
            _Cabecalho(
              language: widget.language,
              level: widget.level,
              respondidas: totalRespondidas,
              total: totalQuestoes,
              aoVoltar: widget.podeVoltar
                  ? () => Navigator.of(context).pop()
                  : widget.aoVoltarAoTitulo,
              somLigado: _som,
              aoAlternarSom: _alternarSom,
              cenarioLigado: _cenario,
              aoAlternarCenario: _alternarCenario,
              aoVerEstatisticas:
                  widget.progresso == null ? null : _verEstatisticas,
            ),
            Expanded(
              child: comSombraDeRecorte(
                chaveSombra: TelaTrilha.chaveSombra,
                rolavel: ListView.separated(
                  controller: rolagem,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  itemCount: licoes.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final licao = licoes[i];
                    return _CartaoDaLicao(
                      licao: licao,
                      respondidas: _respondidas[licao.lessonId] ?? 0,
                      aoTocar: () => _abrir(licao),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Cabecalho extends StatelessWidget {
  const _Cabecalho({
    required this.language,
    required this.level,
    required this.respondidas,
    required this.total,
    required this.somLigado,
    required this.aoAlternarSom,
    required this.cenarioLigado,
    required this.aoAlternarCenario,
    this.aoVerEstatisticas,
    this.aoVoltar,
  });

  final String language;
  final Level level;
  final int respondidas;
  final int total;
  final bool somLigado;
  final VoidCallback aoAlternarSom;
  final bool cenarioLigado;
  final VoidCallback aoAlternarCenario;
  /// Nulo quando não há repositório de progresso: aí o ícone some.
  final VoidCallback? aoVerEstatisticas;
  final VoidCallback? aoVoltar;

  static const Key chaveVoltar = Key('trilha-voltar');

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (aoVoltar != null) ...[
                GestureDetector(
                  key: chaveVoltar,
                  behavior: HitTestBehavior.opaque,
                  onTap: aoVoltar,
                  child: const Icon(
                    Icons.arrow_back,
                    color: Paleta.suave,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                // Encolhe a fonte em vez de quebrar a linha.
                //
                // O titulo divide a faixa com a seta e tres icones, e sobram
                // cerca de 204px. "JavaScript" ocupa ~156px e cabe justo;
                // "Qualidade de Software" passa de 320px e quebraria em duas
                // ou tres linhas, empurrando a barra de progresso e os cartoes
                // para baixo -- e este cabecalho supoe uma linha so.
                //
                // `scaleDown` nao aumenta nada: nome que cabe continua nos
                // 26px de sempre, e so o que nao cabe encolhe. Sem isto, cada
                // nome novo vira aposta, e o banco preve nove linguagens que
                // ainda nao existem.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    nomeBonito(language),
                    style: const TextStyle(
                      color: Paleta.texto,
                      fontFamily: fonteMono,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      shadows: [
                        Shadow(color: Paleta.destaque, offset: Offset(-1.5, 0)),
                        Shadow(color: Paleta.acerto, offset: Offset(1.5, 0)),
                      ],
                    ),
                  ),
                ),
              ),
              // Estatisticas e NAVEGACAO, nao preferencia: ela leva a outra
              // tela em vez de mudar algo aqui. Fica separada das duas chaves
              // por isso, e vem antes delas porque e a acao, nao o ajuste.
              if (aoVerEstatisticas != null) ...[
                GestureDetector(
                  key: TelaTrilha.chaveEstatisticas,
                  behavior: HitTestBehavior.opaque,
                  onTap: aoVerEstatisticas,
                  child: const Icon(
                    Icons.insights_outlined,
                    color: Paleta.suave,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
              ],
              // Nao ha tela de configuracoes ainda. Sao duas chaves, e as duas
              // respondem a mesma pergunta de quem joga: quanto de estimulo eu
              // quero. Quando surgir a terceira, as tres migram para uma tela.
              GestureDetector(
                key: TelaTrilha.chaveCenario,
                behavior: HitTestBehavior.opaque,
                onTap: aoAlternarCenario,
                child: Icon(
                  cenarioLigado
                      ? Icons.landscape_outlined
                      : Icons.landscape_rounded,
                  color: cenarioLigado ? Paleta.destaque : Paleta.suave,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                key: TelaTrilha.chaveSom,
                behavior: HitTestBehavior.opaque,
                onTap: aoAlternarSom,
                child: Icon(
                  somLigado ? Icons.volume_up_outlined : Icons.volume_off_outlined,
                  color: somLigado ? Paleta.destaque : Paleta.suave,
                  size: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${level.rotulo.toLowerCase()} · $respondidas de $total questões',
            style: const TextStyle(
              color: Paleta.suave,
              fontFamily: fonteMono,
              fontSize: Escala.chip,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(Escala.barraAltura / 2),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : respondidas / total,
              minHeight: Escala.barraAltura,
              backgroundColor: Paleta.trilho,
              valueColor: const AlwaysStoppedAnimation(Paleta.acerto),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartaoDaLicao extends StatelessWidget {
  const _CartaoDaLicao({
    required this.licao,
    required this.respondidas,
    required this.aoTocar,
  });

  final Lesson licao;
  final int respondidas;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final total = licao.questions.length;
    final concluida = respondidas >= total;
    final comecada = respondidas > 0;

    // Lição concluída ganha o verde de acerto; começada, o ciano de destaque;
    // intocada fica na linha neutra. A cor diz o estado sem precisar de rótulo.
    final cor = concluida
        ? Paleta.certo
        : comecada
        ? Paleta.destaque
        : Paleta.linha;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: aoTocar,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Paleta.superficie,
          border: Border(left: BorderSide(color: cor, width: 3)),
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(Escala.raio),
            bottomRight: Radius.circular(Escala.raio),
          ),
        ),
        child: Row(
          children: [
            Text(
              '${licao.numero}'.padLeft(2, '0'),
              style: TextStyle(
                color: cor == Paleta.linha ? Paleta.suave : cor,
                fontFamily: fonteMono,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    licao.lessonTitle,
                    style: const TextStyle(
                      color: Paleta.texto,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    concluida ? 'concluída' : '$respondidas de $total',
                    style: TextStyle(
                      color: concluida ? Paleta.certo : Paleta.suave,
                      fontFamily: fonteMono,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (licao.aula != null)
              const Icon(
                Icons.menu_book_outlined,
                color: Paleta.suave,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}
