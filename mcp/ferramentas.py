"""As capacidades que o servidor MCP oferece.

Este arquivo NAO sabe o que e MCP. Ele expoe funcoes puras, e `servidor.py`
as embrulha no protocolo -- a mesma separacao que faz `sessao_questao.dart`
viver fora do widget: da para testar sem subir servidor nenhum.

## Por que nenhuma delas escreve

Todas sao SOMENTE LEITURA, e isso e desenho, nao descuido. A regra que o
proprio curso de Agentes ensina na licao 05: *um limite so vale quando nao
depende do modelo julgar bem*. Com `validar_licao` exposta e `publicar_licao`
NAO exposta, publicar e impossivel para o agente -- nao importa o que ele
decida, nem o que tenha lido num texto que processou.

## Por que reusam o validador em vez de reimplementar

`tools/validate_questions.py` e a autoridade sobre o que e uma licao valida, e
duas implementacoes da mesma regra divergem em silencio. O CLAUDE.md ja
registra esse custo duas vezes: `normalize()` em Python e Dart precisou de um
arquivo de casos compartilhado, e a geometria dos cenarios precisou sair de um
gerador so.

Aqui a regra e mais simples de cumprir: **importar**. Se o validador ganhar uma
regra amanha, o agente passa a ve-la no mesmo dia, sem ninguem lembrar.
"""

from __future__ import annotations

import json
import sys
from collections import defaultdict
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
CONTEUDO = RAIZ / "app" / "assets" / "content"

# O validador mora em tools/ e nao e um pacote instalavel.
sys.path.insert(0, str(RAIZ / "tools"))

import validate_questions as vq  # noqa: E402

import criterios  # noqa: E402


def _relatorio_para_dict(report) -> dict:
    """Traduz o `Report` do validador para algo que o agente consiga usar.

    O `Report` guarda strings ja formatadas para terminal. Devolver a string
    crua funcionaria, e seria pior: a licao 02 do curso diz que **erro de
    ferramenta precisa INSTRUIR**, e para instruir ele precisa dizer se a falha
    e definitiva e o que fazer agora.
    """
    return {
        "aprovada": not report.errors,
        "erros": [e.split(": ", 1)[-1].strip() for e in report.errors],
        "avisos": [a.split(": ", 1)[-1].strip() for a in report.warnings],
    }


def validar_licao(licao: dict) -> dict:
    """Roda as regras do validador contra uma licao em memoria.

    Nao toca o disco e nao grava nada: e a mesma checagem que reprova no CI,
    disponivel ANTES de o conteudo existir como arquivo.

    A impressao digital fica de fora daqui de proposito -- ela compara contra o
    banco inteiro, e tem ferramenta propria. Misturar as duas produziria um
    resultado que o agente nao sabe como corrigir: "reprovada" sem dizer se o
    problema esta na licao ou na relacao dela com o resto.
    """
    if not isinstance(licao, dict):
        return {
            "aprovada": False,
            "erros": [
                "a licao precisa ser um objeto JSON, e veio "
                f"{type(licao).__name__}. Envie o conteudo do arquivo, nao o "
                "caminho dele."
            ],
            "avisos": [],
        }

    esquema = json.loads(vq.SCHEMA_FILE.read_text(encoding="utf-8"))
    validador = vq.Draft7Validator(esquema)
    report = vq.Report()
    onde = licao.get("lessonId", "(licao sem lessonId)")

    vq.check_schema(licao, onde, validador, report)
    vq.check_lesson_rules(licao, onde, report)
    vq.check_aula(licao, onde, report)
    vq.check_marcadores(licao, onde, report)

    nivel = licao.get("level", "")
    for questao in licao.get("questions", []):
        vq.check_question_rules(questao, onde, report)
        vq.check_nivel_coerente(questao, nivel, onde, report)

    resultado = _relatorio_para_dict(report)
    resultado["questoes"] = len(licao.get("questions", []))
    if resultado["aprovada"]:
        resultado["proximo_passo"] = (
            "Estrutura aprovada. Confira as respostas com impressao_digital "
            "antes de considerar a licao pronta."
        )
    else:
        resultado["proximo_passo"] = (
            "Corrija os erros acima e valide de novo. Eles sao definitivos: "
            "repetir a mesma licao dara o mesmo resultado."
        )
    return resultado


