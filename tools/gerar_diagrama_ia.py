"""Desenha a arquitetura do DevLingo para o README.

    python3 tools/gerar_diagrama_ia.py

  docs/imagens/arquitetura-ia.svg

POR QUE UM GERADOR, E NAO UM SVG DESENHADO A MAO

Este repositorio ja tem a cicatriz: o icone do app foi feito a mao, o principio
"arte que nasce de codigo nao diverge da fonte" ficou escrito sem ninguem
cumprir, e o validador nao pega porque so confere o que TEM gerador declarado.

Com gerador, `check_gerados_em_dia` compara o disco com o que este script
produz. Editar o SVG a mao passa a reprovar.

DOIS FLUXOS, E NAO UM

A primeira versao desenhou so o caminho da pergunta, em tres caixas de texto
corrido. O Gustavo reprovou: "nao esta clara, a linguagem esta muito de IA.
Gosto de FLUXOGRAMAS com quadrados e setas".

O diagnostico dele e preciso: aquilo era um RESUMO EM TRES COLUNAS, nao um
fluxograma. Faltavam as duas coisas que fazem um fluxograma ensinar -- o que
entra e o que sai, e o que acontece quando a resposta e NAO.

Aqui sao dois caminhos, porque o DevLingo tem dois:

    PERGUNTAR ao mascote -> Cloudflare e Oracle
    JOGAR e salvar       -> SQLite local e Firebase

E OS NOMES SAO REAIS. "Dar nome aos bois" foi pedido explicito dele: um
recrutador reconhece `qwen3`, `Firestore` e `Cloudflare`, e nao reconhece
"o modelo" nem "a nuvem".

O QUE ELE NAO MOSTRA: o piso da busca, o canario e o conteudo das instrucoes.
Ele conta a FORMA da decisao, nao a configuracao que protege o sistema.
"""
from __future__ import annotations

import math
from pathlib import Path
from xml.sax.saxutils import escape

RAIZ = Path(__file__).resolve().parent.parent
SAIDA = RAIZ / "docs" / "imagens" / "arquitetura-ia.svg"

L, A = 1180, 820

# Cores do projeto, copiadas de docs/paleta.md. Fundo escuro proprio serve aos
# dois temas do GitHub: imagem com fundo nao depende do tema do leitor.
FUNDO = "#170A31"
SUPERFICIE = "#241449"
LINHA = "#4A3577"
TEXTO = "#F2F0FF"
SUAVE = "#B3A7DB"
CIANO = "#00E5FF"
VISOR = "#39FF14"
MAGENTA = "#FF2D95"
AMARELO = "#FFE14D"
LARANJA = "#FF9F45"
MONO = "ui-monospace, 'Cascadia Mono', Consolas, 'DejaVu Sans Mono', monospace"


def txt(x, y, s, *, cor=TEXTO, tam=15, peso="400", meio=False, fim=False, espaco="0"):
    a = ' text-anchor="middle"' if meio else (' text-anchor="end"' if fim else "")
    return (
        f'<text x="{x}" y="{y}" fill="{cor}" font-family="{MONO}" font-size="{tam}" '
        f'font-weight="{peso}" letter-spacing="{espaco}"{a}>{escape(s)}</text>'
    )


def caixa(x, y, w, h, titulo, sub, cor, *, marca=""):
    """Um retangulo do fluxo.

    A COR E O TIPO DE PECA, e nao decoracao: ciano e o que roda no aparelho,
    amarelo e a Cloudflare, laranja e a Oracle, magenta e o Firebase. A legenda
    embaixo amarra cada cor a um nome -- sem isso, cor vira enfeite.
    """
    p = [
        f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="8" fill="{SUPERFICIE}" '
        f'stroke="{cor}" stroke-width="2"/>',
        txt(x + w / 2, y + 28, titulo, tam=16, peso="700", meio=True),
    ]
    yy = y + 50
    for linha in sub:
        p.append(txt(x + w / 2, yy, linha, cor=SUAVE, tam=12, meio=True))
        yy += 17
    if marca:
        p.append(txt(x + w - 9, y + h - 9, marca, cor=cor, tam=13, peso="700", fim=True))
    return "\n".join(p)


def losango(cx, cy, w, h, titulo, cor, sub=""):
    """A decisao. Losango porque e o que um fluxograma usa, e o formato avisa
    que dali saem dois caminhos antes de alguem ler o texto."""
    p = [
        f'<path d="M {cx} {cy - h / 2} L {cx + w / 2} {cy} L {cx} {cy + h / 2} '
        f'L {cx - w / 2} {cy} Z" fill="{SUPERFICIE}" stroke="{cor}" stroke-width="2"/>',
        txt(cx, cy + (0 if sub else 5), titulo, tam=14, peso="700", meio=True),
    ]
    if sub:
        p.append(txt(cx, cy + 17, sub, cor=SUAVE, tam=11, meio=True))
    return "\n".join(p)


