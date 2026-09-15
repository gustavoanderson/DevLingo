# O Tr∅nikAt no Hugging Face Spaces, em MODO FICHAS.
#
# O plano gratuito nao tem placa de video. Por isso aqui so rodam as duas pecas
# que o processador aguenta bem: a busca (embeddinggemma, 300M) e a voz (Piper).
# O modelo gerador fica no PC do Gustavo. Ver estudio/porteiro.py (gerar=False).
#
# Versoes FIXAS, iguais as do PC onde o piso 0,70 foi calibrado: outra versao do
# Ollama ou do modelo pode mudar as notas da busca sem erro nenhum aparecer.
FROM python:3.12-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends curl ca-certificates zstd \
 && rm -rf /var/lib/apt/lists/*

ARG OLLAMA_VERSION=0.34.0
RUN curl -fsSL https://ollama.com/install.sh | OLLAMA_VERSION=${OLLAMA_VERSION} sh

# O Spaces roda o conteiner como o usuario 1000; tudo que ele escreve mora no home.
RUN useradd -m -u 1000 user
USER user
ENV HOME=/home/user \
    PATH=/home/user/.local/bin:$PATH \
    PYTHONUNBUFFERED=1 \
    OLLAMA_HOST=127.0.0.1:11434 \
    OLLAMA_MODELS=/home/user/ollama-models \
    ESTUDIO_HOST=0.0.0.0 \
    ESTUDIO_PORTA=7860 \
    ESTUDIO_GERAR=0 \
    ESTUDIO_KEEP_ALIVE=24h \
    ESTUDIO_VOZ=/home/user/vozes/pt_BR-faber-medium.onnx
WORKDIR /home/user/app

COPY --chown=user requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# Voz faber: dataset CC0 (MODEL_CARD da rhasspy/piper-voices).
ARG VOZ=https://huggingface.co/rhasspy/piper-voices/resolve/main/pt/pt_BR/faber/medium
RUN mkdir -p /home/user/vozes \
 && curl -fsSL -o /home/user/vozes/pt_BR-faber-medium.onnx      "$VOZ/pt_BR-faber-medium.onnx" \
 && curl -fsSL -o /home/user/vozes/pt_BR-faber-medium.onnx.json "$VOZ/pt_BR-faber-medium.onnx.json"

# O modelo de embedding entra na IMAGEM, e nao na partida: baixar a cada vez
# que o Space acorda somaria ~600 MB a espera do primeiro visitante.
RUN ollama serve & PID=$! \
 && until curl -sf http://127.0.0.1:11434/api/version > /dev/null; do sleep 1; done \
 && ollama pull embeddinggemma:300m \
 && kill $PID

COPY --chown=user app/ ./
EXPOSE 7860
CMD ["sh", "iniciar.sh"]
