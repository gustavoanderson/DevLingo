"""Dispara a faixa do tutor contra o Worker no ar.

Dois dossies de proposito: um aluno ADIANTADO e um que nao comecou. O segundo
e o caso que mais erra -- o modelo tende a inventar progresso quando nao ha.

E um dossie VAZIO, que e o do site publico: ali a placa tem que cair no caminho
normal e recitar a propria ficha, que manda entrar na conta.
"""
import json
import urllib.request

URL = "https://tronikat.tronikat-busca.workers.dev/perguntar"

ADIANTADO = (
    "trilha Python iniciante: 38 de 50 questoes respondidas\n"
    "licoes concluidas: 01 Primeiros passos, 02 Numeros e contas, "
    "03 Decidir com condicionais\n"
    "acertos de primeira: 24\n"
    "trilha JavaScript iniciante: 12 de 50 questoes respondidas\n"
    "topico mais custoso: fatiamento de strings"
)

ZERADO = (
    "trilha Python iniciante: 0 de 50 questoes respondidas\n"
    "licoes concluidas: nenhuma\n"
    "acertos de primeira: 0"
)

CASOS = [
    ("como estou indo?", ADIANTADO),
    ("me da um desafio", ADIANTADO),
    ("que projeto eu posso fazer?", ADIANTADO),
    ("o que eu faco agora?", ZERADO),
    ("me sugere um exercicio", ZERADO),
    ("como esta meu progresso?", ""),
]


def perguntar(pergunta, dossie):
    corpo = {"pergunta": pergunta}
    if dossie:
        corpo["progresso"] = dossie
    req = urllib.request.Request(
        URL,
        data=json.dumps(corpo).encode(),
        # Sem User-Agent proprio a Cloudflare devolve 403 -- ja registrado no
        # CLAUDE.md, e ja me pegou uma vez.
        headers={"Content-Type": "application/json",
                 "User-Agent": "DevLingo-teste/1.0",
                 "Origin": "https://gustavoanderson.github.io"},
    )
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read())


for pergunta, dossie in CASOS:
    d = perguntar(pergunta, dossie)
    rotulo = "vazio" if not dossie else ("zerado" if dossie is ZERADO else "adiantado")
    print(f"\n[{rotulo}] {pergunta}")
    print(f"  ficha={d.get('ficha')}  origem={d.get('caminho')}")
    if d.get("motivos"):
        print(f"  MOTIVOS: {d['motivos']}")
    print(f"  {d.get('texto', '')[:220]}")
