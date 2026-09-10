#!/usr/bin/env python3
"""Le a saida do `flutter test --reporter json` e produz um resumo legivel.

## Por que isto existe

O CI precisa saber **quantos testes rodaram**, para conferir que o numero
anunciado no README nao envelheceu. E contar isso lendo a saida normal do
`flutter test` e fragil: o formato muda conforme o ambiente. Medido nesta
maquina e no runner do GitHub, o mesmo comando imprime coisas diferentes:

    local:  00:27 +343: All tests passed!
    CI:     [emoji] 343 tests passed.

Uma expressao regular escrita contra um dos dois quebra no outro -- e um
portao que quebra sozinho ensina a ignorar portao. O reporter `json` nao muda
de forma, porque existe para ser lido por maquina.

O preco de usar o reporter `json` seria perder o log legivel do CI. Este
script paga esse preco de volta: ele imprime o resumo, e imprime as falhas com
o erro junto, que e mais util que a lista corrida de testes que passaram.

## Como usar

    flutter test --reporter json | tee saida.jsonl
    python3 tools/resumo_dos_testes.py saida.jsonl

Sai 0 se todos passaram, 1 se algum falhou ou se nenhum teste rodou -- suite
vazia que "passa" e o pior falso verde possivel.
"""

import json
import os
import sys


def eventos(caminho):
    """Cada linha e um evento JSON. Linhas que nao sao, ficam de fora.

    O reporter as vezes intercala saida do proprio app (um `debugPrint`, um
    aviso do Flutter). Engolir essas linhas em silencio e correto aqui: elas
    nao sao eventos, e reclamar delas transformaria log em erro.
    """
    with open(caminho, encoding="utf-8") as arquivo:
        for linha in arquivo:
            linha = linha.strip()
            if not linha.startswith("{"):
                continue
            try:
                yield json.loads(linha)
            except ValueError:
                continue


def resumir(caminho):
    nomes = {}
    concluidos = []
    erros = {}

    for evento in eventos(caminho):
        tipo = evento.get("type")

        if tipo == "testStart":
            teste = evento.get("test", {})
            nomes[teste.get("id")] = teste.get("name", "(sem nome)")

        elif tipo == "error":
            alvo = evento.get("testID")
            # So o primeiro erro de cada teste. Um teste que quebra costuma
            # emitir varios, e repetir todos afoga o que interessa.
            erros.setdefault(alvo, evento.get("error", "").strip())

        elif tipo == "testDone":
            # `hidden` marca os testes que o proprio arcabouco cria: carregar
            # o arquivo, `setUpAll`, `tearDownAll`. Eles nao sao testes de
            # ninguem, e conta-los inflaria o numero que o README anuncia.
            if evento.get("hidden"):
                continue
            concluidos.append(evento)

    total = len(concluidos)
    falhas = [e for e in concluidos if e.get("result") != "success"]

    for falha in falhas:
        alvo = falha.get("testID")
        print(f"[FALHOU] {nomes.get(alvo, alvo)}")
        detalhe = erros.get(alvo)
        if detalhe:
            for linha in detalhe.splitlines():
                print(f"         {linha}")

    print()
    print(f"Testes concluidos: {total}")
    print(f"Falharam:          {len(falhas)}")

    # O passo seguinte do CI compara este numero com o badge do README.
    saida = os.environ.get("GITHUB_OUTPUT")
    if saida:
        with open(saida, "a", encoding="utf-8") as arquivo:
            arquivo.write(f"total={total}\n")

    if total == 0:
        print("\nNenhum teste rodou. Suite vazia que passa e falso verde.")
        return 1
    return 1 if falhas else 0


def main():
    if len(sys.argv) != 2:
        print(__doc__)
        print("uso: resumo_dos_testes.py <arquivo-com-a-saida-json>")
        return 2
    return resumir(sys.argv[1])


if __name__ == "__main__":
    sys.exit(main())
