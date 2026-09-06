import 'package:flutter/material.dart';

import '../models/lesson.dart';
import '../models/question.dart';
import 'bloco_codigo.dart';
import 'paleta.dart';

/// A tela de exercicio.
///
/// Layout decidido em `docs/mockup-tela-exercicio.html` e no CLAUDE.md:
///
/// - **Fixo no topo:** botao sair, barra de progresso da licao, contador
/// - **Rola no meio:** chip de topico, enunciado, bloco de codigo, alternativas
/// - **Fixo no rodape:** barra de acoes com Dica e Verificar
///
/// O mockup e HTML estatico e desenha a barra de acoes rolando junto com o
/// miolo, porque nao consegue demonstrar a divisao. O CLAUDE.md e a autoridade
/// aqui: a barra fica fixa.
///
/// Ainda sem interacao. Responder, embaralhar e a dica entram no passo seguinte.
class TelaExercicio extends StatefulWidget {
  const TelaExercicio({
    super.key,
    required this.licao,
    required this.indice,
  });

  final Lesson licao;

  /// Posicao da questao dentro da licao, contando de zero.
  final int indice;

  /// Permite ao teste conferir a sombra sem depender de detalhe de pintura.
  static const Key chaveSombra = Key('sombra-de-recorte');

  @override
  State<TelaExercicio> createState() => _TelaExercicioState();
}

class _TelaExercicioState extends State<TelaExercicio> {
  final ScrollController _rolagem = ScrollController();

  /// Ha conteudo abaixo do que esta visivel.
  ///
  /// Sem essa sombra o usuario nao descobre a quinta alternativa: a tela parece
  /// terminar onde o recorte termina.
  bool _temMaisAbaixo = false;

  @override
  void initState() {
    super.initState();
    _rolagem.addListener(_conferirRecorte);
    WidgetsBinding.instance.addPostFrameCallback((_) => _conferirRecorte());
  }

  @override
  void dispose() {
    _rolagem.removeListener(_conferirRecorte);
    _rolagem.dispose();
    super.dispose();
  }

  void _conferirRecorte() {
    if (!_rolagem.hasClients) return;
    final posicao = _rolagem.position;
    final cortado = posicao.maxScrollExtent - posicao.pixels > 1;
    if (cortado != _temMaisAbaixo) {
      setState(() => _temMaisAbaixo = cortado);
    }
  }

  Question get _questao => widget.licao.questions[widget.indice];

  @override
  Widget build(BuildContext context) {
    final questao = _questao;
    final total = widget.licao.questions.length;

    return Scaffold(
      backgroundColor: Paleta.fundo,
      body: SafeArea(
        child: Column(
          children: [
            _Topo(atual: widget.indice + 1, total: total),
            Expanded(
              child: Stack(
                children: [
                  // NotificationListener pega a metrica no primeiro layout, que
                  // e quando o conteudo ainda nem foi medido pelo controlador.
                  NotificationListener<ScrollMetricsNotification>(
                    onNotification: (_) {
                      WidgetsBinding.instance.addPostFrameCallback(
                        (_) => _conferirRecorte(),
                      );
                      return false;
                    },
                    child: ListView(
                      controller: _rolagem,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      children: [
                        _Chip(licao: widget.licao, questao: questao),
                        const SizedBox(height: 12),
                        Text(
                          questao.prompt,
                          style: const TextStyle(
                            color: Paleta.texto,
                            fontSize: Escala.enunciado,
                            height: 1.4,
                          ),
                        ),
                        if (questao.code != null) ...[
                          const SizedBox(height: 14),
                          BlocoCodigo(code: questao.code!),
                        ],
                        const SizedBox(height: 16),
                        if (questao.options != null)
                          _Alternativas(opcoes: questao.options!),
                      ],
                    ),
                  ),
                  if (_temMaisAbaixo)
                    const Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: IgnorePointer(
                        child: _SombraDeRecorte(key: TelaExercicio.chaveSombra),
                      ),
                    ),
                ],
              ),
            ),
            const _BarraAcoes(),
          ],
        ),
      ),
    );
  }
}

class _Topo extends StatelessWidget {
  const _Topo({required this.atual, required this.total});

  final int atual;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Row(
        children: [
          // Sair nao pergunta "tem certeza": o progresso e salvo a cada questao,
          // entao perguntar seria ruido.
          const Text(
            '✕',
            style: TextStyle(color: Paleta.suave, fontSize: 22, height: 1),
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
    final partes = [
      licao.language,
      licao.level.rotulo.toLowerCase(),
      questao.topic,
    ];
    return Text(
      partes.join(' · '),
      style: const TextStyle(
        color: Paleta.destaque,
        fontFamily: fonteMono,
        fontSize: Escala.chip,
      ),
    );
  }
}

class _Alternativas extends StatelessWidget {
  const _Alternativas({required this.opcoes});

  final List<Option> opcoes;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final opcao in opcoes)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Paleta.linha),
                borderRadius: BorderRadius.circular(Escala.raio),
              ),
              child: Text(
                opcao.text,
                style: const TextStyle(
                  color: Paleta.texto,
                  fontFamily: fonteMono,
                  fontSize: Escala.alternativa,
                  height: 1.35,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Degrade no limite do miolo, avisando que ha conteudo cortado abaixo.
class _SombraDeRecorte extends StatelessWidget {
  const _SombraDeRecorte({super.key});

  @override
  Widget build(BuildContext context) {
    // O degrade termina num tom mais fundo que o fundo da tela. Terminar na
    // propria cor do fundo deixaria a sombra invisivel: ela so escurece o que
    // estiver por baixo, e no limite do miolo costuma haver so a borda fina de
    // um cartao. Com o tom mais escuro, o degrade se ve mesmo sobre area vazia.
    return Container(
      height: 44,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Paleta.veu.withValues(alpha: 0),
            Paleta.veu.withValues(alpha: 0.75),
            Paleta.veu,
          ],
          stops: const [0, 0.55, 1],
        ),
      ),
    );
  }
}

class _BarraAcoes extends StatelessWidget {
  const _BarraAcoes();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Row(
        children: [
          // Dica e acao secundaria: contornada, amarela. Se tivesse o mesmo peso
          // do Verificar, viraria o caminho de menor resistencia.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
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
          const SizedBox(width: 10),
          // Verificar e a unica acao primaria: preenchida, magenta.
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Paleta.acerto,
                borderRadius: BorderRadius.circular(Escala.raio),
              ),
              child: const Text(
                'Verificar',
                textAlign: TextAlign.center,
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
    );
  }
}
