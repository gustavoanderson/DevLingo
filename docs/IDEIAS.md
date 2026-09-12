# Ideias estocadas

Tudo que foi pedido, proposto ou combinado e **ainda não existe**. Revisado em 10 de setembro de 2026.

O `CLAUDE.md` guarda o *porquê* de cada decisão já tomada. Este arquivo guarda o que ainda não foi feito, com o custo honesto de cada coisa e o que trava.

**Nada aqui é promessa.** A ordem é do Gustavo.

---

## Índice por estado

| | Quantas |
|---|---|
| Pedidas por ele, não implementadas | **8** |
| Dívidas técnicas combinadas | **5** |
| Conteúdo planejado e não escrito | **6** |
| Infraestrutura e autonomia | **4** |
| Distribuição e negócio | **5** |
| Só dependem dele jogar | **1** |

---

## Ordem decidida em 10 de setembro de 2026

O Gustavo aprovou três ideias e definiu a sequência. **Isto é decisão, não sugestão.**

| | O quê | Por quê nesta ordem |
|---|---|---|
| **1º** | **Licenças** — MIT para código, CC BY-NC-ND para conteúdo | É a única coisa da lista que fica **mais cara quanto mais espera**, e destrava o servidor público |
| **2º** | **Servidor MCP** com as ferramentas que já dão para escrever | `validar_licao`, `impressao_digital`, `conferir_ascii`, `topicos_da_trilha`. É o alicerce das três aprovadas |

As três ideias aprovadas, e todas dependem do servidor:

- **Calibrar dificuldade com o progresso real** (4.1 abaixo, item 3.2 da conversa)
- **Tradução com agente**
- **Curso sob demanda** — ideia dele, e a melhor justificativa de MCP que apareceu

**Não aprovadas, e não descartadas:** servidor MCP público e sala de aula. Ele não se convenceu do valor delas; ficam registradas para quando o assunto voltar.

### Curso sob demanda: o que já foi medido

O aluno pede um tema qualquer de TI — DELPHI, o que for — e recebe uma aula do Tr∅nikAt mais 10 a 20 questões, no formato do app.

| | |
|---|---|
| Saída por lição | ~6.500 tokens (medido nas 5 de Agentes; variam menos de 3%) |
| Tentativas reais | ~2, porque o validador reprova |
| Custo por curso de 10 | **~R$ 0,55** com cache de prompt |
| 50 pessoas, 4 cursos/mês | **~R$ 110/mês** |
| 500 pessoas, 4 cursos/mês | **~R$ 1.100/mês** |

**E ela resolve um problema em aberto:** o freemium já estava escolhido e não tinha o que vender — o app inteiro dura 1,6 hora. Curso sob demanda é a primeira funcionalidade que custa dinheiro real para entregar.

**O furo, e ele é sério:** as 10 regras do validador checam **estrutura, não verdade**. Uma lição perfeitamente formada dizendo que "em Python o ponto e vírgula é obrigatório" passa em todas as dez. E o risco cresce justo onde a ideia é mais atraente — quanto mais nichado o tema, mais o modelo erra com confiança.

Por isso o **agente revisor deixa de ser opcional e vira pré-requisito**, junto com duas defesas: a tela **diz** que o curso foi gerado por IA e não revisado por pessoa (mesma decisão do painel amarelo de demonstração), e cursos gerados ficam **na conta da pessoa**, nunca no repositório.

---

## A fila de trabalho, em ordem

Definida em 11 de setembro de 2026. **Nenhum destes itens precisa de autorização nova** — o critério para entrar aqui é: melhora o app ou o repositório, não gasta dinheiro, e não depende de decisão que ainda não foi tomada.

Quando um terminar, o próximo começa. Se algo bloquear, pule e registre por quê.

