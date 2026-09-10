# Testes de ponta a ponta do DevLingo

Suíte Appium + WebdriverIO que dirige o **APK de release** do DevLingo, o mesmo
que está publicado.

```bash
cd e2e
npm install
npx appium driver install uiautomator2
npm test
```

## Antes de rodar

**Um emulador Android de pé**, com o app instalado:

```bash
emulator -avd Pixel_8
adb -s emulator-5554 install -r ../app/build/app/outputs/flutter-apk/app-x86_64-release.apk
```

**E o arquivo `e2e/.env`**, que não vai para o repositório:

```
DEVLINGO_E2E_EMAIL=sua.conta.de.teste@example.com
DEVLINGO_E2E_SENHA=uma-senha-qualquer
```

Crie a conta pelo próprio app, na tela "Criar conta". Ela precisa ser
**dedicada aos testes**: o app sincroniza progresso com o Firestore por
usuário, então usar a sua conta pessoal faria cada execução mexer no seu
progresso de verdade.

## Por que emulador, e não celular

A suíte roda em **emulador**; o celular real fica para verificação visual.

Não é preferência: é onde cada um encontra coisa. O aparelho de verdade
revelou o vão de mil pixels no estado vazio, a barra de desfechos que não
desenhava e os quatro botões sem rótulo — defeitos que só existem em pixel. A
suíte automatizada precisa de outra coisa: rodar igual em qualquer máquina, e
em CI.

E há um impedimento concreto no aparelho do Gustavo: **a MIUI recusa instalar
pacote novo por USB**. Medido — atualizar pacote existente passa, instalar
novo devolve `INSTALL_FAILED_USER_RESTRICTED`. O Appium precisa instalar o
auxiliar `io.appium.settings`, e não consegue.

## O que a suíte já ensinou sobre o app

Ela nasceu de um **defeito real**: os quatro controles do topo da trilha eram
`View` clicáveis e anônimos. Quem usa leitor de tela ouvia "botão" nos quatro,
sem saber se ia sair da trilha ou desligar o som — e nenhum dos 345 testes de
widget pegava, porque as `Key` do Flutter param na fronteira do Dart.

Hoje eles têm `label` (o que a pessoa ouve) e `identifier` (o que o teste
aponta), separados de propósito: trocar o texto não pode quebrar a automação.

## Armadilhas que custaram tempo, e estão comentadas no código

| Onde | O quê |
|---|---|
| `wdio.conf.js` | Sem `waitForIdleTimeout: 0` a tela de título é inalcançável — as animações em laço nunca deixam a interface ficar ociosa. Mesma causa raiz do `pumpAndSettle` |
| `telas/titulo.js` | O `pointerType` padrão do WebdriverIO é `mouse`, e o Flutter esperava toque. O comando executa, não falha, e não faz nada |
| `telas/titulo.js` | A prontidão da tela de título **não é observável**. Por isso ali há toque-e-verifica com repetição, e não espera fixa |
| `telas/escolha.js` | O `content-desc` do cartão de Frameworks contém "JavaScript". Filtro por texto casaria dois cartões |
| `telas/login.js` | Campo de texto guarda o rótulo em `hint`, não em `content-desc`. `content-desc` vazio **não** quer dizer sem rótulo |

## Estrutura

```
wdio.conf.js          capacidades e serviços
test/telas/           Page Objects: ONDE as coisas estão
test/specs/           os testes: O QUE se verifica
```

A separação existe porque a trilha é o caminho para tudo no app. Com o seletor
escrito dentro de cada spec, mudar o app quebraria dez arquivos; num Page
Object, muda um.

## O que ainda não é verdade

- **Os testes não são independentes entre si.** `noReset: true` mantém os dados
  entre execuções, e um teste que responde uma questão muda o estado que o
  próximo encontra. É escolha consciente enquanto a suíte é pequena; crescendo,
  o caminho é `fullReset` num aparelho dedicado
- **A suíte não roda em CI.** Falta um emulador no fluxo do GitHub Actions
- **Só o cabeçalho da trilha tem cobertura.** Responder uma questão, a tela de
  estatísticas e o fluxo de login ainda não são testados