def _carregar_banco() -> list[tuple[str, dict]]:
    """Le o banco do disco. Nome do arquivo junto, porque o erro precisa dizer
    ONDE a resposta ja e cobrada -- "ja existe" sem endereco nao instrui."""
    if not CONTEUDO.is_dir():
        return []
    return [
        (p.name, json.loads(p.read_text(encoding="utf-8")))
        for p in sorted(CONTEUDO.rglob("*.json"))
    ]


def impressao_digital(resposta: str, trilha: str) -> dict:
    """Diz se uma resposta ja e cobrada naquela trilha, e por qual questao.

    Esta e a ferramenta que a conversa de 10 de setembro revelou ser
    necessaria. Ao registrar a ideia das 10 questoes de treino, eu afirmei que
    ela "colidia em cheio" com a regra de impressao digital; o Gustavo
    contestou, e medir mostrou que a colisao e CONDICIONAL -- depende de o
    espaco de respostas do topico ser pequeno.

    O que a medicao mudou nao foi o veredito sobre a funcionalidade: foi
    descobrir que **o agente nao tem como saber sozinho**. Ele precisa
    perguntar, e perguntar exige uma ferramenta. Esta.

    A comparacao usa a MESMA normalizacao do validador, e olha so a posicao da
    resposta na chave.

    A primeira versao comparava o alvo contra qualquer posicao da tupla, e a
    chave e `(linguagem, familia, topico, resposta)` -- entao
    `impressao_digital("java", "java")` respondia que "java" ja era cobrada,
    casando com o campo da LINGUAGEM. Falso positivo numa ferramenta de agente
    e pior que numa de gente: ele obedece sem desconfiar, e sairia procurando
    outra resposta para um problema que nao existe.
    """
    alvo = (resposta or "").strip()
    if not alvo:
        return {
            "ja_cobrada": False,
            "erro": "resposta vazia. Envie o texto que o aluno digitaria.",
        }

    # Sem as regras da questao que se pretende escrever, usa o padrao. E uma
    # aproximacao, e ela erra para o lado seguro: normalizar demais so pode
    # gerar alerta a mais, nunca deixar passar repeticao.
    procurado = vq.normalize(alvo, None)

    achados = []
    for arquivo, dados in _carregar_banco():
        if dados.get("language") != trilha:
            continue
        for questao in dados.get("questions", []):
            for _lingua, familia, topico, resposta_da_chave in vq.question_fingerprints(
                questao, trilha
            ):
                if resposta_da_chave != procurado:
                    continue
                achados.append(
                    {
                        "questao": questao.get("id"),
                        "arquivo": arquivo,
                        "topico": topico or questao.get("topic"),
                        "familia": familia,
                    }
                )

    if achados:
        onde = ", ".join(f"{a['questao']} (topico '{a['topico']}')" for a in achados)
        return {
            "ja_cobrada": True,
            "ocorrencias": achados,
            "proximo_passo": (
                f"A resposta '{alvo}' ja e cobrada em {onde}. Escolha outra "
                f"resposta: repetir seria a mesma questao com outra roupagem, "
                f"e o validador reprova."
            ),
        }
    return {
        "ja_cobrada": False,
        "proximo_passo": f"A resposta '{alvo}' ainda nao e cobrada na trilha '{trilha}'.",
    }


def conferir_teclado(resposta: str) -> dict:
    """Diz se a resposta e digitavel num teclado de celular brasileiro.

    O validador reprova caractere nao-ASCII em `accepted`, e o motivo que pesa
    mais e pedagogico: digitar acento em teclado de celular e toque longo, e o
    aluno erraria por causa do teclado, nao por causa da linguagem.
    Dificuldade incidental nao ensina nada.

    Existe separada de `validar_licao` porque o agente precisa dela ANTES de
    escrever a questao inteira -- descobrir que a resposta nao serve depois de
    montar cinco alternativas e retrabalho evitavel.
    """
    texto = resposta or ""
    fora = sorted({c for c in texto if ord(c) > 126})
    if not fora:
        return {
            "digitavel": True,
            "proximo_passo": f"'{texto}' e ASCII puro e serve como resposta.",
        }
    return {
        "digitavel": False,
        "caracteres": fora,
        "proximo_passo": (
            f"Os caracteres {fora} exigem toque longo no teclado do celular. "
            f"Escolha uma resposta sem acento -- ou reescreva a questao para "
            f"pedir um termo em ingles, sigla, ou palavra sem acento. A "
            f"restricao vale so para o que o aluno DIGITA: enunciado, dica e "
            f"explicacao continuam com acento normal."
        ),
    }


