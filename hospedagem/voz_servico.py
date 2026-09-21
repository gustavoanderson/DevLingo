"""O serviço de voz do Tr∅nikAt: texto -> áudio + o movimento da boca.

POR QUE ELE EXISTE
------------------
O site tinha DUAS vozes, e o Gustavo notou: as 31 fichas tocam áudio do Piper,
gravado antes, e as respostas GERADAS na borda saíam pela síntese do navegador,
que ele descreveu como "bem robótica". Duas vozes para o mesmo personagem é
defeito de produto, não detalhe.

E os dois pedidos dele estavam ligados: deixar o Tr∅nikAt mais esperto significa
MAIS respostas geradas, e resposta gerada era justamente a que saía robótica.
Fazer só a parte da esperteza transformaria a voz errada de exceção em regra.

A saída escolhida por ele é a Fase 2 do plano: **Piper em tudo**. Este serviço é
o que torna isso possível -- ele dá ao texto gerado a mesma voz que as fichas já
tinham.

O QUE ELE NÃO FAZ, E POR QUÊ
----------------------------
Ele NÃO tem porteiro, NÃO chama modelo nenhum e NÃO decide o que responder. Isso
tudo já vive no Worker da Cloudflare, que é quem recebe a pergunta. Aqui entra
texto que já passou pelo porteiro e pelo juiz, e sai som.

A consequência é o que torna a hospedagem viável: sem Ollama e sem GPU, sobra
Piper em CPU -- que cabe folgado nos 2 OCPU do Oracle Always Free. O
`estudio/servidor.py` junta porteiro e voz porque ele roda na máquina do
Gustavo, com a GTX 1650 ali; na borda os dois papéis se separam.

A VOZ VEM DE `estudio/voz.py`, E NÃO É COPIADA
----------------------------------------------
Aquele arquivo guarda a escolha de ouvido do Gustavo (faber, tom 1,45), a
pronúncia de "Tr∅nikAt" e a tabela de abertura de boca por fonema. Copiar isso
para cá criaria duas versões da voz do personagem, que divergiriam -- o mesmo
defeito que o CLAUDE.md registra para o `normalize()` e para os arquivos
gerados. Então este serviço IMPORTA aquele módulo.

Uso local, para provar antes de hospedar:
    estudio/.venv/Scripts/python.exe hospedagem/voz_servico.py
    curl -s -X POST http://127.0.0.1:8770/falar -d '{"texto":"Oi, eu sou o Tr∅nikAt."}'
"""
from __future__ import annotations

import base64
import json
import os
import sys
import time
from collections import OrderedDict
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from threading import Lock

# `estudio/` entra no caminho para que a voz seja a MESMA do estúdio. Ao
# hospedar, `estudio/voz.py` e o modelo .onnx vão junto -- ver o README.
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "estudio"))

PORTA = int(os.environ.get("VOZ_PORTA", "8770"))

# A CHAVE, e o motivo de o padrão ser fechado em vez de aberto.
#
# Quem chama este serviço em produção não é o navegador: é o Worker da
# Cloudflare, que já é HTTPS e já tem o CORS do site. Ele é a ponte, porque
# navegador não busca em HTTP puro mas Worker busca -- e isso apaga do roteiro
# o domínio, o certificado e o túnel.
#
# O preço é uma porta aberta na máquina. A chave é o que a defende: o Worker a
# manda em `X-Voz-Chave`, e quem não a tiver leva 401.
#
# SEM CHAVE DEFINIDA, SÓ LOCALHOST RESPONDE. É deliberado: a falha provável não
# é alguém adivinhar a chave, é alguém ESQUECER de defini-la ao subir. Nesse
# caso o serviço fica inacessível de fora -- que é chato e visível -- em vez de
# ficar aberto, que é cômodo e silencioso.
CHAVE = os.environ.get("VOZ_CHAVE", "").strip()
LOCAIS = {"127.0.0.1", "::1", "localhost"}

# De onde o navegador pode chamar. Origem que não estiver aqui não recebe
# cabeçalho de CORS e o navegador recusa sozinho. Não é segurança de verdade
# -- qualquer cliente fora do navegador ignora CORS --, é o que impede outro
# site de pendurar a conta de CPU deste aqui.
ORIGENS = {
    "https://gustavoanderson.github.io",
    "http://127.0.0.1:8000", "http://localhost:8000",
    "http://127.0.0.1:8099", "http://localhost:8099",
}

# O Worker limita a PERGUNTA a 300 caracteres e a resposta a 3 frases curtas.
# 700 dá folga larga e ainda impede que alguém mande um livro para sintetizar:
# áudio custa CPU, e CPU é o que esta máquina tem pouco.
LIMITE = 700

