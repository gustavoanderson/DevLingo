#!/usr/bin/env python3
"""Gera o cenario de parallax do DevLingo, em dois formatos.

Rodar:  python3 tools/gerar_faixas.py
Saida:  assets/cenarios/faixa-{dia,tarde,noite}.svg   (referencia de arte)
        app/lib/ui/cenario_gerado.dart                (o que o app desenha)

## Por que dois formatos, e por que um gerador so

Os SVGs sao a referencia de arte: abrem no navegador, entram em pull request e
mostram o cenario parado. Mas o app **nao os usa**: a animacao deles e SMIL, que
o `flutter_svg` nao reproduz, e cada faixa e um arquivo unico com as camadas
dentro -- nao ha como deslizar uma camada sem a outra.

Entao o app desenha o cenario com `CustomPainter`. Isso criaria uma segunda
copia da geometria, e duas copias divergem: e exatamente o problema que este
gerador ja existia para resolver entre as tres faixas.

A saida foi fazer o gerador emitir **os dois**. As strings de caminho vao
identicas para o SVG e para o Dart, entao nao ha o que divergir. O validador
reprova se o arquivo Dart estiver desatualizado em relacao a este script.

## Editar isto, nunca os arquivos gerados

Mudou a silhueta dos predios, a cor de uma faixa ou o desenho do gato? Mexa
aqui e rode de novo. Editar o SVG ou o Dart a mao faz a proxima execucao
apagar a mudanca, e ate la os dois estao contando historias diferentes.
"""
from pathlib import Path

RAIZ = Path(__file__).parent.parent

LARGURA = 680
ALTURA = 58

# ---------------------------------------------------------------- predios
#
# Duas silhuetas, desenhadas so com linhas retas. Cada uma e desenhada DUAS
# vezes, lado a lado, e desliza exatamente `LARGURA`: e isso que torna o loop
# invisivel, porque o quadro em que ela volta ao inicio e identico ao anterior.

PREDIOS_LONGE = (
    "M0 60 L0 34 L40 34 L40 20 L74 20 L74 42 L110 42 L110 12 L146 12 L146 38 L190 38 "
    "L190 26 L232 26 L232 46 L276 46 L276 18 L316 18 L316 40 L360 40 L360 28 L400 28 "
    "L400 8 L436 8 L436 36 L480 36 L480 22 L524 22 L524 44 L566 44 L566 16 L610 16 "
    "L610 38 L652 38 L652 30 L680 30 L680 60 Z"
)
PREDIOS_PERTO = (
    "M0 30 L0 18 L52 18 L52 8 L96 8 L96 22 L150 22 L150 14 L206 14 L206 24 L262 24 "
    "L262 10 L312 10 L312 20 L370 20 L370 12 L424 12 L424 22 L482 22 L482 6 L534 6 "
    "L534 18 L590 18 L590 26 L640 26 L640 16 L680 16 L680 30 Z"
)

# Deslocamento vertical de cada camada, e quantos segundos ela leva para
# percorrer uma largura inteira. A de tras leva mais que o DOBRO do tempo da
# frente, e essa diferenca e a unica coisa que produz sensacao de profundidade.
LONGE_Y, LONGE_SEGUNDOS = -14, 44
PERTO_Y, PERTO_SEGUNDOS = 20, 19

# Letreiros de neon, so na faixa noturna: (x, y, largura, altura, cor)
NEONS = [
    (30, 42, 16, 3, "#FF2D95"),
    (160, 36, 3, 12, "#00E5FF"),
    (300, 43, 13, 3, "#39FF14"),
    (430, 37, 3, 11, "#FFE14D"),
    (570, 42, 15, 3, "#FF2D95"),
]

CHAO_Y, CHAO_ALTURA = 52, 6

FAIXAS = {
    "dia": dict(
        ceu="#3E6B8C", longe="#2C4E68", perto="#1B3346", chao="#14283A",
        sol=False, neon=False,
        desc="Faixa diurna: nevoa azulada, neons apagados.",
    ),
    "tarde": dict(
        ceu="#B03D6E", longe="#7A2A6B", perto="#4E1A57", chao="#3E1145",
        sol=True, neon=False,
        desc="Faixa de fim de tarde: sol listrado no estilo vaporwave.",
    ),
    "noite": dict(
        ceu="#170A31", longe="#241847", perto="#0E0524", chao="#0F0620",
        sol=False, neon=True,
        desc="Faixa noturna: neons acesos nos predios da frente.",
    ),
}

