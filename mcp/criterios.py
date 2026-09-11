"""Os criterios de revisao: o que o validador NAO consegue julgar.

## Por que este arquivo existe

As 10 regras de `tools/validate_questions.py` checam **estrutura**. Nenhuma
checa **verdade**, e nenhuma checa se a questao ensina.

Uma licao perfeitamente formada -- 5 alternativas, gabaritos distribuidos, aula
sincronizada com os topicos, marcacao balanceada, resposta digitavel -- dizendo
que *"em Python o ponto e virgula e obrigatorio"* **passa nas dez**.

A licao 05 do curso de Agentes separa as duas familias:

    verificavel ....... a licao passa no validador?   -> um programa responde
    NAO verificavel ... a explicacao ensina?          -> alguem julga

Este arquivo e a segunda familia escrita. Ela so vira avaliacao util se os
criterios estiverem **escritos** -- julgamento sem criterio escrito nao repete,
e o que nao repete nao serve para comparar duas versoes da mesma licao.

## Por que eles sao perguntas, e nao adjetivos

"A explicacao deve ser boa" nao e criterio: nao da para discordar dele, e
qualquer texto passa. "A explicacao acrescenta algo que o enunciado ja nao
dizia?" e uma pergunta com resposta, e duas pessoas podem chegar a vereditos
diferentes e discutir o porque.

Cada criterio traz o que REPROVA, com exemplo. Sem isso a fronteira fica no
gosto de quem revisa, e a revisao vira loteria.
"""

from __future__ import annotations

