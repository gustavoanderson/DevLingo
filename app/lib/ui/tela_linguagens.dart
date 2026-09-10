import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/progresso.dart';
import '../data/question_bank.dart';
import '../models/lesson.dart';
import 'paleta.dart';
import 'som.dart';
import 'tela_trilha.dart';

/// Escolha da linguagem e do nível.
///
/// Só aparece quando há mais de uma trilha para escolher. Uma tela de escolha
/// com um item só é cerimônia vazia: se o banco tiver uma trilha apenas, o app
/// abre direto nela.
class TelaLinguagens extends StatefulWidget {
  const TelaLinguagens({
    super.key,
    required this.banco,
    this.progresso,
    this.aoVoltarAoTitulo,
    this.sineta,
    this.chegouDaNuvem,
  });

  final QuestionBank banco;
  final RegistroDeProgresso? progresso;

  /// Volta para a tela de título.
  ///
  /// Esta é a primeira tela depois do START, então não há nada na pilha de
  /// navegação para onde voltar: sem este caminho, **rever a tela de título
  /// exigiria fechar e reabrir o app**. Ela não é conteúdo consumível, é a
  /// abertura — e abertura que só se vê matando o processo é abertura perdida.
  final VoidCallback? aoVoltarAoTitulo;

  final Sineta? sineta;

  /// Sobe quando a sincronizacao traz progresso novo da nuvem.
  ///
  /// Esta tela consulta o banco uma vez, no `initState`. Sem escutar isto, o
  /// que chega depois so aparece ao navegar -- e progresso que nao aparece e
  /// indistinguivel de progresso perdido para quem esta olhando.
  final ValueNotifier<int>? chegouDaNuvem;

  static const Key chaveVoltarAoTitulo = Key('voltar-ao-titulo');

  /// As trilhas que existem de verdade, em ordem de linguagem e nível.
  ///
  /// A lição de referência do formato fica de fora — ninguém a joga.
  static List<({String language, Level level, List<Lesson> licoes})> trilhasDe(
    QuestionBank banco,
  ) {
    final trilhas = <({String language, Level level, List<Lesson> licoes})>[];
    for (final language in banco.linguagens) {
      for (final level in Level.values) {
        final licoes = banco.trilha(language, level);
        if (licoes.isNotEmpty) {
          trilhas.add((language: language, level: level, licoes: licoes));
        }
      }
    }
    return trilhas;
  }

  @override
  State<TelaLinguagens> createState() => _TelaLinguagensState();
}

class _TelaLinguagensState extends State<TelaLinguagens> {
  Map<String, int> _respondidas = const {};

  @override
  void initState() {
    super.initState();
    _recarregar();
    widget.chegouDaNuvem?.addListener(_recarregar);
  }

  @override
  void dispose() {
    widget.chegouDaNuvem?.removeListener(_recarregar);
    super.dispose();
  }

  Future<void> _recarregar() async {
    final contagem = await widget.progresso?.respondidasPorLicao();
    if (!mounted || contagem == null) return;
    setState(() => _respondidas = contagem);
  }

