/// Quem está usando o app.
///
/// Só o que o DevLingo precisa saber. O objeto do Firebase carrega dezenas de
/// campos — provedores, token, metadados — e deixar ele vazar para as telas
/// amarraria a interface inteira a uma biblioteca.
class Usuario {
  const Usuario({
    required this.id,
    required this.email,
    this.emailVerificado = false,
  });

  /// Identificador estável, e a chave do progresso na nuvem.
  ///
  /// **Imutável na prática**, pela mesma razão do `id` das questões e do
  /// `applicationId`: o progresso aponta para ele.
  final String id;

  final String email;
  final bool emailVerificado;
}

/// O que pode dar errado ao entrar ou cadastrar.
///
/// Enum próprio, e não o código de erro do Firebase, por dois motivos. O
/// primeiro é que a tela precisa decidir o que dizer, e decidir isso a partir
/// de uma string como `auth/wrong-password` espalha conhecimento da biblioteca
/// pela interface. O segundo é que assim dá para testar cada caminho de erro
/// sem rede nenhuma — que é justamente onde as telas de login costumam ser
/// menos testadas e mais quebradas.
enum FalhaDeAutenticacao {
  emailInvalido,
  emailJaCadastrado,
  senhaFraca,
  senhaCurta,
  credenciaisErradas,
  contaNaoEncontrada,
  semRede,
  muitasTentativas,
  campoVazio,
  desconhecida,
}

/// Erro de autenticação, já com a mensagem que o usuário lê.
///
/// A mensagem diz **o que houve e o que fazer**, nunca só "erro". Mensagem de
/// erro que não sugere saída deixa a pessoa presa numa tela que ela não pode
/// pular — e, com login obrigatório, essa tela é a porta do app inteiro.
class ErroDeAutenticacao implements Exception {
  const ErroDeAutenticacao(this.falha);

  final FalhaDeAutenticacao falha;

  String get mensagem => switch (falha) {
    FalhaDeAutenticacao.emailInvalido =>
      'Esse e-mail não parece completo. Confira se tem @ e o domínio, '
          'como em nome@exemplo.com.',
    FalhaDeAutenticacao.emailJaCadastrado =>
      'Já existe uma conta com esse e-mail. Entre por ela, ou use '
          '"Esqueci minha senha" se não lembrar.',
    FalhaDeAutenticacao.senhaFraca =>
      'Essa senha é fácil de adivinhar. Misture letras e números.',
    FalhaDeAutenticacao.senhaCurta =>
      'A senha precisa de pelo menos $minimoDaSenha caracteres.',
    FalhaDeAutenticacao.credenciaisErradas =>
      'E-mail ou senha não conferem. Confira os dois; se a senha sumiu da '
          'memória, use "Esqueci minha senha".',
    FalhaDeAutenticacao.contaNaoEncontrada =>
      'Não achamos conta com esse e-mail. Confira se digitou certo, ou '
          'crie uma conta.',
    FalhaDeAutenticacao.semRede =>
      'Sem conexão agora. O DevLingo precisa de internet só para entrar; '
          'depois disso ele funciona offline.',
    FalhaDeAutenticacao.muitasTentativas =>
      'Muitas tentativas seguidas. Espere alguns minutos antes de tentar '
          'de novo.',
    FalhaDeAutenticacao.campoVazio => 'Preencha o e-mail e a senha.',
    FalhaDeAutenticacao.desconhecida =>
      'Algo deu errado ao falar com o servidor. Tente de novo em instantes.',
  };

  @override
  String toString() => 'ErroDeAutenticacao(${falha.name}): $mensagem';
}

/// Mínimo que o Firebase Auth aceita. Validado aqui **antes** de ir à rede.
///
/// Checar no aparelho responde na hora e sem consumir cota; deixar a biblioteca
/// reclamar faria a pessoa esperar uma ida ao servidor para descobrir que
/// digitou cinco caracteres.
const int minimoDaSenha = 6;

/// Regra de e-mail deliberadamente frouxa: algo, arroba, algo, ponto, algo.
///
/// Validar e-mail com precisão é impossível na prática — a especificação aceita
/// endereços que ninguém escreve — e **falso negativo aqui é grave**: barrar um
/// e-mail válido tranca a pessoa do lado de fora do app. A checagem só pega
/// erro de digitação óbvio; quem diz se o endereço existe é o e-mail que chega.
final RegExp _formatoDeEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Valida só o e-mail. Nulo quer dizer "pode enviar".
///
/// Existe separado porque a recuperação de senha **não tem campo de senha**, e
/// espremer esse caso dentro de [validarCredenciais] produziu, na primeira
/// versão, uma expressão que ninguém conseguia ler.
FalhaDeAutenticacao? validarEmail(String email) {
  if (email.trim().isEmpty) return FalhaDeAutenticacao.campoVazio;
  if (!_formatoDeEmail.hasMatch(email.trim())) {
    return FalhaDeAutenticacao.emailInvalido;
  }
  return null;
}

/// Valida o formulário inteiro sem tocar na rede.
FalhaDeAutenticacao? validarCredenciais(String email, String senha) {
  if (senha.isEmpty) return FalhaDeAutenticacao.campoVazio;
  final doEmail = validarEmail(email);
  if (doEmail != null) return doEmail;
  if (senha.length < minimoDaSenha) return FalhaDeAutenticacao.senhaCurta;
  return null;
}

/// O que as telas sabem sobre autenticação.
///
/// As telas dependem desta interface, e não do Firebase, pelo mesmo motivo que
/// já valeu para [RegistroDeProgresso]: `testWidgets` roda em tempo falso, onde
/// I/O de verdade nunca avança. Além disso, o Firebase exige um
/// `google-services.json` ligado a um projeto real — e assim as telas de login
/// ficam inteiramente construídas e testadas antes de esse arquivo existir.
abstract interface class Autenticacao {
  /// Quem está logado agora, ou nulo. Lido na abertura, já do cache local.
  Usuario? get usuarioAtual;

  /// Avisa quando alguém entra ou sai.
  Stream<Usuario?> get mudancas;

  Future<Usuario> entrar({required String email, required String senha});

  Future<Usuario> cadastrar({required String email, required String senha});

  /// Dispara o e-mail de recuperação.
  ///
  /// **Não diz se a conta existe.** Responder "não achamos esse e-mail" aqui
  /// entregaria a qualquer um a lista de quem tem conta no app, que é o
  /// vazamento clássico de tela de recuperação de senha. A tela responde a
  /// mesma coisa nos dois casos.
  Future<void> recuperarSenha(String email);

  Future<void> sair();

  void dispose();
}
