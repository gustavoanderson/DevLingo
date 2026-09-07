# CLAUDE.md

Contexto do projeto DevLingo. Leia antes de qualquer tarefa neste repositório.

---

## Como trabalhar com o Gustavo

Ele está em transição de carreira de implantação de telecom para engenharia de qualidade de software, e este projeto é ao mesmo tempo aprendizado e portfólio.

Duas regras que ele pediu explicitamente e que valem em toda sessão:

1. **Seja muito didático.** Explique o raciocínio por trás de cada decisão técnica, não só o resultado. Ele quer entender, não só receber pronto.
2. **Nunca avance sem consultar.** Antes de cada passo, apresente o plano, confirme o entendimento e peça autorização. Ele atua como manager: a análise técnica é sua, a decisão é dele.

Declare erros e limitações abertamente. Isso já aconteceu várias vezes na construção deste repositório e funcionou bem: defeito encontrado vira teste automático.

**Antes de qualquer commit, rode a suíte inteira, não só o arquivo que você mexeu.** Um commit já foi para a `main` com o CI vermelho porque só o arquivo novo tinha sido testado — e o que quebrou foi um teste de *outro* arquivo, que dependia de como o widget alterado renderizava. Mudança em componente compartilhado quebra quem o testa de fora. O Gustavo dispensou hook de pré-commit e confiou na disciplina; esta linha existe porque a sessão que vem não lembra desta.

```bash
python3 tools/validate_questions.py app/assets/content/   # banco
python3 tools/test_normalize.py                            # contrato
cd app && flutter analyze && flutter test                   # app
```

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
- **Distribua os gabaritos mesmo assim.** Defesa secundária, para o caso de o embaralhamento estar desligado ou quebrado. O validador reprova **dois** vieses:
  - **Concentração:** mais da metade dos gabaritos na mesma letra. Já aconteceu — a primeira lição de Python saiu com os 6 em "a".
  - **Letra nunca usada:** com 5 ou mais questões de múltipla escolha, as cinco letras cabem, e nenhuma pode ficar de fora. Também já aconteceu: oito lições escritas à mão cobriam as cinco por instinto, e as duas escritas em lote nunca usaram `d` nem `e`. **Instinto não escala; regra escala.**

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
- Questão: `<linguagem>-<beg|int|adv>-<NNLL>`, onde NN é a lição e **LL é a ordem de criação dentro dela, não a posição na tela**

**LL não é posição, e nunca foi.** A tela embaralha as alternativas, e um dia pode embaralhar as questões; posição na tela nunca esteve no `id`. Tratar LL como ordem de criação é o que permite **aposentar uma questão sem renumerar as outras** — e renumerar seria mudar `id`, que a regra proíbe.

Por isso o banco tem buracos, e eles são corretos. A `javascript-beg-01` pula `0104`, `0108` e `0109`: essas três cobriam comparação, funções e arrays com uma questão cada, saíram na redistribuição da trilha de JavaScript, e **os identificadores delas nunca serão reaproveitados**.

---

## Identidade visual

Paleta e tipografia detalhadas em `docs/paleta.md`. Resumo do que mais importa:

- Fundo `#170A31`, acerto `#FF2D95`, destaque `#00E5FF`, visor `#39FF14`, telemetria `#FFE14D`, texto `#F2F0FF`
- **O verde é acento, nunca corpo de texto.** Verde saturado em texto longo reprova em contraste
- Logo em fonte monoespaçada com deslocamento em ciano e magenta (aberração cromática). Nada de fonte cyberpunk baixada, que quebra em dispositivos sem ela
- Mascote em `assets/mascot/`. O arquivo animado usa SMIL e **não é reproduzido pelo `flutter_svg`**: no app, refaça o movimento com Rive, Lottie ou AnimationController
- Existe uma **variante de tamanho pequeno** do mascote, com cabeça proporcionalmente maior e traços mais grossos. Em tamanho miúdo não se reduz o desenho, redesenha-se. Ela vive dentro de `tools/gerar_faixas.py`
- As três faixas de cenário estão em `assets/cenarios/`, geradas por `tools/gerar_faixas.py` **junto com** `app/lib/ui/cenario_gerado.dart`. Edite o gerador, nunca os arquivos gerados: o validador reprova quando eles divergem
- O mockup navegável da tela está em `docs/mockup-tela-exercicio.html`. Abra no navegador para consultar durante a implementação

### Escrever SVG que o `flutter_svg` desenha de verdade

Três regras aprendidas apanhando na tela do emulador, ao fazer `tronikat-retrato.svg`. Todas custaram um ciclo de build inteiro para descobrir:

1. **Volume se faz com tons chapados, não com gradiente.** Um `linearGradient` num `<path>` da meia-cabeça simplesmente não foi aplicado: a metade metálica saía branca, com a camada de baixo aparecendo. O mesmo gradiente funciona em `<polygon>`, `<rect>` e `<ellipse>`. A causa raiz não foi isolada — e o `moletom` funciona num `<path>` com curva, então "gradiente em path não funciona" seria conclusão larga demais. O que se sabe é o suficiente: **preenchimento chapado desenhou em todos os testes.** Empilhe formas chapadas para fazer o bisel e a face iluminada.
2. **`radialGradient` não apareceu.** O visor renderizou preto. Troque por `linearGradient`.
3. **Nada de `--` dentro de comentário XML.** O padrão proíbe, o `flutter_svg` tolera e desenha assim mesmo. Tolerância não é contrato: basta trocar de versão para o desenho sumir sem ninguém ter mexido nele. O validador agora reprova (`check_svgs_bem_formados`).

E a regra que vale mais que as três: **nenhuma cor é escolhida até ser vista renderizada.** A primeira versão do retrato tinha o aço começando em `#DCDEEC`, quase o branco do pelo — no papel era "metal claro", na tela era um gato branco comum, com o conceito do personagem invisível. A ferramenta para isso é a captura de tela, não a leitura do arquivo.

### Traço de identidade se copia, não se inventa

`assets/mascot/tronikat.svg` é a **fonte da verdade do personagem**. Ao desenhar o Tr∅nikAt em qualquer enquadramento novo, abra aquele arquivo e copie os traços que definem quem ele é, com as proporções convertidas para o novo tamanho.

