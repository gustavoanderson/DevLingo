#!/bin/bash
# Pede as credenciais do Cloudflare Access, CONFERE o formato, e roda o
# conferidor da hospedagem.
#
# POR QUE ESTE SCRIPT EXISTE
#
# Colar credencial num terminal que nao ecoa e mais dificil do que parece, e
# custou duas rodadas em 24/09/2026: o Client ID veio com 187 caracteres em vez
# de 39 (o rotulo da tela foi junto) e o secret com 54 em vez de 64 (truncado).
# Nenhum dos dois erros aparece na tela, e o sintoma final e um `403` COM
# credencial -- que parece politica errada, e leva a mexer na politica que
# estava certa.
#
# Entao ele confere ANTES de testar. Errar o formato para aqui, com a causa
# dita, em vez de virar um diagnostico errado tres passos adiante.
#
# Uso:
#     bash mcp/conferir.sh
#     bash mcp/conferir.sh https://outro-endereco/mcp

set -u
URL="${1:-https://mcp.devlingo.app.br/mcp}"

# Os valores sao lidos SEM eco, e nao passam por argumento nem por histórico.
read -s -p "Client ID (termina em .access): " BRUTO_ID; echo
read -s -p "Client Secret: " BRUTO_SEGREDO; echo

# LIMPEZA AUTOMATICA, porque o erro mais comum e invisivel. Tira espaco,
# tabulacao, quebra de linha e o rotulo do cabecalho, caso venha colado.
limpar() {
  printf '%s' "$1" \
    | tr -d ' \t\r\n' \
    | sed 's/^CF-Access-Client-Id://I; s/^CF-Access-Client-Secret://I'
}

CF_ID=$(limpar "$BRUTO_ID")
CF_SEGREDO=$(limpar "$BRUTO_SEGREDO")

erro=0
echo
echo "--- conferindo o formato antes de gastar uma rodada ---"

# O Client ID e 32 hex + ".access"; o secret, 64 hex. Sao formatos fixos, e e
# por isso que da para conferir sem ver o valor.
if [[ "$CF_ID" =~ ^[0-9a-f]{32}\.access$ ]]; then
  echo "  ok    Client ID      ${#CF_ID} caracteres, termina em .access"
else
  echo "  FALHA Client ID      ${#CF_ID} caracteres (esperado 39, terminando em .access)"
  echo "        Copie SO o valor: comeca no hex e termina em .access."
  erro=1
fi

# DOIS FORMATOS VALEM, e ignorar o novo custou varias rodadas ao Gustavo.
#
# A Cloudflare trocou o formato em 26/08/2026: os secrets novos sao
# `cfast_` + 40 alfanumericos + 8 de checksum, 54 caracteres, e NAO sao
# hexadecimais. Os antigos, 64 hex, continuam valendo -- a documentacao diz
# que nao precisam de rotacao.
#
# Eu escrevi "64 hex" de cabeca, sem conferir na fonte, e esta regra passou a
# BARRAR UMA CREDENCIAL VALIDA. O CLAUDE.md ja avisa: falso positivo e tao
# grave quanto defeito nao pego, porque ensina a contornar o portao em vez de
# confiar nele. Quando uma regra barra algo legitimo, conserta-se a REGRA.
if [[ "$CF_SEGREDO" =~ ^cfast_[A-Za-z0-9]{48}$ ]]; then
  echo "  ok    Client Secret  ${#CF_SEGREDO} caracteres, formato novo (cfast_)"
elif [[ "$CF_SEGREDO" =~ ^[0-9a-f]{64}$ ]]; then
  echo "  ok    Client Secret  ${#CF_SEGREDO} caracteres, formato antigo (hex)"
else
  echo "  FALHA Client Secret  ${#CF_SEGREDO} caracteres"
  echo "        Esperado: 'cfast_' + 48 caracteres (novo, desde 26/08/2026)"
  echo "        ou 64 hexadecimais (antigo). O seu nao bate com nenhum."
  echo "        Ele aparece UMA VEZ SO na tela da Cloudflare."
  erro=1
fi

if [ "$erro" = 1 ]; then
  echo
  echo "Nao vou testar com credencial invalida: o 403 resultante pareceria"
  echo "politica errada, e levaria a mexer no que esta certo."
  exit 1
fi

export CF_ID CF_SEGREDO
echo
exec python mcp/testar_hospedado.py "$URL"
