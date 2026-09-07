import 'package:flutter/material.dart';

import '../auth/autenticacao.dart';
import 'cena_do_login.dart';
import 'paleta.dart';

/// Em que modo o formulário está.
enum ModoDaEntrada { entrar, cadastrar, recuperar }

/// A porta do app: entrar, criar conta e recuperar senha.
///
/// Os três são **um formulário só** com o botão trocado, e não três telas.
/// Separá-las obrigaria a repetir campo de e-mail, validação, tratamento de
/// erro e estado de carregando em triplicata — e é assim que uma delas acaba
/// com uma mensagem de erro pior que as outras.
///
/// ## Login é obrigatório, e o que isso exige em troca
///
/// O Gustavo escolheu conta obrigatória. Essa escolha coloca esta tela na
/// frente do app inteiro, e daí vêm as regras abaixo:
///
/// - **Todo erro diz o que fazer.** Numa tela que dá para pular, mensagem ruim
///   é irritação; aqui, é a pessoa trancada do lado de fora
/// - **O que dá para checar sem rede é checado sem rede.** Formato de e-mail e
///   tamanho de senha respondem na hora, sem esperar ida ao servidor
/// - **Só a primeira abertura precisa de internet.** Depois disso a sessão fica
///   em cache e o app abre offline, o que preserva o offline-first do projeto
/// - **A recuperação nunca diz se a conta existe.** Responder "não achamos esse
///   e-mail" entregaria a lista de quem tem conta
class TelaEntrada extends StatefulWidget {
  const TelaEntrada({
    super.key,
    required this.autenticacao,
    this.aoEntrar,
    this.aoVoltarAoTitulo,
    this.demonstracao = false,
    this.comCena = false,
  });

  final Autenticacao autenticacao;

  /// Mostra, na tela, que nenhuma conta está sendo criada de verdade.
  ///
  /// Enquanto o `google-services.json` não existir, o app roda com a
  /// autenticação em memória. Um login de mentira que **não se anuncia** é pior
  /// que nenhum: a pessoa cadastra um e-mail achando que tem conta, fecha o
  /// app, e descobre depois que nunca houve conta nenhuma.
  final bool demonstracao;

  /// Desenha a cena animada no topo.
  ///
  /// **Padrão falso, e o app passa verdadeiro** -- o contrário do que a leitura
  /// inicial sugere. O motivo é que animação em `repeat()` faz `pumpAndSettle`
  /// esperar para sempre por uma árvore que nunca fica parada, e isso já
  /// derrubou doze testes desta tela de uma vez. Com o padrão falso, quem
  /// escrever um teste novo não tropeça; quem quiser a cena pede por ela.
  ///
  /// Mesmo desenho de `TelaExercicio.comCenario`, pela mesma razão.
  final bool comCena;

  /// Chamado quando alguém entra ou cria conta com sucesso.
  final ValueChanged<Usuario>? aoEntrar;

  /// Volta para a tela de título. A abertura continua alcançável.
  final VoidCallback? aoVoltarAoTitulo;

  static const Key chaveEmail = Key('entrada-email');
  static const Key chaveSenha = Key('entrada-senha');
  static const Key chaveAcao = Key('entrada-acao');
  static const Key chaveErro = Key('entrada-erro');
  static const Key chaveAviso = Key('entrada-aviso');
  static const Key chaveTrocarModo = Key('entrada-trocar-modo');
  static const Key chaveEsqueci = Key('entrada-esqueci');
  static const Key chaveVoltar = Key('entrada-voltar');
  static const Key chaveCarregando = Key('entrada-carregando');
  static const Key chaveDemonstracao = Key('entrada-demonstracao');

  @override
  State<TelaEntrada> createState() => _TelaEntradaState();
}

