# O site do DevLingo

Uma página só, `index.html`: a rua cyberpunk que desce para o túnel do metrô ao rolar, e o Tr∅nikAt em 3D numa videochamada, respondendo num terminal.

Para ver, abra o arquivo no navegador. Não há build.

## Por que é um arquivo só

Ele nasceu como artefato do claude.ai, que exige página única. Os pedaços — a rua (`montarVista`), o túnel (`montarMetro`), a cabeça em Three.js e a chuva do terminal — vivem dentro dele como funções separadas.

**Não existem cópias avulsas desses módulos, e isso é de propósito.** Durante a construção havia um `cabeca.js` solto, e ele ficou para trás: as texturas de pelo e metal só entraram na página montada. Versionar os dois seria pôr no repositório uma cabeça velha ao lado da nova — a mesma divergência que `check_gerados_em_dia` impede nos cenários do app.

Quando for separar em módulos, separe **a partir deste arquivo**.

## O chat muda conforme onde a página roda

A página tenta quatro caminhos, nesta ordem, e o selo no canto da videochamada diz qual está valendo:

| Selo | Quem responde | Voz e boca |
|---|---|---|
| `estúdio local · ao vivo` | o **estúdio** em `http://127.0.0.1:8765` (`estudio/servidor.py`): modelo local, porteiro com juiz | Piper, com a boca movida pelos **fonemas** |
| `nuvem · ao vivo` | um **Cloudflare Worker** (`hospedagem/cloudflare`) que só faz a busca: devolve o id da ficha, ou a recusa | **gravadas de antemão** em `falas/` por `hospedagem/gerar_falas.py`, com a boca pelos fonemas |
| `sem estúdio · via Claude` | um modelo, pela capacidade `sample` do artefato do claude.ai — quem paga é quem visita | voz do navegador, boca aproximada pelas palavras |
| `estúdio offline` | **as respostas prontas** do objeto `RESERVA` | voz do navegador |

### Por que a nuvem só busca

Hospedagem gratuita não tem placa de vídeo (e o Hugging Face passou a cobrar por contêiner: medido, `402`). Mas no **modo fichas** o Tr∅nikAt só fala textos fixos — as fichas revisadas e a frase de recusa —, então a voz pode ser gravada uma vez e servida como arquivo. Na nuvem sobra só a busca, que o Workers AI faz de graça com o **mesmo** `embeddinggemma-300m` calibrado no PC.

Medido em 15/09/2026 com `hospedagem/calibrar_borda.py`: **48/53** legítimas na ficha certa, igual ao PC, e nenhuma manobra ou pergunta geral passa do piso 0,70. **O prefixo `task: sentence similarity | query:` é obrigatório**, apesar de a documentação dizer que não: sem ele, 31/52.

Duas consequências de só falar texto pronto: nenhuma resposta tem fato inventado, e **uma ficha escolhida errada vira resposta errada falada** — sem modelo nem juiz para disfarçar. É por isso que o placar da ficha certa importa mais aqui do que no PC.

Ao mudar `estudio/fichas.md`: rode `gerar_falas.py` (regrava só o que mudou), `npx wrangler deploy` em `hospedagem/cloudflare` e `calibrar_borda.py`. `gerar_falas.py --conferir` reprova falas desatualizadas.

A troca é automática. O estúdio fora do ar é o caso **comum** — quem visita não tem o PC do Gustavo —, então a sondagem é curta (1,5 s), silenciosa e se repete a cada 15 s: ligar o estúdio com a página aberta acende a chamada sem recarregar.

Para a demonstração local:

```bash
estudio/.venv/Scripts/python.exe estudio/servidor.py     # espere "estudio pronto"
python -m http.server 8000 --bind 127.0.0.1 --directory site
# abra http://127.0.0.1:8000
```

A porta 8000 não é arbitrária: é uma das origens que o servidor libera (`ORIGENS` em `servidor.py`). Servida de outra porta, a página enxerga o estúdio como offline.

### Como testar a volta inteira, e o instrumento que NÃO serve

A captura `--screenshot` com `--timeout` do Chrome headless **não mede tempo real**: numa rodada, o cronômetro da página marcava 605 ms quando o print saiu, e uma chamada ao estúdio aparecia como `Failed to fetch` — com o servidor registrando `200` para ela. Parecia CORS, e não era: os cabeçalhos estavam certos, e **a mesma chamada, pelo CDP, passou em 20 ms**. A causa exata dentro do modo de captura não foi isolada — o que se sabe é que ele não serve para medir rede. `--dump-dom` também engana: ele fotografa o DOM no carregamento, e não depois da espera.

O que funciona é controlar o Chrome pelo **protocolo de depuração** (CDP), com esperas de verdade e o console real. Por ele, a volta completa foi medida: pré-verificação `204`, `POST` `200`, 193 quadros de boca vindos dos fonemas, legenda e chat destravado no fim.

E nesta máquina o Chrome headless só desenha WebGL com `--use-gl=angle --use-angle=d3d11`: com o swiftshader, o processo de GPU morre — inclusive na versão já commitada, que serviu de controle.

## Três lições que custaram rodadas

- **Letreiro repetido denuncia gerador.** Os nomes saem de uma fila embaralhada, distribuída por distância e não por lado da rua — senão uma calçada fica com todos os nomes e a outra só com caixas de luz
- **Objeto em movimento não pode dar a volta dentro do quadro.** Os carros sumiam no meio da rua porque o laço reiniciava onde eles ainda eram visíveis
- **Nada visual é aprovado sem render.** A captura do Chrome em modo headless foi a ferramenta de cada correção