Isso virou regra porque eu errei: o retrato saiu com **olho âmbar de pupila em fenda**, invenção minha. Na arte canônica o olho é `<ellipse ... fill="#17092E">` inteiro com um `<circle>` branco em cima — preto, redondo, simples. Ficou bonito e ficou errado: um gato de olho âmbar é outro gato. O Gustavo notou na hora, comparando as duas telas.

A linha entre copiar e recriar:

- **Identidade — copie:** cor e forma do olho, **ângulo das orelhas**, verde do visor, costura ciano da divisa, rosa do focinho e da orelha interna, o `>_` no peito, a assimetria pelo/metal
- **Densidade — pode recriar:** quantas placas, quantos rebites, marcas de calibragem, reflexos. Em close cabe mais detalhe, do mesmo jeito que na variante miúda cabe menos

**Converta por escala, não por olho.** As duas cabeças têm razão conhecida (`rx` 52→128, `ry` 46→118): aplique-a nos pontos da referência e depois ajuste só o que não couber no viewBox, encolhendo em torno do centro da própria base para não mudar o ângulo.

Isso porque desenhar a olho já falhou duas vezes seguidas, e a segunda foi medível. As orelhas do retrato saíram a **36° da vertical**, contra **8° da referência** — mais de quatro vezes mais deitadas, e ficou parecendo outro bicho. O Gustavo pegou comparando com o mascote da escolha de linguagem, que está na mesma tela do app.

Ângulos corretos, medidos do centro da base até o ápice, para conferir se alguém mexer:

| Orelha | Referência | Retrato |
|---|---|---|
| Esquerda (pelo) | 8,1° | 7,6° |
| Direita (metal) | 9,9° | 9,7° |

Orelha de gato é quase reta. Poucos graus a mais já leem como orelha caída, que é outro animal. E a direita **não é o espelho da esquerda** em nenhuma das duas artes: ela é um pouco maior e tem a base mais inclinada.

**Quando o Gustavo apontar algo estético, procure o número antes de mexer.** Nas três correções deste retrato — olho, proporção do corpo e orelhas — o que ele descreveu em palavras tinha uma causa exata e verificável no arquivo: uma cor inventada, uma margem que não deveria existir e um ângulo quatro vezes maior. Ajustar "até ficar bom" teria custado várias rodadas de build; medir resolveu em uma.

Não é liberdade menor do que parece: é a mesma regra já registrada para a variante pequena, onde **em outro tamanho não se reduz o desenho, redesenha-se**. O que não muda de tamanho é quem o personagem é.

### Close é corte, não redução

O retrato tinha "cabeção para corpo pequeno", e a causa não era a cabeça: os ombros iam de `x=22` a `x=378` num viewBox de `0` a `400`. Sobrava margem dos dois lados, o corpo virava uma **figura fechada e completa dentro do quadro**, e o conjunto lia como bonequinho.

Enquadramento que cabe todo dentro da moldura não é close — é retrato de corpo inteiro pequeno. Hoje os ombros são desenhados de `x=-40` a `x=440`, **sangrando de propósito**, e o `_Mascote` não tem folga lateral nenhuma, senão os traria de volta para dentro.

Vale saber, ao mexer nisso, que **na arte canônica a cabeça (104 de largura) é mais larga que os ombros (88)**. O personagem tem cabeça grande mesmo, e é o estilo dele; o que equilibra lá são as pernas longas, que num busto não existem. Por isso num close o equilíbrio precisa vir do corte.

Duas armadilhas menores da mesma rodada: **pescoço que afina para baixo** vira balde, porque não encontra ombro nenhum — ele tem que alargar; e **linha de ombro feita com uma quadrática única de ponta a ponta** vira colina, porque o topo fica alto demais para a largura. Ombro tem quina; o moletom só a suaviza.

Quando um desenho não aparece, **sonde antes de teorizar**: pinte a forma de `#FF0000` chapado e rode. Se o vermelho aparece, o caminho está certo e o problema é o preenchimento. Isso derrubou duas hipóteses minhas em um build.

---

## Tela de título

A primeira tela do app, no formato de fliperama: o Tr∅nikAt em close respirando, fundo synthwave e "Aperte START para iniciar" piscando. Toque em qualquer lugar toca a ficha e entra.

Ela não é só enfeite: **ocupa o tempo de abrir o banco de questões e o de progresso**, que antes era uma roda de carregamento num fundo vazio. A espera não diminuiu; deixou de ser uma espera.

Quatro decisões combinadas com o Gustavo, e o motivo de cada uma:

- **Aparece em toda abertura**, não só na primeira. É a porta do fliperama. Quem faz isso valer é o campo `_comecou` em `main.dart`, que impede o `FutureBuilder` de voltar para ela ao reconstruir
- **O toque nunca é ignorado.** Se a carga não terminou, a ficha toca na mesma hora e a tela passa a dizer "CARREGANDO...", entrando sozinha quando ficar pronta. Botão que não responde é lido como app travado, e o usuário toca de novo, mais forte
- **A ficha divide a chave de som da fanfarra.** Duas chaves obrigariam a desligar som em dois lugares, e "desliguei o som e ainda apitou" é defeito de produto
- **Respeita "reduzir animações" do Android.** Respiração e piscar param, a tela continua inteira e o START continua funcionando

Detalhes de implementação com motivo:

- **Um `AnimationController` só.** A respiração é o ciclo (3,6 s); o piscar é uma subdivisão dele (4 por ciclo, 900 ms). Dois controladores seriam dois relógios acordando o mesmo quadro
- Respiração de **2%**, ancorada em `Alignment.bottomCenter`. Mais que isso vira zoom, e zoom em loop embrulha o estômago. Ancorar no centro afastaria a cabeça dos ombros, que não é respirar
- O piscar liga e desliga **seco**, sem transição: fliperama de 32 bits não tinha canal alfa para desvanecer. Usa `Opacity`, e não `Visibility`, senão o que está em volta pularia de lugar a cada 900 ms
- O fundo é `CustomPainter`, não SVG: **grade em fuga é geometria calculada**, e coordenadas escritas à mão não se adaptam a tela nenhuma. Ele é estático e fica dentro de um `RepaintBoundary`, senão cada quadro da respiração repintaria a grade inteira
- **Recorte no disco do sol é obrigatório.** As fatias são retângulos da largura do sol; sem `clipPath`, no topo — onde o círculo é estreito — elas sobram para os lados e viram traços escuros soltos no céu. Isso apareceu na tela como se fossem falhas de renderização