CRITERIOS = [
    {
        "id": "verdade",
        "campo": "todos",
        "pergunta": "O que a questão afirma é verdade?",
        "peso": "bloqueante",
        "reprova": (
            "Qualquer afirmação tecnicamente errada sobre a linguagem, a "
            "ferramenta ou o conceito. Inclui o caso sutil: afirmação que era "
            "verdadeira numa versão antiga e deixou de ser."
        ),
        "exemplo_ruim": "Em Python o ponto e vírgula é obrigatório ao fim da linha.",
        "por_que_importa": (
            "É o único critério que nenhuma das 10 regras do validador toca, e "
            "é o mais grave: uma questão estruturalmente perfeita ensinando "
            "errado é pior que nenhuma questão, porque o aluno confia nela."
        ),
    },
    {
        "id": "dica_entrega",
        "campo": "hint",
        "pergunta": "A dica ajuda quem travou SEM entregar a resposta?",
        "peso": "alto",
        "reprova": (
            "Dica que contém a resposta literal, ou que a torna dedutível por "
            "eliminação imediata. Também reprova o contrário: dica que apenas "
            "repete o enunciado com outras palavras e não ajuda em nada."
        ),
        "exemplo_ruim": (
            "Enunciado: 'Qual método compara o conteúdo de duas Strings?' — "
            "Dica: 'Use o método equals.'"
        ),
        "por_que_importa": (
            "A dica é o degrau entre travar e desistir. Se ela entrega, o "
            "exercício vira leitura; se não ajuda, ela é enfeite que ocupa "
            "espaço e ensina o aluno a não pedir ajuda."
        ),
    },
    {
        "id": "explicacao_ensina",
        "campo": "explanation",
        "pergunta": "A explicação acrescenta algo que o enunciado já não dizia?",
        "peso": "alto",
        "reprova": (
            "Explicação que só reafirma a resposta correta sem dizer POR QUE, "
            "ou que parafraseia o enunciado. Uma explicação que poderia ser "
            "colada em qualquer questão do mesmo tópico também reprova."
        ),
        "exemplo_ruim": (
            "Resposta: 'equals'. Explicação: 'A resposta certa é equals, "
            "porque equals é o método que compara Strings.'"
        ),
        "por_que_importa": (
            "O CLAUDE.md diz que a explicação é onde o aprendizado acontece, e "
            "ela é o texto mais longo da tela. É o pagamento do exercício: o "
            "aluno errou, gastou tentativas, e o que ele leva é isto."
        ),
    },
    {
        "id": "why_entrega",
        "campo": "options[].why",
        "pergunta": "O 'why' de uma alternativa errada entrega o gabarito?",
        "peso": "alto",
        "reprova": (
            "Texto de alternativa errada que nomeia a resposta correta, ou que "
            "a descreve de forma inconfundível. O aluno vê esse texto na "
            "PRIMEIRA tentativa errada, e a partir dali as outras quatro "
            "deixam de ser escolha."
        ),
        "exemplo_ruim": (
            "why de uma alternativa errada: 'Na verdade quem faz isso é o "
            "equals.' — entrega a resposta no primeiro erro."
        ),
        "por_que_importa": (
            "Já aconteceu de verdade neste banco, num curso de backend, e o "
            "validador não pega: ele confere se o `why` existe, não o que ele "
            "diz."
        ),
    },
    {
        "id": "tom_nao_pune",
        "campo": "todos",
        "pergunta": "Algum texto pune, ridiculariza ou cobra o aluno?",
        "peso": "alto",
        "reprova": (
            "Qualquer 'você deveria saber', 'isso é básico', 'óbvio', ou tom "
            "que trate o erro como falha de caráter. Também reprova a variante "
            "sutil: comparação com outros alunos, ou sugestão de pressa."
        ),
        "exemplo_ruim": "Se você errou isso, revise o básico antes de continuar.",
        "por_que_importa": (
            "O princípio que ordena o app inteiro é 'o objetivo é a pessoa "
            "aprender, não ser punida'. Ele já virou restrição de código em "
            "cinco lugares; texto que pune faz a regra virar mentira."
        ),
    },
    {
        "id": "enunciado_univoco",
        "campo": "prompt",
        "pergunta": "O enunciado admite mais de uma leitura razoável?",
        "peso": "medio",
        "reprova": (
            "Pergunta que não delimita o escopo da resposta, ou onde duas "
            "alternativas ficam defensáveis sob leituras diferentes. Em "
            "questão de escrita, enunciado que não deixa claro ONDE a resposta "
            "termina."
        ),
        "exemplo_ruim": (
            "'Escreva o if que testa o saldo' — a pessoa não sabe se escreve "
            "só a primeira linha ou o bloco inteiro."
        ),
        "por_que_importa": (
            "Foi um defeito real encontrado pelo Gustavo jogando: ele escreveu "
            "o bloco inteiro, o código estava CERTO, e o app marcou errado. "
            "Gerou o molde da resposta — mas o molde só aparece em 22 das 65 "
            "questões de escrita, então o enunciado continua responsável."
        ),
    },
    {
        "id": "distrator_plausivel",
        "campo": "options[].text",
        "pergunta": "As alternativas erradas são erros que alguém cometeria?",
        "peso": "medio",
        "reprova": (
            "Alternativa absurda, que ninguém marcaria — ela não elimina "
            "nada e reduz a questão a menos opções do que parece. Também "
            "reprova o extremo oposto: alternativa tão correta quanto a certa."
        ),
        "exemplo_ruim": (
            "Numa questão sobre comparar Strings, uma alternativa dizendo "
            "'ligar o computador na tomada'."
        ),
        "por_que_importa": (
            "A mecânica de eliminação depende disso: errar risca a "
            "alternativa, e o raciocínio por exclusão é parte do aprendizado. "
            "Distrator vazio transforma cinco opções em três."
        ),
    },
    {
        "id": "definicao_servida",
        "campo": "prompt",
        "pergunta": (
            "Uma questão anterior da mesma lição já exibiu o par "
            "(nome, definição) que esta aqui pede?"
        ),
        "peso": "medio",
        "reprova": (
            "Questão de escrita cujo enunciado repete, quase palavra por "
            "palavra, a RESPOSTA de uma questão anterior do mesmo tópico — e "
            "cuja resposta é o termo que aquela questão já trazia no "
            "enunciado. O aluno não aplica nada: ele copia de volta o que "
            "acabou de ler."
        ),
        "exemplo_ruim": (
            "Q3: 'Para que serve o DNS?' -> 'traduzir nomes de domínio em "
            "endereços numéricos'. Q9: 'Escreva a sigla do serviço que traduz "
            "nomes de domínio em endereços numéricos.'"
        ),
        "por_que_importa": (
            "Isto NAO se confunde com reforço legítimo, e a diferença foi "
            "medida: 36 dos 41 pares deste tipo no banco são múltipla escolha "
            "seguida de escrita, onde a segunda exige APLICAR o conceito num "
            "contexto novo — e esses são bons.\n\n"
            "O que reprova é o caso em que a segunda só pede o nome de volta, "
            "com a definição servida no próprio enunciado. A impressão digital "
            "não pega: as duas respostas são textos diferentes."
        ),
    },
    {
        "id": "aula_prepara",
        "campo": "aula",
        "pergunta": "A aula prepara de verdade o que a questão cobra?",
        "peso": "medio",
        "reprova": (
            "Tópico que a aula declara preparar mas trata de raspão, ou "
            "questão que exige um passo que a aula nunca mostrou. O validador "
            "confere se os NOMES dos tópicos batem; não confere se o conteúdo "
            "cobre."
        ),
        "exemplo_ruim": (
            "A aula menciona 'laços' numa frase, e a questão pede para "
            "rastrear um acumulador ao longo de quatro voltas."
        ),
        "por_que_importa": (
            "Sem isso o aluno continua despreparado, mas agora ACHANDO que foi "
            "preparado — o que o CLAUDE.md registra ser pior que não ter aula."
        ),
    },
]


def por_id(identificador: str) -> dict | None:
    for c in CRITERIOS:
        if c["id"] == identificador:
            return c
    return None
