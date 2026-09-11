#!/usr/bin/env python3
"""Testes das ferramentas do servidor MCP.

Rodam contra o banco REAL, e nao contra dados de mentira. E deliberado: o que
estas ferramentas fazem e responder perguntas sobre o banco, entao um teste com
banco falso provaria que a funcao roda, nao que ela responde certo.

O preco e que alguns testes dependem de conteudo que existe hoje -- por isso
cada um deles confere o pressuposto ANTES de afirmar o resultado, e falha
dizendo "o banco mudou" em vez de "a ferramenta quebrou". Teste que mente sobre
a causa custa mais caro que teste que falta.

    python3 mcp/test_ferramentas.py
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import ferramentas as f  # noqa: E402

RAIZ = Path(__file__).resolve().parent.parent
LICAO_REAL = RAIZ / "app" / "assets" / "content" / "java" / "java-beg-01.json"

falhas: list[str] = []
feitos = 0


def conferir(nome, condicao, detalhe=""):
    global feitos
    feitos += 1
    if not condicao:
        falhas.append(f"  {nome}\n      {detalhe}")


# --------------------------------------------------------------- teclado ----
# A regra que isto espelha e pedagogica antes de ser tecnica: digitar acento em
# teclado de celular e toque longo, e o aluno erraria por causa do teclado.
conferir(
    "conferir_teclado aceita ASCII puro",
    f.conferir_teclado("equals")["digitavel"],
    "'equals' e ASCII e foi recusado",
)
conferir(
    "conferir_teclado recusa acento",
    not f.conferir_teclado("satisfação")["digitavel"],
    "'satisfação' tem cedilha e til, e passou",
)
conferir(
    "conferir_teclado NOMEIA os caracteres que barram",
    f.conferir_teclado("satisfação").get("caracteres") == ["ã", "ç"],
    "o agente precisa saber QUAIS caracteres trocar, nao so que falhou: "
    f"veio {f.conferir_teclado('satisfação').get('caracteres')}",
)

# ----------------------------------------------------- impressao digital ----
# O caso real que motivou esta ferramenta, discutido em 10 de setembro: o
# agente nao tem como saber que `equals` ja e cobrada. Ele precisa perguntar.
_equals = f.impressao_digital("equals", "java")
conferir(
    "impressao_digital acha uma resposta que existe",
    _equals["ja_cobrada"],
    "'equals' e cobrada em java-beg-0302 e nao foi encontrada (o banco mudou?)",
)
conferir(
    "impressao_digital diz ONDE, e nao so que existe",
    _equals["ja_cobrada"]
    and any(o["questao"] == "java-beg-0302" for o in _equals["ocorrencias"]),
    "erro que nao instrui obriga o agente a adivinhar: "
    f"veio {_equals.get('ocorrencias')}",
)
conferir(
    "impressao_digital nao acha o que nao existe",
    not f.impressao_digital("naoExisteEssaRespostaAqui", "java")["ja_cobrada"],
    "resposta inventada foi dada como ja cobrada",
)
conferir(
    "impressao_digital e escopada por trilha",
    not f.impressao_digital("equals", "python")["ja_cobrada"],
    "'equals' e de Java e apareceu em Python: a chave perdeu o escopo",
)

# O FALSO POSITIVO que a primeira versao tinha, e que so apareceu porque eu
# sondei. A chave da impressao digital e `(linguagem, familia, topico,
# resposta)`, e a comparacao varria a tupla INTEIRA -- entao o nome da trilha,
# da familia e do topico casavam como se fossem respostas.
#
# Falso positivo numa ferramenta de agente e pior que numa de gente: ele
# obedece sem desconfiar, e sairia trocando uma resposta que estava certa.
for termo, porque in [
    ("java", "e o nome da LINGUAGEM, posicao 0 da chave"),
    ("escrita", "e o nome da FAMILIA, posicao 1 da chave"),
    ("igualdade", "e um TOPICO, posicao 2 da chave"),
]:
    conferir(
        f"impressao_digital nao casa com '{termo}'",
        not f.impressao_digital(termo, "java")["ja_cobrada"],
        f"{porque} -- so a posicao 3, a resposta, pode casar",
    )

# ------------------------------------------------------------- topicos ------
_java = f.topicos_da_trilha("java")
conferir("topicos_da_trilha acha uma trilha real", _java["existe"], "'java' sumiu")
conferir(
    "topicos_da_trilha conta as licoes",
    _java.get("licoes") == 5,
    f"java tem 5 licoes, veio {_java.get('licoes')}",
)
conferir(
    "topicos_da_trilha conta as questoes",
    _java.get("questoes") == 50,
    f"java tem 50 questoes, veio {_java.get('questoes')}",
)
_nada = f.topicos_da_trilha("delphi")
conferir(
    "trilha inexistente NAO e erro, e uma resposta util",
    not _nada["existe"] and "agentes" in _nada.get("proximo_passo", ""),
    "a resposta precisa listar as trilhas que existem, senao o agente "
    "tenta de novo as cegas",
)

# --------------------------------------------------------- validar licao ----
_boa = json.loads(LICAO_REAL.read_text(encoding="utf-8"))
conferir(
    "validar_licao aprova uma licao que ja esta no banco",
    f.validar_licao(_boa)["aprovada"],
    "uma licao publicada foi reprovada: a ferramenta diverge do validador",
)

# Cada defeito e introduzido SOZINHO. Juntos, um so bastaria para reprovar, e o
# teste passaria sem provar que os outros dois sao vistos.
_dica_curta = json.loads(json.dumps(_boa))
_dica_curta["questions"][0]["hint"] = "x"
conferir(
    "validar_licao reprova dica curta demais",
    not f.validar_licao(_dica_curta)["aprovada"],
    "dica de um caractere passou",
)

_sem_gabarito = json.loads(json.dumps(_boa))
for _q in _sem_gabarito["questions"]:
    if _q.get("answerType") == "multipleChoice":
        for _o in _q["options"]:
            _o["correct"] = False
        break
conferir(
    "validar_licao reprova questao sem gabarito",
    not f.validar_licao(_sem_gabarito)["aprovada"],
    "questao sem nenhuma alternativa correta passou",
)

_id_errado = json.loads(json.dumps(_boa))
_id_errado["questions"][0]["id"] = "python-beg-9999"
conferir(
    "validar_licao reprova id que nao bate com a trilha",
    not f.validar_licao(_id_errado)["aprovada"],
    "id de outra linguagem passou",
)

conferir(
    "validar_licao nao quebra com entrada de tipo errado",
    not f.validar_licao("isto nao e um objeto")["aprovada"],
    "uma string derrubou a ferramenta em vez de virar erro que instrui",
)
conferir(
    "o erro de tipo INSTRUI",
    "objeto JSON" in " ".join(f.validar_licao([])["erros"]),
    "a mensagem precisa dizer o que enviar, nao so que falhou",
)

# ------------------------------------------------------------------ fim -----
print(f"\nConferencias: {feitos}")
if falhas:
    print(f"\n{len(falhas)} falharam:\n")
    print("\n\n".join(falhas))
    print("\nFERRAMENTAS DO MCP REPROVADAS\n")
    sys.exit(1)
print("\nFERRAMENTAS DO MCP APROVADAS\n")
