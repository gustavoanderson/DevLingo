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
import 'janela_tronikat.dart';
import 'paleta.dart';
import 'tronikat_codec.dart';

class BotaoTronikat extends StatelessWidget {
  const BotaoTronikat({super.key, this.consultor});

  /// Injetável para teste: o de verdade fala com a rede, e teste de widget
  /// roda em tempo falso, onde I/O nunca avança.
  final ConsultorDoTronikat? consultor;

  static const String id = 'tronikat-botao';
  static const Key chave = Key(id);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: id,
      label: 'Falar com o Tr∅nikAt',
      button: true,
      child: FloatingActionButton(
        key: chave,
        onPressed: () =>
            JanelaTronikat.abrir(context, consultor ?? TronikatDaBorda()),
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
