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
from collections import defaultdict
from pathlib import Path
from xml.etree import ElementTree

try:
    from jsonschema import Draft7Validator
except ImportError:
    sys.exit("Falta a biblioteca jsonschema. Instale com: pip install jsonschema")

SCHEMA_FILE = Path(__file__).parent / "question.schema.json"

LEVEL_ABBREV = {"beginner": "beg", "intermediate": "int", "advanced": "adv"}
BLANK_MARKER = "______"

# Linha do pubspec que declara uma pasta de linguagem como asset do app.
PUBSPEC_ASSET_RE = re.compile(r"^\s*-\s+assets/content/([A-Za-z0-9_]+)/\s*$")


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


def accepts(resposta, aceitas, rules):
    """Decide se a resposta escrita pelo usuario conta como certa.

    A semantica vive aqui, num lugar so, para o app em Dart ter o que espelhar:
    normaliza os dois lados e procura correspondencia exata em alguma das
    respostas aceitas. Nada de correspondencia parcial, nada de heuristica.
    Determinismo e o ponto: sem falso negativo, sem falso positivo.
    """
    alvo = normalize(resposta, rules)
    return any(normalize(aceita, rules) == alvo for aceita in aceitas)


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

        # --- letra que nunca e resposta e o mesmo vies pelo avesso ---
        # Concentrar demais numa letra e obvio; nunca usar duas letras nao e, e
        # produz o mesmo aprendizado errado: "a certa nunca e a ultima". Com
        # cinco ou mais questoes de multipla escolha, todas as cinco letras
        # cabem, entao exigir todas nao aperta ninguem.
        #
        # Esta regra nasceu de um defeito real: oito licoes escritas a mao
        # cobriam as cinco letras por instinto, e as duas escritas em lote
        # nunca usaram 'd' nem 'e'. Instinto nao escala; regra escala.
        nunca_usadas = sorted(set("abcde") - set(posicoes))
        if nunca_usadas:
            report.error(
                f"{filename} -> gabaritos",
                f"nenhuma questao tem a resposta certa em {nunca_usadas}. "
                f"Com {len(posicoes)} questoes de multipla escolha, as cinco "
                f"letras cabem. Redistribua.",
            )


def find_pubspec(content_dir):
    """Sobe a partir da pasta de conteudo procurando o pubspec.yaml do app."""
    atual = content_dir.resolve()
    for _ in range(4):
        candidato = atual / "pubspec.yaml"
        if candidato.is_file():
            return candidato
        if atual.parent == atual:
            break
        atual = atual.parent
    return None


# Um nome recebendo valor: `x =`, `const x =`, `let x =`. Fica de fora `==`,
# `<=`, `>=` e `!=`, que sao comparacao e nao atribuicao.
ATRIBUICAO_RE = re.compile(r"^\s*(?:const |let |var )?([A-Za-z_]\w*)\s*(?<![=!<>])=(?!=)")
LACO_RE = re.compile(r"\b(for|while)\b")
DEFINE_FUNCAO_RE = re.compile(r"\b(def|function)\b|=>")
# Acumulador: `total += x` ou `total = total + x`. E o sinal de estado que muda
# ao longo das voltas, que e o que separa um laco de exemplo de um laco de
# verdade.
ACUMULADOR_RE = re.compile(r"^\s*([A-Za-z_]\w*)\s*(?:\+=|-=|\*=|=\s*\1\b)")

# Quantos sinais o nivel iniciante tolera. Os numeros vieram de MEDIR o banco,
# nao de opinar: nenhuma das 76 questoes com codigo usa 3 nomes, e apenas 3
# reatribuem algum. Ver "O que separa um nivel do outro" no CLAUDE.md.
TETO_INICIANTE = {"nomes": 2, "reatribuidos": 1}


def sinais_do_codigo(texto):
    """Conta o que aproxima 'passos de raciocinio' num trecho de codigo.

    Deliberadamente grosseiro: le com expressao regular, nao com interpretador.
    Serve para levantar suspeita, nao para julgar -- e por isso o resultado sai
    como aviso.
    """
    linhas = texto.splitlines()
    contagem = {}
    for linha in linhas:
        achou = ATRIBUICAO_RE.match(linha)
        if achou:
            nome = achou.group(1)
            contagem[nome] = contagem.get(nome, 0) + 1

    tem_laco = bool(LACO_RE.search(texto))
    acumula = tem_laco and any(ACUMULADOR_RE.match(l) for l in linhas)

    return {
        "linhas": len(linhas),
        "nomes": len(contagem),
        "reatribuidos": sum(1 for c in contagem.values() if c > 1),
        "laco": tem_laco,
        "acumulador": acumula,
        "funcao": bool(DEFINE_FUNCAO_RE.search(texto)),
    }


