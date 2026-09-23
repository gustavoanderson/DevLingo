"""Prova que o servidor MCP responde PELA REDE, e nao so por stdio.

POR QUE ESTE TESTE EXISTE SEPARADO

`test_servidor.py` fala com as ferramentas em processo. Isso prova que elas
funcionam, e nao prova que o transporte HTTP negocia sessao, roteia chamada e
devolve resultado -- que e a parte nova, e a unica que muda quando o servidor
sai da maquina de quem o escreveu.

E ele e o portao de uma promessa concreta: que hospedar NAO exige reescrever
nada. Se um dia o pacote `mcp` mudar o caminho do endpoint ou o cabecalho da
sessao, e aqui que isso aparece -- e nao no dia em que o servidor no ar parar
de responder para um cliente que ninguem esta olhando.

O QUE ELE NAO COBRE, dito em voz alta

A autenticacao. Ela nao mora aqui: quem valida credencial e o Cloudflare
Access, antes de a requisicao chegar na maquina. Testar isto exigiria o tunel
no ar, e um teste que depende da internet de terceiro nao entra no CI.

Uso:
    python3 mcp/test_remoto.py
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

RAIZ = Path(__file__).resolve().parent
PORTA = int(os.environ.get("PORTA_TESTE", "8932"))
BASE = f"http://127.0.0.1:{PORTA}/mcp"

# As seis, e o teste falha se aparecer uma setima sem alguem ter pensado nela.
# Ferramenta nova exposta na internet e decisao, nao detalhe.
ESPERADAS = {
    "conferir_teclado",
    "criterios_de_revisao",
    "impressao_digital",
    "material_para_revisao",
    "topicos_da_trilha",
    "validar_licao",
}

falhas: list[str] = []


def conferir(ok: bool, nome: str, detalhe: str = "") -> None:
    print(f"  {'ok   ' if ok else 'FALHA'} {nome}{'  ' + detalhe if detalhe else ''}")
    if not ok:
        falhas.append(nome)


def chamar(metodo: str, params: dict, ident: int, sessao: str | None):
    corpo = {"jsonrpc": "2.0", "id": ident, "method": metodo, "params": params}
    cabecalhos = {
        "Content-Type": "application/json",
        # O transporte responde JSON **ou** um fluxo SSE, conforme a chamada.
        # Pedir so um dos dois devolve 406, e o erro nao diz isso.
        "Accept": "application/json, text/event-stream",
    }
    if sessao:
        cabecalhos["mcp-session-id"] = sessao
    pedido = urllib.request.Request(
        BASE, data=json.dumps(corpo).encode(), headers=cabecalhos)
    with urllib.request.urlopen(pedido, timeout=30) as resposta:
        return resposta.headers.get("mcp-session-id"), resposta.read().decode()


def subir() -> subprocess.Popen:
    ambiente = dict(os.environ,
                    MCP_TRANSPORTE="streamable-http",
                    MCP_PORTA=str(PORTA))
    processo = subprocess.Popen(
        [sys.executable, str(RAIZ / "servidor.py")],
        env=ambiente, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    # Espera o servico responder, em vez de chutar um sleep: numa maquina
    # lenta o chute vira teste instavel, que e pior que teste que falha.
    for _ in range(60):
        try:
            chamar("initialize", {"protocolVersion": "2025-06-18",
                                  "capabilities": {},
                                  "clientInfo": {"name": "t", "version": "1"}},
                   0, None)
            return processo
        except (urllib.error.URLError, OSError):
            time.sleep(0.5)
    processo.kill()
    raise SystemExit("o servidor nao subiu em 30 s")


def main() -> int:
    print(f"servidor MCP em {BASE}")
    processo = subir()
    try:
        sessao, texto = chamar(
            "initialize",
            {"protocolVersion": "2025-06-18", "capabilities": {},
             "clientInfo": {"name": "teste", "version": "1"}}, 1, None)
        conferir(bool(sessao), "o transporte negocia uma sessao", str(sessao))
        conferir("devlingo" in texto, "o servidor se identifica")

        _, lista = chamar("tools/list", {}, 2, sessao)
        achadas = set(re.findall(r'"name":"([a-z_]+)"', lista))
        conferir(achadas == ESPERADAS,
                 "as SEIS ferramentas respondem pela rede",
                 f"{len(achadas)}: {sorted(achadas)}")

        # NENHUMA PODE GRAVAR, e e isto que segura a porta se a credencial
        # vazar. Exposto na internet, o limite deixa de ser elegancia de
        # projeto e vira a defesa -- entao ele vira asercao.
        proibidos = ("criar", "gravar", "escrever", "publicar", "apagar",
                     "remover", "salvar")
        suspeitas = [f for f in achadas if any(p in f for p in proibidos)]
        conferir(not suspeitas,
                 "nenhuma ferramenta exposta GRAVA", str(suspeitas))

        # E uma chamada de verdade, porque listar nao prova que roteia.
        _, r = chamar("tools/call",
                      {"name": "topicos_da_trilha",
                       "arguments": {"trilha": "java"}}, 3, sessao)
        conferir("igualdade" in r,
                 "uma ferramenta EXECUTA e devolve dado do banco")
    finally:
        processo.terminate()
        processo.wait(timeout=10)

    print("\nMCP REMOTO APROVADO" if not falhas else f"\n{len(falhas)} FALHA(S)")
    return 1 if falhas else 0


if __name__ == "__main__":
    sys.exit(main())
