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
 * ainda consegue perguntar o que e isto. O valor de portfolio nao depende de
 * cadastro.
 *
 * NENHUMA REGRA DE JOGO MORA AQUI, e nenhuma regra de porteiro tambem. Quem
 * decide qual ficha responde, se a pergunta passa do piso e o que o modelo
 * pode dizer e o Worker -- o mesmo que atende o site. Este arquivo pergunta e
 * mostra.
 */
'use strict';

(function () {
  const WORKER = 'https://tronikat.tronikat-busca.workers.dev';

  // As falas gravadas vivem em `site/falas/`, e o jogo em `jogo/`. O servidor
  // sobe da RAIZ do repositorio -- e a mesma razao pela qual o banco de
  // questoes e lido em `../app/assets/content/` e o mascote em
  // `../assets/mascot/`. Nada e copiado.
  const FALAS = '../site/falas/';

  const $ = (id) => document.getElementById(id);
  let indice = null;      // o indice das falas, buscado uma vez so
  let tocando = null;     // o <audio> em curso, para o proximo poder calar
  let ocupado = false;
  let semRede = false;    // o que a ULTIMA tentativa descobriu, nao um palpite

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
    $('tronikat-conversa').hidden = fora;
    $('tronikat-campo').disabled = fora;
    $('tronikat-enviar').disabled = fora;
    $('tronikat-campo').placeholder = fora
      ? 'Sem conexão no momento…' : 'Pergunte alguma coisa…';
    $('btn-tronikat').classList.toggle('offline', fora);
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

  /* Toca a voz, e FALHAR AQUI NAO E ERRO.
   *
   * O texto ja esta na tela quando isto roda. Navegador que bloqueia som sem
   * gesto, rede que cai, Oracle fora do ar -- em todos, a resposta continua
   * legivel. Som e conveniencia, a mesma regra que o app tem para a fanfarra. */
  async function falar(r) {
    try {
      if (tocando) { tocando.pause(); tocando = null; }
      let url;
      if (r.arquivo) {
        url = r.arquivo;
      } else {
        // Texto gerado na hora nao tem WAV gravado: a voz vem do servico.
        const v = await fetch(WORKER + '/falar', {
          method: 'POST', headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ texto: r.texto }),
        });
        if (!v.ok) return;
        const j = await v.json();
        if (!j.audio) return;
        const bin = atob(j.audio);
        const bytes = new Uint8Array(bin.length);
        for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
        url = URL.createObjectURL(new Blob([bytes], { type: 'audio/wav' }));
      }
      const a = new Audio(url);
      tocando = a;
      a.play().catch(() => {});
    } catch (e) {
      // De proposito: a resposta ja foi entregue em texto.
    }
  }

  async function perguntar(pergunta) {
    const r = await fetch(WORKER + '/perguntar', {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ pergunta }),
    });
    if (!r.ok) throw new Error('o servidor respondeu ' + r.status);
    const corpo = await r.json();

    // Dois caminhos, e o Worker diz qual foi. Resposta GERADA na borda nao tem
    // audio gravado; ficha conhecida tem texto e voz prontos no indice.
    if (corpo.texto) return { texto: corpo.texto };
    const falas = await indiceDasFalas();
    const f = falas[corpo.ficha || '_recusa'];
    if (!f) throw new Error('fala desconhecida: ' + corpo.ficha);
    return { texto: f.texto, arquivo: FALAS + f.audio };
  }

  async function enviar(ev) {
    ev.preventDefault();
    const campo = $('tronikat-campo');
    const pergunta = campo.value.trim();
    if (!pergunta || ocupado) return;

    ocupado = true;
    campo.value = '';
    linha('minha', pergunta);
    // O RETORNO E IMEDIATO, e isso nao e enfeite: a busca mais a geracao levam
    // uns 4 segundos, e botao que nao responde e lido como travado -- a mesma
    // razao pela qual a tela de titulo do app passa a dizer "CARREGANDO..." em
    // vez de ignorar o toque.
    const espera = linha('dele', 'pensando…');
    espera.classList.add('pensando');

    try {
      const r = await perguntar(pergunta);
      semRede = false;
      espera.classList.remove('pensando');
      espera.textContent = r.texto;
      falar(r);
    } catch (e) {
      espera.classList.remove('pensando');
      // DOIS TIPOS DE FALHA, e confundi-los daria o recado errado.
      //
      // `fetch` rejeita quando a requisicao nao chega -- sem rede, DNS morto,
      // CORS. Ai o standby e a resposta certa: e o estado do mundo, nao um
      // tropeco desta pergunta. Ja um 500 do servidor CHEGOU: ha conexao, e
      // pintar tudo de cinza mentiria sobre a causa.
      const naoChegou = e instanceof TypeError;
      if (naoChegou) {
        semRede = true;
        // A bolha sai de cena: quem manda agora e o standby, e deixar as duas
        // seria dizer a mesma coisa de dois jeitos.
        espera.remove();
        pintarEstado();
      } else {
        // A mensagem diz O QUE FAZER. "Erro" sozinho nao ajuda ninguem.
        espera.textContent = 'O Tr∅nikAt não conseguiu responder agora. '
          + 'Tente de novo em instantes — o jogo continua funcionando sem ele.';
        espera.classList.add('falhou');
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
      pintarEstado();
      if (!$('tronikat-campo').disabled) $('tronikat-campo').focus();
      if (!$('tronikat-conversa').childElementCount) {
        linha('dele', 'Oi! Pergunte o que quiser sobre o DevLingo ou sobre programação.');
      }
    } else if (tocando) {
      // Fechar cala. Voz seguindo de uma janela fechada e defeito de produto.
      tocando.pause();
      tocando = null;
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
