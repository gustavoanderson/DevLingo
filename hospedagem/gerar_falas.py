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
import re
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
# (modelo + juiz) e mais ~4 s o Piper sintetizando. Onze segundos, e a maior
# parte deles em SILENCIO.
#
# Ideia do Gustavo: enrolar. Como estas ficam GRAVADAS, elas tocam em zero
# segundo -- nao passam pelo Piper na hora, nem pelo Oracle. Sao a unica coisa
# do site que responde instantaneamente.
#
# ELAS TEM PAPEL, E NAO SAO UM MONTE SO. A primeira versao sorteava de uma
# lista unica, e o resultado que ele ouviu foi:
#
#   "perai, deixa eu processar a informacao"
#   "voce perguntou o que e tal coisa?"
#   "deixa eu processar"
#
# Duas vezes "processar", porque as duas pontas sorteavam do mesmo saco. Hoje
# a sequencia tem tres papeis distintos, na ordem que ele desenhou:
#
#   1. ABERTURA  -- "bom, vamos la"          (reconhece que ouviu)
#   2. ECO       -- a pergunta dele de volta (ganha tempo, e cresce com ela)
#   3. PENSANDO  -- "hmmm, entao..."         (ainda trabalhando)
#
# A regra que vale para as duas listas: NENHUMA pode prometer nada. "Ah, essa
# eu sei!" soa otimo ate ser seguido de "nao sei". Todas tem de servir antes de
# qualquer resposta, inclusive antes de uma recusa.
#
# A abertura e curta de proposito: ela so precisa durar ate o eco ficar pronto.
# TODA FRASE ABRE DE UM JEITO DIFERENTE, e isso e medido, nao estilo.
#
# O Gustavo ouviu "ah, hum, ta" e logo depois "ah, hmm, entendi", e disse: "ta
# muito fake isso, nao pode repetir tanto assim". A medicao deu razao a ele com
# folga -- nas 13 frases antigas, "Certo" abria 3, "Hmmm" abria 3, "Ta" e "Ah"
# abriam 2 cada, e "Deixa eu" aparecia em 5. Simulando o sorteio, **78% das
# conversas** repetiam uma abertura.
#
# Eu tinha PIORADO isso no mesmo dia: ao mapear "Hmmm" para "Ah, hum", as tres
# frases que comecavam com "Hmmm" passaram a abrir identicas e mais longas, o
# que tornou a colisao obvia em vez de discreta.
#
# A regra agora e uma so, e o `conferir_aberturas` abaixo a faz valer: nenhuma
# frase abre com a mesma palavra de outra. Com 13 aberturas distintas, repetir
# deixa de ser improvavel e passa a ser impossivel.
ABERTURA = [
    "Bom, vamos lá.",
    "Opa. Vou olhar isso.",
    "Beleza. Já começo a pensar.",
    "Legal, gostei da pergunta.",
    "Saquei. Vamos nessa.",
]

# A MOLDURA DO ECO, gravada -- e a razao e medida, nao estetica.
#
# O eco era sintetizado inteiro, moldura mais pergunta. Medido em 17/09/2026,
# com a maquina de UM nucleo:
#
#   a resposta sozinha .................. 6,15 s de sintese
#   a resposta com o eco em paralelo .... 11,54 s
#
# O eco ATRASAVA a resposta em 5,4 s. A peca que existia para cobrir a espera
# causava quase metade dela, porque as duas sinteses disputam o mesmo nucleo.
#
# A moldura e texto FIXO, entao pode ser gravada e custa zero. So o assunto --
# tres a seis palavras, depois da limpeza -- precisa de CPU.
ECO = [
    "Então você tá querendo saber...",
    "Ah, entendi. Você quer saber sobre...",
    "Certo. Você tá perguntando sobre...",
]

PENSANDO = [
    # O HUM VIVE AQUI, e em MAIS NENHUM lugar. Ele era o tique mais audivel
    # justamente por estar em tres das cinco: bastava o sorteio tirar duas
    # delas -- 30% das vezes -- para a mesma hesitacao sair duas vezes seguidas.
    # Numa frase so, repetir na mesma conversa e impossivel.
    "Hmmm, quase lá.",
    "Tá. Já te falo.",
    "Pera aí que eu organizo isso.",
    "Olha, já já sai.",
    # O unico "Deixa eu" do catalogo. Ele aparecia em 5 das 13 frases, e tique
    # de vocabulario cansa tanto quanto abertura repetida.
    "Deixa eu montar a resposta.",
]


