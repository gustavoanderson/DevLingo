# CLAUDE.md

Contexto do projeto DevLingo. Leia antes de qualquer tarefa neste repositório.

---

## Como trabalhar com o Gustavo

Ele está em transição de carreira de implantação de telecom para engenharia de qualidade de software, e este projeto é ao mesmo tempo aprendizado e portfólio.

Duas regras que ele pediu explicitamente e que valem em toda sessão:

1. **Seja muito didático.** Explique o raciocínio por trás de cada decisão técnica, não só o resultado. Ele quer entender, não só receber pronto.
2. **Nunca avance sem consultar.** Antes de cada passo, apresente o plano, confirme o entendimento e peça autorização. Ele atua como manager: a análise técnica é sua, a decisão é dele.

Declare erros e limitações abertamente. Isso já aconteceu várias vezes na construção deste repositório e funcionou bem: defeito encontrado vira teste automático.

---

## O que é o DevLingo

App Android para aprender linguagens de programação, no formato Duolingo. O usuário escolhe uma linguagem, entra numa trilha de iniciante, intermediário ou avançado, e progride resolvendo exercícios. O progresso é salvo a cada questão respondida.

Linguagens previstas: Python, JavaScript e Node primeiro; depois HTML, CSS, SQL, C#, Go, C++, COBOL e Ruby. Meta inicial de 50 questões por linguagem.

Mascote: **Tr∅nikAt**, gato branco bípede ciberneticamente modificado, com visor verde no estilo scouter do Vegeta.

---

## Decisões de stack, e o motivo de cada uma

| Camada | Escolha | Motivo |
|---|---|---|
| App | Flutter (Dart) | Android primeiro, com porta aberta para iOS |
| Autenticação | Firebase Auth | Recuperação de senha por e-mail já vem pronta; escrever isso à mão é onde iniciantes criam falhas de segurança |
| Progresso | Firestore com cache local | Offline-first: grava local, sincroniza depois. Bateria acabando não pode perder progresso |
| Conteúdo | JSON versionado no repositório | Funciona offline, custo zero de leitura, revisável em pull request |
| Validação | Python com jsonschema | Roda em CI sem depender do Flutter instalado, e serve à carreira de QA dele |

Repositório remoto: `https://github.com/gustavoanderson/DevLingo` (público).

---

## Ambiente do Gustavo

Windows 11, VS Code, repositório em `D:\repositorio\DevLingo` (singular, sem "s").

**Instalado e verificado.** Nada de espaço no caminho de instalação.

| Peça | Onde | Variável |
|---|---|---|
| Flutter 3.47.2 estável, Dart 3.13.2 | `D:\dev\flutter` | no `Path` do usuário |
| SDK do Android (~21 GB) | `D:\dev\android-sdk` | `ANDROID_HOME`, `ANDROID_SDK_ROOT` |
| Cache do Gradle | `D:\dev\gradle` | `GRADLE_USER_HOME` |
| Pacotes Dart | `D:\dev\pub-cache` | `PUB_CACHE` |
| AVDs dos emuladores | `D:\Android AVDs` | `ANDROID_AVD_HOME` |

### O que este ambiente exige que se saiba

- **O Gustavo tem outro projeto ativo, em Appium**, que compartilha o SDK do Android, o Android Studio e os três emuladores (`CelularResponsivo`, `Pixel_8`, `nightwatch-android-11`). Qualquer mexida no Android afeta os dois projetos. Confira `flutter emulators` depois de qualquer mudança.
- **`ANDROID_AVD_HOME` não se toca.** Foi ele que colocou os emuladores no D:. Ele tem espaço no caminho, e está assim porque funciona.
- **`ANDROID_USER_HOME` foi deliberadamente deixado no C:.** Moveria só 220 MB, mas levaria junto a chave do ADB e o estado do Android Studio, que são compartilhados com o Appium. Ganho irrisório, risco real.
- **Dois JDKs na máquina.** O `JAVA_HOME` do usuário aponta para o **JDK 26**, que o plugin Gradle do Android não suporta. O Flutter usa o **JDK 17** por configuração própria (`flutter config --jdk-dir`), sem mexer no `JAVA_HOME`. Não "conserte" isso trocando o `JAVA_HOME`: outras coisas na máquina dependem do 26.
- **`flutter doctor` reclama de duas coisas que devem ser ignoradas:**
  - *Visual Studio installation is incomplete* — é para app Windows desktop. O DevLingo é Android.
  - *Android license status unknown* — falso alarme. A licença **está** aceita (`<SDK>/licenses/android-sdk-license` existe); a CLI nova do Android aposentou o comando que o Flutter usa para checar.