def criterios_de_revisao() -> dict:
    """Os criterios do que o validador NAO consegue julgar.

    Existe como ferramenta, e nao como texto no prompt do agente, por duas
    razoes. A primeira e a de sempre: o agente que roda na nuvem nao alcanca
    este repositorio, e um criterio copiado para o prompt dele diverge no dia
    em que alguem acrescentar o nono.

    A segunda e mais interessante: **criterio escrito e o que faz julgamento
    repetir**. Sem ele, duas revisoes da mesma licao dao resultados diferentes
    e nenhuma das duas serve para comparar versoes.
    """
    return {
        "criterios": criterios.CRITERIOS,
        "proximo_passo": (
            "Julgue uma licao por vez, criterio por criterio, e cite o texto "
            "exato que motivou cada apontamento. Apontamento sem citacao nao "
            "da para conferir nem para corrigir."
        ),
    }


def material_para_revisao(licao_id: str) -> dict:
    """Devolve o texto de uma licao organizado para ser julgado.

    Nao e o JSON cru de proposito. O que se revisa aqui sao os textos, e cada
    questao junta o que precisa ser lido EM CONJUNTO: a dica so pode ser
    julgada contra o enunciado e a resposta, e o `why` de um distrator so pode
    ser julgado sabendo qual e a alternativa correta.

    Entregar o arquivo cru obrigaria o agente a remontar isso toda vez -- e
    remontar toda vez e onde ele esquece um campo.
    """
    for arquivo, dados in _carregar_banco():
        if dados.get("lessonId") != licao_id:
            continue

        aula = dados.get("aula") or {}
        questoes = []
        for q in dados.get("questions", []):
            correta = next(
                (o for o in q.get("options", []) if o.get("correct")), None
            )
            questoes.append(
                {
                    "id": q.get("id"),
                    "topico": q.get("topic"),
                    "tipo": q.get("answerType"),
                    "enunciado": q.get("prompt"),
                    "codigo": (q.get("code") or {}).get("content"),
                    "resposta": (
                        correta.get("text") if correta else q.get("accepted")
                    ),
                    "dica": q.get("hint"),
                    "explicacao": q.get("explanation"),
                    "distratores": [
                        {"texto": o.get("text"), "why": o.get("why")}
                        for o in q.get("options", [])
                        if not o.get("correct")
                    ],
                }
            )

        return {
            "existe": True,
            "arquivo": arquivo,
            "trilha": dados.get("language"),
            "titulo": dados.get("lessonTitle"),
            "aula": [
                {
                    "topico": s.get("topico"),
                    "titulo": s.get("titulo"),
                    "texto": s.get("texto"),
                }
                for s in aula.get("secoes", [])
            ],
            "questoes": questoes,
        }

    disponiveis = sorted(
        d.get("lessonId") for _, d in _carregar_banco() if d.get("lessonId")
    )
    return {
        "existe": False,
        "proximo_passo": (
            f"A licao '{licao_id}' nao existe. Use topicos_da_trilha para ver "
            f"as trilhas, ou escolha entre: {', '.join(disponiveis[:12])}..."
        ),
    }


def topicos_da_trilha(trilha: str) -> dict:
    """Lista os topicos de uma trilha, com quantas questoes cada um tem.

    Serve a duas perguntas que o agente faz o tempo todo: "este topico ja
    existe?" e "onde ha pouca cobertura?". Sem isso ele inventa nome de topico
    novo para algo que ja tem um -- e a aula deixaria de bater com as questoes,
    que e o que `check_aula` reprova.
    """
    contagem = defaultdict(list)
    licoes = set()
    for arquivo, dados in _carregar_banco():
        if dados.get("language") != trilha:
            continue
        licoes.add(dados.get("lessonId"))
        for questao in dados.get("questions", []):
            contagem[questao.get("topic")].append(questao.get("id"))

    if not contagem:
        existentes = sorted(
            {d.get("language") for _, d in _carregar_banco() if d.get("language")}
        )
        return {
            "existe": False,
            "proximo_passo": (
                f"A trilha '{trilha}' nao existe no banco. As que existem sao: "
                f"{', '.join(existentes)}."
            ),
        }

    return {
        "existe": True,
        "licoes": len(licoes),
        "questoes": sum(len(v) for v in contagem.values()),
        "topicos": [
            {"topico": t, "questoes": len(ids)}
            for t, ids in sorted(contagem.items(), key=lambda kv: -len(kv[1]))
        ],
    }
