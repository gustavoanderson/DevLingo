import 'package:flutter/material.dart';

import 'data/question_bank.dart';
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

/// Carrega o banco e abre a tela de exercicio.
///
/// A questao exibida esta fixa de proposito. E a `python-beg-0306`, a cadeia de
/// `elif` com nove linhas de codigo: ela transborda a tela e por isso exercita a
/// rolagem do miolo e a sombra de recorte, que sao a parte da tela mais facil de
/// quebrar sem ninguem perceber. A escolha de licao e a navegacao entre questoes
/// entram nos passos seguintes.
class _Carga extends StatefulWidget {
  const _Carga();

  @override
  State<_Carga> createState() => _CargaState();
}

class _CargaState extends State<_Carga> {
  late final Future<QuestionBank> _banco = QuestionBank.carregar();

  static const String _licaoDemo = 'python-beg-01';

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuestionBank>(
      future: _banco,
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

        final banco = snapshot.requireData;
        final licao = banco.lessons.firstWhere(
          (l) => l.lessonId == _licaoDemo,
          orElse: () => banco.lessons.first,
        );
        return TelaExercicio(licao: licao);
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
