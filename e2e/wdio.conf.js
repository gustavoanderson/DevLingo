import { readFileSync } from 'node:fs';

// Le o `e2e/.env` sem dependencia nova.
//
// Ele guarda as credenciais da conta de teste e e ignorado pelo git -- mesma
// regra da keystore e do `google-services.json`. Ausente, a suite nao explode
// aqui: ela falha no login com uma mensagem que diz o que criar, que e mais
// util que um erro de arquivo nao encontrado no arranque.
try {
  const bruto = readFileSync(new URL('.env', import.meta.url), 'utf8');
  for (const linha of bruto.split(/\r?\n/)) {
    const corte = linha.indexOf('=');
    if (linha.startsWith('#') || corte < 1) continue;
    process.env[linha.slice(0, corte).trim()] ??= linha.slice(corte + 1).trim();
  }
} catch {
  // Sem .env. Ver a mensagem de `entrarComContaDeTeste`.
}

// Configuracao da suite de ponta a ponta do DevLingo.
//
// Cada bloco abaixo tem um comentario dizendo POR QUE ele esta assim, e nao
// so o que ele faz. Config de automacao e onde moram as decisoes que ninguem
// lembra de ter tomado -- e sao elas que explicam por que a suite passa aqui e
// falha na maquina do colega.

