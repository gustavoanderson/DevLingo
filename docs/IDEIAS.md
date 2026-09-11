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
| 2.5 | **LICENSE separadas** | MIT para código, CC BY-NC-ND para conteúdo, com reserva do nome DevLingo e do Tr∅nikAt |

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

**Nada disso deve ser escrito antes de ele jogar o iniciante.** Calibrar no escuro é chute — a regra que já fez o Python intermediário esperar.

---

## 4. Infraestrutura e autonomia

| | O quê | Estado |
|---|---|---|
| 4.1 | **Servidor MCP** expondo os portões de qualidade | planejado; ver a seção de ideias ousadas |
| 4.2 | **Ponte do Telegram** para aprovações | planejada — `getUpdates`, sem servidor público |
| 4.3 | **Rotina autônoma** de manutenção | depende de 4.1 e 4.2 |
| 4.4 | **Build iOS no GitHub Actions** | runner macOS é grátis para repositório público. Meia hora, custo zero |

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

## 6. O que só depende dele

**Jogar.** Seis das oito trilhas nunca foram jogadas por ninguém — Backend, Qualidade, Frameworks, Java, Selenium e Agentes. Ele está em 20 de 50 no JavaScript.

A dificuldade dessas seis é **estimativa minha**, e o intermediário de cada uma espera isso. É o item mais barato da lista inteira e o que destrava mais coisa.
