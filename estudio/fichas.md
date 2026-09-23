# Fichas do Tr∅nikAt

O que o Tr∅nikAt sabe **sobre o DevLingo**, e só isto. O porteiro compara a pergunta do visitante com as `perguntas` de cada ficha; se nenhuma estiver perto o bastante, o modelo nem é chamado.

> **Uma ficha aqui é diferente de todas as outras: a `programacao`.**
>
> Ela não é uma resposta, é uma **placa de desvio**. Quando a busca a escolhe, o
> Tr∅nikAt responde **de cabeça**, sobre programação, sem ficha nenhuma para
> reescrever — porque ele conhece todas as linguagens, e recusar-se a dizer o
> que é um `console.log` era esquisito num app que ensina programação.
>
> A `resposta` dela só é usada se a geração falhar, e por isso é escrita como
> um pedido de desculpa, e não como conteúdo.
>
> Isso reverte, de propósito, a regra antiga de que ele "não dá aula nem
> escreve código" no site. A reversão é segura porque o recorte não mudou: fora
> de programação e do DevLingo, ele continua desconversando.

Regras de quem escreve aqui:

- **Todo número é medido, nunca lembrado.** O teste de 14/09 mostrou dois modelos inventando o resultado de uma conta com confiança total. Se o Tr∅nikAt diz "400 questões", esse número tem que estar escrito aqui, conferido contra o banco
- **Resposta curta**, até ~70 palavras. O modelo roda com a placa no limite (3,2 GB de 4 GB); ficha longa come a janela de contexto
- **Perguntas-exemplo variadas**: do jeito que alguém digitaria de verdade, com e sem acento, formal e informal. A busca aprende o bairro da pergunta por elas
- **`revisar: Gustavo`** marca o que fala dele. É ele quem decide o que o personagem repete sobre ele para todo visitante

---

## o-que-e

fonte: README.md
perguntas:
- O que é o DevLingo?
- Que app é esse?
- Pra que serve isso aqui?
- Me explica o DevLingo

resposta:
O DevLingo é um app Android para aprender programação no formato do Duolingo: lições curtas, questões e progresso salvo a cada resposta. Foi escrito do zero em português, não traduzido.

## trilhas

fonte: app/assets/content (contado em 14/09/2026)
perguntas:
- Quais trilhas existem?
- O que dá pra aprender no app?
- Quais linguagens tem?
- Tem curso de quê?

resposta:
São 8 trilhas: Python, JavaScript, Java, Frameworks, Backend, Qualidade de Software, Selenium e Agentes de IA. Todas estão no nível iniciante por enquanto.

## tamanho

fonte: app/assets/content (contado em 14/09/2026)
perguntas:
- Quantas questões tem?
- Quantas lições são?
- O app é grande?
- Quanto conteúdo tem no DevLingo?

resposta:
São 400 questões para jogar, em 40 lições. São 8 trilhas, cada uma com 5 lições, e cada lição tem 10 questões. Antes das questões, cada lição tem uma aula curta.

## para-quem

fonte: README.md
perguntas:
- Serve pra quem nunca programou?
- Preciso saber programar antes?
- É para iniciante?
- Qual o nível do app?

resposta:
Serve para quem está começando. Todas as trilhas hoje são de nível iniciante, e cada lição abre com uma aula que ensina o que as questões vão cobrar. Ninguém cai de paraquedas.

## errar

fonte: CLAUDE.md, "Como uma questão é respondida"
perguntas:
- O que acontece se eu errar?
- Errei, e agora?
- Perco vida quando erro?
- O app pune erro?

resposta:
Errar não termina a questão. Na múltipla escolha, a alternativa errada é riscada e você tenta de novo. Nas de escrever, o segundo erro abre a dica e o terceiro mostra a resposta. A tela nunca diz "errado": diz "ainda não", e ao revelar diz "vamos juntos".

## aula

fonte: CLAUDE.md, "A aula do Tr∅nikAt"
perguntas:
- Tem teoria ou é só questão?
- O app explica antes de perguntar?
- Onde fica o conteúdo das lições?
- Como eu estudo antes das questões?

resposta:
Tem teoria, sim. Cada lição começa com uma aula que prepara exatamente os tópicos das questões, e dá para reabri-la a qualquer momento pelo ícone de livro, sem perder a questão em que você estava.

## acento

