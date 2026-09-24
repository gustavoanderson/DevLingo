#!/usr/bin/env python3
"""Confere que o dominio proprio serve o site E o jogo, e que a IA responde.

POR QUE EXISTE

Trocar o endereco publico mexe em quatro coisas que falham SEPARADAS, e tres
delas falham em silencio -- a pagina carrega e parece certa:

  1. o DNS aponta, mas o certificado ainda nao saiu     -> erro de HTTPS
  2. o site abre, mas o jogo nao                        -> caminho relativo
  3. tudo abre, mas o Tronikat para de responder         -> CORS do Worker
  4. tudo abre, mas o login falha                       -> dominio nao
                                                           autorizado no Firebase

As tres ultimas nao aparecem no repositorio: a verdade mora no Worker e no
console do Firebase. E a quarta so se descobre TENTANDO ENTRAR -- por isso o
teste manda credencial falsa de proposito e le o CODIGO do erro, e nao o
sucesso.

NAO ENTRA NO CI: depende de DNS de terceiro e de certificado emitido, e portao
que reprova por motivo que nao e nosso ensina a contorna-lo.

Uso:
    python3 tools/conferir_dominio.py
    python3 tools/conferir_dominio.py https://outro-dominio
"""
from __future__ import annotations

import json
import sys
import urllib.error
import urllib.request
from urllib.parse import urlparse

PADRAO = "https://devlingo.app.br"

# Os mesmos sete caminhos provados quando o jogo foi publicado. O jogo le o
# banco e o mascote de FORA da pasta dele, sem copia -- entao um caminho
# quebrado aqui e 404 no console, com a tela continuando bonita.
CAMINHOS = [
    ("", "o site do portfolio"),
    ("jogo/", "o jogo"),
    ("jogo/cerebro.js", "o cerebro compilado"),
    ("jogo/conteudo.json", "o indice das licoes"),
    ("app/assets/content/python/python-beg-01.json", "o banco de questoes"),
    ("assets/mascot/tronikat-retrato.svg", "o mascote"),
    ("site/falas/indice.json", "as falas gravadas"),
]

falhas: list[str] = []


def conferir(ok: bool, nome: str, detalhe: str = "") -> None:
    print(f"  {'ok   ' if ok else 'FALHA'} {nome}{'  ' + detalhe if detalhe else ''}")
    if not ok:
        falhas.append(nome)


def buscar(url: str, dados=None, cabecalhos=None):
    """Devolve (codigo, texto, cabecalhos_da_resposta)."""
    pedido = urllib.request.Request(
        url, data=dados,
        # Sem User-Agent proprio a Cloudflare responde 403 ao `urllib`, que se
        # anuncia como robo. Ja me custou um diagnostico errado.
        headers={"User-Agent": "DevLingo-conferidor/1.0", **(cabecalhos or {})})
    try:
        with urllib.request.urlopen(pedido, timeout=30) as r:
            return r.status, r.read().decode(errors="replace"), dict(r.headers)
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode(errors="replace"), dict(e.headers)
    except Exception as e:  # certificado, DNS, conexao
        return 0, str(e), {}


def main() -> int:
    base = (sys.argv[1] if len(sys.argv) > 1 else PADRAO).rstrip("/")
    print(f"conferindo {base}")

    print("\n--- os caminhos que o jogo pede ---")
    for caminho, nome in CAMINHOS:
        codigo, corpo, _ = buscar(f"{base}/{caminho}")
        detalhe = f"HTTP {codigo}" if codigo else corpo[:60]
        conferir(codigo == 200, nome, detalhe)
        # Certificado ainda nao emitido e o caso mais comum logo apos apontar
        # o DNS, e ele leva ate uma hora. Vale dizer, em vez de deixar o
        # "FALHA" parecer defeito de configuracao.
        if codigo == 0 and "CERTIFICATE" in corpo.upper():
            print("        ^ o certificado do GitHub Pages ainda nao saiu.")
            print("          Leva ate uma hora. Nao e configuracao errada.")

    # SAIDA EM ASCII PURO, e isto nao e estilo: o terminal do Windows usa
    # cp1252, e o `∅` do nome dele derruba o script com UnicodeEncodeError
    # ANTES de imprimir qualquer resultado. Um conferidor que quebra ao
    # escrever o titulo de uma secao nao confere nada.
    print("\n--- o Tronikat responde a este dominio? ---")
    # O CORS e a parte que falha em SILENCIO: a pagina abre, o jogo funciona,
    # e so a janela do mascote nao responde. O cabecalho `Origin` e o que o
    # navegador manda, e e o que o Worker compara com a lista dele.
    # ORIGEM E `esquema://host`, SEM CAMINHO -- e isto me pegou junto com o
    # erro acima. Nenhum navegador manda `Origin: https://site.com/pasta`, e
    # o Worker compara a string inteira: mandar o caminho junto faz a origem
    # certa parecer desconhecida.
    p = urlparse(base)
    origem = f"{p.scheme}://{p.netloc}"
    codigo, corpo, cab = buscar(
        "https://tronikat.tronikat-busca.workers.dev/perguntar",
        dados=json.dumps({"pergunta": "o que e o devlingo?"}).encode(),
        cabecalhos={"Content-Type": "application/json", "Origin": origem})

    # O QUE SE MEDE E O CABECALHO, e nao o codigo HTTP -- e descobrir isso
    # custou uma sonda. CORS e protecao do NAVEGADOR: o Worker responde 200
    # para qualquer um e apenas OMITE `Access-Control-Allow-Origin` para quem
    # nao esta na lista. Quem confere o codigo esta medindo algo que nunca
    # muda, e aprova origem nenhuma reconhecida.
    liberada = cab.get("Access-Control-Allow-Origin") == origem
    conferir(liberada, f"o Worker LIBERA {origem}",
             cab.get("Access-Control-Allow-Origin") or "cabecalho AUSENTE")
    if not liberada:
        print("        ^ a pagina abriria e a janela do mascote falharia,")
        print("          sem dizer por que. Acrescente a origem em")
        print("          hospedagem/cloudflare/src/index.js e faca o deploy.")
    if codigo == 200:
        try:
            conferir(bool(json.loads(corpo).get("texto")),
                     "e devolve uma resposta de verdade")
        except json.JSONDecodeError:
            conferir(False, "e devolve uma resposta de verdade", corpo[:60])

    print("\n--- o Firebase autoriza este dominio? ---")
    # Nao da para perguntar isso ao repositorio: a lista mora no console. O
    # jeito de descobrir e TENTAR ENTRAR com credencial falsa e ler o codigo
    # do erro -- o que interessa nao e entrar.
    print("  (so o navegador responde; rode `node jogo/testar_dominio.js`)")

    print("\nDOMINIO APROVADO" if not falhas else f"\n{len(falhas)} FALHA(S)")
    return 1 if falhas else 0


if __name__ == "__main__":
    sys.exit(main())