def check_nivel_coerente(question, level, filename, report):
    """Avisa quando os sinais do codigo destoam do nivel declarado.

    **Aviso, nunca erro.** A medicao e aproximada e falso positivo e tao grave
    quanto defeito nao pego: uma regra que reprova conteudo legitimo ensina a
    contornar o validador em vez de confiar nele. Isso ja aconteceu duas vezes
    neste projeto, com a regra de alternativas repetidas e com a de impressao
    digital, e nas duas a saida certa foi rebaixar para aviso.

    Numero de LINHAS nao entra aqui. As duas questoes mais longas do iniciante
    tem 9 e 8 linhas e sao `if/elif/else` de varios ramos: um passo de
    raciocinio so. Tamanho mede outra coisa.
    """
    code = question.get("code")
    if not code or not code.get("content"):
        return

    s = sinais_do_codigo(code["content"])
    onde = f"{filename} -> {question.get('id', '?')}"

    if level == "beginner":
        excessos = []
        if s["nomes"] > TETO_INICIANTE["nomes"]:
            excessos.append(f"{s['nomes']} nomes (o banco iniciante nunca passa de {TETO_INICIANTE['nomes']})")
        if s["reatribuidos"] > TETO_INICIANTE["reatribuidos"]:
            excessos.append(f"{s['reatribuidos']} nomes reatribuidos")
        if s["acumulador"]:
            excessos.append("laco com acumulador")
        if excessos:
            report.warn(
                onde,
                "sinais de nivel intermediario numa questao iniciante: "
                + "; ".join(excessos)
                + ". Confira se a questao cobra combinar dois fatos ou rastrear "
                "estado que muda; se cobrar, ela pertence ao intermediario.",
            )
        return

    if level in ("intermediate", "advanced"):
        # O caminho contrario: questao declarada como avancada que nao tem
        # sinal nenhum de composicao pode ser uma iniciante com outro rotulo,
        # que e exatamente o risco que o criterio existe para evitar.
        composta = (
            s["nomes"] > TETO_INICIANTE["nomes"]
            or s["reatribuidos"] > TETO_INICIANTE["reatribuidos"]
            or s["acumulador"]
            or s["funcao"]
        )
        if not composta:
            report.warn(
                onde,
                f"questao de nivel '{level}' sem nenhum sinal de composicao no "
                "codigo. Pode ser legitima -- no avancado o que conta e o "
                "comportamento nao obvio, nao o tamanho -- mas confira se nao "
                "e uma questao iniciante com outro rotulo.",
            )


def check_gerados_em_dia(content_dir, report):
    """Garante que os arquivos de `gerar_faixas.py` batem com o gerador.

    O cenario existe em dois formatos: os SVGs de `assets/cenarios/`, que sao a
    referencia de arte, e `app/lib/ui/cenario_gerado.dart`, que e o que o app
    desenha. Um script escreve os dois, e e isso que impede os dois de contarem
    historias diferentes.

    Mas so impede enquanto alguem lembrar de rodar o script. Editar o Dart a
    mao funciona -- o app compila, os testes passam, e a tela muda -- e a
    divergencia so aparece quando outra pessoa roda o gerador e ve a mudanca
    desaparecer sem explicacao.

    Esta regra fecha isso: ela roda o gerador em memoria e compara com o que
    esta em disco. Nao grava nada; so reprova e diz o comando para corrigir.
    """
    raiz = find_pubspec(content_dir)
    raiz = raiz.parent.parent if raiz is not None else content_dir.resolve().parent

    gerador = raiz / "tools" / "gerar_faixas.py"
    if not gerador.is_file():
        return

    ambiente = {"__file__": str(gerador), "__name__": "gerar_faixas"}
    try:
        exec(compile(gerador.read_text(encoding="utf-8"), str(gerador), "exec"), ambiente)
    except Exception as exc:  # noqa: BLE001 - o motivo vai para o relatorio
        report.error("tools/gerar_faixas.py", f"o gerador nao roda: {exc}")
        return

    esperados = {
        raiz / "app" / "lib" / "ui" / "cenario_gerado.dart": ambiente["gerar_dart"](),
    }
    for nome, cores in ambiente["FAIXAS"].items():
        esperados[raiz / "assets" / "cenarios" / f"faixa-{nome}.svg"] = ambiente[
            "gerar_svg"
        ](nome, cores)

    for caminho, esperado in esperados.items():
        onde = str(caminho.relative_to(raiz)).replace("\\", "/")
        if not caminho.is_file():
            report.error(onde, "arquivo gerado nao existe. Rode: python3 tools/gerar_faixas.py")
            continue
        if caminho.read_text(encoding="utf-8") != esperado:
            report.error(
                onde,
                "arquivo gerado esta diferente do que tools/gerar_faixas.py produz. "
                "Ou alguem editou a mao, ou o gerador mudou e nao foi rodado. "
                "A correcao e sempre a mesma: edite o GERADOR e rode "
                "'python3 tools/gerar_faixas.py'.",
            )


