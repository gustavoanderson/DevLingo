import 'dart:math';

import '../models/question.dart';
import 'normalize.dart';

/// Em que ponto da resposta a questao esta.
enum FaseResposta {
  /// O aluno ainda pode responder.
  respondendo,

  /// Acertou. A explicacao aparece e o caminho segue.
  acertou,

  /// Esgotou as tentativas. A resposta certa e mostrada junto da explicacao.
  ///
  /// Nao e punicao: o objetivo do jogo e a pessoa aprender, nao ficar presa.
  revelado,
}

/// O estado de uma questao enquanto o aluno responde.
///
/// Vive fora do widget de proposito: a regra de quantas tentativas, o que
/// eliminar e quando revelar e o coracao do app, e testa-la sem montar tela e
/// mais rapido e mais confiavel.
///
/// ## Multipla escolha
///
/// Errar **elimina** a alternativa escolhida e devolve a vez. Com cinco
/// alternativas, quatro erros deixariam so a correta na lista, e fazer o aluno
/// tocar nela nao ensinaria nada: seria clicar no unico botao disponivel
/// fingindo que e escolha. Por isso o quarto erro ja revela.
///
/// ## Lacuna e escrita livre
///
/// Nao ha o que eliminar, entao a ajuda cresce a cada erro, em quatro degraus:
/// primeiro so avisa, depois abre a dica sozinha, depois mostra a **forma** da
/// resposta com os nomes escondidos, e so entao revela. Sem essa escada, ou o
/// aluno trava sem nunca descobrir a resposta, ou recebe tudo de uma vez e nao
/// aprende nada no caminho.
class SessaoQuestao {
  SessaoQuestao(this.questao, {Random? sorteio})
    : alternativas = _embaralhar(questao.options, sorteio);

  final Question questao;

  /// As alternativas na ordem em que aparecem na tela.
  ///
  /// Embaralhadas a cada exibicao. Os ids `a`-`e` do banco sao rotulo de
  /// autoria, nao posicao: sem embaralhar, refazer a licao viraria decoreba de
  /// posicao.
  final List<Option> alternativas;

  static const int _tentativasNaEscrita = 4;

  FaseResposta fase = FaseResposta.respondendo;

  /// A alternativa marcada, ainda nao verificada.
  Option? selecionada;

  /// Ids das alternativas ja tentadas e descartadas.
  final Set<String> eliminadas = {};

  /// Quantas vezes o aluno apertou Verificar.
  ///
  /// A tela nao mostra isso e nao pune. O numero existe para o progresso poder
  /// distinguir, mais tarde, o que foi facil do que custou — que e o que torna
  /// revisao dirigida possivel.
  int tentativas = 0;

  bool dicaAberta = false;

  /// Recado curto exibido depois de uma tentativa errada.
  ///
  /// Nunca e a [Question.explanation]: mostra-la no primeiro erro entregaria a
  /// resposta e esvaziaria a eliminacao.
  String? recado;

  /// A forma da resposta, com os nomes escondidos. Ultimo degrau antes de
  /// revelar, so nas questoes de escrita. Fica separado do [recado] porque
  /// precisa ser exibido em fonte monoespacada para os `·` alinharem.
  String? esqueleto;

  static List<Option> _embaralhar(List<Option>? opcoes, Random? sorteio) {
    if (opcoes == null) return const [];
    final copia = [...opcoes];
    copia.shuffle(sorteio ?? Random());
    return List.unmodifiable(copia);
  }

  bool get ehEscrita => questao.answerType.ehEscrita;
  bool get terminou =>
      fase == FaseResposta.acertou || fase == FaseResposta.revelado;

  Option get correta => questao.alternativaCorreta;

  bool estaEliminada(Option opcao) => eliminadas.contains(opcao.id);

  /// A explicacao completa so aparece no fim, nunca durante as tentativas.
  String? get explicacao => terminou ? questao.explanation : null;

  /// A resposta revelada, para quando o aluno esgotou as tentativas na escrita.
  String? get respostaRevelada =>
      fase == FaseResposta.revelado && ehEscrita ? questao.accepted!.first : null;

  void selecionar(Option opcao) {
    if (terminou || estaEliminada(opcao)) return;
    selecionada = opcao;
    recado = null;
  }

  void abrirDica() {
    if (terminou) return;
    dicaAberta = true;
  }

  /// Verifica a alternativa marcada. So vale para multipla escolha.
  void verificar() {
    final escolha = selecionada;
    if (terminou || escolha == null) return;

    tentativas++;

    if (escolha.correct) {
      fase = FaseResposta.acertou;
      recado = null;
      return;
    }

    eliminadas.add(escolha.id);
    selecionada = null;
    recado =
        escolha.why ??
        'Não é essa. Ela saiu da lista; escolha outra e tente de novo.';

    // Sobrou apenas a correta: revelar em vez de pedir o toque cerimonial.
    if (eliminadas.length >= alternativas.length - 1) {
      fase = FaseResposta.revelado;
    }
  }

  /// Verifica o texto digitado. So vale para lacuna e escrita livre.
  void verificarEscrita(String texto) {
    if (terminou) return;
    if (texto.trim().isEmpty) return;

    tentativas++;

    if (respondeuCerto(questao, texto)) {
      fase = FaseResposta.acertou;
      recado = null;
      esqueleto = null;
      return;
    }

    if (tentativas >= _tentativasNaEscrita) {
      fase = FaseResposta.revelado;
      recado = null;
      esqueleto = null;
      return;
    }

    switch (tentativas) {
      case 2:
        dicaAberta = true;
        recado = 'Ainda não. Abri a dica para ajudar.';
      case 3:
        // Ultimo degrau: mostra a forma, esconde os nomes. Sintaxe e o que a
        // questao ensina; os nomes o enunciado ja disse.
        esqueleto = esqueletoDe(questao.accepted!.first);
        recado =
            'Quase lá. A resposta tem esta forma, com as letras escondidas:';
      default:
        recado = 'Não é isso ainda. Leia o enunciado com calma e tente de novo.';
    }
  }
}
