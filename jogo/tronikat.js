/* A JANELA DO Tr∅nikAt DENTRO DO JOGO.
 *
 * Ele fala do DevLingo e de programacao, exatamente como no site do portfolio
 * -- decisao do Gustavo em 22/09/2026, entre esta e um tutor que veria a
 * questao em que a pessoa travou. A segunda nao foi recusada, foi adiada: o
 * enunciado indo ao modelo cria um risco que este arquivo nao teria como
 * conter, o de ENTREGAR A RESPOSTA, e isso esvaziaria a eliminacao e a
 * revelacao que a mecanica inteira sustenta.
 *
 * ELE NAO SABE EM QUE QUESTAO VOCE ESTA, e isso aqui e uma garantia, nao uma
 * limitacao: nada nesta janela le a tela do exercicio.
 *
 * FICA FORA DO MURO. O botao aparece tambem na tela de entrada, antes do
 * login, porque foi assim que o Gustavo decidiu: quem abre o link sem conta
 * ainda consegue perguntar o que e isto.
 *
 * NENHUMA REGRA DE JOGO MORA AQUI, e nenhuma regra de porteiro tambem. Quem
 * decide qual ficha responde, se a pergunta passa do piso e o que o modelo
 * pode dizer e o Worker -- o mesmo que atende o site. Este arquivo pergunta,
 * mostra e toca.
 *
 * O ROSTO E O MESMO DO SITE, e nao uma copia dele: `site/codec.js` desenha o
 * retrato em estilo Metal Gear, e as duas paginas carregam aquele arquivo.
 */
'use strict';