# Quantas falas ficam guardadas. A mesma pergunta costuma voltar, e o Piper tem
# aleatoriedade -- então o cache faz duas coisas: poupa CPU e garante que a
# mesma frase soe IGUAL nas duas vezes. Sem ele, repetir uma pergunta dava uma
# entonação diferente, o que lê como se fosse outra gravação.
CACHE_MAX = 256

# Curta de proposito: o que aquece e RODAR a rede, e ela roda inteira em
# qualquer tamanho de texto. Frase longa custaria CPU sem aquecer mais nada.
TEXTO_AQUECIMENTO = "Oi."

# Um balde por endereço. Sintetizar é a operação cara deste serviço, e ele fica
# numa máquina gratuita: sem isto, um laço de `curl` de alguém derruba a voz do
# site inteiro. Não protege contra muitos endereços, e não pretende -- protege
# contra o caso comum, que é um só insistindo.
BALDE_MAX = 12          # falas em rajada
BALDE_POR_S = 0.5       # e meia por segundo depois disso


class Limitador:
    def __init__(self) -> None:
        self.baldes: dict[str, tuple[float, float]] = {}
        self.trava = Lock()

    def permite(self, quem: str) -> bool:
        agora = time.time()
        with self.trava:
            fichas, visto = self.baldes.get(quem, (BALDE_MAX, agora))
            fichas = min(BALDE_MAX, fichas + (agora - visto) * BALDE_POR_S)
            if fichas < 1:
                self.baldes[quem] = (fichas, agora)
                return False
            self.baldes[quem] = (fichas - 1, agora)
            # Não deixa o dicionário crescer para sempre num serviço que fica
            # meses no ar: quem não voltou há uma hora já recarregou o balde
            # inteiro de qualquer jeito.
            if len(self.baldes) > 4096:
                for k, (_, t) in list(self.baldes.items()):
                    if agora - t > 3600:
                        self.baldes.pop(k, None)
            return True


class Estudio:
    """Carrega a voz UMA vez. O carregamento leva ~5 s; fazê-lo por requisição
    transformaria cada fala em cinco segundos de espera."""

    def __init__(self) -> None:
        from voz import Voz, MODELO
        self.modelo = Path(MODELO).name
        t = time.time()
        self.voz = Voz()
        # Aquece: a primeira síntese paga a inicialização do onnx, e quem paga
        # isso não pode ser o primeiro visitante.
        self.voz.falar("aquecendo.")
        self.carga_s = time.time() - t
        self.cache: OrderedDict[str, dict] = OrderedDict()
        self.trava = Lock()
        self.sintetizadas = 0
        self.do_cache = 0
        self.aquecimentos = 0

    def aquecer(self) -> dict:
        """Toca o modelo de proposito, PASSANDO AO LARGO DO CACHE.

        Medido em 21/09/2026: depois de ~3 dias parado, a primeira sintese
        custou 7,0 s contra 1,6 s quente -- 5,4 s a mais. O processo nao tinha
        reiniciado (o contador `sintetizadas` estava zerado mas intacto), e a
        ociosidade de 15 minutos NAO esfria: a razao ficou em 0,72-0,76x o
        tempo real nas cinco medicoes. Entao o custo e de ociosidade longa, de
        horas ou dias -- que e o perfil de um site de portfolio, onde a visita
        e rara e quem a faz paga sempre o pior caso.

        E O CACHE E A ARMADILHA. A ideia obvia -- mandar sintetizar uma frase
        curta e fixa -- falharia exatamente quando fosse necessaria: o cache
        guarda POR TEXTO, entao da segunda visita em diante ele devolveria o
        audio guardado sem tocar no modelo. Por isso este metodo chama a voz
        direto e nao grava nada.

        Nao entra em `sintetizadas` de proposito: aquele numero responde
        "quantas falas o site pediu", e misturar aquecimento ali faria o
        /saude mentir sobre o uso real.
        """
        i = time.time()
        self.voz.falar(TEXTO_AQUECIMENTO)
        with self.trava:
            self.aquecimentos += 1
        return {"ok": True, "sintese_s": round(time.time() - i, 3)}

    def falar(self, texto: str) -> dict:
        with self.trava:
            if texto in self.cache:
                self.cache.move_to_end(texto)
                self.do_cache += 1
                return self.cache[texto]
        fala = self.voz.falar(texto)
        corpo = {
            "audio": base64.b64encode(fala.wav).decode("ascii"),
            "duracao": round(fala.duracao, 3),
            "bocas": fala.bocas,
            "sintese_s": round(fala.sintese_s, 3),
        }
        with self.trava:
            self.cache[texto] = corpo
            self.cache.move_to_end(texto)
            while len(self.cache) > CACHE_MAX:
                self.cache.popitem(last=False)
            self.sintetizadas += 1
        return corpo


