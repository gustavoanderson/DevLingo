/// O DOSSIE DE PROGRESSO: o que o Tr∅nikAt precisa saber para dar um conselho.
///
/// Pedido do Gustavo em 23 de setembro de 2026: *"quero que a IA analise o
/// progresso do aluno, possa sugerir projetos/exercicios e desafios a mais
/// ('monte uma calculadora depois de assistir ate a licao tal')"*.
///
/// ## Quem monta e o CLIENTE, e isso nao e detalhe
///
/// O Worker nao alcanca o SQLite do aparelho nem o Firestore, e dar credencial
/// de banco a ele seria abrir uma porta grande para resolver uma leitura. Quem
/// ja tem o dado e quem joga; ele manda o resumo junto com a pergunta.
///
/// ## Livre de Flutter, e pelo motivo de sempre
///
/// O navegador precisa do MESMO dossie, e este repositorio tem a cicatriz do
/// que acontece quando a mesma regra existe em duas linguagens: `normalize()`
/// vive em Dart e em Python, e `tools/normalize_cases.json` existe so para
/// impedir que divirjam em silencio. Aqui nao ha segunda implementacao para
/// divergir -- `ponte_web.dart` compila esta funcao para JavaScript.
///
/// ## O que NAO entra, e por que
///
/// Nem identificador, nem e-mail, nem a resposta que o aluno digitou. Duas
/// razoes, e as duas bastam sozinhas: **tudo que entra num prompt e superficie
/// de injecao**, e o dossie atravessa a rede para um servico de terceiro. O
/// conselho nao fica melhor sabendo quem e a pessoa.
library;

import '../models/lesson.dart';

/// Traduz as licoes do banco para a forma que [montarDossie] le.
///
/// Existe para o app e o navegador entrarem pela MESMA porta: la o JSON de
/// `_trilhas` ja tem esta forma, e aqui os objetos `Lesson` viram ela. A
/// alternativa era [montarDossie] conhecer `Lesson`, e ai o navegador -- que
/// nunca constroi um `Lesson` completo -- teria de fabricar um so para
/// perguntar do proprio progresso.
///
/// Cada item de [trilhas] e uma trilha inteira: mesma linguagem, mesmo nivel.
List<Map<String, Object?>> trilhasParaDossie(List<List<Lesson>> trilhas) => [
      for (final licoes in trilhas)
        if (licoes.isNotEmpty)
          {
            'nome': nomeBonito(licoes.first.language),
            'licoes': [
              for (final l in licoes)
                {
                  'id': l.lessonId,
                  'titulo': l.lessonTitle,
                  'numero': l.numero,
                  'nivel': l.level.rotulo,
                  'questoes': l.questions.length,
                },
            ],
          },
    ];

/// Quanto cabe. O Worker corta em 900 caracteres (`LIMITE_DO_DOSSIE`), e cortar
/// do lado de la produziria uma linha pela metade -- um numero truncado e pior
/// que um numero ausente, porque parece um numero.
const int limiteDoDossie = 900;

/// Monta o dossie a partir do que as duas pontas ja tem.
///
/// [trilhas] e a mesma estrutura que `_trilhas` devolve a ponte: uma lista de
/// `{chave, nome, licoes: [{id, titulo, numero, nivel, questoes}]}`. [feitas]
/// mapeia `lessonId` para quantas questoes distintas foram respondidas -- a
/// saida de `respondidasPorLicao()` no app, e de `_respondidas` no navegador.
///
/// [deCabeca] e opcional porque so o app o tem barato (vem de
/// `resumoDoJogador()`); no navegador a conta exigiria varrer o historico
/// inteiro por um numero que enfeita o conselho, nao o decide.
///
/// Devolve texto vazio para quem nao respondeu nada em lugar nenhum. Isso e
/// deliberado: quem chama nao manda dossie vazio, e a ficha `meu-progresso`
/// responde dizendo para entrar na conta -- ver `JanelaTronikat`.
String montarDossie(
  List<Map<String, Object?>> trilhas,
  Map<String, int> feitas, {
  int? deCabeca,
}) {
  final linhas = <String>[];

  for (final trilha in trilhas) {
    final licoes = (trilha['licoes'] as List<dynamic>? ?? const [])
        .cast<Map<String, Object?>>();

    // SO O QUE FOI COMECADO. Com cinco trilhas no banco e nove previstas,
    // listar as intocadas gastaria o orcamento inteiro dizendo "zero" cinco
    // vezes -- e enterraria a unica linha que sustenta um conselho.
    var respondidas = 0;
    var total = 0;
    final concluidas = <String>[];
    for (final licao in licoes) {
      final id = licao['id'] as String;
      final quantas = licao['questoes'] as int? ?? 0;
      final fez = feitas[id] ?? 0;
      respondidas += fez;
      total += quantas;
      // Licao concluida = todas as questoes respondidas, independente de
      // quantas tentativas cada uma custou. E a mesma definicao da trilha, e
      // mudar aqui faria o mascote contradizer a tela.
      if (quantas > 0 && fez >= quantas) {
        concluidas.add('${licao['numero']} ${licao['titulo']}');
      }
    }
    if (respondidas == 0) continue;

    final nivel = licoes.isEmpty ? '' : ' ${licoes.first['nivel']}';
    linhas.add('trilha ${trilha['nome']}$nivel: '
        '$respondidas de $total questoes respondidas');
    linhas.add(concluidas.isEmpty
        // Dito em voz alta, porque o silencio seria lido como "nao sei".
        // Quem comecou e nao terminou nenhuma licao precisa de um conselho
        // diferente de quem terminou tres.
        ? '  licoes concluidas: nenhuma ainda'
        : '  licoes concluidas: ${concluidas.join(', ')}');
  }

  if (linhas.isEmpty) return '';
  if (deCabeca != null) linhas.add('acertos de primeira: $deCabeca');

  final texto = linhas.join('\n');
  if (texto.length <= limiteDoDossie) return texto;

  // Corta em linha inteira, nunca no meio de uma. Meia linha de progresso e
  // um numero pela metade, e o modelo leria "38 de 5" sem nada denunciar.
  final cabem = <String>[];
  var usado = 0;
  for (final linha in linhas) {
    if (usado + linha.length + 1 > limiteDoDossie) break;
    cabem.add(linha);
    usado += linha.length + 1;
  }
  return cabem.join('\n');
}
