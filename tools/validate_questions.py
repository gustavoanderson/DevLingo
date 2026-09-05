#!/usr/bin/env python3
"""
Validador do banco de questoes do DevLingo.

Roda ANTES de qualquer questao entrar no app. Se ele reprovar, o build para.

Uso:
    python3 validate_questions.py content/
    python3 validate_questions.py content/python-beg-01.json

Saida:
    codigo 0  -> banco aprovado
    codigo 1  -> banco reprovado, com a lista de defeitos
"""

import json
import re
import sys
from pathlib import Path

try:
    from jsonschema import Draft7Validator
except ImportError:
    sys.exit("Falta a biblioteca jsonschema. Instale com: pip install jsonschema")

SCHEMA_FILE = Path(__file__).parent / "question.schema.json"

LEVEL_ABBREV = {"beginner": "beg", "intermediate": "int", "advanced": "adv"}
BLANK_MARKER = "______"


class Report:
    """Acumula defeitos e avisos em vez de parar no primeiro erro.

    Parar no primeiro erro obrigaria voce a rodar o validador dezenas de vezes.
    Ver tudo de uma vez e o que torna a correcao viavel.
    """

    def __init__(self):
        self.errors = []
        self.warnings = []

    def error(self, where, message):
        self.errors.append(f"  [ERRO]   {where}: {message}")

    def warn(self, where, message):
        self.warnings.append(f"  [AVISO]  {where}: {message}")


def normalize(text, rules):
    """Aplica as mesmas regras de normalizacao que o app aplicara na resposta."""
    rules = rules or {}
    out = text
    if rules.get("quotes", True):
        out = out.replace('"', "'")
    if rules.get("trailingSemicolon", True):
        out = out.rstrip().rstrip(";")
    if rules.get("spaces", True):
        # Espaco entre duas palavras e obrigatorio: 'const total' nao pode virar
        # 'consttotal'. Espaco encostado em pontuacao ou operador e irrelevante:
        # 'n * 2' e 'n*2' sao a mesma coisa. Entao colapsamos os espaços e so
        # removemos os que tocam um caractere que nao e letra, digito ou sublinhado.
        out = re.sub(r"\s+", " ", out).strip()
        out = re.sub(r"\s*([^\w\s])\s*", r"\1", out)
    else:
        out = out.strip()
    if not rules.get("caseSensitive", False):
        out = out.lower()
    return out


def check_schema(data, filename, validator, report):
    """Regras estruturais: campos obrigatorios, tipos, enums, 5 alternativas."""
    for err in sorted(validator.iter_errors(data), key=lambda e: list(e.path)):
        path = "/".join(str(p) for p in err.path) or "(raiz)"
        report.error(f"{filename} -> {path}", err.message)


def check_lesson_rules(data, filename, report):
    """Regras de coerencia da licao que o esquema formal nao consegue expressar."""
    language = data.get("language")
    level = data.get("level")
    lesson_id = data.get("lessonId", "")
    abbrev = LEVEL_ABBREV.get(level, "")

    expected_prefix = f"{language}-{abbrev}-"
    if not lesson_id.startswith(expected_prefix):
        report.error(
            f"{filename} -> lessonId",
            f"'{lesson_id}' nao combina com language='{language}' e level='{level}'. "
            f"Esperado comecar com '{expected_prefix}'.",
        )

    for question in data.get("questions", []):
        qid = question.get("id", "(sem id)")
        if not qid.startswith(expected_prefix):
            report.error(
                f"{filename} -> {qid}",
                f"o id da questao nao combina com a licao. Esperado comecar com '{expected_prefix}'.",
            )

    # --- vies de gabarito: se a resposta certa cai quase sempre na mesma letra,
    #     o usuario aprende a chutar a posicao em vez de aprender a linguagem ---
    posicoes = []
    for question in data.get("questions", []):
        if question.get("answerType") != "multipleChoice":
            continue
        for option in question.get("options", []):
            if option.get("correct"):
                posicoes.append(option.get("id"))

    if len(posicoes) >= 5:
        for letra in set(posicoes):
            repetidas = posicoes.count(letra)
            if repetidas > len(posicoes) / 2:
                report.error(
                    f"{filename} -> gabaritos",
                    f"{repetidas} de {len(posicoes)} gabaritos caem na alternativa '{letra}'. "
                    f"Redistribua as alternativas.",
                )


