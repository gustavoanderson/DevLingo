"""Gera o que o Tr∅nikAt publico precisa, a partir de estudio/fichas.md.

No modo fichas ele so fala textos FIXOS (as fichas e a frase de recusa). Entao
a voz nao precisa de servidor: e gravada aqui, uma vez, e vira arquivo do site.
Na borda (Cloudflare Worker) sobra so a busca.

Tres saidas, do MESMO script, pela regra que ja vale para os cenarios do app:
arquivo gerado que passa a ser editado a mao diverge da fonte, e ninguem
descobre qual dos dois esta certo.

  hospedagem/cloudflare/src/fichas.json   perguntas-exemplo e piso (o Worker compara)
  site/falas/indice.json                  texto, duracao e boca de cada fala
  site/falas/<id>.wav                     o audio

Ate a fase 1 o Worker recebia SO as perguntas. Com a geracao na borda ele passou a
receber tambem a `resposta` de cada ficha, que e o material que ele reescreve --
e que ja era publico em site/falas/indice.json. Nao ha chave nem segredo ali.
Os textos moram no site, que ja e publico.

A voz do Piper tem aleatoriedade: gerar duas vezes nao da os mesmos bytes. Por
isso "em dia" compara a IMPRESSAO de cada fala (texto + voz + tom), e nao o WAV.

Uso (com o Python do estudio):
    estudio/.venv/Scripts/python.exe hospedagem/gerar_falas.py             # gera tudo
    estudio/.venv/Scripts/python.exe hospedagem/gerar_falas.py --conferir  # so confere, sem voz
"""
from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(RAIZ / "estudio"))

from base import ler_fichas                     # noqa: E402
from busca import PISO                          # noqa: E402
from porteiro import FRASE_FIXA                 # noqa: E402

FICHAS_JSON = RAIZ / "hospedagem" / "cloudflare" / "src" / "fichas.json"
FALAS = RAIZ / "site" / "falas"
INDICE = FALAS / "indice.json"
RECUSA = "_recusa"          # id da frase fixa; o sublinhado nunca colide com ficha

# AS FALAS DE ENROLAR, e por que elas existem.
#
# Medido em 17/09/2026, do envio ate a voz comecar: ~7,4 s o Worker pensando
# (modelo + juiz) e mais ~4 s o Piper sintetizando no Oracle. Onze segundos, e
# a maior parte deles em SILENCIO -- o texto aparece no meio do caminho, a voz
# so no fim.
#
# Ideia do Gustavo: enrolar. Como estas ficam GRAVADAS, elas tocam em zero
# segundo -- nao passam pelo Piper na hora, nem pelo Oracle, nem por nada. Sao
# a unica coisa no site que responde instantaneamente.
#
# A regra de escrita, e ela e o ponto: NENHUMA pode prometer nada. "Ah, essa eu
# sei!" soa otimo ate ser seguido de "nao sei". Todas servem antes de qualquer
# resposta, inclusive antes de uma recusa.
#
# Duram de 2 a 4 s. Quando a espera passa disso, o site toca outra -- e duas
# seguidas soam como alguem que ainda esta pensando, nao como repeticao.
ENROLAR = [
    "Hmmmm... deixa eu processar isso aqui.",
    "Boa pergunta. So um instante que o visor ta calculando.",
    "Certo, certo... ja te respondo.",
    "Perai que eu puxo isso da memoria.",
    "Hmmm. Essa merece uma olhada com calma.",
    "Deixa eu organizar as ideias aqui...",
    "To processando. Segura ai um segundinho.",
    "Interessante. Rodando aqui no meu circuito...",
    "Anotado. Deixa eu montar a resposta direito.",
    "Hmmmm, perai. To cruzando os dados.",
]


def textos() -> dict[str, str]:
    t = {f.id: f.resposta for f in ler_fichas()}
    t[RECUSA] = FRASE_FIXA
    # O prefixo `_enrolar` e o que o site procura para sortear uma delas.
    for i, frase in enumerate(ENROLAR, 1):
        t[f"_enrolar-{i:02d}"] = frase
    return t


