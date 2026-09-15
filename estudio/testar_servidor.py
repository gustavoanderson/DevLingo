"""Testes do servidor do estudio.

PARTE A -- o PROTOCOLO, com um estudio falso. Em milissegundos e sem modelo:
se origem, limite de tamanho e erros estiverem errados, isso aparece aqui sem
esperar 20 s de carga de modelo -- e sem confundir defeito do servidor com
defeito do porteiro.

PARTE B -- uma volta REAL: pergunta -> porteiro -> voz -> JSON, com o audio
decodificado e a boca conferida contra ele.

Uso:
    estudio/.venv/Scripts/python.exe estudio/testar_servidor.py          # A e B
    estudio/.venv/Scripts/python.exe estudio/testar_servidor.py --rapido # so A
"""
from __future__ import annotations

import base64
import io
import json
import sys
import threading
import time
import urllib.error
import urllib.request
import wave
from http.server import ThreadingHTTPServer

import servidor

falhas: list[str] = []


def conferir(ok: bool, nome: str, detalhe: str = "") -> None:
    print(f"  {'ok  ' if ok else 'FALHA'} {nome}" + (f"  ({detalhe})" if detalhe else ""))
    if not ok:
        falhas.append(nome)


def subir(estudio) -> tuple[ThreadingHTTPServer, str]:
    # Porta 0: o sistema escolhe uma livre. O teste nao briga com um estudio
    # de verdade que esteja rodando na 8765.
    srv = ThreadingHTTPServer((servidor.HOST, 0), servidor.criar_manipulador(estudio))
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    return srv, f"http://{servidor.HOST}:{srv.server_address[1]}"


def pedir(url: str, metodo: str = "GET", corpo: bytes | None = None,
          cabecalhos: dict | None = None) -> tuple[int, dict, dict]:
    req = urllib.request.Request(url, data=corpo, method=metodo, headers=cabecalhos or {})
    try:
        with urllib.request.urlopen(req, timeout=300) as r:
            bruto = r.read()
            return r.status, dict(r.headers), (json.loads(bruto) if bruto else {})
    except urllib.error.HTTPError as e:
        bruto = e.read()
        return e.code, dict(e.headers), (json.loads(bruto) if bruto else {})


class EstudioFalso:
    pronto_em = 0.0
    perguntas: list[str] = []

    def responder(self, pergunta: str) -> dict:
        self.perguntas.append(pergunta)
        return {"texto": "ok", "caminho": "gerada", "ficha": "preco", "duracao": 0.1,
                "bocas": [], "audio": "", "tempos_ms": {}}