export const config = {
  runner: 'local',

  // O Appium 3 escuta em 4723 por padrao. Deixado explicito de proposito:
  // "usa o padrao" e a informacao que some quando o padrao muda de versao.
  port: 4723,

  specs: ['./test/specs/**/*.spec.js'],

  // Um aparelho so, um teste por vez.
  //
  // Paralelismo em teste de celular exige um aparelho por instancia -- dois
  // testes disputando a mesma tela produzem falha que nao se reproduz. Com um
  // aparelho fisico, o numero e 1.
  maxInstances: 1,

  capabilities: [
    {
      platformName: 'Android',

      // QUAL aparelho, dito em voz alta.
      //
      // Sem isto, com mais de um conectado, o driver escolhe o primeiro que o
      // `adb` listar -- e essa ordem nao e estavel. A suite passaria a rodar
      // "em algum aparelho", que e como se descobre tarde demais que o teste
      // nunca tocou o alvo pretendido.
      //
      // O padrao e o emulador, e a razao e de projeto: a SUITE roda em
      // emulador, que e reproduzivel e roda em CI; o celular real fica para
      // verificacao visual e exploratoria, que e onde ele ja provou valor
      // (o vao de mil pixels, a barra invisivel, os quatro botoes mudos).
      //
      // O celular do Gustavo, alias, NAO serve para esta suite: a MIUI recusa
      // instalar pacote NOVO por USB, e o Appium precisa instalar o auxiliar
      // `io.appium.settings`. Medido -- atualizar pacote existente passa,
      // instalar novo devolve INSTALL_FAILED_USER_RESTRICTED.
      'appium:udid': process.env.DEVLINGO_UDID || 'emulator-5554',

      // UiAutomator2, e nao o appium-flutter-driver.
      //
      // O flutter-driver enxerga os widgets por dentro e parece a escolha
      // obvia, mas exige o app compilado com uma extensao ligada -- ou seja,
      // ele testa um binario que NINGUEM instala. Este caminho le a arvore de
      // acessibilidade do Android, que e exatamente o que existe no APK de
      // release publicado.
      //
      // O efeito colateral e puro ganho: o que o Appium nao acha, um leitor de
      // tela tambem nao. A automacao vira auditoria de acessibilidade.
      'appium:automationName': 'UiAutomator2',

      'appium:appPackage': 'com.devlingo.app',
      'appium:appActivity': '.MainActivity',

      // NAO apaga os dados do app entre execucoes.
      //
      // Esta e a decisao mais discutivel do arquivo, e o motivo importa: o
      // progresso do jogador E o objeto de teste em metade dos casos, e
      // limpar apagaria o progresso real do Gustavo neste aparelho.
      //
      // O preco e real e fica registrado: os testes NAO sao independentes
      // entre si. Um teste que responde uma questao muda o estado que o
      // proximo encontra. Enquanto a suite for pequena, da para conviver
      // escrevendo cada teste para nao depender de contagem exata; quando
      // crescer, o caminho e um aparelho dedicado com `fullReset`.
      'appium:noReset': true,

      // Quanto o servidor espera por um comando novo antes de encerrar a
      // sessao sozinho. O padrao (60s) derruba a sessao quando alguem para num
      // ponto de interrupcao para investigar.
      'appium:newCommandTimeout': 240,

      // SEM ESTA LINHA, A TELA DE TITULO E INALCANCAVEL.
      //
      // O UiAutomator espera a interface ficar OCIOSA antes de ler a arvore. A
      // tela de titulo do DevLingo tem duas animacoes em laco infinito -- o
      // mascote respirando a cada 3,6s e o START piscando a cada 900ms --,
      // entao ela nunca fica ociosa. Medido, com `uiautomator dump`:
      //
      //   trilha (sem animacao):  arvore capturada
      //   titulo (com animacao):  ERROR: could not get idle state.
      //
      // E exatamente a mesma causa raiz que o `pumpAndSettle` do lado Flutter,
      // registrada no CLAUDE.md: espera por "parou de mexer" nunca termina
      // quando algo mexe para sempre. Duas ferramentas, dois anos de
      // distancia, o mesmo engano.
      //
      // Zerar desliga essa espera. O preco e que a leitura pode pegar a tela
      // no meio de uma transicao -- o mesmo risco ja registrado para o print
      // tirado logo apos um toque. Por isso os testes esperam ELEMENTO, e
      // nunca tempo.
      'appium:settings[waitForIdleTimeout]': 0,
    },
  ],

  logLevel: 'warn',
  bail: 0,

  // Teto da espera IMPLICITA do WebdriverIO -- o quanto um `waitForDisplayed`
  // sem argumento espera antes de desistir.
  //
  // Dez segundos e generoso de proposito para app Flutter: a primeira tela
  // depois de instalar carrega banco de questoes e progresso. Espera curta
  // demais produz "teste instavel" que na verdade e teste apressado.
  waitforTimeout: 10000,
  connectionRetryTimeout: 120000,
  connectionRetryCount: 2,

  // Sobe o servidor Appium junto com a suite, e derruba no fim.
  //
  // A alternativa e o servidor num terminal a parte. Funciona, e falha do
  // jeito pior: alguem esquece de subir, o erro e "connection refused", e alem
  // disso a suite deixa de rodar sozinha em qualquer maquina.
  services: ['appium'],
  appium: {
    args: {
      // Sem isto o Appium 3 recusa capacidades que ele nao conhece.
      relaxedSecurity: true,
    },
  },

  /**
   * Reforca a configuracao de ociosidade DEPOIS que a sessao abre.
   *
   * A capacidade `settings[waitForIdleTimeout]` acima deveria bastar, mas
   * capacidade com nome errado e ignorada em SILENCIO -- nao ha erro, e o
   * sintoma e um comando que executa e nao faz nada. Aqui a chamada e
   * explicita, e o `console.log` mostra o que o driver realmente aceitou.
   *
   * Cinto e suspensorio, e neste caso justificado: sem esta configuracao a
   * tela de titulo do DevLingo e inalcancavel, porque as animacoes em laco
   * nunca deixam a interface ficar ociosa.
   */
  before: async function () {
    await driver.updateSettings({ waitForIdleTimeout: 0 });
    const atual = await driver.getSettings();
    console.log('waitForIdleTimeout =', atual.waitForIdleTimeout);
  },

  framework: 'mocha',
  reporters: ['spec'],

  mochaOpts: {
    ui: 'bdd',
    // Noventa segundos por teste. Instalar, abrir e navegar num aparelho real
    // e ordens de grandeza mais lento que um teste de widget -- os 343 do
    // Flutter inteiros levam 22 segundos.
    timeout: 90000,
  },
};
