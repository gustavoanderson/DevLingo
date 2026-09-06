import 'package:flutter/material.dart';

import 'data/progresso.dart';
import 'data/question_bank.dart';
import 'ui/paleta.dart';
import 'ui/tela_linguagens.dart';
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
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: Paleta.fundo,
            body: Center(
              child: CircularProgressIndicator(color: Paleta.destaque),
            ),
          );
        }
        if (snapshot.hasError) {
          return _Falha(erro: '${snapshot.error}');
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
          );
        }

        return TelaLinguagens(
          banco: partida.banco,
          progresso: partida.progresso,
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
