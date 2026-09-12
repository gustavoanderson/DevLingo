// GERADO POR tools/gerar_faixas.py -- NAO EDITE A MAO.
//
// Editar este arquivo funciona ate alguem rodar o gerador de novo, e ai a
// mudanca some sem aviso. Pior: ate la, este arquivo e os SVGs em
// assets/cenarios/ estao mostrando cenarios diferentes.
//
// Para mudar o cenario, edite tools/gerar_faixas.py e rode:
//     python3 tools/gerar_faixas.py
//
// As strings de caminho abaixo sao literalmente as mesmas que vao para os SVGs,
// e e isso que impede as duas saidas de divergirem.

import 'dart:ui';

/// Medidas da faixa, no sistema de coordenadas do desenho.
const double larguraDaFaixa = 680;
const double alturaDaFaixa = 58;

/// Silhuetas dos predios. Cada uma e desenhada duas vezes, lado a lado.
const String predioLonge = 'M0 60 L0 34 L40 34 L40 20 L74 20 L74 42 L110 42 L110 12 L146 12 L146 38 L190 38 L190 26 L232 26 L232 46 L276 46 L276 18 L316 18 L316 40 L360 40 L360 28 L400 28 L400 8 L436 8 L436 36 L480 36 L480 22 L524 22 L524 44 L566 44 L566 16 L610 16 L610 38 L652 38 L652 30 L680 30 L680 60 Z';
const String predioPerto = 'M0 30 L0 18 L52 18 L52 8 L96 8 L96 22 L150 22 L150 14 L206 14 L206 24 L262 24 L262 10 L312 10 L312 20 L370 20 L370 12 L424 12 L424 22 L482 22 L482 6 L534 6 L534 18 L590 18 L590 26 L640 26 L640 16 L680 16 L680 30 Z';

const double predioLongeY = -14;
const double predioPertoY = 20;

/// Quanto tempo cada camada leva para percorrer uma largura inteira.
///
/// A de tras leva mais que o dobro da de frente, e essa diferenca e a unica
/// coisa que produz a sensacao de profundidade.
const double segundosLonge = 44;
const double segundosPerto = 19;

const double chaoY = 52;
const double chaoAltura = 6;

/// Onde o gato fica. Ele nao anda para os lados: o cenario desliza atras dele.
const double gatoX = 150;
const double gatoY = 52;

/// Quanto dura um passo completo, em segundos.
const double passoSegundos = 0.85;

/// Letreiros de neon dos predios da frente, so na faixa noturna.
const List<(Rect, Color)> neonsDaFaixa = [
  (Rect.fromLTWH(30, 42, 16, 3), Color(0xFFFF2D95)),
  (Rect.fromLTWH(160, 36, 3, 12), Color(0xFF00E5FF)),
  (Rect.fromLTWH(300, 43, 13, 3), Color(0xFF39FF14)),
  (Rect.fromLTWH(430, 37, 3, 11), Color(0xFFFFE14D)),
  (Rect.fromLTWH(570, 42, 15, 3), Color(0xFFFF2D95)),
];

/// Uma faixa: as quatro cores e o que ela tem de especial.
class FaixaDoCenario {
  final String nome;
  final Color ceu;
  final Color longe;
  final Color perto;
  final Color chao;
  final bool temSol;
  final bool temNeon;

  const FaixaDoCenario({
    required this.nome,
    required this.ceu,
    required this.longe,
    required this.perto,
    required this.chao,
    required this.temSol,
    required this.temNeon,
  });
}

const Map<String, FaixaDoCenario> faixas = {
  'dia': FaixaDoCenario(
    nome: 'dia',
    ceu: Color(0xFF3E6B8C),
    longe: Color(0xFF2C4E68),
    perto: Color(0xFF1B3346),
    chao: Color(0xFF14283A),
    temSol: false,
    temNeon: false,
  ),
  'tarde': FaixaDoCenario(
    nome: 'tarde',
    ceu: Color(0xFFB03D6E),
    longe: Color(0xFF7A2A6B),
    perto: Color(0xFF4E1A57),
    chao: Color(0xFF3E1145),
    temSol: true,
    temNeon: false,
  ),
  'noite': FaixaDoCenario(
    nome: 'noite',
    ceu: Color(0xFF170A31),
    longe: Color(0xFF241847),
    perto: Color(0xFF0E0524),
    chao: Color(0xFF0F0620),
    temSol: false,
    temNeon: true,
  ),
};

/// Que tipo de forma o painter deve desenhar.
enum TipoDeForma { oval, disco, forma, traco, caixa, membro }

/// Uma peca do desenho do gato.
///
/// Um tipo so, com os campos que sobram nulos, em vez de seis classes: a lista
/// e gerada, lida em ordem e desenhada em sequencia, entao hierarquia aqui
/// custaria mais do que resolve.
class FormaDoGato {
  final TipoDeForma tipo;
  final int cor;

