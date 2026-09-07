import 'package:flutter/foundation.dart';

import 'nuvem.dart';
import 'progresso.dart';

/// O que aconteceu numa rodada de sincronização.
class ResultadoDaSincronizacao {
  const ResultadoDaSincronizacao({
    this.enviados = 0,
    this.recebidos = 0,
    this.falhou = false,
    this.motivo,
  });

  final int enviados;

  /// Quantos eventos vieram e eram **novos**. O que já existia não conta.
  final int recebidos;

  final bool falhou;
  final String? motivo;

  bool get mudouAlgo => enviados > 0 || recebidos > 0;

  static const ResultadoDaSincronizacao semRede = ResultadoDaSincronizacao(
    falhou: true,
    motivo: 'sem conexao',
  );
}

/// Leva o histórico local para a nuvem, e traz o que estiver lá.
///
/// ## Por que isto é simples, e por que era para ser difícil
///
/// Sincronizar costuma ser a parte mais espinhosa de um app offline-first,
/// porque a pergunta "qual das duas versões vale?" não tem resposta boa. Aqui
/// ela **não é feita**, por uma decisão tomada antes de escrever qualquer
/// linha: o que sincroniza é o **histórico**, que só cresce.
///
/// Dois aparelhos nunca discordam sobre uma lista que só recebe itens. Juntar é
/// a união dos dois conjuntos, e o estado atual é recalculado a partir dela por
/// `Progresso.recalcularEstado`. Não há conflito para resolver porque não há
/// duas verdades disputando.
///
/// ## A ordem importa: sobe antes de descer
///
/// Se descesse primeiro, um evento local ainda não enviado poderia ser
/// recalculado para fora do estado atual e só voltar na rodada seguinte — o
/// aluno veria o progresso piscar para trás. Subindo antes, o que é dele já
/// está lá quando o estado é refeito.
///
/// ## Falhar aqui não pode quebrar nada
///
/// Sem conexão, a sincronização desiste em silêncio e o app segue funcionando
/// com o banco local, que é a fonte de verdade do dia a dia. Nada do que o
/// aluno fez se perde: os eventos continuam marcados como pendentes e sobem na
/// próxima vez. **Sincronização é conveniência, não requisito** — a mesma regra
/// que já vale para o som.
class Sincronizador {
  Sincronizador(this._nuvem);

  final NuvemDeProgresso _nuvem;

  /// Evita duas rodadas ao mesmo tempo.
  ///
  /// Sem isto, entrar no app e terminar uma lição em sequência dispararia duas
  /// sincronizações concorrentes, e as duas tentariam subir os mesmos eventos
  /// pendentes. Não corromperia nada — o envio é idempotente — mas gastaria
  /// cota e banda à toa.
  bool _emAndamento = false;

  Future<ResultadoDaSincronizacao> sincronizar(Progresso progresso) async {
    final uid = progresso.usuarioAtual;
    if (uid == Progresso.semDono) {
      // Ninguem entrou ainda. Subir progresso orfao para a nuvem o daria a uma
      // conta que talvez nem seja a de quem jogou.
      return const ResultadoDaSincronizacao();
    }
    if (_emAndamento) return const ResultadoDaSincronizacao();

    _emAndamento = true;
    try {
      final enviados = await _subir(progresso, uid);
      final recebidos = await _descer(progresso, uid);
      return ResultadoDaSincronizacao(
        enviados: enviados,
        recebidos: recebidos,
      );
    } on Object catch (erro) {
      // Falha de rede e o caso COMUM, nao o excepcional: elevador, metro,
      // avião. O app continua inteiro com o banco local, e os eventos seguem
      // pendentes para a proxima rodada.
      debugPrint('Sincronizacao adiada: $erro');
      return ResultadoDaSincronizacao(falhou: true, motivo: '$erro');
    } finally {
      _emAndamento = false;
    }
  }

  Future<int> _subir(Progresso progresso, String uid) async {
    final pendentes = await progresso.eventosPendentes();
    if (pendentes.isEmpty) return 0;

    await _nuvem.enviar(uid, pendentes);
    // Só marca DEPOIS que o envio voltou. Marcar antes perderia os eventos
    // para sempre se a rede caísse no meio: eles ficariam como enviados sem
    // nunca terem chegado.
    await progresso.marcarSincronizados(
      pendentes.map((e) => e['evento_id'] as String),
    );
    return pendentes.length;
  }

  Future<int> _descer(Progresso progresso, String uid) async {
    final marca = await progresso.marcaDeSincronizacao();
    final lote = await _nuvem.baixar(uid, marca: marca);
    if (lote.eventos.isEmpty) return 0;

    final novos = await progresso.receberEventos(lote.eventos);
    // A marca avança mesmo que nenhum evento fosse novo: eles já foram vistos,
    // e baixá-los de novo na próxima rodada só gastaria cota.
    if (lote.ate > marca) {
      await progresso.definirMarcaDeSincronizacao(lote.ate);
    }
    return novos;
  }
}