(function () {
  const WORKER = 'https://tronikat.tronikat-busca.workers.dev';

  // As falas gravadas vivem em `site/falas/`, e o jogo em `jogo/`. O servidor
  // sobe da RAIZ do repositorio -- e a mesma razao pela qual o banco de
  // questoes e lido em `../app/assets/content/` e o mascote em
  // `../assets/mascot/`. Nada e copiado.
  const FALAS = '../site/falas/';

  // Enquanto o Worker pensa, ele ENROLA. Ideia do Gustavo, ja provada no site.
  const ENROLAR = ['_pensar-01', '_pensar-02', '_pensar-03', '_pensar-04', '_pensar-05'];

  const $ = (id) => document.getElementById(id);
  let indice = null;      // o indice das falas, buscado uma vez so
  let tocando = null;     // o <audio> em curso, para o proximo poder calar
  let ocupado = false;
  let semRede = false;    // o que a ULTIMA tentativa descobriu, nao um palpite
  let jaAbriu = false;    // a chamada so anuncia quem ainda nao foi descoberto

  /* --------------------------------------------------------- o standby
   *
   * Ideia do Gustavo: sem conexao ele nao vira mensagem de erro, vira
   * PERSONAGEM ESPERANDO -- cinza, chuviscando, com "connection lost".
   *
   * A distincao que faz isso valer a pena: o DevLingo funciona offline por
   * desenho, e o Tr∅nikAt e a unica peca que nao. Um "erro" aqui deixaria a
   * pessoa achando que o jogo caiu junto; por isso o standby diz, em voz alta,
   * que o resto continua de pe.
   *
   * DUAS FONTES, e nenhuma sozinha basta. `navigator.onLine` responde rapido e
   * MENTE do lado otimista: ele diz `true` para quem esta num wi-fi sem saida
   * para a internet -- ve-se a rede, nao se ve o mundo. Entao ele liga o
   * standby na hora quando diz `false`, e uma falha de `fetch` liga tambem,
   * mesmo com ele jurando que ha rede. */
  function pintarEstado() {
    const fora = semRede || navigator.onLine === false;
    $('tronikat-standby').hidden = !fora;
    $('tronikat-vivo').hidden = fora;
    $('tronikat-campo').disabled = fora;
    $('tronikat-enviar').disabled = fora;
    $('tronikat-campo').placeholder = fora
      ? 'Sem conexão no momento…' : 'Pergunte alguma coisa…';
    $('btn-tronikat').classList.toggle('offline', fora);
    pintarChamada();
  }

  /* A CHAMADA: o balao de tres pontinhos que anuncia a IA.
   *
   * Pedido do Gustavo, e ela resolve descoberta: o botao e um gato de 62px num
   * canto, e nada nele diz "converse comigo".
   *
   * Duas condicoes para ela sumir, e as duas sao sobre nao mentir:
   *
   *   - DEPOIS DO PRIMEIRO TOQUE. Quem ja sabe que ele existe nao precisa de um
   *     balao pulsando para sempre; aviso que nao para de avisar vira ruido.
   *     Ela volta na proxima visita, porque o estado nao e guardado -- quem
   *     chega de novo e, para efeito de descoberta, alguem chegando
   *   - OFFLINE. Tres pontinhos saltitando sobre um mascote cinza em
   *     "connection lost" seria a tela se contradizendo */
  function pintarChamada() {
    const fora = semRede || navigator.onLine === false;
    const mostrar = !jaAbriu && fora === false && $('tronikat-janela').hidden;
    $('tronikat-chamada').hidden = !mostrar;
    $('btn-tronikat').classList.toggle('chamando', mostrar);
  }

  /* ------------------------------------------------------------ a conversa */

  function linha(quem, texto) {
    const d = document.createElement('div');
    d.className = 'fala fala-' + quem;
    d.textContent = texto;
    $('tronikat-conversa').appendChild(d);
    // A conversa cresce para baixo, e quem esta lendo quer ver o fim.
    $('tronikat-conversa').scrollTop = $('tronikat-conversa').scrollHeight;
    return d;
  }

  async function indiceDasFalas() {
    if (!indice) indice = await fetch(FALAS + 'indice.json').then((r) => r.json());
    return indice;
  }

  /* --------------------------------------------------------------- a voz */

  /* Toca uma fala e MOVE A BOCA junto, lendo `audio.currentTime` a cada quadro.
   *
   * O relogio e o do AUDIO, e nao um cronometro proprio: se o som engasgar, a
   * boca espera junto em vez de seguir falando sozinha. E a mesma escolha do
   * site, e o motivo esta escrito la.
   *
   * `bocas` vem como [inicio, fim, abertura, arredondamento], no mesmo formato
   * para fala gravada e para texto sintetizado na hora -- por isso existe um
   * tocador so, e nao dois caminhos para divergir.
   *
   * Resolve no fim do audio OU no erro: som bloqueado pelo navegador nao pode
   * deixar a conversa pendurada. */
  function tocar(r) {
    return new Promise((resolve) => {
      let url = r.arquivo, temporaria = false;
      if (!url) {
        if (!r.audio) { resolve(); return; }
        const bin = atob(r.audio);
        const bytes = new Uint8Array(bin.length);
        for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
        url = URL.createObjectURL(new Blob([bytes], { type: 'audio/wav' }));
        temporaria = true;
      }
      const audio = new Audio(url);
      if (tocando) { try { tocando.pause(); } catch (e) {} }
      tocando = audio;
      const bocas = r.bocas || [];
      let i = 0, fim = false;
      const boca = (v, a) => { if (window.Fala) Fala.abrir(v, a, true); };
      function quadro() {
        if (fim) return;
        const t = audio.currentTime;
        while (i < bocas.length && bocas[i][1] <= t) i++;
        const b = bocas[i];
        if (b && b[0] <= t) boca(b[2], b[3]); else boca(0, 0);
        requestAnimationFrame(quadro);
      }
      function acabar() {
        if (fim) return;
        fim = true;
        boca(0, 0);
        if (temporaria) URL.revokeObjectURL(url);
        if (tocando === audio) tocando = null;
        resolve();
      }
      audio.onended = audio.onerror = acabar;
      audio.onplay = () => requestAnimationFrame(quadro);
      audio.play().catch(acabar);
    });
  }

  async function perguntar(pergunta) {
    // O DOSSIE DE PROGRESSO viaja junto, quando ha quem o monte. Sem ele a
    // faixa do tutor no Worker nunca liga -- e o Worker nao tem como buscar o
    // progresso sozinho: ele nao fala com o Firestore em nome de ninguem.
    //
    // Quem preenche `window.ProgressoDoAluno` e `jogo.js`, apos o login. Na
    // tela de entrada ele continua nulo de proposito: o botao fica FORA do
    // muro, e quem ainda nao entrou nao tem progresso a analisar.
    //
    // E QUEM LE E ESTE LADO, e nao o contrario: `jogo.js` carrega ANTES deste
    // arquivo, entao ele escrever aqui dependeria da ordem das tags `<script>`
    // e derrubaria a abertura do jogo no dia em que alguem as reordenasse.
    let progresso = null;
    try {
      if (window.ProgressoDoAluno) progresso = window.ProgressoDoAluno();
    } catch (e) {
      // Pior que um conselho sem progresso e nenhuma resposta.
    }
    const r = await fetch(WORKER + '/perguntar', {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(progresso ? { pergunta, progresso } : { pergunta }),
    });
    if (!r.ok) throw new Error('o servidor respondeu ' + r.status);
    const corpo = await r.json();
    const falas = await indiceDasFalas();

    // Dois caminhos, e o Worker diz qual foi. Ficha conhecida ja tem texto, voz
    // e boca gravados; resposta GERADA na borda precisa passar pelo servico de
    // voz, que devolve `bocas` no mesmo formato -- por isso o tocador e um so.
    if (corpo.texto) {
      let voz = {};
      try {
        const v = await fetch(WORKER + '/falar', {
          method: 'POST', headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ texto: corpo.texto }),
        });
        if (v.ok) voz = await v.json();
      } catch (e) {
        // Sem voz a resposta ainda vale: o texto e o conteudo, a fala e o tom.
      }
      return { texto: corpo.texto, audio: voz.audio, bocas: voz.bocas };
    }
    const f = falas[corpo.ficha || '_recusa'];
    if (!f) throw new Error('fala desconhecida: ' + corpo.ficha);
    return { texto: f.texto, arquivo: FALAS + f.audio, bocas: f.bocas };
  }

  async function enviar(ev) {
    ev.preventDefault();
    const campo = $('tronikat-campo');
    const pergunta = campo.value.trim();
    if (!pergunta || ocupado) return;

    ocupado = true;
    campo.value = '';
    linha('minha', pergunta);

    /* ENQUANTO ELE PENSA, ELE ENROLA -- e o texto NAO sai antes da fala.
     *
     * A primeira versao mostrava a resposta escrita assim que o Worker
     * respondia, e a voz chegava segundos depois. O Gustavo: "o texto da
     * janela sai antes da fala, lembra que no site tinha uma demora ate a
     * resposta sair? tem que implementar ali tambem".
     *
     * Ele esta certo, e o motivo e que sao a MESMA fala. Ler antes de ouvir
     * transforma a voz em repeticao do que a pessoa ja leu -- e o personagem
     * vira legenda de si mesmo. No site as duas saem juntas, e e isso que faz
     * parecer alguem falando.
     *
     * A enrolacao e o que paga por essa espera. Ela toca em ZERO segundo,
     * porque ja esta gravada, entao o silencio de 1 a 5 segundos do Worker
     * deixa de ser silencio. */
    const pensando = linha('dele', '…');
    pensando.classList.add('pensando');
    const falas = await indiceDasFalas().catch(() => null);
    // O sorteio escolhe UMA fala, e o arquivo tem de ser o dela. A primeira
    // versao sorteava e depois montava o caminho com `ENROLAR[0]`: tocava
    // sempre "Hmmm, quase la", com a boca de outra frase por cima.
    const qual = ENROLAR[Math.floor(Math.random() * ENROLAR.length)];
    const enrolacao = (falas && falas[qual])
      ? tocar({ ...falas[qual], arquivo: FALAS + falas[qual].audio })
      : Promise.resolve();

    try {
      const r = await perguntar(pergunta);
      semRede = false;
      // A enrolacao termina de falar antes: duas vozes por cima uma da outra
      // seriam duas pessoas, e ele e um so.
      await enrolacao;
      pensando.classList.remove('pensando');
      pensando.textContent = r.texto;
      $('tronikat-conversa').scrollTop = $('tronikat-conversa').scrollHeight;
      tocar(r);
    } catch (e) {
      await enrolacao.catch(() => {});
      pensando.classList.remove('pensando');
      // DOIS TIPOS DE FALHA, e confundi-los daria o recado errado.
      //
      // `fetch` rejeita quando a requisicao nao chega -- sem rede, DNS morto,
      // CORS. Ai o standby e a resposta certa: e o estado do mundo, nao um
      // tropeco desta pergunta. Ja um 500 do servidor CHEGOU: ha conexao, e
      // pintar tudo de cinza mentiria sobre a causa.
      if (e instanceof TypeError) {
        semRede = true;
        // A bolha sai de cena: quem manda agora e o standby, e deixar as duas
        // seria dizer a mesma coisa de dois jeitos.
        pensando.remove();
        pintarEstado();
      } else {
        // A mensagem diz O QUE FAZER. "Erro" sozinho nao ajuda ninguem.
        pensando.textContent = 'O Tr∅nikAt não conseguiu responder agora. '
          + 'Tente de novo em instantes — o jogo continua funcionando sem ele.';
        pensando.classList.add('falhou');
      }
    } finally {
      ocupado = false;
      if (!$('tronikat-campo').disabled) campo.focus();
    }
  }

  function alternar() {
    const j = $('tronikat-janela');
    const abrindo = j.hidden;
    j.hidden = !abrindo;
    $('btn-tronikat').setAttribute('aria-expanded', String(abrindo));
    if (abrindo) {
      jaAbriu = true;
      pintarEstado();
      if (!$('tronikat-campo').disabled) $('tronikat-campo').focus();
      if (!$('tronikat-conversa').childElementCount) {
        linha('dele', 'Oi! Pergunte o que quiser sobre o DevLingo ou sobre programação.');
      }
    } else if (tocando) {
      // Fechar cala. Voz seguindo de uma janela fechada e defeito de produto.
      tocando.pause();
      tocando = null;
      if (window.Fala) Fala.abrir(0, 0, true);
    }
  }

  window.addEventListener('DOMContentLoaded', () => {
    $('btn-tronikat').addEventListener('click', alternar);
    $('tronikat-fechar').addEventListener('click', alternar);
    $('tronikat-form').addEventListener('submit', enviar);
    // Esc fecha, porque a janela cobre parte da tela e o teclado tem que dar
    // conta dela sozinho.
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape' && !$('tronikat-janela').hidden) alternar();
    });

    // A REDE VOLTANDO TIRA ELE DO STANDBY SOZINHO, e isso importa: sem escutar
    // o evento, quem perdeu o sinal no elevador ficaria olhando um gato cinza
    // depois de a conexao voltar, e concluiria que o recurso quebrou.
    window.addEventListener('online', () => { semRede = false; pintarEstado(); });
    window.addEventListener('offline', () => { pintarEstado(); });
    pintarEstado();
  });
})();