fonte: CLAUDE.md, "Só ASCII no que o aluno digita"
perguntas:
- Preciso digitar acento nas respostas?
- E se eu escrever sem acento?
- O teclado do celular atrapalha?
- Por que as respostas não têm acento?

resposta:
Não precisa. Tudo que você digita como resposta é sem acento, de propósito: acento no celular é toque longo, e ninguém deveria errar uma questão de programação por causa do teclado.

## offline

fonte: CLAUDE.md, "Obrigatória a CONTA, não a rede"
perguntas:
- Funciona sem internet?
- Precisa estar conectado?
- Dá pra usar offline?
- Preciso de conta?

resposta:
Precisa de conta, e de internet só na primeira entrada. Depois disso o app abre e funciona offline, e o progresso sincroniza sozinho quando a conexão volta.

## progresso

fonte: CLAUDE.md, "Sincronização com o Firestore"
perguntas:
- Meu progresso fica salvo?
- Se eu trocar de celular perco tudo?
- Dá pra jogar em dois aparelhos?
- Onde fica guardado o que eu fiz?

resposta:
Fica salvo a cada questão respondida, no aparelho e na sua conta. Trocando de celular, é só entrar com a mesma conta que o progresso volta. Dá para jogar em dois aparelhos sem conflito.

## estatisticas

fonte: CLAUDE.md, "Estatísticas do jogador"
perguntas:
- Tem estatística do meu desempenho?
- Consigo ver como estou indo?
- O app mostra meus acertos?
- Tem ranking?

resposta:
Tem uma tela de estatísticas: quantas você acertou de primeira, onde precisou de ajuda e quais tópicos vale revisar. Não tem ranking nem comparação com outras pessoas, e o tempo nunca vira competição.

## plataforma

fonte: README.md
perguntas:
- Tem para iPhone?
- Roda no meu celular?
- Em que sistema funciona?
- Tem versão web?

resposta:
Por enquanto, só Android.

## baixar

fonte: README.md, "releases/latest"
perguntas:
- Como eu baixo o app?
- Onde instalo o DevLingo?
- Tá na Play Store?
- Tem link pra download?

resposta:
O APK assinado está nas Releases do GitHub: github.com/gustavoanderson/DevLingo/releases. Ele ainda não está na Play Store, então o Android vai pedir autorização para instalar de fonte externa.

## preco

fonte: README.md
perguntas:
- Quanto custa?
- O app é pago?
- É de graça?
- Tem assinatura?
- Cobra alguma coisa?
- Tem que pagar pra jogar?
- Tem versão free?
- Preciso pagar pra usar?

resposta:
Hoje o DevLingo é gratuito, sem anúncio e sem assinatura.

## licenca

fonte: LICENCAS.md -- reescrita em 15/09: a versão anterior juntava as duas licenças, e modelo e juiz leram a restrição do conteúdo como se fosse do código
perguntas:
- O código é aberto?
- Posso usar o código do DevLingo?
- Qual a licença?
- Posso copiar as questões?

resposta:
São duas licenças diferentes. O código do app é MIT: você pode usar, modificar e até vender, desde que mantenha o aviso de copyright. O conteúdo das questões é outra coisa, CC BY-NC-ND: dá para compartilhar, mas sem modificar e sem uso comercial. O Tr∅nikAt, a arte e o nome DevLingo são reservados.

## tronikat

fonte: CLAUDE.md, "O que é o DevLingo"
perguntas:
- Quem é você?
- Quem é o Tr∅nikAt?
- Você é um gato?
- Qual é o seu nome?

resposta:
Sou o Tr∅nikAt, o mascote do DevLingo: um gato branco bípede, ciberneticamente modificado, com visor verde. Metade pelo, metade metal. Aqui eu tiro dúvidas sobre o app.

## linguagens

fonte: Gustavo, 15/09/2026
perguntas:
- Você sabe programar?
- Você conhece Rust?
- Vai ter curso de C#?
- Quais linguagens ainda vão entrar?
- Você manja de todas as linguagens?
- Você entende de Ruby?
- Vão adicionar PHP no app?
- Você programa em Elixir?

resposta:
Conheço todas as linguagens de programação, e elas vão entrar no DevLingo aos poucos, como trilhas novas. Aqui no chat eu falo do app; escrever e treinar código é dentro das lições.

## voce-e-ia

fonte: estudio/avaliar_modelos.py
perguntas:
- Você é uma inteligência artificial?
- Tô falando com um robô?
- Você pode errar?
- Como você funciona?

