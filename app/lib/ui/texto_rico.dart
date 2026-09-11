/// Quebra um texto corrido em trechos com estilo, para enunciados e aulas.
///
/// É função pura, fora de qualquer widget, pelos mesmos dois motivos de
/// [realce.dart]: dá para testar sem montar tela, e existe uma **invariante**
/// que só um teste garante — a concatenação dos trechos tem que ser idêntica ao
/// texto original **sem os marcadores**. Um analisador que come um caractere é
/// pior que nenhum, e esse defeito passa despercebido a olho nu.
///
/// ## Duas fontes de destaque, e a ordem entre elas importa
///
/// 1. **Marcação explícita** no conteúdo: `` `assim` `` vira termo técnico,
///    `**assim**` vira negrito. É o autor decidindo, e ganha sempre
/// 2. **Léxico automático**: palavras técnicas conhecidas da linguagem, fora
///    de marcação, viram termo sozinhas
///
/// A marcação vem primeiro porque é a única forma de dizer "aqui é código" num
/// caso que o léxico erraria — e há casos assim, medidos no banco.
///
/// ## Por que o léxico não pode ser a lista do realce de sintaxe
///
/// Seria a escolha óbvia: `realce.dart` já tem as palavras reservadas de cada
/// linguagem. Mas ele classifica **código**, onde toda palavra é código. Aqui o
/// texto é português, e duas palavras reservadas **também são português**:
///
/// - `as` apareceu 6 vezes no banco, e **todas as 6 eram artigo** ("dispensa as
///   chaves", "atropelar as outras")
/// - `for` apareceu 4 vezes, e **2 eram o verbo** ("se for verdadeira")
///
/// Destacar essas como código ensinaria errado justamente onde o aluno está
/// aprendendo. Elas ficam de fora do léxico e dependem de crase quando forem
/// mesmo o comando. `do` sai pelo mesmo motivo.
library;

import 'package:flutter/material.dart';

import 'paleta.dart';

/// Como um pedaço de texto deve ser pintado.
enum EstiloDoTrecho {
  /// Corpo do texto, sem destaque.
  normal,

  /// Ênfase do autor, com `**dois asteriscos**`.
  negrito,

  /// Nome de função, tipo ou palavra reservada. Itálico e cor própria.
  termo,
}

class TrechoDeTexto {
  const TrechoDeTexto(this.texto, this.estilo);

  final String texto;
  final EstiloDoTrecho estilo;

  bool get vazio => texto.isEmpty;

  @override
  String toString() => '${estilo.name}(${texto.length}): $texto';

  @override
  bool operator ==(Object other) =>
      other is TrechoDeTexto &&
      other.texto == texto &&
      other.estilo == estilo;

  @override
  int get hashCode => Object.hash(texto, estilo);
}

/// Termos que o aluno precisa reconhecer como sendo da linguagem, e não do
/// português.
///
/// Só entram aqui palavras que **não existem em português**. Ver o comentário
/// da biblioteca: `as`, `for` e `do` ficaram de fora por colidirem, e o autor
/// as marca com crase quando forem mesmo o comando.
const Set<String> _termosPython = {
  'None', 'True', 'False', 'and', 'append', 'bool', 'break', 'capitalize',
  'class', 'continue', 'def', 'dict', 'elif', 'else', 'float', 'if', 'import',
  'in', 'input', 'int', 'is', 'lambda', 'len', 'list', 'lower', 'not', 'or',
  'pass', 'print', 'range', 'replace', 'return', 'split', 'str', 'strip',
  'try', 'tuple', 'type', 'upper', 'while',
};

const Set<String> _termosJs = {
  'Array', 'Boolean', 'Number', 'Object', 'String', 'array', 'boolean',
  'break', 'case', 'catch', 'class', 'console', 'const', 'default', 'else',
  'false', 'function', 'if', 'in', 'includes', 'indexOf', 'instanceof',
  'length', 'let', 'log', 'new', 'null', 'number', 'object', 'of', 'pop',
  'push', 'return', 'slice', 'split', 'string', 'switch', 'this', 'throw',
  'toLowerCase', 'toUpperCase', 'true', 'try', 'typeof', 'undefined', 'var',
  'while',
};

