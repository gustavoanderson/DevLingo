/* TESTE DE PONTA A PONTA DO DEVLINGO NO NAVEGADOR.
 *
 *     python tools/construir_jogo.py     # antes, uma vez
 *     node jogo/testar_jogo.js
 *
 * Joga uma licao INTEIRA como uma pessoa jogaria: abre a escolha de trilha,
 * entra em Python, abre a licao 03, responde as dez questoes -- errando a
 * primeira de proposito --, e confere que o fim da licao devolve para a
 * trilha.
 *
 * O instrumento e o que o CLAUDE.md registra para o site: Chrome por CDP, com
 * WebSocket nativo do Node e perfil novo a cada rodada. E a CPU vai
 * estrangulada em 4x, que e como se simula o notebook do Gustavo -- foi assim
 * que a versao pesada do site foi pega.
 *
 * COMO O TESTE SABE A RESPOSTA CERTA: lendo o mesmo JSON do banco que a pagina
 * le. Ele NAO pergunta a pagina qual e a certa -- se perguntasse, um defeito
 * que invertesse o gabarito passaria, porque teste e pagina errariam juntos.
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

  // O servidor e o do Python, servindo a RAIZ: o jogo busca as licoes em
  // ../app/assets/content, o mesmo banco que o app usa, sem copia.
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

    // Espera o servidor responder antes de navegar.
    for (let i = 0; i < 40; i++) {
      try { if ((await fetch(BASE)).ok) break; } catch { /* ainda subindo */ }
      await dormir(150);
    }

    // ---------------------------------------------------- 1. escolha de trilha
    console.log('\n=== escolha de trilha ===');
    await cdp('Page.navigate', { url: BASE }, sessionId);
    conferir(await esperar(visivel('vista-escolha')), 'a escolha de trilha aparece');
    // A vista aparecer NAO quer dizer que a medicao ja foi registrada: o
    // navegador anota a primeira pintura um pouco depois. A primeira versao
    // deste teste leu cedo demais e reprovou com NaN -- defeito do instrumento,
    // nao da pagina. Espera-se o registro existir.
    const EXPR_FCP = `(performance.getEntriesByType('paint')
      .find(p => p.name === 'first-contentful-paint') || {}).startTime`;
    await esperar(EXPR_FCP);
    const fcp = await js(EXPR_FCP);
    conferir(fcp > 0 && fcp < 4000, 'primeira pintura abaixo de 4 s com CPU 4x mais lenta',
      Math.round(fcp) + ' ms');
    const nomes = await js(`[...document.querySelectorAll('#lista-trilhas .titulo-cartao')].map(e => e.textContent)`);
    conferir(nomes.length >= 8, 'as trilhas do banco aparecem', nomes.length + ' trilhas');
    // A ordem e REGRA do app: Java depende de nada, Selenium le Java. Se ela
    // inverter aqui, a regra passou a morar em outro lugar.
    conferir(nomes.indexOf('Java') < nomes.indexOf('Selenium'), 'Java vem antes de Selenium, como no app');
    conferir(nomes.indexOf('JavaScript') < nomes.indexOf('Frameworks'), 'JavaScript vem antes de Frameworks');

    // ------------------------------------------------------------ 2. a trilha
    console.log('\n=== a trilha de Python ===');
    await js(`document.querySelector('a[href="#/python"]').click()`);
    conferir(await esperar(visivel('vista-trilha')), 'clicar em Python abre a trilha');
    const licoes = await js(`[...document.querySelectorAll('#lista-licoes .num-licao')].map(e => e.textContent)`);
    conferir(licoes.length === 5, 'cinco licoes jogaveis', licoes.join(' / '));
    conferir(!licoes.some((t) => t.includes(' 00')), 'a licao 00 de referencia NAO aparece');

    // ----------------------------------------------------------- 3. a licao
    console.log('\n=== jogando python-beg-03 inteira ===');
    const licao = JSON.parse(fs.readFileSync(
      path.join(RAIZ, 'app/assets/content/python/python-beg-03.json'), 'utf8'));
    await js(`document.querySelector('a[href="#/python/python-beg-03"]').click()`);
    conferir(await esperar(visivel('vista-exercicio') + ` && document.querySelectorAll('.alt').length > 0`),
      'clicar na licao abre o exercicio');

    let errouUmaVez = false;
    let jogadas = 0;
    for (let i = 0; i < licao.questions.length; i++) {
      const q = licao.questions[i];
      const enunciado = await js(`document.getElementById('enunciado').textContent`);
      if (enunciado !== q.prompt) {
        conferir(false, `questao ${i + 1} e a do banco`, `veio "${enunciado.slice(0, 40)}"`);
        break;
      }
      if (q.answerType === 'multipleChoice') {
        const certa = q.options.find((o) => o.correct).id;
        const clicar = (id) => js(`(() => {
          const b = [...document.querySelectorAll('.alt')].find(x => x.querySelector('.rotulo').textContent === '${id}');
          if (b) b.click(); return !!b; })()`);
        if (!errouUmaVez) {
          // Erra a primeira de proposito: a eliminacao e a parte da mecanica que
          // mais depende do cerebro, e um teste que so acerta nunca a exercita.
          const errada = q.options.find((o) => !o.correct).id;
          await clicar(errada);
          await js(`document.getElementById('btn-verificar').click()`);
          const riscada = await js(`[...document.querySelectorAll('.alt.eliminada .rotulo')].map(e => e.textContent)`);
          conferir(riscada.includes(errada), 'errar risca a alternativa escolhida', 'riscada: ' + riscada.join(','));
          conferir(await js(`document.getElementById('retorno-titulo').textContent`) === 'AINDA NÃO',
            'errar mostra AINDA NÃO, e nunca ERRADO');
          errouUmaVez = true;
        }
        await clicar(certa);
      } else {
        await js(`document.getElementById('campo').value = ${JSON.stringify(q.accepted[0])}`);
      }
      await js(`document.getElementById('btn-verificar').click()`);
      const fase = await js(`document.getElementById('retorno').dataset.fase`);
      if (fase !== 'acertou') {
        conferir(false, `questao ${i + 1} (${q.id}) aceita a resposta do banco`, 'fase: ' + fase);
        break;
      }
      await js(`document.getElementById('btn-verificar').click()`); // Continuar
      await dormir(60);
      jogadas++;
    }
    // Conta as que PASSARAM, e nao so as que o laco visitou: se ele sair no
    // meio por falha, esta linha tem que reprovar junto, e nao dizer ok.
    conferir(jogadas === licao.questions.length,
      `as ${licao.questions.length} questoes aceitaram a resposta do banco`, `${jogadas} de ${licao.questions.length}`);

    // ------------------------------------------------------- 4. fim da licao
    conferir(await esperar(visivel('vista-trilha')), 'o fim da licao devolve para a trilha');
    conferir(await js(`location.hash`) === '#/python', 'o endereco volta para #/python');

    // ------------------------------------------------ 5. o botao voltar do navegador
    await js(`history.back()`);
    conferir(await esperar(visivel('vista-exercicio')), 'o voltar do navegador reabre a licao');

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
