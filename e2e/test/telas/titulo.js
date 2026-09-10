// Page Object da tela de titulo -- a abertura em formato de fliperama.

/**
 * Esta tela e um caso especial, e vale entender por que.
 *
 * ## Ela nao tem botao
 *
 * O contrato dela e literalmente "toque em qualquer lugar para inserir a
 * ficha". Nao existe alvo a apontar, entao o toque por COORDENADA nao e
 * preguica aqui -- e a traducao fiel do que a tela oferece. Em qualquer outra
 * tela isso seria o seletor errado.
 *
 * ## Ela quebra a espera por ociosidade
 *
 * O mascote respira num laco de 3,6s e o START pisca a cada 900ms, os dois
 * infinitos. O `uiautomator dump` nesta tela devolve:
 *
 *   ERROR: could not get idle state.
 *
 * E a mesma causa raiz do `pumpAndSettle` do lado Flutter. Quem resolve e a
 * capacidade `settings[waitForIdleTimeout]: 0` no `wdio.conf.js` -- sem ela,
 * NENHUM comando funciona aqui.
 */
class TelaTitulo {
  /**
   * O convite piscante -- e a prova de que a tela ja desenhou.
   *
   * Eu tinha escrito aqui que "nao ha o que esperar nesta tela". Estava
   * errado, e o erro custou tres tentativas de correcao no lugar errado: o
   * teste tocava logo depois do `activateApp`, quando o app ainda nao tinha
   * desenhado nada, e o toque caia no vazio. Como o comando nao falha, a
   * quebra aparecia so tres passos adiante, na tela seguinte.
   *
   * A tela TEM elemento: o `content-desc` traz "Aperte START para iniciar".
   */
  get convite() {
    return $(
      'android=new UiSelector().descriptionContains("Aperte START")',
    );
  }

  /** Espera a tela de titulo estar desenhada e pronta para o toque. */
  async esperar() {
    await this.convite.waitForExist({
      timeout: 30000,
      timeoutMsg:
        'a tela de titulo nao apareceu. Numa instalacao limpa o Flutter leva '
        + 'dezenas de segundos para aquecer -- ver o CLAUDE.md.',
    });
  }

  /** Verdadeiro enquanto a tela de titulo ainda estiver na frente. */
  async aindaNoTitulo() {
    const fonte = await driver.getPageSource();
    return fonte.includes('APRENDA A PROGRAMAR');
  }

  /**
   * Insere a ficha, e CONFIRMA que a tela mudou.
   *
   * ## Por que ha repeticao aqui, se a suite nao usa espera fixa
   *
   * Porque a prontidao desta tela **nao e observavel**. Medido: com uma pausa
   * de 6s antes do toque, a tela avanca; tocando assim que o convite aparece
   * na arvore, o mesmo comando executa, nao levanta erro, e nada acontece. Nao
   * existe elemento que diga "agora ja da para tocar" -- o convite piscante
   * aparece antes disso.
   *
   * Quando a prontidao nao e observavel, aumentar a pausa e chutar: curta
   * demais falha em maquina lenta, longa demais desperdica em toda execucao. A
   * saida honesta e **agir e verificar o efeito**, repetindo enquanto o efeito
   * nao vier.
   *
   * Repare que continua nao havendo espera fixa: cada volta espera uma
   * CONDICAO (a tela de titulo ter saido), e o teto existe para falhar com
   * mensagem util em vez de pendurar.
   */
  async inserirFicha() {
    await this.esperar();
    const { width, height } = await driver.getWindowSize();

    // `mobile: clickGesture`, e nao a acao W3C de ponteiro.
    //
    // Medido, nesta ordem:
    //
    //   driver.action('pointer')                      -> nao avanca a tela
    //   driver.action('pointer', {pointerType:touch}) -> nao avanca a tela
    //   adb shell input tap <x> <y>                   -> AVANCA
    //
    // As duas primeiras executam sem erro nenhum e nao fazem nada, que e o
    // pior tipo de falha: o teste so quebra tres passos adiante, no
    // `waitForDisplayed` da tela seguinte, apontando para o lugar errado.
    //
    // `mobile: clickGesture` e o gesto nativo do driver UiAutomator2 -- o
    // mesmo caminho que o `adb shell input tap` usa. Quando a acao padrao do
    // protocolo nao chega no app, e nele que se recorre.
    const alvo = {
      x: Math.round(width / 2),
      y: Math.round(height / 2),
    };

    for (let tentativa = 1; tentativa <= 6; tentativa += 1) {
      await driver.execute('mobile: clickGesture', alvo);
      try {
        await browser.waitUntil(async () => !(await this.aindaNoTitulo()), {
          timeout: 5000,
          interval: 500,
        });
        return;
      } catch {
        // A ficha nao entrou. Tenta de novo -- o app ainda estava aquecendo.
      }
    }

    throw new Error(
      'a ficha nao entrou depois de 6 tentativas: a tela de titulo continua '
      + 'na frente. Confira se o app abriu de verdade no aparelho.',
    );
  }
}

export default new TelaTitulo();
