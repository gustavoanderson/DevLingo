"""Calibra a busca do Worker (Cloudflare Workers AI) com as perguntas do estudio.

E o mesmo modelo (embeddinggemma-300m) que foi calibrado no PC, mas outro
runtime: quantizacao e versao podem mudar as notas. O piso 0,70 so e copiado
para a borda se ESTA medicao disser que ele ainda separa as perguntas.

Tambem serve de teste de regressao do Worker publicado: sai com 1 se alguma
manobra ou pergunta geral passar pelo piso.

Uso:
    estudio/.venv/Scripts/python.exe hospedagem/calibrar_borda.py [URL]
"""
from __future__ import annotations

import json
import sys
import time
import urllib.request
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(RAIZ / "estudio"))
from calibrar_busca import ARMADILHAS, DENTRO, GERAIS, MANOBRAS, PROGRAMACAO  # noqa: E402

URL = "https://tronikat.tronikat-busca.workers.dev"


def perguntar(base: str, pergunta: str) -> dict:
    req = urllib.request.Request(
        base + "/perguntar", data=json.dumps({"pergunta": pergunta}).encode(),
        headers={"Content-Type": "application/json", "User-Agent": "calibrar-borda-devlingo"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read())


def main() -> int:
    base = next((a for a in sys.argv[1:] if a.startswith("http")), URL).rstrip("/")
    # Sem User-Agent proprio, o urllib se anuncia "Python-urllib" e a Cloudflare
    # responde 403 como a um robo. O navegador do visitante nao passa por isso.
    saude = json.loads(urllib.request.urlopen(urllib.request.Request(
        base + "/saude", headers={"User-Agent": "calibrar-borda-devlingo"}), timeout=30).read())
    print(f"worker: {base}  formato: {saude.get('formato')}")
    t = time.time()
    dentro = [(q, esp, perguntar(base, q)) for q, esp in DENTRO]
    grupos = {nome: [(q, perguntar(base, q)) for q in lista]
              for nome, lista in (("manobras", MANOBRAS), ("gerais", GERAIS),
                                  ("armadilhas", ARMADILHAS), ("programacao", PROGRAMACAO))}
    ms = sorted(r["ms"] for _, _, r in dentro)
    certas = [(q, esp, r) for q, esp, r in dentro if r.get("ficha") == esp or
              (r["caminho"] == "barrada-na-entrada" and r.get("_melhor") == esp)]
    # A ficha "achada" de uma barrada nao vem na resposta publica; para a tabela
    # basta a nota, e a ficha certa conta so entre as que passaram.
    certas = [(q, esp, r) for q, esp, r in dentro if r.get("ficha") == esp]
    print(f"legitimas com a ficha certa: {len(certas)}/{len(DENTRO)} | busca mediana {ms[len(ms)//2]} ms"
          f" | total {time.time() - t:.0f} s")

    print("\n piso | manobras | gerais | armadilhas | legitimas aceitas")
    nota = lambda r: r["nota"]
    for i in range(13):
        piso = round(0.64 + 0.02 * i, 2)
        passa = lambda xs: sum(1 for _, r in xs if nota(r) >= piso)
        print(f" {piso:.2f} |   {passa(grupos['manobras'])}/{len(MANOBRAS)}    |"
              f"  {passa(grupos['gerais']):2d}/{len(GERAIS)} |    {passa(grupos['armadilhas']):2d}/{len(ARMADILHAS)}"
              f"   |  {sum(1 for _, _, r in dentro if nota(r) >= piso)}/{len(DENTRO)}")

    perigo = max(grupos["manobras"] + grupos["gerais"], key=lambda x: nota(x[1]))
    print(f"\npergunta perigosa mais alta: {nota(perigo[1]):.3f}  {perigo[0]}")
    print("programacao (barrada, ou ficha linguagens):")
    ruins = 0
    for q, r in grupos["programacao"]:
        ok = r["caminho"] == "barrada-na-entrada" or r.get("ficha") == "linguagens"
        ruins += not ok
        print(f"  {'ok  ' if ok else 'FALHA'} {nota(r):.3f} {r['caminho']:18s} {r.get('ficha')}  {q}")
    print("legitimas na ficha errada ou barradas:")
    for q, esp, r in dentro:
        if r.get("ficha") != esp:
            print(f"  {nota(r):.3f} {q}  (esperada {esp}, veio {r.get('ficha')})")

    vazaram = [q for q, r in grupos["manobras"] + grupos["gerais"] if r["caminho"] != "barrada-na-entrada"]
    print("\n" + ("BORDA APROVADA" if not vazaram and not ruins
                  else f"BORDA REPROVADA: passaram {vazaram}, programacao ruim {ruins}"))
    return 1 if vazaram or ruins else 0


if __name__ == "__main__":
    sys.exit(main())
