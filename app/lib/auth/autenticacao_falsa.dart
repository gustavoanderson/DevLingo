import 'dart:async';

import 'autenticacao.dart';

/// Autenticação em memória, para teste e para desenvolver sem Firebase.
///
/// Ela existe por duas razões, e a segunda é a que importa hoje:
///
/// 1. `testWidgets` roda em tempo falso, onde I/O de verdade nunca avança
/// 2. O Firebase exige um `google-services.json` ligado a um projeto real, que
///    depende da conta Google do Gustavo. Com esta implementação, as telas de
///    login ficam **inteiras e testadas** antes de aquele arquivo existir
///
/// Ela não é um simulador do Firebase: reproduz só os comportamentos que as
/// telas precisam distinguir. Guardar senha em texto puro aqui é aceitável
/// **porque nada disto sai da memória do processo de teste** — o contrário
/// seria fingir segurança onde ela não é o assunto.
class AutenticacaoFalsa implements Autenticacao {
  AutenticacaoFalsa({
    Map<String, String>? contas,
    this.jaLogadoComo,
    this.falhaProgramada,
  }) : _contas = {...?contas} {
    if (jaLogadoComo != null) {
      _atual = _usuarioDe(jaLogadoComo!);
    }
  }

  /// E-mail para senha. Contas que já existem antes do teste começar.
  final Map<String, String> _contas;

  /// Simula o app reaberto com sessão em cache, que é o caso comum: só a
  /// primeira abertura precisa de rede.
  final String? jaLogadoComo;

  /// Faz a próxima operação de rede falhar, para exercitar os caminhos de erro.
  ///
  /// Tela de login é onde os caminhos de erro mais aparecem para o usuário e
  /// menos aparecem em teste. Com login obrigatório, um erro mal tratado tranca
  /// a pessoa do lado de fora do app inteiro.
  FalhaDeAutenticacao? falhaProgramada;

  final StreamController<Usuario?> _mudancas =
      StreamController<Usuario?>.broadcast();

  Usuario? _atual;

  /// Quantas vezes o e-mail de recuperação foi pedido, e para quem.
  final List<String> recuperacoesPedidas = [];

  int _proximoId = 1;
  final Map<String, String> _idsPorEmail = {};

  Usuario _usuarioDe(String email) {
    final id = _idsPorEmail.putIfAbsent(email, () => 'uid-${_proximoId++}');
    return Usuario(id: id, email: email);
  }

  @override
  Usuario? get usuarioAtual => _atual;

  @override
  Stream<Usuario?> get mudancas => _mudancas.stream;

  void _talvezFalhar() {
    final falha = falhaProgramada;
    if (falha != null) {
      falhaProgramada = null;
      throw ErroDeAutenticacao(falha);
    }
  }

  @override
  Future<Usuario> entrar({
    required String email,
    required String senha,
  }) async {
    _talvezFalhar();
    final alvo = email.trim().toLowerCase();
    if (!_contas.containsKey(alvo)) {
      throw const ErroDeAutenticacao(FalhaDeAutenticacao.contaNaoEncontrada);
    }
    if (_contas[alvo] != senha) {
      throw const ErroDeAutenticacao(FalhaDeAutenticacao.credenciaisErradas);
    }
    _atual = _usuarioDe(alvo);
    _mudancas.add(_atual);
    return _atual!;
  }

  @override
  Future<Usuario> cadastrar({
    required String email,
    required String senha,
  }) async {
    _talvezFalhar();
    final alvo = email.trim().toLowerCase();
    if (_contas.containsKey(alvo)) {
      throw const ErroDeAutenticacao(FalhaDeAutenticacao.emailJaCadastrado);
    }
    _contas[alvo] = senha;
    _atual = _usuarioDe(alvo);
    _mudancas.add(_atual);
    return _atual!;
  }

  @override
  Future<void> recuperarSenha(String email) async {
    _talvezFalhar();
    // Registra o pedido mesmo para conta inexistente, e NAO reclama: a tela
    // responde a mesma coisa nos dois casos, senao entrega quem tem conta.
    recuperacoesPedidas.add(email.trim().toLowerCase());
  }

  @override
  Future<void> sair() async {
    _atual = null;
    _mudancas.add(null);
  }

  @override
  void dispose() => _mudancas.close();
}
