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

    print(f"\n{'VOZ APROVADA' if not falhas else f'VOZ REPROVADA: {len(falhas)} falha(s)'}")
    return 1 if falhas else 0


if __name__ == "__main__":
    sys.exit(main())
