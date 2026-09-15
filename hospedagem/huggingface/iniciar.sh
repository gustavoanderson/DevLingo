#!/bin/sh
# Sobe o Ollama (so para o embedding) e, quando ele responder, o servidor do estudio.
set -e
ollama serve &
until curl -sf http://127.0.0.1:11434/api/version > /dev/null; do sleep 1; done
exec python servidor.py