class _TelaEntradaState extends State<TelaEntrada> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _senha = TextEditingController();

  ModoDaEntrada _modo = ModoDaEntrada.entrar;
  String? _erro;
  String? _aviso;
  bool _ocupado = false;

  @override
  void dispose() {
    _email.dispose();
    _senha.dispose();
    super.dispose();
  }

  void _trocarModo(ModoDaEntrada novo) {
    setState(() {
      _modo = novo;
      // Erro do modo anterior nao faz sentido no novo, e deixa-lo na tela faz
      // parecer que a acao recem-escolhida ja falhou.
      _erro = null;
      _aviso = null;
    });
  }

  Future<void> _enviar() async {
    if (_ocupado) return;

    final email = _email.text.trim();
    final senha = _senha.text;

    // Validacao local primeiro: responde na hora, sem gastar ida ao servidor
    // nem cota, e sem deixar a pessoa esperando para descobrir um erro de
    // digitacao.
    final problema = _modo == ModoDaEntrada.recuperar
        ? validarEmail(email)
        : validarCredenciais(email, senha);

    if (problema != null) {
      setState(() => _erro = ErroDeAutenticacao(problema).mensagem);
      return;
    }

    setState(() {
      _ocupado = true;
      _erro = null;
      _aviso = null;
    });

    try {
      switch (_modo) {
        case ModoDaEntrada.entrar:
          final usuario = await widget.autenticacao.entrar(
            email: email,
            senha: senha,
          );
          widget.aoEntrar?.call(usuario);
        case ModoDaEntrada.cadastrar:
          final usuario = await widget.autenticacao.cadastrar(
            email: email,
            senha: senha,
          );
          widget.aoEntrar?.call(usuario);
        case ModoDaEntrada.recuperar:
          await widget.autenticacao.recuperarSenha(email);
          if (!mounted) return;
          setState(() {
            // A MESMA resposta exista a conta ou nao. Dizer "nao achamos esse
            // e-mail" entregaria a lista de quem tem conta no app.
            _aviso =
                'Se houver conta com esse e-mail, o link de nova senha já '
                'está a caminho. Confira também o spam.';
            _modo = ModoDaEntrada.entrar;
          });
      }
    } on ErroDeAutenticacao catch (e) {
      if (!mounted) return;
      setState(() => _erro = e.mensagem);
    } on Object {
      if (!mounted) return;
      setState(
        () => _erro =
            const ErroDeAutenticacao(FalhaDeAutenticacao.desconhecida).mensagem,
      );
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  String get _titulo => switch (_modo) {
    ModoDaEntrada.entrar => 'Entrar',
    ModoDaEntrada.cadastrar => 'Criar conta',
    ModoDaEntrada.recuperar => 'Esqueci minha senha',
  };

  String get _explicacao => switch (_modo) {
    ModoDaEntrada.entrar =>
      'Sua conta guarda o progresso. Você só precisa de internet agora; '
          'depois o DevLingo funciona offline.',
    ModoDaEntrada.cadastrar =>
      'Só e-mail e senha. O e-mail serve para você recuperar o acesso se '
          'esquecer a senha.',
    ModoDaEntrada.recuperar =>
      'Informe o e-mail da conta e enviamos um link para criar uma senha nova.',
  };

  @override
  Widget build(BuildContext context) {
    // Com o teclado aberto, a cena congela: movimento no canto do olho
    // atrapalha quem esta digitando uma senha, e esta e a porta do app.
    final tecladoAberto = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: Paleta.fundo,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            if (widget.aoVoltarAoTitulo != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: TelaEntrada.chaveVoltar,
                  onPressed: widget.aoVoltarAoTitulo,
                  icon: const Icon(
                    Icons.arrow_back,
                    size: 16,
                    color: Paleta.suave,
                  ),
                  label: const Text(
                    'TELA DE INÍCIO',
                    style: TextStyle(
                      color: Paleta.suave,
                      fontFamily: fonteMono,
                      fontSize: 12,
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            if (widget.comCena) ...[
              Semantics(
                label:
                    'Tr∅nikAt programando, com outro Tr∅nikAt voando ao fundo '
                    'deixando um rastro de arco-íris',
                child: CenaDoLogin(atenuada: tecladoAberto),
              ),
              const SizedBox(height: 14),
            ],
            Text(
              _titulo,
              style: const TextStyle(
                color: Paleta.texto,
                fontFamily: fonteMono,
                fontSize: 26,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _explicacao,
              style: const TextStyle(
                color: Paleta.suave,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            if (widget.demonstracao) ...[
              const SizedBox(height: 12),
              _Painel(
                chave: TelaEntrada.chaveDemonstracao,
                texto:
                    'Modo de demonstração: nada é enviado a servidor nenhum, '
                    'e a conta some ao fechar o app.',
                cor: Paleta.telemetria,
                fundo: const Color(0x33FFE14D),
              ),
            ],
            const SizedBox(height: 16),
            _Campo(
              chave: TelaEntrada.chaveEmail,
              controlador: _email,
              rotulo: 'E-mail',
              teclado: TextInputType.emailAddress,
              habilitado: !_ocupado,
            ),
            if (_modo != ModoDaEntrada.recuperar) ...[
              const SizedBox(height: 12),
              _Campo(
                chave: TelaEntrada.chaveSenha,
                controlador: _senha,
                rotulo: 'Senha',
                escondido: true,
                habilitado: !_ocupado,
                // O minimo aparece ANTES de a pessoa errar, e nao como bronca
                // depois. Regra escondida ate a falha e regra mal comunicada.
                auxilio: _modo == ModoDaEntrada.cadastrar
                    ? 'Pelo menos $minimoDaSenha caracteres.'
                    : null,
              ),
            ],
            if (_erro != null) ...[
              const SizedBox(height: 14),
              _Painel(
                chave: TelaEntrada.chaveErro,
                texto: _erro!,
                cor: Paleta.erro,
                fundo: Paleta.erroTenue,
              ),
            ],
            if (_aviso != null) ...[
              const SizedBox(height: 14),
              _Painel(
                chave: TelaEntrada.chaveAviso,
                texto: _aviso!,
                cor: Paleta.certo,
                fundo: Paleta.certoTenue,
              ),
            ],
            const SizedBox(height: 16),
            _BotaoPrimario(
              chave: TelaEntrada.chaveAcao,
              rotulo: switch (_modo) {
                ModoDaEntrada.entrar => 'Entrar',
                ModoDaEntrada.cadastrar => 'Criar conta',
                ModoDaEntrada.recuperar => 'Enviar link',
              },
              ocupado: _ocupado,
              aoTocar: _enviar,
            ),
            const SizedBox(height: 6),
            if (_modo == ModoDaEntrada.entrar)
              TextButton(
                key: TelaEntrada.chaveEsqueci,
                onPressed: _ocupado
                    ? null
                    : () => _trocarModo(ModoDaEntrada.recuperar),
                child: const Text(
                  'Esqueci minha senha',
                  style: TextStyle(color: Paleta.destaque, fontSize: 14),
                ),
              ),
            TextButton(
              key: TelaEntrada.chaveTrocarModo,
              onPressed: _ocupado
                  ? null
                  : () => _trocarModo(
                      _modo == ModoDaEntrada.cadastrar
                          ? ModoDaEntrada.entrar
                          : ModoDaEntrada.cadastrar,
                    ),
              child: Text(
                _modo == ModoDaEntrada.cadastrar
                    ? 'Já tenho conta. Entrar'
                    : 'Ainda não tenho conta. Criar',
                style: const TextStyle(color: Paleta.destaque, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Campo extends StatelessWidget {
  const _Campo({
    required this.chave,
    required this.controlador,
    required this.rotulo,
    this.teclado,
    this.escondido = false,
    this.habilitado = true,
    this.auxilio,
  });

  final Key chave;
  final TextEditingController controlador;
  final String rotulo;
  final TextInputType? teclado;
  final bool escondido;
  final bool habilitado;
  final String? auxilio;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: chave,
      controller: controlador,
      keyboardType: teclado,
      obscureText: escondido,
      enabled: habilitado,
      autocorrect: false,
      enableSuggestions: false,
      style: const TextStyle(
        color: Paleta.texto,
        fontFamily: fonteMono,
        fontSize: 16,
      ),
      decoration: InputDecoration(
        labelText: rotulo,
        helperText: auxilio,
        labelStyle: const TextStyle(color: Paleta.suave),
        helperStyle: const TextStyle(color: Paleta.suave, fontSize: 12),
        filled: true,
        fillColor: Paleta.superficie,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Escala.raio),
          borderSide: const BorderSide(color: Paleta.linha),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Escala.raio),
          borderSide: const BorderSide(color: Paleta.destaque, width: 2),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Escala.raio),
        ),
      ),
    );
  }
}

class _Painel extends StatelessWidget {
  const _Painel({
    required this.chave,
    required this.texto,
    required this.cor,
    required this.fundo,
  });

  final Key chave;
  final String texto;
  final Color cor;
  final Color fundo;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: chave,
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: fundo,
        border: Border(left: BorderSide(color: cor, width: 3)),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(Escala.raio),
          bottomRight: Radius.circular(Escala.raio),
        ),
      ),
      // O texto fica em Paleta.texto, e nao na cor do painel: vermelho e verde
      // saturados reprovam em contraste quando usados em texto corrido. A cor
      // sinaliza pela borda e pelo fundo, como no painel de retorno da questao.
      child: Text(
        texto,
        style: const TextStyle(
          color: Paleta.texto,
          fontSize: 14,
          height: 1.45,
        ),
      ),
    );
  }
}

class _BotaoPrimario extends StatelessWidget {
  const _BotaoPrimario({
    required this.chave,
    required this.rotulo,
    required this.ocupado,
    required this.aoTocar,
  });

  final Key chave;
  final String rotulo;
  final bool ocupado;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton(
        key: chave,
        onPressed: ocupado ? null : aoTocar,
        style: FilledButton.styleFrom(
          backgroundColor: Paleta.acerto,
          foregroundColor: Paleta.sobreAcerto,
          disabledBackgroundColor: Paleta.linha,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Escala.raio),
          ),
        ),
        child: ocupado
            ? const SizedBox(
                key: TelaEntrada.chaveCarregando,
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Paleta.texto,
                ),
              )
            : Text(
                rotulo,
                style: const TextStyle(
                  fontSize: Escala.verificar,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}