- **AVDs guardam caminhos absolutos.** Ao mover o SDK, o `skin.path` do `Pixel_8` apontava para o caminho velho e precisou de correção à mão. O `image.sysdir.1` é relativo e sobrevive. Se um emulador parar de abrir depois de mover algo, é aí que se olha.
- **O harness do Claude Code bloqueia `Remove-Item` em caminhos de disco.** Remoções precisam ser feitas pelo Gustavo num terminal dele. Se um arquivo estiver travado, é quase sempre o servidor do `adb`: encerre-o antes.
- **Para instalar pacote do SDK, use `android.exe sdk install`, não o `sdkmanager`.** O `sdkmanager` virou um atalho para a CLI nova e **crasha** quando o Gradle manda instalar algo, derrubando o build inteiro. O binário novo é `<SDK>\cmdline-tools\latest\bin\android.exe`, e a sintaxe usa barra: `android sdk install "ndk/28.2.13676358"`.
- **A CLI do Android mente no código de saída.** Ela conclui o trabalho e **depois** sai com `-1073740791` (`0xC0000409`). Confira o sistema de arquivos, nunca o código de saída, para saber se um pacote foi instalado.
- **NDK 28.2.13676358 instalado** em `D:\dev\android-sdk\ndk` (2,12 GB). É obrigatório: o template do Flutter declara `ndkVersion = flutter.ndkVersion` e o build falha sem ele.

### `flutter doctor` não é prova de nada

O `doctor` só confere se as ferramentas existem; ele não compila. Nesta máquina ele ficou verde no Android enquanto o build quebrava por falta do NDK.

**A prova real é compilar um APK.** Se mexer no ambiente, rode:

```powershell
flutter build apk --debug
```

Foi assim que o NDK faltante apareceu — e teria explodido no meio da primeira tela do app, misturado a erros de código novo, se o teste não tivesse sido feito antes.

---

## Banco de questões

### O princípio central do formato

Uma questão separa **o que ela mostra** do **como é respondida**. O campo `code` é opcional e independente do campo `answerType`. Isso permite qualquer combinação (teórica pura, teórica com código, lacuna com código, escrita livre) sem criar tipos novos. Não quebre essa separação.

### Regras que não se negociam

- **`id` é imutável.** O progresso do usuário aponta para ele. Para aposentar uma questão, remova-a; nunca reaproveite o identificador.
- **`hint` e `explanation` são obrigatórias.** A dica ajuda quem travou sem entregar a resposta. A explicação aparece depois de responder e é onde o aprendizado acontece.
- **Múltipla escolha tem exatamente 5 alternativas e 1 correta.**
- **Os `id` `a`–`e` das alternativas são rótulos de autoria, não posição de tela.** O app embaralha as alternativas ao renderizar (ver "Tela de exercício"). O `correct: true` fica no objeto certo e viaja junto com ele.
- **Distribua os gabaritos mesmo assim.** Se mais da metade cair na mesma letra, o validador reprova. É defesa secundária, para o caso de o embaralhamento estar desligado ou quebrado. Isso já aconteceu: a primeira lição de Python saiu com os 6 gabaritos em "a".

### Normalização de respostas escritas

`spaces: true` ignora **apenas espaços irrelevantes**, os que tocam pontuação ou operador. O espaço obrigatório entre duas palavras é sempre exigido.

