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
    this.sineta,
  });

  final QuestionBank banco;
  final RegistroDeProgresso? progresso;
  final Sineta? sineta;

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
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          children: [
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
    final cor = completa
        ? Paleta.certo
        : respondidas > 0
        ? Paleta.destaque
        : Paleta.linha;

    return GestureDetector(
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
            const SizedBox(height: 4),
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
    );
  }
}