A tela recebe `pronto` e `aoIniciar` de fora justamente para ser testável sem I/O: ela não sabe o que é um banco de questões. Ver "Testes de widget não enxergam I/O real".

### A cena animada da tela de entrada

`app/lib/ui/cena_do_login.dart`. O Tr∅nikAt programando em primeiro plano; ao fundo, **o mesmo** Tr∅nikAt rodopiando em meio a um rastro de arco-íris.

#### Nyan Cat não, mascote nosso

A ideia do Gustavo era o Nyan Cat. Ele **não é meme de domínio público**: é obra de 2011 de Christopher Torres, registrada e licenciada comercialmente. Reproduzi-lo num app que é portfólio público, e candidato à loja, é risco real, não teórico.

O que produz o efeito não é protegido — gato voando, rastro de arco-íris, estrelas. Protegido é aquele desenho. Então a cena usa o Tr∅nikAt, o que além de seguro reforça a identidade do projeto em vez de emprestar a de outro.

#### Uma função só desenha o personagem

`_tronikat` desenha o Tr∅nikAt inteiro, e os **dois** gatos da cena chamam ela. Isso não é economia de código: é o que garante que sejam o mesmo personagem.

A primeira versão tinha dois desenhos separados, e o Gustavo listou o que faltava no voador: sem olho, sem boca, sem bigode, sem a divisa entre a metade viva e a metálica. Com uma função só, esquecer um traço num dos gatos deixou de ser possível.

**A pose é parâmetro, o personagem não.** `_Pose.digitando` põe os braços no teclado; `_Pose.girando` abre braços e pernas para a pirueta. Na primeira versão o voador não tinha membro nenhum — o desenho só sabia fazer braços indo ao teclado, e o gato do arco-íris saiu como um tronco girando.

#### Proporção se mede, não se estima

O Gustavo disse que o corpo estava "muito gordo em relação à cabeça". Medindo `tronikat.svg`, o diagnóstico era outro:

| | Canônico | Estava | Erro |
|---|---|---|---|
| corpo topo ÷ cabeça | 0,73 | 0,73 | certo |
| corpo base ÷ cabeça | 0,85 | 0,87 | certo |
| **corpo altura ÷ cabeça** | **0,88** | **1,43** | **+63%** |

A largura estava certa; a **altura** é que estava 63% maior, e o corpo lia como um tubo. Terceira vez neste projeto em que uma queixa estética tinha um número exato por trás — ver "Traço de identidade se copia, não se inventa".

#### O que mais faltava, e estava nas duas artes canônicas

- **A cauda termina numa luz verde.** Está em `tronikat.svg` (`circle r=6 fill=#39FF14`) e em `gerar_faixas.py` (`("disco", 16, -27, 2.5, "#39FF14")`). Faltava aqui
- **Orelhas a 6 graus da vertical**, coladas na cabeça. Orelha inclinada já custou uma correção no retrato

#### Decisões de tela

- **O psicodélico fica dentro do painel**, não na tela inteira. Fundo mudando de cor atrás de campo de senha prejudica a leitura de quem está digitando — e esta é a porta do app
- **O voador fica DENTRO do arco-íris**, não na frente: o rastro é pintado atrás dele e depois repintado por cima com transparência. Sem essa terceira passada ele parecia um adesivo colado na fita
- **Congela com o teclado aberto**, e não some. Sumir faria o formulário saltar no meio da digitação
- **`comCena` é falso por padrão, e o app passa verdadeiro.** Animação em `repeat()` faz `pumpAndSettle` esperar para sempre, e isso derrubou doze testes desta tela de uma vez. Com o padrão falso, quem escreve um teste novo não tropeça

### Dá para voltar à tela de título

Sem isso, **rever a abertura exigia fechar e reabrir o app** — que é um jeito ruim de dizer "esta tela não é para ser vista de novo". Ela é a porta do fliperama, não um vídeo de introdução que se pula uma vez.

Voltar é só `setState(() => _comecou = false)` em `main.dart`. A carga já terminou, então a tela reaparece com `pronto: true`, o próximo START entra na hora, e **nada é recarregado**: o progresso continua onde estava.

São dois caminhos porque há dois pontos de entrada:

| Onde | Como |
|---|---|
| Escolha de linguagem | Botão `TELA DE INÍCIO`, discreto, no topo |
| Trilha, quando é a primeira tela | A **mesma** seta de voltar que já existia, que antes ficava nula |

A segunda merece atenção: com uma linguagem só no banco, o app abre direto na trilha e a tela de escolha nem existe. Em vez de um segundo botão, a seta que já estava lá muda de destino — ela sempre volta um passo, e qual é esse passo depende de por onde se entrou.

O botão é **secundário de propósito**: a ação principal da tela é escolher uma trilha. E ele **não toca a ficha** — a moeda é o som de entrar no fliperama, e voltar para a abertura não é inserir moeda; inserir moeda é o START de lá.

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

### Navegação

```
Título  →  Escolha de linguagem  →  Trilha  →  Aula  →  Questões
   ↑                 ↑                  ↑                  │
   └─ TELA DE ───────┘                  │                  │
      INÍCIO         └───── voltar ─────┴──── ✕ / fim ─────┘
```

Com uma linguagem só, a escolha de linguagem some do caminho e a seta da trilha
passa a levar direto ao título. Ver "Dá para voltar à tela de título".

**A escolha de linguagem só aparece quando há mais de uma trilha.** Com uma só, o app abre direto nela: tela de escolha com um item é cerimônia vazia.

**Nada tranca.** Qualquer lição abre a qualquer momento. Trancar puniria — a mesma razão pela qual errar não termina a questão — e atrapalharia quem quer revisar uma lição antiga ou espiar a seguinte.

**Lição concluída = todas as questões respondidas**, independente de quantas tentativas cada uma custou. Coerente com "o objetivo é aprender, não acertar de primeira".

A trilha é onde o progresso gravado a cada questão deixa de ser dado guardado e vira algo que o aluno enxerga. A contagem vem de **uma consulta agrupada**, não uma por lição.

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

### Estatísticas do jogador

