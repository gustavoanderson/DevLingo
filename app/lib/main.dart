import 'package:flutter/material.dart';

import 'auth/autenticacao.dart';
import 'auth/autenticacao_falsa.dart';
import 'data/progresso.dart';
import 'data/question_bank.dart';
import 'ui/paleta.dart';
import 'ui/som.dart';
import 'ui/tela_entrada.dart';
import 'ui/tela_linguagens.dart';
import 'ui/tela_titulo.dart';
import 'ui/tela_trilha.dart';

void main() => runApp(const DevLingoApp());

class DevLingoApp extends StatelessWidget {
  const DevLingoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DevLingo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Paleta.fundo,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Paleta.acerto,
          brightness: Brightness.dark,
          surface: Paleta.fundo,
        ),
      ),
      home: const _Carga(),
    );
  }
}

class _Partida {
  final QuestionBank banco;
  final Progresso progresso;

  const _Partida(this.banco, this.progresso);
}

/// Abre o banco de questoes e o progresso, e entrega a primeira tela.
class _Carga extends StatefulWidget {
  const _Carga();

  @override
  State<_Carga> createState() => _CargaState();
}

class _CargaState extends State<_Carga> {
  late final Future<_Partida> _partida = _preparar();

  /// O usuario ja apertou START e a tela de titulo saiu de cena.
  ///
  /// A tela de titulo aparece em **toda** abertura, e nao so na primeira: ela e
  /// a porta do fliperama. Este campo e o que faz o app nao voltar para ela
  /// quando o `FutureBuilder` reconstroi.
  bool _comecou = false;

  /// Quem esta usando o app, ou nulo enquanto ninguem entrou.
  ///
  /// O Gustavo escolheu **conta obrigatoria**: sem usuario, o app nao passa da
  /// tela de entrada. Mas "obrigatoria" vale para a CONTA, nao para a rede --
  /// depois do primeiro login a sessao fica em cache e o app abre offline, o
  /// que preserva o offline-first ja decidido para o projeto.
  ///
  /// Nasce lendo `usuarioAtual`, que é a **sessão em cache**. Com a
  /// implementação em memória isso é sempre nulo; com o Firebase, é o que faz o
  /// app abrir offline em quem já entrou uma vez. Deixar para "resolver depois"
  /// significaria trocar a autenticação e o app continuar pedindo login toda
  /// abertura, sem ninguém entender por quê.
  late Usuario? _usuario = _autenticacao.usuarioAtual;

  /// AINDA E A IMPLEMENTACAO EM MEMORIA.
  ///
  /// O Firebase exige um `google-services.json` ligado a um projeto real, que
  /// depende da conta Google do Gustavo. Ate ele existir, o app roda com a
  /// autenticacao falsa, e a tela de entrada **avisa isso na cara** -- login de
  /// mentira que nao se anuncia e pior que nenhum.
  ///
  /// Ao trocar pela de verdade, mude esta linha e apague o `demonstracao: true`
  /// mais abaixo. O resto do app nao muda, porque depende da interface.
  late final Autenticacao _autenticacao = AutenticacaoFalsa();

  /// A sineta le a preferencia do banco a cada toque, sem cache: assim o botao
  /// de desligar tem efeito imediato e nao ha duas copias do mesmo dado para
  /// manter em sincronia.
  ///
  /// Ela espera a **promessa** da carga, e nao um campo preenchido no fim dela.
  /// A versao anterior lia um `Progresso?` que so existia depois da carga e
  /// respondia `false` enquanto fosse nulo -- o que era inofensivo quando o
  /// unico som vinha da tela de exercicio, que so existe depois da carga, e
  /// virou defeito com a tela de titulo, que aceita toque **durante** ela: a
  /// ficha simplesmente nao tocaria em quem apertasse START rapido. Esperando a
  /// promessa, o som sai com a preferencia certa, nem que saia um instante
  /// depois. Se a carga falhar, o `catch` da propria sineta engole.
  late final Sineta _sineta = SinetaDeVerdade(
    estaLigado: () async => (await _partida).progresso.somLigado(),
  );

  @override
  void dispose() {
    _sineta.dispose();
    _autenticacao.dispose();
    super.dispose();
  }

  Future<_Partida> _preparar() async {
    final banco = await QuestionBank.carregar();
    final progresso = await Progresso.abrir();
    return _Partida(banco, progresso);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Partida>(
      future: _partida,
      builder: (context, snapshot) {
        // O erro tem prioridade sobre a tela de titulo: nao adianta oferecer
        // START para um app que nao tem questoes para mostrar.
        if (snapshot.hasError) {
          return _Falha(erro: '${snapshot.error}');
        }

        final pronto = snapshot.connectionState == ConnectionState.done;

        // A tela de titulo cobre a carga em vez de uma roda de progresso. Ela
        // aceita o toque mesmo antes de `pronto`, e so entao entra sozinha.
        if (!_comecou) {
          return TelaTitulo(
            pronto: pronto,
            sineta: _sineta,
            aoIniciar: () => setState(() => _comecou = true),
          );
        }

        // Devolver para a tela de titulo e so desligar `_comecou`: a carga ja
        // terminou, entao ela reaparece com `pronto: true` e o proximo START
        // entra na hora. Nada e recarregado, e o progresso continua onde estava.
        void aoVoltarAoTitulo() => setState(() => _comecou = false);

        // Conta obrigatoria: depois do START, quem nao entrou nao passa daqui.
        //
        // A ordem e deliberada -- titulo ANTES do login. A arte do fliperama e
        // a primeira coisa que a pessoa ve, e o formulario so aparece depois de
        // ela pedir para comecar. Login como primeirissima tela transforma a
        // abertura do app num pedagio.
        if (_usuario == null) {
          return TelaEntrada(
            autenticacao: _autenticacao,
            demonstracao: _autenticacao is AutenticacaoFalsa,
            aoVoltarAoTitulo: aoVoltarAoTitulo,
            aoEntrar: (usuario) => setState(() => _usuario = usuario),
          );
        }

        final partida = snapshot.requireData;
        final trilhas = TelaLinguagens.trilhasDe(partida.banco);

        // Tela de escolha com um item so e cerimonia vazia: com uma trilha
        // apenas, o app abre direto nela.
        if (trilhas.length == 1) {
          return TelaTrilha(
            banco: partida.banco,
            language: trilhas.single.language,
            level: trilhas.single.level,
            progresso: partida.progresso,
            podeVoltar: false,
            aoVoltarAoTitulo: aoVoltarAoTitulo,
            sineta: _sineta,
          );
        }

        return TelaLinguagens(
          banco: partida.banco,
          progresso: partida.progresso,
          aoVoltarAoTitulo: aoVoltarAoTitulo,
          sineta: _sineta,
        );
      },
    );
  }
}

class _Falha extends StatelessWidget {
  const _Falha({required this.erro});

  final String erro;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Paleta.fundo,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Não foi possível carregar o banco',
                style: TextStyle(
                  color: Paleta.acerto,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                erro,
                style: const TextStyle(
                  color: Paleta.suave,
                  fontFamily: fonteMono,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