Isso foi corrigido depois de um defeito real: a versão antiga removia todos os espaços, e `consttotal=0` era aceito como resposta certa para `const total = 0;`. Python nunca revelaria isso; JavaScript revelou. Se for mexer em `normalize()`, escreva testes negativos, não só positivos.

#### A regra existe em duas linguagens, e há um contrato entre elas

`normalize()` vive em [`tools/validate_questions.py`](tools/validate_questions.py) e em [`app/lib/answer/normalize.dart`](app/lib/answer/normalize.dart). Duas implementações da mesma regra é onde elas divergem em silêncio — e divergir aqui significa o app aceitar como certa uma resposta que o validador considera errada, ou o contrário.

Por isso existe [`tools/normalize_cases.json`](tools/normalize_cases.json): um arquivo de casos que **os dois lados leem**. O CI roda os dois jobs. Se divergirem, reprova.

**Ao mexer em qualquer das duas implementações, acrescente o caso ao arquivo compartilhado primeiro.**

Uma armadilha já capturada ali: em Python 3 o `\w` é ciente de Unicode e `á` conta como letra; em Dart o `\w` é ASCII puro e não conta. A tradução literal faz `café com leite` virar `cafécom leite` no app e continuar correto no validador. O Dart usa `[^\p{L}\p{N}_\s]` com `unicode: true` por causa disso.

#### Só ASCII no que o aluno digita

O validador **reprova** caractere não-ASCII em `accepted`. Dois motivos:

- **Pedagógico, e é o que pesa mais:** digitar acento em teclado de celular é toque longo. O aluno erraria por causa do teclado, não por causa da linguagem. Dificuldade incidental não ensina nada.
- **Técnico:** com acento decomposto (letra + acento combinante), o acento não é letra em nenhuma das duas linguagens, conta como pontuação, e o espaço encostado nele some. As duas concordam, então o contrato segue cumprido, mas o resultado difere do mesmo texto escrito precomposto — falso negativo. Corrigir exigiria normalização Unicode nos dois lados, e no Dart isso significa dependência nova para um risco que no Android é quase teórico.

A restrição vale **apenas para o que se digita**. Acento continua livre em `prompt`, `hint`, `explanation` e nas alternativas de múltipla escolha — tudo que o aluno **lê**.

Por causa dessa regra, as questões `python-beg-0106` e `javascript-beg-0106` pedem `Oi, mundo!` em vez de `Olá, mundo!`. As explicações registram que a saudação clássica leva acento e por que ali ela aparece sem.

### Validador

```bash
pip install jsonschema
python3 tools/validate_questions.py app/assets/content/
```

Saída 0 aprova, 1 reprova. Roda também em GitHub Actions a cada push. Toda vez que um defeito de conteúdo for encontrado à mão, escreva a regra correspondente no validador e prove que ela pega, rodando contra um arquivo defeituoso de propósito.

**Falso positivo é tão grave quanto defeito não pego.** Uma regra que reprova conteúdo legítimo ensina a contornar o validador em vez de confiar nele. Quando uma regra barrar algo correto, conserte a regra, não o conteúdo. Isso já aconteceu duas vezes:

- A regra de alternativas repetidas comparava os textos em minúsculas e reprovava `True` ao lado de `true`, que numa linguagem *case-sensitive* são respostas realmente diferentes e um distrator legítimo. Hoje ela preserva a caixa, e diferença apenas de caixa é `[AVISO]`, não `[ERRO]`.
- A regra de impressão digital, na primeira versão, acusaria a resposta `3` em JavaScript contra a mesma resposta em Python. Hoje é escopada por linguagem.

Nas duas, a saída certa foi `[AVISO]`: o `Report` distingue aviso de defeito justamente para relatar o que é suspeito sem barrar o que é válido.

#### Regra dos assets do pubspec

O banco vive em `app/assets/content/`, **dentro** do projeto Flutter, porque o Flutter só empacota assets que estejam na pasta do app. A alternativa — manter o conteúdo na raiz e copiar antes de cada build — foi descartada: um passo que se esquece produz um app que roda com as questões de ontem, sem nada avisar.

