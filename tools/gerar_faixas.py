#!/usr/bin/env python3
"""Gera os tres SVGs de faixa de cenario a partir de um molde unico.

Rodar:  python3 tools/gerar_faixas.py
Saida:  assets/cenarios/faixa-{dia,tarde,noite}.svg

Um molde so garante que as tres faixas tenham exatamente a mesma silhueta de
predios e o mesmo ritmo de parallax. Se fossem tres arquivos escritos a mao,
qualquer ajuste teria que ser repetido tres vezes e uma delas ficaria para tras.
"""
from pathlib import Path

FAR = ("M0 60 L0 34 L40 34 L40 20 L74 20 L74 42 L110 42 L110 12 L146 12 L146 38 L190 38 "
       "L190 26 L232 26 L232 46 L276 46 L276 18 L316 18 L316 40 L360 40 L360 28 L400 28 "
       "L400 8 L436 8 L436 36 L480 36 L480 22 L524 22 L524 44 L566 44 L566 16 L610 16 "
       "L610 38 L652 38 L652 30 L680 30 L680 60 Z")
NEAR = ("M0 30 L0 18 L52 18 L52 8 L96 8 L96 22 L150 22 L150 14 L206 14 L206 24 L262 24 "
        "L262 10 L312 10 L312 20 L370 20 L370 12 L424 12 L424 22 L482 22 L482 6 L534 6 "
        "L534 18 L590 18 L590 26 L640 26 L640 16 L680 16 L680 30 Z")

# O Tr0nikAt em variante de tamanho pequeno: cabeca proporcionalmente maior e
# tracos mais grossos. Em tamanho miudo nao se reduz o desenho, redesenha-se.
CAT = """<g id="cat">
<ellipse cx="0" cy="0" rx="13" ry="3" fill="#000000" opacity="0.4"/>
<path d="M8 -14 Q17 -17 16 -26" stroke="#C9CBE0" stroke-width="2.5" fill="none" stroke-linecap="round"/>
<circle cx="16" cy="-27" r="2.5" fill="#39FF14"/>
<line x1="-3" y1="-7" x2="-5" y2="0" stroke="#F2F0FF" stroke-width="4" stroke-linecap="round"><animate attributeName="x2" values="-8;-3;2;-3;-8" dur="0.85s" repeatCount="indefinite"/></line>
<line x1="3" y1="-7" x2="5" y2="0" stroke="#9BA0B8" stroke-width="4" stroke-linecap="round"><animate attributeName="x2" values="2;-3;-8;-3;2" dur="0.85s" repeatCount="indefinite"/></line>
<line x1="-7" y1="-16" x2="-11" y2="-8" stroke="#F2F0FF" stroke-width="3.5" stroke-linecap="round"><animate attributeName="x2" values="-12;-10;-8;-10;-12" dur="0.85s" repeatCount="indefinite"/></line>
<line x1="7" y1="-16" x2="11" y2="-8" stroke="#9BA0B8" stroke-width="3.5" stroke-linecap="round"><animate attributeName="x2" values="8;10;12;10;8" dur="0.85s" repeatCount="indefinite"/></line>
<path d="M-8 -18 L-7 -6 L7 -6 L8 -18 Q0 -21 -8 -18 Z" fill="#2A1B4D"/>
<path d="M-6 -18 Q0 -15 6 -18" stroke="#FF2D95" stroke-width="1.8" fill="none"/>
<polygon points="-9,-34 -7,-46 -1,-35" fill="#F2F0FF"/>
<polygon points="2,-35 8,-46 11,-32" fill="#C9CBE0"/>
<circle cx="0" cy="-28" r="11" fill="#F2F0FF"/>
<path d="M0 -39 A 11 11 0 0 1 0 -17 Z" fill="#C9CBE0"/>
<circle cx="-5" cy="-28" r="3" fill="#17092E"/>
<circle cx="-6.2" cy="-29.2" r="1.2" fill="#FFFFFF"/>
<polygon points="-2,-25 2,-25 0,-22.5" fill="#FF4FD8"/>
<path d="M-2.5 -21.5 Q0 -19.5 2.5 -21.5" stroke="#17092E" stroke-width="1.4" fill="none" stroke-linecap="round"/>
<rect x="0.5" y="-33" width="13" height="8" rx="2" fill="#3A3E52"/>
<rect x="2.5" y="-31" width="9" height="4" fill="#39FF14"/>
</g>"""