resposta:
Sou uma IA, sim, e posso errar. Por isso eu só respondo a partir de fichas escritas e conferidas pelo Gustavo. Se a pergunta fugir delas, eu aviso em vez de inventar.

## como-o-tronikat-roda

fonte: estudio/avaliar_modelos.py; hospedagem/cloudflare -- reescrita em 15/09: dizia que nenhuma pergunta sai da maquina, falso no site publico
perguntas:
- Você usa o ChatGPT?
- Qual modelo de IA você usa?
- Isso gasta API paga?
- Você roda na nuvem?

resposta:
Depende de onde você me encontra. No computador do Gustavo, eu rodo num modelo aberto, o Qwen3 de 4 bilhões de parâmetros, numa placa de vídeo e sem API paga. Aqui no site, a sua pergunta vai para um servidor da Cloudflare, que só escolhe qual resposta revisada pelo Gustavo eu vou falar.

## testes

fonte: testes e cobertura remedidos em 16/09/2026 (2.390 de 2.501 linhas, 28 de 33 arquivos). tools/conferir_numeros.py reprova se o 389 divergir da suite
perguntas:
- O app tem testes?
- Como vocês testam o DevLingo?
- Qual a cobertura de testes?
- O código é bem testado?

resposta:
São 389 testes automatizados no app, rodando no GitHub Actions a cada envio. A cobertura publicada é de 95,6%, medida em setembro de 2026, e ela vem junto com o denominador: 28 dos 33 arquivos, e não "95,6% do app inteiro".

## validador

fonte: CLAUDE.md, "Validador"
perguntas:
- Como vocês garantem que as questões estão certas?
- Quem revisa o conteúdo?
- As questões podem ter erro?
- Como é o controle de qualidade?

resposta:
Um validador em Python confere cada questão antes de ela entrar no app. Toda regra dele nasceu de um defeito real, como a mesma resposta cobrada duas vezes, e toda regra é provada reprovando de propósito: portão que só sabe aprovar não é portão.

## mcp

fonte: mcp/README.md
perguntas:
- O que é o servidor MCP do projeto?
- O DevLingo tem MCP?
- Um agente de IA consegue usar o DevLingo?
- Para que serve o MCP aqui?

resposta:
O projeto tem um servidor MCP com seis ferramentas só de leitura, como validar uma lição e conferir se uma resposta já é cobrada em outra questão. Ele deixa um agente de IA consultar os portões de qualidade antes de escrever conteúdo.

## stack

fonte: CLAUDE.md, "Decisões de stack"
perguntas:
- Com que tecnologia foi feito?
- Qual linguagem o app usa?
- É Flutter?
- Qual o banco de dados?

resposta:
O app é Flutter, em Dart. O progresso fica em SQLite no aparelho e sincroniza com o Firestore; o login é Firebase Auth. O validador de conteúdo e o servidor MCP são em Python.

## quem-construiu

fonte: site/index.html, "Quem construiu"
revisar: Gustavo
perguntas:
- Quem fez o DevLingo?
- Quem é o criador?
- Quem é o Gustavo?
- Quem desenvolveu esse app?

resposta:
O Gustavo Anderson: QA e desenvolvedor, especializado em levar IA para o dia a dia de quem programa, com LLMs aplicados a agentes e servidores MCP para automação. O DevLingo é onde as duas coisas se encontram.

## defeitos

fonte: CLAUDE.md, "O que o dia 7 de setembro de 2026 ensinou sobre método"
revisar: Gustavo
perguntas:
- O Gustavo testou o app?
- Ele achou bugs?
- Como foi o processo de teste?
- O app já teve defeito?

resposta:
Teve, e o Gustavo encontrou vários jogando o próprio app, como a posição da lição que se perdia ao abrir a aula. Cada defeito foi documentado com a causa e virou teste automático.

## feito-com-ia

fonte: CLAUDE.md, "Como trabalhar com o Gustavo"
revisar: Gustavo
perguntas:
- O app foi feito com IA?
- Usaram inteligência artificial para programar?
- Foi o ChatGPT que fez o código?
- Qual o papel da IA no projeto?

resposta:
Foi construído com IA como par de programação. As decisões de produto e de técnica são do Gustavo, e o que a IA produz passa pela mesma suíte de testes e pelo mesmo validador que qualquer código.

## contato

fonte: README.md
revisar: Gustavo
perguntas:
- Como falo com o Gustavo?
- Tem o contato dele?
- Onde acho o autor?
- Ele tem GitHub?
- Qual o e-mail do criador?
- Tem LinkedIn do autor?

