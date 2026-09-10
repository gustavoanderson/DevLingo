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
   * Insere a ficha.
   *
   * Nao ha o que esperar aparecer nesta tela, entao a confirmacao de que o
   * toque funcionou fica com quem chama: a tela seguinte e que tem elemento
   * para esperar. Um `esperar()` aqui teria que ser tempo fixo, e tempo fixo e
   * a origem numero um de teste instavel.
   */
  async inserirFicha() {
    const { width, height } = await driver.getWindowSize();

    // `pointerType: 'touch'` NAO e detalhe: sem ele, o padrao do WebdriverIO
    // e 'mouse'.
    //
    // Medido: a versao sem esta linha executava sem erro nenhum, e a tela nao
    // saia do lugar -- enquanto `adb shell input tap` nas mesmas coordenadas
    // avancava. O Android entrega evento de mouse por outro caminho, e o
    // `GestureDetector` do Flutter esperava toque.
    //
    // E o pior tipo de falha: o comando "funciona", nao levanta excecao, e o
    // teste so quebra la na frente, no `waitForDisplayed` da tela seguinte --
    // apontando para o lugar errado.
    await driver
      .action('pointer', { parameters: { pointerType: 'touch' } })
      .move({ x: Math.round(width / 2), y: Math.round(height / 2) })
      .down()
      .pause(80)
      .up()
      .perform();
  }
}

export default new TelaTitulo();