Mas o Flutter **não inclui subpastas recursivamente**: declarar `assets/content/` não inclui `assets/content/python/`. Cada pasta de linguagem precisa estar listada uma a uma no `pubspec.yaml`, e esquecer uma recria a mesma falha silenciosa que a mudança queria eliminar.

Por isso o validador **reprova** quando a lista de assets do `pubspec.yaml` não bate com as pastas que existem em `app/assets/content/` — nos dois sentidos: pasta sem declaração, e declaração sem pasta. Ao criar uma linguagem nova, o validador diz exatamente qual linha acrescentar.

#### Regra de impressão digital

Avisa quando duas questões da mesma linguagem cobram a **mesma resposta**. Ela não compara enunciados: onze questões do banco têm o mesmo `prompt` ("O que este código imprime?") e são todas legítimas. O que se repete numa questão disfarçada é a resposta.

A chave é assimétrica, e o motivo importa:

| Tipo | Chave | Motivo |
|---|---|---|
| `fillBlank` / `freeWrite` | só a resposta | O aluno *produz* a resposta, então ela é o próprio conceito. O `topic` fica de fora de propósito: a mesma resposta cobrada sob outro tópico continua sendo a mesma questão com outra roupagem |
| `multipleChoice` | resposta + `topic` | Ali a resposta costuma ser o valor de saída (`True`, `3`, `5.0`), não o conceito. Sem o `topic`, questões legitimamente distintas colidiriam o tempo todo |

Ela já pegou um defeito real: as questões `python-beg-0203` e `python-beg-0206` tinham o mesmo gabarito `5.0`, mesmo tópico e mesma lição, o que tornava a segunda adivinhável depois da primeira.

### Convenções de nome

- Lição: `app/assets/content/<linguagem>/<linguagem>-<beg|int|adv>-<NN>.json`
- Questão: `<linguagem>-<beg|int|adv>-<NNLL>`, onde NN é a lição e LL a posição

---

## Identidade visual

Paleta e tipografia detalhadas em `docs/paleta.md`. Resumo do que mais importa:

- Fundo `#170A31`, acerto `#FF2D95`, destaque `#00E5FF`, visor `#39FF14`, telemetria `#FFE14D`, texto `#F2F0FF`
- **O verde é acento, nunca corpo de texto.** Verde saturado em texto longo reprova em contraste
- Logo em fonte monoespaçada com deslocamento em ciano e magenta (aberração cromática). Nada de fonte cyberpunk baixada, que quebra em dispositivos sem ela
- Mascote em `assets/mascot/`. O arquivo animado usa SMIL e **não é reproduzido pelo `flutter_svg`**: no app, refaça o movimento com Rive, Lottie ou AnimationController
- Existe uma **variante de tamanho pequeno** do mascote, com cabeça proporcionalmente maior e traços mais grossos. Em tamanho miúdo não se reduz o desenho, redesenha-se. Ela vive dentro de `tools/gerar_faixas.py`
- As três faixas de cenário estão em `assets/cenarios/`, geradas por `tools/gerar_faixas.py`. Edite o gerador, nunca os SVGs à mão, senão as três divergem
- O mockup navegável da tela está em `docs/mockup-tela-exercicio.html`. Abra no navegador para consultar durante a implementação

---

## Tela de exercício

Layout decidido:

- **Fixo no topo:** botão sair, barra de progresso da lição, contador
- **Rola no meio:** chip de tópico, enunciado, bloco de código, alternativas
- **Fixo no rodapé:** barra de ações (Dica e Verificar) e, abaixo dela, a faixa animada de 58px colada na borda

Detalhes que têm motivo:

- Sair não pergunta "tem certeza". Se o progresso é salvo a cada questão, perguntar é ruído
- A barra de progresso mede a lição, não a linguagem. Barra que não sai do lugar desmotiva
- O código rola na horizontal e **nunca quebra linha**: quebra automática destrói a indentação, e indentação em Python é sintaxe
- Dica é ação secundária (contornada, amarela). Verificar é a única ação primária (preenchida, magenta). Se a dica tivesse o mesmo peso, viraria o caminho de menor resistência
- Régua de símbolos acima do teclado nas questões de escrita: parênteses, colchetes, dois pontos, asterisco, igual
- Sombra no limite do miolo quando houver conteúdo cortado, senão o usuário não descobre a quinta alternativa

