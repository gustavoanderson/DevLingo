# Pôr o servidor MCP no ar

Roteiro para colocar `mcp/servidor.py` numa máquina que fica ligada, alcançável
pela internet, autenticado — e **sem abrir porta nenhuma**.

Ele é irmão de [`hospedagem/ORACLE.md`](../hospedagem/ORACLE.md), que hospedou a
voz do Tr∅nikAt na mesma VM. O que muda aqui é o caminho de fora para dentro: a
voz recebe conexão numa porta aberta, defendida por uma chave que só o Worker
manda; **o MCP não abre porta nenhuma**, e quem valida credencial é a Cloudflare.

---

## Por que assim, e não como a voz

A voz é chamada por **um** cliente que nós controlamos: o Worker. Uma chave
compartilhada entre duas peças nossas resolve, e o preço — uma porta aberta,
defendida por segredo — é aceitável.

O MCP é outra coisa: ele existe para ser alcançado por **clientes que não são
nossos** (Claude Desktop, Claude Code, um agente em CI). Três diferenças
decorrem disso:

| | Voz | MCP |
|---|---|---|
| Quem chama | só o Worker | qualquer cliente MCP |
| Como entra | porta aberta nos **dois** firewalls | túnel que sai **de dentro** |
| Quem autentica | chave nossa, no header | **Cloudflare Access**, antes da máquina |

**A porta aberta some, e com ela some a armadilha mais cara do `ORACLE.md`** —
os dois firewalls em série, que aquele arquivo marca com *"⚠️ esta é a que mais
custa tempo"*. O `cloudflared` abre a conexão de dentro para fora; não há
entrada a liberar.

**E a autenticação não é escrita por nós, de propósito.** Código nosso no
caminho de quem entra é onde iniciantes criam falhas — a mesma razão já
registrada no `CLAUDE.md` para usar Firebase Auth em vez de escrever login.

### O que continua segurando a porta

Se a credencial vazar, quem entra encontra **seis ferramentas somente leitura**.
Nenhuma grava, publica ou apaga. Isso foi decidido quando o servidor era local e
só o dono o alcançava; exposto, deixa de ser elegância de projeto e vira a
defesa. `mcp/test_remoto.py` reprova se aparecer uma ferramenta com nome de
escrita.

---

## Dá para começar ANTES do domínio, e vale

O domínio só é exigido na Parte 3. As Partes 1 e 2 — pôr o código na VM e
deixá-lo rodando — não dependem de DNS nenhum, e o `cloudflared` sabe criar um
túnel com **URL temporária** sem login e sem domínio:

```bash
cloudflared tunnel --url http://127.0.0.1:8931
```

Ele imprime um endereço `*.trycloudflare.com`.

> ⚠️ **O servidor vai recusar esse endereço com `421 Misdirected Request`**, e
> isso não é defeito: o SDK valida o cabeçalho `Host` contra uma lista, como
> defesa contra DNS rebinding. O nome sorteado pelo túnel não está nela.
>
**A correção é acrescentar o nome à lista, e não desligar a proteção.**
Desligar seria uma linha, e trocaria uma defesa real por conveniência: sem
ela, uma página maliciosa aberta por alguém na mesma rede pode resolver um
nome próprio para este endereço e conversar com o servidor.

Para o túnel temporário, o nome é sorteado, então passe-o na hora:

```bash
sudo systemctl stop mcp
cd ~/mcp/fonte
MCP_TRANSPORTE=streamable-http MCP_PORTA=8931 \
  MCP_HOSTS=o-nome-sorteado.trycloudflare.com \
  ~/mcp/.venv/bin/python mcp/servidor.py &
```

Com o domínio próprio isso deixa de ser incômodo: o nome é fixo e já está no
`mcp.service` da Parte 2.

Confira dali de fora:

```bash
python3 mcp/testar_hospedado.py https://SEU-ENDERECO.trycloudflare.com/mcp --sem-auth
```