def check_question_rules(question, filename, report):
    """Regras de qualidade de uma questao isolada."""
    qid = question.get("id", "(sem id)")
    where = f"{filename} -> {qid}"
    answer_type = question.get("answerType")
    code = question.get("code")

    # --- linha destacada precisa existir de fato ---
    if code and "highlightLine" in code:
        total_lines = len(code["content"].split("\n"))
        if code["highlightLine"] > total_lines:
            report.error(
                where,
                f"highlightLine={code['highlightLine']} mas o bloco tem apenas {total_lines} linha(s).",
            )

    if answer_type == "multipleChoice":
        options = question.get("options", [])

        # --- exatamente uma correta: o defeito classico de banco escrito a mao ---
        corrects = [o for o in options if o.get("correct")]
        if len(corrects) == 0:
            report.error(where, "nenhuma alternativa marcada como correta.")
        elif len(corrects) > 1:
            marked = ", ".join(o["id"] for o in corrects)
            report.error(where, f"{len(corrects)} alternativas marcadas como corretas ({marked}).")

        # --- ids das alternativas unicos ---
        ids = [o.get("id") for o in options]
        if len(set(ids)) != len(ids):
            report.error(where, "ha alternativas com o mesmo id.")

        # --- textos repetidos deixam a questao sem resposta unica ---
        # A comparacao preserva a caixa de proposito. A maioria das linguagens do
        # DevLingo e case-sensitive, entao 'True' e 'true' sao respostas realmente
        # diferentes: uma e o booleano, a outra da NameError. Comparar em minusculas
        # reprovava esse distrator legitimo, e falso positivo em portao de qualidade
        # ensina a contornar o validador em vez de confiar nele.
        texts = [o.get("text", "").strip() for o in options]
        duplicates = {t for t in texts if texts.count(t) > 1}
        if duplicates:
            report.error(where, f"alternativas com texto repetido: {sorted(duplicates)}")

        # --- diferenca apenas na caixa: legitima como distrator, mas tambem e a
        #     cara de uma desatencao do autor. Avisa sem reprovar, e quem escreveu
        #     decide se foi intencional ---
        lowered = [t.lower() for t in texts]
        for chave in sorted({t for t in lowered if lowered.count(t) > 1}):
            variantes = sorted({t for t in texts if t.lower() == chave})
            if len(variantes) > 1:
                report.warn(
                    where,
                    f"alternativas que diferem apenas na caixa: {variantes}. "
                    f"Proposital numa linguagem case-sensitive; confirme que nao foi descuido.",
                )

        # --- a dica nao pode entregar a resposta ---
        hint = question.get("hint", "").lower()
        for correct in corrects:
            answer = correct.get("text", "").strip().lower()
            if len(answer) >= 4 and answer in hint:
                report.error(where, "a dica contem a resposta correta literalmente.")

    elif answer_type in ("fillBlank", "freeWrite"):
        accepted = question.get("accepted", [])
        rules = question.get("normalize")

        # --- respostas que colapsam na mesma coisa apos normalizar sao redundantes ---
        seen = {}
        for answer in accepted:
            key = normalize(answer, rules)
            if key in seen:
                report.warn(
                    where,
                    f"'{answer}' e '{seen[key]}' viram a mesma coisa depois da normalizacao.",
                )
            else:
                seen[key] = answer

        # --- fillBlank sem lacuna no codigo e um enunciado quebrado ---
        if answer_type == "fillBlank":
            if not code:
                report.error(where, "fillBlank sem bloco de codigo: nao ha onde por a lacuna.")
            elif BLANK_MARKER not in code.get("content", ""):
                report.error(
                    where,
                    f"fillBlank sem o marcador de lacuna '{BLANK_MARKER}' no bloco de codigo.",
                )

        # --- a dica nao pode entregar a resposta ---
        hint = normalize(question.get("hint", ""), rules)
        for answer in accepted:
            key = normalize(answer, rules)
            if len(key) >= 4 and key in hint:
                report.error(where, f"a dica contem a resposta '{answer}' literalmente.")


def validate(paths):
    schema = json.loads(SCHEMA_FILE.read_text(encoding="utf-8"))
    validator = Draft7Validator(schema)
    report = Report()

    files = []
    for raw in paths:
        path = Path(raw)
        if path.is_dir():
            # rglob: o conteudo fica em subpastas por linguagem (content/python/, content/javascript/)
            # o proprio esquema mora em tools/ e nao e uma licao
            files.extend(sorted(p for p in path.rglob("*.json") if p.name != SCHEMA_FILE.name))
        else:
            files.append(path)

    if not files:
        sys.exit("Nenhum arquivo .json encontrado nos caminhos informados.")

    seen_ids = {}
    total_questions = 0

    for path in files:
        filename = path.name
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            report.error(filename, f"JSON invalido: {exc}")
            continue

        check_schema(data, filename, validator, report)
        check_lesson_rules(data, filename, report)

        for question in data.get("questions", []):
            total_questions += 1
            qid = question.get("id")

            # --- id duplicado quebraria o progresso salvo do usuario ---
            if qid in seen_ids:
                report.error(filename, f"id '{qid}' ja usado em {seen_ids[qid]}.")
            elif qid:
                seen_ids[qid] = filename

            check_question_rules(question, filename, report)

    print(f"\nArquivos analisados: {len(files)}")
    print(f"Questoes analisadas: {total_questions}")

    if report.warnings:
        print(f"\n{len(report.warnings)} aviso(s):")
        print("\n".join(report.warnings))

    if report.errors:
        print(f"\n{len(report.errors)} defeito(s):")
        print("\n".join(report.errors))
        print("\nBANCO REPROVADO\n")
        return 1

    print("\nBANCO APROVADO\n")
    return 0


if __name__ == "__main__":
    sys.exit(validate(sys.argv[1:] or ["."]))