def parte_a() -> None:
    print("=== PARTE A: o protocolo, com estudio falso ===")
    falso = EstudioFalso()
    srv, base = subir(falso)
    try:
        conferir(srv.server_address[0] == "127.0.0.1", "escuta so em 127.0.0.1",
                 srv.server_address[0])

        cod, cab, corpo = pedir(base + "/saude")
        conferir(cod == 200 and corpo.get("ok") is True, "/saude responde")

        j = {"Content-Type": "application/json"}
        cod, cab, corpo = pedir(base + "/perguntar", "POST", json.dumps({"pergunta": "  oi  "}).encode(),
                                {**j, "Origin": "https://gustavoanderson.github.io"})
        conferir(cod == 200 and corpo.get("texto") == "ok", "pergunta valida chega ao estudio")
        conferir(falso.perguntas[-1] == "oi", "a pergunta chega aparada", repr(falso.perguntas[-1]))
        conferir(cab.get("Access-Control-Allow-Origin") == "https://gustavoanderson.github.io",
                 "origem permitida recebe o cabecalho de permissao")

        cod, cab, _ = pedir(base + "/perguntar", "POST", json.dumps({"pergunta": "oi"}).encode(),
                            {**j, "Origin": "https://site-qualquer.example"})
        conferir("Access-Control-Allow-Origin" not in cab,
                 "origem desconhecida NAO recebe permissao")

        cod, cab, _ = pedir(base + "/perguntar", "OPTIONS",
                            cabecalhos={"Origin": "null",
                                        "Access-Control-Request-Private-Network": "true"})
        conferir(cod == 204 and cab.get("Access-Control-Allow-Private-Network") == "true",
                 "pre-verificacao responde a Private Network Access")

        antes = len(falso.perguntas)
        cod, _, _ = pedir(base + "/perguntar", "POST", json.dumps({"pergunta": "a" * 301}).encode(), j)
        conferir(cod == 413, "pergunta de 301 caracteres e recusada", str(cod))
        cod, _, _ = pedir(base + "/perguntar", "POST", json.dumps({"pergunta": "ã" * 300}).encode(), j)
        conferir(cod == 200, "300 caracteres acentuados passam (o limite e em caracteres, nao bytes)",
                 str(cod))
        cod, _, _ = pedir(base + "/perguntar", "POST", b"x" * 5000, j)
        conferir(cod == 413, "corpo enorme e recusado sem ser lido", str(cod))
        cod, _, _ = pedir(base + "/perguntar", "POST", b"nao e json", j)
        conferir(cod == 400, "corpo que nao e JSON da 400", str(cod))
        cod, _, _ = pedir(base + "/perguntar", "POST", json.dumps({"pergunta": "   "}).encode(), j)
        conferir(cod == 400, "pergunta em branco da 400", str(cod))
        cod, _, _ = pedir(base + "/perguntar", "POST", json.dumps({"pergunta": 42}).encode(), j)
        conferir(cod == 400, "pergunta que nao e texto da 400", str(cod))
        conferir(len(falso.perguntas) == antes + 1,
                 "nenhuma requisicao recusada chegou ao estudio",
                 f"{len(falso.perguntas) - antes} chegou(aram)")

        cod, _, _ = pedir(base + "/nada")
        conferir(cod == 404, "caminho desconhecido da 404")
    finally:
        srv.shutdown()


def parte_b() -> None:
    print("\n=== PARTE B: uma volta real ===")
    t = time.time()
    estudio = servidor.Estudio()
    print(f"  estudio carregado em {time.time() - t:.1f} s")
    srv, base = subir(estudio)
    j = {"Content-Type": "application/json"}
    try:
        t = time.time()
        cod, _, r = pedir(base + "/perguntar", "POST",
                          json.dumps({"pergunta": "o app é de graça?"}).encode(), j)
        total = time.time() - t
        conferir(cod == 200 and r.get("ficha") == "preco", "pergunta legitima acha a ficha certa",
                 f"{r.get('ficha')} via {r.get('caminho')}")
        with wave.open(io.BytesIO(base64.b64decode(r["audio"]))) as w:
            dur = w.getnframes() / w.getframerate()
        conferir(abs(dur - r["duracao"]) < 0.01, "o audio devolvido tem a duracao declarada",
                 f"{dur:.2f} s")
        conferir(r["bocas"] and abs(r["bocas"][-1][1] - dur) <= 0.02 * dur,
                 "a boca termina junto com o audio")
        print(f"  tempo da pergunta a resposta com voz: {total:.2f} s  {r['tempos_ms']}")

        cod, _, r = pedir(base + "/perguntar", "POST",
                          json.dumps({"pergunta": "Quanto é 347 vezes 29?"}).encode(), j)
        conferir(r.get("caminho") == "barrada-na-entrada" and "10063" not in r.get("texto", ""),
                 "a manobra e barrada e mesmo assim ganha voz", r.get("caminho"))
        conferir(r.get("duracao", 0) > 0, "a frase fixa tambem e falada")
    finally:
        srv.shutdown()


def main() -> int:
    parte_a()
    if "--rapido" not in sys.argv:
        parte_b()
    print(f"\n{'SERVIDOR APROVADO' if not falhas else f'SERVIDOR REPROVADO: {len(falhas)} falha(s)'}")
    return 1 if falhas else 0


if __name__ == "__main__":
    sys.exit(main())
