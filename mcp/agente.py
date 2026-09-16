#!/usr/bin/env python3
"""Cliente MCP leve: o modelo local usando os portoes de qualidade do DevLingo.

POR QUE ESTE ARQUIVO EXISTE
O Hermes Agent era o cliente previsto, e **nao cabe nesta maquina** -- medido em
16/09/2026: ele exige piso de 64.000 tokens de contexto, e o custo em VRAM do
qwen3 4B e ~0,61 GB a cada 4.096 tokens (3,18 GB com 4k, 3,79 GB com 8k). Os 64k
pediriam ~12 GB numa GTX 1650 de 4 GB. Nao e configuracao, e fisica.

O piso de 64k e exigencia DO HERMES, nao do MCP nem do modelo. O servidor MCP
funciona (6 ferramentas, conexao em 3,6 s) e o qwen3-gpu responde bem. Faltava
so um arcabouco que coubesse. Este arquivo e ele, e cabe em 8k folgado.

AS QUATRO DECISOES, E TODAS SAO DO PROPRIO CURSO DE AGENTES DE IA
- **Teto de voltas** (licao 01, "condicao de parada"). Sem teto, um modelo
  confuso chama ferramenta para sempre. Aqui o teto reprova em voz alta, nao
  em silencio
- **Rastro de cada chamada** (licao 05). O caminho e escolhido durante a
  execucao, entao sem rastro nao ha como saber o que aconteceu
- **O agente propoe; o codigo decide** (licao 03). Ferramenta que o modelo
  inventar e recusada aqui, com um erro que INSTRUI (licao 02) -- a lista do
  que existe de verdade volta para ele
- **So leitura.** O servidor nao expoe ferramenta de escrita, entao publicar e
  impossivel para o agente, nao importa o que ele decida

Uso:
    python mcp/agente.py "quantas questoes tem o topico igualdade em java?"
    python mcp/agente.py --modelo qwen3-gpu-ctx8k --voltas 6 "..."
"""
from __future__ import annotations

import argparse
import asyncio
import json
import sys
import urllib.request
from pathlib import Path

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

RAIZ = Path(__file__).resolve().parent.parent
SERVIDOR = RAIZ / "mcp" / "servidor.py"

# 127.0.0.1, e NUNCA "localhost": no Windows o localhost tenta IPv6 primeiro, o
# Ollama escuta so no IPv4, e a espera custa ~2 s POR CHAMADA. Medido em
# 16/09/2026: 2.035 ms com localhost contra 9 ms com 127.0.0.1.
OLLAMA = "http://127.0.0.1:11434"

# O ctx8k existe porque o padrao do Ollama e 4.096, e os esquemas das 6
# ferramentas nao cabem la. Ele cabe INTEIRO na GPU (3,79 de 3,79 GB).
MODELO = "qwen3-gpu-ctx8k"

SISTEMA = (
    "Voce ajuda a escrever conteudo do DevLingo. Use as ferramentas para "
    "conferir fatos do banco de questoes em vez de supor: elas leem o banco "
    "de verdade. Responda em portugues, curto e direto."
)


def conversar(modelo: str, mensagens: list[dict], ferramentas: list[dict]) -> dict:
    """Uma volta no modelo local. Usa /api/chat, que e quem aceita ferramentas."""
    corpo = json.dumps({
        "model": modelo,
        "messages": mensagens,
        "tools": ferramentas,
        "stream": False,
        "options": {"temperature": 0},   # conferir fato nao e tarefa criativa
    }).encode()
    req = urllib.request.Request(
        OLLAMA + "/api/chat", data=corpo,
        headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=300) as r:
        return json.loads(r.read())["message"]


def como_texto(resultado) -> str:
    """Achata o retorno do MCP para o que o modelo consegue ler."""
    partes = []
    for bloco in getattr(resultado, "content", []) or []:
        texto = getattr(bloco, "text", None)
        if texto:
            partes.append(texto)
    return "\n".join(partes) if partes else json.dumps(
        getattr(resultado, "structuredContent", {}) or {}, ensure_ascii=False)


async def rodar(pergunta: str, modelo: str, teto: int) -> int:
    parametros = StdioServerParameters(
        command=sys.executable, args=[str(SERVIDOR)])

    async with stdio_client(parametros) as (ler, escrever):
        async with ClientSession(ler, escrever) as sessao:
            await sessao.initialize()
            catalogo = await sessao.list_tools()

            # O esquema do MCP ja e o que a API de ferramentas espera; so muda
            # a embalagem. Nao ha traducao de tipos a manter em sincronia.
            #
            # O campo e `input_schema`, em snake_case: este pacote (mcp 2.2.0)
            # renomeou o `inputSchema` da API classica. Escrever de cabeca aqui
            # da AttributeError na primeira execucao.
            ferramentas = [{
                "type": "function",
                "function": {
                    "name": f.name,
                    "description": f.description or "",
                    "parameters": f.input_schema,
                },
            } for f in catalogo.tools]
            nomes = {f.name for f in catalogo.tools}
            print(f"  ferramentas descobertas: {', '.join(sorted(nomes))}\n")

            mensagens = [{"role": "system", "content": SISTEMA},
                         {"role": "user", "content": pergunta}]

            for volta in range(1, teto + 1):
                msg = conversar(modelo, mensagens, ferramentas)
                chamadas = msg.get("tool_calls") or []
                mensagens.append(msg)

                if not chamadas:
                    print(f"\n  resposta (volta {volta}):\n\n{msg.get('content','').strip()}\n")
                    return 0

                for chamada in chamadas:
                    fn = chamada["function"]
                    nome, args = fn["name"], fn.get("arguments") or {}
                    if isinstance(args, str):
                        args = json.loads(args or "{}")

                    print(f"  [volta {volta}] {nome}({json.dumps(args, ensure_ascii=False)})")

                    # O agente PROPOE; quem decide o que existe e o codigo. E o
                    # erro INSTRUI: devolve a lista real em vez de so negar.
                    if nome not in nomes:
                        saida = (f"ferramenta '{nome}' nao existe. "
                                 f"As que existem: {', '.join(sorted(nomes))}")
                    else:
                        saida = como_texto(await sessao.call_tool(nome, args))

                    print(f"      -> {saida[:160]}")
                    mensagens.append({"role": "tool", "content": saida})

            # Teto estourado reprova em voz alta. Agente que para calado parece
            # ter respondido.
            print(f"\n  TETO DE {teto} VOLTAS ESTOURADO sem resposta final.")
            return 1


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("pergunta")
    ap.add_argument("--modelo", default=MODELO)
    ap.add_argument("--voltas", type=int, default=6, help="teto de voltas")
    a = ap.parse_args()
    print(f"  modelo: {a.modelo}  |  teto: {a.voltas} voltas\n")
    return asyncio.run(rodar(a.pergunta, a.modelo, a.voltas))


if __name__ == "__main__":
    sys.exit(main())
