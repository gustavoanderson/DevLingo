# Pôr a voz do Tr∅nikAt no ar

Roteiro para subir `hospedagem/voz_servico.py` numa máquina do **Oracle Cloud Always Free**.

Ao terminar, o texto que o Tr∅nikAt gera passa a sair **na voz dele**, com a boca acompanhando as sílabas — a mesma voz que as 31 fichas já têm gravada.

---

## Como isto se liga

```
navegador  --HTTPS-->  Worker da Cloudflare  --HTTP-->  máquina do Oracle
              (já existe)     (a ponte)        + chave      (a voz)
```

**O Worker é a ponte, e é ele que resolve o HTTPS.** Navegador não busca em HTTP puro; Worker busca. Por isso a máquina não precisa de domínio, nem de certificado, nem de túnel — e some do seu dia a parte mais chata.

O preço é uma porta aberta na máquina, defendida por uma chave secreta que só o Worker manda.

> ⚠️ **A PORTA É 8080, E NÃO PODE SER QUALQUER UMA.**
>
> Cloudflare Workers só conseguem buscar em portas de uma lista fechada. Para
> HTTP são **80, 8080, 8880, 2052, 2082, 2086, 2095** (e as de HTTPS são outras).
>
> Isto custou uma rodada em 17/09/2026: o serviço subiu na 8770, ficou
> respondendo perfeitamente de fora — `curl` direto devolvia `200` —, e mesmo
> assim o Worker só dava `voz indisponivel`. O `fetch` dele é recusado **antes
> de sair**, então o sintoma não aparece em lugar nenhum do lado da máquina.
>
> Se um dia precisar mudar a porta, escolha dentro daquela lista.

> ⚠️ **E O ENDERECO PRECISA SER UM NOME, NUNCA UM IP.**
>
> Workers tambem nao buscam em IP puro. O `fetch` para `http://136.248.107.142:8080`
> e interceptado pela propria Cloudflare e volta como **`error code: 1003`**
> (*Direct IP access not allowed*) -- de novo sem deixar rastro do lado da maquina.
>
> A saida sem comprar dominio e **sslip.io**: um DNS curinga gratuito e sem
> cadastro em que o proprio nome carrega o IP. O endereco vira
> `http://136.248.107.142.sslip.io:8080`.
>
> As duas armadilhas juntas custaram tres rodadas em 17/09/2026, e nenhuma
> aparecia em log nenhum ate o Worker passar a registrar o erro do `fetch`
> (`console.error` no `catch` de `/falar`, visivel em `npx wrangler tail`).

| | |
|---|---|
| Custo | **zero** |
| Tempo | ~1 hora, a maior parte esperando a Oracle |
| Cartão | a Oracle pede no cadastro e **não cobra** no Always Free |
| O que você edita no repositório | **nada** — só define duas variáveis na Cloudflare |

**Se travar em qualquer passo, me manda a saída do comando.** Vários passos aqui têm uma armadilha conhecida, e elas estão marcadas.

---

# Parte 1 — A conta (~20 min, quase tudo esperando)

1. Vá em <https://www.oracle.com/cloud/free/> e clique em **Start for free**.
2. País **Brazil**, seu nome, seu e-mail. Confirme o e-mail que chegar.
3. Crie a senha. Em *Company name* pode pôr qualquer coisa (`DevLingo` serve).
4. **Escolha a região: `Brazil East (Sao Paulo)`.**

   > ⚠️ **A região não muda depois.** É a única escolha irreversível do roteiro. Se São Paulo não aparecer, use `Brazil Southeast (Vinhedo)`.

5. Cadastre o cartão. A Oracle faz uma reserva de cerca de US$ 1 e devolve — não é cobrança.
6. Ela leva de 5 a 15 minutos para provisionar a conta e manda um e-mail. Espere.

> ⚠️ **Não aceite "Upgrade to Pay As You Go"** em nenhuma tela. É o que tira você do gratuito.

---

# Parte 2 — A máquina (~10 min, e é onde dá para errar)

No console, menu ☰ (canto superior esquerdo) → **Compute** → **Instances** → **Create instance**.

| Campo | O que pôr |
|---|---|
| **Name** | `voz-tronikat` |
| **Compartment** | deixe o que já vem |
| **Placement** | deixe o que já vem |

### Imagem e formato — o passo crítico

Clique em **Edit** na caixa *Image and shape*.

**Change image** → aba **Canonical Ubuntu** → marque **Ubuntu 24.04** → *Select image*.

**Change shape** → abre a tela *Browse all shapes*.

Nela, procure a fileira **Shape series**, logo abaixo de *Virtual machine*. São
quatro **cartões** lado a lado:

