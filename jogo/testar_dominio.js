/* O Firebase Auth so aceita pedido de dominio AUTORIZADO no console.
 *
 * Se `gustavoanderson.github.io` nao estiver na lista, todo login publicado
 * falha com `auth/unauthorized-domain` -- e esse erro nao aparece em lugar
 * nenhum do repositorio, so no navegador de quem abre o link. E exatamente a
 * classe de defeito que este projeto ja pagou com as regras do Firestore.
 *
 * O teste manda credencial falsa de proposito: o que interessa nao e entrar, e
 * QUAL erro volta. "credencial invalida" prova que o pedido chegou ao Firebase;
 * "unauthorized-domain" prova que nem chegou.
 */
'use strict';
const { spawn } = require('child_process');
const http = require('http');

const PORTA_CDP = 9416;
const URL = process.argv[2] || 'https://devlingo.app.br/jogo/';
const esperar = (ms) => new Promise((r) => setTimeout(r, ms));

async function alvo() {
  for (let i = 0; i < 60; i++) {
    try {
      const lista = await new Promise((res, rej) => {
        http.get(`http://127.0.0.1:${PORTA_CDP}/json/list`, (r) => {
          let b = ''; r.on('data', (d) => (b += d)); r.on('end', () => res(JSON.parse(b)));
        }).on('error', rej);
      });
      const p = lista.find((t) => t.type === 'page' && t.webSocketDebuggerUrl);
      if (p) return p.webSocketDebuggerUrl;
    } catch (e) { /* ainda subindo */ }
    await esperar(500);
  }
  throw new Error('o Chrome nao abriu');
}

(async () => {
  const perfil = 'D:/dev/chrome-dom-' + Date.now();
  const chrome = spawn('C:/Program Files/Google/Chrome/Application/chrome.exe',
    [`--remote-debugging-port=${PORTA_CDP}`, `--user-data-dir=${perfil}`,
     '--headless=new', '--use-gl=angle', '--use-angle=d3d11',
     '--no-first-run', '--no-default-browser-check', URL], { stdio: 'ignore' });

  const ws = new WebSocket(await alvo());
  await new Promise((r) => ws.addEventListener('open', r));
  let id = 0;
  const pend = new Map();
  ws.addEventListener('message', (ev) => {
    const d = JSON.parse(ev.data);
    if (d.id && pend.has(d.id)) { pend.get(d.id)(d); pend.delete(d.id); }
  });
  const cmd = (m, p = {}) => new Promise((res) => {
    const meu = ++id; pend.set(meu, res);
    ws.send(JSON.stringify({ id: meu, method: m, params: p }));
  });
  const js = async (e) => (await cmd('Runtime.evaluate',
    { expression: e, awaitPromise: true, returnByValue: true })).result.result.value;

  await cmd('Runtime.enable');
  await esperar(6000);

  console.log('=== o jogo PUBLICADO ===');
  console.log('  cerebro:', await js('typeof devlingo'));
  console.log('  trilhas:', await js('typeof trilhas !== "undefined" ? trilhas.length : -1'));

  // Credencial falsa: interessa o CODIGO do erro, nao entrar.
  const erro = await js(`(async () => {
    try {
      await Nuvem.entrar('nao-existe-mesmo-2026@devlingo.invalid', 'senhaqualquer123');
      return 'ENTROU (inesperado)';
    } catch (e) { return String(e && (e.code || e.message || e)); }
  })()`);
  console.log('  resposta do Firebase:', erro);

  const barrado = /unauthorized.domain/i.test(erro || '');
  console.log(barrado
    ? '\nDOMINIO NAO AUTORIZADO -- o login publicado NAO funciona.\n'
      + 'Console do Firebase > Authentication > Settings > Authorized domains\n'
      + 'e acrescentar: gustavoanderson.github.io'
    : '\nDOMINIO AUTORIZADO -- o pedido chegou ao Firebase e ele respondeu.');

  ws.close(); chrome.kill();
  process.exit(barrado ? 1 : 0);
})();
