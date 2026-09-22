/* TESTE DE PONTA A PONTA DO DEVLINGO NO NAVEGADOR.
 *
 *     python tools/construir_jogo.py     # antes, uma vez
 *     node jogo/testar_jogo.js
 *
 * Faz o que uma pessoa faria: tenta entrar sem conta, erra a senha, entra,
 * ve o progresso que ja tinha, joga uma licao INTEIRA -- errando a primeira de
 * proposito --, volta para a trilha, e sai da conta.
 *
 * A NUVEM E FALSA, e isso e deliberado. `nuvem.js` e o unico arquivo que fala
 * com o Firebase, e o teste poe uma versao em memoria no lugar dele ANTES de a
 * pagina carregar -- o mesmo padrao da `AutenticacaoFalsa` do app. Duas razoes:
 *
 *   - teste automatico nao cria conta nem grava partida no projeto de verdade
 *   - a nuvem falsa GUARDA cada partida que a pagina tentou gravar, e isso
 *     deixa conferir o formato de cada uma -- que e o que decide o cross-play
 *
 * O cross-play de verdade, com a conta real e o celular, e verificado a mao:
 * nenhuma nuvem falsa prova que o Firebase aceitou.
 *
 * COMO O TESTE SABE A RESPOSTA CERTA: lendo o JSON do banco, e NAO perguntando
 * a pagina. Se perguntasse, um defeito que invertesse o gabarito passaria,
 * porque teste e pagina errariam juntos. Pelo mesmo motivo, as colunas
 * esperadas da partida estao escritas AQUI, e nao pedidas ao cerebro: sao as
 * de `evento_resposta`, e o teste Dart "o contrato da partida com o navegador"
 * prova que elas batem com o esquema real do app.
 *
 * Sai com 0 se tudo passar e 1 se qualquer coisa falhar, dizendo o que.
 */
'use strict';
const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');

const RAIZ = path.resolve(__dirname, '..');
const CHROME = process.env.CHROME || 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const PORTA_WEB = 8124;
const PORTA_CDP = 9413;
const BASE = `http://127.0.0.1:${PORTA_WEB}/jogo/index.html`;
const dormir = (ms) => new Promise((r) => setTimeout(r, ms));

// As colunas de `evento_resposta` no app. Uma a mais ou a menos derruba a
// sincronizacao NO CELULAR, que enfia o documento da nuvem direto no SQLite.
const COLUNAS_DA_PARTIDA = [
  'desfecho', 'duracao_ms', 'evento_id', 'language', 'lesson_id', 'level',
  'question_id', 'respondida_em', 'sincronizado', 'tentativas', 'topic', 'uid',
  'usou_dica',
];

const CONTA = { email: 'aluna@exemplo.com', senha: 'segredo123', uid: 'uid-de-teste' };

// Tres questoes da licao 01 ja respondidas numa sessao anterior -- uma delas
// DUAS vezes. Sao quatro partidas e tres questoes: a trilha tem de dizer 3.
const HISTORICO = [
  ['python-beg-0101', 1], ['python-beg-0101', 2], ['python-beg-0102', 3], ['python-beg-0103', 4],
].map(([q, t]) => ({
  evento_id: `${CONTA.uid}|${q}|${t}`, uid: CONTA.uid, question_id: q,
  lesson_id: 'python-beg-01', language: 'python', level: 'beginner', topic: 'x',
  tentativas: 1, desfecho: 'acertou', usou_dica: 0, duracao_ms: 1000,
  respondida_em: t, sincronizado: 0,
}));

// A nuvem falsa. Roda DENTRO da pagina, antes de qualquer script dela.
const NUVEM_FALSA = `
  window.__gravadas = [];
  window.__recuperacoes = [];
  (function () {
    const CONTA = ${JSON.stringify(CONTA)};
    const HISTORICO = ${JSON.stringify(HISTORICO)};
    let avisar = null;
    const erro = (codigo) => Object.assign(new Error(codigo), { code: codigo });
    window.Nuvem = {
      async aoMudarUsuario(cb) { avisar = cb; cb(null); },
      async entrar(email, senha) {
        if (email !== CONTA.email || senha !== CONTA.senha) throw erro('auth/invalid-credential');
        avisar({ uid: CONTA.uid, email });
      },
      async cadastrar() { throw erro('auth/email-already-in-use'); },
      async recuperarSenha(email) {
        window.__recuperacoes.push(email);
        if (email !== CONTA.email) throw erro('auth/user-not-found');
      },
      async sair() { avisar(null); },
      async gravarPartida(ev) { window.__gravadas.push(ev); },
      async baixarPartidas(uid) { return uid === CONTA.uid ? HISTORICO.slice() : []; },
    };
  })();
`;

