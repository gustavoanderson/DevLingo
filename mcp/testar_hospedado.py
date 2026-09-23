"""Confere um servidor MCP que JA esta no ar, de fora dele.

POR QUE SEPARADO DE `test_remoto.py`

Aquele sobe um servidor local e fala com ele: e teste de CI, e roda sempre.
Este aponta para uma URL de verdade -- tunel temporario ou dominio proprio --
e por isso NAO entra no CI: teste que depende da internet de terceiro reprova
por motivo que nao e nosso, e portao que reprova sem culpa ensina a
contorna-lo.

Ele existe para responder uma pergunta que so a rede responde: *o caminho
inteiro esta de pe, e esta fechado para quem nao tem credencial?*

O QUE ELE VERIFICA, E A ORDEM IMPORTA

  1. o endereco responde           -- tunel de pe
  2. SEM credencial e barrado      -- a porta esta trancada
  3. COM credencial entra          -- a chave certa abre
  4. as seis ferramentas la estao  -- e o servidor certo do outro lado
  5. nenhuma delas grava           -- o que segura a porta se a chave vazar

O passo 2 e o mais importante, e e o unico que falha para o lado perigoso: um
servidor que responde `200` sem credencial esta ABERTO, e isso parece sucesso
para quem so olha se "funcionou".

Uso:
    python3 mcp/testar_hospedado.py https://mcp.devlingo.app.br/mcp
    python3 mcp/testar_hospedado.py https://algo.trycloudflare.com/mcp --sem-auth

As credenciais vem do ambiente, e nunca de argumento: o que se digita na linha
de comando fica no historico do terminal.

    export CF_ID=...  CF_SEGREDO=...
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.request

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


def postar(url: str, corpo: dict, credenciais: dict[str, str] | None):
    """Devolve (codigo, cabecalhos, texto). Nunca lanca por codigo HTTP."""
    cabecalhos = {
        "Content-Type": "application/json",
        # O transporte responde JSON **ou** um fluxo SSE, conforme a chamada.
        # Pedir so um dos dois devolve 406, e a mensagem nao diz isso.
        "Accept": "application/json, text/event-stream",
    }
    if credenciais:
        cabecalhos.update(credenciais)
    pedido = urllib.request.Request(
        url, data=json.dumps(corpo).encode(), headers=cabecalhos)
    try:
        with urllib.request.urlopen(pedido, timeout=30) as r:
            return r.status, dict(r.headers), r.read().decode()
    except urllib.error.HTTPError as e:
        return e.code, dict(e.headers), e.read().decode(errors="replace")


INICIAR = {
    "jsonrpc": "2.0", "id": 1, "method": "initialize",
    "params": {"protocolVersion": "2025-06-18", "capabilities": {},
               "clientInfo": {"name": "conferidor", "version": "1"}},
}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("url", help="o endpoint /mcp publicado")
    ap.add_argument("--sem-auth", action="store_true",
                    help="tunel temporario, ainda sem Access na frente")
    args = ap.parse_args()

    ident, segredo = os.environ.get("CF_ID"), os.environ.get("CF_SEGREDO")
    if not args.sem_auth and not (ident and segredo):
        raise SystemExit(
            "faltam CF_ID e CF_SEGREDO no ambiente.\n"
            "Se o Access ainda nao esta na frente, passe --sem-auth.")
    credenciais = ({"CF-Access-Client-Id": ident,
                    "CF-Access-Client-Secret": segredo}
                   if ident and segredo else None)

    print(f"conferindo {args.url}")

    # 1. de pe
    try:
        codigo, _, _ = postar(args.url, INICIAR, credenciais)
    except (urllib.error.URLError, OSError) as e:
        conferir(False, "o endereco responde", str(e)[:70])
        print("\n1 FALHA(S)")
        return 1
    conferir(True, "o endereco responde", f"HTTP {codigo}")

    # 2. trancado -- e este e o que falha para o lado perigoso
    if args.sem_auth:
        print("  --    porta trancada          (pulado: --sem-auth)")
    else:
        codigo_nu, cab, _ = postar(args.url, INICIAR, None)
        # O Access devolve 302 para o login quando a politica e `Allow` em vez
        # de `Service Auth` -- barrado tambem, mas pelo motivo errado, e o
        # sintoma seguinte seria 403 COM o token.
        barrado = codigo_nu in (401, 403) or (
            300 <= codigo_nu < 400 and "cloudflareaccess" in
            str(cab.get("Location", "")).lower())
        conferir(barrado, "SEM credencial e BARRADO", f"HTTP {codigo_nu}")
        if codigo_nu == 200:
            print("     ^ o servidor esta ABERTO: nenhuma politica esta valendo")

    # 3. a chave certa abre
    codigo, cabecalhos, texto = postar(args.url, INICIAR, credenciais)
    sessao = cabecalhos.get("mcp-session-id")
    conferir(codigo == 200 and bool(sessao),
             "COM credencial ENTRA e negocia sessao", f"HTTP {codigo}")
    if codigo != 200:
        print(f"\n{len(falhas)} FALHA(S)")
        return 1
    conferir("devlingo" in texto, "e o servidor do DevLingo do outro lado")

    # 4 e 5
    cab = dict(credenciais or {})
    cab["mcp-session-id"] = sessao
    _, _, lista = postar(
        args.url, {"jsonrpc": "2.0", "id": 2, "method": "tools/list",
                   "params": {}}, cab)
    achadas = set(re.findall(r'"name":"([a-z_]+)"', lista))
    conferir(achadas == ESPERADAS, "as SEIS ferramentas estao la",
             f"{len(achadas)}: {sorted(achadas)}")

    proibidos = ("criar", "gravar", "escrever", "publicar", "apagar",
                 "remover", "salvar")
    suspeitas = [f for f in achadas if any(p in f for p in proibidos)]
    conferir(not suspeitas, "nenhuma ferramenta publicada GRAVA",
             str(suspeitas))

    print("\nHOSPEDAGEM APROVADA" if not falhas else f"\n{len(falhas)} FALHA(S)")
    return 1 if falhas else 0


if __name__ == "__main__":
    sys.exit(main())