```
[ AMD ]   [ Intel ]   [ Ampere ]   [ Specialty and previous generation ]
                         ^^^^                        ^^^^
                   "Arm-based processor"      costuma vir SELECIONADO
```

> ⚠️ **O Ampere é um cartão, e não uma aba — e ele não vem selecionado.**
>
> A Oracle costuma abrir essa tela com *Specialty and previous generation*
> marcado, e aí a lista de baixo mostra só AMD (`VM.Standard.E2.1.Micro`,
> `E3.Flex`, `VM.Standard2.x`). O Ampere está ali do lado o tempo todo; **a
> lista só troca depois que você clica no cartão.**

**Clique no cartão `Ampere`.** A lista de baixo se refaz e aparecem dois shapes:
**VM.Standard.A1.Flex** (com o selo *Always Free-eligible*) e o `A2.Flex`.

Marque o **A1.Flex**. A linha vai mostrar algo como `1 (80 max)` e `6 (512 max)`.

> ⚠️ **Isso NAO e uma opcao fixa.** E o valor atual, com o maximo do shape entre
> parenteses. Para mudar, clique na **setinha `▸` a esquerda do nome do shape**:
> a linha expande e revela os campos de OCPU e memoria.

Ajuste para **2 OCPUs** e **12 GB**.

**Mas 1 OCPU e 6 GB bastam**, e as vezes sao a escolha melhor. A sintese do
Piper usa um nucleo por vez -- medido, 0,717 s para 4,46 s de audio. Os 2/12
sao folga porque e de graca; **pedir menos tem mais chance de ser provisionado**,
ja que a escassez do ARM gratuito e de capacidade. Se der *Out of capacity* com
2/12, baixe para 1/6 sem hesitar: nao muda nada para este servico.

> ⚠️ **Confira que aparece o selo "Always Free eligible"** antes de continuar.
>
> O padrão da Oracle é um formato Intel/AMD que **não** é gratuito, e ele vem pré-selecionado. Se você não trocar para Ampere, a conta vem no fim do mês.

### Advanced options: nao mexa

Ainda na etapa 1 aparece uma secao **Advanced options**, com *Instance metadata
service* e *Initialization script*. **Tudo ali e opcional e pode ficar como
esta:**

- **Require an authorization header** (ligado) e o IMDSv2, a versao mais segura
  do servico de metadados. O Ubuntu 24.04 suporta. Deixe ligado
- **Initialization script** deixe VAZIO. A instalacao e a mao por SSH, nas
  partes 4 a 7 -- assim cada passo se ve dar certo, em vez de um cloud-init
  falhar calado no primeiro boot

Recolha a secao e siga.

### Rede e chave -- numa etapa SEGUINTE

> A tela de criacao e um assistente por etapas: repare no **"1 Basic
> information"** na lateral esquerda. Rede e chave SSH **nao estao na etapa 1**.
> Role ate o fim e clique em **Next**.

- **Networking**: deixe criar a VCN nova que ele oferece.
- **Assign a public IPv4 address**: precisa estar **ligado**.
- **Add SSH keys**: escolha **Generate a key pair for me** e clique em **Save private key**.

> ⚠️ **Baixe a chave privada agora.** Ela não é oferecida de novo, e sem ela não há como entrar na máquina — só apagar e refazer.

Clique em **Create**. Em 1 a 2 minutos o estado vira **RUNNING**.

**Anote o `Public IP address`** que aparece na página. Ele vai ser usado duas vezes.

### Se aparecer "Out of capacity" — aconteceu, em 17/09/2026

```
Out of capacity for shape VM.Standard.A1.Flex in availability domain AD-1
```

É o erro mais comum do ARM gratuito, e não é culpa de ninguém: a Oracle vende a
capacidade Ampere e sobra pouco para o Always Free.

**A primeira sugestão da mensagem não serve no Brasil.** Ela manda tentar outro
*availability domain*, e São Paulo tem **um só**. Não há AD-2.

O que tentar, em ordem:

1. Pedir **1 OCPU e 6 GB** em vez de 2 e 12 — a voz roda num núcleo só
2. Tentar de novo mais tarde; a capacidade libera em horários imprevisíveis

Em 17/09 **as duas falharam**, e a saída foi o AMD abaixo.

### O plano B: o AMD de 1 GB, e ele é melhor do que parece

**`VM.Standard.E2.1.Micro`** — 1 OCPU, 1 GB, também Always Free, e quase sempre
com capacidade. Duas vantagens que só apareceram quando o ARM faltou:

