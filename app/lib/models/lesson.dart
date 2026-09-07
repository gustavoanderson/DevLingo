import 'question.dart';

/// Como o nome da linguagem aparece na tela.
///
/// No banco a linguagem e uma chave em minusculas, boa para caminho de arquivo
/// e comparacao. Aqui ela vira o nome que as pessoas escrevem: `javascript` na
/// pasta, JavaScript na tela.
const Map<String, String> nomeDaLinguagem = {
  'python': 'Python',
  'javascript': 'JavaScript',
  'node': 'Node',

  /// Curso teorico de engenharia de backend. Nao e uma linguagem, e o campo
  /// `language` do banco continua servindo: ele identifica a TRILHA.
  ///
  /// O nome de tela e curto de proposito. O cabecalho da trilha usa mono de
  /// 26px e sobram cerca de 204px depois da seta e dos tres icones;
  /// "JavaScript" ocupa ~156px e cabe justo, enquanto "Fundamentos de Backend"
  /// passaria de 340px e quebraria em tres linhas.
  'backend': 'Backend',

  /// Engenharia de qualidade de software. Segundo curso que nao ensina uma
  /// linguagem -- ver o comentario de `backend` acima sobre o campo `language`
  /// identificar a TRILHA, e nao um idioma de programacao.
  ///
  /// "Qualidade" ocupa cerca de 140px na mono de 26px do cabecalho da trilha,
  /// dentro dos ~204px disponiveis. "Engenharia de Qualidade" passaria de 340px
  /// e quebraria a linha, pelo mesmo motivo que "Fundamentos de Backend".
  'qa': 'Qualidade',
  'html': 'HTML',
  'css': 'CSS',
  'sql': 'SQL',
  'csharp': 'C#',
  'golang': 'Go',
  'cpp': 'C++',
  'cobol': 'COBOL',
  'ruby': 'Ruby',
};

String nomeBonito(String chave) => nomeDaLinguagem[chave] ?? chave;

/// Uma parte da aula, preparando um topico especifico.
class SecaoDaAula {
  /// Qual `topic` das questoes esta secao prepara.
  ///
  /// E o que permite ao validador conferir, por conjunto e nao por semelhanca
  /// de texto, que a aula cobre tudo o que sera cobrado.
  final String topico;

  final String titulo;
  final String texto;

  /// Exemplo opcional. Mesmo bloco das questoes, entao a IDE em miniatura serve
  /// para os dois sem codigo duplicado.
  final CodeBlock? code;

  const SecaoDaAula({
    required this.topico,
    required this.titulo,
    required this.texto,
    this.code,
  });

  /// Paragrafos separados por linha em branco.
  List<String> get paragrafos => texto
      .split('\n\n')
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList(growable: false);

  factory SecaoDaAula.fromJson(Map<String, dynamic> json) {
    final codeJson = json['code'] as Map<String, dynamic>?;
    return SecaoDaAula(
      topico: json['topico'] as String,
      titulo: json['titulo'] as String,
      texto: json['texto'] as String,
      code: codeJson == null ? null : CodeBlock.fromJson(codeJson),
    );
  }
}

/// A apresentacao que o Tr0nikAt faz antes das questoes.
///
/// Mora no mesmo arquivo das questoes de proposito: aula e questoes escritas
/// juntas nao podem divergir. O validador reprova quando os topicos das duas
/// deixam de bater.
class Aula {
  final String titulo;
  final List<SecaoDaAula> secoes;

  const Aula({required this.titulo, required this.secoes});

  factory Aula.fromJson(Map<String, dynamic> json) => Aula(
    titulo: json['titulo'] as String,
    secoes: (json['secoes'] as List<dynamic>)
        .map((item) => SecaoDaAula.fromJson(item as Map<String, dynamic>))
        .toList(growable: false),
  );
}

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

  /// A aula introdutoria. Nula nas licoes que ainda nao a tem.
  final Aula? aula;

  const Lesson({
    required this.schemaVersion,
    required this.language,
    required this.level,
    required this.lessonId,
    required this.lessonTitle,
    required this.questions,
    this.aula,
  });

  /// Número da lição extraído do identificador: `python-beg-03` devolve 3.
  ///
  /// A lição `00` é a de referência do formato e não faz parte da trilha.
  int get numero => int.parse(lessonId.split('-').last);

  bool get ehLicaoDeReferencia => numero == 0;

  factory Lesson.fromJson(Map<String, dynamic> json) {
    final aulaJson = json['aula'] as Map<String, dynamic>?;
    return Lesson(
      schemaVersion: json['schemaVersion'] as int,
      language: json['language'] as String,
      level: Level.fromJson(json['level'] as String),
      lessonId: json['lessonId'] as String,
      lessonTitle: json['lessonTitle'] as String,
      questions: (json['questions'] as List<dynamic>)
          .map((item) => Question.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
      aula: aulaJson == null ? null : Aula.fromJson(aulaJson),
    );
  }
}
