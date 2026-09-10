// Page Object da tela de escolha de trilha.

/**
 * O cartao de uma trilha, pela chave dela ("python", "frameworks", "qa"...).
 *
 * Usa `resource-id`, e a razao esta registrada em `tela_linguagens.dart`: o
 * `content-desc` NAO serve aqui. Medido no aparelho, a descricao do cartao de
 * Frameworks e
 *
 *   "0, Frameworks\nReact, Vue, Svelte, Next, Nuxt e Astro
 *    — melhor depois do JavaScript\niniciante · 5 licoes · 0 de 50 questoes"
 *
 * Um filtro por "contem JavaScript" casaria com o cartao de JavaScript E com
 * este. Dois elementos para o mesmo seletor e o pior tipo de falha: as vezes
 * pega o certo, as vezes o errado, e o relatorio nao explica nada.
 *
 * Repare tambem que a descricao COMECA com o progresso ("0, ") e TERMINA com
 * a contagem de questoes. As duas pontas mudam sozinhas conforme se joga.
 */
const cartao = (chave) =>
  $(`android=new UiSelector().resourceId("trilha-${chave}-beg")`);

class TelaEscolha {
  cartaoDaTrilha(chave) {
    return cartao(chave);
  }

  async abrirTrilha(chave) {
    const alvo = cartao(chave);
    await alvo.waitForExist({
      timeoutMsg: `o cartao da trilha "${chave}" nao apareceu na tela de escolha`,
    });
    await alvo.click();
  }

  async esperar() {
    // Python e a primeira da ordem sugerida, e a trilha que sempre existe.
    // `waitForExist`, e nao `waitForDisplayed`.
    //
    // Sao perguntas diferentes: "existe na arvore" e "esta visivel". Num app
    // Flutter os nos de acessibilidade sao sinteticos, e o calculo de
    // visibilidade do UiAutomator nem sempre concorda com o que se ve.
    // Medido -- a sonda achava o no pelo `getPageSource`, e o
    // `waitForDisplayed` no mesmo seletor estourava o tempo.
    await cartao('python').waitForExist({
      timeoutMsg: 'a tela de escolha de trilha nao apareceu',
    });
  }
}

export default new TelaEscolha();