- **É x86**, a mesma arquitetura onde o Piper já foi medido. O desempenho em
  ARM Ampere era o **único número não medido** deste plano; no AMD a incógnita
  simplesmente não existe
- Always Free permite **duas** dessas instâncias

E a dúvida que restava — se cabe em 1 GB — **foi medida, não estimada**. O
serviço rodando no desktop, com a voz carregada e 6 falas sintetizadas:

| | |
|---|---|
| Memória em uso | **328 MB** |
| Pico | **333 MB** |

Com o Ubuntu 24.04 de servidor consumindo 150 a 250 MB, sobram uns 400 MB de
folga. **Não é marginal, cabe.** O cache pode somar até ~64 MB com o tempo (256
falas em base64); se algum dia apertar, é só baixar `CACHE_MAX` no
`voz_servico.py`.

**Para usar o AMD:** em *Change shape*, cartão **Specialty and previous
generation** → `VM.Standard.E2.1.Micro` (com o selo *Always Free-eligible*).
O resto do roteiro segue **igual**, exceto o `cloudflared` da parte 8, que já
não é usado.

---

# Parte 3 — Entrar na máquina

No **Git Bash** (não no PowerShell — o `chmod` não existe lá):

```bash
chmod 600 /caminho/da/sua-chave.key
ssh -i /caminho/da/sua-chave.key ubuntu@SEU_IP
```

Na primeira vez ele pergunta se confia na máquina: responda `yes`.

> O usuário é **`ubuntu`**, e não `root` nem seu nome.

---

# Parte 4 — Instalar o que a voz precisa (~5 min)

Já dentro da máquina:

```bash
sudo apt update && sudo apt install -y python3-venv python3-pip espeak-ng
mkdir -p ~/voz && cd ~/voz
python3 -m venv .venv
.venv/bin/pip install --upgrade pip
.venv/bin/pip install "piper-tts[alignment]" numpy onnx
```

> **`espeak-ng` não é opcional.** É ele que transforma texto em fonemas, e são os fonemas que movem a boca do Tr∅nikAt. Sem ele a voz sai e a boca fica parada.

---

# Parte 5 — Mandar os arquivos

**Abra outro Git Bash na sua máquina** (deixe o SSH aberto no primeiro), vá até a pasta do repositório e rode:

```bash
cd /d/repositorio/DevLingo

scp -i /caminho/da/sua-chave.key \
  estudio/voz.py hospedagem/voz_servico.py \
  "/d/dev/piper-vozes/pt_BR-faber-medium.onnx" \
  "/d/dev/piper-vozes/pt_BR-faber-medium.onnx.json" \
  ubuntu@SEU_IP:~/voz/
```

> ⚠️ **O `.onnx.json` vai junto, sempre.** Sem ele o Piper não sabe a taxa de amostragem nem o alfabeto de fonemas do modelo, e nem carrega.

---

# Parte 6 — Criar a chave secreta

De volta ao SSH da máquina:

```bash
openssl rand -hex 24
```

**Copie o que sair e guarde.** É a senha que o Worker vai mandar em cada pedido. Ela aparece mais duas vezes neste roteiro.

---

# Parte 7 — Deixar a voz rodando sozinha

Ainda no SSH, cole o bloco inteiro de uma vez — **trocando `COLE_A_CHAVE_AQUI`** pelo que saiu no passo 6:

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
Environment=VOZ_PORTA=8080
Environment=VOZ_CHAVE=COLE_A_CHAVE_AQUI
ExecStart=/home/ubuntu/voz/.venv/bin/python /home/ubuntu/voz/voz_servico.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
FIM

sudo systemctl daemon-reload
sudo systemctl enable --now voz
sleep 25 && curl -s localhost:8080/saude
```

Tem que sair algo assim:

```json
{"ok": true, "voz": "pt_BR-faber-medium.onnx", "com_chave": true, "carga_s": 6.1, ...}
```

**`"com_chave": true` é o que importa conferir.** Se vier `false`, a chave não chegou no serviço e ele só vai responder a si mesmo — volte ao arquivo acima.

Se não sair nada: `sudo journalctl -u voz -n 40 --no-pager`.

---

# Parte 8 — Medir o Piper no ARM

**Este é o único número do plano que nunca foi medido.** Tudo o que sabemos veio do seu desktop x86.

```bash
curl -s -X POST localhost:8080/falar \
  -H 'Content-Type: application/json' -H "X-Voz-Chave: $(grep VOZ_CHAVE /etc/systemd/system/voz.service | cut -d= -f3)" \
  -d '{"texto":"Tr∅nikAt na escuta. Câmbio."}' \
  | python3 -c "import json,sys; r=json.load(sys.stdin); print('audio', r['duracao'],'s | sintese', r['sintese_s'],'s | razao', round(r['duracao']/r['sintese_s'],1),'x tempo real')"
