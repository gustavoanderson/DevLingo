# O site do DevLingo

Uma página só, `index.html`: a rua cyberpunk que desce para o túnel do metrô ao rolar, e o Tr∅nikAt em 3D respondendo num terminal.

Para ver, abra o arquivo no navegador. Não há build.

## Por que é um arquivo só

Ele nasceu como artefato do claude.ai, que exige página única. Os pedaços — a rua (`montarVista`), o túnel (`montarMetro`), a cabeça em Three.js e a chuva do terminal — vivem dentro dele como funções separadas.

**Não existem cópias avulsas desses módulos, e isso é de propósito.** Durante a construção havia um `cabeca.js` solto, e ele ficou para trás: as texturas de pelo e metal só entraram na página montada. Versionar os dois seria pôr no repositório uma cabeça velha ao lado da nova — a mesma divergência que `check_gerados_em_dia` impede nos cenários do app.

Quando for separar em módulos, separe **a partir deste arquivo**.

## O chat muda conforme onde a página roda

| Onde | Quem responde |
|---|---|
| Artefato do claude.ai | um modelo, pela capacidade `sample` — quem paga é quem visita |
| Qualquer outro lugar (GitHub Pages, arquivo local) | **as respostas prontas** do objeto `RESERVA` |

A troca é automática: sem `window.claude`, a página cai nas respostas prontas em vez de quebrar. Dar IA de verdade fora do claude.ai é o trabalho do estúdio local com o Hermes, planejado em `docs/IDEIAS.md`.

## Três lições que custaram rodadas

- **Letreiro repetido denuncia gerador.** Os nomes saem de uma fila embaralhada, distribuída por distância e não por lado da rua — senão uma calçada fica com todos os nomes e a outra só com caixas de luz
- **Objeto em movimento não pode dar a volta dentro do quadro.** Os carros sumiam no meio da rua porque o laço reiniciava onde eles ainda eram visíveis
- **Nada visual é aprovado sem render.** A captura do Chrome em modo headless foi a ferramenta de cada correção