### Embaralhamento das alternativas

As alternativas de múltipla escolha são embaralhadas **no momento de renderizar**, toda vez que a questão aparece. Sem isso, refazer a lição vira decoreba de posição ("nessa aqui é a terceira").

- Os `id` `a`–`e` do JSON são só rótulos para revisão em pull request e para a `explanation` se referir a uma alternativa. Não definem onde a alternativa cai na tela.
- O `correct: true` está preso ao objeto da alternativa, então sobrevive a qualquer ordem.
- A regra "distribua os gabaritos" do validador continua valendo como **segunda linha de defesa**: se o embaralhamento for desligado por acessibilidade, config, ou um bug, o banco ainda não deixa a resposta sempre na mesma letra.
- Se algum dia surgir uma questão que exija ordem fixa ("todas as anteriores", opções numéricas crescentes), criar um flag opcional `keepOrder: true` na questão. Nenhuma questão atual precisa disso.

### A aula do Tr∅nikAt

Antes das questões, cada lição tem uma **aula**: uma apresentação em texto cobrindo o beabá que as questões vão exigir. Ela existe porque sem ela o jogador cai de paraquedas, e **nenhum ajuste de dica conserta não saber o que é `print`**.

A aula mora no **mesmo arquivo** das questões, no campo `aula`. Cada seção declara qual `topico` prepara.

**O validador reprova quando os tópicos das duas deixam de bater**, nos dois sentidos: tópico cobrado sem seção que o prepare, e seção que prepara algo que nenhuma questão cobra. Sem essa regra, as questões mudariam e a aula ficaria para trás — e o jogador continuaria despreparado, só que agora **achando que foi preparado**, o que é pior que não ter aula.

Lição sem aula gera `[AVISO]`, não erro, para não travar conteúdo antigo. A lição de referência `-00` é exceção: ninguém a joga.

**Custo permanente aceito:** a partir daqui, toda lição nova custa lição **e** aula.

A aula aparece sozinha na primeira vez que a lição abre, e depois fica acessível pelo ícone de livro no topo do exercício. Reler não remarca a data da primeira leitura.

### Como uma questão é respondida

O princípio: **o objetivo do jogo é a pessoa aprender, não ser punida.** Toda questão termina com o aluno sabendo a resposta e o porquê. A lógica vive em `app/lib/answer/sessao_questao.dart`, fora do widget, para ser testável sem montar tela.

**Múltipla escolha.** Errar **elimina** a alternativa escolhida — riscada, não apagada, porque ver o que já foi descartado faz parte do raciocínio por exclusão — e devolve a vez. Com cinco alternativas, quatro erros deixariam só a correta na lista, e fazer o aluno tocar nela seria clicar no único botão disponível fingindo que é escolha: **por isso o quarto erro já revela.**

**Lacuna e escrita livre.** Não há o que eliminar, então a ajuda cresce: o primeiro erro só avisa, o segundo **abre a dica sozinho**, o terceiro revela a resposta. Sem isso, tentativa infinita significaria que o aluno pode nunca descobrir a resposta.

**A explicação só aparece no fim.** Mostrá-la no primeiro erro entregaria a resposta e esvaziaria a eliminação. Durante as tentativas aparece apenas o `why` da alternativa escolhida, ou uma linha neutra.

**Verde para certo, vermelho para errado — mas só em rótulo, borda e preenchimento.** O corpo da explicação continua em `#F2F0FF`. Verde saturado em texto longo sobre fundo escuro reprova em contraste, e a explicação é o texto mais longo da tela: pintá-la de verde a tornaria difícil de ler justo quando mais importa ser lida. O vermelho é `#FF5F57`, o mesmo já usado no pontinho da aba da IDE — não foi inventada cor nova.

