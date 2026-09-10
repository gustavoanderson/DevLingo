import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/lesson.dart';

/// Carrega o banco de questões empacotado em `assets/content/`.
///
/// As lições são **descobertas** pelo manifesto de assets, não listadas em
/// código. Acrescentar `python-beg-06.json` não exige mexer aqui — basta o
/// arquivo existir numa pasta de linguagem já declarada no `pubspec.yaml`.
///
/// O `pubspec.yaml` continua sendo o ponto que exige atenção: o Flutter não
/// empacota subpastas recursivamente, então cada pasta de linguagem precisa
/// estar listada lá. O validador em `tools/validate_questions.py` reprova
/// quando essa lista sai de sincronia com as pastas que existem.
class QuestionBank {
  static const String _prefixo = 'assets/content/';

  final List<Lesson> lessons;

  const QuestionBank(this.lessons);

  /// Todas as lições da trilha, fora a de referência do formato (`-00`).
  List<Lesson> get licoesDaTrilha =>
      lessons.where((licao) => !licao.ehLicaoDeReferencia).toList();

  int get totalDeQuestoes =>
      lessons.fold(0, (soma, licao) => soma + licao.questions.length);

  /// As trilhas que existem no banco, na ordem sugerida de aprendizado.
  ///
  /// Antes isto era `..sort()` puro, e a ordem alfabetica punha Frameworks
  /// acima de JavaScript -- a trilha que depende dele. Ver [ordemDasTrilhas].
  ///
  /// O desempate alfabetico no fim nao e decoracao: sem ele, duas trilhas fora
  /// da lista de ordem empatariam e a ordem entre elas passaria a depender de
  /// como o `Set` iterou, que e detalhe de implementacao e muda sem aviso.
  List<String> get linguagens =>
      lessons.map((licao) => licao.language).toSet().toList()
        ..sort((a, b) {
          final ordem = posicaoDaTrilha(a).compareTo(posicaoDaTrilha(b));
          return ordem != 0 ? ordem : a.compareTo(b);
        });

  /// As lições de uma linguagem e nível, em ordem de número.
  List<Lesson> trilha(String language, Level level) =>
      (lessons
            .where(
              (licao) =>
                  licao.language == language &&
                  licao.level == level &&
                  !licao.ehLicaoDeReferencia,
            )
            .toList())
        ..sort((a, b) => a.numero.compareTo(b.numero));

  static Future<QuestionBank> carregar({AssetBundle? bundle}) async {
    final pacote = bundle ?? rootBundle;

    final manifesto = await AssetManifest.loadFromAssetBundle(pacote);
    final caminhos =
        manifesto
            .listAssets()
            .where(
              (caminho) =>
                  caminho.startsWith(_prefixo) && caminho.endsWith('.json'),
            )
            .toList()
          ..sort();

    if (caminhos.isEmpty) {
      throw StateError(
        'Nenhuma lição encontrada em $_prefixo. '
        'Confira se as pastas de linguagem estão declaradas no pubspec.yaml.',
      );
    }

    final licoes = <Lesson>[];
    // O id da questao e imutavel e o progresso do usuario aponta para ele.
    // Duas questoes com o mesmo id fariam o progresso de uma sobrescrever o da
    // outra em silencio, entao a carga falha alto em vez de seguir adiante.
    final idsVistos = <String, String>{};

    for (final caminho in caminhos) {
      final cru = await pacote.loadString(caminho);
      final Lesson licao;
      try {
        licao = Lesson.fromJson(json.decode(cru) as Map<String, dynamic>);
      } on Object catch (erro) {
        throw FormatException('Falha ao ler $caminho: $erro');
      }

      for (final questao in licao.questions) {
        final anterior = idsVistos[questao.id];
        if (anterior != null) {
          throw StateError(
            'id de questão repetido: "${questao.id}" aparece em $anterior e em $caminho.',
          );
        }
        idsVistos[questao.id] = caminho;
      }

      licoes.add(licao);
    }

    return QuestionBank(List.unmodifiable(licoes));
  }
}