# ---------------------------------------------------------------- o gato
#
# O Tr0nikAt em variante de tamanho pequeno: cabeca proporcionalmente maior e
# tracos mais grossos. Em tamanho miudo nao se reduz o desenho, redesenha-se.
#
# A origem (0,0) fica nos pes. Y negativo sobe.
#
# Primitivas, e o que cada uma vira nos dois formatos:
#   oval    -> <ellipse>            / canvas.drawOval
#   disco   -> <circle>             / canvas.drawCircle
#   forma   -> <path fill>          / canvas.drawPath preenchido
#   traco   -> <path stroke>        / canvas.drawPath contornado
#   caixa   -> <rect>               / canvas.drawRRect
#   membro  -> <line> com <animate> / linha com a ponta oscilando
#
# Um `membro` tem a ponta indo de `xa` (no inicio do passo) ate `xb` (no meio) e
# voltando. Sao os mesmos extremos dos valores SMIL do SVG, e a interpolacao por
# cosseno reproduz o vaivem sem os cinco quadros intermediarios escritos a mao.
PASSO_SEGUNDOS = 0.85

GATO = [
    ("oval", 0, 0, 13, 3, "#000000", 0.4),
    ("traco", "M8 -14 Q17 -17 16 -26", "#C9CBE0", 2.5),
    ("disco", 16, -27, 2.5, "#39FF14"),
    # Pernas e bracos ficam atras do corpo, entao vem antes dele.
    ("membro", -3, -7, -8, 2, 0, "#F2F0FF", 4),
    ("membro", 3, -7, 2, -8, 0, "#9BA0B8", 4),
    ("membro", -7, -16, -12, -8, -8, "#F2F0FF", 3.5),
    ("membro", 7, -16, 8, 12, -8, "#9BA0B8", 3.5),
    ("forma", "M-8 -18 L-7 -6 L7 -6 L8 -18 Q0 -21 -8 -18 Z", "#2A1B4D"),
    ("traco", "M-6 -18 Q0 -15 6 -18", "#FF2D95", 1.8),
    ("forma", "M-9 -34 L-7 -46 L-1 -35 Z", "#F2F0FF"),
    ("forma", "M2 -35 L8 -46 L11 -32 Z", "#C9CBE0"),
    ("disco", 0, -28, 11, "#F2F0FF"),
    # A metade metalica da cabeca, em Bezier e nao em arco.
    #
    # Aqui havia `A 11 11 0 0 1 0 -17`, e a corda entre os dois pontos mede 22,
    # que e exatamente `2 x raio`: o caso-limite do arco eliptico, onde erro de
    # ponto flutuante pode degenerar a figura. O retrato do mascote ja levou uma
    # rodada de depuracao por causa disso, entao aqui nasce em Bezier.
    ("forma", "M0 -39 C6.08 -39 11 -34.08 11 -28 C11 -21.92 6.08 -17 0 -17 Z", "#C9CBE0"),
    ("disco", -5, -28, 3, "#17092E"),
    ("disco", -6.2, -29.2, 1.2, "#FFFFFF"),
    ("forma", "M-2 -25 L2 -25 L0 -22.5 Z", "#FF4FD8"),
    ("traco", "M-2.5 -21.5 Q0 -19.5 2.5 -21.5", "#17092E", 1.4),
    ("caixa", 0.5, -33, 13, 8, 2, "#3A3E52"),
    ("caixa", 2.5, -31, 9, 4, 0, "#39FF14"),
]

# Onde o gato fica na faixa. Ele nao anda para os lados: o cenario e que desliza.
GATO_X, GATO_Y = 150, 52


# ---------------------------------------------------------------- SVG