| # | O quê | Por que nesta posição | Tamanho |
|---|---|---|---|
| **1** | **Revisar as 40 lições restantes** com os 9 critérios | O revisor achou **6 questões defeituosas olhando uma lição**. Faltam 40. É o item com maior densidade de defeito real por hora gasta | 3–4 h |
| **2** | **Leitura em voz alta** — decidida em 11/09 | Curta, custo zero, e entrega acessibilidade de verdade. Ver a seção A abaixo | 3–4 h |
| **3** | **O site jogável, com o Tr∅nikAt** — decidido em 11/09 | O maior da lista, e o de maior peso de portfólio. Em partes, semanas. Ver a seção B | semanas |
| **4** | **Tradução** — decidida em 11/09 | Infraestrutura primeiro, depois UMA trilha em inglês. Ver a seção C | semanas |
| **5** | **Termos técnicos na explicação** | 129 ocorrências — mais que aula e enunciado somados — e é onde o CLAUDE.md diz que o aprendizado acontece. Uma linha de código muda tudo isso | 1 h |
| **6** | **Gerador do ícone** | Fecha um princípio quebrado: o CLAUDE.md afirma que a arte nasce de código, e o ícone é o único que não | 30 min |
| **7** | **Acessibilidade nas demais telas** | Só o cabeçalho da trilha foi revisado. O Appium já provou que o defeito existe e que nenhum teste de widget o vê | 2–3 h |
| **8** | **Appium no CI** | A suíte existe e ninguém a roda. Sem isso ela apodrece — e ela é o ativo de portfólio mais forte do projeto | 2 h |
| **9** | **Trocar os sons** | Dívida antiga: ele os acha "genéricos e irritantes", e baixar o volume foi paliativo. O problema é o timbre da onda quadrada | 2 h |
| **10** | **Playwright no curso de QA** | Buraco identificado na conferência dos 17 temas: 4 deles são de Playwright, e o mapa das 15 lições só cita Cypress | 3–4 lições |
| **11** | **Telas de marco** a cada 10 questões | A primeira funcionalidade nova da fila. Reusa `_tronikat`, `resumoDoJogador`, a tabela `preferencia` e a fanfarra — quase nada é código novo | 3 h |
| **12** | **Selo de conclusão de trilha** | Arte que nasce de código, como os cenários e os sons. Compartilhável, e respeita a regra de não premiar desempenho | 2 h |
| **13** | **Exportar em PDF** as questões respondidas | O dado já existe em `evento_resposta`. É leitura e desenho | 3 h |

## Três frentes novas, decididas em 11 de setembro de 2026

A ordem escolhida por ele: **revisão → voz alta → site → tradução.**

### A. Leitura em voz alta

Botão em cada questão que lê enunciado, alternativas e explicação. **Custo zero** — `flutter_tts` usa o motor de voz do próprio Android.

Eu havia registrado isto como dependente da revisão de acessibilidade, e **estava errado**: `flutter_tts` e `Semantics` são mecanismos independentes, e um não espera o outro.

O problema difícil é **ler código em voz alta**. `System.out.println` soletrado é inútil e lido como palavra é incompreensível. Ou o bloco de código fica de fora, ou alguém escreve uma **forma falada** para ele — e a segunda provavelmente vale a pena, porque código é metade do conteúdo.

A voz depende do aparelho: a existência de voz masculina e feminina em português **não é garantida**, e a escolha precisa degradar para "a que houver".

### B. O site: portfólio jogável, com o Tr∅nikAt

Pedido dele, com o **bruno-simon.com** como referência.

**A expectativa precisa ficar calibrada, e está escrita aqui de propósito:** aquele site é referência mundial — Three.js com física e um carro dirigível, feito por um especialista em WebGL ao longo de meses. Prometer aquilo seria mentir.

O que cabe: um site 3D interativo, com o Tr∅nikAt navegável, seções sobre o app e sobre o Gustavo como idealizador. **GitHub Pages, custo zero de hospedagem.** Em semanas, por partes.

#### O agente conversável, e a decisão de dinheiro

Ele escolheu **IA de verdade, com teto rígido** — e recusou tanto o roteiro sem IA quanto a IA aberta.

Três coisas que isso exige, e que não são óbvias:

- **A chave NÃO pode ficar no site.** Página estática que chama a API carrega a chave no JavaScript, e qualquer visitante a lê. Precisa de uma função no meio — Cloudflare Workers ou similar, camada gratuita
- **Teto por visitante e teto diário.** Sem os dois, uma pessoa em laço gasta o crédito do mês numa tarde
- **O agente só fala do DevLingo.** Isso é limite de ferramenta e de instrução, e a parte que funciona é a ferramenta: ele não tem acesso a nada além do conteúdo do projeto

