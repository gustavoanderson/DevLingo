"""Desenha o caminho de uma pergunta feita ao Tr∅nikAt, para o README.

    python3 tools/gerar_diagrama_ia.py

  docs/imagens/arquitetura-ia.svg

POR QUE UM GERADOR, E NAO UM SVG DESENHADO A MAO

Este repositorio ja tem a cicatriz: o icone do app foi feito a mao, o principio
"arte que nasce de codigo nao diverge da fonte" ficou escrito sem ninguem
cumprir, e o validador nao pega porque so confere o que tem gerador declarado.

Com gerador, `check_gerados_em_dia` compara o disco com o que este script
produz. Editar o SVG a mao passa a reprovar.

E ha um ganho que so aparece depois: as CAIXAS sao dados. Mudar o desenho e
mexer numa lista, e nao em quarenta coordenadas -- que e a mesma razao pela
qual `gerar_faixas.py` calcula a geometria do cenario em vez de guarda-la.

O QUE ELE NAO MOSTRA, DE PROPOSITO

Nada de endereco de servico, nome de modelo, piso da busca ou o canario. O
desenho e para quem abre o repositorio pela primeira vez: ele conta a FORMA da
decisao, nao a configuracao. Quem quiser o detalhe tem o CLAUDE.md.
"""
from __future__ import annotations

from pathlib import Path
from xml.sax.saxutils import escape

RAIZ = Path(__file__).resolve().parent.parent
SAIDA = RAIZ / "docs" / "imagens" / "arquitetura-ia.svg"

L, A = 1000, 610

# As cores sao as do projeto, copiadas de docs/paleta.md. O fundo escuro e
# proprio serve aos dois temas do GitHub: uma imagem com fundo nao depende de
# qual tema o leitor usa.
FUNDO = "#170A31"
SUPERFICIE = "#1E0F3E"
LINHA = "#3D2A66"
TEXTO = "#F2F0FF"
SUAVE = "#9B8FC7"
CIANO = "#00E5FF"
VISOR = "#39FF14"
MAGENTA = "#FF2D95"
AMARELO = "#FFE14D"
MONO = "ui-monospace, 'Cascadia Mono', Consolas, 'DejaVu Sans Mono', monospace"

# Cada etapa e um dado: rotulo, titulo, as linhas do corpo, e a cor do acento.
# A ORDEM E A HISTORIA -- entrada, modelo, saida --, e por isso ela mora numa
# lista em vez de em coordenadas espalhadas.
ETAPAS = [
    {
        "tag": "1. ENTRADA",
        "titulo": "A busca decide",
        "cor": CIANO,
        "linhas": [
            "A pergunta é comparada",
            "com exemplos conhecidos.",
            "",
            "Não reconheceu?",
            "Resposta fixa — o modelo",
            "nem chega a ser chamado.",
        ],
    },
    {
        "tag": "2. MODELO",
        "titulo": "Escreve, sem inventar",
        "cor": AMARELO,
        "linhas": [
            "Recebe SÓ a ficha do",
            "assunto, e a reescreve",
            "com a voz do personagem.",
            "",
            "Ele não tem acesso",
            "a mais nada.",
        ],
    },
    {
        "tag": "3. SAÍDA",
        "titulo": "O código confere",
        "cor": VISOR,
        "linhas": [
            "Cada afirmação é julgada",
            "contra a ficha, uma a uma.",
            "",
            "Qualquer falha? Descarta",
            "e fala o texto gravado.",
        ],
    },
]

# O que o desenho precisa dizer alem das tres caixas. Sao as decisoes que um
# recrutador reconhece -- e cada uma responde a pergunta "por que confiar nisto?"
PILARES = [
    (CIANO, "Quem decide é CÓDIGO, não o modelo",
     "modelo pequeno não pode ser a proteção do sistema"),
    (VISOR, "O juiz faz LAUDO, não veredito",
     "o código numera as frases; ele classifica cada número"),
    (MAGENTA, "Falhar cai para o texto gravado",
     "no pior caso nada melhora, e nada piora"),
]


def _texto(x, y, s, *, cor=TEXTO, tam=14, peso="400", meio=False, espaco="0"):
    ancora = ' text-anchor="middle"' if meio else ""
    return (
        f'<text x="{x}" y="{y}" fill="{cor}" font-family="{MONO}" '
        f'font-size="{tam}" font-weight="{peso}" letter-spacing="{espaco}"{ancora}>'
        f"{escape(s)}</text>"
    )


