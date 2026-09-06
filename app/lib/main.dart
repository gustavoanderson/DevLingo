import 'package:flutter/material.dart';

import 'data/question_bank.dart';
import 'models/lesson.dart';

void main() => runApp(const DevLingoApp());

/// Paleta do projeto. Detalhes e o motivo de cada cor em `docs/paleta.md`.
///
/// O verde é **acento, nunca corpo de texto**: verde saturado sobre fundo
/// escuro reprova em contraste quando usado em texto longo.
abstract final class Paleta {
  static const fundo = Color(0xFF170A31);
  static const superficie = Color(0xFF1E0F3E);
  static const linha = Color(0xFF3B2A63);
  static const texto = Color(0xFFF2F0FF);
  static const suave = Color(0xFF9B93C4);
  static const acerto = Color(0xFFFF2D95);
  static const destaque = Color(0xFF00E5FF);
  static const visor = Color(0xFF39FF14);
}

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
      home: const TelaBanco(),
    );
  }
}

/// Tela provisória do B2: prova que o banco foi lido dos assets.
///
/// Some quando a tela de exercício entrar, no B4.
class TelaBanco extends StatefulWidget {
  const TelaBanco({super.key});

  @override
  State<TelaBanco> createState() => _TelaBancoState();
}

class _TelaBancoState extends State<TelaBanco> {
  late final Future<QuestionBank> _banco = QuestionBank.carregar();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<QuestionBank>(
          future: _banco,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(color: Paleta.destaque),
              );
            }
            if (snapshot.hasError) {
              return _Falha(erro: '${snapshot.error}');
            }
            return _Resumo(banco: snapshot.requireData);
          },
        ),
      ),
    );
  }
}

class _Falha extends StatelessWidget {
  const _Falha({required this.erro});

  final String erro;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nao foi possivel carregar o banco',
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
              fontFamily: 'monospace',
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _Resumo extends StatelessWidget {
  const _Resumo({required this.banco});

  final QuestionBank banco;

  @override
  Widget build(BuildContext context) {
    final licoes = banco.lessons;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
      children: [
        const Text(
          'DevLingo',
          style: TextStyle(
            color: Paleta.texto,
            fontFamily: 'monospace',
            fontSize: 34,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            shadows: [
              Shadow(color: Paleta.destaque, offset: Offset(-2, 0)),
              Shadow(color: Paleta.acerto, offset: Offset(2, 0)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'BANCO CARREGADO DOS ASSETS',
          style: TextStyle(
            color: Paleta.visor,
            fontFamily: 'monospace',
            fontSize: 11,
            letterSpacing: 2.2,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            _Numero(valor: '${banco.totalDeQuestoes}', rotulo: 'questoes'),
            _Numero(valor: '${licoes.length}', rotulo: 'licoes'),
            _Numero(
              valor: '${banco.linguagens.length}',
              rotulo: 'linguagens',
            ),
          ],
        ),
        const SizedBox(height: 28),
        for (final licao in licoes) _LinhaLicao(licao: licao),
      ],
    );
  }
}

class _Numero extends StatelessWidget {
  const _Numero({required this.valor, required this.rotulo});

  final String valor;
  final String rotulo;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            valor,
            style: const TextStyle(
              color: Paleta.acerto,
              fontFamily: 'monospace',
              fontSize: 30,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            rotulo.toUpperCase(),
            style: const TextStyle(
              color: Paleta.suave,
              fontFamily: 'monospace',
              fontSize: 10,
              letterSpacing: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _LinhaLicao extends StatelessWidget {
  const _LinhaLicao({required this.licao});

  final Lesson licao;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Paleta.superficie,
        border: Border(left: BorderSide(color: Paleta.destaque, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            licao.lessonId,
            style: const TextStyle(
              color: Paleta.destaque,
              fontFamily: 'monospace',
              fontSize: 11,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            licao.lessonTitle,
            style: const TextStyle(
              color: Paleta.texto,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${licao.questions.length} questoes  ·  ${licao.level.rotulo}',
            style: const TextStyle(color: Paleta.suave, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
