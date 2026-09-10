// Page Object da tela de trilha.
//
// ## Por que esta camada existe
//
// A pergunta que decide se vale a pena nao e "e boa pratica?", e sim: **em
// quantos testes este seletor vai aparecer?**
//
// A trilha e o caminho para tudo no DevLingo -- toda licao, toda questao e a
// tela de estatisticas passam por aqui. Se o seletor do botao de som estiver
// escrito dentro de cada spec, mudar o app quebra dez arquivos. Aqui, muda um.
//
// O custo e honesto: numa suite de tres testes, esta camada parece burocracia.
// Ela se paga a partir do momento em que a mesma tela e tocada por varios.

/**
 * Como apontamos para um elemento, e por que assim.
 *
 * O DevLingo e Flutter, e isso muda tudo em relacao ao que os cursos de Appium
 * ensinam. Medido no aparelho, com `uiautomator dump`:
 *
 * - **Nao existe classe util.** Todo elemento do app e `android.view.View`.
 *   Filtrar por `android.widget.Button` nao acha nada
 * - **`resource-id` so existe onde alguem colocou** um `Semantics(identifier:)`
 *   no codigo Dart. Nao vem de graca como num app Android nativo
 *
 * Entao a ordem de preferencia e:
 *
 * 1. **`resource-id`** -- e contrato: existe para ser apontado, e o texto da
 *    tela pode mudar sem quebrar o teste
 * 2. **`content-desc`** -- e o que a pessoa OUVE. Funciona, mas o dia em que o
 *    texto mudar, o teste cai junto
 * 3. **XPath** -- ultimo recurso, e neste app quase sempre errado. Ver o
 *    comentario de `cartaoDaLicao`
 */
const porId = (id) => $(`android=new UiSelector().resourceId("${id}")`);

class TelaTrilha {
  // Os quatro controles do topo. Estes ids nascem de
  // `TelaTrilha.idVoltar` e companhia, em `app/lib/ui/tela_trilha.dart` -- a
  // MESMA string que a `Key` do teste de widget usa.
  get voltar() {
    return porId('trilha-voltar');
  }

  get estatisticas() {
    return porId('trilha-estatisticas');
  }

  get cenario() {
    return porId('trilha-cenario');
  }

  get som() {
    return porId('trilha-som');
  }

  /**
   * O cartao de uma licao, pelo `lessonId` ("frameworks-beg-01").
   *
   * Este identificador tem uma propriedade rara: **ele e imutavel por regra do
   * banco de questoes**, porque o progresso do usuario aponta para ele. O
   * seletor herda de graca uma garantia que ja existia no projeto.
   *
   * A alternativa seria o `content-desc`, que o Flutter monta juntando o texto
   * dos filhos:
   *
   *   "01\nPor que framework existe, e o mapa dos seis\n0 de 10"
   *
   * Ele TERMINA com o progresso, que muda assim que alguem joga a licao. Um
   * teste presa a essa string passaria hoje e falharia amanha, relatando
   * "elemento nao encontrado" -- escondendo que a causa foi o teste anterior.
   *
   * O XPath equivalente seria:
   *
   *   //*[@resource-id="licao-frameworks-beg-01"]
   *
   * e ele funciona. Nao usamos porque XPath percorre a arvore inteira a cada
   * busca, e porque num app onde tudo e `android.view.View` ele degenera em
   * caminho por posicao -- `//View[3]/View[1]` --, que quebra quando alguem
   * acrescenta um espacador.
   */
  cartaoDaLicao(lessonId) {
    return porId(`licao-${lessonId}`);
  }

  /**
   * Espera a tela estar de fato pronta.
   *
   * Nao existe `sleep` nesta suite, de proposito. Espera fixa e a origem
   * numero um de teste instavel: curta demais falha em aparelho lento, longa
   * demais transforma dez testes em dez minutos. Aqui esperamos um ELEMENTO,
   * que e a condicao que realmente importa.
   */
  async esperar() {
    await this.som.waitForDisplayed({
      timeoutMsg:
        'a tela de trilha nao apareceu: o botao de som nunca ficou visivel',
    });
  }
}

export default new TelaTrilha();
