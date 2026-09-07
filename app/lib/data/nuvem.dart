/// Um lote de eventos que veio da nuvem, e até onde ele vai.
///
/// A marca é do relógio do **servidor**, não do aparelho. Ver
/// [NuvemDeProgresso.baixar].
class LoteDeEventos {
  const LoteDeEventos({required this.eventos, required this.ate});

  final List<Map<String, Object?>> eventos;

  /// O maior carimbo de servidor visto neste lote, para virar a próxima marca.
  /// Zero quando o lote veio vazio — aí a marca anterior continua valendo.
  final int ate;

  static const LoteDeEventos vazio = LoteDeEventos(eventos: [], ate: 0);
}

/// Onde o histórico do aluno é guardado fora do aparelho.
///
/// Interface, e não a classe do Firestore direto, pelo mesmo motivo de
/// `Autenticacao` e `RegistroDeProgresso`: `testWidgets` roda em tempo falso,
/// onde I/O real nunca avança, e o Firestore exige projeto configurado. Com
/// isto, a lógica de sincronização fica testada **sem rede nenhuma** — e é
/// justamente a lógica que é difícil de acertar.
abstract interface class NuvemDeProgresso {
  /// Sobe um lote de eventos.
  ///
  /// **Precisa ser idempotente.** Cada evento tem id derivado do próprio
  /// conteúdo, então mandar o mesmo duas vezes tem que sobrescrever, nunca
  /// duplicar. Sem isso, a primeira queda de conexão infla o histórico e as
  /// estatísticas passam a contar partidas que não houve.
  Future<void> enviar(String uid, List<Map<String, Object?>> eventos);

  /// Traz o que chegou ao servidor **depois** de [marca].
  ///
  /// A marca é do relógio do servidor, e não do aparelho. Um celular que ficou
  /// uma semana offline sobe hoje partidas de terça; se a marca fosse a data da
  /// partida, o outro aparelho as consideraria antigas e nunca as baixaria.
  ///
  /// Relógio de aparelho também erra — basta o dono mexer na data — e usar o do
  /// servidor tira essa variável do caminho.
  Future<LoteDeEventos> baixar(String uid, {required int marca});
}

/// Nuvem em memória, para teste e para rodar sem Firebase.
///
/// Não é um simulador do Firestore: reproduz só o que a sincronização precisa
/// distinguir. O relógio é um contador, e não o de verdade, porque teste que
/// depende de tempo real é teste que falha sozinho de madrugada.
class NuvemFalsa implements NuvemDeProgresso {
  /// Tudo que "está no servidor", por usuário e por id de evento.
  final Map<String, Map<String, Map<String, Object?>>> guardados = {};

  /// Carimbo de servidor de cada evento.
  final Map<String, int> carimbos = {};

  /// Faz a próxima operação falhar, para exercitar o caminho de erro.
  ///
  /// Sincronização que só é testada quando dá certo é sincronização que quebra
  /// no primeiro elevador sem sinal.
  Object? falhaProgramada;

  int _relogio = 0;
  int enviosFeitos = 0;
  int descidasFeitas = 0;

  void _talvezFalhar() {
    final falha = falhaProgramada;
    if (falha != null) {
      falhaProgramada = null;
      throw falha;
    }
  }

  @override
  Future<void> enviar(String uid, List<Map<String, Object?>> eventos) async {
    _talvezFalhar();
    enviosFeitos++;
    final doUsuario = guardados.putIfAbsent(uid, () => {});
    for (final evento in eventos) {
      final id = evento['evento_id'] as String;
      // Sobrescreve em vez de acumular: e o que "idempotente" quer dizer aqui.
      doUsuario[id] = {...evento};
      carimbos[id] = ++_relogio;
    }
  }

  @override
  Future<LoteDeEventos> baixar(String uid, {required int marca}) async {
    _talvezFalhar();
    descidasFeitas++;
    final doUsuario = guardados[uid] ?? {};

    final novos = <Map<String, Object?>>[];
    var maior = marca;
    for (final entrada in doUsuario.entries) {
      final carimbo = carimbos[entrada.key] ?? 0;
      if (carimbo <= marca) continue;
      novos.add({...entrada.value});
      if (carimbo > maior) maior = carimbo;
    }
    return LoteDeEventos(eventos: novos, ate: maior);
  }
}