def check_svgs_bem_formados(content_dir, report):
    """Garante que todo SVG do repositorio seja XML bem formado.

    Isto virou regra depois de um defeito real. Um comentario da arte do mascote
    tinha '--' no miolo, o que XML proibe. O `flutter_svg` tolerou e a arte
    apareceu no aparelho; o `expat` do Python reprovou. Ou seja: o arquivo estava
    quebrado e o app nao reclamava.

    Tolerancia de um renderizador nao e contrato. Basta trocar de biblioteca, de
    versao ou de plataforma para o desenho sumir sem ninguem ter mexido nele: o
    tipo de defeito que aparece meses depois e cuja causa ninguem mais lembra.

    A checagem so olha se o XML fecha. Nao tenta julgar o desenho: para isso e
    preciso renderizar e olhar, e foi olhando a captura de tela do emulador que
    os defeitos de arte deste arquivo foram encontrados, um por um.
    """
    raiz = find_pubspec(content_dir)
    raiz = raiz.parent.parent if raiz is not None else content_dir.resolve().parent

    for svg in sorted(raiz.rglob("*.svg")):
        if "build" in svg.parts:  # copias geradas, nao fonte
            continue
        try:
            ElementTree.parse(svg)
        except ElementTree.ParseError as exc:
            report.error(
                str(svg.relative_to(raiz)),
                f"SVG mal formado: {exc}. "
                f"A causa mais comum aqui e '--' dentro de um comentario XML, "
                f"que o flutter_svg aceita e o padrao proibe.",
            )


def check_pubspec_assets(content_dir, report):
    """Garante que toda pasta de linguagem esteja declarada como asset do app.

    O Flutter NAO empacota subpastas recursivamente: declarar 'assets/content/'
    nao inclui 'assets/content/python/'. Cada pasta de linguagem precisa estar
    listada uma a uma no pubspec.

    Sem esta regra, acrescentar uma linguagem e esquecer o pubspec produz um app
    que compila, roda e simplesmente nao tem as questoes dela. Nada quebra, nada
    avisa. E o mesmo tipo de defeito silencioso que motivou mover o conteudo para
    dentro de app/: a saida certa e tornar o erro impossivel, nao pedir disciplina.
    """
    pubspec = find_pubspec(content_dir)
    if pubspec is None:
        return

    declaradas = set()
    for linha in pubspec.read_text(encoding="utf-8").splitlines():
        achou = PUBSPEC_ASSET_RE.match(linha)
        if achou:
            declaradas.add(achou.group(1))

    existentes = {p.name for p in content_dir.iterdir() if p.is_dir()}
    onde = f"{pubspec.name} -> assets"

    for lang in sorted(existentes - declaradas):
        report.error(
            onde,
            f"a pasta '{lang}' existe em {content_dir.name}/ mas nao esta declarada em assets. "
            f"O app rodaria sem as questoes dela e sem aviso nenhum. "
            f"Acrescente '- assets/content/{lang}/' ao pubspec.yaml.",
        )

    for lang in sorted(declaradas - existentes):
        report.error(
            onde,
            f"assets declara 'assets/content/{lang}/' mas essa pasta nao existe em {content_dir.name}/.",
        )