def svg_do_gato():
    """O gato em SVG, com o vaivem em SMIL.

    O SMIL nao roda no app -- e o proprio `desc` do arquivo avisa isso. Ele
    existe para o SVG aberto no navegador mostrar a caminhada, que e o que torna
    a referencia de arte util para revisar.
    """
    partes = []
    for f in GATO:
        tipo = f[0]
        if tipo == "oval":
            _, cx, cy, rx, ry, cor, op = f
            partes.append(
                f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" '
                f'fill="{cor}" opacity="{op}"/>'
            )
        elif tipo == "disco":
            _, cx, cy, r, cor = f
            partes.append(f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{cor}"/>')
        elif tipo == "forma":
            _, d, cor = f
            partes.append(f'<path d="{d}" fill="{cor}"/>')
        elif tipo == "traco":
            _, d, cor, larg = f
            partes.append(
                f'<path d="{d}" stroke="{cor}" stroke-width="{larg}" '
                f'fill="none" stroke-linecap="round"/>'
            )
        elif tipo == "caixa":
            _, x, y, w, h, rx, cor = f
            arred = f' rx="{rx}"' if rx else ""
            partes.append(
                f'<rect x="{x}" y="{y}" width="{w}" height="{h}"{arred} fill="{cor}"/>'
            )
        elif tipo == "membro":
            _, x1, y1, xa, xb, y2, cor, larg = f
            meio = (xa + xb) / 2
            valores = f"{xa};{meio};{xb};{meio};{xa}"
            partes.append(
                f'<line x1="{x1}" y1="{y1}" x2="{xa}" y2="{y2}" stroke="{cor}" '
                f'stroke-width="{larg}" stroke-linecap="round">'
                f'<animate attributeName="x2" values="{valores}" '
                f'dur="{PASSO_SEGUNDOS}s" repeatCount="indefinite"/></line>'
            )
        else:
            raise ValueError(f"primitiva desconhecida no gato: {tipo}")
    return "<g id=\"cat\">\n" + "\n".join(partes) + "\n</g>"


def gerar_svg(nome, c):
    sol = ""
    if c["sol"]:
        sol = (
            f'<circle cx="520" cy="34" r="32" fill="#FF9E6B"/>'
            f'<rect x="484" y="22" width="72" height="3" fill="{c["ceu"]}"/>'
            f'<rect x="484" y="31" width="72" height="4" fill="{c["ceu"]}"/>'
            f'<rect x="484" y="42" width="72" height="5" fill="{c["ceu"]}"/>'
        )

    neon = ""
    if c["neon"]:
        for x, y, w, h, cor in NEONS:
            neon += f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{cor}"/>'
            neon += (
                f'<rect x="{x + LARGURA}" y="{y}" width="{w}" height="{h}" fill="{cor}"/>'
            )

    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{LARGURA}" height="{ALTURA}" viewBox="0 0 {LARGURA} {ALTURA}" role="img">
<title>DevLingo :: faixa de cenario ({nome})</title>
<desc>{c['desc']} O Tr0nikAt caminha parado enquanto as camadas deslizam. ATENCAO: a animacao aqui usa SMIL e NAO e reproduzida pelo flutter_svg. O app nao le este arquivo; ele desenha o mesmo cenario a partir de app/lib/ui/cenario_gerado.dart, gerado por tools/gerar_faixas.py junto com este SVG.</desc>
<defs><path id="far" d="{PREDIOS_LONGE}"/><path id="near" d="{PREDIOS_PERTO}"/>
{svg_do_gato()}</defs>
<rect x="0" y="0" width="{LARGURA}" height="{ALTURA}" fill="{c['ceu']}"/>{sol}
<g fill="{c['longe']}"><animateTransform attributeName="transform" type="translate" values="-{LARGURA} 0;0 0" dur="{LONGE_SEGUNDOS}s" repeatCount="indefinite"/><use href="#far" x="0" y="{LONGE_Y}"/><use href="#far" x="{LARGURA}" y="{LONGE_Y}"/></g>
<g><animateTransform attributeName="transform" type="translate" values="-{LARGURA} 0;0 0" dur="{PERTO_SEGUNDOS}s" repeatCount="indefinite"/><use href="#near" x="0" y="{PERTO_Y}" fill="{c['perto']}"/><use href="#near" x="{LARGURA}" y="{PERTO_Y}" fill="{c['perto']}"/>{neon}</g>
<rect x="0" y="{CHAO_Y}" width="{LARGURA}" height="{CHAO_ALTURA}" fill="{c['chao']}"/>
<use href="#cat" transform="translate({GATO_X} {GATO_Y})"/>
</svg>
"""


# ---------------------------------------------------------------- Dart


def cor_dart(hexa, opacidade=1.0):
    """`#RRGGBB` vira `0xAARRGGBB`, que e como o Dart escreve cor."""
    alfa = round(opacidade * 255)
    return f"0x{alfa:02X}{hexa.lstrip('#').upper()}"


def gerar_dart():
    formas = []
    for f in GATO:
        tipo = f[0]
        if tipo == "oval":
            _, cx, cy, rx, ry, cor, op = f
            formas.append(
                f"  FormaDoGato.oval({cx}, {cy}, {rx}, {ry}, {cor_dart(cor, op)}),"
            )
        elif tipo == "disco":
            _, cx, cy, r, cor = f
            formas.append(f"  FormaDoGato.disco({cx}, {cy}, {r}, {cor_dart(cor)}),")
        elif tipo == "forma":
            _, d, cor = f
            formas.append(f"  FormaDoGato.forma('{d}', {cor_dart(cor)}),")
        elif tipo == "traco":
            _, d, cor, larg = f
            formas.append(f"  FormaDoGato.traco('{d}', {cor_dart(cor)}, {larg}),")
        elif tipo == "caixa":
            _, x, y, w, h, rx, cor = f
            formas.append(
                f"  FormaDoGato.caixa({x}, {y}, {w}, {h}, {rx}, {cor_dart(cor)}),"
            )
        elif tipo == "membro":
            _, x1, y1, xa, xb, y2, cor, larg = f
            formas.append(
                f"  FormaDoGato.membro({x1}, {y1}, {xa}, {xb}, {y2}, "
                f"{cor_dart(cor)}, {larg}),"
            )

    faixas = []
    for nome, c in FAIXAS.items():
        faixas.append(
            f"""  '{nome}': FaixaDoCenario(
    nome: '{nome}',
    ceu: Color({cor_dart(c['ceu'])}),
    longe: Color({cor_dart(c['longe'])}),
    perto: Color({cor_dart(c['perto'])}),
    chao: Color({cor_dart(c['chao'])}),
    temSol: {str(c['sol']).lower()},
    temNeon: {str(c['neon']).lower()},
  ),"""
        )

    neons = [
        f"  (Rect.fromLTWH({x}, {y}, {w}, {h}), Color({cor_dart(cor)})),"
        for x, y, w, h, cor in NEONS
    ]

    return f"""// GERADO POR tools/gerar_faixas.py -- NAO EDITE A MAO.
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
const double larguraDaFaixa = {LARGURA};
const double alturaDaFaixa = {ALTURA};

/// Silhuetas dos predios. Cada uma e desenhada duas vezes, lado a lado.
const String predioLonge = '{PREDIOS_LONGE}';
const String predioPerto = '{PREDIOS_PERTO}';

const double predioLongeY = {LONGE_Y};
const double predioPertoY = {PERTO_Y};

/// Quanto tempo cada camada leva para percorrer uma largura inteira.
///
/// A de tras leva mais que o dobro da de frente, e essa diferenca e a unica
/// coisa que produz a sensacao de profundidade.
const double segundosLonge = {LONGE_SEGUNDOS};
const double segundosPerto = {PERTO_SEGUNDOS};

const double chaoY = {CHAO_Y};
const double chaoAltura = {CHAO_ALTURA};

/// Onde o gato fica. Ele nao anda para os lados: o cenario desliza atras dele.
const double gatoX = {GATO_X};
const double gatoY = {GATO_Y};

/// Quanto dura um passo completo, em segundos.
const double passoSegundos = {PASSO_SEGUNDOS};

/// Letreiros de neon dos predios da frente, so na faixa noturna.
const List<(Rect, Color)> neonsDaFaixa = [
{chr(10).join(neons)}
];

/// Uma faixa: as quatro cores e o que ela tem de especial.
class FaixaDoCenario {{
  final String nome;
  final Color ceu;
  final Color longe;
  final Color perto;
  final Color chao;
  final bool temSol;
  final bool temNeon;

  const FaixaDoCenario({{
    required this.nome,
    required this.ceu,
    required this.longe,
    required this.perto,
    required this.chao,
    required this.temSol,
    required this.temNeon,
  }});
}}

const Map<String, FaixaDoCenario> faixas = {{
{chr(10).join(faixas)}
}};

/// Que tipo de forma o painter deve desenhar.
enum TipoDeForma {{ oval, disco, forma, traco, caixa, membro }}

/// Uma peca do desenho do gato.
///
/// Um tipo so, com os campos que sobram nulos, em vez de seis classes: a lista
/// e gerada, lida em ordem e desenhada em sequencia, entao hierarquia aqui
/// custaria mais do que resolve.
class FormaDoGato {{
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
    this.cor, {{
    this.d,
    this.a = 0,
    this.b = 0,
    this.c = 0,
    this.e = 0,
    this.raio = 0,
    this.largura = 0,
  }});

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
}}

/// O gato, em ordem de desenho: o que vem depois cobre o que veio antes.
const List<FormaDoGato> gato = [
{chr(10).join(formas)}
];
"""


if __name__ == "__main__":
    destino_svg = RAIZ / "assets" / "cenarios"
    destino_svg.mkdir(parents=True, exist_ok=True)
    for nome, cores in FAIXAS.items():
        arquivo = destino_svg / f"faixa-{nome}.svg"
        arquivo.write_text(gerar_svg(nome, cores), encoding="utf-8", newline="\n")
        print(f"gerado: {arquivo.relative_to(RAIZ)}")

    destino_dart = RAIZ / "app" / "lib" / "ui" / "cenario_gerado.dart"
    destino_dart.write_text(gerar_dart(), encoding="utf-8", newline="\n")
    print(f"gerado: {destino_dart.relative_to(RAIZ)}")
