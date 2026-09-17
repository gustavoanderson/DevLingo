# Pôr a voz do Tr∅nikAt no ar

Roteiro para subir `hospedagem/voz_servico.py` numa máquina do **Oracle Cloud Always Free**, e ligá-la ao site por um túnel da Cloudflare.

Ao terminar, o site passa a ter **uma voz só**: as fichas continuam tocando o áudio gravado, e o texto gerado ganha a mesma voz do Piper, com a boca por fonema.

---

## Antes de começar, o que esperar

| | |
|---|---|
| Custo | **zero** — Always Free e túnel gratuito |
| Tempo | cerca de uma hora, quase toda esperando a máquina criar |
| O que precisa de cartão | a Oracle pede cartão no cadastro e **não cobra** no Always Free |
| Risco de conta | criar a instância errada sai do Always Free e **cobra**. O passo 2 diz exatamente qual escolher |

**Nenhuma porta é aberta para a internet.** O túnel faz conexão de dentro para fora, então a máquina não fica exposta — não há regra de firewall para errar, e não há IP público para alguém varrer.

---

## 1. Criar a conta

<https://www.oracle.com/cloud/free/>

Escolha a região mais perto (São Paulo, `sa-saopaulo-1`, ou Vinhedo, `sa-vinhedo-1`). **A região não muda depois.**

> Se aparecer *"Out of capacity"* ao criar a máquina no passo 2, é comum no ARM gratuito: tente outra hora ou a outra região brasileira.

## 2. Criar a máquina — e é aqui que dá para errar

No menu, **Compute → Instances → Create instance**.

| Campo | Valor |
|---|---|
| Image | **Ubuntu 24.04** |
| Shape | **Ampere → VM.Standard.A1.Flex** |
| OCPUs | **2** |
| Memória | **8 GB** |
| Chave SSH | **baixe a chave privada** e guarde |

**Confira que aparece "Always Free eligible" na tela antes de criar.** O padrão da Oracle é um shape Intel que **não** é gratuito. O A1.Flex é, dentro de 4 OCPU e 24 GB somados em todas as instâncias — e desde junho de 2026 a conta nova costuma vir com metade disso, o que ainda sobra: a voz usa um núcleo por vez.

Anote o **IP público** ao terminar. Ele serve só para você entrar por SSH.

## 3. Entrar

```bash
chmod 600 sua-chave.key
ssh -i sua-chave.key ubuntu@SEU_IP
```

## 4. Instalar o que a voz precisa

```bash
sudo apt update && sudo apt install -y python3-venv python3-pip espeak-ng
mkdir -p ~/voz && cd ~/voz
python3 -m venv .venv
.venv/bin/pip install --upgrade pip
.venv/bin/pip install "piper-tts[alignment]" numpy onnx
```

`espeak-ng` não é opcional: é ele que transforma o texto em fonemas, e são os fonemas que movem a boca.

**Isto é o único passo não medido deste roteiro.** As medições do Piper foram feitas no desktop x86 do Gustavo; em ARM Ampere ninguém mediu. Há folga grande — 6,2× mais rápido que tempo real —, então mesmo 3× mais lento sobra o dobro. O passo 7 mede.

## 5. Mandar os arquivos

Da sua máquina, no diretório do repositório:

```bash
scp -i sua-chave.key estudio/voz.py hospedagem/voz_servico.py ubuntu@SEU_IP:~/voz/
scp -i sua-chave.key "D:/dev/piper-vozes/pt_BR-faber-medium.onnx"      ubuntu@SEU_IP:~/voz/
scp -i sua-chave.key "D:/dev/piper-vozes/pt_BR-faber-medium.onnx.json" ubuntu@SEU_IP:~/voz/
```

O `.json` vai junto **sempre**: sem ele o Piper não sabe a taxa de amostragem nem o alfabeto de fonemas do modelo.

O `voz_servico.py` procura o `voz.py` em `../estudio/`. Na máquina os dois ficam lado a lado, então diga onde está a voz por variável de ambiente (passo 6).

## 6. Deixar rodando sozinho