Ideia do Gustavo: mostrar ao jogador o desempenho dele — quantas acertou de primeira, quantas tentativas levou, e o que mais fizer sentido. Substitui, e amplia, a "tela de revisão dirigida" que estava na lista.

**A COLETA está pronta (versão 4 do banco). A TELA ainda não existe**, e essa separação foi deliberada: dado não coletado é dado perdido, e nenhuma tela futura consegue reconstruir quanto tempo alguém levou numa questão que já respondeu. A tela pode esperar o tempo que for; a medição tinha que começar antes de alguém jogar.

#### O que o banco responde hoje

`resumoDoJogador()` e `custoPorTopico()` existem **sem tela nenhuma que os use**, pelo mesmo motivo: provar que o formato responde às perguntas que motivaram guardar os dados. Descobrir que falta uma coluna no dia de desenhar a tela seria tarde demais.

| Métrica | De onde sai |
|---|---|
| Questões respondidas, por lição e linguagem | `respondidasPorLicao()` |
| Acertos de primeira, e a taxa | `deCabeca`, `taxaDeCabeca` |
| Reveladas, e em quais tópicos | `reveladas`, `custoPorTopico()` |
| Média de tentativas por questão | `tentativasPorQuestao` |
| Quantas vezes pediu a dica | `comDica` |
| Tempo médio por questão | `tempoMedioPorQuestao` |
| Partidas totais, contando as repetidas | `partidas` |
| Em quantos dias distintos jogou | `diasEstudados` |

#### As duas tabelas, e por que são duas

- **`resposta` é o ESTADO ATUAL**, uma linha por questão, com `question_id` como chave primária. É o que a trilha consulta toda vez que abre, então precisa continuar pequeno
- **`evento_resposta` é o HISTÓRICO**, só cresce, uma linha por vez que a questão foi respondida. Só é lido quando alguém abrir estatísticas

Uma tabela só obrigaria a escolher entre as duas coisas: ou a trilha passa a varrer o histórico inteiro para contar questões respondidas, ou o histórico é destruído a cada vez que alguém refaz uma lição. **Refazer sobrescreve em `resposta` e acumula em `evento_resposta`** — é isso que torna possível falar em evolução.

#### Decisões que a estatística exige e que são fáceis de errar

- **Nulo é "não medido", nunca zero.** Quem jogou antes da versão 4 tem registro sem tempo e sem dica. Gravar zero seria mais simples e mentiria nas médias: uma questão "respondida em 0 segundo" puxaria a média para baixo e ninguém saberia por quê. Por isso `ResumoDoJogador` carrega `questoesComTempo` ao lado de `tempoMedido` — dividir pelo total daria média errada
- **`tetoDeDuracao` é 10 minutos, e é um chute confesso.** O app não distingue pensar de ir almoçar. Sem teto, uma questão de seis horas destrói qualquer média e a estatística passa a mentir sem avisar, o que é pior que não existir. Recalibrar quando houver dados reais
- **Pedir a dica ≠ a dica abrir sozinha.** Ela abre sozinha no segundo erro de uma questão de escrita. Contar isso como "usou a dica" transformaria "pedi ajuda" em "errei duas vezes". Por isso `SessaoQuestao` tem `dicaPedida` separado de `dicaAberta`, e só o primeiro vai para o banco
- **`SessaoQuestao` recebe um relógio injetável.** Sem isso, o teste teria que esperar de verdade ou aceitar qualquer número, que é o mesmo que não testar
- **Toda saída de `respondendo` passa por `_concluir`.** Atribuir `fase` direto em cada ramo funcionava, mas bastaria um ramo novo esquecer o carimbo da hora para a duração sumir sem nada quebrar

#### Quando a tela for feita

- **Nada de "você está pior que ontem".** A mecânica inteira foi desenhada para não punir; estatística que cobra é a mesma punição em forma de número
- **Tempo não vira competição.** Medir para o aluno se conhecer, não para ele correr — pressa é inimiga de entender
- **A tela precisa tratar o nulo.** Partidas anteriores à versão 4 não têm tempo nem dica, e fingir que têm é o único jeito de a tela mentir

#### Migração com duas rotas: prove que convergem

Um esquema pode ser alcançado por dois caminhos — o `CREATE TABLE` de quem instala agora, e o `ALTER TABLE` de quem atualiza. Se divergirem, o defeito só aparece em quem instalou numa versão específica, que é o tipo de bug que não se reproduz na máquina de ninguém.

As colunas novas vivem numa lista só (`_colunasDeMedicao`) usada pelas duas rotas, e **um teste compara o `PRAGMA table_info` das duas**. Ele foi verificado introduzindo uma divergência de propósito: uma coluna só no `CREATE`. O teste reprovou, como devia.

Vale registrar como essa verificação quase falhou: o script que introduziu a divergência **não substituiu nada e mesmo assim imprimiu sucesso**, e o teste passou. Por um instante isso parecia prova de que o teste era falso negativo — quando na verdade o experimento nunca tinha acontecido. Ao sondar, confirme que a sonda entrou no arquivo antes de acreditar no resultado.

### Migração do banco: nunca recriar

O app já está no celular de alguém, com progresso dentro. Ao mudar o esquema, **recriar o banco do zero é mais simples e apaga o progresso do aluno** — que é exatamente o que o `Progresso` existe para não fazer.

Suba a `versao`, acrescente o degrau em `_migrar`, e mantenha o `CREATE TABLE` numa função só, usada pelo `onCreate` e pelo `onUpgrade`. Duas cópias do mesmo `CREATE TABLE` divergem com o tempo, e a diferença só aparece em quem instalou o app numa versão específica.

**E escreva o teste de migração:** ele cria um banco exatamente como a versão antiga o deixava, com dados dentro, abre com o código novo e confere que o progresso sobreviveu. É a única forma de saber que a atualização não vai destruir dado de usuário, e não dá para descobrir isso em produção.

### Testes de widget não enxergam I/O real

`testWidgets` roda numa zona de tempo falso. I/O de verdade — SQLite, rede, arquivo — **nunca avança** nela, e um `await` no banco dentro de um teste de widget trava o arquivo inteiro em vez de falhar. Isso já aconteceu: um teste ficou 10 minutos pendurado e derrubou os outros 16 junto.