def question_fingerprints(question, language):
    """Chaves que identificam O QUE a questao cobra, nao como ela foi escrita.

    A repeticao que interessa nao esta na roupagem do enunciado: onze questoes do
    banco tem o mesmo prompt ("O que este codigo imprime?") e sao todas legitimas.
    O que se repete numa questao disfarcada e a resposta.

    A chave e assimetrica de proposito:

    - Lacuna e escrita livre usam SO a resposta. O aluno a produz, entao ela e o
      proprio conceito. O topico fica de fora: a mesma resposta cobrada sob outro
      topico continua sendo a mesma questao com outra roupagem. Foi esse o caso
      real que motivou a regra, uma lacuna de resposta '%' em duas licoes seguidas.

    - Multipla escolha leva o topico junto, porque ali a resposta costuma ser o
      valor de saida (True, 3, 5.0) e nao o conceito. Sem o topico, questoes
      legitimamente distintas colidiriam o tempo todo.

    Tudo escopado por linguagem: '3' como resposta em JavaScript e em Python nao
    tem relacao nenhuma.
    """
    answer_type = question.get("answerType")

    if answer_type == "multipleChoice":
        topic = question.get("topic", "")
        return {
            (language, "multipla escolha", topic, normalize(option.get("text", ""), None))
            for option in question.get("options", [])
            if option.get("correct")
        }

    rules = question.get("normalize")
    return {
        (language, "escrita", "", normalize(answer, rules))
        for answer in question.get("accepted", [])
    }


def check_duplicate_fingerprints(fingerprints, report):
    """Avisa quando duas questoes da mesma linguagem cobram a mesma resposta.

    Avisa, nao reprova: duas questoes parecidas as vezes sao reforco proposital
    do mesmo conceito. Quem escreveu e quem decide.
    """
    for chave in sorted(fingerprints, key=str):
        ocorrencias = sorted(set(fingerprints[chave]))
        if len({qid for qid, _ in ocorrencias}) < 2:
            continue

        language, familia, topic, answer = chave
        escopo = f"{familia}, topic={topic}" if topic else familia
        onde = ", ".join(f"{qid} em {arquivo}" for qid, arquivo in ocorrencias)
        report.warn(
            f"{language} -> impressao digital",
            f"{len(ocorrencias)} questoes cobram a mesma resposta '{answer}' ({escopo}): {onde}. "
            f"Confirme que nao e a mesma questao com outra roupagem.",
        )