  /// Caminho SVG, para [TipoDeForma.forma] e [TipoDeForma.traco].
  final String? d;

  final double a;
  final double b;
  final double c;
  final double e;

  /// Raio do canto arredondado, so na caixa.
  final double raio;

  /// Espessura, no traco e no membro.
  final double largura;

  const FormaDoGato._(
    this.tipo,
    this.cor, {
    this.d,
    this.a = 0,
    this.b = 0,
    this.c = 0,
    this.e = 0,
    this.raio = 0,
    this.largura = 0,
  });

  const FormaDoGato.oval(double cx, double cy, double rx, double ry, int cor)
      : this._(TipoDeForma.oval, cor, a: cx, b: cy, c: rx, e: ry);

  const FormaDoGato.disco(double cx, double cy, double r, int cor)
      : this._(TipoDeForma.disco, cor, a: cx, b: cy, c: r);

  const FormaDoGato.forma(String d, int cor)
      : this._(TipoDeForma.forma, cor, d: d);

  const FormaDoGato.traco(String d, int cor, double largura)
      : this._(TipoDeForma.traco, cor, d: d, largura: largura);

  const FormaDoGato.caixa(
    double x,
    double y,
    double w,
    double h,
    double raio,
    int cor,
  ) : this._(TipoDeForma.caixa, cor, a: x, b: y, c: w, e: h, raio: raio);

  /// Perna ou braco: a ponta vai de [a] ate [b] e volta, no ritmo do passo.
  const FormaDoGato.membro(
    double x1,
    double y1,
    double xa,
    double xb,
    double y2,
    int cor,
    double largura,
  ) : this._(
        TipoDeForma.membro,
        cor,
        a: x1,
        b: y1,
        c: xa,
        e: xb,
        raio: y2,
        largura: largura,
      );
}

/// O gato, em ordem de desenho: o que vem depois cobre o que veio antes.
const List<FormaDoGato> gato = [
  FormaDoGato.oval(0, 0, 13, 3, 0x66000000),
  FormaDoGato.traco('M7 -7 Q16 -6 18 -1', 0xFFC9CBE0, 2.5),
  FormaDoGato.disco(18.5, -0.5, 2.5, 0xFF39FF14),
  FormaDoGato.membro(-3, -7, -8, 2, 0, 0xFFF2F0FF, 4),
  FormaDoGato.membro(3, -7, 2, -8, 0, 0xFF9BA0B8, 4),
  FormaDoGato.membro(-7, -16, -12, -8, -8, 0xFFF2F0FF, 3.5),
  FormaDoGato.membro(7, -16, 8, 12, -8, 0xFF9BA0B8, 3.5),
  FormaDoGato.forma('M-8 -18 L-7 -6 L7 -6 L8 -18 Q0 -21 -8 -18 Z', 0xFFF2F0FF),
  FormaDoGato.forma('M0 -19.6 L0 -6 L7 -6 L8 -18 Q4 -20.3 0 -19.6 Z', 0xFFC9CBE0),
  FormaDoGato.traco('M0 -19.6 L0 -6', 0xFF00E5FF, 0.9),
  FormaDoGato.disco(4.5, -15.5, 1.1, 0xFF8A8FA6),
  FormaDoGato.disco(4.5, -10.5, 1.1, 0xFF8A8FA6),
  FormaDoGato.traco('M-6 -16 L-4 -14 L-6 -12', 0xFF39FF14, 1.1),
  FormaDoGato.traco('M-3 -12 L-1 -12', 0xFF39FF14, 1.1),
  FormaDoGato.forma('M-9 -34 L-7 -46 L-1 -35 Z', 0xFFF2F0FF),
  FormaDoGato.forma('M2 -35 L8 -46 L11 -32 Z', 0xFFC9CBE0),
  FormaDoGato.disco(0, -28, 11, 0xFFF2F0FF),
  FormaDoGato.forma('M0 -39 C6.08 -39 11 -34.08 11 -28 C11 -21.92 6.08 -17 0 -17 Z', 0xFFC9CBE0),
  FormaDoGato.disco(-5, -28, 3, 0xFF17092E),
  FormaDoGato.disco(-6.2, -29.2, 1.2, 0xFFFFFFFF),
  FormaDoGato.forma('M-2 -25 L2 -25 L0 -22.5 Z', 0xFFFF4FD8),
  FormaDoGato.traco('M-2.5 -21.5 Q0 -19.5 2.5 -21.5', 0xFF17092E, 1.4),
  FormaDoGato.caixa(0.5, -33, 13, 8, 2, 0xFF3A3E52),
  FormaDoGato.caixa(2.5, -31, 9, 4, 0, 0xFF39FF14),
];
