"""Portao do servico de voz -- e ele existe por UMA invariante silenciosa.

    estudio/.venv/Scripts/python.exe hospedagem/testar_voz_servico.py

O /aquecer tem de sintetizar PASSANDO AO LARGO DO CACHE. Se um dia alguem
"simplificar" fazendo-o chamar o `falar()` de sempre, o aquecimento passa a
responder do cache -- rapido, com ok: true, sem erro nenhum -- e DEIXA DE
AQUECER. O site continua adiantando o custo que ja nao adianta nada, e o
primeiro visitante volta a pagar os ~5 s que este mecanismo existe para tirar.

Nada quebra, nada avisa. E a mesma familia do silencio dentro do WAV e das
frases que abriam iguais: defeito que so aparece no ouvido de quem usa.

Nao roda no CI: precisa do modelo do Piper, que nao existe no runner -- mesma
razao de `estudio/testar_voz.py` e de `mcp/agente.py`.
"""
from __future__ import annotations

import json
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
BASE = "http://127.0.0.1:8770"


def bate(caminho: str, corpo: dict | None = None) -> tuple[int, dict]:
    dados = json.dumps(corpo).encode() if corpo is not None else None
    req = urllib.request.Request(
        BASE + caminho, data=dados, method="POST" if dados is not None else "GET",
        headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            return r.status, json.load(r)
    except urllib.error.HTTPError as e:
        try:
            return e.code, json.loads(e.read() or b"{}")
        except Exception:
            return e.code, {}


def main() -> int:
    falhas: list[str] = []

    def conferir(ok: bool, nome: str, detalhe: str = "") -> None:
        print(f"  {'ok  ' if ok else 'FALHA'} {nome}" + (f"  ({detalhe})" if detalhe else ""))
        if not ok:
            falhas.append(nome)

    print("subindo o servico...")
    proc = subprocess.Popen([sys.executable, str(RAIZ / "hospedagem" / "voz_servico.py")],
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        for _ in range(90):                     # a carga do modelo leva ~8 s aqui
            try:
                if bate("/saude")[1].get("ok"):
                    break
            except Exception:
                time.sleep(1)
        else:
            print("o servico nao subiu")
            return 1

        antes = bate("/saude")[1]
        print(f"servico no ar (carga {antes['carga_s']:.1f} s)\n")

        codigo, corpo = bate("/aquecer", {})
        conferir(codigo == 200 and corpo.get("ok") is True, "o /aquecer responde", str(corpo))

        for _ in range(2):
            bate("/aquecer", {})
        s = bate("/saude")[1]

        # O CORACAO DO TESTE. Tres aquecimentos nao podem ter deixado rastro no
        # cache nem no contador de falas pedidas pelo site.
        conferir(s["em_cache"] == antes["em_cache"],
                 "aquecer NAO escreve no cache", f"em_cache {s['em_cache']}")
        conferir(s["sintetizadas"] == antes["sintetizadas"],
                 "aquecer nao conta como fala", f"sintetizadas {s['sintetizadas']}")
        conferir(s["aquecimentos"] == antes["aquecimentos"] + 3,
                 "os aquecimentos sao contados a parte", f"{s['aquecimentos']}")

        # E o contrario: falar CONTINUA usando o cache. Sem esta metade, um
        # /aquecer que quebrasse o cache do /falar passaria despercebido.
        bate("/falar", {"texto": "Uma fala de verdade, para o cache."})
        meio = bate("/saude")[1]
        bate("/falar", {"texto": "Uma fala de verdade, para o cache."})
        fim = bate("/saude")[1]
        conferir(meio["em_cache"] == antes["em_cache"] + 1 and fim["do_cache"] == meio["do_cache"] + 1,
                 "falar continua guardando e reusando", f"do_cache {fim['do_cache']}")

        conferir(bate("/naoexiste", {})[0] == 404, "caminho desconhecido da 404")

        print(f"\n{'SERVICO APROVADO' if not falhas else f'SERVICO REPROVADO: {len(falhas)} falha(s)'}")
        return 1 if falhas else 0
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=10)
        except subprocess.TimeoutExpired:
            proc.kill()


if __name__ == "__main__":
    sys.exit(main())
