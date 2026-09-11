"""Servidor MCP do DevLingo: os portoes de qualidade do projeto, como ferramentas.

## O que este arquivo NAO faz

Ele nao implementa regra nenhuma. Toda a logica mora em `ferramentas.py`, que
por sua vez importa `tools/validate_questions.py` -- a autoridade unica sobre o
que e uma licao valida. Aqui so ha o embrulho do protocolo.

A separacao e a mesma que o CLAUDE.md ja exige em tres lugares: `normalize()`
com contrato compartilhado entre Python e Dart, a geometria dos cenarios saindo
de um gerador so, e o Page Object guardando o seletor num lugar so. **Quando
algo e usado por muitos, ele mora num lugar so.**

## Por que MCP, e nao um script

O teste da licao 03 do proprio curso: *quantos consumidores diferentes precisam
disto, e eles alcancam onde a capacidade mora?*

    eu, numa sessao local ......... alcanca
    rotina de madrugada, na nuvem . NAO alcanca
    agente revisor rodando em CI .. NAO alcanca

Tres consumidores, e dois deles rodam onde as regras nao estao. E o motivo de
forcamento geografico, nao o "da para usar MCP aqui".

## Por que TODAS sao somente leitura

Licao 05: *um limite so vale quando nao depende do modelo julgar bem.*

Com `validar_licao` exposta e nenhuma ferramenta de escrita, publicar e
**impossivel** para o agente -- nao importa o que ele decida, nem o que tenha
lido num texto que processou. O limite nao esta no julgamento dele; esta na
ausencia da ferramenta.

Se um dia entrar algo que escreve, ele entra com aprovacao humana no caminho,
que e o criterio ja combinado: *autonomia onde o erro e verificavel
automaticamente; pessoa onde nao e.*

## Como rodar

    python3 mcp/servidor.py

Ver `mcp/README.md` para conectar num cliente.
"""

from __future__ import annotations

import sys
from pathlib import Path

# O cliente MCP inicia este arquivo de um diretorio de trabalho que nao e o
# nosso -- normalmente o dele. Sem isto, `import ferramentas` falha, e falha
# com "ModuleNotFoundError" no stderr de um processo que ninguem esta olhando.
sys.path.insert(0, str(Path(__file__).resolve().parent))

from mcp.server.mcpserver import MCPServer  # noqa: E402

import ferramentas  # noqa: E402

servidor = MCPServer(
    name="devlingo",
    instructions=(
        "Portoes de qualidade do banco de questoes do DevLingo. Todas as "
        "ferramentas sao SOMENTE LEITURA: nenhuma grava, publica ou apaga.\n\n"
        "Ao escrever ou revisar uma licao, a ordem que economiza retrabalho e: "
        "topicos_da_trilha para saber o que ja existe, conferir_teclado antes "
        "de fixar cada resposta escrita, impressao_digital para nao repetir "
        "resposta ja cobrada, e validar_licao por ultimo, com a licao montada."
    ),
)


@servidor.tool(
    description=(
        "Roda as 10 regras do validador do DevLingo contra uma licao em "
        "memoria e devolve os erros e avisos. E a MESMA checagem que reprova "
        "no CI, disponivel antes de o conteudo virar arquivo.\n\n"
        "Nao grava nada. Nao confere repeticao de resposta contra o banco: "
        "para isso use impressao_digital.\n\n"
        "Use quando a licao ja estiver montada, com aula e questoes."
    )
)
def validar_licao(licao: dict) -> dict:
    """Valida uma licao completa.

    Args:
        licao: o objeto JSON da licao, com schemaVersion, language, level,
            lessonId, lessonTitle, aula e questions. Envie o CONTEUDO, nao o
            caminho de um arquivo.
    """
    return ferramentas.validar_licao(licao)


@servidor.tool(
    description=(
        "Diz se uma resposta ja e cobrada por outra questao da mesma trilha, "
        "e por qual. O validador reprova duas questoes que cobram a mesma "
        "resposta, porque a segunda vira adivinhavel depois da primeira.\n\n"
        "Use ANTES de fixar a resposta de uma questao nova. Num topico "
        "estreito o espaco de respostas se esgota rapido, e descobrir isso "
        "depois de escrever as cinco alternativas e retrabalho."
    )
)
def impressao_digital(resposta: str, trilha: str) -> dict:
    """Procura uma resposta no banco.

    Args:
        resposta: o texto exato que o aluno digitaria ou a alternativa correta.
        trilha: a chave da trilha, como 'java' ou 'python'. A busca e escopada
            por trilha: a mesma resposta em linguagens diferentes nao colide.
    """
    return ferramentas.impressao_digital(resposta, trilha)


@servidor.tool(
    description=(
        "Diz se uma resposta e digitavel num teclado de celular brasileiro. O "
        "validador reprova caractere nao-ASCII no que o aluno DIGITA, porque "
        "acento em teclado de celular e toque longo e o aluno erraria por "
        "causa do teclado, nao da linguagem.\n\n"
        "Use ANTES de fixar a resposta de uma questao de escrita ou lacuna, "
        "e nao depois de montar a questao inteira: descobrir que a resposta "
        "nao serve quando as cinco alternativas ja estao escritas e "
        "retrabalho evitavel.\n\n"
        "A restricao vale so para o campo 'accepted'. Enunciado, dica, "
        "explicacao e alternativas de multipla escolha continuam com acento."
    )
)
def conferir_teclado(resposta: str) -> dict:
    """Confere se a resposta e ASCII puro.

    Args:
        resposta: o texto que entraria em 'accepted'.
    """
    return ferramentas.conferir_teclado(resposta)


@servidor.tool(
    description=(
        "Lista os topicos de uma trilha com a contagem de questoes de cada "
        "um, e diz quantas licoes ela tem.\n\n"
        "Use antes de escrever para reaproveitar um topico que ja existe em "
        "vez de inventar nome novo para a mesma coisa: a aula precisa declarar "
        "exatamente os topicos que as questoes cobram, e o validador reprova "
        "quando os dois lados deixam de bater."
    )
)
def topicos_da_trilha(trilha: str) -> dict:
    """Lista os topicos existentes numa trilha.

    Args:
        trilha: a chave da trilha, como 'java' ou 'agentes'. Se ela nao
            existir, a resposta lista as que existem.
    """
    return ferramentas.topicos_da_trilha(trilha)


if __name__ == "__main__":
    servidor.run()