**Por que fazer isso antes:** se a VM tiver Python velho, memória curta ou
faltar dependência, o lugar de descobrir é aqui — e não depois de esperar a
propagação do DNS, quando a causa fica misturada com "será que o domínio
propagou?".

A URL muda a cada reinício e **não tem Access na frente**, então ela serve para
provar o caminho e não para usar. Enquanto durar, quem tiver o endereço
alcança o servidor; as seis ferramentas são somente leitura, mas não deixe o
túnel temporário aberto além do teste.

---

## Antes de começar

- A VM do Oracle já no ar, com o serviço de voz rodando (ver `ORACLE.md`)
- `devlingo.app.br` **Active** no painel da Cloudflare, com os nameservers já
  trocados no registro.br

> **Por que o domínio precisa estar na Cloudflare:** o túnel publica num
> hostname de uma zona que ela administra, e o plano gratuito só oferece o
> *full setup* — que exige os nameservers dela. Conferido na documentação.
>
> O `trycloudflare.com` gratuito serve para **provar o caminho** antes disso,
> mas dá URL que muda a cada reinício: não serve para algo que se cita.

---

## Parte 1 — O código na VM

No SSH da máquina:

```bash
mkdir -p ~/mcp && cd ~/mcp
# Só o que o servidor precisa: as ferramentas, os critérios, e o validador,
# que é a autoridade única sobre o que é uma lição válida.
git clone --depth 1 https://github.com/gustavoanderson/DevLingo.git fonte
python3 -m venv .venv
.venv/bin/pip install --quiet mcp jsonschema
```

> **`--depth 1` porque o histórico não serve aqui**, e clonar tudo puxa as
> falas gravadas e os cenários — dezenas de megabytes numa máquina de 1/8 de
> núcleo, para rodar um servidor que lê JSON.

Prove que ele sobe **antes** de embrulhar em serviço:

```bash
cd ~/mcp/fonte
MCP_TRANSPORTE=streamable-http MCP_PORTA=8931 \
  ~/mcp/.venv/bin/python mcp/servidor.py &
sleep 3
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8931/mcp
kill %1
```

`400` é o esperado, e **não é erro**: o endpoint existe e recusou um GET sem
sessão MCP. `000` ou recusa de conexão é que seriam problema.

---

## Parte 2 — Deixar rodando sozinho

```bash
sudo tee /etc/systemd/system/mcp.service >/dev/null <<'FIM'
[Unit]
Description=Servidor MCP do DevLingo
After=network.target

[Service]
User=ubuntu
WorkingDirectory=/home/ubuntu/mcp/fonte
Environment=MCP_TRANSPORTE=streamable-http
Environment=MCP_HOST=127.0.0.1
Environment=MCP_PORTA=8931
Environment=MCP_HOSTS=mcp.devlingo.app.br
ExecStart=/home/ubuntu/mcp/.venv/bin/python /home/ubuntu/mcp/fonte/mcp/servidor.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
FIM

sudo systemctl daemon-reload
sudo systemctl enable --now mcp
sleep 5 && systemctl is-active mcp
```

> **`MCP_HOST=127.0.0.1`, e nunca `0.0.0.0`.** Quem publica é o túnel, que sai
> de dentro. Escutar em todas as interfaces abriria a máquina para a rede sem
> ninguém ter pedido — e aí a porta fechada no firewall seria a única coisa
> entre o servidor e o mundo, o que é exatamente o arranjo que este roteiro
> existe para evitar.

---

## Parte 3 — O túnel

```bash
curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg \
  | sudo tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main" \
  | sudo tee /etc/apt/sources.list.d/cloudflared.list
sudo apt-get update && sudo apt-get install -y cloudflared
cloudflared tunnel login
```

O `login` imprime uma URL. Abra no navegador, escolha `devlingo.app.br`, e ele
grava o certificado na máquina.

```bash
cloudflared tunnel create devlingo-mcp
cloudflared tunnel route dns devlingo-mcp mcp.devlingo.app.br
```