def textos() -> dict[str, str]:
    t = {f.id: f.resposta for f in ler_fichas()}
    t[RECUSA] = FRASE_FIXA
    # Os prefixos sao o que o site usa para sortear DENTRO do papel certo.
    for i, frase in enumerate(ABERTURA, 1):
        t[f"_abrir-{i:02d}"] = frase
    for i, frase in enumerate(PENSANDO, 1):
        t[f"_pensar-{i:02d}"] = frase
    for i, frase in enumerate(ECO, 1):
        t[f"_eco-{i:02d}"] = frase
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


# PALAVRAS QUE SO EXISTEM COM ACENTO, e o portao que as exige.
#
# Em 21/09/2026 o Gustavo ouviu o Tr∅nikAt dizer "comeco" com som de K, e
# "voce" com a tonica na silaba errada. As 13 frases de enrolacao estavam em
# ASCII puro -- eu apliquei a texto FALADO a convencao que o repositorio tem
# para CODIGO.
#
# O estrago, medido com os fonemas do espeak:
#
#   comeco   -> kˌomˈɛkʊ   |  começo -> kˌomˈesʊ
#   voce     -> vˈɔsɪ      |  você   -> vosˈe     (a tonica MUDA de lugar)
#   nao      -> nˈaʊ       |  não    -> nˈɐ̃ʊ̃      (perde a nasalizacao)
#   la       -> la         |  lá     -> lˈa       (fica SEM tonica)
#   Entao    -> ẽntˈaʊ     |  Então  -> ẽntˈɐ̃ʊ̃
#
# Nada disso quebra: o audio e gerado, o teste passa, o site toca. So quem
# ouve percebe -- e foi assim que passou por duas sessoes inteiras.
#
# A lista e curta de proposito: so palavras comuns em fala espontanea cuja
# versao sem acento EXISTE e soa diferente. Nao e um corretor ortografico.
SEM_ACENTO = {
    "nao": "não", "voce": "você", "ja": "já", "ta": "tá", "la": "lá",
    "entao": "então", "comeco": "começo", "tambem": "também", "esta": "está",
    "sera": "será", "aqui": None, "porque": None, "vamos": None,
    "ai": "aí", "so": "só", "ate": "até", "voces": "vocês", "e": None,
}


def conferir_acentos() -> list[str]:
    """Recusa gravar frase falada com palavra que perdeu o acento.

    Roda sobre TODAS as falas, nao so as de enrolacao: ficha nova escrita as
    pressas cai no mesmo buraco, e ficha vira audio gravado.
    """
    erros = []
    for chave, frase in textos().items():
        # O hifen NAO separa: "reabri-la" e uma palavra so, e o pronome
        # enclitico -la nao leva acento. Sem isto a regra reprovava conteudo
        # correto -- e falso positivo ensina a contornar o portao em vez de
        # confiar nele.
        for cru in re.findall(r"[A-Za-zÀ-ÿ]+(?:-[A-Za-zÀ-ÿ]+)*", frase):
            certo = SEM_ACENTO.get(cru.lower())
            if certo:
                erros.append(f'{chave}: "{cru}" deveria ser "{certo}" -- {frase}')
    return erros


def conferir_aberturas() -> list[str]:
    """Nenhuma frase de enrolacao pode abrir com a mesma palavra de outra.

    Este portao existe porque o defeito era INAUDIVEL uma frase por vez: cada
    uma soa bem sozinha, e o "fake" so aparece quando duas caem na mesma
    conversa. Escrevendo mais uma frase daqui a um mes, ninguem vai lembrar de
    conferir as outras doze -- entao quem confere e o gerador, antes de gravar.

    Vale tambem para o "Deixa eu": tique de vocabulario cansa tanto quanto
    abertura repetida, e ele ja chegou a estar em 5 das 13 frases.
    """
    frases = ABERTURA + ECO + PENSANDO
    erros, vistas = [], {}
    for f in frases:
        # A abertura e o que vem antes da primeira virgula ou ponto.
        chave = re.split(r"[,.]", f)[0].strip().lower()
        if chave in vistas:
            erros.append(f'abrem igual ("{chave}"): "{vistas[chave]}" e "{f}"')
        vistas[chave] = f
    tique = [f for f in frases if "deixa eu" in f.lower()]
    if len(tique) > 1:
        erros.append(f'"Deixa eu" em {len(tique)} frases, e so pode haver uma: {tique}')
    return erros


def main() -> int:
    colisoes = conferir_aberturas() + conferir_acentos()
    if colisoes:
        for c in colisoes:
            print(f"  [ERRO] {c}")
        print(f"FALAS REPROVADAS: {len(colisoes)} problema(s). Nada foi gravado.")
        return 1
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
