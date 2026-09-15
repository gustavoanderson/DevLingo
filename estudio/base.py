"""Le e confere as fichas do Tr∅nikAt (estudio/fichas.md).

As fichas sao a UNICA fonte do que o Tr∅nikAt diz. Um erro de estrutura aqui
nao quebra nada de forma visivel: a ficha simplesmente some da busca, e o
personagem passa a responder "nao sei" para uma pergunta que tinha resposta.
Por isso elas tem validador, como as questoes do app.

Uso:
    python estudio/base.py        # confere; sai com 1 se houver defeito
"""
from __future__ import annotations

import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

ARQUIVO = Path(__file__).with_name("fichas.md")

# Teto de palavras da resposta. O modelo roda com a placa no limite (3,2 GB de
# 4 GB), e cada palavra da ficha disputa a janela de contexto com a pergunta.
TETO_DE_PALAVRAS = 80
MINIMO_DE_PERGUNTAS = 3


@dataclass
class Ficha:
    id: str
    fonte: str = ""
    revisar: str = ""
    perguntas: list[str] = field(default_factory=list)
    resposta: str = ""


def ler_fichas(caminho: Path = ARQUIVO) -> list[Ficha]:
    texto = caminho.read_text(encoding="utf-8")
    # O cabecalho do arquivo (explicacao para quem escreve) termina no '---'.
    corpo = texto.split("\n---\n", 1)[-1]
    fichas: list[Ficha] = []
    for bloco in re.split(r"^## ", corpo, flags=re.M)[1:]:
        linhas = bloco.splitlines()
        ficha = Ficha(id=linhas[0].strip())
        secao = None
        resposta: list[str] = []
        for linha in linhas[1:]:
            if linha.startswith("fonte:"):
                ficha.fonte = linha.split(":", 1)[1].strip()
            elif linha.startswith("revisar:"):
                ficha.revisar = linha.split(":", 1)[1].strip()
            elif linha.strip() == "perguntas:":
                secao = "perguntas"
            elif linha.strip() == "resposta:":
                secao = "resposta"
            elif secao == "perguntas" and linha.startswith("- "):
                ficha.perguntas.append(linha[2:].strip())
            elif secao == "resposta" and linha.strip():
                resposta.append(linha.strip())
        ficha.resposta = " ".join(resposta)
        fichas.append(ficha)
    return fichas


def conferir(fichas: list[Ficha]) -> list[str]:
    defeitos: list[str] = []
    vistos: dict[str, str] = {}
    ids = [f.id for f in fichas]
    for duplicado in {i for i in ids if ids.count(i) > 1}:
        defeitos.append(f"id repetido: {duplicado}")
    for f in fichas:
        if not re.fullmatch(r"[a-z0-9]+(-[a-z0-9]+)*", f.id):
            defeitos.append(f"{f.id}: id fora do padrao (minusculas-com-hifen)")
        if not f.fonte:
            defeitos.append(f"{f.id}: sem fonte -- de onde saiu o que ela afirma?")
        if len(f.perguntas) < MINIMO_DE_PERGUNTAS:
            defeitos.append(f"{f.id}: {len(f.perguntas)} perguntas, minimo {MINIMO_DE_PERGUNTAS}")
        if not f.resposta:
            defeitos.append(f"{f.id}: sem resposta")
        palavras = len(f.resposta.split())
        if palavras > TETO_DE_PALAVRAS:
            defeitos.append(f"{f.id}: resposta com {palavras} palavras, teto {TETO_DE_PALAVRAS}")
        # A mesma pergunta-exemplo em duas fichas deixa a busca sem criterio:
        # a pergunta casaria igualmente com as duas.
        for p in f.perguntas:
            chave = p.lower().strip(" ?!.")
            if chave in vistos and vistos[chave] != f.id:
                defeitos.append(f"pergunta '{p}' em {vistos[chave]} e {f.id}")
            vistos[chave] = f.id
    return defeitos


def main() -> int:
    fichas = ler_fichas()
    defeitos = conferir(fichas)
    print(f"{len(fichas)} fichas, {sum(len(f.perguntas) for f in fichas)} perguntas-exemplo")
    pendentes = [f.id for f in fichas if f.revisar]
    if pendentes:
        print(f"aguardando revisao do Gustavo: {', '.join(pendentes)}")
    for d in defeitos:
        print(f"[ERRO] {d}")
    print("FICHAS APROVADAS" if not defeitos else "FICHAS REPROVADAS")
    return 1 if defeitos else 0


if __name__ == "__main__":
    sys.exit(main())
