#!/bin/bash
# Mantem a copia do repositorio que o servidor MCP le em dia com a `main`.
#
#     roda na VM, a cada 15 min, pelo timer `mcp-atualizar` (ver HOSPEDAR.md)
#
# EXISTE PORQUE A COPIA ENVELHECIA CALADA. O servidor foi instalado com um
# `git clone` feito uma vez, e em 28/09/2026 estava 24 commits atras. As
# ferramentas que leem o banco -- `impressao_digital`, `topicos_da_trilha` --
# responderiam sobre as questoes do dia da instalacao, sem erro nenhum, e
# numa demonstracao o numero nao bateria com o repositorio.
#
# O BANCO NAO PRECISA DE REINICIO: o servidor le o disco a cada chamada
# (`_carregar_banco`). Quem precisa e o CODIGO -- servidor, ferramentas e o
# validador que elas importam. Por isso so se reinicia quando ele muda: um
# reinicio a cada 15 min derrubaria conexoes a toa.
#
# Falhar aqui nunca derruba o servidor: sem rede, o `pull` falha e a copia
# fica como estava, que e o comportamento de antes deste script.
set -u
cd "$HOME/mcp/fonte" || exit 1

antes=$(git rev-parse HEAD)
git pull -q --ff-only origin main || { echo "pull falhou; copia mantida em ${antes:0:7}"; exit 0; }
depois=$(git rev-parse HEAD)

[ "$antes" = "$depois" ] && exit 0
echo "copia atualizada: ${antes:0:7} -> ${depois:0:7}"

# O esquema (tools/question.schema.json) fica de fora: ele e relido a cada
# chamada, como o banco. O validador entra porque e importado como modulo.
if git diff --name-only "$antes" "$depois" | grep -qE '^(mcp/.*\.py|tools/validate_questions\.py)$'; then
  echo "codigo do servidor mudou: reiniciando o mcp"
  sudo systemctl restart mcp
fi
