"""O servidor do estudio: a ponte entre o site e o Tr∅nikAt local.

Recebe a pergunta do site, passa pelo porteiro (entrada, modelo, juiz) e pela
voz, e devolve texto, audio e a linha do tempo da boca num JSON so.

Tres decisoes de seguranca, mesmo sendo um servidor local
----------------------------------------------------------
- ESCUTA SO EM 127.0.0.1, nunca em 0.0.0.0. Nem outro aparelho do Wi-Fi alcanca
  o estudio. Quando houver tunel, ele sera a unica porta, aberta de proposito
- PERGUNTA LIMITADA a 300 caracteres. Texto gigante e o primeiro recurso de
  quem tenta injecao, e ocupa a placa a toa
- UMA PERGUNTA POR VEZ. Ha uma placa de video so; duas perguntas simultaneas
  disputariam a memoria e as duas ficariam lentas. A trava serializa

E uma de compatibilidade: navegador moderno so deixa uma pagina da internet
falar com um servidor da sua propria maquina se o servidor disser que aceita
(Private Network Access). Sem o cabecalho no OPTIONS, o site do GitHub Pages
nao alcanca o estudio, e o erro no console nao diz isso com clareza.

Uso:
    estudio/.venv/Scripts/python.exe estudio/servidor.py        # porta 8765
"""
from __future__ import annotations

import base64
import json
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HOST = "127.0.0.1"
PORTA = 8765
LIMITE_DA_PERGUNTA = 300

# Quem pode chamar o estudio pelo navegador. "null" e a pagina aberta como
# arquivo local (file://). Qualquer outra origem recebe resposta sem o
# cabecalho de permissao, e o navegador a bloqueia.
ORIGENS = {
    "null",
    "http://127.0.0.1:8000", "http://localhost:8000",
    "https://gustavoanderson.github.io",
}


class Estudio:
    """Porteiro e voz carregados uma vez, e uma trava para a placa."""

    def __init__(self) -> None:
        from porteiro import Porteiro      # import tardio: o teste pode trocar
        from voz import Voz
        t = time.time()
        self.porteiro = Porteiro()
        self.voz = Voz()
        self.trava = threading.Lock()
        # Aquece o modelo, o juiz e a voz: a primeira pergunta de verdade nao
        # pode pagar a carga fria (medida: ~65 s so para ler o modelo do HD).
        self.responder("o que é o devlingo?")
        self.pronto_em = round(time.time() - t, 1)

    def responder(self, pergunta: str) -> dict:
        with self.trava:
            r = self.porteiro.responder(pergunta)
            t = time.time()
            fala = self.voz.falar(r.texto)
            tempos = {**r.tempos_ms, "voz": round(1000 * (time.time() - t))}
        return {
            "texto": r.texto,
            "caminho": r.caminho,
            "ficha": r.ficha,
            "duracao": round(fala.duracao, 3),
            "bocas": fala.bocas,
            "audio": base64.b64encode(fala.wav).decode("ascii"),
            "tempos_ms": tempos,
        }


def criar_manipulador(estudio):
    class Manipulador(BaseHTTPRequestHandler):
        server_version = "EstudioTronikat"

        def log_message(self, fmt, *args):     # o log padrao imprime ate o corpo
            sys.stderr.write(f"[{self.log_date_time_string()}] {fmt % args}\n")

        def _cors(self) -> None:
            origem = self.headers.get("Origin")
            if origem in ORIGENS:
                self.send_header("Access-Control-Allow-Origin", origem)
                self.send_header("Vary", "Origin")

        def _json(self, codigo: int, corpo: dict) -> None:
            dados = json.dumps(corpo, ensure_ascii=False).encode("utf-8")
            self.send_response(codigo)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(dados)))
            self._cors()
            self.end_headers()
            self.wfile.write(dados)

        def do_OPTIONS(self) -> None:
            self.send_response(204)
            self._cors()
            self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
            self.send_header("Access-Control-Allow-Headers", "Content-Type")
            self.send_header("Access-Control-Allow-Private-Network", "true")
            self.end_headers()

        def do_GET(self) -> None:
            if self.path == "/saude":
                self._json(200, {"ok": True, "pronto_em_s": estudio.pronto_em})
            else:
                self._json(404, {"erro": "caminho desconhecido"})

        def do_POST(self) -> None:
            if self.path != "/perguntar":
                return self._json(404, {"erro": "caminho desconhecido"})
            try:
                tamanho = int(self.headers.get("Content-Length", "0"))
            except ValueError:
                return self._json(400, {"erro": "Content-Length invalido"})
            # O corpo nem e lido se for grande demais. O pior caso NAO e o UTF-8
            # (4 bytes): JSON pode escrever cada caractere ESCAPADO -- o "a" com
            # til vira barra-u-0-0-e-3, 6 bytes; um emoji vira dois desses, 12.
            # A primeira versao usou 4 e recusava uma pergunta legitima de 300
            # letras acentuadas enviada pelo json.dumps padrao. Pego pelo
            # testar_servidor.py. O limite de verdade (300 caracteres) e
            # conferido depois de ler.
            if tamanho > 12 * LIMITE_DA_PERGUNTA + 64:
                return self._json(413, {"erro": f"pergunta com mais de {LIMITE_DA_PERGUNTA} caracteres"})
            try:
                pergunta = json.loads(self.rfile.read(tamanho) or b"{}").get("pergunta", "")
            except (json.JSONDecodeError, AttributeError, UnicodeDecodeError):
                return self._json(400, {"erro": "corpo precisa ser JSON com o campo 'pergunta'"})
            if not isinstance(pergunta, str) or not pergunta.strip():
                return self._json(400, {"erro": "pergunta vazia"})
            if len(pergunta) > LIMITE_DA_PERGUNTA:
                return self._json(413, {"erro": f"pergunta com mais de {LIMITE_DA_PERGUNTA} caracteres"})
            self._json(200, estudio.responder(pergunta.strip()))

    return Manipulador


def main() -> int:
    print("carregando o estudio (modelo, juiz e voz)...", flush=True)
    estudio = Estudio()
    servidor = ThreadingHTTPServer((HOST, PORTA), criar_manipulador(estudio))
    print(f"estudio pronto em {estudio.pronto_em} s -- http://{HOST}:{PORTA}", flush=True)
    try:
        servidor.serve_forever()
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
