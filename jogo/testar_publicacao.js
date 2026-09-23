/* Prova que o JOGO abre no layout que o Pages vai servir.
 *
 * O teste do jogo roda contra a raiz do repositorio; a publicacao e uma
 * montagem diferente, e presumir que "e a mesma coisa" e exatamente o erro que
 * este repositorio ja pagou. Aqui se serve a pasta montada e se conta erro de
 * console, que e o que denuncia caminho quebrado.
 */
'use strict';
const { spawn } = require('child_process');
const http = require('http');

const PUB = process.argv[2] || "D:/dev/pub-teste";
const PORTA_WEB = 8000;   // a porta que o Worker autoriza no CORS
const PORTA_CDP = 9415;
const esperar = (ms) => new Promise((r) => setTimeout(r, ms));

let falhas = 0;
const ok = (nome, cond, detalhe = '') => {
  console.log(`  ${cond ? 'ok   ' : 'FALHA'} ${nome}${detalhe ? '  ' + detalhe : ''}`);
  if (!cond) falhas++;
};

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
  const servidor = spawn('python',
    ['-m', 'http.server', String(PORTA_WEB), '--bind', '127.0.0.1'],
    { cwd: PUB, stdio: 'ignore' });
  const perfil = 'D:/dev/chrome-pub-' + Date.now();
  const chrome = spawn('C:/Program Files/Google/Chrome/Application/chrome.exe',
    [`--remote-debugging-port=${PORTA_CDP}`, `--user-data-dir=${perfil}`,
     '--headless=new', '--use-gl=angle', '--use-angle=d3d11',
     '--no-first-run', '--no-default-browser-check',
     `http://127.0.0.1:${PORTA_WEB}/jogo/index.html`],
    { stdio: 'ignore' });

  const ws = new WebSocket(await alvo());
  await new Promise((r) => ws.addEventListener('open', r));

  let id = 0;
  const pendentes = new Map();
  const eventos = [];
  ws.addEventListener('message', (ev) => {
    const d = JSON.parse(ev.data);
    if (d.id && pendentes.has(d.id)) { pendentes.get(d.id)(d); pendentes.delete(d.id); }
    else if (d.method) eventos.push(d);
  });
  const cmd = (method, params = {}) => new Promise((res) => {
    const meu = ++id; pendentes.set(meu, res);
    ws.send(JSON.stringify({ id: meu, method, params }));
  });
  const js = async (e) => (await cmd('Runtime.evaluate',
    { expression: e, awaitPromise: true, returnByValue: true })).result.result.value;

  await cmd('Runtime.enable');
  await cmd('Log.enable');
  await cmd('Page.enable');
  await cmd('Page.reload');
  await esperar(5000);

  console.log('\n=== o jogo no layout do Pages ===');

  ok('o cerebro carregou', await js('typeof devlingo === "object"'));
  const trilhas = await js('typeof trilhas !== "undefined" ? trilhas.length : -1');
  ok('as trilhas vieram do conteudo.json', trilhas > 0, `${trilhas} trilhas`);
  ok('a tela de entrada aparece',
     await js(`!document.getElementById('vista-entrada').hidden`));
  ok('o mascote da entrada resolve',
     await js(`[...document.images].filter(i => i.currentSrc && !i.complete).length === 0`));
  ok('o botao do Tr∅nikAt existe',
     await js(`!!document.getElementById('btn-tronikat')`));

  // O que denuncia caminho quebrado e 404 no console, nao a tela.
  const erros = eventos
    .filter((e) => e.method === 'Log.entryAdded' && e.params.entry.level === 'error')
    .map((e) => e.params.entry.text);
  ok('nenhum erro no console', erros.length === 0, erros.slice(0, 3).join(' | '));

  ws.close(); servidor.kill(); chrome.kill();
  console.log(falhas ? `\n${falhas} FALHA(S)` : '\nPUBLICACAO APROVADA');
  process.exit(falhas ? 1 : 0);
})();