Depois, o serviço:

```bash
sudo mkdir -p /etc/cloudflared
sudo tee /etc/cloudflared/config.yml >/dev/null <<'FIM'
tunnel: devlingo-mcp
credentials-file: /home/ubuntu/.cloudflared/devlingo-mcp.json
ingress:
  - hostname: mcp.devlingo.app.br
    service: http://127.0.0.1:8931
  - service: http_status:404
FIM

sudo cloudflared service install
sudo systemctl enable --now cloudflared
```

> **A última regra do `ingress` é obrigatória.** Sem o `http_status:404` final,
> o `cloudflared` recusa a configuração — e a mensagem fala de "catch-all
> rule", não de o que falta.

---

## Parte 4 — A autenticação, no painel

Isto é no navegador, em **Zero Trust** no painel da Cloudflare.

1. **Access → Applications → Add an application → Self-hosted**
2. Domínio: `mcp.devlingo.app.br`
3. Em **Policies**, crie uma com ação **Service Auth** — e não *Allow*
4. **Access → Service Auth → Service Tokens → Create**; guarde o **Client ID**
   e o **Client Secret** (o segredo aparece **uma vez só**)
5. Na política, inclua o seletor **Service Token** e escolha o que você criou

> **Ação `Service Auth`, e não `Allow`:** `Allow` manda um humano fazer login
> pelo navegador, e cliente MCP não tem navegador. `Service Auth` aceita
> **apenas** o par de cabeçalhos, e recusa sessão de pessoa.

Limites do plano gratuito, conferidos: 50 usuários, 1000 túneis, 500
aplicações. Este arranjo usa um de cada.

---

## Parte 5 — Provar

De qualquer máquina, sem estar na VM:

```bash
curl -s -o /dev/null -w '%{http_code}\n' https://mcp.devlingo.app.br/mcp
```

**`403` aqui é a resposta CERTA**, e é o teste mais importante deste arquivo:
significa que o Access barrou quem não mandou credencial. `200` sem token
significaria que a política não está valendo, e o servidor está aberto.

Com o token:

```bash
curl -s https://mcp.devlingo.app.br/mcp \
  -H "CF-Access-Client-Id: SEU_ID" \
  -H "CF-Access-Client-Secret: SEU_SEGREDO" \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"curl","version":"1"}}}'
```

Tem que voltar o `serverInfo` com `devlingo`.

---

## Como conectar um cliente

Em `~/.claude.json` ou no cliente MCP de sua preferência:

```json
{
  "mcpServers": {
    "devlingo": {
      "type": "http",
      "url": "https://mcp.devlingo.app.br/mcp",
      "headers": {
        "CF-Access-Client-Id": "SEU_ID",
        "CF-Access-Client-Secret": "SEU_SEGREDO"
      }
    }
  }
}
```

**O segredo não entra no repositório.** Ele é credencial de acesso ao servidor,
e vale a mesma regra da keystore de release: a primeira barreira é o arquivo não
estar numa pasta que o git enxerga.

---

## Quando algo não funciona

| Sintoma | Causa provável |
|---|---|
| `403` **com** o token | a política não tem o seletor Service Token, ou a ação é `Allow` |
| `200` **sem** token | não há política valendo — o servidor está aberto |
| `530` ou `1033` | o túnel não está no ar: `systemctl status cloudflared` |
| `502` | o túnel subiu e o servidor MCP não: `systemctl status mcp` |
| **`421`** | **o `Host` não está em `MCP_HOSTS`** — a defesa contra DNS rebinding fez o trabalho dela |
| `406` numa chamada | faltou `Accept: application/json, text/event-stream` |
| o domínio não resolve | nameservers ainda propagando, ou copiados com erro |

**O par 530/502 é o que mais economiza tempo:** o primeiro diz que o problema
está entre a Cloudflare e a máquina; o segundo, que está dentro dela. Sem essa
distinção, os dois parecem "o site caiu".
