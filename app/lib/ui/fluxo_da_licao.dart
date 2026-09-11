import 'dart:async';

import 'package:flutter/material.dart';

import '../answer/sessao_questao.dart';
import '../data/progresso.dart';
import '../models/lesson.dart';
import 'som.dart';
import 'tela_aula.dart';
import 'tela_exercicio.dart';

/// Decide entre mostrar a aula e mostrar as questões.
///
/// A aula aparece **sozinha na primeira vez** que a lição abre. Depois disso
/// ela continua acessível pelo ícone no topo do exercício, mas não se impõe:
/// quem já leu não precisa passar por ela de novo para chegar nas questões.
class FluxoDaLicao extends StatefulWidget {
  const FluxoDaLicao({
    super.key,
    required this.licao,
    this.progresso,
    this.indiceInicial = 0,
    this.aulaJaVista = false,
    this.sineta,
    this.comCenario = false,
  });

  final Lesson licao;
  final RegistroDeProgresso? progresso;
  final int indiceInicial;

  /// Se o aluno já viu a aula desta lição em alguma sessão anterior.
  final bool aulaJaVista;

  final Sineta? sineta;

  /// Repassado direto para a tela de exercício, que é quem desenha o cenário.
  /// O fluxo não decide nada sobre ele: só carrega a preferência da trilha.
  final bool comCenario;

  @override
  State<FluxoDaLicao> createState() => _FluxoDaLicaoState();
}

class _FluxoDaLicaoState extends State<FluxoDaLicao> {
  late bool _mostrandoAula = widget.licao.aula != null && !widget.aulaJaVista;

  /// Verdadeiro quando a aula foi aberta de novo, a pedido, no meio do exercício.
  bool _relendo = false;

  /// Em que questão o aluno está agora.
  ///
  /// Precisa morar **aqui**, e não só na tela de exercício, porque abrir a aula
  /// desmonta aquela tela: `_mostrandoAula` troca `TelaExercicio` por
  /// `TelaAula`, o State do exercício é descartado, e ao voltar ele renasceria
  /// em `widget.indiceInicial` — o índice de quando a lição abriu.
  ///
  /// Foi um defeito real relatado pelo Gustavo: consultar o material na questão
  /// 7 devolvia para a 5, mandando refazer o que já estava feito. Este campo é
  /// o que sobrevive à troca de tela.
  late int _indice = widget.indiceInicial;

  /// O que o aluno já digitou na questão atual.
  ///
  /// Mesmo motivo de [_indice], e o defeito era irmão: consultar a aula no
  /// meio de uma resposta apagava o que estava escrito, porque o controlador
  /// de texto morre junto com a tela desmontada. Quem estava terminando de
  /// escrever uma linha voltava para um campo vazio.
  String _texto = '';

  /// A sessão da questão atual: tentativas, alternativas eliminadas, se já
  /// terminou e como.
  ///
  /// Terceiro campo desta família, pelo mesmo motivo dos dois de cima — e o
  /// defeito era o mais grave. Quem acertava e ia consultar a aula **sem
  /// avançar** voltava para a questão zerada, tendo que responder de novo.
  ///
  /// E responder de novo grava de novo: o id do evento carrega o instante,
  /// então a segunda resposta vira uma **partida a mais no histórico**, e um
  /// erro nela reescreveria o acerto que já estava salvo.
  ///
  /// Guarda a sessão inteira, e não campo a campo: ela é mutável e a tela muta
  /// o próprio objeto, então esta referência basta. Campo novo em
  /// `SessaoQuestao` passa a sobreviver sem ninguém lembrar de propagá-lo.
  SessaoQuestao? _sessao;

  void _comecar() {
    if (!_relendo) {
      unawaited(
        widget.progresso?.marcarAulaVista(widget.licao.lessonId) ??
            Future<void>.value(),
      );
    }
    setState(() {
      _mostrandoAula = false;
      _relendo = false;
    });
  }

  void _reler() => setState(() {
    _mostrandoAula = true;
    _relendo = true;
  });

  @override
  Widget build(BuildContext context) {
    if (_mostrandoAula) {
      return TelaAula(
        licao: widget.licao,
        aoComecar: _comecar,
        rotuloDoBotao: _relendo ? 'Voltar às questões' : 'Começar as questões',
      );
    }

    return TelaExercicio(
      licao: widget.licao,
      progresso: widget.progresso,
      indiceInicial: _indice,
      aoRelerAula: widget.licao.aula == null ? null : _reler,
      // Sem `setState`: nada nesta tela depende do valor para desenhar, e
      // reconstruir a cada virada de questão seria trabalho jogado fora. Ele
      // só é lido quando o exercício remonta, depois da aula.
      aoMudarQuestao: (indice) => _indice = indice,
      textoInicial: _texto,
      aoMudarTexto: (texto) => _texto = texto,
      sessaoInicial: _sessao,
      // Sem `setState`, pela mesma razão de `aoMudarQuestao`: nada aqui desenha
      // a partir dela. E é obrigatório que seja assim — a tela avisa a sessão
      // nova durante o próprio `build`, e um `setState` ali seria erro.
      aoMudarSessao: (sessao) => _sessao = sessao,
      sineta: widget.sineta,
      comCenario: widget.comCenario,
    );
  }
}
