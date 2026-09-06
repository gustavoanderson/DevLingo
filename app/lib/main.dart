import 'package:flutter/material.dart';

import 'data/progresso.dart';
import 'data/question_bank.dart';
import 'ui/paleta.dart';
import 'ui/som.dart';
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
            sineta: _sineta,
          );
        }

        return TelaLinguagens(
          banco: partida.banco,
          progresso: partida.progresso,
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
