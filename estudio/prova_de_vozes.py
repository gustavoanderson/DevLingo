"""Prova de vozes do Tr∅nikAt: a mesma fala, em cada voz, normal e "de desenho".

Voz de personagem e decisao de gosto, e de quem conhece o personagem. Este
script nao escolhe: gera os arquivos para o Gustavo ouvir e decidir, e mede o
que da para medir -- quanto tempo a sintese leva na CPU.

A voz de desenho, sem biblioteca nova
-------------------------------------
O Piper nao tem controle de tom. O truque e o do disco acelerado: tocar o som
mais rapido do que foi gravado sobe o tom. Sozinho, isso tambem acelera a fala
e vira "voz de esquilo". Entao, para um fator k:
  1. o Piper sintetiza k vezes mais DEVAGAR (length_scale = k)
  2. o audio e reamostrado para durar 1/k -- tom k vezes mais agudo
O ritmo volta ao natural e fica so o tom. A reamostragem e uma interpolacao
linear com numpy (que ja veio com o onnxruntime), e o arquivo sai na taxa
original: um WAV de taxa esquisita pode nao tocar em todo lugar.

Uso:
    estudio/.venv/Scripts/python.exe estudio/prova_de_vozes.py
"""
from __future__ import annotations

import time
import wave
from pathlib import Path

import numpy as np
from piper import PiperVoice, SynthesisConfig

PASTA_VOZES = Path(r"D:\dev\piper-vozes")
SAIDA = PASTA_VOZES / "prova"
VOZES = ["cadu", "faber", "jeff"]

# (nome, fator de tom). 1.0 e a voz como veio.
VARIANTES = [("normal", 1.0), ("desenho-leve", 1.25), ("desenho-forte", 1.45)]

FALA = ("Oi! Eu sou o Tr∅nikAt, o gato ciborgue do DevLingo. "
        "Errar não termina a questão: a tela nunca diz errado, diz ainda não.")

# O sintetizador le o que estiver escrito. "Tr∅nikAt" tem um simbolo de
# conjunto vazio no meio, que seria lido como simbolo ou pulado. O nome e
# grafado para a VOZ, e so para ela: a tela continua mostrando Tr∅nikAt.
PRONUNCIA = {"Tr∅nikAt": "Trônicat", "DevLingo": "Dév Língo"}


def para_voz(texto: str) -> str:
    for escrito, falado in PRONUNCIA.items():
        texto = texto.replace(escrito, falado)
    return texto


def sintetizar(voz: PiperVoice, texto: str, k: float) -> tuple[np.ndarray, int, float]:
    """Devolve (amostras int16, taxa, segundos de sintese)."""
    inicio = time.time()
    pedacos = list(voz.synthesize(texto, SynthesisConfig(length_scale=k)))
    gasto = time.time() - inicio
    taxa = pedacos[0].sample_rate
    audio = np.concatenate([p.audio_int16_array for p in pedacos])
    if k != 1.0:
        # Reamostra para durar 1/k: cada amostra nova le a posicao k*i do
        # original. Tocado na taxa original, o tom sobe k vezes.
        n = int(len(audio) / k)
        audio = np.interp(np.arange(n) * k, np.arange(len(audio)), audio).astype(np.int16)
    return audio, taxa, gasto


def gravar(caminho: Path, audio: np.ndarray, taxa: int) -> None:
    with wave.open(str(caminho), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(taxa)
        w.writeframes(audio.tobytes())


def main() -> int:
    SAIDA.mkdir(parents=True, exist_ok=True)
    texto = para_voz(FALA)
    print(f"texto enviado a voz: {texto}\n")
    print(f"{'voz':6s} {'variante':14s} {'audio':>7s} {'sintese':>8s} {'x tempo real':>13s}")
    for nome in VOZES:
        modelo = PASTA_VOZES / f"pt_BR-{nome}-medium.onnx"
        carga = time.time()
        voz = PiperVoice.load(modelo)
        carga = time.time() - carga
        sintetizar(voz, "aquecendo.", 1.0)          # a primeira chamada paga a inicializacao
        for variante, k in VARIANTES:
            audio, taxa, gasto = sintetizar(voz, texto, k)
            duracao = len(audio) / taxa
            gravar(SAIDA / f"{nome}-{variante}.wav", audio, taxa)
            # "x tempo real" < 1 quer dizer que a sintese e mais rapida que a fala
            print(f"{nome:6s} {variante:14s} {duracao:6.1f}s {gasto:7.2f}s {gasto / duracao:12.2f}")
        print(f"       (carga da voz: {carga:.1f} s)")
    print(f"\narquivos em {SAIDA}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