  Future<void> _abrir(String language, Level level) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => TelaTrilha(
          banco: widget.banco,
          language: language,
          level: level,
          progresso: widget.progresso,
          sineta: widget.sineta,
        ),
      ),
    );
    await _recarregar();
  }

  @override
  Widget build(BuildContext context) {
    final trilhas = TelaLinguagens.trilhasDe(widget.banco);

    return Scaffold(
      backgroundColor: Paleta.fundo,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            if (widget.aoVoltarAoTitulo != null) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: _BotaoTitulo(aoTocar: widget.aoVoltarAoTitulo!),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DevLingo',
                        style: TextStyle(
                          color: Paleta.texto,
                          fontFamily: fonteMono,
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          shadows: [
                            Shadow(
                              color: Paleta.destaque,
                              offset: Offset(-2, 0),
                            ),
                            Shadow(color: Paleta.acerto, offset: Offset(2, 0)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Escolha por onde começar.',
                        style: TextStyle(
                          color: Paleta.suave,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SvgPicture.asset(
                  'assets/mascot/tronikat.svg',
                  width: 82,
                  semanticsLabel: 'Tr∅nikAt, o mascote do DevLingo',
                ),
              ],
            ),
            const SizedBox(height: 26),
            for (final trilha in trilhas) ...[
              _CartaoDaTrilha(
                language: trilha.language,
                level: trilha.level,
                licoes: trilha.licoes,
                respondidas: trilha.licoes.fold<int>(
                  0,
                  (soma, l) => soma + (_respondidas[l.lessonId] ?? 0),
                ),
                aoTocar: () => _abrir(trilha.language, trilha.level),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

/// Botão discreto que devolve para a tela de título.
///
/// **Secundário de propósito.** A ação principal desta tela é escolher uma
/// trilha; voltar à abertura é um extra. Se ele tivesse o peso de um dos
/// cartões, competiria com a escolha que a tela existe para oferecer — o mesmo
/// raciocínio que faz a Dica ser contornada e o Verificar preenchido.
///
/// Não toca a ficha: a moeda é o som de **entrar** no fliperama. Voltar para a
/// tela de abertura não é inserir moeda; inserir moeda é o START de lá.
class _BotaoTitulo extends StatelessWidget {
  const _BotaoTitulo({required this.aoTocar});

  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      key: TelaLinguagens.chaveVoltarAoTitulo,
      onPressed: aoTocar,
      icon: const Icon(Icons.arrow_back, size: 16, color: Paleta.suave),
      label: const Text(
        'TELA DE INÍCIO',
        style: TextStyle(
          color: Paleta.suave,
          fontFamily: fonteMono,
          fontSize: 12,
          letterSpacing: 1.4,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        // Alvo de toque confortavel mesmo com o rotulo pequeno: o texto e
        // discreto por hierarquia, nao para ser dificil de acertar.
        minimumSize: const Size(0, 44),
        tapTargetSize: MaterialTapTargetSize.padded,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Escala.raio),
          side: const BorderSide(color: Paleta.linha),
        ),
      ),
    );
  }
}

class _CartaoDaTrilha extends StatelessWidget {
  const _CartaoDaTrilha({
    required this.language,
    required this.level,
    required this.licoes,
    required this.respondidas,
    required this.aoTocar,
  });

  final String language;
  final Level level;
  final List<Lesson> licoes;
  final int respondidas;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final total = licoes.fold<int>(0, (soma, l) => soma + l.questions.length);
    final completa = respondidas >= total && total > 0;

    // So no iniciante. A descricao diz o que a TRILHA cobre, e repeti-la nos
    // tres cartoes da mesma linguagem seria a mesma frase tres vezes seguidas
    // -- o que muda entre eles e o nivel, que a linha de baixo ja diz.
    final descricao = level == Level.beginner ? descricaoDe(language) : null;
    final cor = completa
        ? Paleta.certo
        : respondidas > 0
        ? Paleta.destaque
        : Paleta.linha;

    // O identificador repete a `Key`, e existe porque o `content-desc` NAO
    // serve para achar este cartao.
    //
    // Medido no aparelho: a descricao do cartao de Frameworks e
    // "0, Frameworks\nReact, Vue, ... melhor depois do JavaScript\n...". Um
    // filtro por "contem JavaScript" casaria com o cartao de JavaScript E com
    // este -- dois elementos para o mesmo seletor, e o teste ou falha confuso
    // ou acerta o cartao errado.
    //
    // Da para contornar com expressao regular. Contornar seria a resposta
    // errada: quando o seletor fica dificil, quem esta mal desenhado e o app.
    return Semantics(
      identifier: 'trilha-$language-${level.abreviacao}',
      child: GestureDetector(
        key: Key('trilha-$language-${level.abreviacao}'),
        behavior: HitTestBehavior.opaque,
        onTap: aoTocar,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
            children: [
              Text(
                nomeBonito(language),
                style: const TextStyle(
                  color: Paleta.texto,
                  fontFamily: fonteMono,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              // A descricao cola no nome, e os numeros ficam agrupados com a
              // barra. A hierarquia sai da PROXIMIDADE, e nao de uma cor nova:
              // descricao e metadados sao os dois `suave` em 13px, e inventar um
              // tom intermediario para separa-los mexeria numa paleta que e
              // documentada e ja foi julgada renderizada.
              if (descricao != null) ...[
                const SizedBox(height: 6),
                Text(
                  descricao,
                  style: const TextStyle(
                    color: Paleta.suave,
                    fontFamily: fonteMono,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
              SizedBox(height: descricao == null ? 4 : 12),
              Text(
                '${level.rotulo.toLowerCase()} · ${licoes.length} '
                '${licoes.length == 1 ? "lição" : "lições"} · '
                '$respondidas de $total questões',
                style: const TextStyle(
                  color: Paleta.suave,
                  fontFamily: fonteMono,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : respondidas / total,
                  minHeight: 8,
                  backgroundColor: Paleta.trilho,
                  valueColor: AlwaysStoppedAnimation(
                    cor == Paleta.linha ? Paleta.suave : cor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
