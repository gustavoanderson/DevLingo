"""A voz do Tr∅nikAt: texto aprovado pelo porteiro -> audio + o movimento da boca.

Escolhida pelo Gustavo de ouvido, em 15/09/2026, na prova_de_vozes.py:
**faber, desenho forte** (tom 1,45 vezes mais agudo).

A boca sai dos FONEMAS, e nao do volume
---------------------------------------
O plano era abrir a boca pelo volume do som. O Piper faz melhor: com
include_alignments ele diz quantas amostras de audio cada fonema ocupa, e a soma
bate amostra por amostra com o audio (medido: 24 fonemas, 35.584 amostras, igual
ao arquivo). Entao a boca sabe que o "a" de Tronicat vai de 1,11 s a 1,18 s, e
pode abrir NELE -- e fechar no "m", que volume nenhum distingue de um "a" baixo.

Dois cuidados que so aparecem medindo:
- os tempos vem do audio ANTES do efeito de desenho. O efeito comprime o audio
  TOM vezes, entao todo tempo e dividido por TOM; sem isso a boca atrasa em
  relacao a voz, cada vez mais ao longo da frase
- o alinhamento exige o pacote onnx: piper-tts[alignment]

Uso, para ouvir e ver a boca:
    estudio/.venv/Scripts/python.exe estudio/voz.py "texto"
"""
from __future__ import annotations

import io
import os
import unicodedata
import sys
import time
import wave
from dataclasses import dataclass
from pathlib import Path

import numpy as np
from piper import PiperVoice, SynthesisConfig

MODELO = Path(os.environ.get("ESTUDIO_VOZ", r"D:\dev\piper-vozes\pt_BR-faber-medium.onnx"))
TOM = 1.45

# QUANTO MAIS DEVAGAR ELE FALA, sem mexer no timbre.
#
# O TOM acima e usado DUAS vezes, com papeis diferentes: primeiro como
# `length_scale` (sintetiza mais devagar) e depois como fator de reamostragem
# (encolhe o audio, o que devolve a velocidade E sobe o tom). Os dois se
# cancelam na VELOCIDADE e se somam no TIMBRE -- e por isso a voz sai aguda em
# ritmo normal.
#
# Como sao dois papeis, eles se separam. Multiplicando so o primeiro, a fala
# fica mais longa e o tom nao muda:
#
#     duracao final = original * LENTIDAO
#     tom final     = original * TOM        (inalterado)
#
# 1,0 e a velocidade de sempre. O Gustavo pediu "levemente mais lento" em
# 17/09/2026, para a fala ficar mais facil de acompanhar e de quebra ocupar
# mais da espera. Mexer neste numero regrava TODAS as falas.
# 1,12 ainda soou rapido para ele. 1,35 e o segundo passo -- este numero e a
# unica coisa a mexer se precisar de mais ou de menos.
LENTIDAO = 1.35

# O sintetizador le o que estiver escrito. "Tr∅nikAt" tem um simbolo no meio
# que seria lido como simbolo ou pulado. Grafado so para a VOZ; a tela continua
# mostrando Tr∅nikAt. Pronuncias aprovadas pelo Gustavo na prova de vozes.
# ORDEM IMPORTA: a substituicao e sequencial, entao o mais LONGO vem antes.
# Com "Hmm" primeiro, "Hmmmm" viraria "Ããmm".
#
# O "Hmm" existe aqui porque o espeak le uma palavra sem vogal SOLETRANDO:
# medido, "Hmmmm" vira 18 fonemas -- "a-ga e-me e-me e-me e-mi" -- e foi
# exatamente assim que saiu na primeira versao das falas de enrolar. O Gustavo
# ouviu e apontou. Com o mapeamento, a TELA continua mostrando "Hmmm", que se
# le naturalmente, e a VOZ diz o som certo.
PRONUNCIA = {
    "Tr∅nikAt": "Trônicat",
    "DevLingo": "Dév Língo",
    # O HUM DE PENSAR, e ele passou por DUAS correcoes medidas.
    #
    # "Ããã" saia PICOTADO: o espeak lia tres vogais separadas, com acento
    # proprio -- ^ˌɐ̃ɐ̃ˈɐ̃$ -- e o resultado era "ã-ã-Ã", nao um hum continuo.
    #
    # A primeira correcao foi "Ahmmm", que o Gustavo sugeriu. Ela conserta o
    # picote -- vira ^ˈam$, um som so -- mas sai CURTA: 0,38 s. E aqui esta o
    # achado que so a medicao deu: o Piper COLAPSA letra repetida, entao
    # "ahmmmmm" e "ahm" duram exatamente o mesmo. Nao da para alongar um hum
    # escrevendo mais emes, que era a ideia dele e a minha.
    #
    # O que alonga e a VIRGULA. "Ah, hum" vira ^ˈa, ˈũm$ -- o "ah" aberto que
    # ele pediu, e depois o hum nasal -- e mede 0,61 s, quase o dobro. Duas
    # batidas de hesitacao em vez de uma silaba fechada.
    "Hmmmm": "Ah, hum", "Hmmm": "Ah, hum", "Hmm": "Ahm",
}

