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

### Validador

```bash
pip install jsonschema
python3 tools/validate_questions.py content/
```

Saída 0 aprova, 1 reprova. Roda também em GitHub Actions a cada push. Toda vez que um defeito de conteúdo for encontrado à mão, escreva a regra correspondente no validador e prove que ela pega, rodando contra um arquivo defeituoso de propósito.

**Falso positivo é tão grave quanto defeito não pego.** Uma regra que reprova conteúdo legítimo ensina a contornar o validador em vez de confiar nele. Quando uma regra barrar algo correto, conserte a regra, não o conteúdo. Isso já aconteceu duas vezes:

- A regra de alternativas repetidas comparava os textos em minúsculas e reprovava `True` ao lado de `true`, que numa linguagem *case-sensitive* são respostas realmente diferentes e um distrator legítimo. Hoje ela preserva a caixa, e diferença apenas de caixa é `[AVISO]`, não `[ERRO]`.
- A regra de impressão digital, na primeira versão, acusaria a resposta `3` em JavaScript contra a mesma resposta em Python. Hoje é escopada por linguagem.

Nas duas, a saída certa foi `[AVISO]`: o `Report` distingue aviso de defeito justamente para relatar o que é suspeito sem barrar o que é válido.

#### Regra de impressão digital

Avisa quando duas questões da mesma linguagem cobram a **mesma resposta**. Ela não compara enunciados: onze questões do banco têm o mesmo `prompt` ("O que este código imprime?") e são todas legítimas. O que se repete numa questão disfarçada é a resposta.

A chave é assimétrica, e o motivo importa:

| Tipo | Chave | Motivo |
|---|---|---|
| `fillBlank` / `freeWrite` | só a resposta | O aluno *produz* a resposta, então ela é o próprio conceito. O `topic` fica de fora de propósito: a mesma resposta cobrada sob outro tópico continua sendo a mesma questão com outra roupagem |
| `multipleChoice` | resposta + `topic` | Ali a resposta costuma ser o valor de saída (`True`, `3`, `5.0`), não o conceito. Sem o `topic`, questões legitimamente distintas colidiriam o tempo todo |

Ela já pegou um defeito real: as questões `python-beg-0203` e `python-beg-0206` tinham o mesmo gabarito `5.0`, mesmo tópico e mesma lição, o que tornava a segunda adivinhável depois da primeira.

### Convenções de nome

- Lição: `content/<linguagem>/<linguagem>-<beg|int|adv>-<NN>.json`
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

1. Ler os JSON de `content/` empacotados como asset do app
2. Tela de exercício conforme `docs/mockup-tela-exercicio.html`
3. As três formas de resposta: múltipla escolha, lacuna e escrita livre
4. `normalize()` portado para Dart, com os mesmos testes negativos do validador
5. Embaralhamento das alternativas a cada exibição
6. Progresso salvo local a cada questão respondida

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
