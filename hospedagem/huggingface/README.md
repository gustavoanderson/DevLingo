---
title: Tronikat
emoji: 🐱
colorFrom: purple
colorTo: pink
sdk: docker
app_port: 7860
pinned: false
short_description: O guia do DevLingo, com busca semântica e voz
---

# Tr∅nikAt

O guia do [DevLingo](https://github.com/gustavoanderson/DevLingo), um app Android para aprender programação em português.

Este Space é a **API** que o site do DevLingo chama. Ele roda em **modo fichas**:

1. a pergunta vira um embedding (`embeddinggemma:300m`, no processador);
2. a busca escolhe a ficha revisada mais próxima; abaixo da nota mínima (0,70), responde com uma frase fixa;
3. a resposta é o texto da ficha, falado pela voz Piper *faber*, com a linha do tempo da boca por fonema.

Não há modelo gerando texto aqui: o plano gratuito não tem placa de vídeo. A versão com o modelo gerador e o juiz de saída roda no PC do autor. O código-fonte é o mesmo, e só uma variável de ambiente (`ESTUDIO_GERAR=0`) muda o modo.

## Endpoints

| Método | Caminho | Resposta |
|---|---|---|
| `GET` | `/saude` | `{"ok": true, "modo": "fichas"}` |
| `POST` | `/perguntar` | corpo `{"pergunta": "..."}` (até 300 caracteres) → texto, áudio WAV em base64 e a linha do tempo da boca |

Os arquivos deste Space são gerados por `hospedagem/publicar_space.py`, no repositório do DevLingo. Não edite aqui: a fonte é lá.
