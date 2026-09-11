#!/usr/bin/env python3
"""Gera o relatorio de estado do DevLingo.

    python3 tools/relatorio.py            # imprime em texto
    python3 tools/relatorio.py --html     # imprime em HTML, para e-mail

## O que ele NAO e

Nao e "a IA contando o que fez". **Todo numero aqui sai de medicao**: conta de
commit, contagem de arquivo, saida do validador. Se o relatorio disser que ha
404 questoes, e porque alguem contou 404 questoes agora.

Isso e deliberado, e e a mesma regra que vale para o resto do projeto. Um
relatorio automatico que estima, arredonda ou elogia vira ruido em duas
semanas -- e quem recebe para de abrir.

## Por que ele fica separado do canal

Este arquivo so PRODUZ o texto. Quem envia -- e-mail, Telegram, arquivo --
e outro programa. Assim o canal pode mudar sem tocar no conteudo, e o
conteudo pode ser conferido rodando o comando acima, sem disparar nada para
ninguem.
"""

from __future__ import annotations

import json
import subprocess
import sys
from collections import Counter
from datetime import datetime, timedelta
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
CONTEUDO = RAIZ / "app" / "assets" / "content"


def _git(*args) -> str:
    try:
        return subprocess.run(
            ["git", *args], cwd=RAIZ, capture_output=True, text=True, timeout=30
        ).stdout.strip()
    except Exception:
        return ""


def coletar() -> dict:
    desde = "7 days ago"
    commits = [c for c in _git("log", f"--since={desde}", "--oneline").splitlines() if c]

    # Arquivos tocados na semana, agrupados pelo que sao. Diz onde o trabalho
    # foi, que e mais util que o total de commits.
    tocados = Counter()
    for linha in _git("log", f"--since={desde}", "--name-only", "--format=").splitlines():
        if not linha.strip():
            continue
        if linha.startswith("app/assets/content/"):
            tocados["conteudo"] += 1
        elif linha.startswith(("app/lib/", "app/test/")):
            tocados["app"] += 1
        elif linha.startswith("mcp/"):
            tocados["servidor mcp"] += 1
        elif linha.startswith("tools/"):
            tocados["ferramentas"] += 1
        elif linha.endswith(".md"):
            tocados["documentacao"] += 1

    questoes, por_trilha = 0, {}
    for arq in sorted(CONTEUDO.rglob("*.json")):
        dados = json.loads(arq.read_text(encoding="utf-8"))
        n = len(dados.get("questions", []))
        questoes += n
        por_trilha[dados.get("language", "?")] = por_trilha.get(dados.get("language", "?"), 0) + n

    # O validador e a fonte da verdade sobre a saude do banco. Rodar de verdade
    # custa dois segundos e vale mais que qualquer numero guardado.
    try:
        val = subprocess.run(
            [sys.executable, str(RAIZ / "tools" / "validate_questions.py"), str(CONTEUDO)],
            capture_output=True, text=True, timeout=180,
        )
        banco_ok = val.returncode == 0
        avisos = sum(1 for l in val.stdout.splitlines() if "[AVISO]" in l)
    except Exception:
        banco_ok, avisos = None, None

    readme = (RAIZ / "README.md").read_text(encoding="utf-8")
    import re
    def badge(nome):
        m = re.search(rf"{nome}-(\d+)", readme)
        return int(m.group(1)) if m else None

    return {
        "quando": datetime.now(),
        "commits": commits,
        "tocados": tocados,
        "questoes": questoes,
        "por_trilha": por_trilha,
        "trilhas": len(por_trilha),
        "testes": badge("testes"),
        "banco_ok": banco_ok,
        "avisos": avisos,
        "versao": next(
            (l.split(":")[1].strip()
             for l in (RAIZ / "app" / "pubspec.yaml").read_text(encoding="utf-8").splitlines()
             if l.startswith("version:")), "?"),
        "ultimo_commit": _git("log", "-1", "--format=%s"),
        "arquivos_dart": len(list((RAIZ / "app" / "lib").rglob("*.dart"))),
    }