const falhas = [];
function conferir(ok, nome, detalhe = '') {
  console.log(`  ${ok ? 'ok   ' : 'FALHA'} ${nome}${detalhe ? '  (' + detalhe + ')' : ''}`);
  if (!ok) falhas.push(nome);
}

let seq = 1;
function conversa(ws) {
  const pend = new Map();
  const eventos = [];
  ws.addEventListener('message', (e) => {
    const m = JSON.parse(e.data);
    if (m.id && pend.has(m.id)) { pend.get(m.id)(m); pend.delete(m.id); } else if (m.method) eventos.push(m);
  });
  const cdp = (method, params = {}, sessionId) => new Promise((res) => {
    const i = seq++; pend.set(i, res);
    ws.send(JSON.stringify(sessionId ? { id: i, method, params, sessionId } : { id: i, method, params }));
  });
  return [cdp, eventos];
}

(async () => {
  if (!fs.existsSync(path.join(RAIZ, 'jogo', 'cerebro.js'))) {
    console.log('falta jogo/cerebro.js -- rode antes: python tools/construir_jogo.py');
    process.exit(1);
  }

  const servidor = spawn('python', ['-m', 'http.server', String(PORTA_WEB), '--bind', '127.0.0.1'],
    { cwd: RAIZ, stdio: 'ignore' });
  const perfil = path.join(process.env.TEMP || RAIZ, 'chrome-testar-jogo-' + Date.now());
  fs.mkdirSync(perfil, { recursive: true });
  const chrome = spawn(CHROME, [
    `--remote-debugging-port=${PORTA_CDP}`, `--user-data-dir=${perfil}`,
    '--no-first-run', '--no-default-browser-check', '--headless=new',
    '--use-gl=angle', '--use-angle=d3d11', '--window-size=900,900', 'about:blank',
  ], { stdio: 'ignore' });

  const encerrar = async (codigo) => {
    chrome.kill(); servidor.kill(); await dormir(400);
    try { fs.rmSync(perfil, { recursive: true, force: true }); } catch { /* ignora */ }
    process.exit(codigo);
  };

  try {
    let v = null;
    for (let i = 0; i < 60 && !v; i++) {
      try { v = await (await fetch(`http://127.0.0.1:${PORTA_CDP}/json/version`)).json(); } catch { await dormir(250); }
    }
    const ws = new WebSocket(v.webSocketDebuggerUrl);
    await new Promise((r) => ws.addEventListener('open', r));
    const [cdp, eventos] = conversa(ws);
    const { targetId } = await cdp('Target.createTarget', { url: 'about:blank' }).then((r) => r.result);
    const { sessionId } = await cdp('Target.attachToTarget', { targetId, flatten: true }).then((r) => r.result);
    for (const d of ['Page', 'Runtime', 'Log']) await cdp(d + '.enable', {}, sessionId);
    await cdp('Emulation.setCPUThrottlingRate', { rate: 4 }, sessionId);
    // A nuvem falsa entra ANTES de qualquer script da pagina.
    await cdp('Page.addScriptToEvaluateOnNewDocument', { source: NUVEM_FALSA }, sessionId);

    const js = async (expr) => {
      const r = await cdp('Runtime.evaluate', { expression: expr, returnByValue: true, awaitPromise: true }, sessionId);
      return r.result.result.value;
    };
    const esperar = async (expr, ms = 8000) => {
      const fim = Date.now() + ms;
      while (Date.now() < fim) { if (await js(expr)) return true; await dormir(100); }
      return false;
    };
    const visivel = (id) => `!document.getElementById('${id}').hidden`;
    const texto = (id) => js(`document.getElementById('${id}').textContent`);
    const tentarEntrar = async (email, senha) => {
      await js(`document.getElementById('email').value = ${JSON.stringify(email)};
                document.getElementById('senha').value = ${JSON.stringify(senha)};
                document.getElementById('btn-entrar').click()`);
      await dormir(250);
    };

    for (let i = 0; i < 40; i++) {
      try { if ((await fetch(BASE)).ok) break; } catch { /* ainda subindo */ }
      await dormir(150);
    }

    // ------------------------------------------------------------ 1. o muro
    console.log('\n=== sem conta, nada abre ===');
    await cdp('Page.navigate', { url: BASE + '#/python' }, sessionId);
    conferir(await esperar(visivel('vista-entrada')), 'o endereco da trilha cai na entrada');
    conferir(await js(`document.getElementById('vista-trilha').hidden`), 'a trilha NAO aparece sem conta');
    const EXPR_FCP = `(performance.getEntriesByType('paint')
      .find(p => p.name === 'first-contentful-paint') || {}).startTime`;
    await esperar(EXPR_FCP);
    const fcp = await js(EXPR_FCP);
    conferir(fcp > 0 && fcp < 4000, 'primeira pintura abaixo de 4 s com CPU 4x mais lenta', Math.round(fcp) + ' ms');
    conferir((await texto('dica-senha')).includes('6'), 'o minimo da senha aparece ANTES de errar',
      await texto('dica-senha'));

    // ------------------------------------------------------- 2. a validacao
    console.log('\n=== a validacao, sem rede ===');
    await tentarEntrar('', '');
    conferir(await texto('erro-entrada') === 'Preencha o e-mail e a senha.', 'campos vazios pedem preenchimento');
    await tentarEntrar('fulano', 'segredo123');
    conferir((await texto('erro-entrada')).includes('não parece completo'), 'e-mail malformado e barrado',
      (await texto('erro-entrada')).slice(0, 40));
    await tentarEntrar(CONTA.email, 'errada99');
    const msg = await texto('erro-entrada');
    conferir(msg.includes('não conferem') && !msg.includes('Não achamos'),
      'senha errada NAO entrega se a conta existe', msg.slice(0, 40));

    // ----------------------------------------------- 3. recuperacao de senha
    console.log('\n=== recuperar senha nunca revela se a conta existe ===');
    await js(`document.getElementById('ir-recuperar').click()`);
    await js(`document.getElementById('email').value = 'ninguem@exemplo.com';
              document.getElementById('btn-entrar').click()`);
    await dormir(250);
    const avisoFantasma = await texto('aviso-entrada');
    await js(`document.getElementById('ir-recuperar').click()`);
    await js(`document.getElementById('email').value = ${JSON.stringify(CONTA.email)};
              document.getElementById('btn-entrar').click()`);
    await dormir(250);
    const avisoReal = await texto('aviso-entrada');
    conferir(avisoFantasma !== '' && avisoFantasma === avisoReal,
      'a resposta e IDENTICA exista a conta ou nao', avisoReal.slice(0, 40));

    // ------------------------------------------------------------- 4. entrar
    console.log('\n=== entrando, e o progresso que ja existia ===');
    await tentarEntrar(CONTA.email, CONTA.senha);
    // A pessoa tentou abrir #/python antes de entrar. Depois do login ela vai
    // PARA ONDE QUERIA IR, e nao para a escolha de trilha -- link direto que se
    // perde no login e link que ninguem mais compartilha. A primeira versao
    // deste teste esperava a escolha e reprovou o comportamento certo.
    conferir(await esperar(visivel('vista-trilha')), 'a conta certa entra, e no endereco que a pessoa pediu');
    await js(`location.hash = '#/'`);
    conferir(await esperar(visivel('vista-escolha')), 'a escolha de trilha abre depois de entrar');
    conferir(await texto('quem') === CONTA.email, 'mostra quem esta na conta');
    const nomes = await js(`[...document.querySelectorAll('#lista-trilhas .titulo-cartao')].map(e => e.textContent)`);
    conferir(nomes.indexOf('Java') < nomes.indexOf('Selenium'), 'Java vem antes de Selenium, como no app');
    const ladoPython = await js(`document.querySelector('a[href="#/python"] .lado').textContent`);
    conferir(ladoPython === '3 de 50', 'Python mostra o progresso que veio da nuvem', ladoPython);
    const ladoJava = await js(`document.querySelector('a[href="#/java"] .lado').textContent`);
    conferir(ladoJava === '5 lições', 'trilha nunca jogada ve um convite, nao zeros', ladoJava);

    await js(`document.querySelector('a[href="#/python"]').click()`);
    conferir(await esperar(visivel('vista-trilha')), 'clicar em Python abre a trilha');
    const lado01 = await js(`document.querySelector('a[href="#/python/python-beg-01"] .lado').textContent`);
    // Quatro partidas, tres questoes distintas: refazer nao conta duas vezes.
    conferir(lado01 === '3 de 10', 'licao 01 conta questoes DISTINTAS, e nao partidas', lado01);
    const licoes = await js(`[...document.querySelectorAll('#lista-licoes .num-licao')].map(e => e.textContent)`);
    conferir(!licoes.some((t) => t.includes(' 00')), 'a licao 00 de referencia NAO aparece');

    // ----------------------------------------------------------- 5. jogar
    console.log('\n=== jogando python-beg-03 inteira ===');
    const licao = JSON.parse(fs.readFileSync(path.join(RAIZ, 'app/assets/content/python/python-beg-03.json'), 'utf8'));
    await js(`document.querySelector('a[href="#/python/python-beg-03"]').click()`);
    conferir(await esperar(visivel('vista-exercicio') + ` && document.querySelectorAll('.alt').length > 0`),
      'clicar na licao abre o exercicio');

    let errouUmaVez = false;
    let jogadas = 0;
    for (let i = 0; i < licao.questions.length; i++) {
      const q = licao.questions[i];
      if (await texto('enunciado') !== q.prompt) {
        conferir(false, `questao ${i + 1} e a do banco`);
        break;
      }
      if (q.answerType === 'multipleChoice') {
        const certa = q.options.find((o) => o.correct).id;
        const clicar = (id) => js(`(() => {
          const b = [...document.querySelectorAll('.alt')].find(x => x.querySelector('.rotulo').textContent === '${id}');
          if (b) b.click(); return !!b; })()`);
        if (!errouUmaVez) {
          const errada = q.options.find((o) => !o.correct).id;
          await clicar(errada);
          await js(`document.getElementById('btn-verificar').click()`);
          const riscada = await js(`[...document.querySelectorAll('.alt.eliminada .rotulo')].map(e => e.textContent)`);
          conferir(riscada.includes(errada), 'errar risca a alternativa escolhida');
          conferir(await texto('retorno-titulo') === 'AINDA NÃO', 'errar mostra AINDA NÃO, e nunca ERRADO');
          errouUmaVez = true;
        }
        await clicar(certa);
      } else {
        await js(`document.getElementById('campo').value = ${JSON.stringify(q.accepted[0])}`);
      }
      await js(`document.getElementById('btn-verificar').click()`);
      if (await js(`document.getElementById('retorno').dataset.fase`) !== 'acertou') {
        conferir(false, `questao ${i + 1} (${q.id}) aceita a resposta do banco`);
        break;
      }
      await js(`document.getElementById('btn-verificar').click()`);
      await dormir(60);
      jogadas++;
    }
    conferir(jogadas === licao.questions.length, 'as questoes aceitaram a resposta do banco',
      `${jogadas} de ${licao.questions.length}`);

    // -------------------------------------------- 6. o formato de cada partida
    console.log('\n=== as partidas gravadas, no formato do app ===');
    const gravadas = await js('window.__gravadas');
    conferir(gravadas.length === licao.questions.length, 'uma partida gravada por questao',
      `${gravadas.length} gravadas`);
    const esperadas = COLUNAS_DA_PARTIDA.join(',');
    const erradas = gravadas.filter((p) => Object.keys(p).sort().join(',') !== esperadas);
    conferir(erradas.length === 0, 'TODAS com exatamente as colunas de evento_resposta',
      erradas.length ? 'veio: ' + Object.keys(erradas[0]).sort().join(',') : '');
    conferir(gravadas.every((p) => p.uid === CONTA.uid && p.evento_id === `${p.uid}|${p.question_id}|${p.respondida_em}`),
      'o evento_id segue uid|questao|instante, como no app');
    conferir(gravadas.every((p) => typeof p.usou_dica === 'number'), 'usou_dica e INTEIRO, nunca booleano');
    conferir(gravadas.every((p) => ['acertou', 'revelada'].includes(p.desfecho)),
      'o desfecho e acertou ou revelada -- nunca "revelado"');
    conferir(gravadas[0].tentativas === 2, 'a questao em que errou registra 2 tentativas',
      'tentativas: ' + gravadas[0].tentativas);

    // ------------------------------------------------------ 7. de volta
    conferir(await esperar(visivel('vista-trilha')), 'o fim da licao devolve para a trilha');
    const lado03 = await js(`document.querySelector('a[href="#/python/python-beg-03"] .lado').textContent`);
    conferir(lado03 === '10 de 10', 'a licao jogada aparece completa na trilha', lado03);
    conferir(await js(`document.querySelector('a[href="#/python/python-beg-03"]').classList.contains('concluida')`),
      'licao completa ganha a marca de concluida');

    // ------------------------------------------------------------ 8. sair
    console.log('\n=== saindo da conta ===');
    await js(`location.hash = '#/'`);
    await esperar(visivel('vista-escolha'));
    await js(`document.getElementById('sair-conta').click()`);
    conferir(await esperar(visivel('vista-entrada')), 'sair da conta volta para a entrada');

    const erros = eventos.filter((e) => e.method === 'Log.entryAdded' && e.params.entry.level === 'error')
      .map((e) => e.params.entry.text);
    conferir(erros.length === 0, 'nenhum erro no console', erros.slice(0, 2).join(' | '));

    ws.close();
    console.log(falhas.length ? `\nJOGO REPROVADO: ${falhas.length} falha(s)` : '\nJOGO APROVADO');
    await encerrar(falhas.length ? 1 : 0);
  } catch (e) {
    console.error('o teste quebrou:', e);
    await encerrar(1);
  }
})();
