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
  SessaoQuestao(this.questao, {Random? sorteio, DateTime Function()? relogio})
    : alternativas = _embaralhar(questao.options, sorteio),
      _relogio = relogio ?? DateTime.now {
    iniciadaEm = _relogio();
  }

  /// Injetavel para o teste nao depender do relogio de verdade.
  ///
  /// Sem isto, medir tempo tornaria a sessao impossivel de testar: o teste
  /// teria que esperar de verdade, ou aceitar qualquer numero, que e o mesmo
  /// que nao testar.
  final DateTime Function() _relogio;

  final Question questao;

  /// Quando a questao apareceu, e quando terminou. Viram a duracao gravada.
  late final DateTime iniciadaEm;
  DateTime? terminadaEm;

  /// Quanto tempo o aluno levou. Nulo enquanto a questao nao terminou.
  ///
  /// **Vem crua, sem teto.** Quem decide o que e uma medicao plausivel e o
  /// [Progresso], ao gravar: a sessao mede, o repositorio julga. Assim o teto
  /// tem um lugar so, em vez de um valor diferente em cada chamador.
  Duration? get duracao => terminadaEm?.difference(iniciadaEm);

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

  /// Se o painel da dica esta visivel, tendo sido pedido ou aberto sozinho.
  bool dicaAberta = false;

  /// Se o aluno **escolheu** abrir a dica, tocando no botao.
  ///
  /// Separado de [dicaAberta] de proposito. A dica tambem abre sozinha no
  /// segundo erro de uma questao de escrita, e contar isso como "usou a dica"
  /// transformaria "pedi ajuda" em "errei duas vezes" na estatistica. Sao duas
  /// coisas diferentes sobre o aluno, e so uma delas e escolha dele.
  bool dicaPedida = false;

  /// Recado curto exibido depois de uma tentativa errada.
  ///
  /// Nunca e a [Question.explanation]: mostra-la no primeiro erro entregaria a
  /// resposta e esvaziaria a eliminacao.
  String? recado;

  /// A forma da resposta, com os nomes escondidos.
  ///
  /// **Nao e mais preenchido**, e o campo continua aqui por compatibilidade
  /// com quem o leia. A forma passou a ser exibida desde o inicio da questao,
  /// e nao como ultimo degrau antes de revelar: descobrir ONDE A RESPOSTA
  /// TERMINA errando tres vezes e frustracao sem aprendizado.
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
    dicaPedida = true;
  }

  /// Encerra a questao, carimbando a hora.
  ///
  /// Toda saida de [FaseResposta.respondendo] passa por aqui. Atribuir `fase`
  /// direto em cada ramo funcionaria, e era assim antes -- mas bastaria um ramo
  /// novo esquecer o carimbo para a duracao sumir sem nada quebrar.
  void _concluir(FaseResposta desfecho) {
    fase = desfecho;
    terminadaEm = _relogio();
  }

  /// Verifica a alternativa marcada. So vale para multipla escolha.
  void verificar() {
    final escolha = selecionada;
    if (terminou || escolha == null) return;

    tentativas++;

    if (escolha.correct) {
      _concluir(FaseResposta.acertou);
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
      _concluir(FaseResposta.revelado);
    }
  }

  /// Verifica o texto digitado. So vale para lacuna e escrita livre.
  void verificarEscrita(String texto) {
    if (terminou) return;
    if (texto.trim().isEmpty) return;

    tentativas++;

    if (respondeuCerto(questao, texto)) {
      _concluir(FaseResposta.acertou);
      recado = null;
      esqueleto = null;
      return;
    }

    if (tentativas >= _tentativasNaEscrita) {
      _concluir(FaseResposta.revelado);
      recado = null;
      esqueleto = null;
      return;
    }

    switch (tentativas) {
      case 2:
        dicaAberta = true;
        recado = 'Ainda não. Abri a dica para ajudar.';
      case 3:
        // A forma da resposta ficava AQUI, no terceiro erro. Hoje ela e o
        // molde exibido desde o comeco -- ver `_Molde` em tela_exercicio.dart
        // --, entao repeti-la seria mostrar a mesma coisa duas vezes na tela.
        // O recado passa a apontar para o que ja esta la.
        recado =
            'Quase lá. Compare o que você escreveu com o formato mostrado '
            'acima do campo.';
      default:
        recado = 'Não é isso ainda. Leia o enunciado com calma e tente de novo.';
    }
  }
}
