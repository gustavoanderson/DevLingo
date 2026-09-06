import 'question.dart';

/// Nível da trilha. As abreviações de três letras são as que aparecem nos
/// identificadores: `python-beg-01`, `python-int-01`, `python-adv-01`.
enum Level {
  beginner('beg', 'Iniciante'),
  intermediate('int', 'Intermediário'),
  advanced('adv', 'Avançado');

  const Level(this.abreviacao, this.rotulo);

  final String abreviacao;
  final String rotulo;

  static Level fromJson(String valor) => switch (valor) {
    'beginner' => Level.beginner,
    'intermediate' => Level.intermediate,
    'advanced' => Level.advanced,
    _ => throw FormatException('level desconhecido: "$valor"'),
  };
}

/// Uma lição: o arquivo inteiro de `app/assets/content/<linguagem>/`.
class Lesson {
  /// Versão do formato. Permite ler arquivos antigos sem quebrar.
  final int schemaVersion;

  final String language;
  final Level level;

  /// Identificador imutável da lição. Nunca reutilizar nem renumerar.
  final String lessonId;

  final String lessonTitle;
  final List<Question> questions;

  const Lesson({
    required this.schemaVersion,
    required this.language,
    required this.level,
    required this.lessonId,
    required this.lessonTitle,
    required this.questions,
  });

  /// Número da lição extraído do identificador: `python-beg-03` devolve 3.
  ///
  /// A lição `00` é a de referência do formato e não faz parte da trilha.
  int get numero => int.parse(lessonId.split('-').last);

  bool get ehLicaoDeReferencia => numero == 0;

  factory Lesson.fromJson(Map<String, dynamic> json) => Lesson(
    schemaVersion: json['schemaVersion'] as int,
    language: json['language'] as String,
    level: Level.fromJson(json['level'] as String),
    lessonId: json['lessonId'] as String,
    lessonTitle: json['lessonTitle'] as String,
    questions: (json['questions'] as List<dynamic>)
        .map((item) => Question.fromJson(item as Map<String, dynamic>))
        .toList(growable: false),
  );
}
