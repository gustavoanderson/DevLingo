#!/usr/bin/env python3
"""A ponte do Telegram: responde comandos e guarda recados.

    python3 tools/telegram.py              # le, responde, guarda
    python3 tools/telegram.py --enviar-relatorio

## O que este bot E, e o que ele NAO e

Ele responde **comandos**, com dados medidos na hora. Ele nao pensa, nao
opina e nao escreve codigo -- isso exigiria chamar um modelo, que custa
dinheiro, e a decisao do Gustavo em 11/09/2026 foi nao gastar por enquanto.

Entao a divisao e honesta:

    /status      -> um programa responde, instantaneo, R$ 0
    "e se a gente mudasse X?"  -> vira RECADO, e o Claude le na proxima sessao

Recado que vira resposta automatica generica seria pior que silencio: daria a
impressao de ter sido lido por alguem que nao leu.

## Por que nao ha arquivo de estado

O Telegram guarda o ponteiro do que ja foi entregue. Chamando `getUpdates` sem
`offset`, ele devolve tudo que ainda nao foi confirmado; chamando depois com
`offset = ultimo + 1`, ele confirma e esquece.

Isso evita commitar um arquivo de controle a cada minuto -- que poluiria o
historico do repositorio com centenas de commits vazios por dia.
"""

from __future__ import annotations

import json
import os
import sys
import urllib.parse
import urllib.request
from datetime import datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import relatorio  # noqa: E402

RAIZ = Path(__file__).resolve().parent.parent
RECADOS = RAIZ / "RECADOS.md"
TOKEN = os.environ.get("TELEGRAM_TOKEN", "")
CHAT = os.environ.get("TELEGRAM_CHAT_ID", "")


def chamar(metodo: str, **params) -> dict:
    url = f"https://api.telegram.org/bot{TOKEN}/{metodo}"
    dados = urllib.parse.urlencode(params).encode() if params else None
    try:
        with urllib.request.urlopen(url, dados, timeout=25) as r:
            return json.load(r)
    except Exception as erro:
        return {"ok": False, "erro": str(erro)}


def responder(texto: str, para: str | None = None) -> None:
    chamar("sendMessage", chat_id=para or CHAT, text=texto, parse_mode="Markdown")


def texto_status() -> str:
    d = relatorio.coletar()
    return (
        f"*DevLingo* — {d['quando']:%d/%m %H:%M}\n\n"
        f"versão `{d['versao']}`\n"
        f"{d['questoes']} questões em {d['trilhas']} trilhas\n"
        f"{d['testes']} testes\n"
        f"banco {'aprovado' if d['banco_ok'] else '*REPROVADO*'}"
        f" ({d['avisos']} avisos)\n"
        f"{len(d['commits'])} commits na semana\n\n"
        f"último: _{d['ultimo_commit'][:70]}_"
    )


def texto_pendencias() -> str:
    d = relatorio.coletar()
    linhas = "\n\n".join(
        f"{i}. {p}" for i, p in enumerate(relatorio.pendencias(d), 1)
    )
    return f"*Esperando você*\n\n{linhas}"


AJUDA = (
    "*Comandos*\n\n"
    "`/status` — números do projeto, medidos na hora\n"
    "`/pendencias` — o que está esperando você\n"
    "`/relatorio` — o relatório completo\n"
    "`/ajuda` — isto aqui\n\n"
    "Qualquer outra coisa que você escrever vira *recado*: fica guardado no "
    "repositório e o Claude lê na próxima sessão.\n\n"
    "Ele não responde recado sozinho — responder sem ter lido seria pior que "
    "não responder."
)

COMANDOS = {
    "/status": texto_status,
    "/pendencias": texto_pendencias,
    "/relatorio": lambda: f"```\n{relatorio.texto(relatorio.coletar())}\n```",
    "/ajuda": lambda: AJUDA,
    "/start": lambda: AJUDA,
    "/help": lambda: AJUDA,
}


def guardar_recado(quem: str, texto: str) -> None:
    """Grava no RECADOS.md, mais novo em cima.

    Em cima porque quem le comeca pelo topo, e recado velho ja respondido nao
    deve competir com o que chegou agora.
    """
    agora = datetime.now().strftime("%d/%m/%Y %H:%M")
    nova = f"- **{agora}** — {quem}: {texto}\n"
    if RECADOS.exists():
        conteudo = RECADOS.read_text(encoding="utf-8")
        marca = "<!-- novos aqui -->\n"
        conteudo = (
            conteudo.replace(marca, marca + nova)
            if marca in conteudo
            else conteudo + nova
        )
    else:
        conteudo = (
            "# Recados do Telegram\n\n"
            "Mensagens que o Gustavo mandou pelo bot e que **não são comando**.\n"
            "O Claude lê isto no começo de cada sessão.\n\n"
            "Risque com `~~` o que já foi tratado — apagar perderia o histórico "
            "de pedidos, que é justamente o que este arquivo existe para guardar.\n\n"
            "<!-- novos aqui -->\n" + nova
        )
    RECADOS.write_text(conteudo, encoding="utf-8")


def main() -> int:
    if not TOKEN or not CHAT:
        print("Faltam TELEGRAM_TOKEN e/ou TELEGRAM_CHAT_ID.")
        return 1

    if "--enviar-relatorio" in sys.argv:
        d = relatorio.coletar()
        responder(f"```\n{relatorio.texto(d)}\n```")
        print("relatorio enviado")
        return 0

    r = chamar("getUpdates", timeout=0)
    if not r.get("ok"):
        print("falha ao ler:", r)
        return 1

    updates = r.get("result", [])
    if not updates:
        print("nada novo")
        return 0

    recados = 0
    for u in updates:
        msg = u.get("message") or {}
        texto = (msg.get("text") or "").strip()
        chat = str((msg.get("chat") or {}).get("id", ""))
        quem = (msg.get("chat") or {}).get("first_name", "alguem")
        if not texto:
            continue

        # So o dono comanda. Sem isto, qualquer um que achasse o bot leria os
        # numeros do projeto -- e, pior, encheria o RECADOS.md.
        if chat != CHAT:
            print(f"ignorado: mensagem de outro chat ({chat})")
            continue

        acao = COMANDOS.get(texto.split()[0].lower())
        if acao:
            responder(acao(), para=chat)
            print(f"respondi {texto.split()[0]}")
        else:
            guardar_recado(quem, texto)
            recados += 1
            responder(
                "Recado guardado. ✍️\n\n"
                "O Claude lê na próxima sessão. Se for urgente, me chame por lá.",
                para=chat,
            )

    # Confirma a leitura: o Telegram para de reenviar estes.
    chamar("getUpdates", offset=updates[-1]["update_id"] + 1, timeout=0)
    print(f"processados {len(updates)}; {recados} recado(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