def _caixa(x, y, w, h, etapa):
    """Uma etapa do caminho.

    A FAIXA COLORIDA fica a ESQUERDA, e nao em volta: borda inteira colorida
    competiria com as outras duas caixas e o olho nao saberia por onde comecar.
    E a mesma escolha do cartao de trilha no app.
    """
    p = [
        f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="10" '
        f'fill="{SUPERFICIE}" stroke="{LINHA}" stroke-width="1"/>',
        f'<rect x="{x}" y="{y}" width="4" height="{h}" rx="2" fill="{etapa["cor"]}"/>',
        _texto(x + 20, y + 30, etapa["tag"], cor=etapa["cor"], tam=12, peso="700", espaco="1.5"),
        _texto(x + 20, y + 58, etapa["titulo"], tam=17, peso="700"),
    ]
    yy = y + 88
    for linha in etapa["linhas"]:
        if linha:
            p.append(_texto(x + 20, yy, linha, cor=SUAVE, tam=13))
        yy += 21
    return "\n  ".join(p)


def _seta(x, y):
    """A seta entre as caixas.

    ASCII-like, em traco simples: o CLAUDE.md registra que glifos de seta e de
    caixa NAO sao monoespacados na fonte do app, e o habito de desenhar a
    geometria em vez de escreve-la com caractere nasceu dali.
    """
    return (
        f'<path d="M {x} {y} l 22 0 m -7 -6 l 7 6 l -7 6" '
        f'fill="none" stroke="{SUAVE}" stroke-width="2" '
        f'stroke-linecap="round" stroke-linejoin="round"/>'
    )


def gerar_svg() -> str:
    partes = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{L}" height="{A}" '
        f'viewBox="0 0 {L} {A}" role="img" '
        f'aria-label="Como o Tr∅nikAt responde: a busca decide, o modelo escreve só a '
        f'partir da ficha, e o código confere cada afirmação antes de virar fala">',
        "<defs>",
        '  <linearGradient id="ceu" x1="0" y1="0" x2="0" y2="1">',
        '    <stop offset="0" stop-color="#1B0B3A"/>',
        f'    <stop offset="1" stop-color="{FUNDO}"/>',
        "  </linearGradient>",
        "</defs>",
        f'<rect width="{L}" height="{A}" fill="url(#ceu)"/>',
    ]

    partes.append(_texto(L // 2, 48, "COMO O Tr∅nikAt RESPONDE", cor=VISOR, tam=15,
                         peso="700", meio=True, espaco="3"))
    partes.append(_texto(L // 2, 76,
                         "a IA do DevLingo, e por que dá para confiar no que ela diz",
                         cor=SUAVE, tam=14, meio=True))

    # As tres caixas, espacadas por conta -- mudar a largura nao exige mexer em
    # coordenada nenhuma.
    larg, alt, topo = 288, 232, 110
    vao = (L - 2 * 40 - 3 * larg) // 2
    for i, etapa in enumerate(ETAPAS):
        x = 40 + i * (larg + vao)
        partes.append(_caixa(x, topo, larg, alt, etapa))
        if i < len(ETAPAS) - 1:
            partes.append(_seta(x + larg + (vao - 22) // 2, topo + alt // 2))

    partes.append(_texto(40, topo + alt + 48, "O QUE SUSTENTA ISSO", cor=TEXTO, tam=12,
                         peso="700", espaco="2"))

    y = topo + alt + 78
    for cor, titulo, porque in PILARES:
        partes.append(f'<circle cx="46" cy="{y - 5}" r="4" fill="{cor}"/>')
        partes.append(_texto(62, y, titulo, tam=14, peso="700"))
        partes.append(_texto(62, y + 19, porque, cor=SUAVE, tam=12))
        y += 46

    partes.append(_texto(L - 40, A - 26,
                         "sem chave de API  ·  custo zero  ·  o app funciona offline sem ele",
                         cor=SUAVE, tam=12, meio=False, espaco="0"))
    # Alinhado a direita por medida de texto seria fragil; o ancora resolve.
    partes[-1] = partes[-1].replace('<text x="%d"' % (L - 40),
                                    '<text text-anchor="end" x="%d"' % (L - 40))

    partes.append("</svg>")
    return "\n".join(partes) + "\n"


def main() -> int:
    SAIDA.parent.mkdir(parents=True, exist_ok=True)
    SAIDA.write_text(gerar_svg(), encoding="utf-8", newline="\n")
    print(f"escrito: {SAIDA.relative_to(RAIZ)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