def impressao(texto: str) -> str:
    import voz
    # LENTIDAO entra aqui senao mexer nela nao regrava nada, e os WAVs
    # ficariam na velocidade antiga sem ninguem perceber.
    base = f"{texto}|{Path(voz.MODELO).name}|{voz.TOM}|{voz.LENTIDAO}|{voz.PRONUNCIA}"
    return hashlib.sha1(base.encode("utf-8")).hexdigest()[:16]


def json_do_worker() -> str:
    # A `resposta` entrou na FASE 1 (geracao na borda): sem ela o Worker nao tem
    # o que reescrever. Isso NAO expoe nada novo -- os mesmos textos ja sao
    # publicos em site/falas/indice.json, servido em HTTP 200 com 346 KB.
    fichas = [{"id": f.id, "perguntas": f.perguntas, "resposta": f.resposta}
              for f in ler_fichas()]
    return json.dumps({"piso": PISO, "fichas": fichas}, ensure_ascii=False, indent=1) + "\n"


def conferir() -> list[str]:
    erros = []
    if not FICHAS_JSON.exists() or FICHAS_JSON.read_text(encoding="utf-8") != json_do_worker():
        erros.append(f"{FICHAS_JSON.relative_to(RAIZ)} difere de fichas.md")
    indice = json.loads(INDICE.read_text(encoding="utf-8")) if INDICE.exists() else {}
    esperado = textos()
    for fid, texto in esperado.items():
        fala = indice.get(fid)
        if not fala:
            erros.append(f"fala faltando: {fid}")
        elif fala["impressao"] != impressao(texto):
            erros.append(f"fala desatualizada: {fid}")
        elif not (FALAS / fala["audio"]).exists():
            erros.append(f"audio faltando: {fala['audio']}")
    for fid in set(indice) - set(esperado):
        erros.append(f"fala sobrando (ficha removida?): {fid}")
    return erros


def gerar() -> None:
    from voz import Voz
    FICHAS_JSON.write_text(json_do_worker(), encoding="utf-8", newline="\n")
    FALAS.mkdir(parents=True, exist_ok=True)
    antigo = json.loads(INDICE.read_text(encoding="utf-8")) if INDICE.exists() else {}
    v = Voz()
    indice = {}
    for fid, texto in textos().items():
        imp = impressao(texto)
        # So regrava o que mudou: cada regravacao troca os bytes do WAV e poluiria o historico.
        if antigo.get(fid, {}).get("impressao") == imp and (FALAS / antigo[fid]["audio"]).exists():
            indice[fid] = antigo[fid]
            continue
        fala = v.falar(texto)
        (FALAS / f"{fid}.wav").write_bytes(fala.wav)
        indice[fid] = {"texto": texto, "duracao": round(fala.duracao, 3),
                       "bocas": fala.bocas, "audio": f"{fid}.wav", "impressao": imp}
        print(f"  gravada {fid:22s} {fala.duracao:5.1f} s")
    for fid in set(antigo) - set(indice):
        (FALAS / antigo[fid]["audio"]).unlink(missing_ok=True)
        print(f"  removida {fid}")
    INDICE.write_text(json.dumps(indice, ensure_ascii=False, indent=1) + "\n", encoding="utf-8", newline="\n")


def main() -> int:
    if "--conferir" in sys.argv:
        erros = conferir()
        for e in erros:
            print(f"  [ERRO] {e}")
        print("FALAS EM DIA" if not erros else f"FALAS DESATUALIZADAS: {len(erros)}")
        return 1 if erros else 0
    gerar()
    erros = conferir()
    print("FALAS EM DIA" if not erros else f"ainda com erro: {erros}")
    return 1 if erros else 0


if __name__ == "__main__":
    sys.exit(main())