# As perguntas que so o Gustavo responde. Elas ficam AQUI, e nao numa lista
# solta, porque um relatorio que so informa nao move nada -- ele precisa
# terminar com o que espera dele.
def pendencias(d: dict) -> list[str]:
    itens = []
    # ATENCAO: quais trilhas foram jogadas NAO e medivel daqui. O progresso
    # vive no Firestore e no SQLite do aparelho, e `run-as` nao alcanca um
    # build de release.
    #
    # A primeira versao deste relatorio afirmava "6 trilhas nunca jogadas,
    # incluindo python" -- e era palpite meu, logo acima da frase "todo numero
    # foi medido agora". Numero inventado dentro de um relatorio que se vende
    # como medido e pior que numero nenhum: ele contamina os outros.
    itens.append(
        f"O nivel intermediario das {d['trilhas']} trilhas espera voce jogar o "
        f"iniciante -- calibrar dificuldade sem ninguem ter jogado e chute. "
        f"Quais ja foram jogadas nao aparece aqui porque o progresso vive no "
        f"aparelho e na nuvem, fora do alcance deste relatorio."
    )
    itens.append(
        "O gerador do icone nunca foi versionado: hoje o icone e arte editada "
        "a mao, contra o principio de que arte nasce de codigo."
    )
    itens.append(
        "O app nao tem tela de licencas das dependencias (`showLicensePage`). "
        "Algumas exigem esse aviso antes de publicar em loja."
    )
    return itens


def texto(d: dict) -> str:
    L = []
    L.append(f"DevLingo — estado em {d['quando']:%d/%m/%Y}")
    L.append("=" * 46)
    L.append("")
    L.append(f"  Versao ............ {d['versao']}")
    L.append(f"  Questoes .......... {d['questoes']} em {d['trilhas']} trilhas")
    L.append(f"  Testes ............ {d['testes']}")
    L.append(f"  Arquivos Dart ..... {d['arquivos_dart']}")
    if d["banco_ok"] is not None:
        L.append(f"  Banco ............. {'APROVADO' if d['banco_ok'] else 'REPROVADO'}"
                 f" ({d['avisos']} avisos)")
    L.append("")
    L.append(f"NA ULTIMA SEMANA — {len(d['commits'])} commits")
    if d["tocados"]:
        for area, n in d["tocados"].most_common():
            L.append(f"  {n:4d} arquivos em {area}")
    L.append("")
    L.append(f"  ultimo: {d['ultimo_commit'][:60]}")
    L.append("")
    L.append("ESPERANDO VOCE")
    for i, p in enumerate(pendencias(d), 1):
        L.append(f"  {i}. {p}")
    L.append("")
    L.append("Todo numero acima foi medido agora, nao estimado.")
    return "\n".join(L)


def html(d: dict) -> str:
    linhas = "".join(
        f"<tr><td style='padding:4px 14px 4px 0;color:#666'>{k}</td>"
        f"<td style='padding:4px 0;font-weight:600'>{v}</td></tr>"
        for k, v in [
            ("Versão", d["versao"]),
            ("Questões", f"{d['questoes']} em {d['trilhas']} trilhas"),
            ("Testes", d["testes"]),
            ("Banco", "aprovado" if d["banco_ok"] else "REPROVADO"),
            ("Commits na semana", len(d["commits"])),
        ]
    )
    pend = "".join(f"<li style='margin:8px 0'>{p}</li>" for p in pendencias(d))
    areas = "".join(
        f"<li>{n} arquivos em <b>{a}</b></li>" for a, n in d["tocados"].most_common()
    )
    return f"""<div style="font-family:system-ui,sans-serif;max-width:600px;color:#222">
<h2 style="margin:0 0 4px">DevLingo</h2>
<p style="margin:0 0 18px;color:#666">Estado em {d['quando']:%d/%m/%Y}</p>
<table style="border-collapse:collapse;margin-bottom:22px">{linhas}</table>
<h3 style="margin:0 0 8px">Na última semana</h3>
<ul style="margin:0 0 22px;padding-left:20px;color:#444">{areas}</ul>
<h3 style="margin:0 0 8px">Esperando você</h3>
<ol style="margin:0 0 22px;padding-left:20px;color:#444">{pend}</ol>
<p style="color:#888;font-size:13px;border-top:1px solid #eee;padding-top:12px">
Todo número acima foi medido na hora, não estimado.</p></div>"""


if __name__ == "__main__":
    dados = coletar()
    print(html(dados) if "--html" in sys.argv else texto(dados))