/// Vocabulario do curso de backend.
///
/// Aqui os termos sao quase todos siglas e substantivos ingleses, e nenhum
/// colide com o portugues -- ao contrario de `as` e `for` nas linguagens. Foi
/// o receio que nao se confirmou: o jargao de engenharia ja e todo ASCII, o
/// que tambem deixa as questoes de escrita viaveis neste curso.
///
/// `cache` fica de fora por um motivo especifico: virou palavra portuguesa
/// corrente ("o cache do navegador"), e destaca-la em todo paragrafo faria o
/// texto piscar. Ela entra por crase quando for o conceito sendo nomeado.
const Set<String> _termosBackend = {
  'ACID', 'API', 'APIs', 'CDN', 'CORS', 'CRUD', 'CSP', 'DELETE', 'DNS', 'GET',
  'GraphQL', 'HTTP', 'HTTPS', 'JSON', 'JWT', 'NoSQL', 'OAuth', 'PATCH', 'POST',
  'PUT', 'REST', 'SQL', 'SSL', 'TLS', 'URL', 'XML', 'backend', 'endpoint',
  'endpoints', 'frontend', 'header', 'headers', 'host', 'localhost', 'payload',
  'query', 'request', 'response', 'session', 'sharding', 'status', 'timeout',
  'token', 'tokens', 'webhook',
};

/// Vocabulario de engenharia de qualidade.
///
/// Siglas e termos ingleses do oficio. Duas exclusoes deliberadas, pela mesma
/// razao de `cache` no lexico de backend -- viraram palavra portuguesa
/// corrente e destaca-las faria o texto piscar:
///
/// - `teste` e `testes`, que aparecem em praticamente toda frase do curso
/// - `bug`, que qualquer pessoa usa em portugues sem pensar duas vezes
///
/// `Dado`, `Quando` e `Entao` do Gherkin em portugues tambem ficam de fora: as
/// duas primeiras sao palavras comuns, e a terceira leva til. Elas entram por
/// crase quando forem os passos do cenario.
const Set<String> _termosQa = {
  'ACID', 'API', 'APIs', 'BDD', 'CI', 'CD', 'CQ', 'DoD', 'DoR', 'E2E',
  'Gherkin', 'Given', 'ISTQB', 'Kanban', 'MVP', 'POM', 'QA', 'Scrum', 'TDD',
  'Then', 'UI', 'GUI', 'WCAG', 'When', 'WIP', 'assert', 'backlog', 'burndown',
  'defect', 'error', 'expect', 'failure', 'fixture', 'flaky', 'mock',
  'regression', 'retest', 'shift-left', 'smoke', 'spy', 'sprint', 'stub',
  'timebox',
};

/// Vocabulario do curso de frameworks de JavaScript.
///
/// Entram os nomes das seis tecnologias e o vocabulario de codigo. Ficam de
/// fora, pela mesma razao de `cache` no lexico de backend e de `teste` no de
/// QA, as palavras que sao portugues corrente neste curso -- destaca-las em
/// todo paragrafo faria o texto piscar. A lista saiu de MEDIR as 70 passagens
/// de aula e enunciado, contando so as ocorrencias fora de crase e negrito:
///
///   tela 22, componente 22, estado 14, navegador 13, servidor 10,
///   rota 7, diretiva 2, compilador 1, ilha 1
///
/// Todas sao substantivos portugueses usados como prosa, e nenhuma e codigo.
/// Elas entram por crase quando forem o conceito sendo nomeado.
///
/// `script` e `template` tambem ficaram de fora: as 4 ocorrencias sao tecnicas
/// neste curso, mas as duas palavras existem em portugues e o ganho nao paga o
/// risco em licao futura.
///
/// **Nada de hifen aqui.** O casador anda por caracteres de nome, e hifen nao e
/// um deles -- `v-if` seria partido em `v` e `if`, e a entrada nunca casaria.
/// Diretivas do Vue e marcacoes do Astro dependem da crase do autor.
const Set<String> _termosFrameworks = {
  'Astro', 'CSS', 'DOM', 'HTML', 'JSX', 'JavaScript', 'Next', 'Nuxt', 'React',
  'Svelte', 'TypeScript', 'Vue', 'className', 'const', 'hook', 'hooks',
  'htmlFor', 'let', 'number', 'onClick', 'prop', 'props', 'ref', 'string',
  'useState',
};