A saída não é `tester.runAsync`, é **depender de interface**. A tela recebe `RegistroDeProgresso`, e o teste de widget passa uma implementação em memória. Assim o teste de tela prova o que deve provar — que a tela chama o repositório com os dados certos — e o SQLite continua provado à parte, em `progresso_test.dart`, com banco de verdade e um caso que fecha e reabre o arquivo.

### Cenário animado: implementado, e as regras que ele cumpre

Vive em `app/lib/ui/faixa_cenario.dart`, colado na borda de baixo da tela de exercício. O Tr∅nikAt caminha parado e o cenário desliza atrás dele, no sentido oposto ao que ele aponta. Cada camada é desenhada duas vezes e desliza exatamente a largura de um bloco, o que torna o loop invisível: o quadro em que ela volta ao início é idêntico ao anterior.

As sete regras, e o estado de cada uma:

1. **Um `AnimationController` só**, e ele mede o ciclo mais longo — o da camada de trás. As outras duas velocidades, e o passo do gato, saem daquele valor por multiplicação. Com um relógio por camada, elas sairiam de sincronia ao longo dos minutos e o loop deixaria de fechar
2. **`RepaintBoundary`** isolando a faixa
3. **Para em segundo plano**, via `WidgetsBindingObserver`
4. **Congela com o teclado aberto**, e continua na tela. Sumir com ela faria o layout pular no meio da digitação, que é pior que o movimento
5. **Respeita "reduzir animações"** do Android
6. **Chave manual**: o ícone de montanha na trilha, ao lado do de som. Desligar **tira a faixa**, não apenas para o movimento — quem desliga quer a tela sem aquilo, não um cenário parado ocupando 58 pixels
7. O véu escuro não se aplica a uma faixa de 58px na borda; ele volta a valer se um dia o cenário ocupar a tela inteira atrás do card

**A camada de trás é mais lenta que a da frente, e essa diferença é a única coisa que produz profundidade.** Um teste trava isso: se as duas velocidades ficarem iguais, o parallax vira um fundo deslizante e ninguém percebe o que se perdeu.

**A preferência do cenário mora na tabela `preferencia`**, que nasceu genérica — chave e valor — justamente porque este segundo uso estava previsto. Ela chegou sem custar migração nenhuma.

#### Animação infinita quebra `pumpAndSettle`

`pumpAndSettle` espera a árvore ficar parada, e uma animação em `repeat()` nunca fica. Três testes da trilha estouraram o limite de tempo assim que o cenário passou a vir ligado por padrão — sem defeito nenhum no código.

A saída foi o `ProgressoFalso` dos testes nascer com o cenário **desligado**, e um grupo próprio provar que a preferência ligada funciona, usando `pump` com duração explícita. É a mesma família do problema já registrado em "Testes de widget não enxergam I/O real": o relógio do teste não é o relógio do app.

#### O gerador escreve SVG **e** Dart

`tools/gerar_faixas.py` emite duas saídas a partir da mesma fonte:

| Saída | Para quê |
|---|---|
| `assets/cenarios/faixa-{dia,tarde,noite}.svg` | Referência de arte: abre no navegador, entra em pull request, anima em SMIL |
| `app/lib/ui/cenario_gerado.dart` | O que o app desenha de verdade |

O app **não lê os SVGs**: a animação deles é SMIL, que o `flutter_svg` não reproduz, e cada faixa é um arquivo único com as camadas dentro — não há como deslizar uma sem a outra. Então o app desenha com `CustomPainter`.

Isso criaria uma segunda cópia da geometria, e duas cópias divergem. A saída foi emitir as duas do mesmo script, com **as mesmas strings de caminho** indo para os dois lados. O `path_parsing` (declarado explicitamente no `pubspec.yaml`, e não usado de carona no `flutter_svg`) lê essas strings no Dart.

**O validador reprova quando um arquivo gerado difere do que o gerador produz** (`check_gerados_em_dia`). Ele roda o gerador em memória e compara com o disco. Sem essa regra, editar o Dart à mão funcionaria — o app compila, os testes passam, a tela muda — e a divergência só apareceria quando outra pessoa rodasse o gerador e visse a mudança sumir sem explicação.

**Nenhum caminho do cenário usa arco elíptico**, e há um teste que impede a reintrodução. O `A` já custou uma rodada de depuração no retrato do mascote, quando a corda entre os pontos batia com o diâmetro.

#### Como verificar que anima, e não só que desenha

Desenhar e animar são coisas diferentes, e o teste de widget não distingue. A verificação foi feita capturando três quadros no emulador com ~0,9 s entre eles e contando pixels diferentes por região:

```
quadro 1 -> 2:  pixels mudados na FAIXA = 71209   no CONTEUDO acima = 0
quadro 2 -> 3:  pixels mudados na FAIXA = 65786   no CONTEUDO acima = 0
```

Setenta mil pixels mudando na faixa e **zero** acima dela. O script está no scratchpad da sessão; para repetir, use `Pillow` com `ImageChops.difference` sobre recortes das duas regiões.

---

## Conta e login

**Decisão do Gustavo: conta obrigatória.** Ninguém joga sem entrar.

Eu havia recomendado outra coisa — backup automático do Android primeiro, conta depois — e a recomendação foi recusada com a informação na mesa. Fica registrado para uma sessão futura não "corrigir" isto achando que foi descuido: **é escolha, não esquecimento.**

### Obrigatória a CONTA, não a rede

Sem esse desenho, login obrigatório brigaria com o offline-first já decidido para o projeto. Como fica:

- A **primeira** abertura precisa de internet, para entrar ou criar conta
- Depois disso a sessão fica em cache e o app abre **offline**, com o usuário já autenticado
- Por isso `_usuario` em `main.dart` nasce lendo `autenticacao.usuarioAtual`, e não nulo
- A mensagem de erro de rede diz isso em voz alta: *"precisa de internet só para entrar; depois disso ele funciona offline"*. Se a pessoa achar que o app inteiro exige conexão, ela desinstala

### A ordem é título → login → trilha

O formulário aparece **depois** do START, não antes. A arte do fliperama é a primeira coisa que a pessoa vê; login como primeiríssima tela transforma a abertura do app num pedágio.

### O que a tela de entrada garante

Os três modos — entrar, criar conta, recuperar senha — são **um formulário só** com o botão trocado. Três telas separadas repetiriam campo, validação e tratamento de erro em triplicata, e é assim que uma delas acaba com mensagem pior que as outras.

