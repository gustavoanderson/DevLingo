"""Monta e publica o Space do Tr∅nikAt no Hugging Face.

O Space e um repositorio SEPARADO, e isso e um risco: se alguem editar la, o
codigo do Space e o do DevLingo divergem em silencio. Por isso a fonte e sempre
esta aqui -- o script copia os arquivos certos e publica. O README do Space avisa.

Duas protecoes que custariam caro se faltassem:
- SO ENTRA O QUE ESTA NA LISTA. O estudio tem resultados de medicao, venv e
  audio de teste; nada disso vai para um repositorio publico
- FIM DE LINHA LF. Este repositorio usa core.autocrlf=true; um iniciar.sh com
  CRLF quebra no Linux com "set: Illegal option -" e nada aponta o motivo

O token NUNCA vai em arquivo do repositorio: vem da variavel HF_TOKEN ou do
login salvo por `hf auth login` (fica no perfil do usuario, fora daqui).

Uso (com o Python do estudio, que tem o huggingface_hub):
    estudio/.venv/Scripts/python.exe hospedagem/publicar_space.py            # so monta e lista
    estudio/.venv/Scripts/python.exe hospedagem/publicar_space.py --publicar USUARIO/tronikat
"""
from __future__ import annotations

import os
import shutil
import sys
import tempfile
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
SPACE = RAIZ / "hospedagem" / "huggingface"
ESTUDIO = RAIZ / "estudio"

# destino no Space -> origem no DevLingo
ARQUIVOS = {
    "Dockerfile": SPACE / "Dockerfile",
    "README.md": SPACE / "README.md",
    "requirements.txt": SPACE / "requirements.txt",
    "app/iniciar.sh": SPACE / "iniciar.sh",
    "app/servidor.py": ESTUDIO / "servidor.py",
    "app/porteiro.py": ESTUDIO / "porteiro.py",
    "app/busca.py": ESTUDIO / "busca.py",
    "app/base.py": ESTUDIO / "base.py",
    "app/voz.py": ESTUDIO / "voz.py",
    "app/fichas.md": ESTUDIO / "fichas.md",
}


def montar(destino: Path) -> list[str]:
    for nome, origem in ARQUIVOS.items():
        alvo = destino / nome
        alvo.parent.mkdir(parents=True, exist_ok=True)
        texto = origem.read_text(encoding="utf-8").replace("\r\n", "\n")
        alvo.write_bytes(texto.encode("utf-8"))
    return sorted(ARQUIVOS)


def main() -> int:
    montagem = Path(tempfile.mkdtemp(prefix="space-tronikat-"))
    try:
        for nome in montar(montagem):
            bruto = (montagem / nome).read_bytes()
            print(f"  {nome:22s} {len(bruto):7d} bytes{'  (CRLF!)' if b'\r\n' in bruto else ''}")
        if "--publicar" not in sys.argv:
            print("\nso montado. Para publicar: --publicar USUARIO/tronikat, com HF_TOKEN definido")
            return 0
        repo = sys.argv[sys.argv.index("--publicar") + 1]
        from huggingface_hub import HfApi, get_token
        # HF_TOKEN no terminal, ou o login salvo por "hf auth login". Nunca arquivo do repo.
        token = os.environ.get("HF_TOKEN") or get_token()
        if not token:
            print("faca login antes: estudio/.venv/Scripts/hf.exe auth login (token com permissao de escrita)")
            return 1
        api = HfApi(token=token)
        print(f"publicando como: {api.whoami()['name']}")
        api.create_repo(repo, repo_type="space", space_sdk="docker", exist_ok=True)
        api.upload_folder(folder_path=str(montagem), repo_id=repo, repo_type="space",
                          commit_message="Publica o Tr∅nikAt a partir do repositorio DevLingo",
                          delete_patterns=["*"])
        print(f"\npublicado: https://huggingface.co/spaces/{repo}")
        return 0
    finally:
        shutil.rmtree(montagem, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