# Quanto a boca abre em cada fonema (IPA do espeak-ng), de 0 a 1, e se os labios
# arredondam. O desenho do Tr∅nikAt nao tem dentes nem lingua: abertura e
# arredondamento sao tudo o que a boca dele consegue mostrar.
ABERTURA = {
    **{v: 1.0 for v in "aɐ"},
    **{v: 0.75 for v in "ɛɔ"},
    **{v: 0.6 for v in "eo"},
    **{v: 0.45 for v in "iɪuʊ"},
    **{v: 0.35 for v in "wj"},
    **{c: 0.0 for c in "mbp"},        # bilabiais: a boca FECHA
    **{c: 0.15 for c in "fv"},        # labiodentais: quase fechada
}
ARREDONDA = set("oɔuʊw")
CONSOANTE_PADRAO = 0.25
SILENCIO = set(" ,.;:!?^$_ˈˌ")        # pausa, pontuacao e marcas de tonicidade


@dataclass
class Fala:
    wav: bytes                      # arquivo WAV completo, pronto para tocar
    duracao: float                  # segundos
    bocas: list[tuple[float, float, float, bool]]   # (inicio, fim, abertura, arredonda)
    sintese_s: float


def para_voz(texto: str) -> str:
    for escrito, falado in PRONUNCIA.items():
        texto = texto.replace(escrito, falado)
    return texto


def boca_de(fonema: str) -> tuple[float, bool]:
    # Nasal: a boca e a da vogal. Decompoe ANTES de tirar o til: o espeak
    # escreve "\u0250\u0303" (letra + til separado), mas um "\u00e3" pre-composto e um
    # caractere so, e tirar so o til combinante o deixava passar como
    # consoante (abertura 0,25 em vez de 1,0). Pego por testar_voz.py.
    base = "".join(c for c in unicodedata.normalize("NFD", fonema) if not unicodedata.combining(c))
    if not base or all(c in SILENCIO for c in base):
        return 0.0, False
    letra = base[0]
    return ABERTURA.get(letra, CONSOANTE_PADRAO), letra in ARREDONDA


