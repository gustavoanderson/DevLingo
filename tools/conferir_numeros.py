#!/usr/bin/env python3
"""Confere que os numeros anunciados no site e nas fichas batem com o banco.

POR QUE EXISTE
O CI ja reprova quando os badges do README mentem. Mas o site publico e as
fichas do Tr∅nikAt tambem anunciam contagens, e la ninguem conferia.

Nas fichas o risco e MAIOR que no README, e a razao e o desenho do estudio:
ficha vira AUDIO GRAVADO. Um numero velho nao fica so escrito -- ele e FALADO
para quem abre o site. E corrigir nao e editar uma linha: exige regravar a voz
com hospedagem/gerar_falas.py.

O QUE ESTE CONFERIDOR NAO OLHA: A COBERTURA
Ela muda a cada commit. Com 2.501 linhas medidas, UMA unica linha sem teste ja
move a casa decimal -- um portao nessa precisao reprovaria o tempo todo, e
portao que reprova sem motivo ensina a contorna-lo. O CLAUDE.md registra essa
decisao para o README, e ela vale aqui igual.

Por isso, no site e nas fichas, a cobertura e uma afirmacao DATADA ("95,6% em
16/09/2026"), que continua verdadeira para sempre e nao precisa de portao.

POR QUE CADA NUMERO E ANCORADO NUMA FRASE
Procurar o numero solto no arquivo nao funciona: `bottom:-400px` e
`CICLO = 3400` existem no CSS e no JavaScript do site, e um conferidor ingenuo
os leria como contagens. Cada afirmacao abaixo traz a frase que a cerca.

POR QUE TODA AFIRMACAO PRECISA CASAR PELO MENOS UMA VEZ
Se alguem reescrever a frase, a expressao para de casar -- e um portao que nao
encontra o que conferir passa calado, que e o pior falso verde possivel (a
mesma razao pela qual tools/resumo_dos_testes.py reprova suite vazia). Por
isso, afirmacao que nao casa nenhuma vez REPROVA, e diz qual.

Uso:
    python3 tools/conferir_numeros.py [--testes N]

Sem --testes, as afirmacoes sobre a suite sao puladas (e avisadas). O CI sempre
passa o numero, que so e conhecido depois de a suite rodar.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
CONTEUDO = RAIZ / "app" / "assets" / "content"

# A licao de referencia nao e jogavel: ela ensina o FORMATO, e o CLAUDE.md
# registra que ela nao conta para meta nenhuma. Dai o site dizer 404 (tudo) e
# a ficha dizer 400 (o que da para jogar) -- os DOIS estao certos, e um
# conferidor que nao soubesse a diferenca acusaria a ficha de mentir.
SUFIXO_REFERENCIA = "-00.json"


def contar_banco() -> dict[str, int]:
    """Conta o que o banco realmente tem. Esta e a unica fonte de verdade."""
    total = jogaveis = licoes = 0
    trilhas = set()
    por_trilha: dict[str, int] = {}
    for arquivo in sorted(CONTEUDO.glob("*/*.json")):
        dados = json.loads(arquivo.read_text(encoding="utf-8"))
        quantas = len(dados.get("questions", []))
        total += quantas
        trilhas.add(arquivo.parent.name)
        if not arquivo.name.endswith(SUFIXO_REFERENCIA):
            jogaveis += quantas
            licoes += 1
            chave = f"trilha:{arquivo.parent.name}"
            por_trilha[chave] = por_trilha.get(chave, 0) + quantas
    return {
        "total": total,
        "jogaveis": jogaveis,
        "licoes": licoes,
        "trilhas": len(trilhas),
        **por_trilha,
    }


# Uma afirmacao POR TRILHA DO BANCO, gerada, e nao escrita a mao. Desde 25/09/2026
# cada cartao de curso do site anuncia quantas questoes aquele curso tem. Gerar a
# lista a partir das pastas faz duas coisas: confere o numero de cada cartao, e
# REPROVA quando entra uma trilha nova sem cartao -- a expressao dela nao casa.
TRILHAS_NO_BANCO = sorted(d.name for d in CONTEUDO.iterdir() if d.is_dir())


# (expressao, fatos na ordem dos grupos capturados)
AFIRMACOES: dict[str, list[tuple[str, list[str]]]] = {
    "site/index.html": [
        # O topo e o placar deixaram de anunciar numeros em 25/09/2026: eles
        # foram para dentro da secao de trilhas, onde tem contexto.
        (r"(\d+) questões para jogar, em (\d+) trilhas",    ["jogaveis", "trilhas"]),
        *[(rf'data-trilha="{t}">(\d+) questões', [f"trilha:{t}"]) for t in TRILHAS_NO_BANCO],
        (r"São (\d+) testes automatizados",                ["testes"]),
        (r"- (\d+) questoes em (\d+) trilhas",             ["total", "trilhas"]),
        (r"- (\d+) testes automatizados",                  ["testes"]),
        (r"São (\d+) questões em (\d+) trilhas",           ["total", "trilhas"]),
    ],
    # O README TAMBEM ENTRA, e ele e a razao desta entrada existir.
    #
    # O ci.yml ja confere estes tres badges, em dois passos proprios -- e por
    # isso eu os deixei de fora aqui, achando que estavam guardados. Estavam,
    # mas SO NO CI: rodar `conferir_numeros.py` localmente passava verde com o
    # badge de testes dizendo 390 contra 401 reais, e a `main` levou SEIS
    # commits com o CI vermelho antes de o Gustavo perguntar por que.
    #
    # Portao que so existe onde nao se olha antes de commitar nao previne nada;
    # ele apenas documenta o erro depois. A redundancia com o ci.yml e barata e
    # deliberada: o que importa e um comando SO cobrir tudo antes do push.
    "README.md": [
        (r"badge/testes-(\d+)",   ["testes"]),
        (r"badge/questões-(\d+)", ["total"]),
        (r"badge/trilhas-(\d+)",  ["trilhas"]),
    ],
    "estudio/fichas.md": [
        (r'diz "(\d+) questões"',                          ["jogaveis"]),
        (r"São (\d+) trilhas:",                            ["trilhas"]),
        # A frase foi reescrita em 17/09/2026 porque a antiga ("cinco licoes de
        # dez questoes") era INVERTIVEL: o modelo gerou "cada licao tem cinco
        # questoes", que e falso, e o juiz aprovou porque todos os numeros
        # estavam na ficha. Hoje cada numero vem colado no proprio substantivo.
        (r"São (\d+) questões para jogar, em (\d+) lições\. São (\d+) trilhas",
         ["jogaveis", "licoes", "trilhas"]),
        (r"São (\d+) testes automatizados no app",         ["testes"]),
    ],
}

ROTULOS = {
    "total": "questoes no banco",
    "jogaveis": "questoes jogaveis",
    "licoes": "licoes jogaveis",
    "trilhas": "trilhas",
    "testes": "testes na suite",
}


def rotulo(chave: str) -> str:
    if chave.startswith("trilha:"):
        return f"questoes de {chave[7:]}"
    return ROTULOS[chave]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--testes", type=int, default=None,
                    help="total de testes da suite; sem ele, essas afirmacoes sao puladas")
    args = ap.parse_args()

    fatos = contar_banco()
    if args.testes is not None:
        fatos["testes"] = args.testes

    print("medido agora:")
    for chave, valor in fatos.items():
        print(f"  {rotulo(chave):20s} {valor}")
    if "testes" not in fatos:
        print("  testes na suite     -- nao informado, afirmacoes sobre a suite PULADAS")
    print()

    erros: list[str] = []
    pulados = 0

    for relativo, afirmacoes in AFIRMACOES.items():
        caminho = RAIZ / relativo
        if not caminho.exists():
            erros.append(f"{relativo}: arquivo nao encontrado")
            continue
        texto = caminho.read_text(encoding="utf-8")

        for expressao, chaves in afirmacoes:
            if any(c not in fatos for c in chaves):
                pulados += 1
                continue

            achados = list(re.finditer(expressao, texto))
            if not achados:
                # Frase reescrita: o portao deixou de guardar sem avisar.
                erros.append(
                    f"{relativo}: nada casou com /{expressao}/. "
                    "Se a frase mudou, atualize a expressao em tools/conferir_numeros.py; "
                    "sem isso este numero deixa de ser conferido.")
                continue

            for achado in achados:
                linha = texto.count("\n", 0, achado.start()) + 1
                for grupo, chave in enumerate(chaves, start=1):
                    anunciado = int(achado.group(grupo))
                    real = fatos[chave]
                    marca = "ok  " if anunciado == real else "ERRO"
                    print(f"  {marca} {relativo}:{linha}  {rotulo(chave)}: "
                          f"anuncia {anunciado}, real {real}")
                    if anunciado != real:
                        erros.append(
                            f"{relativo}:{linha} anuncia {anunciado} "
                            f"{rotulo(chave)}, e o real e {real}.")

    print()
    if pulados:
        print(f"{pulados} afirmacao(oes) pulada(s) por falta de --testes.\n")

    if erros:
        for erro in erros:
            print(f"::error::{erro}")
        print(f"\nNUMEROS DIVERGENTES: {len(erros)}")
        return 1

    print("NUMEROS CONFEREM")
    return 0


if __name__ == "__main__":
    sys.exit(main())
