// Page Object da tela de entrada.
//
// O app exige conta -- "ninguem joga sem entrar" e decisao registrada no
// CLAUDE.md. Entao TODO teste que va alem da tela de titulo passa por aqui.

/**
 * Aqui usamos XPath, depois de tres telas evitando XPath. Vale explicar, porque
 * a regra nao e "XPath e ruim".
 *
 * ## O que estes campos expoem
 *
 * Medido no emulador:
 *
 *   EditText  hint='E-mail'
 *   EditText  hint='Senha'  password='true'
 *
 * Eles NAO tem `content-desc`, e por um bom motivo: em Android, campo de texto
 * guarda o rotulo em `hint`, nao em `content-desc`. E o padrao correto, e o
 * Flutter mapeou o `labelText` para la sozinho. (Eu quase "corrigi" isso como
 * se fosse defeito de acessibilidade -- nao e.)
 *
 * ## Por que XPath aqui, e nao antes
 *
 * O `UiSelector` do UiAutomator sabe casar por `text`, `description`,
 * `className`, `resourceId` e `index`. **Ele nao sabe casar por `hint`.**
 * XPath sabe.
 *
 * E a distincao que importa:
 *
 *   //android.widget.EditText[@hint="E-mail"]     <- casa por ATRIBUTO. ok
 *   //View[3]/View[1]/View[2]                     <- casa por POSICAO. nunca
 *
 * O problema do XPath nunca foi a sintaxe: e ele degenerar em caminho, que
 * quebra quando alguem acrescenta um espacador. Casar atributo e legitimo.
 *
 * ## O que ainda e melhor
 *
 * `hint` e texto de interface: o dia em que "Senha" virar "Sua senha", este
 * seletor cai. Um `Semantics(identifier:)` nos dois campos resolveria de vez,
 * como fizemos no cabecalho da trilha. Fica anotado como o proximo passo --
 * este arquivo e a versao que funciona sem mexer no app de novo.
 */
const campoEmail = () => $('//android.widget.EditText[@hint="E-mail"]');
const campoSenha = () => $('//android.widget.EditText[@password="true"]');

class TelaLogin {
  get email() {
    return campoEmail();
  }

  get senha() {
    return campoSenha();
  }

  get entrar() {
    return $('android=new UiSelector().description("Entrar").clickable(true)');
  }

  async esperar() {
    await campoEmail().waitForDisplayed({
      timeoutMsg: 'a tela de entrada nao apareceu',
    });
  }

  /**
   * Entra com a conta de teste.
   *
   * As credenciais vem do ambiente, e nunca do codigo. O `e2e/.env` que as
   * guarda e ignorado pelo git, pela mesma regra da keystore e do
   * `google-services.json`.
   *
   * A conta e DEDICADA, e nao a do Gustavo: o app sincroniza progresso com o
   * Firestore por uid, entao usar a conta pessoal faria cada rodada de teste
   * mexer no progresso real dele.
   */
  async entrarComContaDeTeste() {
    const email = process.env.DEVLINGO_E2E_EMAIL;
    const senha = process.env.DEVLINGO_E2E_SENHA;

    if (!email || !senha) {
      throw new Error(
        'faltam DEVLINGO_E2E_EMAIL e DEVLINGO_E2E_SENHA. ' +
          'Crie o arquivo e2e/.env -- ver e2e/README.md.',
      );
    }

    await this.esperar();
    await campoEmail().setValue(email);
    await campoSenha().setValue(senha);

    // O teclado cobre o botao. `hideKeyboard` e a API propria do Appium para
    // isso -- melhor que mandar BACK, que fecha o teclado quando ele esta
    // aberto e SAI DO APP quando nao esta. Medido do jeito ruim.
    if (await driver.isKeyboardShown()) {
      await driver.hideKeyboard();
    }

    await this.entrar.click();
  }
}

export default new TelaLogin();
