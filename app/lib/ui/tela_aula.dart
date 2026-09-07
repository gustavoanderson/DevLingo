import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/lesson.dart';
import 'bloco_codigo.dart';
import 'paleta.dart';
import 'sombra_de_recorte.dart';
import 'texto_rico.dart';

/// A aula que o Tr0nikAt dá antes das questões.
///
/// Existe porque sem ela o jogador cai de paraquedas: nenhum ajuste de dica
/// conserta não saber o que é `print`. Aparece sozinha na primeira vez que a
/// lição abre, e depois continua acessível sem se impor.
///
/// O conteúdo mora no mesmo arquivo das questões, e o validador reprova quando
/// os tópicos das duas deixam de bater — assim a aula não envelhece em silêncio
/// enquanto as questões mudam.
class TelaAula extends StatefulWidget {
  const TelaAula({
    super.key,
    required this.licao,
    required this.aoComecar,
    this.rotuloDoBotao = 'Começar as questões',
  });

  final Lesson licao;
  final VoidCallback aoComecar;
  final String rotuloDoBotao;

  static const Key chaveComecar = Key('aula-comecar');
  static const Key chaveSombra = Key('sombra-da-aula');

  @override
  State<TelaAula> createState() => _TelaAulaState();
}

class _TelaAulaState extends State<TelaAula>
    with AvisaConteudoCortado<TelaAula> {
  Aula get aula => widget.licao.aula!;

  @override
  void initState() {
    super.initState();
    iniciarAvisoDeRecorte();
  }

  @override
  void dispose() {
    encerrarAvisoDeRecorte();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Paleta.fundo,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: comSombraDeRecorte(
                chaveSombra: TelaAula.chaveSombra,
                rolavel: ListView(
                  controller: rolagem,
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                  children: [
                    _Capa(licao: widget.licao, aula: aula),
                    const SizedBox(height: 26),
                    for (final (indice, secao) in aula.secoes.indexed) ...[
                      _Secao(
                        numero: indice + 1,
                        secao: secao,
                        linguagem: widget.licao.language,
                      ),
                      if (indice < aula.secoes.length - 1)
                        const SizedBox(height: 26),
                    ],
                  ],
                ),
              ),
            ),
            _BarraComecar(
              rotulo: widget.rotuloDoBotao,
              aoTocar: widget.aoComecar,
            ),
          ],
        ),
      ),
    );
  }
}

class _Capa extends StatelessWidget {
  const _Capa({required this.licao, required this.aula});

  final Lesson licao;
  final Aula aula;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${licao.language} · ${licao.level.rotulo.toLowerCase()}',
                style: const TextStyle(
                  color: Paleta.destaque,
                  fontFamily: fonteMono,
                  fontSize: Escala.chip,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                aula.titulo,
                style: const TextStyle(
                  color: Paleta.texto,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Antes de responder, o Tr∅nikAt explica o que vem por aí.',
                style: const TextStyle(
                  color: Paleta.suave,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SvgPicture.asset(
          'assets/mascot/tronikat.svg',
          width: 92,
          semanticsLabel: 'Tr∅nikAt, o mascote do DevLingo',
        ),
      ],
    );
  }
}

class _Secao extends StatelessWidget {
  const _Secao({
    required this.numero,
    required this.secao,
    required this.linguagem,
  });

  /// De qual linguagem sao os termos a destacar no texto.
  final String linguagem;

  final int numero;
  final SecaoDaAula secao;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // A numeracao e informacao, nao enfeite: as secoes vem na ordem em
            // que os conceitos se apoiam uns nos outros.
            Text(
              '$numero'.padLeft(2, '0'),
              style: const TextStyle(
                color: Paleta.acerto,
                fontFamily: fonteMono,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                secao.titulo,
                style: const TextStyle(
                  color: Paleta.texto,
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (final paragrafo in secao.paragrafos) ...[
          textoComTermos(
            paragrafo,
            linguagem: linguagem,
            estilo: const TextStyle(
              color: Paleta.texto,
              fontSize: Escala.alternativa,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (secao.code != null) ...[
          const SizedBox(height: 2),
          BlocoCodigo(code: secao.code!),
        ],
      ],
    );
  }
}

class _BarraComecar extends StatelessWidget {
  const _BarraComecar({required this.rotulo, required this.aoTocar});

  final String rotulo;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: GestureDetector(
        key: TelaAula.chaveComecar,
        behavior: HitTestBehavior.opaque,
        onTap: aoTocar,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Paleta.acerto,
            borderRadius: BorderRadius.circular(Escala.raio),
          ),
          child: Text(
            rotulo,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Paleta.sobreAcerto,
              fontSize: Escala.verificar,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
