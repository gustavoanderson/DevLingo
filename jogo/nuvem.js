/* A NUVEM: o UNICO arquivo do navegador que fala com o Firebase.
 *
 * E o espelho de dois arquivos do app, `autenticacao_firebase.dart` e
 * `nuvem_firestore.dart`, e pelo mesmo motivo que eles existem separados: quem
 * desenha a tela nao precisa saber que existe Firebase, e o teste troca este
 * arquivo inteiro por uma versao em memoria.
 *
 * ELE NAO DECIDE REGRA NENHUMA. O formato da partida vem do cerebro
 * (`partida.dart`), as mensagens de erro tambem (`autenticacao.dart`). Aqui so
 * se leva e se traz.
 *
 * A CONFIGURACAO ABAIXO NAO E SEGREDO. E o identificador do projeto, e ela ja
 * esta visivel dentro do APK do app. O que protege os dados sao as regras do
 * Firestore (`firestore.rules`: cada um so le e escreve a propria pasta) e o
 * login -- nao o sigilo destes campos.
 *
 * O `measurementId` que o console mandou junto FICOU DE FORA, de proposito: ele
 * liga o Google Analytics, que pesa, rastreia quem visita e ninguem pediu.
 *
 * FIRESTORE LITE, e nao o completo, por causa de uma decisao do Gustavo: o
 * navegador NAO funciona offline. O Lite fala com o servidor por requisicao
 * simples, sem cache local nem escuta em tempo real -- exatamente o que sobra
 * quando nao ha offline --, e pesa bem menos.
 *
 * A versao 12.18.0 e a mesma que o plugin do Flutter usa
 * (`firebase_core_web`, `supportedFirebaseJsSdkVersion`): sabidamente existe e
 * funciona com este projeto, em vez de um numero escolhido de cabeca.
 */
'use strict';

(function () {
  // Um teste pode ter posto uma nuvem falsa antes de esta pagina carregar.
  // Quem chegou primeiro fica: e assim que o teste de ponta a ponta joga sem
  // precisar de conta de verdade.
  if (window.Nuvem) return;

  const SDK = 'https://www.gstatic.com/firebasejs/12.18.0/';
  const CONFIG = {
    apiKey: 'AIzaSyAjAghJZKhpupJTWJbk-C9StPGVLSEKF5A',
    authDomain: 'devlingo-cc399.firebaseapp.com',
    projectId: 'devlingo-cc399',
    storageBucket: 'devlingo-cc399.firebasestorage.app',
    messagingSenderId: '348920744401',
    appId: '1:348920744401:web:2e58614a622203ea2bb8f0',
  };

  let fb = null;   // os modulos, carregados uma vez

  async function iniciar() {
    if (fb) return fb;
    const [app, auth, fs] = await Promise.all([
      import(SDK + 'firebase-app.js'),
      import(SDK + 'firebase-auth.js'),
      import(SDK + 'firebase-firestore-lite.js'),
    ]);
    const aplicativo = app.initializeApp(CONFIG);
    const autenticacao = auth.getAuth(aplicativo);
    // O e-mail de nova senha chega em portugues.
    autenticacao.languageCode = 'pt';
    fb = { auth, fs, autenticacao, banco: fs.getFirestore(aplicativo) };
    return fb;
  }

  window.Nuvem = {
    /* Avisa quando alguem entra ou sai. A sessao fica guardada no navegador,
       entao quem ja entrou volta direto -- como no app. */
    async aoMudarUsuario(retorno) {
      const f = await iniciar();
      f.auth.onAuthStateChanged(f.autenticacao,
        (u) => retorno(u ? { uid: u.uid, email: u.email } : null));
    },

    async entrar(email, senha) {
      const f = await iniciar();
      await f.auth.signInWithEmailAndPassword(f.autenticacao, email, senha);
    },

    async cadastrar(email, senha) {
      const f = await iniciar();
      await f.auth.createUserWithEmailAndPassword(f.autenticacao, email, senha);
    },

    async recuperarSenha(email) {
      const f = await iniciar();
      await f.auth.sendPasswordResetEmail(f.autenticacao, email);
    },

    async sair() {
      const f = await iniciar();
      await f.auth.signOut(f.autenticacao);
    },

    /* Grava UMA partida, no mesmo caminho e no mesmo formato do app:
       `usuarios/{uid}/eventos/{evento_id}`.

       O `sincronizado_em` NAO e opcional. O celular baixa com
       `where('sincronizado_em', isGreaterThan: ...)`: sem este campo, a partida
       do navegador fica fora da consulta e NUNCA chega ao aparelho -- sem erro
       nenhum, em lugar nenhum. E ele vem do RELOGIO DO SERVIDOR, como no app:
       relogio de navegador erra, basta alguem mexer na data. */
    async gravarPartida(evento) {
      const f = await iniciar();
      await f.fs.setDoc(
        f.fs.doc(f.banco, 'usuarios', evento.uid, 'eventos', evento.evento_id),
        { ...evento, sincronizado_em: f.fs.serverTimestamp() });
    },

    /* Todas as partidas da pessoa. O carimbo do servidor sai, como no app:
       ele e metadado de sincronizacao, nao progresso. */
    async baixarPartidas(uid) {
      const f = await iniciar();
      const lote = await f.fs.getDocs(f.fs.collection(f.banco, 'usuarios', uid, 'eventos'));
      return lote.docs.map((d) => {
        const dados = { ...d.data() };
        delete dados.sincronizado_em;
        return dados;
      });
    },
  };
})();
