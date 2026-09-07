import 'package:flutter/material.dart';

import '../data/progresso.dart';
import 'paleta.dart';

/// O desempenho do aluno, a partir do que o banco vem medindo desde a versão 4.
///
/// A coleta ficou meses sem tela, de propósito: dado não medido não se
/// reconstrói — ninguém consegue descobrir depois quanto tempo alguém levou
/// numa questão já respondida. A medição tinha que começar antes de alguém
/// jogar; a tela podia esperar. Ela é o fim daquela espera.
///
/// ## Ela recebe os dados prontos, e não o banco
///
/// [resumo] e [topicos] chegam já carregados, o que faz dela um widget puro:
/// testável sem SQLite e sem I/O, que na zona de tempo falso do `testWidgets`
/// nunca avançaria. Quem abre é que consulta — ver [abrir].
///
/// ## Três regras de tom, e todas vêm da mecânica do jogo
///
/// - **Nada de "você está pior que ontem".** O app inteiro foi desenhado para
///   não punir: errar não termina a questão, e o título diz `AINDA NÃO` em vez
///   de `ERRADO`. Estatística que cobra é a mesma punição em forma de número
/// - **Tempo não vira competição.** Ele aparece para a pessoa se conhecer,
///   nunca como meta a bater — pressa é inimiga de entender. Por isso é o único
///   cartão sem cor de acento
/// - **O nulo é dito em voz alta.** Partidas anteriores à medição não têm tempo
///   nem dica, e fingir que têm é o único jeito de esta tela mentir. Ver
///   [_Rodape]
class TelaEstatisticas extends StatelessWidget {
  const TelaEstatisticas({
    super.key,
    required this.resumo,
    required this.topicos,
    this.aoVoltar,
  });

  final ResumoDoJogador resumo;
  final List<CustoDoTopico> topicos;
  final VoidCallback? aoVoltar;

  static const Key chaveVazio = Key('estatisticas-vazio');
  static const Key chaveVoltar = Key('estatisticas-voltar');
  static const Key chaveTopicos = Key('estatisticas-topicos');
  static const Key chaveBarra = Key('estatisticas-barra');
  static const Key chaveRodape = Key('estatisticas-rodape');

  /// Consulta e abre. Existe para quem chama não precisar saber que são duas
  /// consultas, nem em que ordem elas vêm.
  static Future<void> abrir(
    BuildContext context,
    RegistroDeProgresso progresso,
  ) async {
    final resumo = await progresso.resumoDoJogador();
    final topicos = await progresso.custoPorTopico();
    if (!context.mounted) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (contextoDaTela) => TelaEstatisticas(
          resumo: resumo,
          topicos: topicos,
          aoVoltar: () => Navigator.of(contextoDaTela).pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Paleta.fundo,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Cabecalho(aoVoltar: aoVoltar),
            Expanded(
              child: resumo.respondidas == 0
                  ? const _Vazio()
                  : _Conteudo(resumo: resumo, topicos: topicos),
            ),
          ],
        ),
      ),
    );
  }
}

class _Cabecalho extends StatelessWidget {
  const _Cabecalho({this.aoVoltar});

