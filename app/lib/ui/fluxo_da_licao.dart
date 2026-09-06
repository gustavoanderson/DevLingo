import 'dart:async';

import 'package:flutter/material.dart';

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
  });

  final Lesson licao;
  final RegistroDeProgresso? progresso;
  final int indiceInicial;

  /// Se o aluno já viu a aula desta lição em alguma sessão anterior.
  final bool aulaJaVista;

  final Sineta? sineta;

  @override
  State<FluxoDaLicao> createState() => _FluxoDaLicaoState();
}

class _FluxoDaLicaoState extends State<FluxoDaLicao> {
  late bool _mostrandoAula = widget.licao.aula != null && !widget.aulaJaVista;

  /// Verdadeiro quando a aula foi aberta de novo, a pedido, no meio do exercício.
  bool _relendo = false;

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
      indiceInicial: widget.indiceInicial,
      aoRelerAula: widget.licao.aula == null ? null : _reler,
      sineta: widget.sineta,
    );
  }
}
