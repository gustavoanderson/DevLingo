#!/usr/bin/env python3
"""
Prova que a normalizacao em Python cumpre o contrato de tools/normalize_cases.json.

O mesmo arquivo de casos e lido pelo app em Dart, em app/test/normalize_test.dart.
As duas implementacoes precisam produzir exatamente os mesmos resultados. Se uma
delas divergir, um dos dois lados reprova e o CI para.

Isso existe por causa de um defeito real: a versao antiga da normalizacao removia
todos os espacos, e 'consttotal=0' era aceito como resposta certa para
'const total = 0;'. Python nunca revelaria isso, JavaScript revelou. Agora a
mesma regra vive em duas linguagens, que e exatamente onde implementacoes
divergem em silencio.

Uso:
    python3 tools/test_normalize.py

Saida:
    codigo 0  -> as duas listas de casos passaram
    codigo 1  -> algum caso falhou, com o esperado e o obtido lado a lado
"""

import json
import sys
from pathlib import Path

from validate_questions import accepts, normalize

CASES_FILE = Path(__file__).parent / "normalize_cases.json"


def rodar():
    dados = json.loads(CASES_FILE.read_text(encoding="utf-8"))
    falhas = []

    casos_norm = dados["normalizacao"]
    for caso in casos_norm:
        obtido = normalize(caso["entrada"], caso["regras"])
        if obtido != caso["saida"]:
            falhas.append(
                f"  [normalizacao] {caso['nome']}\n"
                f"      entrada:  {caso['entrada']!r}\n"
                f"      esperado: {caso['saida']!r}\n"
                f"      obtido:   {obtido!r}"
            )

    casos_aceite = dados["aceitacao"]
    for caso in casos_aceite:
        obtido = accepts(caso["resposta"], caso["aceitas"], caso["regras"])
        if obtido != caso["aceita"]:
            falhas.append(
                f"  [aceitacao] {caso['nome']}\n"
                f"      resposta: {caso['resposta']!r}\n"
                f"      aceitas:  {caso['aceitas']!r}\n"
                f"      esperado: {'aceita' if caso['aceita'] else 'recusa'}\n"
                f"      obtido:   {'aceita' if obtido else 'recusa'}"
            )

    total = len(casos_norm) + len(casos_aceite)
    print(f"\nCasos de normalizacao: {len(casos_norm)}")
    print(f"Casos de aceitacao:    {len(casos_aceite)}")

    if falhas:
        print(f"\n{len(falhas)} de {total} caso(s) falharam:\n")
        print("\n\n".join(falhas))
        print("\nCONTRATO DE NORMALIZACAO QUEBRADO (Python)\n")
        return 1

    print(f"\nCONTRATO DE NORMALIZACAO CUMPRIDO (Python): {total} casos\n")
    return 0


if __name__ == "__main__":
    sys.exit(rodar())