**A cor sinaliza, o texto não pune.** O título é `AINDA NÃO`, e ao revelar é `VAMOS JUNTOS` — nunca `ERRADO`. O vermelho deixa claro que algo não deu certo; a escrita continua do lado do aluno.

### Texto que o usuário lê leva acento

Comentários de código, mensagens de commit e nomes de variável ficam em ASCII, por convenção do repositório. **Texto de interface, não.** Já entrou defeito por isso: o painel de retorno mostrava *"Nao e essa"* para o usuário, porque a string foi escrita como se fosse comentário. Ao criar qualquer texto visível na tela, escreva português correto.

**O painel de retorno é fixo acima da barra de ações**, nunca dentro da rolagem: a explicação é o pagamento do exercício e não pode depender de o aluno descobrir que precisa rolar.

**O número de tentativas fica gravado, mas a tela nunca o mostra.** Não existe "você errou 3 vezes". O dado existe para o progresso poder distinguir, mais tarde, o que foi fácil do que custou — que é o que torna revisão dirigida possível, o uso que o campo `topic` já antecipa.

### Progresso

Guardado em SQLite, em `app/lib/data/progresso.dart`. Duas tabelas: `resposta`, com uma linha por questão respondida, e `posicao`, com uma linha por lição.

**SQLite e não chave-valor** por dois motivos. O dado de tentativas só vira revisão dirigida se der para consultar, e consulta dentro de um JSON guardado numa string não é consulta. E o CLAUDE.md prevê Firestore com cache local mais tarde: o formato local já nasce parecido com o que vai sincronizar. A consulta `custoPorTopico()` existe sem tela que a use, para provar que o formato responde à pergunta que motivou guardar tentativas.

**A gravação acontece quando a questão termina, não no `Continuar`.** Se o app fechar entre uma coisa e outra, o que já foi respondido não se perde — e é isso que dá direito ao ✕ não perguntar "tem certeza".

**`question_id` é chave primária**, então refazer a lição substitui o registro em vez de duplicar. Isso só funciona porque o `id` da questão é imutável no banco de conteúdo: aquela regra ganhou consequência real aqui.

### Migração do banco: nunca recriar

O app já está no celular de alguém, com progresso dentro. Ao mudar o esquema, **recriar o banco do zero é mais simples e apaga o progresso do aluno** — que é exatamente o que o `Progresso` existe para não fazer.

Suba a `versao`, acrescente o degrau em `_migrar`, e mantenha o `CREATE TABLE` numa função só, usada pelo `onCreate` e pelo `onUpgrade`. Duas cópias do mesmo `CREATE TABLE` divergem com o tempo, e a diferença só aparece em quem instalou o app numa versão específica.

**E escreva o teste de migração:** ele cria um banco exatamente como a versão antiga o deixava, com dados dentro, abre com o código novo e confere que o progresso sobreviveu. É a única forma de saber que a atualização não vai destruir dado de usuário, e não dá para descobrir isso em produção.

### Testes de widget não enxergam I/O real

`testWidgets` roda numa zona de tempo falso. I/O de verdade — SQLite, rede, arquivo — **nunca avança** nela, e um `await` no banco dentro de um teste de widget trava o arquivo inteiro em vez de falhar. Isso já aconteceu: um teste ficou 10 minutos pendurado e derrubou os outros 16 junto.

A saída não é `tester.runAsync`, é **depender de interface**. A tela recebe `RegistroDeProgresso`, e o teste de widget passa uma implementação em memória. Assim o teste de tela prova o que deve provar — que a tela chama o repositório com os dados certos — e o SQLite continua provado à parte, em `progresso_test.dart`, com banco de verdade e um caso que fecha e reabre o arquivo.

### Fundo animado: regras de performance

O cenário é parallax em camadas. O Tr∅nikAt caminha parado e o cenário desliza atrás dele, no sentido oposto ao que ele aponta. Cada camada é desenhada duas vezes e desliza exatamente a largura de um bloco, o que torna o loop invisível.