Custo estimado por conversa, com os preços de setembro de 2026: **~R$ 0,05 com Sonnet, ~R$ 0,12 com Opus**. Cem conversas por mês ficam entre R$ 5 e R$ 12 — barato. **O risco não é o preço unitário, é o abuso**, e é por isso que o teto vem antes do agente.

### C. Tradução

**A infraestrutura vem primeiro, e não dá para pular:** seletor de idioma, chave de trilha por idioma, impressão digital escopada por idioma, léxico medido por idioma, e as strings da UI extraídas dos widgets.

Depois, **uma trilha só**, em inglês, para medir o custo real. Traduzir as oito antes de medir repetiria o erro de escrever o nível intermediário no escuro.

Os números já medidos: **417.420 caracteres** em 3.688 campos, e **109 das 168 respostas escritas são palavras portuguesas** — nas trilhas conceituais, traduzir significa reescrever a questão, não trocar a string.

---

### O que ficou fora da fila, e por quê

| O quê | Motivo |
|---|---|
| **Curso sob demanda** | Custa dinheiro por uso. Decisão dele: só quando o lançamento puder gerar receita |

| **iOS, inclusive o build no CI** | **Fora.** Decisão dele, repetida |
| **Play Store** | US$ 25 e um teste fechado de 14 dias com 12 pessoas. Decisão dele |

| **Nível intermediário** | Calibrado por dados de uso, que se acumulam sozinhos |

---

## 1. Funcionalidades pedidas

### 1.1 Traduzir o app para outros idiomas

**Pedida em 10 de setembro de 2026.** Inglês, alemão, japonês, francês, chinês, espanhol.

O argumento dele: *"a resolução do exercício no código é universal em inglês, né?"*

**Ele está certo numa metade, e a medição mostra qual.** Das 168 respostas escritas do banco:

| | Quantas | Onde |
|---|---|---|
| Universais — código ou termo inglês | **59** | `equals`, `length`, `push`, `WHERE` |
| **Em português** | **109** | `laco`, `divergir`, `consumidores`, `regressao` |

E a distribuição explica por quê:

| Trilha | Respostas em português |
|---|---|
| Agentes de IA | 31 |
| Frameworks | 22 |
| Selenium | 20 |
| Backend | 10 |
| Qualidade de Software | 8 |
| **Python + Java + JavaScript** | **18, somadas** |

**A intuição dele vale exatamente onde código é o assunto, e quebra onde conceito é o assunto.** Nas trilhas de linguagem, a resposta é `equals` em qualquer idioma. Nas quatro trilhas conceituais — que hoje são metade do banco — a resposta é uma palavra portuguesa, e traduzir significa **reescrever a questão**, não trocar a string.

#### O tamanho real

**417.420 caracteres** em 3.688 campos de texto. Por idioma. Isso é um livro de ~70 mil palavras, seis vezes.

#### Cinco coisas que quebram, e não são óbvias

- **A regra "só ASCII no que se digita" foi desenhada para teclado brasileiro.** Ela existe porque digitar `ç` é toque longo. Em alemão o problema é `ü`; em francês, `é`; em japonês e chinês **não há teclado alfabético** — há IME, e digitar qualquer coisa passa por conversão. A regra precisa ser **por idioma**, não global
- **A impressão digital é escopada por trilha.** Seis idiomas na mesma trilha fariam `equals` colidir consigo mesmo seis vezes. A chave precisa ganhar o idioma
- **O léxico de destaque é medido em português.** `as`, `for` e `do` ficaram de fora porque são palavras portuguesas; `cache`, `tela` e `estado` também. **Cada idioma exige a mesma medição do zero** — em inglês, `for` e `do` são ambíguos de outro jeito
- **O validador roda todas as regras por arquivo.** Seis idiomas é seis vezes tudo: distribuição de gabarito, aula sincronizada com tópicos, marcação, ASCII
- **A interface tem texto espalhado em widget**, não centralizado. Antes de traduzir conteúdo, é preciso extrair as strings da UI

