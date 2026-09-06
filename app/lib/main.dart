import 'package:flutter/material.dart';

import 'data/progresso.dart';
import 'data/question_bank.dart';
import 'models/lesson.dart';
import 'ui/paleta.dart';
import 'ui/tela_exercicio.dart';

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

/// O que o app precisa ter em maos antes de abrir a tela de exercicio.
class _Partida {
  final Lesson licao;
  final Progresso progresso;
  final int indice;

  const _Partida(this.licao, this.progresso, this.indice);
}

/// Abre o banco de questoes e o progresso, e retoma de onde o aluno parou.
///
/// A licao esta fixa enquanto nao existe tela de escolha de linguagem e trilha.
class _Carga extends StatefulWidget {
  const _Carga();

  @override
  State<_Carga> createState() => _CargaState();
}

class _CargaState extends State<_Carga> {
  late final Future<_Partida> _partida = _preparar();

  static const String _licaoDemo = 'python-beg-01';

  Future<_Partida> _preparar() async {
    final banco = await QuestionBank.carregar();
    final licao = banco.lessons.firstWhere(
      (l) => l.lessonId == _licaoDemo,
      orElse: () => banco.lessons.first,
    );
    final progresso = await Progresso.abrir();
    final salvo = await progresso.posicaoDe(licao.lessonId) ?? 0;
    // Uma licao que encolheu entre versoes do app nao pode abrir fora do fim.
    final indice = salvo.clamp(0, licao.questions.length - 1);
    return _Partida(licao, progresso, indice);
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
        return TelaExercicio(
          licao: partida.licao,
          progresso: partida.progresso,
          indiceInicial: partida.indice,
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
