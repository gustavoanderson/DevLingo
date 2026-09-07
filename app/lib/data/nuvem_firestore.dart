import 'package:cloud_firestore/cloud_firestore.dart';

import 'nuvem.dart';

/// O histórico do aluno no Firestore.
///
/// O caminho é `usuarios/{uid}/eventos/{eventoId}`, e ele não é arbitrário: as
/// regras de segurança publicadas em `firestore.rules` liberam exatamente
/// `usuarios/{uid}/**` para o dono, e mais nada. Mudar este caminho sem mudar
/// as regras faz o app parar de gravar com "permissão negada".
///
/// ## Dois carimbos de tempo, e o motivo de cada um
///
/// - `respondida_em` é **quando o aluno respondeu**, medido no aparelho dele.
///   É o dado pedagógico, e vai junto no documento
/// - `sincronizado_em` é **quando o documento chegou ao servidor**, medido pelo
///   Google. É só para paginar o download
///
/// Paginar pelo primeiro seria um defeito silencioso: um celular que ficou uma
/// semana offline sobe hoje partidas de terça, e o outro aparelho — cuja marca
/// já passou de terça — nunca as veria. Relógio de aparelho também erra, basta
/// o dono mexer na data. O do servidor tira essa variável do caminho.
class NuvemFirestore implements NuvemDeProgresso {
  NuvemFirestore({FirebaseFirestore? firestore})
    : _bd = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _bd;

  /// Quantos documentos vêm por rodada.
  ///
  /// O Firestore cobra por documento lido, e uma sincronização não precisa
  /// trazer tudo de uma vez: o que sobrar vem na próxima. Sem limite, a
  /// primeira abertura de quem já jogou muito viraria uma conta inesperada.
  static const int porRodada = 300;

  CollectionReference<Map<String, dynamic>> _eventos(String uid) =>
      _bd.collection('usuarios').doc(uid).collection('eventos');

  @override
  Future<void> enviar(String uid, List<Map<String, Object?>> eventos) async {
    if (eventos.isEmpty) return;

    // Um lote só: o Firestore aplica tudo ou nada, e cobra menos que N
    // gravações soltas. O teto dele é 500 operações, e `porRodada` fica abaixo.
    final lote = _bd.batch();
    for (final evento in eventos) {
      final id = evento['evento_id'] as String;
      lote.set(
        _eventos(uid).doc(id),
        {
          ...evento,
          // O carimbo é escrito pelo SERVIDOR, e não pelo aparelho.
          'sincronizado_em': FieldValue.serverTimestamp(),
        },
        // `merge: false`: o mesmo id sobrescreve, nunca duplica. É o que torna
        // reenviar inofensivo depois de uma queda de conexão.
        SetOptions(merge: false),
      );
    }
    await lote.commit();
  }

  @override
  Future<LoteDeEventos> baixar(String uid, {required int marca}) async {
    final consulta = await _eventos(uid)
        .where(
          'sincronizado_em',
          isGreaterThan: Timestamp.fromMillisecondsSinceEpoch(marca),
        )
        .orderBy('sincronizado_em')
        .limit(porRodada)
        .get();

    if (consulta.docs.isEmpty) return LoteDeEventos.vazio;

    final eventos = <Map<String, Object?>>[];
    var ate = marca;

    for (final doc in consulta.docs) {
      final dados = Map<String, Object?>.from(doc.data());

      // O carimbo do servidor fica FORA do que vai para o SQLite: ele é
      // metadado de sincronização, não progresso, e a tabela local não tem
      // essa coluna.
      final carimbo = dados.remove('sincronizado_em');
      if (carimbo is Timestamp && carimbo.millisecondsSinceEpoch > ate) {
        ate = carimbo.millisecondsSinceEpoch;
      }

      // Um documento recém-escrito por este aparelho pode voltar com o carimbo
      // ainda nulo, porque o servidor só o resolve depois. Ele é ignorado nesta
      // rodada e vem na próxima, já com carimbo.
      if (carimbo == null) continue;

      eventos.add(_paraOBancoLocal(dados));
    }

    return LoteDeEventos(eventos: eventos, ate: ate);
  }

  /// Ajusta os tipos que o Firestore devolve para o que o SQLite aceita.
  ///
  /// O Firestore guarda todo número inteiro como `int` de 64 bits, mas devolve
  /// booleano como `bool` — e o SQLite não tem tipo booleano. Sem esta
  /// conversão, `usou_dica` chegaria como `true` e a inserção falharia com um
  /// erro de tipo que só apareceria no aparelho de quem sincroniza.
  static Map<String, Object?> _paraOBancoLocal(Map<String, Object?> dados) {
    return {
      for (final entrada in dados.entries)
        entrada.key: switch (entrada.value) {
          final bool b => b ? 1 : 0,
          final Timestamp t => t.millisecondsSinceEpoch,
          final valor => valor,
        },
    };
  }
}
