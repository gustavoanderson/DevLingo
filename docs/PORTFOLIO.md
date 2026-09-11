# DevLingo — o que este projeto demonstra

Documento vivo, organizado para quem avalia: recrutador, entrevistador, ou o próprio Gustavo montando um currículo.

O `README.md` apresenta o produto. Este arquivo apresenta **as decisões de engenharia e as evidências delas**.

---

## Em números

| | |
|---|---|
| Questões no banco | **354**, em 7 trilhas |
| Testes automatizados | **345** unitários e de widget, mais 3 de ponta a ponta |
| Cobertura | **95,6%** — 2.366 de 2.476 linhas, em 28 de 32 arquivos |
| Versões publicadas | 5, de `v1.0.0` a `v1.4.0` |
| Defeitos encontrados jogando | **9**, todos documentados com causa raiz |
| Linhas de contexto escrito | mais de 1.500 no `CLAUDE.md` |

---

## 1. Qualidade não é etapa: é o método

O projeto é portfólio de alguém em transição para engenharia de qualidade, e isso aparece na arquitetura, não num capítulo à parte.

### Um validador cujas regras nasceram de defeitos reais

Cada regra do `tools/validate_questions.py` existe porque algo passou. Nenhuma é preventiva por princípio:

| Regra | O defeito que a originou |
|---|---|
| Gabarito concentrado | a primeira lição de Python saiu com os 6 em "a" |
| Letra nunca usada | duas lições escritas em lote nunca usaram `d` nem `e` |
| Impressão digital | `python-beg-0203` e `-0206` cobravam a mesma resposta |
| Aula fora de sincronia | tópico cobrado sem seção que o prepare |
| Só ASCII no que se digita | uma lacuna pedia `satisfação`, com til e cedilha |
| Marcação aninhada | `**sem o \`ln\`**` — 15 campos, invisível à checagem de paridade |

**E toda regra é verificada reprovando de propósito.** Um portão que só sabe aprovar não é portão.

### O falso positivo é tratado como defeito

Duas regras já foram **corrigidas por reprovarem conteúdo legítimo** — a de alternativas repetidas, que barrava `True` ao lado de `true` numa linguagem sensível a caixa, e a de impressão digital, que acusaria `3` em JavaScript contra `3` em Python.

Nas duas, a saída foi consertar a regra, e não o conteúdo. **Portão que reprova sem motivo ensina o time a contorná-lo.**

### Contrato entre duas implementações da mesma regra

A normalização de respostas existe em Python e em Dart. Duas implementações divergem em silêncio — e divergir aqui significa o app aceitar como certa uma resposta que o validador recusa.

Por isso existe `tools/normalize_cases.json`, que **os dois lados leem**, e o CI reprova se discordarem. Uma armadilha já capturada ali: em Python o `\w` conta `á` como letra; em Dart, não.

---

## 2. Verde não quer dizer correto

**Oito vezes** a suíte ficou verde escondendo um defeito que só apareceu na tela.

| Defeito | Como foi encontrado |
|---|---|
| Barra de resultados **invisível** | 105.300 pixels da cor do fundo onde deviam estar três faixas |
| Vão de mil pixels no estado vazio | só existia em aparelho de tela alta |
| Título colado no ícone | 4px de folga, contra 60 entre os outros |
| Quatro controles **sem rótulo** | dump da árvore de acessibilidade, com Appium |

O método que os pegou não foi olhar o print: foi **medi-lo**. Recortar a região e contar pixels por cor transforma "acho que está estranho" em um número.

### E medir também derruba acusação falsa

No mesmo dia, uma acusação de "título ilegível" foi **desmentida pela medição**: o pixel mais claro era exatamente a cor certa. O print tinha capturado a animação de transição.

Duas correções de método vieram daí, e valem além deste projeto: fazer o toque e a espera **dentro do aparelho**, e **confirmar em que tela você está antes de comparar pixels**.

---

## 3. Automação que encontrou um defeito de produto

A suíte Appium (`e2e/`) foi escrita contra o **APK de release publicado**, e não contra um binário especial de teste.

Essa escolha teve consequência imediata: o dump da árvore de acessibilidade mostrou os quatro controles do topo da trilha como `View` clicáveis e **anônimos**. Quem usa leitor de tela ouvia "botão" nos quatro, sem saber se ia sair da trilha ou desligar o som.

**Nenhum dos 343 testes pegava**, porque as `Key` do Flutter param na fronteira do Dart. O defeito era de quem olha de fora.

A correção separou duas coisas que costumam ser confundidas:

| | Vira | Serve a | Pode mudar? |
|---|---|---|---|
| `label` | `content-desc` | a pessoa | **sim** |
| `identifier` | `resource-id` | o teste | **não — é contrato** |

### O que a automação ensinou, com número

| Descoberta | Medição |
|---|---|
| Animação em laço torna a tela inalcançável | `ERROR: could not get idle state` — mesma causa raiz do `pumpAndSettle` |
| `pointerType` padrão é `mouse`, e o Flutter esperava toque | o comando executava, não falhava, e não fazia nada |
| A prontidão da tela de título **não é observável** | pausa de 6s funciona; esperar o convite aparecer, não |
| A MIUI bloqueia pacote **novo**, não `adb install` | atualizar passa, instalar novo devolve `INSTALL_FAILED_USER_RESTRICTED` |