```

| Razão | O que significa |
|---|---|
| **acima de 2×** | ótimo, siga |
| **1× a 2×** | funciona, mas a fala demora a começar — me avise |
| **abaixo de 1×** | mais lento que tempo real; me mande o número, o desenho muda |

No seu desktop deu **6,2×**.

---

# Parte 9 — Abrir a porta, nos DOIS firewalls

> ⚠️ **Esta é a armadilha que mais custa tempo.** A Oracle tem **dois** firewalls em série, e mexer só num deixa tudo parecendo quebrado sem erro nenhum que ajude.

### 9a. O firewall da nuvem

No console: **Instances** → clique em `voz-tronikat` → em *Primary VNIC*, clique no nome da **Subnet** → clique na **Security List** (`Default Security List for ...`) → **Add Ingress Rules**.

| Campo | Valor |
|---|---|
| Source Type | CIDR |
| Source CIDR | `0.0.0.0/0` |
| IP Protocol | TCP |
| Destination Port Range | `8080` |

Salve.

### 9b. O firewall de dentro da máquina

No SSH:

```bash
sudo iptables -L INPUT --line-numbers | head -12
```

Procure a linha com `REJECT` e **anote o número dela**. Depois, trocando `N` por esse número:

```bash
sudo iptables -I INPUT N -p tcp --dport 8080 -j ACCEPT
sudo netfilter-persistent save
```

> A regra precisa entrar **antes** do `REJECT`. Pôr depois não tem efeito nenhum, e é o erro clássico aqui.

Se a máquina usar `ufw` em vez de iptables (`sudo ufw status` responde `active`):

```bash
sudo ufw allow 8080/tcp
```

### 9c. Conferir de fora

**Na sua máquina**, não na do Oracle:

```bash
curl -s -m 8 http://SEU_IP:8080/saude
```

Se responder o JSON, os dois firewalls estão certos. Se der tempo esgotado, falta um dos dois.

---

# Parte 10 — Ligar o Worker à voz

Na sua máquina, no repositório:

```bash
cd hospedagem/cloudflare
npx wrangler secret put VOZ_ORIGEM      # cole:  http://SEU_IP:8080
npx wrangler secret put VOZ_CHAVE       # cole:  a chave do passo 6
```

> **São `secret`, e não variáveis no `wrangler.toml`, de propósito:** o repositório é público, e `secret` não grava nada em arquivo.

Depois me avise. **Falta um passo que é meu:** apagar o `GERAR = "nao"` do `wrangler.toml` e publicar — é ele que hoje segura o Tr∅nikAt respondendo só por ficha, para o site ter uma voz só enquanto a voz nova não existia.

---

# Parte 11 — Conferir que fechou

```bash
curl -s -X POST https://tronikat.tronikat-busca.workers.dev/falar \
  -H 'Content-Type: application/json' -d '{"texto":"Teste da ponte."}' \
  | head -c 120
```

Tem que voltar um JSON com `audio`, `duracao` e `bocas`.

Depois, no site:

- Pergunte algo que **não** esteja nas fichas
- A resposta tem de sair **na voz do Tr∅nikAt**, não na do navegador
- A boca tem de acompanhar as sílabas, e não abrir e fechar em ritmo genérico

E para ver o serviço trabalhando: `curl -s http://SEU_IP:8080/saude` mostra quantas falas foram sintetizadas e quantas vieram do cache.

---

# Quando algo der errado

| Sintoma | Causa provável |
|---|---|
| `curl` de fora dá **tempo esgotado** | falta um dos dois firewalls — parte 9 |
| **401** na resposta | a chave do Worker não bate com a do `voz.service` |
| **503 `voz nao configurada`** | os `secret` da parte 10 não foram definidos |
| **503 `voz indisponivel`** | a máquina não respondeu: `sudo systemctl status voz` |
| **429** | o limitador cortou — 12 falas em rajada, meia por segundo depois |
| Voz sai, **boca fica parada** | faltou `espeak-ng`, ou o `.onnx.json` não subiu |
| `"com_chave": false` | o `Environment=VOZ_CHAVE=` do serviço ficou vazio |
| A máquina some depois de semanas | a Oracle recicla instância Always Free **ociosa**; se sumir, recrie |

## O que fica ligado depois

Nada precisa de manutenção. O `systemd` religa a voz se ela cair ou se a máquina reiniciar (`Restart=always`). O cache mantém as falas repetidas instantâneas e idênticas.