def criar_manipulador(estudio: Estudio, limitador: Limitador):
    class Manipulador(BaseHTTPRequestHandler):
        protocol_version = "HTTP/1.1"

        def log_message(self, fmt, *args):      # o log padrão imprime o corpo
            print(f"{self.address_string()} {fmt % args}", flush=True)

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
            self.send_header("Access-Control-Allow-Methods", "POST, GET, OPTIONS")
            self.send_header("Access-Control-Allow-Headers", "Content-Type")
            self.send_header("Content-Length", "0")
            self.end_headers()

        def do_GET(self) -> None:
            if self.path != "/saude":
                return self._json(404, {"erro": "caminho desconhecido"})
            self._json(200, {
                # Diz SE ha chave, nunca qual. Sem isto, conferir a configuracao
                # de fora exigiria entrar na maquina por SSH.
                "ok": True, "voz": estudio.modelo, "com_chave": bool(CHAVE),
                "carga_s": round(estudio.carga_s, 2),
                "sintetizadas": estudio.sintetizadas, "do_cache": estudio.do_cache,
                "aquecimentos": estudio.aquecimentos,
                "em_cache": len(estudio.cache),
            })

        def _autorizado(self) -> bool:
            if CHAVE:
                return self.headers.get("X-Voz-Chave", "") == CHAVE
            # Sem chave: só quem está na própria máquina. Ver o comentário de
            # CHAVE -- fechado é o padrão seguro para o erro que de fato acontece.
            return self.client_address[0] in LOCAIS

        def do_POST(self) -> None:
            if self.path not in ("/falar", "/aquecer"):
                return self._json(404, {"erro": "caminho desconhecido"})
            if not self._autorizado():
                return self._json(401, {"erro": "sem chave"})
            # Quem está atrás de um túnel ou proxy chega sempre do mesmo IP;
            # o cabeçalho diz o endereço de verdade. Só é confiável porque
            # quem o escreve é o túnel, e não o visitante.
            quem = (self.headers.get("CF-Connecting-IP")
                    or self.headers.get("X-Forwarded-For", "").split(",")[0].strip()
                    or self.client_address[0])
            if not limitador.permite(quem):
                return self._json(429, {"erro": "muitas falas seguidas; espere um pouco"})
            if self.path == "/aquecer":
                # Passa pela chave e pelo limitador como o /falar: aquecer custa
                # CPU, e a maquina tem um nucleo so.
                try:
                    return self._json(200, estudio.aquecer())
                except Exception as e:
                    print(f"falha ao aquecer: {e}", flush=True)
                    return self._json(503, {"erro": "voz indisponivel"})
            try:
                n = int(self.headers.get("Content-Length", "0"))
                if n > 8192:
                    return self._json(413, {"erro": "corpo grande demais"})
                texto = json.loads(self.rfile.read(n) or b"{}").get("texto")
            except Exception:
                return self._json(400, {"erro": "corpo precisa ser JSON com o campo 'texto'"})
            if not isinstance(texto, str) or not texto.strip():
                return self._json(400, {"erro": "texto vazio"})
            texto = texto.strip()
            if len(texto) > LIMITE:
                return self._json(413, {"erro": f"texto com mais de {LIMITE} caracteres"})
            try:
                self._json(200, estudio.falar(texto))
            except Exception as e:
                # Falhar aqui deixa o site MUDO, e não quebrado: o texto já está
                # na tela quando a voz é pedida. Voz é conveniência, não
                # requisito -- a mesma regra que o CLAUDE.md já dá ao som do app.
                print(f"falha ao sintetizar: {e}", flush=True)
                self._json(503, {"erro": "voz indisponivel"})

    return Manipulador


def main() -> int:
    print("carregando a voz...", flush=True)
    estudio = Estudio()
    print(f"voz {estudio.modelo} carregada em {estudio.carga_s:.1f} s", flush=True)
    if CHAVE:
        print(f"chave definida ({len(CHAVE)} caracteres): aceita de qualquer lugar "
              "quem mandar X-Voz-Chave", flush=True)
    else:
        print("SEM CHAVE: so localhost responde. Defina VOZ_CHAVE para o Worker "
              "poder chamar. Ver hospedagem/ORACLE.md", flush=True)
    servidor = ThreadingHTTPServer(("0.0.0.0", PORTA), criar_manipulador(estudio, Limitador()))
    print(f"ouvindo em http://0.0.0.0:{PORTA}  (POST /falar, GET /saude)", flush=True)
    try:
        servidor.serve_forever()
    except KeyboardInterrupt:
        print("\nencerrando")
    return 0


if __name__ == "__main__":
    sys.exit(main())