#### A tensão com o que o README já afirma

Vale dizer em voz alta, porque é contradição real. O `README.md` diz hoje:

> **Feito para o público brasileiro.** [...] **Não é tradução:** as questões foram pensadas em português, e até detalhes como *não exigir acento no que o aluno digita* existem porque digitar `ç` em teclado de celular é toque longo.

Esse parágrafo é **um diferencial hoje** e vira **uma promessa quebrada** se o app virar multi-idioma mal feito. A saída não é apagá-lo: é que cada idioma seja pensado naquele idioma, e não traduzido. Que é caro, e é o ponto.

#### O caminho barato que provavelmente é o certo

**Um idioma, escolhido, e a infraestrutura pronta para o segundo.** Inglês, porque dobra o alcance com o menor atrito — e porque é o idioma em que o portfólio é lido por recrutador estrangeiro.

E há um argumento que cabe aqui e não em nenhum outro item desta lista: **traduzir com qualidade, em escala, verificando cada regra, é exatamente o trabalho de um agente com ferramentas.** Esta ideia é a melhor justificativa de MCP que apareceu até agora — ver a seção 4.

---

### 1.2 Leitura em voz alta

Botão em cada questão que lê enunciado, alternativas e explicação. Voz feminina ou masculina.

**Não substitui a revisão de acessibilidade**, que continua sendo o item mais importante e está pela metade. Com `Semantics` correto, o TalkBack já lê a tela; o botão serve a quem enxerga e quer ouvir, a quem tem dislexia, a quem estuda no ônibus.

O problema difícil é **ler código em voz alta**: `System.out.println` letra a letra é inútil e como palavra é incompreensível. Ou o bloco fica de fora, ou alguém escreve uma forma falada.

E a voz **depende do aparelho** — `flutter_tts` usa o motor do Android, e voz masculina em português não é garantida.

---

### 1.3 Exportar em PDF as questões respondidas

Folha de estudo com o que a pessoa já respondeu. O dado existe em `evento_resposta`.

Duas decisões de conteúdo: **inclui a explicação?** (deveria — é o que ensina) e **inclui as erradas com o `why`?** (provavelmente, porque exclusão é parte do método).

Coerente com a licença: uso pessoal de quem estudou.

---

### 1.4 Selo de conclusão de trilha

"Fulano concluiu a trilha de Java", publicável em rede social.

**Sem número.** Sem taxa de acerto, sem tempo, sem comparação — nome, trilha e data. Uma variante "concluiu sem errar" quebraria a regra registrada, porque a medalha que você não ganhou pune.

Limite honesto: **não prova nada** para quem recebe, porque qualquer um desenha um igual. Verificar exigiria endereço público.

---

### 1.5 Telas de marco a cada 10 questões

Palavras dele: *"um respiro pra pessoa, uma mensagem de gratificação do engajamento"*.

**Respiro, não recompensa por desempenho.** Questões reveladas contam igual.

Reusa o que já existe: `_tronikat` com uma `_Pose` nova, `resumoDoJogador().respondidas`, a tabela `preferencia`, a fanfarra. **Desenhar um Tr∅nikAt do zero repetiria um erro já cometido.**

Três decisões dele: marco por trilha ou no total; entre questões ou no fim da lição; dá para desligar.

---

### 1.6 Revisão dirigida, com 10 variações de dificuldade

Lição gerada a partir de onde a pessoa tropeçou. Ele estendeu: **dez variações sobre o mesmo tema, em graus crescentes.**

Os graus já têm critério pronto — um fato aplicado direto, dois fatos combinados, o caso em que a intuição erra.

A colisão com a impressão digital é **condicional**, e ver o `CLAUDE.md` para a análise completa: ela depende do espaço de respostas do tópico ser pequeno, e **fortalece** o caso do MCP em vez de enfraquecê-lo.

---

### 1.7 Badges de percurso e sequência de dias

**O critério importa mais que o desenho.** Concluir lição e manter sequência celebram persistência. Acertar de primeira, terminar rápido ou zerar sem erro punem por via indireta.

