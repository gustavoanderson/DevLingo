"""Os "olhos" do porteiro: transformar texto em embedding e comparar.

Modulo compartilhado entre o porteiro (que roda) e o calibrador (que mede).
Existe separado para que o programa de verdade nunca dependa de um script de
medicao: mexer no teste nao pode quebrar o produto.

Os numeros daqui foram medidos em 14/09/2026; a justificativa de cada um esta
no cabecalho de calibrar_busca.py.
"""
from __future__ import annotations

import json
import math
import urllib.request

# 127.0.0.1, e NUNCA "localhost". No Windows, localhost resolve primeiro para o
# IPv6 (::1); o Ollama escuta so no IPv4; o cliente espera a tentativa IPv6
# desistir e so entao tenta de novo. Medido: 2.168 ms com localhost, 108 ms
# com 127.0.0.1 -- os 2 segundos sumiam FORA do Ollama, antes de a requisicao
# chegar nele, e por isso nao apareciam em nenhuma duracao registrada por ele.
OLLAMA = "http://127.0.0.1:11434"

MODELO_EMBEDDING = "embeddinggemma:300m"   # 45/50 fichas certas, carga em ~10 s
PISO = 0.70                                # manobras 0/5, gerais 0/12, legitimas 43/50

# Cada modelo tem o formato de entrada usado no treino dele. Usar o formato
# errado nao da erro nenhum -- so piora a busca em silencio (o Qwen3 caiu de
# 42/50 para 22/50 assim).
FORMATOS = {
    "embeddinggemma:300m": lambda t: f"task: sentence similarity | query: {t}",
    "qwen3-embedding:0.6b": lambda t: t,
}


def chamar(caminho: str, corpo: dict, tempo: int = 600) -> dict:
    req = urllib.request.Request(OLLAMA + caminho, data=json.dumps(corpo).encode(),
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=tempo) as r:
        return json.loads(r.read().decode("utf-8"))


def embed(textos: list[str], modelo: str = MODELO_EMBEDDING) -> list[list[float]]:
    return chamar("/api/embed", {
        "model": modelo,
        "input": [FORMATOS[modelo](t) for t in textos],
        "keep_alive": "30m",
        # num_gpu 0 = CPU. A placa e do modelo que fala (3,2 GB de 4 GB); o
        # porteiro nao pode tira-lo de la para conseguir enxergar. Na CPU a
        # busca leva ~120 ms.
        "options": {"num_gpu": 0},
    })["embeddings"]


def cosseno(a: list[float], b: list[float]) -> float:
    pa = math.sqrt(sum(x * x for x in a)) or 1
    pb = math.sqrt(sum(x * x for x in b)) or 1
    return sum(x * y for x, y in zip(a, b)) / (pa * pb)


def ranking(vetor: list[float], rotulados: list[tuple[str, list[float]]]) -> list[tuple[str, float]]:
    """Rotulos do mais parecido para o menos. A nota de um rotulo e a do seu
    vetor mais parecido -- uma ficha vale pela sua melhor pergunta-exemplo."""
    melhor: dict[str, float] = {}
    for rotulo, v in rotulados:
        s = cosseno(vetor, v)
        if s > melhor.get(rotulo, -1.0):
            melhor[rotulo] = s
    return sorted(melhor.items(), key=lambda kv: kv[1], reverse=True)