- **Todo erro diz o que fazer.** Numa tela que dá para pular, mensagem ruim é irritação; aqui é a pessoa trancada do lado de fora do app inteiro. Um teste percorre `FalhaDeAutenticacao.values` e reprova mensagem curta demais
- **O que dá para checar sem rede é checado sem rede.** Formato de e-mail e tamanho de senha respondem na hora. Um teste prova que e-mail malformado **nem chega a chamar** a autenticação
- **A validação de e-mail é frouxa de propósito.** Falso negativo aqui tranca a pessoa fora do app; a checagem só pega erro de digitação óbvio. Quem diz se o endereço existe é o e-mail que chega
- **A recuperação NUNCA revela se a conta existe.** Responder "não achamos esse e-mail" entregaria a lista de quem tem conta. Um teste compara as duas respostas e exige que sejam idênticas
- **O mínimo da senha aparece antes de a pessoa errar.** Regra escondida até a falha é regra mal comunicada

### O Firebase está ligado

Projeto **`devlingo-cc399`**, plano Spark (gratuito). Provado no emulador: conta criada de verdade, UID devolvido pelo servidor, e o app reabriu **sem pedir login** — a sessão em cache funciona, que era a promessa central do desenho.

O `google-services.json` fica em `app/android/app/` e **não vai para o repositório** (`.gitignore`). Quem clonar o projeto sem ele **não fica sem app**: o `main.dart` tenta `Firebase.initializeApp()` dentro de um `try`, e ao falhar cai na `AutenticacaoFalsa` com o aviso de demonstração na tela. Tela preta com stack trace puniria quem não tem culpa da configuração.

#### Três coisas que custaram tempo, e valem para a próxima vez

**1. Criar o projeto não liga o Authentication.** O primeiro cadastro falhou com `CONFIGURATION_NOT_FOUND`, que significa que o serviço de autenticação nunca foi iniciado no projeto. Cada serviço do Firebase nasce desligado; o botão **"Começar"** na tela do Authentication é o que cria a configuração. Sem ele, o app fala com o servidor e não encontra serviço atrás da porta.

**2. O menu do console mudou.** A documentação (e eu) dizia *Criação/Build → Authentication*. No console atual não existe "Criação": os produtos foram agrupados por tema, e Authentication está em **Segurança**. O caminho que não envelhece é a URL direta:

```
https://console.firebase.google.com/project/<id-do-projeto>/authentication
```

**3. O APK de debug com Firebase derruba o emulador.** Ele passou de ~110 MB para **155 MB**, e o `adb install` falhava com `Broken pipe (32)` ao chamar o serviço `package` — o `system_server` do emulador morria processando o pacote. O sintoma engana: parece problema de espaço (havia 9 GB livres) ou de assinatura.

O que resolveu foi **desinstalar antes de instalar** e, quando o emulador já estava em estado ruim, reiniciá-lo. Compilar com `--target-platform android-x64` ajuda pouco (155,9 MB contra 163 MB): o peso é do runtime de debug, não das ABIs.

**Desinstalar apaga o `devlingo.db`.** O progresso local se perde — foi o que aconteceu com as 10 questões de Python já respondidas. Em desenvolvimento é aceitável; ao testar migração de banco, não é.

#### O log guarda o código cru do Firebase

Descobrir o `CONFIGURATION_NOT_FOUND` exigiu filtrar o logcat do Android à mão, porque a tela dizia apenas *"algo deu errado ao falar com o servidor"* — correto para quem usa, inútil para quem desenvolve.

`AutenticacaoFirebase._tentar` agora registra o código cru via `debugPrint`, com os casos que **não são culpa de quem digitou** documentados ali: `CONFIGURATION_NOT_FOUND`, `operation-not-allowed` e `api-key-not-valid`. A mensagem na tela continua em português e sem jargão.

#### `invalid-credential` é ambíguo de propósito

Em projetos novos o Firebase liga por padrão a proteção contra enumeração de e-mails, e passa a devolver `invalid-credential` no lugar de `wrong-password` e `user-not-found`. Ele **não diz** qual dos dois foi, justamente para não entregar quem tem conta.

Por isso ele é traduzido para `credenciaisErradas`, cuja mensagem manda conferir os dois campos e oferece a recuperação. Mapeá-lo para "conta não encontrada" devolveria, na mensagem, a informação que o Firebase escondeu no código.

### O que ainda falta, e o que está bloqueado

| Pendência | Estado |
|---|---|
| Projeto no Firebase e `google-services.json` | **feito** (`devlingo-cc399`) |
| Trocar `AutenticacaoFalsa` pela implementação real | **feito** |
| Sincronizar o progresso com o Firestore | falta |
| **O progresso ainda não é por usuário** | falta, junto com o Firestore |

A última é um **defeito real e conhecido**: o `devlingo.db` é único no aparelho e não tem coluna de usuário. Hoje, duas contas no mesmo celular veriam o mesmo progresso. Não foi resolvido agora porque a solução certa vem junto com a sincronização — e resolver pela metade duas vezes custa mais que resolver uma.

Combinado quando o Firebase entrar: **a primeira conta que autenticar no aparelho adota o progresso que já está lá.** O Gustavo já tem partidas gravadas, e elas não podem evaporar quando o login chegar.

### Modo de demonstração

Quando o Firebase **não sobe** — sem `google-services.json`, ou falha na inicialização — o app cai na `AutenticacaoFalsa` e a tela **avisa isso na cara**, num painel amarelo. Login de mentira que não se anuncia é pior que nenhum: a pessoa cadastra um e-mail achando que tem conta e descobre depois que nunca houve conta nenhuma.

O painel é acionado por `_autenticacao is AutenticacaoFalsa`, então ele aparece e some sozinho conforme o Firebase esteja disponível. **O desaparecimento dele foi a primeira prova visual de que o Firebase tinha subido.**

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

Hoje são **104 questões** em 11 arquivos, e o app é jogável de ponta a ponta: título, escolha de linguagem, trilha, aula e exercício, com progresso salvo.

O princípio que ordenou tudo isto continua valendo: **escrever mais conteúdo não aproxima uma versão jogável**, e calibrar dificuldade sem nunca ter jogado é chute. Foi por isso que o Python intermediário esperou a Etapa B, e é por isso que o próximo nível espera o Gustavo jogar o JavaScript.