Valor extra: **superfície nova para a automação testar.**

---

### 1.8 Cronômetro, opt-in de verdade

Quebraria a regra se o app sugerisse o modo desafio, comparasse seu tempo com o de outros, ou o exibisse por padrão.

---

## 2. Dívidas técnicas combinadas

| | O quê | Por que importa |
|---|---|---|
| 2.1 | **Trocar todos os sons.** Ele os acha genéricos e irritantes | Baixar o volume foi paliativo; o problema é o timbre da onda quadrada. Mexer em `gerar_sons.py`, **nunca no WAV** |
| 2.2 | **Acessibilidade nas outras telas** | Só o cabeçalho da trilha foi revisado. É pré-requisito da leitura em voz alta |
| 2.3 | **Termos técnicos na explicação** | 129 ocorrências — mais que aula e enunciado somados, e é onde o aprendizado acontece |
| 2.4 | **E2E cobre uma tela e não roda em CI** | A suíte Appium tem 3 testes, todos da trilha |
| ~~2.5~~ | ~~**LICENSE separadas**~~ | **feito em 11/09/2026** — `LICENSE` e `LICENCAS.md` |

---

## 3. Conteúdo planejado e não escrito

| | O quê | Tamanho |
|---|---|---|
| 3.1 | Intermediário e avançado de **todas as 8 trilhas** | ~800 questões |
| 3.2 | **Playwright** no curso de QA — buraco real | 3 a 4 lições |
| 3.3 | **JavaScript para QAs** — `async`/`await`, massa de teste, asserção | decisão pendente: trilha `qa` ou `javascript` intermediário |
| 3.4 | **Testar com IA e testar IA** no curso de QA | 2 a 3 lições |
| 3.5 | Trilhas previstas e inexistentes: HTML, CSS, SQL, C#, Go, C++, Ruby, COBOL, Node | 50 questões cada |
| 3.6 | Mutação com Jest e Stryker | 1 lição, nível avançado |

O **intermediário** (3.1) é o único item desta seção que depende de dados de quem jogou: calibrar dificuldade no escuro é chute. Os outros cinco são níveis novos de assunto, e podem ser escritos a qualquer momento.

---

## 4. Infraestrutura e autonomia

| | O quê | Estado |
|---|---|---|
| ~~4.1~~ | ~~**Servidor MCP**~~ | **feito em 11/09/2026** — 6 ferramentas, testado ponta a ponta |
| ~~4.2~~ | ~~**Ponte do Telegram**~~ | **feita em 11/09/2026** — comandos e caixa de recados |
| 4.3 | **Rotina autônoma** de manutenção | depende de 4.1 e 4.2 |
| ~~4.4~~ | ~~**Build iOS no CI**~~ | **FORA.** Decisão dele, repetida em 11/09/2026: iOS não entra por ora, nem o build no CI. Não trazer de volta até ele levantar |

---

## 5. Distribuição e negócio

| | O quê | O que trava |
|---|---|---|
| 5.1 | **Play Store** | US$ 25 **e teste fechado com 12 pessoas por 14 dias** — começar cedo |
| 5.2 | **Versão web** | Flutter compila para web; o SQLite não vai direto |
| 5.3 | **Freemium** — iniciante livre, avançado pago | modelo escolhido, nada implementado |
| 5.4 | **Checkout** | depende de 5.3 |
| 5.5 | **Patrocínios** | depende de ter usuários |

Duas ressalvas já medidas: **o app inteiro dura 1,6 hora** com a média real dele de 29 s por questão — pouco para assinatura; e **o Firestore gratuito tem teto de leituras**, então o custo aparece antes da receita.

---

## 6. O que depende de dados de uso

O **nível intermediário** (3.1) é calibrado pelo custo real de cada questão — tentativas, reveladas, tempo. Esses dados se acumulam sozinhos conforme o app for usado.

**Isto não é cobrança e não deve virar uma**, e está aqui só para explicar por que 3.1 está no fim da fila enquanto 3.2 a 3.6 não estão. Ver o CLAUDE.md, "Duas coisas para NÃO repetir".
