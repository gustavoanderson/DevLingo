"""Constroi o DevLingo do navegador: as duas pecas que NAO vivem no git.

    python tools/construir_jogo.py

  jogo/cerebro.js      o cerebro do jogo, compilado de app/lib/ponte_web.dart
  jogo/conteudo.json   o indice das licoes

POR QUE AS DUAS SAO GERADAS, e por que nenhuma e versionada

O `cerebro.js` porque `dart compile js` nao garante saida byte a byte entre
versoes do SDK. Versiona-lo criaria a regra "gerado tem de bater com o
gerador", e o portao reprovaria por troca de versao do Flutter sem ninguem ter
mexido em codigo.

O `conteudo.json` porque um site estatico NAO CONSEGUE LISTAR PASTAS. O app
descobre as licoes pelo pubspec.yaml; o navegador so conhece o que alguem
disser a ele. Escrito a mao, este indice envelheceria na primeira licao nova --
exatamente a falha silenciosa que o CLAUDE.md registra para os assets do
pubspec, e que ali virou regra do validador.

O INDICE E CRU, de proposito: uma linha por arquivo, com o que esta escrito no
arquivo e nada mais. A ordem das trilhas, os nomes de tela, esconder a licao 00
e o rotulo do nivel sao REGRAS, e regra mora no cerebro -- ver `_trilhas` em
ponte_web.dart. Se este script decidisse a ordem, Java-antes-de-Selenium
passaria a existir em dois lugares.
"""
from __future__ import annotations

import json
import shutil
import subprocess
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
CONTEUDO = RAIZ / "app" / "assets" / "content"
JOGO = RAIZ / "jogo"


def indice() -> list[dict]:
    linhas = []
    for arq in sorted(CONTEUDO.glob("*/*.json")):
        d = json.loads(arq.read_text(encoding="utf-8"))
        linhas.append({
            # Caminho relativo a raiz do servidor. O jogo mora em /jogo/, entao
            # sobe um nivel para alcancar o banco -- o mesmo banco que o app usa,
            # sem copia.
            "arquivo": "../" + arq.relative_to(RAIZ).as_posix(),
            "language": d["language"],
            "level": d["level"],
            "lessonId": d["lessonId"],
            "lessonTitle": d["lessonTitle"],
            "questoes": len(d["questions"]),
        })
    return linhas


def compilar() -> None:
    dart = shutil.which("dart")
    if not dart:
        raise SystemExit("dart nao encontrado no PATH -- ele vem com o Flutter")
    r = subprocess.run(
        [dart, "compile", "js", "lib/ponte_web.dart",
         "-o", str(JOGO / "cerebro.js"), "-O2"],
        cwd=RAIZ / "app", capture_output=True, text=True)
    if r.returncode != 0:
        print(r.stdout[-2000:], r.stderr[-2000:])
        raise SystemExit("o cerebro NAO compilou")


def main() -> int:
    JOGO.mkdir(exist_ok=True)
    linhas = indice()
    (JOGO / "conteudo.json").write_text(
        json.dumps(linhas, ensure_ascii=False, indent=1), encoding="utf-8")
    trilhas = sorted({l["language"] for l in linhas})
    print(f"conteudo.json  {len(linhas)} licoes em {len(trilhas)} trilhas")

    compilar()
    kb = (JOGO / "cerebro.js").stat().st_size / 1024
    print(f"cerebro.js     {kb:.0f} KB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
