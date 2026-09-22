import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';

import 'autenticacao.dart';

/// A autenticação de verdade, sobre o Firebase Auth.
///
/// O resto do app não sabe que ela existe: as telas dependem de [Autenticacao],
/// e foi por isso que elas ficaram inteiras e testadas antes de o
/// `google-services.json` existir.
///
/// ## O que esta classe faz de fato
///
/// Ela **traduz**. O Firebase fala em `FirebaseAuthException` com códigos como
/// `wrong-password`; o app fala em [FalhaDeAutenticacao]. Deixar o código do
/// Firebase vazar para a tela amarraria a interface à biblioteca e espalharia
/// strings mágicas pela camada de apresentação.
///
/// A tradução também é o que torna os caminhos de erro testáveis sem rede:
/// `AutenticacaoFalsa` produz as mesmas falhas, e os testes da tela exercitam
/// senha errada, conta inexistente e queda de conexão sem tocar em servidor.
class AutenticacaoFirebase implements Autenticacao {
  AutenticacaoFirebase({fb.FirebaseAuth? auth})
    : _auth = auth ?? fb.FirebaseAuth.instance;

  final fb.FirebaseAuth _auth;

  /// O usuário da **sessão em cache**, lido do disco sem ir à rede.
  ///
  /// É isto que permite conta obrigatória conviver com offline-first: só a
  /// primeira abertura precisa de internet, e depois o app abre autenticado
  /// mesmo sem sinal.
  @override
  Usuario? get usuarioAtual => _converter(_auth.currentUser);

  @override
  Stream<Usuario?> get mudancas =>
      _auth.authStateChanges().map(_converter);

  static Usuario? _converter(fb.User? u) {
    if (u == null) return null;
    return Usuario(
      id: u.uid,
      // O e-mail é nulo em provedores anônimos; aqui só existe e-mail/senha,
      // mas o tipo do Firebase é anulável e fingir o contrário quebraria num
      // dia em que alguém ativasse outro provedor no console.
      email: u.email ?? '',
      emailVerificado: u.emailVerified,
    );
  }

  @override
  Future<Usuario> entrar({
    required String email,
    required String senha,
  }) async {
    return _tentar(() async {
      final credencial = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: senha,
      );
      return _converter(credencial.user)!;
    });
  }

  @override
  Future<Usuario> cadastrar({
    required String email,
    required String senha,
  }) async {
    return _tentar(() async {
      final credencial = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: senha,
      );
      return _converter(credencial.user)!;
    });
  }

  @override
  Future<void> recuperarSenha(String email) {
    return _tentar(() => _auth.sendPasswordResetEmail(email: email.trim()));
  }

  @override
  Future<void> sair() => _auth.signOut();

  /// Nada a liberar: o `FirebaseAuth` é um singleton do processo.
  @override
  void dispose() {}

  /// Roda a operação e converte qualquer falha para o vocabulário do app.
  Future<T> _tentar<T>(Future<T> Function() operacao) async {
    try {
      return await operacao();
    } on fb.FirebaseAuthException catch (e) {
      // O codigo cru vai para o log de depuracao, e nao para a tela.
      //
      // A mensagem que o usuario le e sempre em portugues e sem jargao; mas
      // quando a causa e ERRO DE CONFIGURACAO, e nao do usuario, quem precisa
      // do detalhe e quem esta desenvolvendo. Sem esta linha, descobrir que o
      // provedor de e-mail/senha estava desativado no console exigiu filtrar o
      // logcat do Android a mao.
      //
      // Casos que aparecem aqui e NAO sao culpa de quem digitou:
      //   CONFIGURATION_NOT_FOUND  Authentication nunca foi iniciado no projeto
      //   operation-not-allowed    o provedor e-mail/senha esta desligado
      //   api-key-not-valid        google-services.json de outro projeto
      debugPrint('FirebaseAuth falhou: ${e.code} -- ${e.message}');
      throw ErroDeAutenticacao(falhaDoCodigo(e.code));
    } on Object catch (erro) {
      // Qualquer outra coisa -- erro de plataforma, canal fechado -- vira
      // "desconhecida". A tela precisa de uma mensagem util em TODO caminho:
      // com login obrigatorio, erro sem saida tranca a pessoa fora do app.
      debugPrint('Falha nao prevista na autenticacao: $erro');
      throw const ErroDeAutenticacao(FalhaDeAutenticacao.desconhecida);
    }
  }

  // A traducao dos codigos mora em autenticacao.dart, como `falhaDoCodigo`:
  // o navegador recebe os mesmos codigos e precisava dela sem Flutter.
}
