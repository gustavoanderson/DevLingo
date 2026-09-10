#!/usr/bin/env python3
"""Le `app/coverage/lcov.info` e diz a cobertura -- com o denominador junto.

## Por que o denominador precisa aparecer

O `flutter test --coverage` so instrumenta arquivo que algum teste **importa**.
Um arquivo que nenhum teste toca nao entra no lcov, e portanto **nao entra na
conta**. Publicar so a porcentagem esconde isso: "95,6%" le como "95,6% do
app", quando e 95,6% da parte que os testes ja alcancam.

Num repositorio que e portfolio de qualidade, esse tipo de numero e pior que
numero nenhum -- quem avalia reconhece a diferenca entre uma metrica honesta e
uma que foi escolhida por ser bonita.

Entao o relatorio diz as duas coisas: a porcentagem, e quantos arquivos estao
dentro dela, com a lista dos que ficaram fora.

## Sem piso de cobertura, de proposito

Nao ha reprovacao por porcentagem baixa. Um piso escolhido hoje seria numero
inventado, e portao que reprova sem motivo ensina a contornar portao -- e a
mesma razao pela qual `check_nivel_coerente` avisa em vez de reprovar.

## Como usar

    python3 tools/resumo_da_cobertura.py app
"""

import os
import pathlib
import sys


def normalizar(caminho):
    """Deixa o caminho comparavel, venha ele do lcov ou do disco.

    O lcov gravado no Windows usa barra invertida, e o do runner usa barra
    normal. Comparar sem isso faria os 32 arquivos parecerem 32 ausentes.
    """
    texto = str(caminho).replace("\\", "/")
    return texto.split("lib/", 1)[-1] if "lib/" in texto else texto


def ler_lcov(caminho):
    cobertas = 0
    total = 0
    arquivos = set()

    with open(caminho, encoding="utf-8") as arquivo:
        for linha in arquivo:
            linha = linha.strip()
            if linha.startswith("SF:"):
                arquivos.add(normalizar(linha[3:]))
            elif linha.startswith("LH:"):
                cobertas += int(linha[3:])
            elif linha.startswith("LF:"):
                total += int(linha[3:])

    return cobertas, total, arquivos


def main():
    raiz = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "app")
    lcov = raiz / "coverage" / "lcov.info"

    if not lcov.exists():
        print(f"nao achei {lcov}. Rode `flutter test --coverage` antes.")
        return 1

    cobertas, total, instrumentados = ler_lcov(lcov)
    if total == 0:
        print("o lcov nao tem linha nenhuma. Algo deu errado na medicao.")
        return 1

    no_disco = {normalizar(p) for p in (raiz / "lib").rglob("*.dart")}
    ausentes = sorted(no_disco - instrumentados)
    pct = 100 * cobertas / total

    linhas = [
        "## Cobertura",
        "",
        "| | |",
        "|---|---|",
        f"| Linhas cobertas | {cobertas} de {total} |",
        f"| Cobertura | **{pct:.1f}%** |",
        f"| Arquivos medidos | {len(instrumentados)} de {len(no_disco)} |",
    ]

    if ausentes:
        linhas += [
            "",
            "### Fora da conta",
            "",
            "Arquivos que nenhum teste importa, e que por isso **nao entram na "
            "porcentagem acima**:",
            "",
        ]
        linhas += [f"- `{nome}`" for nome in ausentes]

    relatorio = "\n".join(linhas)
    print(relatorio)

    resumo = os.environ.get("GITHUB_STEP_SUMMARY")
    if resumo:
        with open(resumo, "a", encoding="utf-8") as arquivo:
            arquivo.write(relatorio + "\n")

    return 0


if __name__ == "__main__":
    sys.exit(main())
