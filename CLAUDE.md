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

**Ambiente do Gustavo:** Windows, VS Code, repositório em `D:\repositorios\DevLingo`. O disco C: está quase cheio, então Flutter SDK, Android SDK, cache do Gradle e emuladores devem ser apontados para o D: via variáveis de ambiente (`ANDROID_USER_HOME`, `GRADLE_USER_HOME`, `PUB_CACHE`). Nada de espaço no caminho de instalação do Flutter.

Repositório remoto: `https://github.com/gustavoanderson/DevLingo` (público).

---

## Banco de questões

### O princípio central do formato

Uma questão separa **o que ela mostra** do **como é respondida**. O campo `code` é opcional e independente do campo `answerType`. Isso permite qualquer combinação (teórica pura, teórica com código, lacuna com código, escrita livre) sem criar tipos novos. Não quebre essa separação.

### Regras que não se negociam

- **`id` é imutável.** O progresso do usuário aponta para ele. Para aposentar uma questão, remova-a; nunca reaproveite o identificador.
- **`hint` e `explanation` são obrigatórias.** A dica ajuda quem travou sem entregar a resposta. A explicação aparece depois de responder e é onde o aprendizado acontece.
- **Múltipla escolha tem exatamente 5 alternativas e 1 correta.**
- **Distribua os gabaritos.** Se mais da metade cair na mesma letra, o validador reprova. Isso já aconteceu: a primeira lição de Python saiu com os 6 gabaritos em "a".

### Normalização de respostas escritas

`spaces: true` ignora **apenas espaços irrelevantes**, os que tocam pontuação ou operador. O espaço obrigatório entre duas palavras é sempre exigido.

Isso foi corrigido depois de um defeito real: a versão antiga removia todos os espaços, e `consttotal=0` era aceito como resposta certa para `const total = 0;`. Python nunca revelaria isso; JavaScript revelou. Se for mexer em `normalize()`, escreva testes negativos, não só positivos.

### Validador

```bash
pip install jsonschema
python3 tools/validate_questions.py content/
```

Saída 0 aprova, 1 reprova. Roda também em GitHub Actions a cada push. Toda vez que um defeito de conteúdo for encontrado à mão, escreva a regra correspondente no validador e prove que ela pega, rodando contra um arquivo defeituoso de propósito.

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

Concluído: identidade visual, ciclo de caminhada, esquema do banco, validador com CI, layout da tela de exercício, três faixas de cenário (dia, tarde, noite), lição 1 de Python iniciante, lição sonda de JavaScript iniciante.

Próximo: completar Python iniciante (lições 2 a 5), depois Python intermediário e avançado, e só então JavaScript e Node de verdade. Uma linguagem por vez, porque calibrar dificuldade exige comparar as questões entre si.

**Pendente e combinado:** perto da lição 4, escrever uma regra no validador que compare enunciados parecidos e avise sobre questões repetidas com outra roupagem.

O ambiente Flutter ainda **não** foi instalado. Isso foi adiado de propósito: ambiente instalado e não usado envelhece e pede atualização justo no dia em que se precisa dele.
