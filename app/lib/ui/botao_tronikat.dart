/// O botão que chama o Tr∅nikAt, flutuando no canto.
///
/// **No CANTO, e não no topo** — e essa correção nasceu de um erro meu. O
/// Gustavo pediu a IA *"rodando no cantinho"*, igual ao navegador, e eu pus um
/// ícone discreto na barra de cima, junto do sair e das licenças. Ele instalou
/// a v1.9.0 e relatou: *"não apareceu o popup do tronikat no app"*.
///
/// O botão **estava lá**. Mas estava onde ninguém procurou, do tamanho dos
/// controles de sistema, e só numa das telas — se a pessoa entrasse direto
/// numa trilha, não havia nada. Recurso que não se encontra é igual a recurso
/// que não existe, que é a mesma razão pela qual a janela do navegador ganhou
/// o balão de três pontinhos.
///
/// Ele aparece na **escolha de trilha** e na **trilha**, e fica fora da tela de
/// exercício: lá a ação principal é responder, e um mascote conversável ao
/// lado do campo seria um convite a pedir a resposta — que ele não pode dar,
/// porque nem enxerga a questão.
library;

import 'package:flutter/material.dart';

import '../data/tronikat.dart';
import '../models/lesson.dart';
import '../data/question_bank.dart';
import '../data/progresso.dart';
import '../data/dossie.dart';
import 'chamada_tronikat.dart';
import 'janela_tronikat.dart';
import 'paleta.dart';
import 'tronikat_codec.dart';

class BotaoTronikat extends StatefulWidget {
  /// Monta o dossie do app: todas as trilhas do banco, contra o progresso.
  ///
  /// Mora aqui, e nao em `dossie.dart`, porque `QuestionBank` carrega asset e
  /// **importa Flutter** -- e `dossie.dart` precisa continuar compilando para
  /// JavaScript, que e o que faz o navegador usar a mesma regra em vez de uma
  /// segunda escrita a mao.
  ///
  /// Devolve nulo quando nao ha progresso a consultar. A janela entende isso
  /// como "nao pergunte", e a placa `meu-progresso` responde mandando entrar.
  static Future<String> Function()? dossieDe(
    QuestionBank banco,
    RegistroDeProgresso? progresso,
  ) {
    if (progresso == null) return null;
    return () async {
      // TODAS as trilhas, e nao so aquela em que a pessoa esta. A pergunta
      // "o que eu faco agora?" nao respeita a tela em que foi feita, e um
      // conselho que ignora as outras quatro trilhas e um conselho pela
      // metade.
      final trilhas = <List<Lesson>>[
        for (final language in banco.linguagens)
          for (final level in Level.values)
            if (banco.trilha(language, level).isNotEmpty)
              banco.trilha(language, level),
      ];
      return montarDossie(
        trilhasParaDossie(trilhas),
        await progresso.respondidasPorLicao(),
        deCabeca: (await progresso.resumoDoJogador()).deCabeca,
      );
    };
  }

  const BotaoTronikat({
    super.key,
    this.consultor,
    this.dossie,
    this.comChamada = false,
  });

  /// Mostra o balão de três pontinhos acima do botão.
  ///
  /// **Falso por padrão, e o app passa verdadeiro** -- exatamente como
  /// `comCena` em `cena_do_login.dart`, e pelo mesmo motivo: animação em
  /// `repeat()` faz `pumpAndSettle` esperar para sempre, e isso já derrubou
  /// doze testes daquela tela de uma vez. Com o padrão falso, quem escreve um
  /// teste novo de trilha não tropeça.
  final bool comChamada;

  /// Repassado a janela. Ver `JanelaTronikat.dossie`.
  final Future<String> Function()? dossie;

  /// Injetável para teste: o de verdade fala com a rede, e teste de widget
  /// roda em tempo falso, onde I/O nunca avança.
  final ConsultorDoTronikat? consultor;

  static const String id = 'tronikat-botao';
  static const Key chave = Key(id);

  @override
  State<BotaoTronikat> createState() => _BotaoTronikatState();
}

class _BotaoTronikatState extends State<BotaoTronikat> {
  /// A chamada some ao primeiro toque e NÃO volta ao fechar a janela.
  ///
  /// Quem já sabe que ele existe não precisa de um balão pulsando para
  /// sempre: aviso que não para de avisar vira ruído. É a mesma disciplina
  /// que fez o app recusar sugerir o modo desafio.
  ///
  /// E ela volta na abertura seguinte, porque isto não é guardado em lugar
  /// nenhum: quem abre o app de novo é, para efeito de descoberta, alguém
  /// chegando.
  bool _jaTocou = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (widget.comChamada && !_jaTocou) ...[
          const ChamadaTronikat(),
          const SizedBox(height: 10),
        ],
        _botao(context),
      ],
    );
  }

  Widget _botao(BuildContext context) {
    return Semantics(
      identifier: BotaoTronikat.id,
      label: 'Falar com o Tr∅nikAt',
      button: true,
      child: FloatingActionButton(
        key: BotaoTronikat.chave,
        onPressed: () {
          if (!_jaTocou) setState(() => _jaTocou = true);
          JanelaTronikat.abrir(
              context, widget.consultor ?? TronikatDaBorda(),
              dossie: widget.dossie);
        },
        backgroundColor: Paleta.superficie,
        foregroundColor: Paleta.visor,
        tooltip: 'Falar com o Tr∅nikAt',
        // A BORDA CIANO é o que o separa do fundo. Sem ela o botão é um
        // círculo roxo sobre fundo roxo, que foi metade do problema de ele não
        // ter sido achado.
        shape: const CircleBorder(
          side: BorderSide(color: Paleta.destaque, width: 2),
        ),
        child: ClipOval(
          // O ROSTO, e não um ícone genérico. Quem vê o gato sabe com quem vai
          // falar; um balãozinho de chat seria qualquer aplicativo.
          child: SizedBox(
            width: 52,
            height: 52,
            child: FittedBox(
              fit: BoxFit.cover,
              // O codec é 128x96, mais largo que alto. Recortado no círculo,
              // sobra a cabeça, que é o que identifica.
              alignment: Alignment.topCenter,
              // PARADO, e por economia medida: o codec anima para sempre, e
              // num ícone de 52px isso é repintura a cada quadro enquanto a
              // tela estiver aberta -- bateria por um piscar que ninguém vê
              // nesse tamanho. Quem se move é a janela, onde ele fala.
              //
              // Quem encontrou isso foi o teste: `pumpAndSettle` estourou,
              // porque animação em `repeat()` nunca assenta. Mesmo sintoma que
              // a faixa de cenário já deu na trilha.
              child: const TronikatCodec(largura: 80, parado: true),
            ),
          ),
        ),
      ),
    );
  }
}