/// Vocabulario do curso de Java.
///
/// A medicao das 70 passagens repetiu o padrao dos outros cursos -- o
/// vocabulario de codigo deu ZERO ocorrencias nuas, porque o autor marcou tudo
/// com crase. O que aparece solto e portugues:
///
///   texto 22, array 7, classe 7, valor 5, tipo 5, objeto 2
///
/// Todos ficam de fora. `array` merece nota: e termo tecnico, e virou palavra
/// portuguesa corrente ("num array de 3 itens"), como `cache` no backend.
///
/// **`for` fica de fora, e isto e reincidencia.** A medicao encontrou "se o
/// lado esquerdo `for` falso" -- o mesmo verbo que ja tinha tirado `for` do
/// lexico de JavaScript. A colisao entre o comando e o verbo do portugues nao
/// e coincidencia daquele curso: ela reaparece em qualquer linguagem que use
/// `for`. Quando for mesmo o comando, o autor marca com crase.
///
/// Os tipos primitivos entram porque em Java eles sao palavras reservadas e
/// aparecem em quase toda linha -- e sao justamente o que distingue a
/// linguagem de Python e JavaScript, onde o tipo nao se escreve.
const Set<String> _termosJava = {
  'ArrayList', 'JVM', 'String', 'StringBuilder', 'System', 'boolean', 'char',
  'charAt', 'class', 'contains', 'double', 'else', 'equals', 'false', 'final',
  'float', 'if', 'int', 'javac', 'length', 'long', 'main', 'new', 'null',
  'public', 'return', 'static', 'substring', 'toLowerCase', 'toString',
  'toUpperCase', 'trim', 'true', 'var', 'void', 'while',
};

/// Vocabulario do curso de Selenium.
///
/// A medicao das 70 passagens confirmou, com dados novos, a exclusao que o
/// lexico de QA ja tinha feito: `teste` aparece 61 VEZES fora de marcacao.
/// Destaca-la faria praticamente toda frase do curso piscar.
///
/// As outras excluidas, todas portugues corrente aqui: tela 16, elemento 12,
/// seletor 11, espera 9, navegador 8, clique 1.
///
/// `driver` fica DENTRO, apesar de parecer da mesma familia: ele nao e
/// palavra portuguesa, e no curso ele e sempre o objeto do codigo -- a
/// variavel que se chama `driver`, ou o programa `chromedriver`.
///
/// O codigo destas licoes e Java, e o realce dele sai do tokenizador de Java
/// por `code.language`. Este lexico serve so ao texto corrido.
const Set<String> _termosSelenium = {
  'By', 'ChromeDriver', 'ExpectedConditions', 'JUnit', 'Selenium', 'TestNG',
  'WebDriver', 'WebDriverWait', 'WebElement', 'assertEquals', 'assertFalse',
  'assertTrue', 'clear', 'click', 'close', 'cssSelector', 'driver',
  'findElement', 'findElements', 'flaky', 'getAttribute', 'getText', 'quit',
  'sendKeys', 'xpath',
};