| Etapa | Entrega | Estado |
|---|---|---|
| **A** | Ambiente Flutter e Android, tudo no D: | **concluída e provada com APK compilado** |
| **B** | **App mínimo jogável** | **próxima** |
| C | Polimento visual: fundo parallax, mascote animado | depois |
| D | Firebase: login e progresso na nuvem | **em andamento** — login funcionando de verdade; falta sincronizar o progresso no Firestore |
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
| **C2** | Trilha e escolha de linguagem | **concluída** |
| **C3** | JavaScript iniciante, 50 questões | **concluída, e ainda não jogada pelo Gustavo** |
| **C4** | Realce de sintaxe nos blocos de código | **concluída** |
| **C5** | Som de acerto | **concluída** |
| **C6** | Tela de título de fliperama, com a ficha | **concluída** |
| **C7** | Coleta de dados para estatísticas (banco v4) | **concluída — falta só a tela** |
| **C8** | Cenário animado em parallax na tela de exercício | **concluída** |
| **D1** | Telas de entrar, criar conta e recuperar senha | **concluída, em modo de demonstração** |
| **D2** | Cena animada da tela de entrada | **concluída** |
| **D3** | Firebase Auth de verdade, com conta criada e sessão persistida | **concluída** |

**Combinado e ainda não feito:**

- **O Gustavo ainda não jogou o JavaScript.** As 50 questões foram calibradas sem ele jogar nenhuma; a dificuldade é palpite meu até ele passar por elas. É a mesma razão que fez o Python intermediário esperar
- **A TELA de estatísticas do jogador.** A coleta já está feita e medindo desde a versão 4 do banco — ver a seção própria em Progresso, que lista o que `resumoDoJogador()` já responde e os cuidados para a tela não mentir
- Verificar o comportamento do som no modo silencioso, num celular de verdade

### Som de acerto

Os dois WAVs são **ondas quadradas sintetizadas**, não instrumentos gravados — chiptune combina com um gato ciborgue de visor neon melhor que orquestra.

**A fonte deles é `tools/gerar_sons.py`, não os arquivos.** Para mudar um efeito, mude as notas no script e rode `python3 tools/gerar_sons.py`; nunca edite o WAV. Mesma regra de `gerar_faixas.py`, e pelo mesmo motivo: arquivo gerado que passa a ser editado à mão diverge do gerador, e ninguém descobre qual dos dois está certo. O script reproduz os dois arquivos **byte a byte** — se parar de reproduzir, alguém mexeu num lado só.

A ficha sai mais baixa (0,30 contra 0,32) e com ataque mais seco que a fanfarra. É deliberado: a moeda é confirmação de interface, a fanfarra é recompensa. No mesmo volume, uma achata a outra.

**Só o acerto tem som.** Errar e revelar são silenciosos: som de erro é punição sonora, e revelar não é conquista. Três testes travam isso.

**O som nunca é o único retorno.** O verde e a explicação funcionam com ele mudo, então desligar não tira informação de ninguém. A chave fica no ícone de som da trilha, e a preferência mora no banco.

**Nada de áudio pode tocar a plataforma antes do primeiro acerto.** O `AudioPlayer` é criado dentro do primeiro `acerto()`, nunca no construtor: criá-lo no construtor punha conversa com o serviço de áudio dentro do `build` de uma tela, que é onde ela não pode estar.

**Pendente de verificação:** o áudio está configurado no canal de notificação, que é o que o modo silencioso do aparelho silencia. Isso **não foi verificado** — no emulador não há como confirmar por `adb` se o som saiu. Confira num celular de verdade.

**Há dois sons, e uma chave só.** `acerto.wav` é a fanfarra; `ficha.wav` é a moeda da tela de título. Os dois passam pelo mesmo `estaLigado` e pelo mesmo tocador — não há por que abrir uma segunda conversa com a plataforma de áudio para telas que nunca disputam a saída. Ambos são gerados por script Python com o módulo `wave`, onda quadrada; não há gravação no repositório.

`SinetaMuda` conta os dois **separadamente** (`toques` e `fichas`). Um contador só provaria que *algum* som tocou, e o teste da tela de título passaria mesmo se ela disparasse a fanfarra de acerto por engano.

### Realce de sintaxe

O tokenizador vive em `app/lib/ui/realce.dart` e é **Dart puro, sem importar Flutter**: classificar código é lógica, pintar é apresentação. As cores vêm do mockup.

**A invariante que o teste prova não olha cor nenhuma:** a concatenação dos tokens tem que ser idêntica à linha original. Um realce que come um caractere — uma aspa, um espaço de indentação — é pior que nenhum, porque o código passa a mentir sobre si mesmo, e isso passa despercebido a olho nu. Essa checagem roda contra **todas as linhas de código do banco**, questões e aulas.

A varredura é **linha a linha**, porque é assim que o bloco desenha. Texto ou comentário que atravesse mais de uma linha não é reconhecido; nenhuma questão usa isso, e aceitar a limitação evita carregar estado entre linhas.

