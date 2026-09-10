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
  /// O nome e longo -- cerca de 328px na mono de 26px, contra os ~204px que
  /// sobram no cabecalho da trilha ao lado dos tres icones. Ele so cabe porque
  /// aquele titulo passou a encolher a fonte quando precisa; ver `_Cabecalho`
  /// em `tela_trilha.dart`.
  'qa': 'Qualidade de Software',

  /// Frameworks de JavaScript e TypeScript: React, Vue, Svelte, Next, Nuxt e
  /// Astro. Terceiro curso que nao ensina uma linguagem -- ver o comentario de
  /// `backend` acima sobre o campo `language` identificar a TRILHA.
  ///
  /// O nome de tela e "Frameworks", e nao "Front-end", porque HTML e CSS ja
  /// estao reservados como trilhas proprias e este curso nao cobre nenhum dos
  /// dois.
  ///
  /// Sao as mesmas 10 letras de "JavaScript", entao ele nao aperta o cabecalho
  /// mais do que a trilha que ja existia -- e e isso, e nao "cabe sem
  /// encolher", que o teste trava. A diferenca importa: medido, "Frameworks
  /// modernos para JavaScript" cairia para 0,261 da escala, uns 7px numa fonte
  /// pensada para 26. O nome longo vive na DESCRICAO, que aparece no cartao da
  /// escolha, onde nao ha tres icones disputando a linha.
  'frameworks': 'Frameworks',
  /// Linguagem de tipos declarados, e a mais pedida nas vagas de QA que o
  /// Gustavo acompanha -- banco e seguradora, sobretudo.
  ///
  /// Quatro caracteres. Cabe folgado no cabecalho da trilha.
  'java': 'Java',

  /// Automacao de teste web em Java. Quarto curso que nao ensina linguagem.
  ///
  /// O nome de tela e so "Selenium", e nao "Selenium com Java": sao 8
  /// caracteres contra 17, e o cabecalho da trilha ja aperta em 21 (medido:
  /// "Qualidade de Software" encolhe para 0,548 da escala num aparelho de
  /// 412dp). Quem carrega o "com Java" e a DESCRICAO do cartao, que vive na
  /// tela de escolha e nao disputa espaco com tres icones.
  'selenium': 'Selenium',

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

/// Uma linha dizendo o que a trilha cobre, no cartao da tela de escolha.
///
/// Nasceu de um defeito de descoberta que o Gustavo apontou: quem abre a lista
/// ve "Frameworks" e nao tem como saber que aquilo e sobre JavaScript. E o
/// problema nao era so daquela trilha -- "Backend" nao diz que cobre HTTP e
/// bancos, e "Qualidade de Software" nao diz que fala de ciclo do bug.
///
/// **O nome curto continua sendo o nome.** A descricao vive so no cartao, que
/// e outra superficie: o cabecalho da trilha divide a linha com a seta e tres
/// icones, e ali nao caberia nada disto. Ver o comentario de `frameworks` em
/// [nomeDaLinguagem].
///
/// Os cinco textos tem entre 62 e 68 caracteres de proposito. Comprimento
/// parecido faz os cinco quebrarem em duas linhas do mesmo jeito, e os cartoes
/// ficam com a mesma altura -- lista de cartoes de altura irregular le como
/// desalinho, nao como conteudo diferente.
///
/// **Nao passa pelo `textoComTermos`, e isso foi decidido medindo.** O lexico
/// ja conhece React, Vue, Next, HTTP e REST, entao os nomes acenderiam
/// sozinhos. Mas na linha da Frameworks seriam 7 de 11 palavras destacadas: o
/// cartao viraria uma mancha ciano, e destaque que cobre quase tudo deixa de
/// destacar. Mesma regra do verde no `CLAUDE.md` -- acento, nunca corpo.
const Map<String, String> descricaoDaLinguagem = {
  'python': 'Sua primeira linguagem: valores, contas, decisões, textos e listas',
  'javascript':
      'A linguagem do navegador: variáveis, comparação, funções e arrays',
  'frameworks':
      'React, Vue, Svelte, Next, Nuxt e Astro — melhor depois do JavaScript',
  'backend':
      'O lado do servidor: HTTP, APIs e REST, bancos de dados e autenticação',
  'qa': 'O ofício de testar: princípios, níveis, ciclo do bug e técnicas',
  'java': 'A linguagem do mundo corporativo: tipos declarados, classes e arrays',
  'selenium':
      'Localizadores, esperas e Page Object — em Java, melhor depois dele',
};

String? descricaoDe(String chave) => descricaoDaLinguagem[chave];

/// Em que ordem as trilhas aparecem na tela de escolha.
///
/// **Isto existe porque a ordem alfabetica estava ensinando errado.** Ela nao
/// foi decidida por ninguem: saia do `..sort()` da lista de linguagens, e o
/// resultado era Backend, Frameworks, JavaScript, Python, Qualidade. Ou seja,
/// a trilha que DEPENDE de JavaScript aparecia acima dele, e a primeira
/// linguagem recomendada ficava em quarto lugar.
///
/// A ordem abaixo sugere um caminho: comece por Python, siga para JavaScript,
/// e so entao Frameworks, que assume os dois. Backend rende mais depois de ver
/// codigo, e Qualidade nao tem pre-requisito de linguagem.
///
/// **Sugerir nao e trancar.** O `CLAUDE.md` e explicito que nada tranca no
/// DevLingo -- trancar puniria, e atrapalharia quem quer revisar ou espiar
/// adiante. Qualquer trilha continua abrindo a qualquer momento.
///
/// As trilhas que ainda nao existem estao aqui num palpite inicial, para que
/// nenhuma delas caia no fim da lista no dia em que ganhar conteudo. Quem
/// escrever uma delas revisita a posicao.
const List<String> ordemDasTrilhas = [
  'python',
  'javascript',
  'frameworks',
  // Java vem depois das duas primeiras linguagens, e ANTES do Selenium: aquele
  // curso le codigo Java em toda questao, entao a ordem precisa refletir a
  // dependencia -- mesma razao que poe Frameworks depois de JavaScript.
  'java',
  'node',
  'html',
  'css',
  'backend',
  'sql',
  'qa',
  'selenium',
  'csharp',
  'golang',
  'cpp',
  'ruby',
  'cobol',
];

/// Posicao da trilha na ordem sugerida.
///
/// Chave desconhecida vai para o fim em vez de sumir ou explodir: uma trilha
/// nova que alguem esqueceu de listar precisa continuar aparecendo na tela.
int posicaoDaTrilha(String chave) {
  final posicao = ordemDasTrilhas.indexOf(chave);
  return posicao < 0 ? ordemDasTrilhas.length : posicao;
}

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
