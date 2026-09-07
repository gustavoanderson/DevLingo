#!/usr/bin/env python3
"""Sintetiza os efeitos sonoros do DevLingo.

Uso:
    python3 tools/gerar_sons.py            # grava em app/assets/som/
    python3 tools/gerar_sons.py --conferir # so verifica, nao grava

Gera dois arquivos, ambos onda quadrada, 44100 Hz, 16 bits mono:

    acerto.wav  fanfarra de quem acertou uma questao (do do do sol)
    ficha.wav   moeda caindo no fliperama, na tela de titulo (do sol, agudo)

Chiptune em vez de instrumento gravado, porque o Tr0nikAt e um gato ciborgue de
visor neon e a paleta e dos anos 80: 8-bit combina com o projeto. E, na pratica,
sintetizar cabe na biblioteca padrao e num arquivo de texto revisavel em pull
request, enquanto um WAV gravado entra no repositorio como caixa-preta.

**Este script e a fonte dos dois sons.** Para mudar um efeito, mude as notas
aqui e rode de novo; nao edite o WAV. E a mesma regra de `gerar_faixas.py` para
as faixas de cenario, e existe pelo mesmo motivo: arquivo gerado que passa a ser
editado a mao diverge do gerador, e ninguem descobre qual dos dois esta certo.
"""

import array
import math
import os
import sys
import wave
from pathlib import Path

TAXA = 44100
# Baixado de 0,32 para 0,16 depois de o Gustavo jogar num celular de verdade e
# achar estridente. Onda quadrada tem harmonicos impares fortes, e o que no
# alto-falante do emulador soava "8-bit" no aparelho dele soava agressivo.
#
# Metade da amplitude e cerca de 6 dB a menos. Nao resolve o timbre -- isso e
# a troca de sons ja combinada -- mas tira o incomodo enquanto ela nao vem.
VOLUME = 0.16

DESTINO = Path(__file__).resolve().parent.parent / "app" / "assets" / "som"

# Frequencias em Hz. Nomes em portugues para bater com os comentarios.
DO5, SOL5 = 523.25, 783.99
DO6, SOL6 = 1046.50, 1567.98

# (frequencia, duracao em segundos, pausa depois)
FANFARRA = [
    (DO5, 0.090, 0.045),
    (DO5, 0.090, 0.045),
    (DO5, 0.090, 0.045),
    (SOL5, 0.400, 0.000),
]

# Curto e agudo: ficha e um evento, nao uma melodia. Duas notas bastam, e o
# salto de oitava para cima e o que soa como "credito registrado".
FICHA = [
    (DO6, 0.055, 0.010),
    (SOL6, 0.260, 0.000),
]

# A ficha sai um pouco mais baixa que a fanfarra, e isso e de proposito: ela e
# um clique de interface, e a fanfarra e uma recompensa. Som de confirmacao no
# mesmo volume da comemoracao achata os dois.
#
# O envelope tambem difere. A moeda tem ataque mais seco e cauda mais longa:
# e o que faz soar como metal batendo e ressoando, em vez de nota tocada.
#
# A proporcao entre os dois foi preservada na reducao: 0,30/0,32 virou
# 0,15/0,16. Baixar so um deles inverteria a relacao que este comentario
# acabou de explicar.
VOLUME_FICHA = 0.15
ENVELOPE_FANFARRA = (0.006, 0.10)  # (ataque, decaimento), em segundos
ENVELOPE_FICHA = (0.004, 0.13)


def onda_quadrada(freq, duracao, volume, ataque, decaimento):
    """Uma nota em onda quadrada, com envelope para nao estalar nas pontas.

    Sem o ataque, o inicio abrupto vira um clique audivel; sem o decaimento, o
    fim tambem. O envelope e a diferenca entre "8-bit" e "defeito".
    """
    saida = []
    for i in range(int(TAXA * duracao)):
        t = i / TAXA
        # Quadrada: o sinal do seno, que e o timbre 8-bit classico.
        valor = 1.0 if math.sin(2 * math.pi * freq * t) >= 0 else -1.0

        env = 1.0
        if t < ataque:
            env = t / ataque
        restante = duracao - t
        if restante < decaimento:
            env = min(env, restante / decaimento)

        saida.append(valor * env * volume)
    return saida


def sintetizar(notas, volume, envelope):
    ataque, decaimento = envelope
    amostras = []
    for freq, duracao, pausa in notas:
        amostras.extend(onda_quadrada(freq, duracao, volume, ataque, decaimento))
        if pausa:
            amostras.extend([0.0] * int(TAXA * pausa))
    return amostras


def gravar(nome, amostras):
    destino = DESTINO / nome
    destino.parent.mkdir(parents=True, exist_ok=True)
    quadros = array.array(
        "h", (int(max(-1.0, min(1.0, a)) * 32767) for a in amostras)
    )
    with wave.open(str(destino), "wb") as arquivo:
        arquivo.setnchannels(1)
        arquivo.setsampwidth(2)
        arquivo.setframerate(TAXA)
        arquivo.writeframes(quadros.tobytes())
    return destino


def main():
    conferir = "--conferir" in sys.argv
    sons = {
        "acerto.wav": (FANFARRA, VOLUME, ENVELOPE_FANFARRA),
        "ficha.wav": (FICHA, VOLUME_FICHA, ENVELOPE_FICHA),
    }

    for nome, (notas, volume, envelope) in sons.items():
        amostras = sintetizar(notas, volume, envelope)
        duracao = len(amostras) / TAXA

        if conferir:
            existente = DESTINO / nome
            estado = "existe" if existente.is_file() else "FALTANDO"
            print(f"{nome}: {duracao:.2f} s sintetizados, no disco: {estado}")
            continue

        destino = gravar(nome, amostras)
        tamanho = os.path.getsize(destino) / 1024
        print(f"gerado: {destino}")
        print(f"  duracao: {duracao:.2f} s   tamanho: {tamanho:.1f} KB")

    return 0


if __name__ == "__main__":
    sys.exit(main())