  final VoidCallback? aoVoltar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          if (aoVoltar != null) ...[
            GestureDetector(
              key: TelaEstatisticas.chaveVoltar,
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
          const Expanded(
            child: Text(
              'Seu desempenho',
              style: TextStyle(
                color: Paleta.texto,
                fontFamily: fonteMono,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                shadows: [
                  Shadow(color: Paleta.destaque, offset: Offset(-1.5, 0)),
                  Shadow(color: Paleta.acerto, offset: Offset(1.5, 0)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Quem ainda não jogou nada.
///
/// Sem isto, a tela mostraria "0%" e "0 de 0" — números que **parecem um
/// resultado ruim** quando na verdade não há resultado nenhum. Seria a tela
/// cobrando de alguém que ainda não teve chance, que é justamente o que ela
/// não pode fazer.
///
/// ## Encosta no topo, e não no centro
///
/// A primeira versão usava `Center`, e no emulador ficou bem. Num Xiaomi 15T
/// Pro de 2772 pixels de altura ficou **quase mil pixels de nada** entre o
/// título e a mensagem, e o resultado lê como tela travada carregando, não
/// como recado.
///
/// Centralizar no espaço restante é uma decisão que só se enxerga em tela
/// alta: quanto mais espaço sobra, mais o conteúdo afunda. Encostado no topo o
/// vão sobra **embaixo**, que é onde toda lista curta deixa sobrar e ninguém
/// estranha — a própria trilha faz isso com cinco lições.
class _Vazio extends StatelessWidget {
  const _Vazio();

  /// Respiro abaixo do cabeçalho. Fixo de propósito: proporcional à altura
  /// recriaria o problema que esta classe existe para resolver.
  static const double respiro = 56;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: TelaEstatisticas.chaveVazio,
      // Rola porque em tela baixa com fonte ampliada pelo sistema o bloco
      // passa da altura disponível, e aí ele precisa caber de algum jeito.
      padding: const EdgeInsets.fromLTRB(32, respiro, 32, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          Icon(Icons.insights_outlined, color: Paleta.linha, size: 56),
          SizedBox(height: 18),
          Text(
            'Ainda não há o que mostrar',
            style: TextStyle(
              color: Paleta.texto,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 10),
          Text(
            'Responda algumas questões e volte aqui. Estes números existem '
            'para você se conhecer, não para cobrar nada.',
            style: TextStyle(
              color: Paleta.suave,
              fontSize: 14,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _Conteudo extends StatelessWidget {
  const _Conteudo({required this.resumo, required this.topicos});

  final ResumoDoJogador resumo;
  final List<CustoDoTopico> topicos;

  /// Quantas terminaram com acerto, mas depois de mais de uma tentativa.
  ///
  /// Sai por subtração porque o banco não guarda esta categoria: ela é o que
  /// sobra entre o total, as de primeira e as reveladas. As três somam
  /// exatamente [ResumoDoJogador.respondidas], e é isso que deixa a barra de
  /// [_Desfechos] ser lida como um inteiro repartido.
  int get _comInsistencia =>
      resumo.respondidas - resumo.deCabeca - resumo.reveladas;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _Numeros(resumo: resumo),
        const SizedBox(height: 26),
        _Desfechos(
          deCabeca: resumo.deCabeca,
          comInsistencia: _comInsistencia,
          reveladas: resumo.reveladas,
        ),
        if (topicos.isNotEmpty) ...[
          const SizedBox(height: 26),
          _Topicos(key: TelaEstatisticas.chaveTopicos, topicos: topicos),
        ],
        const SizedBox(height: 26),
        _Rodape(resumo: resumo),
      ],
    );
  }
}

/// Os quatro números de topo.
class _Numeros extends StatelessWidget {
  const _Numeros({required this.resumo});

  final ResumoDoJogador resumo;

  static String _tempo(Duration? d) {
    if (d == null) return '—';
    if (d.inMinutes < 1) return '${d.inSeconds}s';
    return '${d.inMinutes}min ${d.inSeconds % 60}s';
  }

  @override
  Widget build(BuildContext context) {
    final media = resumo.tempoMedioPorQuestao;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _Cartao(
                valor: '${resumo.respondidas}',
                rotulo: 'questões respondidas',
                cor: Paleta.destaque,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Cartao(
                valor: '${(resumo.taxaDeCabeca * 100).round()}%',
                rotulo: 'saíram de primeira',
                cor: Paleta.certo,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _Cartao(
                valor: _tempo(media),
                // "em média por questao", e nunca "seu tempo": a diferenca de
                // palavra e a diferenca entre se conhecer e competir consigo
                // mesmo. E o unico cartao sem cor de acento, pelo mesmo motivo
                // -- destacar o tempo seria convidar a corrida.
                rotulo: media == null
                    ? 'tempo ainda não medido'
                    : 'em média por questão',
                cor: Paleta.linha,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Cartao(
                valor: '${resumo.diasEstudados}',
                rotulo: resumo.diasEstudados == 1
                    ? 'dia de estudo'
                    : 'dias de estudo',
                cor: Paleta.acerto,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Cartao extends StatelessWidget {
  const _Cartao({required this.valor, required this.rotulo, required this.cor});

  final String valor;
  final String rotulo;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
            valor,
            style: const TextStyle(
              color: Paleta.texto,
              fontFamily: fonteMono,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            rotulo,
            style: const TextStyle(
              color: Paleta.suave,
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Como as questões terminaram, numa barra só.
///
/// As três fatias somam o total, então a proporção se lê de relance, sem
/// comparar números. **Nenhuma delas é vermelha**, e isso é a regra de tom
/// virando cor: revelar não é falhar, é o jeito que o app resolveu não deixar
/// ninguém preso — a tela de exercício diz `VAMOS JUNTOS` nessa hora, e o
/// amarelo aqui é o mesmo já usado na Dica.
class _Desfechos extends StatelessWidget {
  const _Desfechos({
    required this.deCabeca,
    required this.comInsistencia,
    required this.reveladas,
  });

  final int deCabeca;
  final int comInsistencia;
  final int reveladas;

  static const double altura = 12;

  @override
  Widget build(BuildContext context) {
    final fatias = <(int, Color, String)>[
      (deCabeca, Paleta.certo, 'de primeira'),
      (comInsistencia, Paleta.destaque, 'insistindo'),
      (reveladas, Paleta.telemetria, 'vimos juntos'),
    ];
    if (fatias.every((f) => f.$1 <= 0)) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Titulo('Como as questões terminaram'),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: SizedBox(
            key: TelaEstatisticas.chaveBarra,
            height: altura,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              // `stretch` é obrigatório, e a falta dele deixou a barra
              // **invisível** num aparelho de verdade — 105 mil pixels da cor
              // do fundo onde deviam estar três faixas coloridas.
              //
              // O motivo é sutil: `ColoredBox` sem filho é um `RenderProxyBox`
              // sem filho, e esse caso resolve para `constraints.smallest`. O
              // `Expanded` torna a largura obrigatória, mas o alinhamento
              // padrão do `Row` (`center`) passa a **altura** frouxa, de 0 a
              // 12 — e `smallest` escolhe zero. A barra existia, ocupava o
              // espaço, e tinha altura nenhuma.
              children: [
                for (final (quantas, cor, _) in fatias)
                  if (quantas > 0)
                    Expanded(flex: quantas, child: ColoredBox(color: cor)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        for (final (quantas, cor, rotulo) in fatias)
          if (quantas > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: cor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '$quantas $rotulo',
                    style: const TextStyle(color: Paleta.texto, fontSize: 14),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

/// Onde o aluno mais insistiu, por tópico.
///
/// **O título não diz "onde você foi pior".** Diz onde custou mais, que é a
/// mesma informação sem o julgamento — e é a que serve para escolher o que
/// revisar. É o primeiro uso real do campo `topic`, que o banco de questões
/// carrega desde o começo justamente prevendo revisão dirigida.
class _Topicos extends StatelessWidget {
  const _Topicos({super.key, required this.topicos});

  final List<CustoDoTopico> topicos;

  /// Quantos tópicos cabem antes de a lista virar um relatório.
  static const int quantos = 6;

  @override
  Widget build(BuildContext context) {
    // `custoPorTopico` ja devolve do mais caro para o mais barato, entao o
    // corte e so pegar do comeco. So entram os que custaram mais de uma
    // tentativa: listar topicos com media 1,0 encheria a tela de linhas
    // dizendo "aqui voce foi bem", que nao ajudam a escolher o que revisar.
    final relevantes = topicos
        .where((t) => t.tentativasPorQuestao > 1)
        .take(quantos)
        .toList(growable: false);

    if (relevantes.isEmpty) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Titulo('Onde você mais insistiu'),
          SizedBox(height: 10),
          Text(
            'Nenhum tópico exigiu mais de uma tentativa até agora.',
            style: TextStyle(color: Paleta.suave, fontSize: 14, height: 1.4),
          ),
        ],
      );
    }

    final maior = relevantes.first.tentativasPorQuestao;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Titulo('Onde você mais insistiu'),
        const SizedBox(height: 4),
        const Text(
          'Média de tentativas por questão. Bom lugar para revisar.',
          style: TextStyle(color: Paleta.suave, fontSize: 12, height: 1.4),
        ),
        const SizedBox(height: 14),
        for (final t in relevantes)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        t.topic,
                        style: const TextStyle(
                          color: Paleta.texto,
                          fontFamily: fonteMono,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Text(
                      t.tentativasPorQuestao.toStringAsFixed(1),
                      style: const TextStyle(
                        color: Paleta.suave,
                        fontFamily: fonteMono,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    // Proporcional ao topico mais caro, e nao a um teto fixo:
                    // assim a barra compara os topicos ENTRE SI, que e a
                    // pergunta que a lista responde. Contra um teto qualquer,
                    // todas ficariam curtas e nada se distinguiria.
                    value: maior == 0 ? 0 : t.tentativasPorQuestao / maior,
                    minHeight: 8,
                    backgroundColor: Paleta.trilho,
                    valueColor: const AlwaysStoppedAnimation(Paleta.destaque),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// O que os números de cima não contam sozinhos.
///
/// Três honestidades, e nenhuma é rodapé de contrato: refazer uma lição conta
/// como partida mas não como questão nova; há partidas anteriores à medição,
/// que ficam fora da média de tempo; e a dica pedida é contada à parte. Sem
/// dizer isso, quem somasse os números concluiria que a tela está quebrada — ou
/// pior, acreditaria numa média que não é sobre tudo o que jogou.
class _Rodape extends StatelessWidget {
  const _Rodape({required this.resumo});

  final ResumoDoJogador resumo;

  @override
  Widget build(BuildContext context) {
    final semTempo = resumo.respondidas - resumo.questoesComTempo;
    final uma = semTempo == 1;
    final linhas = <String>[
      if (resumo.partidas > resumo.respondidas)
        'Você jogou ${resumo.partidas} vezes em ${resumo.respondidas} '
            'questões — refazer uma lição conta aqui.',
      if (semTempo > 0)
        '$semTempo ${uma ? "questão é" : "questões são"} de antes de o app '
            'medir tempo, então ${uma ? "ela fica" : "elas ficam"} fora da '
            'média.',
      if (resumo.comDica > 0)
        'Você pediu a dica em ${resumo.comDica} '
            '${resumo.comDica == 1 ? "questão" : "questões"}.',
    ];

    if (linhas.isEmpty) return const SizedBox.shrink();

    return Container(
      // A chave fica no container real, e nao no widget: assim `findsNothing`
      // num teste prova que o rodape SUMIU, e nao apenas que ele desenhou
      // vazio -- um `SizedBox.shrink` com chave passaria pelas duas coisas.
      key: TelaEstatisticas.chaveRodape,
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Paleta.superficie,
        borderRadius: BorderRadius.circular(Escala.raio),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final linha in linhas)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                linha,
                style: const TextStyle(
                  color: Paleta.suave,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Titulo extends StatelessWidget {
  const _Titulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: const TextStyle(
        color: Paleta.texto,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
