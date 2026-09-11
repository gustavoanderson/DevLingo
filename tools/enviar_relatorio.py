#!/usr/bin/env python3
"""Envia o relatorio do DevLingo por e-mail.

    python3 tools/enviar_relatorio.py --seco     # mostra, nao envia
    python3 tools/enviar_relatorio.py            # envia de verdade

## Separado de `relatorio.py` de proposito

Aquele arquivo PRODUZ o texto; este entrega. A separacao permite conferir o
conteudo sem disparar nada para ninguem -- e `--seco` existe exatamente para
isso: imprime o e-mail inteiro, com cabecalho e corpo, sem tocar em servidor.

Um script de envio que so da para testar enviando e' um script que ninguem
testa.

## Os tres segredos, e por que nenhum mora aqui

    REMETENTE_EMAIL ...... a conta que envia
    REMETENTE_SENHA_APP .. a senha de app do Google (16 caracteres)
    DESTINO_EMAIL ........ para onde vai

Todos vem de variavel de ambiente. **Senha em codigo vira senha no git**, e
senha no git de repositorio publico vira senha do mundo -- e esta da permissao
de enviar e-mail em nome de quem a gerou.

Senha de app NAO e a senha da conta Google: e um codigo de 16 letras que so
serve para envio, que nao passa pela verificacao em duas etapas, e que se
revoga sozinho sem mexer na conta. Se ela vazar, o estrago e mandar e-mail
como voce -- ruim, e muito menor que entregar a conta.
"""

from __future__ import annotations

import os
import smtplib
import ssl
import sys
from email.message import EmailMessage
from email.utils import formatdate
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import relatorio  # noqa: E402

SERVIDOR = "smtp.gmail.com"
PORTA = 587  # STARTTLS. A 465 (SSL direto) tambem serve; esta atravessa mais
             # redes corporativas, que costumam bloquear a 465.


def montar(dados: dict, de: str, para: str) -> EmailMessage:
    msg = EmailMessage()
    # O assunto carrega o numero que mais muda, para dar para ler a semana
    # inteira pela lista da caixa de entrada, sem abrir nada.
    msg["Subject"] = (
        f"DevLingo — {dados['questoes']} questões, {dados['testes']} testes, "
        f"{len(dados['commits'])} commits na semana"
    )
    msg["From"] = de
    msg["To"] = para
    msg["Date"] = formatdate(localtime=True)
    # Texto primeiro, HTML como alternativa: cliente que nao renderiza HTML
    # -- ou pessoa que le no relogio -- ainda recebe o conteudo inteiro.
    msg.set_content(relatorio.texto(dados))
    msg.add_alternative(relatorio.html(dados), subtype="html")
    return msg


def main() -> int:
    seco = "--seco" in sys.argv
    de = os.environ.get("REMETENTE_EMAIL", "")
    senha = os.environ.get("REMETENTE_SENHA_APP", "")
    para = os.environ.get("DESTINO_EMAIL", "") or de

    if not seco and not (de and senha and para):
        faltando = [n for n, v in [
            ("REMETENTE_EMAIL", de),
            ("REMETENTE_SENHA_APP", senha),
            ("DESTINO_EMAIL", para),
        ] if not v]
        print(f"Faltam as variaveis: {', '.join(faltando)}")
        print("Rode com --seco para ver o e-mail sem enviar.")
        return 1

    dados = relatorio.coletar()
    # Sem parenteses: em RFC 5322 texto entre parenteses e COMENTARIO, entao
    # "(nao definido)" saia como endereco vazio no modo seco.
    msg = montar(dados, de or "nao-definido@exemplo", para or "nao-definido@exemplo")

    if seco:
        print("=" * 60)
        print(f"De     : {msg['From']}")
        print(f"Para   : {msg['To']}")
        print(f"Assunto: {msg['Subject']}")
        print("=" * 60)
        print(relatorio.texto(dados))
        print("=" * 60)
        print(f"(modo seco: nada foi enviado; o HTML tem "
              f"{len(relatorio.html(dados))} bytes)")
        return 0

    contexto = ssl.create_default_context()
    with smtplib.SMTP(SERVIDOR, PORTA, timeout=30) as smtp:
        smtp.starttls(context=contexto)
        smtp.login(de, senha)
        smtp.send_message(msg)
    print(f"Relatorio enviado para {para}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