def check_aula(data, filename, report):
    """A aula precisa cobrir exatamente os topicos que a licao vai cobrar.

    Sem essa regra a aula envelhece em silencio: as questoes mudam, a aula fica,
    e o jogador continua caindo de paraquedas — so que agora achando que foi
    preparado, o que e pior que nao ter aula nenhuma.

    A conferencia e por conjunto, nao por semelhanca de texto, porque cada secao
    declara qual topico prepara. Isso torna a regra exata em vez de heuristica.
    """
    lesson_id = data.get("lessonId", "")
    aula = data.get("aula")

    topicos_das_questoes = {
        q.get("topic") for q in data.get("questions", []) if q.get("topic")
    }

    if aula is None:
        # A licao de referencia do formato nao e jogada por ninguem.
        if not lesson_id.endswith("-00"):
            report.warn(
                f"{filename} -> aula",
                "licao sem aula. O jogador cai direto nas questoes sem ver o "
                "beaba que elas exigem.",
            )
        return

    topicos_da_aula = {
        s.get("topico") for s in aula.get("secoes", []) if s.get("topico")
    }

    for topico in sorted(topicos_das_questoes - topicos_da_aula):
        report.error(
            f"{filename} -> aula",
            f"o topico '{topico}' e cobrado nas questoes mas nao e preparado na "
            f"aula. Acrescente uma secao com \"topico\": \"{topico}\".",
        )

    for topico in sorted(topicos_da_aula - topicos_das_questoes):
        report.error(
            f"{filename} -> aula",
            f"a aula prepara o topico '{topico}', que nenhuma questao da licao "
            f"cobra. Ou a secao sobra, ou esta faltando questao.",
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

        # --- 'why' e opcional, mas nao pode ficar pela metade ---
        # O campo aparece quando o aluno escolhe aquela alternativa. Se so
        # algumas tiverem, o aluno recebe explicacao numa tentativa e silencio
        # na seguinte, sem entender por que. Ou a questao inteira tem, ou
        # nenhuma tem e o app cai na linha neutra.
        erradas = [o for o in options if not o.get("correct")]
        com_why = [o for o in erradas if o.get("why")]
        if com_why and len(com_why) != len(erradas):
            faltando = sorted(o["id"] for o in erradas if not o.get("why"))
            report.error(
                where,
                f"{len(com_why)} de {len(erradas)} alternativas erradas tem 'why'. "
                f"Ou todas tem, ou nenhuma tem. Faltam: {faltando}.",
            )

        for correct in corrects:
            if correct.get("why"):
                report.error(
                    where,
                    f"a alternativa correta '{correct['id']}' tem 'why'. Esse campo "
                    f"explica por que uma alternativa esta ERRADA; o papel da certa "
                    f"cabe a explanation.",
                )

        # --- 'why' nao pode entregar qual e a certa ---
        # Se entregasse, a eliminacao progressiva perderia o sentido: bastaria
        # errar uma vez para saber a resposta.
        for errada in erradas:
            texto_why = (errada.get("why") or "").lower()
            if not texto_why:
                continue
            for correct in corrects:
                answer = correct.get("text", "").strip().lower()
                if len(answer) >= 4 and answer in texto_why:
                    report.error(
                        where,
                        f"o 'why' da alternativa '{errada['id']}' contem a resposta "
                        f"correta literalmente, e entregaria o jogo na primeira "
                        f"tentativa errada.",
                    )

    elif answer_type in ("fillBlank", "freeWrite"):
        accepted = question.get("accepted", [])
        rules = question.get("normalize")

        # --- so ASCII no que o aluno precisa DIGITAR ---
        # Dois motivos, e os dois importam.
        #
        # Tecnico: com acento decomposto (letra + acento combinante) o acento
        # nao e letra em Python nem em Dart, conta como pontuacao, e o espaco
        # encostado nele some. As duas implementacoes concordam, entao o
        # contrato de normalizacao continua cumprido, mas o resultado difere do
        # mesmo texto escrito precomposto. Isso e falso negativo: a resposta
        # certa recusada. Corrigir exigiria normalizacao Unicode nos dois lados,
        # e no Dart isso significa dependencia nova para um risco que no Android
        # e quase teorico.
        #
        # Pedagogico, e este pesa mais: digitar acento em teclado de celular e
        # toque longo. O aluno erraria por causa do teclado, nao por causa da
        # linguagem. Dificuldade incidental nao ensina nada.
        #
        # A restricao vale apenas para o que se DIGITA. Acento continua livre em
        # prompt, hint, explanation e nas alternativas de multipla escolha, que
        # e tudo que o aluno LE.
        for answer in accepted:
            fora = sorted({c for c in answer if ord(c) > 127})
            if fora:
                nomes = ", ".join(f"{c!r} (U+{ord(c):04X})" for c in fora)
                report.error(
                    where,
                    f"a resposta {answer!r} tem caractere fora do ASCII: {nomes}. "
                    f"O aluno digita essa resposta, e acento em teclado de celular "
                    f"e toque longo. Reescreva sem acento; o texto acentuado pode "
                    f"ficar no enunciado e na explicacao.",
                )

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
            # rglob: o conteudo fica em subpastas por linguagem
            # (app/assets/content/python/, app/assets/content/javascript/)
            # o proprio esquema mora em tools/ e nao e uma licao
            files.extend(sorted(p for p in path.rglob("*.json") if p.name != SCHEMA_FILE.name))
            if path.name == "content":
                check_pubspec_assets(path, report)
                check_svgs_bem_formados(path, report)
                check_gerados_em_dia(path, report)
        else:
            files.append(path)

    if not files:
        sys.exit("Nenhum arquivo .json encontrado nos caminhos informados.")

    seen_ids = {}
    # impressao digital acumula entre arquivos: questoes repetidas costumam estar
    # em licoes diferentes, entao a comparacao so faz sentido no banco inteiro
    fingerprints = defaultdict(list)
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
        check_aula(data, filename, report)

        for question in data.get("questions", []):
            total_questions += 1
            qid = question.get("id")

            # --- id duplicado quebraria o progresso salvo do usuario ---
            if qid in seen_ids:
                report.error(filename, f"id '{qid}' ja usado em {seen_ids[qid]}.")
            elif qid:
                seen_ids[qid] = filename

            check_question_rules(question, filename, report)
            check_nivel_coerente(question, data.get("level", ""), filename, report)

            if qid:
                for chave in question_fingerprints(question, data.get("language", "")):
                    fingerprints[chave].append((qid, filename))

    check_duplicate_fingerprints(fingerprints, report)

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