class Voz:
    def __init__(self, modelo: Path = MODELO) -> None:
        self.piper = PiperVoice.load(modelo, include_alignments=True)

    def falar(self, texto: str) -> Fala:
        inicio = time.time()
        pedacos = list(self.piper.synthesize(
            para_voz(texto), SynthesisConfig(length_scale=TOM * LENTIDAO),
            include_alignments=True))
        taxa = pedacos[0].sample_rate

        # A linha do tempo da boca, no tempo do audio LENTO (antes do efeito).
        bocas: list[tuple[float, float, float, bool]] = []
        amostra = 0
        for p in pedacos:
            for a in p.phoneme_alignments or []:
                abertura, redonda = boca_de(a.phoneme)
                t0, t1 = amostra / taxa / TOM, (amostra + a.num_samples) / taxa / TOM
                # Fonemas vizinhos com a mesma boca viram um trecho so: a cabeca
                # 3D recebe menos mudancas e anima mais suave.
                if bocas and bocas[-1][2] == abertura and bocas[-1][3] == redonda:
                    bocas[-1] = (bocas[-1][0], t1, abertura, redonda)
                else:
                    bocas.append((t0, t1, abertura, redonda))
                amostra += a.num_samples
        # Arredonda UMA vez, no fim. A primeira versao arredondava o inicio de
        # cada trecho mas nao o fim dos trechos fundidos, e diferencas de
        # decimo de milesimo faziam um trecho terminar depois do seguinte
        # comecar. Pego por testar_voz.py.
        bocas = [(round(t0, 3), round(t1, 3), ab, rd) for t0, t1, ab, rd in bocas]

        # O efeito de desenho: reamostrar para durar 1/TOM e tocar na taxa
        # original sobe o tom TOM vezes. Detalhes em prova_de_vozes.py.
        audio = np.concatenate([p.audio_int16_array for p in pedacos])
        n = int(len(audio) / TOM)
        audio = np.interp(np.arange(n) * TOM, np.arange(len(audio)), audio).astype(np.int16)

        # APARA O SILENCIO DAS PONTAS, e isto nao e detalhe de arquivo.
        #
        # O Piper deixa uma cauda em cada sintese. Medido em 17/09/2026 nos 14
        # arquivos gravados: 37 ms no inicio e 236 ms no FIM, em media. Entre
        # duas falas emendadas isso da ~273 ms de silencio REAL -- e numa
        # sequencia de sete, quase 1,7 s de nada.
        #
        # E o pior: esse silencio NAO aparece medindo do lado do tocador, que e
        # onde eu estava medindo. A conta dava 310 ms de vao total enquanto o
        # Gustavo ouvia "muito espaco". O silencio estava dentro da onda.
        #
        # Sobram 40 ms de cada lado, de proposito: corte rente tira o ataque da
        # primeira silaba e a queda da ultima, e a fala fica com som de cortada.
        MARGEM = int(0.040 * taxa)
        limite = max(300, int(np.abs(audio).max() * 0.02))
        forte = np.flatnonzero(np.abs(audio) > limite)
        recorte = 0
        if len(forte):
            ini = max(0, forte[0] - MARGEM)
            fim = min(len(audio), forte[-1] + MARGEM)
            audio = audio[ini:fim]
            recorte = ini / taxa
        # A boca vive no mesmo eixo do audio: cortando o comeco, todo tempo
        # anda junto. Sem isto ela ficaria atrasada pelo tanto que se aparou.
        # Duas correcoes, e as duas sao do mesmo eixo: cortar o COMECO anda com
        # todo mundo para tras; cortar o FIM encurta o eixo, e o que passar do
        # novo fim precisa ser aparado tambem. Sem a segunda, a boca continua se
        # mexendo depois de a voz acabar -- pego pelo testar_voz.py, que exige
        # "a boca termina junto com a voz".
        fim_novo = len(audio) / taxa
        ajustadas = []
        for t0, t1, ab, rd in bocas:
            t0, t1 = max(0.0, t0 - recorte), max(0.0, t1 - recorte)
            if t0 >= fim_novo:
                continue
            ajustadas.append((round(t0, 3), round(min(t1, fim_novo), 3), ab, rd))
        bocas = ajustadas

        buf = io.BytesIO()
        with wave.open(buf, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(taxa)
            w.writeframes(audio.tobytes())
        # A duracao vem do audio JA aparado, senao o site reservaria tempo para
        # um silencio que nao existe mais.
        return Fala(buf.getvalue(), len(audio) / taxa, bocas, time.time() - inicio)


def main() -> int:
    texto = " ".join(sys.argv[1:]) or "Oi! Eu sou o Tr∅nikAt, o gato ciborgue do DevLingo."
    t = time.time()
    voz = Voz()
    print(f"voz carregada em {time.time() - t:.1f} s")
    voz.falar("aquecendo.")
    fala = voz.falar(texto)
    saida = MODELO.parent / "ultima-fala.wav"
    saida.write_bytes(fala.wav)
    ultimo_fim = fala.bocas[-1][1] if fala.bocas else 0
    print(f"audio {fala.duracao:.2f} s | sintese {fala.sintese_s:.2f} s | "
          f"{len(fala.bocas)} trechos de boca | a boca termina em {ultimo_fim:.2f} s")
    for t0, t1, ab, rd in fala.bocas[:12]:
        print(f"   {t0:5.2f}s -> {t1:5.2f}s  abertura {ab:.2f}{'  (arredonda)' if rd else ''}")
    print(f"\ngravado em {saida}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
