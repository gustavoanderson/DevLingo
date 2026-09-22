/// O FORMATO DE UMA PARTIDA -- o contrato entre o app e o navegador.
///
/// Uma partida e o registro de uma questao respondida, e ela viaja: o app a
/// grava no SQLite, sobe para o Firestore, e outro aparelho a baixa. Desde
/// 22/09/2026 o NAVEGADOR tambem grava partidas, e o celular as recebe.
///
/// Por isso este arquivo existe, e por isso ele NAO importa `sqflite`: e o
/// unico lugar que diz o que uma partida contem, e o `ponte_web.dart` precisa
/// compila-lo para JavaScript. Antes, isto morava dentro de `progresso.dart`,
/// preso ao banco local, e a versao web teria de reescrever o formato em JS.
///
/// REESCREVER SERIA QUEBRAR O CROSS-PLAY EM SILENCIO, e por tres razoes medidas
/// no codigo, nenhuma delas visivel de fora:
///
/// 1. O app recebe uma partida da nuvem fazendo `insert('evento_resposta',
///    {...evento, ...})` DIRETO no SQLite. Um campo a mais que nao seja coluna
///    derruba a insercao no aparelho -- "table evento_resposta has no column
///    named X". Um campo `NOT NULL` a menos, tambem
/// 2. O desfecho gravado e `revelada`, mas a fase da sessao e `revelado`. Um
///    "a" contra um "o". Copiar o nome da fase gravaria um valor que o app nao
///    reconhece
/// 3. O `evento_id` e derivado do conteudo, e dois lados que o calculem de
///    jeitos diferentes produzem a mesma partida com dois ids -- historico
///    duplicado, estatistica inflada
///
/// Um teste em `progresso_test.dart` compara as chaves de [eventoDaPartida] com
/// o `PRAGMA table_info` real da tabela. Se alguem acrescentar coluna so de um
/// lado, ele reprova.
library;

import '../answer/sessao_questao.dart';
import '../models/lesson.dart';
import '../models/question.dart';

/// Como a questao terminou.
enum Desfecho {
  /// O aluno chegou na resposta sozinho, com uma ou mais tentativas.
  acertou,

  /// As tentativas se esgotaram e a resposta foi revelada.
  revelada,
}

/// Acima disto, a duracao medida e descartada.
///
/// O app nao distingue pensar de ir almocar. Sem teto, uma questao de seis
/// horas destroi qualquer media e a estatistica passa a mentir sem avisar --
/// pior do que nao existir.
///
/// Dez minutos e um **chute** deliberadamente generoso: pensar seis minutos
/// numa questao dificil e plausivel, dez ja e ter saido. Recalibrar quando
/// houver dados reais de alguem jogando; ate la, e um numero escolhido sem
/// evidencia, e esta escrito aqui que e.
const Duration tetoDeDuracao = Duration(minutes: 10);

/// A duracao que deve ser gravada: a medida, ou nulo se implausivel.
///
/// **Nulo e "nao medido", nunca zero.** Uma questao "respondida em 0 segundo"
/// puxaria a media para baixo e ninguem saberia por que.
int? duracaoGravavel(Duration? medida) {
  if (medida == null) return null;
  if (medida.isNegative || medida > tetoDeDuracao) return null;
  return medida.inMilliseconds;
}

/// Identificador de uma partida, derivado do proprio conteudo -- dono, questao
/// e instante -- em vez de um contador local. Isso resolve dois problemas:
///
/// - **Nao colide entre aparelhos.** Com `AUTOINCREMENT`, o celular e o
///   tablet gerariam o id 1 para partidas diferentes, e ao juntar os
///   historicos uma sobrescreveria a outra
/// - **Reenviar nao duplica.** A mesma partida produz sempre o mesmo id,
///   entao mandar de novo para a nuvem e inofensivo
String idDoEvento(String uid, String questionId, int quando) =>
    '$uid|$questionId|$quando';

/// Os dados de uma partida terminada, como o estado atual os guarda.
///
/// Devolve nulo se a questao ainda nao terminou: partida so existe depois do
/// fim, e gravar antes produziria um registro de algo que nao aconteceu.
Map<String, Object?>? dadosDaPartida({
  required String uid,
  required Lesson licao,
  required Question questao,
  required SessaoQuestao sessao,
  required int instante,
}) {
  if (!sessao.terminou) return null;
  return {
    'uid': uid,
    'question_id': questao.id,
    'lesson_id': licao.lessonId,
    'language': licao.language,
    'level': licao.level.name,
    'topic': questao.topic,
    'tentativas': sessao.tentativas,
    // FaseResposta.revelado vira Desfecho.revelada -- nomes diferentes, e e
    // aqui, num lugar so, que um vira o outro.
    'desfecho': sessao.fase == FaseResposta.acertou
        ? Desfecho.acertou.name
        : Desfecho.revelada.name,
    // Inteiro e nao booleano: e como o SQLite guarda, e como o app sobe para a
    // nuvem. Mandar `true` funcionaria por acaso -- o app converte na volta --,
    // mas deixaria o mesmo campo com dois tipos no Firestore.
    'usou_dica': sessao.dicaPedida ? 1 : 0,
    'duracao_ms': duracaoGravavel(sessao.duracao),
    'respondida_em': instante,
  };
}

/// A partida como ela vai para o historico, e dali para a nuvem: os dados mais
/// o id e a marca de "ainda nao enviado". E exatamente uma linha de
/// `evento_resposta`.
Map<String, Object?>? eventoDaPartida({
  required String uid,
  required Lesson licao,
  required Question questao,
  required SessaoQuestao sessao,
  required int instante,
}) {
  final dados = dadosDaPartida(
      uid: uid, licao: licao, questao: questao, sessao: sessao, instante: instante);
  if (dados == null) return null;
  return {
    ...dados,
    'evento_id': idDoEvento(uid, questao.id, instante),
    'sincronizado': 0,
  };
}

/// Quantas questoes DISTINTAS foram respondidas em cada licao, a partir do
/// historico.
///
/// E a definicao de progresso do app: *licao concluida = todas as questoes
/// respondidas, independente de quantas tentativas cada uma custou*. Refazer
/// uma questao nao conta duas vezes.
///
/// O app responde isto com SQL, na tabela de estado atual. O navegador nao tem
/// essa tabela -- le o historico direto da nuvem --, e esta funcao faz a mesma
/// conta sobre ele. Um teste compara as duas contra os mesmos dados; se
/// divergirem, a trilha do navegador e a do celular mostram numeros diferentes
/// para a mesma pessoa.
Map<String, int> respondidasPorLicaoNoHistorico(
    Iterable<Map<String, Object?>> eventos) {
  final porLicao = <String, Set<String>>{};
  for (final e in eventos) {
    porLicao
        .putIfAbsent(e['lesson_id']! as String, () => <String>{})
        .add(e['question_id']! as String);
  }
  return {for (final m in porLicao.entries) m.key: m.value.length};
}