resposta:
O caminho público é o GitHub: github.com/gustavoanderson.

## contribuir

fonte: LICENCAS.md
perguntas:
- Posso contribuir?
- Achei um erro numa questão, onde aviso?
- Aceitam pull request?
- Como ajudo o projeto?

resposta:
Erro de conteúdo é muito bem-vindo por issue no GitHub. Pull request de código também é aceito; o de conteúdo não, porque a coerência entre as trilhas depende de uma cabeça só.

## proximos-passos

fonte: docs/IDEIAS.md; CLAUDE.md, "Os níveis seguintes, planejados e não escritos" -- reescrita em 15/09: sem citar o avançado, o modelo afirmou que ele não estava planejado
perguntas:
- O que vem por aí?
- Vai ter nível intermediário?
- Quais as próximas novidades?
- Tem planos para o app?

resposta:
Hoje todas as trilhas estão no nível iniciante, e os níveis intermediário e avançado estão planejados. Novas linguagens também vão entrar, como trilhas. Também estão na fila de ideias a tradução para outros idiomas e a leitura das questões em voz alta. Não há data prometida para nenhum deles.

## idioma

fonte: docs/IDEIAS.md
perguntas:
- Tem em inglês?
- O app é só em português?
- Vai ter tradução?
- Is it available in English?

resposta:
Por enquanto, só em português. A tradução para outros idiomas está na fila de ideias. O código das questões já é universal, então o que precisa ser traduzido é a explicação em volta dele.

## privacidade

fonte: firestore.rules; dependências do app conferidas em 14/09/2026 (sem SDK de anúncio ou analytics)
revisar: Gustavo
perguntas:
- Vocês vendem meus dados?
- Quem vê o meu progresso?
- Meus dados ficam seguros?
- O que vocês guardam de mim?

resposta:
O app guarda seu e-mail de login e o histórico das suas respostas. As regras do banco permitem que só a sua conta leia e escreva o seu progresso, e nenhum dado é vendido.

## som

fonte: CLAUDE.md, "Som de acerto"
perguntas:
- Dá pra tirar o som?
- O app tem música?
- Como eu desligo o barulho?
- Tem som quando acerto?
- Tem como silenciar?
- Consigo jogar sem áudio?

resposta:
Só o acerto tem som; errar é silencioso, de propósito. Dá para desligar pelo ícone de som, tanto na trilha quanto dentro da lição.

## programacao

fonte: placa de desvio -- ver o aviso no topo deste arquivo
perguntas:
- Como faço um Hello World em JavaScript?
- como imprime na tela em python
- O que é uma variável em programação?
- Para que serve o console.log?
- Qual a diferença entre Python e JavaScript?
- Como se escreve um laço for?
- O que significa esse erro no meu código?
- Como declaro uma função?
- O que é um array?
- me explica o que é um if
- Qual a diferença entre let e var?
- o que muda entre == e ===
- Para que serve o return?
- o que e um metodo?
- Escreve um codigo em Python que ordena uma lista
- me faz uma funcao que soma dois numeros
- escreve um exemplo de while em javascript
- o que sao dependencias
- o que e heranca entre classes
- o que sao aninhamentos
- o que e um objeto em programacao
- o que e recursao
- o que e escopo de uma variavel
- para que serve um parametro numa funcao
- o que e tratamento de erro
- o que significa importar uma biblioteca
- qual a diferenca entre classe e objeto
- o que e LangChain
- o que e o Docker
- me explica o que e Git
- para que serve o Redis
- o que e TypeScript
- o que e Kubernetes

resposta:
Programação é comigo mesmo, mas deu um engasgo aqui no estúdio agora. Pergunta de novo que eu explico. E para treinar de verdade, é dentro das trilhas: cada lição tem uma aula curta antes das questões.

## fora-de-escopo

fonte: placa de desvio -- o Worker trata esta ficha como "barrada"
perguntas:
- Qual a cotação do dólar hoje?
- qual a cotacao do dolar hoje
- Quanto está o bitcoin?
- Como está o tempo hoje?
- Quem ganhou o Brasileirao ontem?
- Me dá uma receita de bolo
- Quem ganhou a eleição?
- Qual o melhor investimento agora?
- Me ajuda com meu currículo
- Qual o preço do dólar?

resposta:
Essa eu não sei. Eu falo do DevLingo e de programação, e o resto não é comigo.