def seta(x1, y1, x2, y2, *, rotulo="", cor=SUAVE, acima=True):
    """Seta reta com ponta desenhada.

    A PONTA E GEOMETRIA, e nao um glifo de texto: o CLAUDE.md mede que
    caractere de seta NAO e monoespacado, e quem desenha com ele fica com o
    desenho torto conforme a fonte disponivel.
    """
    ang = math.atan2(y2 - y1, x2 - x1)
    px, py = x2 - 11 * math.cos(ang), y2 - 11 * math.sin(ang)
    a1, a2 = ang + 2.6, ang - 2.6
    p = [
        f'<line x1="{x1}" y1="{y1}" x2="{px:.1f}" y2="{py:.1f}" stroke="{cor}" '
        f'stroke-width="2.5" stroke-linecap="round"/>',
        f'<path d="M {x2} {y2} L {x2 + 12 * math.cos(a1):.1f} {y2 + 12 * math.sin(a1):.1f} '
        f'L {x2 + 12 * math.cos(a2):.1f} {y2 + 12 * math.sin(a2):.1f} Z" fill="{cor}"/>',
    ]
    if rotulo:
        mx, my = (x1 + x2) / 2, (y1 + y2) / 2
        # Rotulo de seta horizontal sobe; de seta vertical desvia para o lado.
        # Sem isso ele cai em cima do proprio traco.
        if abs(y2 - y1) < 6:
            p.append(txt(mx, my - 11 if acima else my + 20, rotulo, cor=cor, tam=12,
                         peso="700", meio=True))
        else:
            p.append(txt(mx + 11, my + 4, rotulo, cor=cor, tam=12, peso="700"))
    return "\n".join(p)


def cotovelo(x1, y1, x2, y2, *, cor=SUAVE, rotulo=""):
    """Liga dois pontos descendo primeiro e virando depois.

    Existe porque seta reta entre caixas de alturas diferentes cruza o que
    estiver no meio -- e um fluxograma com traco por cima de caixa deixa de
    ser legivel exatamente onde precisa ser.
    """
    ang = 0 if x2 > x1 else math.pi
    px = x2 - 11 * math.cos(ang)
    a1, a2 = ang + 2.6, ang - 2.6
    p = [
        f'<path d="M {x1} {y1} L {x1} {y2} L {px:.1f} {y2}" fill="none" stroke="{cor}" '
        f'stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/>',
        f'<path d="M {x2} {y2} L {x2 + 12 * math.cos(a1):.1f} {y2 + 12 * math.sin(a1):.1f} '
        f'L {x2 + 12 * math.cos(a2):.1f} {y2 + 12 * math.sin(a2):.1f} Z" fill="{cor}"/>',
    ]
    if rotulo:
        p.append(txt(x1 + 11, (y1 + y2) / 2, rotulo, cor=cor, tam=12, peso="700"))
    return "\n".join(p)