**Linguagem sem tokenizador não quebra o app:** o código só fica sem cor. Isso importa porque o banco prevê nove linguagens que ainda não têm nenhum.

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
#    Captura NO APARELHO e depois puxa. Nao use `adb exec-out screencap -p > x.png`
#    no PowerShell: o `>` de la e redirecionamento de TEXTO, grava BOM na frente
#    e corrompe o PNG. O arquivo sai com tamanho plausivel e nao abre.
adb shell screencap -p /sdcard/tela.png
adb pull /sdcard/tela.png tela.png
```

O print é a única ferramenta que enxerga defeito visual. Cinco vezes neste repositório a suíte ficou verde escondendo algo que só apareceu na tela: a sombra de recorte invisível, os textos sem acento, o aço claro demais no retrato do mascote, o gradiente que não era aplicado e as fatias do sol vazando para fora do disco. **Verde quer dizer "passou nas checagens que existem".**

Três coisas que parecem defeito e não são:

- **A primeira tela fica branca por muito tempo.** É a VM do Dart aquecendo num build de debug. Em relançamento são uns 15 segundos; **numa instalação limpa já levou 57**, com o `ProfileInstaller` rodando junto. Um print tirado cedo demais mostra tela em branco e faz parecer que o app quebrou. Antes de investigar, confira `adb logcat | grep Displayed`: ele imprime `Displayed com.devlingo.app/.MainActivity: +56s887ms`, e `dumpsys activity activities` mostra se o `mResumedActivity` já é o app.
- **O Impeller registra `Could not link pipeline program` no logcat.** É o motor gráfico novo falhando em compilar shaders na GPU emulada. O app renderiza normalmente mesmo assim. Ignore, a menos que a tela realmente não apareça.
- **O Impeller também repete `Attempted to add an invalid command to the render pass`** a cada quadro na tela de título. A tela desenha corretamente, inclusive as sombras do texto e os degradês do fundo. É ruído de validação da GPU emulada. **Ainda não foi confirmado num aparelho de verdade** — se aparecer lá, ou se algo sumir da tela, o primeiro suspeito é `Shadow(blurRadius:)` no texto piscante.

Comandos do PowerShell com aspas aninhadas (`adb shell 'while [ ... ]'`) quebram o parser do PowerShell 5.1. Use o Bash para esses.

Fica **fora** da Etapa B: Firebase, fundo animado, escolha de linguagem, telas de trilha. Uma linguagem, uma trilha, direto ao exercício.

## O que separa um nível do outro

Sem isso escrito, o intermediário vira "iniciante com palavras difíceis".

O critério abaixo **não é opinião**: ele foi extraído medindo as 100 questões jogáveis do iniciante. A proposta anterior, escrita de cabeça, dizia *"iniciante: código de até 3 linhas"* — e reprovava 17 questões legítimas do próprio banco. Medir antes de legislar evitou uma regra que já nasceria brigando com o conteúdo.

### O achado: tamanho de código não mede dificuldade

As duas questões **mais longas** do iniciante são `python-beg-0306` (9 linhas) e `javascript-beg-0205` (8 linhas). As duas são o mesmo padrão:

```python
nota = 7
if nota >= 9:
    print("Excelente")
elif nota >= 7:
    print("Bom")
...
```

Nove linhas, e **um único passo de raciocínio**: ler o valor, descer até o primeiro ramo verdadeiro. Sete questões do iniciante têm 5 linhas ou mais e nenhum estado que mude.

O que cobra passos de verdade é **estado que muda** — um nome reatribuído, um acumulador dentro de laço. É nisso que o critério se apoia.

### O que o iniciante é, medido

| Sinal | O banco atual |
|---|---|
| Nomes distintos no código | 0 em 31 questões, 1 em 39, 2 em 6. **Nenhuma tem 3** |
| Nomes reatribuídos | apenas 3 de 76, e as 3 são sobre variáveis, escopo ou laços |
| Laços | 8 de 76, todas na lição de laços, **nenhuma com acumulador** |
| Linhas de código | mediana 2, máximo 9 — não separa nada |
| Formato | 60% múltipla escolha, 20% escrita livre, 20% lacuna |

### O critério

| Nível | O que a resposta exige | Sinais verificáveis |
|---|---|---|
| **Iniciante** | **um fato, aplicado direto.** Você sabe ou não sabe o que o operador faz | no máximo 2 nomes; no máximo 1 reatribuição; laço só quando o laço é o tema, e sem acumulador |
| **Intermediário** | **dois fatos combinados, ou estado que muda ao longo do código** | 3 ou mais nomes, ou 2 ou mais reatribuições, ou laço com acumulador, ou função definida cujo retorno é usado adiante |
| **Avançado** | **o caso em que a intuição erra.** A pessoa que "já sabe" responde errado | não tem teto de tamanho; o que define é a surpresa, não a extensão |

Regras de conteúdo que acompanham:

- **A explicação muda de foco a cada nível.** Iniciante ensina *o quê*; intermediário ensina *como combinar*; avançado ensina *por quê*
- **Dependência entre questões cresce.** Iniciante não pode depender de ter visto outra questão. Intermediário pode compor conceitos já ensinados na mesma trilha. Avançado pode assumir a trilha inteira
- **Número de linhas não entra no critério.** A evidência acima mostra que ele mede outra coisa

### O validador avisa, mas não reprova

`check_nivel_coerente` compara os sinais medidos com o nível declarado e emite **`[AVISO]`**, nunca `[ERRO]`.

Isso é deliberado, e segue a regra de falso positivo já registrada: a medição é aproximada — ela lê o código com expressão regular, não com um interpretador — e reprovar conteúdo legítimo ensina a contornar o validador em vez de confiar nele. O aviso pede uma segunda olhada; a decisão continua de quem escreve.

O banco aprova hoje com **quatro avisos, e os quatro são intencionais**. Todos são distratores que diferem apenas na caixa, num idioma em que a caixa é justamente o conteúdo da questão:

| Questão | Distrator | Por que existe |
|---|---|---|
| `python-beg-0302` | `true` ao lado de `True` | Em minúsculas daria `NameError`, não o booleano |
| `python-beg-0402` | `ada`, `Ada` ao lado de `ADA` | `Ada` é resultado de `capitalize`, não de `upper` |
| `python-beg-0403` | `OI` ao lado de `oi` | `OI` é o que apareceria se strings fossem mutáveis |
| `javascript-beg-0401` | `ada`, `Ada` ao lado de `ADA` | O distrator natural de `toUpperCase` é o texto intacto |

E um quinto, de outra natureza:

| Questão | Aviso | Por que fica |
|---|---|---|
| `python-beg-0504` | laço com acumulador numa questão iniciante | É o **único acumulador do banco**, e é o motivo de laços existirem. Uma lição de laços sem `total = total + n` ensina laços pela metade |

Esse aviso é **legítimo**, e não falso positivo: a questão realmente exige rastrear `total` mudando a cada volta (0 → 1 → 3 → 6), que é o critério do intermediário. Ela fica no iniciante como **ponte** para o nível seguinte — a última coisa que a trilha mostra antes de o próximo nível assumir. Se o intermediário de Python for escrito e retomar acumuladores do zero, vale reconsiderar.

A tentação aqui era enfraquecer a regra para o caso caber — tolerar acumulador quando o tópico é `lacos`. Foi recusado: a regra está certa, e é a exceção que precisa ser justificada, não o contrário.

Se algum desses avisos sumir, alguém mexeu na questão. Se aparecer um sexto, é para conferir antes de aceitar.
