"""Testes da voz do Tr∅nikAt.

O defeito que motivou este arquivo nao quebra nada nem da erro: se os tempos dos
fonemas nao forem divididos pelo TOM, a boca termina de mexer 45% DEPOIS de a
voz calar (medido: 7,66 s de boca para 5,28 s de audio). Tudo continua rodando,
e o personagem fica dublado errado. So um teste pega.

Uso:
    estudio/.venv/Scripts/python.exe estudio/testar_voz.py
"""
from __future__ import annotations

import io
import sys
import wave

from voz import TOM, Voz, boca_de, para_voz


def main() -> int:
    falhas: list[str] = []

    def conferir(ok: bool, nome: str, detalhe: str = "") -> None:
        print(f"  {'ok  ' if ok else 'FALHA'} {nome}" + (f"  ({detalhe})" if detalhe else ""))
        if not ok:
            falhas.append(nome)

    print("=== sem sintetizar ===")
    conferir(para_voz("Sou o Tr∅nikAt") == "Sou o Trônicat", "o nome e grafado para a voz")
    conferir("∅" not in para_voz("Tr∅nikAt, do DevLingo"), "nenhum simbolo chega ao sintetizador")
    conferir(boca_de("m") == (0.0, False) and boca_de("b")[0] == 0.0, "bilabial fecha a boca")
    conferir(boca_de("a")[0] == 1.0, "'a' abre a boca inteira")
    conferir(boca_de("u")[1] and boca_de("o")[1], "'o' e 'u' arredondam")
    conferir(boca_de("ã")[0] == boca_de("a")[0], "vogal nasal tem a boca da vogal")
    conferir(boca_de(" ") == (0.0, False) and boca_de("ˈ") == (0.0, False),
             "pausa e tonicidade nao mexem a boca")

    print("\n=== sintetizando ===")
    voz = Voz()
    fala = voz.falar("Mamãe, o Tr∅nikAt fala do DevLingo. Amanhã tem mais!")
    with wave.open(io.BytesIO(fala.wav)) as w:
        taxa, quadros = w.getframerate(), w.getnframes()
    conferir(abs(quadros / taxa - fala.duracao) < 0.01, "o WAV tem a duracao declarada",
             f"{quadros / taxa:.2f} s")
    fim = fala.bocas[-1][1]
    # O teste principal. Tolerancia de 2%: o arredondamento da reamostragem.
    conferir(abs(fim - fala.duracao) <= 0.02 * fala.duracao,
             "a boca termina junto com a voz", f"boca {fim:.2f} s, voz {fala.duracao:.2f} s")
    conferir(all(b[0] < b[1] for b in fala.bocas), "todo trecho de boca tem duracao positiva")
    conferir(all(a[1] <= b[0] + 1e-6 for a, b in zip(fala.bocas, fala.bocas[1:])),
             "os trechos nao se sobrepoem")
    conferir(any(b[2] == 0.0 for b in fala.bocas[1:-1]),
             "'Mamae' e 'Amanha' fecham a boca no meio da fala")
    conferir(fala.duracao < 1.2 * voz.falar("Mamãe, o Trônicat fala do Dév Língo. Amanhã tem mais!").duracao,
             "a grafia pronunciavel nao muda o tamanho da fala", f"TOM {TOM}")

    # AS PONTAS NAO PODEM TER SILENCIO, e este teste existe porque o defeito
    # era INAUDIVEL do lado de fora. O Piper deixa uma cauda em cada sintese:
    # medido em 17/09/2026, 37 ms no inicio e 236 ms no FIM. Entre duas falas
    # emendadas dava ~273 ms de nada, e numa sequencia de sete, quase 1,7 s.
    #
    # O Gustavo ouvia isso e reclamava de "muito espaco". Eu media do lado do
    # TOCADOR, onde o vao aparecia como 310 ms no total -- numero bom. O
    # silencio estava DENTRO da onda, e por isso nenhuma medicao de fluxo o
    # pegava. Se alguem tirar a aparagem, e exatamente isso que volta: sem erro,
    # sem teste vermelho, so a conversa arrastada de novo.
    import numpy as np
    with wave.open(io.BytesIO(fala.wav)) as w:
        a = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16)
    limite = max(300, int(np.abs(a).max() * 0.02))
    forte = np.flatnonzero(np.abs(a) > limite)
    ini, fim_s = forte[0] / taxa * 1000, (len(a) - forte[-1]) / taxa * 1000
    # 60 ms de teto para os 40 ms de margem que a aparagem deixa de proposito:
    # corte rente tira o ataque da primeira silaba e a queda da ultima.
    conferir(ini <= 60 and fim_s <= 60, "as pontas nao guardam silencio",
             f"inicio {ini:.0f} ms, fim {fim_s:.0f} ms")

    # O HUM NAO PODE SER SOLETRADO. O espeak le palavra sem vogal letra por
    # letra: "Hmmmm" virava 18 fonemas -- "a-ga e-me e-me e-me e-mi". Um hum de
    # pensar tem POUCOS trechos de boca; soletrado, tem muitos.
    # Mede o hum SOZINHO. A primeira versao deste teste usou "Hmmm, entao..." e
    # contou 12 trechos -- mas os de "entao" estavam na conta, entao o numero
    # nao media o hum. Mesma familia do erro ja registrado no CLAUDE.md, quando
    # medi altura para detectar um FittedBox que encolhe por transformacao.
    #
    # Controle medido: com o mapeamento sao 5 trechos; sem ele, 20. O teto de 8
    # fica no meio, com folga dos dois lados.
    hum = voz.falar("Hmmm")
    conferir(len(hum.bocas) <= 8, "o hum de pensar nao e soletrado",
             f"{len(hum.bocas)} trechos de boca")

    print(f"\n{'VOZ APROVADA' if not falhas else f'VOZ REPROVADA: {len(falhas)} falha(s)'}")
    return 1 if falhas else 0


if __name__ == "__main__":
    sys.exit(main())
