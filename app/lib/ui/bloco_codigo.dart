import 'package:flutter/material.dart';

import '../models/question.dart';
import 'paleta.dart';

/// O bloco de codigo da tela de exercicio, no formato de uma IDE em miniatura.
///
/// Duas regras de layout que nao se negociam:
///
/// - **O codigo nunca quebra linha.** Quebra automatica destroi a indentacao, e
///   indentacao em Python e sintaxe. A rolagem e horizontal.
/// - **A linha destacada sangra ate as bordas** do bloco, inclusive quando o
///   conteudo e mais largo que a tela.
///
/// O realce de sintaxe ficou para um passo seguinte. Codigo legivel sem cor nao
/// impede ninguem de responder, e empilhar um tokenizador aqui aumentaria a
/// chance da tela nao ficar de pe.
class BlocoCodigo extends StatelessWidget {
  const BlocoCodigo({super.key, required this.code});

  final CodeBlock code;

  /// Nome de arquivo exibido na aba, derivado da linguagem do bloco.
  String get _nomeArquivo => switch (code.language) {
    'python' => 'main.py',
    'javascript' || 'node' => 'main.js',
    'html' => 'index.html',
    'css' => 'estilo.css',
    'sql' => 'consulta.sql',
    'csharp' => 'Programa.cs',
    'golang' => 'main.go',
    'cpp' => 'main.cpp',
    'ruby' => 'main.rb',
    'cobol' => 'PROGRAMA.CBL',
    _ => 'arquivo.txt',
  };

  @override
  Widget build(BuildContext context) {
    final linhas = code.linhas;
    final larguraNumero = '${linhas.length}'.length;

    return Container(
      decoration: BoxDecoration(
        color: Paleta.ideFundo,
        border: Border.all(color: Paleta.linha),
        borderRadius: BorderRadius.circular(Escala.raio),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Aba(nomeArquivo: _nomeArquivo),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: LayoutBuilder(
              builder: (context, restricoes) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  // Sem quebra de linha: o conteudo mais largo que a tela rola
                  // na horizontal em vez de ser reflowado.
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: restricoes.maxWidth),
                    // IntrinsicWidth para a coluna assumir a largura da linha
                    // mais longa, e assim o fundo da linha destacada cobrir
                    // toda a extensao rolavel, nao so a parte visivel.
                    child: IntrinsicWidth(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < linhas.length; i++)
                            _Linha(
                              numero: i + 1,
                              larguraNumero: larguraNumero,
                              texto: linhas[i],
                              destacada: code.highlightLine == i + 1,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Aba extends StatelessWidget {
  const _Aba({required this.nomeArquivo});

  final String nomeArquivo;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Paleta.ideAba,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      child: Row(
        children: [
          const _Ponto(Paleta.pontoVermelho),
          const SizedBox(width: 6),
          const _Ponto(Paleta.pontoAmarelo),
          const SizedBox(width: 6),
          const _Ponto(Paleta.pontoVerde),
          const SizedBox(width: 10),
          Text(
            nomeArquivo,
            style: const TextStyle(
              color: Paleta.suave,
              fontFamily: fonteMono,
              fontSize: Escala.nomeArquivo,
            ),
          ),
        ],
      ),
    );
  }
}

class _Ponto extends StatelessWidget {
  const _Ponto(this.cor);

  final Color cor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
    );
  }
}

class _Linha extends StatelessWidget {
  const _Linha({
    required this.numero,
    required this.larguraNumero,
    required this.texto,
    required this.destacada,
  });

  final int numero;
  final int larguraNumero;
  final String texto;
  final bool destacada;

  @override
  Widget build(BuildContext context) {
    const estiloBase = TextStyle(
      color: Paleta.texto,
      fontFamily: fonteMono,
      fontSize: Escala.codigo,
      height: Escala.entrelinhaCodigo,
    );

    return Container(
      // A cor de fundo fica no Container da linha inteira, por isso o recuo
      // horizontal e aplicado aqui dentro e nao no bloco: assim o destaque
      // sangra ate as bordas.
      color: destacada ? Paleta.ideLinhaDestacada : null,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$numero'.padLeft(larguraNumero),
            style: estiloBase.copyWith(color: Paleta.ideNumeroLinha),
          ),
          const SizedBox(width: 12),
          _TextoDaLinha(texto: texto, estilo: estiloBase),
        ],
      ),
    );
  }
}

/// Uma linha de codigo, com a lacuna virando pastilha quando o marcador aparece.
class _TextoDaLinha extends StatelessWidget {
  const _TextoDaLinha({required this.texto, required this.estilo});

  final String texto;
  final TextStyle estilo;

  @override
  Widget build(BuildContext context) {
    if (!texto.contains(CodeBlock.marcadorLacuna)) {
      // softWrap falso e o que garante que a linha nunca quebre.
      return Text(texto, style: estilo, softWrap: false);
    }

    final partes = texto.split(CodeBlock.marcadorLacuna);
    final pedacos = <InlineSpan>[];

    for (var i = 0; i < partes.length; i++) {
      if (partes[i].isNotEmpty) {
        pedacos.add(TextSpan(text: partes[i]));
      }
      if (i < partes.length - 1) {
        pedacos.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 1),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
              decoration: BoxDecoration(
                color: Paleta.lacunaFundo,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '    ',
                style: estilo.copyWith(
                  color: Paleta.lacunaTexto,
                  height: 1.1,
                ),
              ),
            ),
          ),
        );
      }
    }

    return Text.rich(TextSpan(style: estilo, children: pedacos), softWrap: false);
  }
}