1. Um único `AnimationController` para todas as camadas. Vários timers concorrentes causam engasgo e vazamento
2. `RepaintBoundary` isolando o fundo, senão cada quadro redesenha o card da pergunta
3. Pausar quando o app vai para segundo plano. Sem isso, anima com a tela desligada e come bateria
4. Congelar quando o teclado abrir
5. Respeitar a configuração de acessibilidade de reduzir animações do Android
6. Chave manual nas configurações para desligar o fundo
7. Véu escuro entre o fundo e o card da pergunta

---

## Validação de código escrito pelo usuário

Três níveis possíveis, e o app fica nos dois primeiros:

1. **Lacuna:** comparação normalizada contra lista de respostas aceitas
2. **Linha inteira:** mesma normalização, resposta livre
3. **Execução real:** exigiria interpretador embarcado (Chaquopy, QuickJS) ou sandbox remoto. Fora do escopo inicial

Os níveis 1 e 2 são determinísticos, o que é exatamente o que se quer: sem falso negativo.

---

## Estado e próximos passos

Concluído: identidade visual, ciclo de caminhada, esquema do banco, validador com CI, layout da tela de exercício, três faixas de cenário (dia, tarde, noite), lição sonda de JavaScript iniciante, e **Python iniciante inteiro**.

**A meta de 50 questões de Python iniciante está cumprida**, nas lições 1 a 5:

| Lição | Tema |
|---|---|
| 01 | Primeiros passos: exibir e guardar valores |
| 02 | Números e contas: operadores aritméticos |
| 03 | Decidir: comparação, booleanos e condicionais |
| 04 | Strings: medir, cortar e transformar |
| 05 | Listas e o laço `for` |

A trilha foi calibrada para encadear: os operadores da 2 alimentam as condições da 3; o recuo obrigatório da 3 reaparece dentro do laço da 5; o fatiamento de texto da 4 vira indexação de lista na 5; e a imutabilidade das strings na 4 ganha seu contraponto exato no `append` mutável da 5. Ao mexer em qualquer lição, confira se essas amarras continuam de pé.

As 4 questões de `python-beg-00` são a lição de referência do formato e **não contam** para a meta. Elas participam da validação como qualquer outra, inclusive da regra de impressão digital.

A regra de impressão digital, que era o pendente combinado para perto da lição 4, **está implementada** — ver "Validador". O desenho mudou no caminho: ela compara respostas, não enunciados.

### Etapas até o app na mão do Gustavo

O conteúdo saiu na frente do app. Hoje existem 64 questões e nenhuma tela. **Escrever mais conteúdo não aproxima uma versão jogável** — a Etapa B aproxima. E calibrar dificuldade sem nunca ter jogado é chute: depois de resolver as 50 questões no celular, o Gustavo vai saber coisas sobre o ritmo da trilha que nenhuma revisão em JSON revela. Por isso o Python intermediário vem **depois** da Etapa B, não antes.

| Etapa | Entrega | Estado |
|---|---|---|
| **A** | Ambiente Flutter e Android, tudo no D: | **concluída e provada com APK compilado** |
| **B** | **App mínimo jogável** | **próxima** |
| C | Polimento visual: fundo parallax, mascote animado | depois |
| D | Firebase: login e progresso na nuvem | depois |
| E | Python intermediário e avançado, depois JavaScript e Node | depois |

**Etapa B, o escopo mínimo.** Nada além disto entra, porque o objetivo é chegar a algo jogável, não a algo completo:

| | Passo | Estado |
|---|---|---|
| **B1** | Projeto Flutter em `app/`, rodando no emulador | **concluído** |
| **B2** | Ler os JSON como asset e modelar as questões em Dart | **concluído** |
| **B3** | `normalize()` em Dart, presa ao contrato compartilhado | **concluído** |
| **B4** | Tela de exercício conforme o mockup | **concluído** |
| **B5** | As três formas de resposta, embaralhamento e correção | **concluído** |
| **B6** | Progresso salvo local a cada questão respondida | **concluído** |

**A Etapa B está fechada: o DevLingo é jogável de ponta a ponta.**

