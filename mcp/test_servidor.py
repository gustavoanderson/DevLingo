#!/usr/bin/env python3
"""Teste de fumaca do servidor MCP.

`test_ferramentas.py` prova a LOGICA. Este arquivo prova o EMBRULHO, e os dois
quebram por motivos diferentes: a logica quebra quando uma regra muda; o
embrulho quebra quando o SDK muda de API -- e foi exatamente o que aconteceu ao
escrever isto, com `FastMCP` virando `MCPServer` na versao 2.

Sem este teste, uma troca de versao do SDK derrubaria o servidor em silencio:
nada mais o carrega, e o `test_ferramentas.py` passaria verde do mesmo jeito.

O que ele NAO faz e subir o processo e falar o protocolo de ponta a ponta.
Isso foi verificado a mao, com um cliente stdio de verdade, e ficou de fora do
CI para nao gastar minuto de runner com um processo filho -- decisao
registrada, e nao esquecimento.

    python3 mcp/test_servidor.py
"""

from __future__ import annotations

import asyncio
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import servidor as s  # noqa: E402

ESPERADAS = {
    "validar_licao",
    "impressao_digital",
    "conferir_teclado",
    "topicos_da_trilha",
}

falhas: list[str] = []
ferramentas = asyncio.run(s.servidor.list_tools())
nomes = {f.name for f in ferramentas}

if nomes != ESPERADAS:
    falhas.append(
        f"  as ferramentas anunciadas mudaram\n"
        f"      esperadas: {sorted(ESPERADAS)}\n"
        f"      anunciadas: {sorted(nomes)}"
    )

for f in ferramentas:
    # A descricao NAO e documentacao: e o que o modelo le para escolher a
    # ferramenta. A licao 02 do curso e inteira sobre isso -- descricao vaga
    # produz agente que chama a ferramenta parecida em vez da certa.
    if not f.description or len(f.description) < 80:
        falhas.append(
            f"  {f.name} tem descricao curta demais\n"
            f"      ela e o que o modelo le para DECIDIR, nao um comentario"
        )
    # Quando usar, e quando nao usar. Sem isso o agente acerta o caso obvio e
    # erra a fronteira, que e onde as chamadas caras acontecem.
    if "Use " not in (f.description or ""):
        falhas.append(
            f"  {f.name} nao diz QUANDO usar\n"
            f"      a descricao precisa de uma frase começando com 'Use ...'"
        )
    obrigatorios = (f.input_schema or {}).get("required", [])
    if not obrigatorios:
        falhas.append(
            f"  {f.name} nao declara parametro obrigatorio\n"
            f"      parametro frouxo faz o modelo adivinhar o formato"
        )

print(f"\nFerramentas conferidas: {len(ferramentas)}")

if falhas:
    print(f"\n{len(falhas)} problema(s):\n")
    print("\n\n".join(falhas))
    print("\nSERVIDOR MCP REPROVADO\n")
    sys.exit(1)

print("\nSERVIDOR MCP APROVADO\n")