```bash
sudo tee /etc/systemd/system/voz.service >/dev/null <<'FIM'
[Unit]
Description=Voz do Tronikat
After=network.target

[Service]
User=ubuntu
WorkingDirectory=/home/ubuntu/voz
Environment=ESTUDIO_VOZ=/home/ubuntu/voz/pt_BR-faber-medium.onnx
Environment=PYTHONPATH=/home/ubuntu/voz
Environment=VOZ_PORTA=8770
ExecStart=/home/ubuntu/voz/.venv/bin/python /home/ubuntu/voz/voz_servico.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
FIM

sudo systemctl enable --now voz
sleep 20 && curl -s localhost:8770/saude
```

Tem que sair algo como `{"ok": true, "voz": "pt_BR-faber-medium.onnx", "carga_s": ...}`.

Se não sair: `sudo journalctl -u voz -n 40 --no-pager`.

## 7. Medir no ARM antes de seguir

```bash
curl -s -X POST localhost:8770/falar -H 'Content-Type: application/json' \
  -d '{"texto":"Tr∅nikAt na escuta. Câmbio."}' \
  | python3 -c "import json,sys; r=json.load(sys.stdin); \
print('audio', r['duracao'],'s | sintese', r['sintese_s'],'s | razao', round(r['duracao']/r['sintese_s'],1),'x')"
```

| Resultado | O que fazer |
|---|---|
| razão **acima de 2×** | ótimo, siga |
| entre **1× e 2×** | funciona, mas a fala demora a começar; me avise |
| **abaixo de 1×** | mais lento que tempo real; me mande o número, o desenho muda |

No desktop deu **6,2×**.

## 8. O túnel, que é o que dá HTTPS

O site é HTTPS. Chamar `http://SEU_IP` seria bloqueado pelo navegador como conteúdo misto — por isso túnel, e não IP direto.

```bash
curl -L -o cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64
chmod +x cloudflared && sudo mv cloudflared /usr/local/bin/

cloudflared tunnel login          # abre uma URL: abra no seu navegador e autorize
cloudflared tunnel create voz-tronikat
cloudflared tunnel route dns voz-tronikat voz.SEUDOMINIO
```

**Se você não tem domínio na Cloudflare**, pule o `route dns` e use o túnel rápido, que dá um endereço `trycloudflare.com` pronto:

```bash
cloudflared tunnel --url http://localhost:8770
```

> O endereço do túnel rápido **muda a cada reinício**. Serve para provar que funciona hoje; para ficar no ar, vale registrar um domínio na Cloudflare (há domínios baratos) e usar o túnel nomeado com systemd.

Para o túnel nomeado ficar sozinho:

```bash
sudo cloudflared service install
sudo systemctl enable --now cloudflared
```

## 9. Ligar o site à voz

Duas edições no repositório, e o Gustavo decide quando:

**1.** Em `site/index.html`, preencha o endereço:

```js
const VOZ_URL = 'https://voz.SEUDOMINIO';
```

**2.** Em `hospedagem/voz_servico.py`, acrescente a origem do site se ela mudar (a do GitHub Pages já está lá).

**3.** Em `hospedagem/cloudflare/wrangler.toml`, **apague a linha `GERAR = "nao"`** — é ela que hoje mantém o Tr∅nikAt respondendo só por ficha, para o site ter uma voz só enquanto a voz nova não existe.

Depois:

```bash
cd hospedagem/cloudflare && npx wrangler deploy
estudio/.venv/Scripts/python.exe hospedagem/calibrar_borda.py
```

## 10. Conferir que fechou

- Abra o site e pergunte algo que **não** esteja nas fichas
- A resposta tem de sair **na voz do Tr∅nikAt**, não na do navegador
- A boca tem de acompanhar as sílabas, e não abrir e fechar no ritmo genérico
- `curl -s https://voz.SEUDOMINIO/saude` mostra quantas falas foram sintetizadas e quantas vieram do cache

---

## Quando algo der errado

| Sintoma | Causa provável |
|---|---|
| O site não fala, e o console diz **CORS** | a origem do site não está em `ORIGENS`, no `voz_servico.py` |
| O site não fala, e o console diz **Mixed Content** | `VOZ_URL` está em `http://`. Tem de ser o endereço do túnel, em `https://` |
| `429` nas respostas | o limitador cortou: são 12 falas em rajada e meia por segundo depois. Se for uso real, aumente `BALDE_MAX` |
| A voz volta mas a boca fica parada | faltou `espeak-ng`, ou o `.onnx.json` não subiu |
| A máquina some depois de semanas | a Oracle recicla instância Always Free **ociosa**. O túnel mantém tráfego, o que ajuda; se sumir, recrie |