| **C1** | Aulas introdutórias do Tr∅nikAt | **concluída** |

**Combinado e ainda não feito:**

- **Som de acerto.** Uma fanfarra de trompete comemorando, no espírito "tã-tã-tã-tãã". Exige um arquivo de áudio, um pacote (`audioplayers`), respeito ao modo silencioso e uma chave para desligar — mesmo padrão do fundo animado. Ficou fora do B5 porque som é camada, não requisito para jogar.
- **Realce de sintaxe no bloco de código.** É a única parte da tela que não é traduzir CSS para Flutter, e código legível sem cor não impede ninguém de responder.

### O app

Vive em `app/`, com o Dart package `devlingo`. O `applicationId` é **`com.devlingo.app`** e é **imutável na prática**: mudá-lo depois de publicar quebra a atualização para quem já instalou. Mesma natureza do campo `id` das questões. O `flutter create` gera `com.devlingo.devlingo`; foi corrigido à mão no `build.gradle.kts` e na pasta do pacote Kotlin.

### Receita para ver o app rodando

```bash
# 1. subir o emulador (Android 11 e o piso; se roda nele, roda acima)
D:/dev/android-sdk/emulator/emulator.exe -avd nightwatch-android-11

# 2. esperar o boot de verdade, sem chutar tempo
adb wait-for-device
adb shell 'while [ "$(getprop sys.boot_completed)" != "1" ]; do sleep 2; done'

# 3. compilar, instalar, abrir
cd app && flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell am start -n com.devlingo.app/.MainActivity

# 4. conferir de verdade, com print
adb exec-out screencap -p > tela.png
```

Duas coisas que parecem defeito e não são:

- **A primeira tela fica branca por muito tempo.** É a VM do Dart aquecendo num build de debug. Em relançamento são uns 15 segundos; **numa instalação limpa já levou 57**, com o `ProfileInstaller` rodando junto. Um print tirado cedo demais mostra tela em branco e faz parecer que o app quebrou. Antes de investigar, confira `adb logcat | grep Displayed`: ele imprime `Displayed com.devlingo.app/.MainActivity: +56s887ms`, e `dumpsys activity activities` mostra se o `mResumedActivity` já é o app.
- **O Impeller registra `Could not link pipeline program` no logcat.** É o motor gráfico novo falhando em compilar shaders na GPU emulada. O app renderiza normalmente mesmo assim. Ignore, a menos que a tela realmente não apareça.

Comandos do PowerShell com aspas aninhadas (`adb shell 'while [ ... ]'`) quebram o parser do PowerShell 5.1. Use o Bash para esses.

Fica **fora** da Etapa B: Firebase, fundo animado, escolha de linguagem, telas de trilha. Uma linguagem, uma trilha, direto ao exercício.

**Antes da Etapa E**, decidir **o que separa um nível do outro**. No iniciante o critério foi implícito: uma questão por conceito, sem composição. Proposta a validar com o Gustavo:

| Nível | Critério |
|---|---|
| Iniciante | um conceito por questão, código de até 3 linhas, sem composição |
| Intermediário | dois conceitos combinados, até 8 linhas, exige rastrear estado |
| Avançado | comportamento não óbvio, casos de borda, o porquê além do quê |

Sem isso escrito, o intermediário vira "iniciante com palavras difíceis".

O banco aprova hoje com **três avisos, e os três são intencionais**. Todos são distratores que diferem apenas na caixa, num idioma em que a caixa é justamente o conteúdo da questão:

| Questão | Distrator | Por que existe |
|---|---|---|
| `python-beg-0302` | `true` ao lado de `True` | Em minúsculas daria `NameError`, não o booleano |
| `python-beg-0402` | `ada`, `Ada` ao lado de `ADA` | `Ada` é resultado de `capitalize`, não de `upper` |
| `python-beg-0403` | `OI` ao lado de `oi` | `OI` é o que apareceria se strings fossem mutáveis |

Se algum desses avisos sumir, alguém mexeu na questão. Se aparecer um quarto, é para conferir antes de aceitar.