def gerar_svg() -> str:
    o = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{L}" height="{A}" '
        f'viewBox="0 0 {L} {A}" role="img" aria-label="Arquitetura do DevLingo: '
        f'o aluno pergunta ao mascote e a resposta passa por busca, geração e '
        f'conferência na Cloudflare e por síntese de voz na Oracle; e o aluno joga, '
        f'com o progresso salvo em SQLite local e sincronizado pelo Firebase">',
        f'<rect width="{L}" height="{A}" fill="{FUNDO}"/>',
    ]

    o.append(txt(L / 2, 44, "COMO O DEVLINGO FUNCIONA POR DENTRO", cor=VISOR,
                 tam=21, peso="700", meio=True, espaco="2"))
    o.append(txt(L / 2, 70, "dois caminhos: perguntar ao mascote, e jogar",
                 cor=SUAVE, tam=14, meio=True))

    # ============================================ FLUXO 1: a pergunta ao mascote
    #
    # AS COORDENADAS SAIRAM DE UM RENDER, e nao de estimativa. A primeira
    # tentativa punha a voz embaixo do losango e a saida a direita, e quatro
    # rotulos cairam em cima de caixa -- "REPROVOU" por cima de "FALA", a
    # resposta colada na borda. Aqui a linha principal TERMINA na entrega, e o
    # unico traco que desce pela direita tem a faixa livre para descer.
    o.append(f'<rect x="24" y="94" width="{L - 48}" height="330" rx="12" '
             f'fill="none" stroke="{LINHA}" stroke-width="1"/>')
    o.append(txt(44, 122, "1 · O ALUNO PERGUNTA AO Tr∅nikAt", cor=CIANO, tam=15,
                 peso="700", espaco="1.5"))

    y, h = 200, 80
    o.append(caixa(44, y - h / 2, 156, h, "ALUNO",
                   ["digita a pergunta", "no app ou no site"], CIANO))
    o.append(seta(200, y, 240, y))

    o.append(caixa(244, y - h / 2, 166, h, "ACHA O ASSUNTO",
                   ["embeddinggemma-300m"], AMARELO, marca="*"))
    o.append(seta(410, y, 444, y))

    o.append(losango(512, y, 136, 86, "reconhece?", AMARELO))
    o.append(seta(580, y, 614, y, rotulo="SIM", cor=VISOR))

    o.append(caixa(618, y - h / 2, 172, h, "ESCREVE",
                   ["qwen3-30b-a3b", "só a partir da ficha"], AMARELO, marca="*"))
    o.append(seta(790, y, 824, y))

    o.append(losango(890, y, 132, 86, "aprova?", VISOR, sub="frase a frase"))
    o.append(txt(890, y - 62, "llama-3.2-3b julga cada", cor=SUAVE, tam=11, meio=True))
    o.append(txt(890, y - 49, "afirmação contra a ficha", cor=SUAVE, tam=11, meio=True))
    o.append(seta(956, y, 990, y, rotulo="SIM", cor=VISOR))

    o.append(caixa(994, y - h / 2, 162, h, "ENTREGA",
                   ["texto na tela", "+ voz do Piper"], LARANJA, marca="**"))

    # As duas recusas caem no MESMO lugar, e e isso que o desenho precisa
    # mostrar: falhar nunca inventa -- recita o que ja estava escrito.
    yb = 356
    o.append(caixa(300, yb - 32, 400, 64, "RESPONDE O TEXTO JÁ GRAVADO",
                   ["escrito e revisado por uma pessoa"], MAGENTA))
    o.append(seta(512, y + 43, 512, yb - 32, rotulo="NÃO", cor=MAGENTA))
    o.append(cotovelo(890, y + 43, 704, yb, cor=MAGENTA, rotulo="REPROVOU"))

    # ============================================ FLUXO 2: o progresso
    o.append(f'<rect x="24" y="448" width="{L - 48}" height="180" rx="12" '
             f'fill="none" stroke="{LINHA}" stroke-width="1"/>')
    o.append(txt(44, 476, "2 · O ALUNO JOGA, E O PROGRESSO O SEGUE", cor=CIANO,
                 tam=15, peso="700", espaco="1.5"))

    y2 = 556
    o.append(caixa(44, y2 - h / 2, 170, h, "RESPONDE", ["uma questão"], CIANO))
    o.append(seta(214, y2, 252, y2))
    o.append(caixa(256, y2 - h / 2, 204, h, "SALVA NO APARELHO",
                   ["SQLite", "funciona sem internet"], CIANO))
    # O vao aqui e MAIOR que os outros porque o rotulo e mais longo: "tem
    # rede?" com o vao padrao caia por cima da caixa da esquerda.
    o.append(seta(460, y2, 546, y2, rotulo="tem rede?"))
    o.append(caixa(550, y2 - h / 2, 210, h, "FIREBASE",
                   ["Auth + Firestore", "login e histórico"], MAGENTA, marca="***"))
    o.append(seta(760, y2, 798, y2))
    o.append(caixa(802, y2 - h / 2, 254, h, "OUTRO APARELHO",
                   ["continua de onde parou", "celular ou navegador"], CIANO))

    # ============================================ legenda
    o.append(txt(44, 674, "ONDE CADA PARTE RODA", cor=TEXTO, tam=13, peso="700", espaco="1.5"))
    legenda = [
        (AMARELO, "*", "Cloudflare Workers AI",
         "busca e geração rodam na borda, camada gratuita — não há chave de API"),
        (LARANJA, "**", "Oracle Cloud · VM Always Free",
         "a voz é sintetizada por Piper numa máquina de 1/8 de OCPU, custo zero"),
        (MAGENTA, "***", "Firebase · Google",
         "o Auth guarda a senha, e nosso código nunca a vê; o Firestore, o histórico"),
    ]
    yl = 704
    for cor, marca, nome, porque in legenda:
        o.append(f'<rect x="44" y="{yl - 11}" width="12" height="12" rx="3" fill="{cor}"/>')
        o.append(txt(66, yl, marca, cor=cor, tam=13, peso="700"))
        o.append(txt(104, yl, nome, cor=cor, tam=14, peso="700"))
        o.append(txt(420, yl, porque, cor=SUAVE, tam=13))
        yl += 30

    o.append(txt(L - 34, A - 20,
                 "sem internet o jogo continua inteiro — só o mascote fica esperando",
                 cor=SUAVE, tam=13, fim=True))
    o.append("</svg>")
    return "\n".join(o) + "\n"


def main() -> int:
    SAIDA.parent.mkdir(parents=True, exist_ok=True)
    SAIDA.write_text(gerar_svg(), encoding="utf-8", newline="\n")
    print(f"escrito: {SAIDA.relative_to(RAIZ)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
