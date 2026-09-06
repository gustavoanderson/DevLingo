/// Modelo de uma questão do DevLingo.
///
/// Espelha `tools/question.schema.json`. O princípio central do formato precisa
/// sobreviver à tradução para Dart: uma questão separa **o que ela mostra** do
/// **como é respondida**. O campo [code] é opcional e independente de
/// [answerType], o que permite qualquer combinação — teórica pura, teórica com
/// código, lacuna com código, escrita livre — sem criar tipos novos.
///
/// Não quebre essa separação.
library;

/// Como o usuário responde. Independente do que a questão mostra.
enum AnswerType {
  multipleChoice,
  fillBlank,
  freeWrite;

  static AnswerType fromJson(String valor) => switch (valor) {
    'multipleChoice' => AnswerType.multipleChoice,
    'fillBlank' => AnswerType.fillBlank,
    'freeWrite' => AnswerType.freeWrite,
    _ => throw FormatException('answerType desconhecido: "$valor"'),
  };

  /// Lacuna e escrita livre compartilham o mesmo mecanismo de correção:
  /// comparação normalizada contra uma lista de respostas aceitas.
  bool get ehEscrita =>
      this == AnswerType.fillBlank || this == AnswerType.freeWrite;
}

/// Bloco de código exibido na IDE simulada. Ausente em questões puramente
/// teóricas — e presente em questões de qualquer [AnswerType].
class CodeBlock {
  /// Usada apenas para o realce de sintaxe. Pode diferir da linguagem da lição.
  final String language;
  final String content;

  /// Linha destacada, contando a partir de 1. Nulo quando não há destaque.
  final int? highlightLine;

  const CodeBlock({
    required this.language,
    required this.content,
    this.highlightLine,
  });

  /// Marcador da lacuna nas questões de [AnswerType.fillBlank].
  static const String marcadorLacuna = '______';

  bool get temLacuna => content.contains(marcadorLacuna);

  /// O código nunca quebra linha na tela: quebra automática destrói a
  /// indentação, e indentação em Python é sintaxe. A rolagem é horizontal.
  List<String> get linhas => content.split('\n');

  factory CodeBlock.fromJson(Map<String, dynamic> json) => CodeBlock(
    language: json['language'] as String,
    content: json['content'] as String,
    highlightLine: json['highlightLine'] as int?,
  );
}

/// Uma alternativa de múltipla escolha.
///
/// O [id] (`a` a `e`) é rótulo de autoria, para revisão em pull request e para
/// a explicação se referir a uma alternativa. **Não define a posição na tela**:
/// as alternativas são embaralhadas a cada exibição, e [correct] viaja junto
/// com o objeto.
class Option {
  final String id;
  final String text;
  final bool correct;

  /// Opcional. Por que **esta** alternativa esta errada.
  ///
  /// Aparece no momento em que o aluno a escolhe. Nunca entrega qual e a certa:
  /// se entregasse, a eliminacao progressiva perderia o sentido, porque bastaria
  /// errar uma vez para saber a resposta. O papel de explicar a certa cabe a
  /// [Question.explanation], que so aparece no fim.
  ///
  /// Nulo quando a questao nao tem esse detalhamento. Nesse caso o app mostra
  /// uma linha neutra. O validador exige que ou todas as alternativas erradas
  /// tenham o campo, ou nenhuma tenha.
  final String? why;

  const Option({
    required this.id,
    required this.text,
    required this.correct,
    this.why,
  });

  factory Option.fromJson(Map<String, dynamic> json) => Option(
    id: json['id'] as String,
    text: json['text'] as String,
    correct: json['correct'] as bool,
    why: json['why'] as String?,
  );
}

/// O que ignorar antes de comparar uma resposta escrita.
///
/// Os padrões são os mesmos do esquema JSON, para que uma questão sem o campo
/// `normalize` se comporte igual no app e no validador.
class NormalizeRules {
  /// Ignora **apenas espaços irrelevantes**, os que tocam pontuação ou
  /// operador. O espaço obrigatório entre duas palavras é sempre exigido.
  final bool spaces;
  final bool quotes;
  final bool trailingSemicolon;
  final bool caseSensitive;

  const NormalizeRules({
    this.spaces = true,
    this.quotes = true,
    this.trailingSemicolon = true,
    this.caseSensitive = false,
  });

  factory NormalizeRules.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const NormalizeRules();
    return NormalizeRules(
      spaces: json['spaces'] as bool? ?? true,
      quotes: json['quotes'] as bool? ?? true,
      trailingSemicolon: json['trailingSemicolon'] as bool? ?? true,
      caseSensitive: json['caseSensitive'] as bool? ?? false,
    );
  }
}

/// Uma questão do banco.
class Question {
  /// Identificador imutável. O progresso do usuário aponta para ele.
  final String id;

  /// Assunto. Base para revisão dirigida no futuro.
  final String topic;

  /// Enunciado. Sempre presente, mesmo quando há bloco de código.
  final String prompt;

  /// Opcional e **independente** de [answerType].
  final CodeBlock? code;

  final AnswerType answerType;

  /// Exclusivo de [AnswerType.multipleChoice]. Sempre 5 itens, sempre 1 correto.
  final List<Option>? options;

  /// Exclusivo das respostas escritas. Lista de respostas consideradas certas.
  final List<String>? accepted;

  final NormalizeRules normalize;

  /// Ajuda quem travou sem entregar a resposta.
  final String hint;

  /// Aparece depois de responder. É onde o aprendizado acontece.
  final String explanation;

  const Question({
    required this.id,
    required this.topic,
    required this.prompt,
    this.code,
    required this.answerType,
    this.options,
    this.accepted,
    required this.normalize,
    required this.hint,
    required this.explanation,
  });

  /// A alternativa correta. Só existe em múltipla escolha.
  Option get alternativaCorreta =>
      options!.firstWhere((alternativa) => alternativa.correct);

  factory Question.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final answerType = AnswerType.fromJson(json['answerType'] as String);

    final optionsJson = json['options'] as List<dynamic>?;
    final acceptedJson = json['accepted'] as List<dynamic>?;

    // O validador em Python já reprova estas combinações antes de qualquer
    // arquivo entrar no repositório. A checagem é repetida aqui porque um
    // asset corrompido ou editado à mão não passa pelo validador, e falhar
    // alto na hora de carregar é melhor que renderizar uma questão sem
    // resposta possível.
    if (answerType == AnswerType.multipleChoice) {
      if (optionsJson == null) {
        throw FormatException('$id: multipleChoice sem "options".');
      }
      if (acceptedJson != null) {
        throw FormatException('$id: multipleChoice não pode ter "accepted".');
      }
    } else {
      if (acceptedJson == null) {
        throw FormatException('$id: ${answerType.name} sem "accepted".');
      }
      if (optionsJson != null) {
        throw FormatException(
          '$id: ${answerType.name} não pode ter "options".',
        );
      }
    }

    final codeJson = json['code'] as Map<String, dynamic>?;

    return Question(
      id: id,
      topic: json['topic'] as String,
      prompt: json['prompt'] as String,
      code: codeJson == null ? null : CodeBlock.fromJson(codeJson),
      answerType: answerType,
      options: optionsJson
          ?.map((item) => Option.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
      accepted: acceptedJson
          ?.map((item) => item as String)
          .toList(growable: false),
      normalize: NormalizeRules.fromJson(
        json['normalize'] as Map<String, dynamic>?,
      ),
      hint: json['hint'] as String,
      explanation: json['explanation'] as String,
    );
  }
}
