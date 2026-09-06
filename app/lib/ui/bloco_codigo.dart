import 'package:flutter/material.dart';

import '../models/question.dart';
import 'models_de_token.dart';
import 'paleta.dart';
import 'realce.dart';

/// O bloco de codigo da tela de exercicio, no formato de uma IDE em miniatura.
///
/// Duas regras de layout que nao se negociam:
///
/// - **O codigo nunca quebra linha.** Quebra automatica destroi a indentacao, e
///   indentacao em Python e sintaxe. A rolagem e horizontal.
/// - **A linha destacada sangra ate as bordas** do bloco, inclusive quando o
///   conteudo e mais largo que a tela.
///
/// O realce de sintaxe vem de [tokenizar], que e funcao pura e mora fora daqui.
/// As cores estao em [Paleta] e vieram do mockup.
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
                              linguagem: code.language,
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
    required this.linguagem,
    required this.destacada,
  });

  final int numero;
  final int larguraNumero;
  final String texto;
  final String linguagem;
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
          _TextoDaLinha(
            texto: texto,
            linguagem: linguagem,
            estilo: estiloBase,
          ),
        ],
      ),
    );
  }
}

/// Uma linha de codigo, com realce de sintaxe e a lacuna virando pastilha.
class _TextoDaLinha extends StatelessWidget {
  const _TextoDaLinha({
    required this.texto,
    required this.linguagem,
    required this.estilo,
  });

  final String texto;
  final String linguagem;
  final TextStyle estilo;

  static Color corDe(TipoDeToken tipo) => switch (tipo) {
    TipoDeToken.palavraChave => Paleta.sintaxePalavraChave,
    TipoDeToken.texto => Paleta.sintaxeTexto,
    TipoDeToken.numero => Paleta.sintaxeNumero,
    TipoDeToken.funcao => Paleta.sintaxeFuncao,
    TipoDeToken.comentario => Paleta.sintaxeComentario,
    TipoDeToken.nome => Paleta.sintaxeNome,
    TipoDeToken.pontuacao || TipoDeToken.espaco => Paleta.sintaxePontuacao,
    TipoDeToken.lacuna => Paleta.lacunaTexto,
  };

  @override
  Widget build(BuildContext context) {
    final pedacos = <InlineSpan>[];

    for (final token in tokenizar(texto, linguagem)) {
      if (token.tipo == TipoDeToken.lacuna) {
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
        continue;
      }
      pedacos.add(
        TextSpan(text: token.texto, style: TextStyle(color: corDe(token.tipo))),
      );
    }

    // softWrap falso e o que garante que a linha nunca quebre: quebra
    // automatica destroi a indentacao, e indentacao em Python e sintaxe.
    return Text.rich(
      TextSpan(style: estilo, children: pedacos),
      softWrap: false,
    );
  }
}