A terceira gerou a decisão mais defensável da suíte: **quando a prontidão não é observável, age-se e verifica-se o efeito**, repetindo — em vez de aumentar a pausa e torcer.

---

## 4. Decisões de arquitetura com trade-off explícito

### Eliminar o conflito em vez de resolvê-lo

Duas contas no mesmo aparelho, ou o mesmo usuário em dois aparelhos, produziriam versões diferentes do mesmo progresso. Havia três estratégias, e duas **resolvem** o conflito — melhor resultado vence, mais recente vence.

A escolhida **elimina**: o histórico só cresce, e o estado atual passou a ser um **cache derivado** dele. Juntar dois aparelhos é juntar duas listas, e não existe conflito possível.

Apagar a tabela de estado inteira não perde nada — **e há um teste que prova isso**.

### O id do evento é derivado do conteúdo

Era autoincremento, e isso quebraria a sincronização de duas formas: colisão entre aparelhos, e reenvio duplicando o histórico. Hoje o id sai de `uid|questão|instante`, então a mesma partida produz o mesmo id em qualquer lugar e reenviar é inofensivo.

### Migração com duas rotas, provada convergente

Um esquema pode ser alcançado pelo `CREATE TABLE` de quem instala agora e pelo `ALTER TABLE` de quem atualiza. Se divergirem, o defeito só aparece em quem instalou numa versão específica.

As colunas vivem numa lista só, e **um teste compara o `PRAGMA table_info` das duas rotas**.

---

## 5. Produto: decisões com princípio escrito

O princípio que ordena o app: **o objetivo é a pessoa aprender, não ser punida.**

Ele não é slogan — ele aparece como restrição de código, e cada uma tem teste:

- O título nunca diz `ERRADO`. Diz **`AINDA NÃO`**, e ao revelar, **`VAMOS JUNTOS`**
- A alternativa errada é **riscada, não apagada** — ver o que foi descartado faz parte do raciocínio
- As estatísticas não têm **nenhuma fatia vermelha**: revelar não é falhar
- Um teste varre a tela de estatísticas atrás de `errou`, `errado`, `falhou` e `pior`, e **reprova se alguma aparecer**
- Tempo é o único cartão **sem cor de acento**, para não convidar à corrida

### E decisões que foram medidas antes de tomadas

O critério que separa iniciante de intermediário **não é opinião**: foi extraído medindo as 100 questões jogáveis. A proposta anterior, escrita de cabeça, reprovava 17 questões legítimas do próprio banco.

O achado: **tamanho de código não mede dificuldade.** As duas questões mais longas do iniciante têm 9 e 8 linhas e um único passo de raciocínio. O que cobra passos é **estado que muda**.

---

## 6. Colaboração com IA, com governança

O código foi escrito em pareamento com o Claude Code, e o `CLAUDE.md` é o artefato dessa colaboração — mais de 1.500 linhas de decisões, com o porquê de cada uma.

O que o torna incomum não é o tamanho: é **o que ele registra contra o autor**.

- Decisões em que **a recomendação da IA foi recusada** com a informação na mesa, marcadas como escolha e não esquecimento
- Uma lista de vezes em que **a IA afirmou um número sem medir e estava errada** — a largura de um título, o que o CI fazia, se um campo tinha rótulo
- Regras que **pegaram quem as escreveu**: a checagem de marcação aninhada reprovou a primeira lição escrita depois dela
- Um viés identificado por medição: gabarito concentrado numa letra, três vezes seguidas. **A correção não foi manual — foi escrever a ferramenta**, porque corrigir à mão não conserta viés

### A regra de ouro do arranjo

> A análise técnica é da IA; **a decisão é humana.**

E a regra que a torna operável: **autonomia se concede onde o erro é verificável automaticamente**, e não onde é tecnicamente possível.

---

## 7. O que este projeto **não** tem

Um portfólio que só lista acertos não é avaliável.

- **Só o nível iniciante** existe. Intermediário e avançado estão planejados e não escritos
- **Cinco das sete trilhas nunca foram jogadas por ninguém.** A dificuldade delas é estimativa
- A revisão de acessibilidade foi feita **só no cabeçalho da trilha**
- A suíte de ponta a ponta cobre **uma tela**, e não roda em CI
- Nunca foi compilado para **iOS** — falta hardware
- Nenhum usuário além do autor

---

## 8. O que está sendo construído agora

| Frente | Estado |
|---|---|
| Curso de **Agentes de IA** | 2 de 5 lições escritas |
| **Servidor MCP** expondo os portões de qualidade do projeto | planejado |
| **Revisão dirigida** — lição gerada a partir de onde a pessoa tropeçou | planejada |
| Rotina autônoma de manutenção, com aprovação por mensagem | planejada |
| Licenças separadas para código e conteúdo | planejada |

A revisão dirigida é a funcionalidade que **força** o MCP a existir: o agente roda na nuvem, as regras de qualidade vivem em outro lugar, e três consumidores diferentes precisam das mesmas ferramentas.