/// Curso de Agentes de IA.
///
/// A trilha rodou com 50 questoes escritas e **nenhum lexico**: ela caia no
/// ramo vazio do `switch`, e so as poucas passagens em crase eram destacadas.
///
/// A lista e curta porque a medicao mandou que fosse. Contando so as
/// ocorrencias NUAS -- fora de crase e de negrito, que sao as que o lexico
/// automatico veria -- o jargao deste curso e quase todo portugues corrente:
///
///   agente 88, modelo 54, ferramenta 27, laco 23, agentes 16,
///   ferramentas 15, servidor 12, estado 8, sequencia 8, paralelo 7,
///   supervisor 5, rastro 3, cliente 3
///
/// Todas ficaram **fora**. Destacar `agente` pintaria o texto de ciano 88
/// vezes, que e a mesma razao ja registrada para `cache` no backend e `tela`
/// em frameworks. Elas entram por crase quando forem o conceito sendo nomeado.
///
/// O que sobra sao siglas e nomes proprios, que nao colidem com prosa. `MCP`
/// sozinho responde por 16 das ocorrencias que passavam despercebidas.
///
/// Os nomes com `_` medem zero nus porque hoje estao todos em crase; ficam
/// aqui para o dia em que alguem esquecer a crase.
const Set<String> _termosAgentes = {
  'API', 'AutoGen', 'CrewAI', 'JSON', 'LangGraph', 'MCP', 'ReAct',
  'duracao_ms', 'grafo', 'impressao_digital', 'ja_cobradas', 'prompt',
  'token', 'tokens', 'validar_licao',
};

Set<String> termosDe(String linguagem) => switch (linguagem) {
  'python' => _termosPython,
  'javascript' || 'node' => _termosJs,
  'backend' => _termosBackend,
  'qa' => _termosQa,
  'frameworks' => _termosFrameworks,
  'java' => _termosJava,
  'selenium' => _termosSelenium,
  'agentes' => _termosAgentes,
  _ => const {},
};

bool _ehLetraDeNome(int u) =>
    (u >= 0x41 && u <= 0x5A) || // A-Z
    (u >= 0x61 && u <= 0x7A) || // a-z
    (u >= 0x30 && u <= 0x39) || // 0-9
    u == 0x5F; // _

/// Quebra [texto] em trechos estilizados.
///
/// Passar `linguagem` vazia desliga o léxico automático, mas **não** a
/// marcação: uma linguagem sem tokenizador continua com o negrito e as crases
/// do autor funcionando. Isso importa porque o banco prevê nove linguagens que
/// ainda não têm léxico nenhum.
List<TrechoDeTexto> analisarTexto(String texto, {String linguagem = ''}) {
  final marcados = _separarMarcacao(texto);
  final termos = termosDe(linguagem);
  if (termos.isEmpty) return _juntarVizinhos(marcados);

  final saida = <TrechoDeTexto>[];
  for (final trecho in marcados) {
    if (trecho.estilo != EstiloDoTrecho.normal) {
      saida.add(trecho);
      continue;
    }
    saida.addAll(_aplicarLexico(trecho.texto, termos));
  }
  return _juntarVizinhos(saida);
}

/// Tira `**negrito**` e `` `termo` `` do texto, virando trechos.
///
/// Marcador sem par fecha **não** é erro aqui: ele fica como texto comum, e o
/// aluno vê o asterisco em vez de perder metade do parágrafo. Quem reprova
/// marcador desbalanceado é o validador do banco, antes de o conteúdo existir
/// no app — errar em silêncio na tela seria pior que a crase aparecendo.
List<TrechoDeTexto> _separarMarcacao(String texto) {
  final saida = <TrechoDeTexto>[];
  final buffer = StringBuffer();
  var i = 0;

  void despejar() {
    if (buffer.isNotEmpty) {
      saida.add(TrechoDeTexto(buffer.toString(), EstiloDoTrecho.normal));
      buffer.clear();
    }
  }

  while (i < texto.length) {
    final negrito = texto.startsWith('**', i);
    final crase = texto[i] == '`';

    if (negrito || crase) {
      final abertura = negrito ? '**' : '`';
      final fim = texto.indexOf(abertura, i + abertura.length);
      // Fechamento colado na abertura (`` ou ****) nao delimita nada.
      if (fim > i + abertura.length) {
        despejar();
        saida.add(
          TrechoDeTexto(
            texto.substring(i + abertura.length, fim),
            negrito ? EstiloDoTrecho.negrito : EstiloDoTrecho.termo,
          ),
        );
        i = fim + abertura.length;
        continue;
      }
    }

    buffer.write(texto[i]);
    i++;
  }

  despejar();
  return saida;
}

