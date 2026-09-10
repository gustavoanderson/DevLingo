import titulo from '../telas/titulo.js';
import escolha from '../telas/escolha.js';
import trilha from '../telas/trilha.js';

/**
 * O contrato de acessibilidade do cabecalho da trilha.
 *
 * ## Por que este e o primeiro teste da suite
 *
 * Ele nasceu de um defeito REAL, encontrado com Appium em 10 de setembro de
 * 2026. O `uiautomator dump` da tela de trilha mostrava os quatro controles do
 * topo como `android.view.View` clicaveis e ANONIMOS:
 *
 *   x=  52- 124  (SEM DESCRICAO)   <- voltar
 *   x= 890- 968  (SEM DESCRICAO)   <- estatisticas
 *   x=1020-1098  (SEM DESCRICAO)   <- cenario
 *   x=1150-1228  (SEM DESCRICAO)   <- som
 *
 * Quem usa leitor de tela ouvia "botao" nos quatro, sem saber se ia sair da
 * trilha ou desligar o som. **Nenhum dos 343 testes de widget pegava**, porque
 * as `Key` do Flutter existiam e funcionavam -- e param na fronteira do Dart.
 *
 * Entao este teste guarda duas coisas ao mesmo tempo:
 *
 * - que o app continua **acessivel** (o `label`, que a pessoa ouve)
 * - que a suite continua **automatizavel** (o `identifier`, que o teste usa)
 *
 * Ele reprova se alguem remover o `Semantics` -- e a correcao volta a sumir do
 * jeito que ela sumiu por meses: em silencio, com tudo verde.
 */
describe('Acessibilidade do cabecalho da trilha', () => {
  before(async () => {
    // Estado conhecido. Com `noReset: true` o app resume onde estava, e um
    // teste que comeca "em algum lugar" e um teste que falha de formas
    // diferentes a cada execucao.
    await driver.terminateApp('com.devlingo.app');
    await driver.activateApp('com.devlingo.app');

    await titulo.inserirFicha();
    await escolha.esperar();
    await escolha.abrirTrilha('frameworks');
    await trilha.esperar();
  });

  it('os quatro controles do topo tem rotulo para leitor de tela', async () => {
    // O rotulo e o que a PESSOA ouve. Ele pode mudar -- e por isso ele nao e o
    // seletor; e o valor verificado.
    const esperado = {
      voltar: 'Voltar',
      estatisticas: 'Estatísticas',
      cenario: 'Cenário animado',
      som: 'Som',
    };

    for (const [nome, rotulo] of Object.entries(esperado)) {
      const elemento = trilha[nome];
      await expect(elemento).toBeDisplayed();
      await expect(elemento).toHaveAttribute('content-desc', rotulo);
    }
  });

  it('a chave de som anuncia o estado, e nao so o nome', async () => {
    // O estado vai em `checkable`/`checked`, e nao dentro do rotulo.
    //
    // A alternativa seria escrever "Desativar som" quando ligado, e ela e pior
    // por dois motivos: obriga o leitor de tela a anunciar a ACAO no lugar do
    // NOME, e faz o rotulo mudar -- uma coisa a mais para o teste perseguir.
    //
    // O ganho pratico aqui e direto: da para saber se o som esta ligado sem
    // olhar pixel nenhum, e sem depender de qual icone foi desenhado.
    await expect(trilha.som).toHaveAttribute('checkable', 'true');

    const antes = await trilha.som.getAttribute('checked');
    await trilha.som.click();
    await browser.waitUntil(
      async () => (await trilha.som.getAttribute('checked')) !== antes,
      {
        timeoutMsg:
          'a chave de som nao mudou de estado na arvore de acessibilidade',
      },
    );

    // Devolve como estava. Com `noReset: true` os testes compartilham estado,
    // e deixar o som trocado seria mudar o mundo para quem vier depois -- e
    // para o Gustavo, que usa este aparelho de verdade.
    await trilha.som.click();
    await browser.waitUntil(
      async () => (await trilha.som.getAttribute('checked')) === antes,
      { timeoutMsg: 'nao consegui devolver a chave de som ao estado original' },
    );
  });

  it('os cartoes de licao sao alcancaveis pelo id imutavel', async () => {
    // O `lessonId` e imutavel por REGRA DO BANCO de questoes -- o progresso do
    // usuario aponta para ele. O seletor herda essa garantia de graca.
    const primeira = trilha.cartaoDaLicao('frameworks-beg-01');
    await expect(primeira).toBeDisplayed();
  });
});