FAIXAS = {
    "dia":   dict(ceu="#3E6B8C", longe="#2C4E68", perto="#1B3346", chao="#14283A",
                  sol=False, neon=False,
                  desc="Faixa diurna: nevoa azulada, neons apagados."),
    "tarde": dict(ceu="#B03D6E", longe="#7A2A6B", perto="#4E1A57", chao="#3E1145",
                  sol=True, neon=False,
                  desc="Faixa de fim de tarde: sol listrado no estilo vaporwave."),
    "noite": dict(ceu="#170A31", longe="#241847", perto="#0E0524", chao="#0F0620",
                  sol=False, neon=True,
                  desc="Faixa noturna: neons acesos nos predios da frente."),
}

NEONS = [(30, 42, 16, 3, "#FF2D95"), (160, 36, 3, 12, "#00E5FF"), (300, 43, 13, 3, "#39FF14"),
         (430, 37, 3, 11, "#FFE14D"), (570, 42, 15, 3, "#FF2D95")]


def gerar(nome, c):
    sol = ""
    if c["sol"]:
        sol = (f'<circle cx="520" cy="34" r="32" fill="#FF9E6B"/>'
               f'<rect x="484" y="22" width="72" height="3" fill="{c["ceu"]}"/>'
               f'<rect x="484" y="31" width="72" height="4" fill="{c["ceu"]}"/>'
               f'<rect x="484" y="42" width="72" height="5" fill="{c["ceu"]}"/>')
    neon = ""
    for x, y, w, h, cor in NEONS:
        neon += f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{cor}"/>'
        neon += f'<rect x="{x+680}" y="{y}" width="{w}" height="{h}" fill="{cor}"/>'
    if not c["neon"]:
        neon = ""

    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="680" height="58" viewBox="0 0 680 58" role="img">
<title>DevLingo - faixa de cenario ({nome})</title>
<desc>{c['desc']} O Tr0nikAt caminha parado enquanto as camadas deslizam. ATENCAO: a animacao usa SMIL e nao e reproduzida pelo flutter_svg. No app, refaca o movimento com Rive, Lottie ou AnimationController.</desc>
<defs><path id="far" d="{FAR}"/><path id="near" d="{NEAR}"/>{CAT}</defs>
<rect x="0" y="0" width="680" height="58" fill="{c['ceu']}"/>{sol}
<g fill="{c['longe']}"><animateTransform attributeName="transform" type="translate" values="-680 0;0 0" dur="44s" repeatCount="indefinite"/><use href="#far" x="0" y="-14"/><use href="#far" x="680" y="-14"/></g>
<g><animateTransform attributeName="transform" type="translate" values="-680 0;0 0" dur="19s" repeatCount="indefinite"/><use href="#near" x="0" y="20" fill="{c['perto']}"/><use href="#near" x="680" y="20" fill="{c['perto']}"/>{neon}</g>
<rect x="0" y="52" width="680" height="6" fill="{c['chao']}"/>
<use href="#cat" transform="translate(150 52)"/>
</svg>
"""


if __name__ == "__main__":
    destino = Path(__file__).parent.parent / "assets" / "cenarios"
    destino.mkdir(parents=True, exist_ok=True)
    for nome, cores in FAIXAS.items():
        arquivo = destino / f"faixa-{nome}.svg"
        arquivo.write_text(gerar(nome, cores), encoding="utf-8")
        print(f"gerado: {arquivo.relative_to(destino.parent.parent)}")