/// Marca as palavras do léxico dentro de um trecho sem marcação.
List<TrechoDeTexto> _aplicarLexico(String texto, Set<String> termos) {
  final saida = <TrechoDeTexto>[];
  var inicioComum = 0;
  var i = 0;

  while (i < texto.length) {
    if (!_ehLetraDeNome(texto.codeUnitAt(i))) {
      i++;
      continue;
    }

    final inicio = i;
    while (i < texto.length && _ehLetraDeNome(texto.codeUnitAt(i))) {
      i++;
    }
    final palavra = texto.substring(inicio, i);

    // `console.log` e uma coisa so, e nao duas palavras coladas num ponto.
    // Sem esta juncao, o ponto ficaria em cor de texto no meio do termo.
    var fim = i;
    while (fim < texto.length &&
        texto[fim] == '.' &&
        fim + 1 < texto.length &&
        _ehLetraDeNome(texto.codeUnitAt(fim + 1))) {
      var j = fim + 1;
      while (j < texto.length && _ehLetraDeNome(texto.codeUnitAt(j))) {
        j++;
      }
      if (!termos.contains(texto.substring(fim + 1, j))) break;
      fim = j;
    }

    if (!termos.contains(palavra)) continue;

    if (inicio > inicioComum) {
      saida.add(
        TrechoDeTexto(
          texto.substring(inicioComum, inicio),
          EstiloDoTrecho.normal,
        ),
      );
    }
    saida.add(
      TrechoDeTexto(texto.substring(inicio, fim), EstiloDoTrecho.termo),
    );
    inicioComum = fim;
    i = fim;
  }

  if (inicioComum < texto.length) {
    saida.add(
      TrechoDeTexto(texto.substring(inicioComum), EstiloDoTrecho.normal),
    );
  }
  return saida;
}

/// Funde trechos vizinhos de mesmo estilo, e descarta os vazios.
///
/// Sem isto, um parágrafo comum viraria dezenas de trechos idênticos, e cada um
/// vira um `TextSpan` na tela — trabalho de layout em troca de nada.
List<TrechoDeTexto> _juntarVizinhos(List<TrechoDeTexto> trechos) {
  final saida = <TrechoDeTexto>[];
  for (final t in trechos) {
    if (t.vazio) continue;
    if (saida.isNotEmpty && saida.last.estilo == t.estilo) {
      saida[saida.length - 1] = TrechoDeTexto(
        saida.last.texto + t.texto,
        t.estilo,
      );
      continue;
    }
    saida.add(t);
  }
  return saida;
}

/// Desenha [texto] com os termos técnicos destacados.
///
/// Devolve um `Text.rich`, e não um widget próprio: assim ele herda quebra de
/// linha, seleção e acessibilidade sem nada a mais.
///
/// O destaque é **itálico e cor**, nunca fonte monoespaçada. Trocar a família
/// no meio de um parágrafo muda a altura da linha e faz o texto ondular — e o
/// que se quer aqui é a palavra saltar, não o parágrafo se desmontar.
Widget textoComTermos(
  String texto, {
  required TextStyle estilo,
  String linguagem = '',
  TextAlign? alinhamento,
}) {
  final trechos = analisarTexto(texto, linguagem: linguagem);

  // Sem nenhum destaque, devolve o texto simples: um `Text.rich` de um span so
  // seria o mesmo desenho por um caminho mais caro.
  if (trechos.length == 1 && trechos.first.estilo == EstiloDoTrecho.normal) {
    return Text(texto, style: estilo, textAlign: alinhamento);
  }

  return Text.rich(
    TextSpan(
      children: [
        for (final t in trechos)
          TextSpan(text: t.texto, style: _estiloDe(t.estilo, estilo)),
      ],
    ),
    style: estilo,
    textAlign: alinhamento,
  );
}

TextStyle? _estiloDe(EstiloDoTrecho estilo, TextStyle base) => switch (estilo) {
  EstiloDoTrecho.normal => null,
  EstiloDoTrecho.negrito => const TextStyle(fontWeight: FontWeight.w700),
  EstiloDoTrecho.termo => const TextStyle(
    color: Paleta.termo,
    fontStyle: FontStyle.italic,
  ),
};
