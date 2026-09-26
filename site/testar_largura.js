/* A home cabe na tela, no celular e no computador.
 *
 *     node site/testar_largura.js [pasta]      (padrao: site/)
 *
 * Existe porque o mesmo defeito apareceu DUAS VEZES em 25/09/2026, e nenhum
 * teste o pegaria: a pagina ficava mais larga que a tela do celular e
 * escorregava para o lado. Primeiro uma sombra decorativa com -50vw (565 px
 * numa tela de 390); horas depois, uma grade de cartoes que, para medir a
 * largura minima, concluia caber tres colunas (851 px). Nos dois casos quem
 * pegou foi uma medicao feita a mao.
 *
 * NO CELULAR, ESTOURAR A LARGURA NAO APARECE COMO ROLAGEM. O Chrome alarga a
 * area util inteira ate caber o que estourou -- e dai `scrollWidth` e
 * `innerWidth` crescem JUNTOS e comparar os dois nao acusa nada. O que acusa
 * e `innerWidth` passar da largura da tela. Por isso o teste emula um
 * celular de verdade (`mobile: true`), e nao so uma janela estreita.
 *
 * Confere tambem depois de rolar ate o fim: a nave e a bolinha do Tr∅nikAt
 * so aparecem com a rolagem, e sao elementos presos a direita.
 */
'use strict';
const { spawn } = require('child_process');
const fs = require('fs');
const http = require('http');
const os = require('os');
const path = require('path');

const PASTA = path.resolve(process.argv[2] || path.join(__dirname));
const PORTA_SITE = 8765 + Math.floor(Math.random() * 400);
const PORTA_CDP = 9500 + Math.floor(Math.random() * 400);
const CHROME = process.env.CHROME || (process.platform === 'win32'
  ? 'C:/Program Files/Google/Chrome/Application/chrome.exe' : 'google-chrome');
const dormir = (ms) => new Promise((r) => setTimeout(r, ms));

const TIPOS = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript',
  '.json': 'application/json', '.css': 'text/css', '.svg': 'image/svg+xml',
  '.jpg': 'image/jpeg', '.png': 'image/png', '.mp4': 'video/mp4', '.wav': 'audio/wav' };

function servir() {
  return http.createServer((req, res) => {
    const rel = decodeURIComponent(req.url.split('?')[0]).replace(/^\/+/, '') || 'index.html';
    const arquivo = path.join(PASTA, rel);
    if (!arquivo.startsWith(PASTA) || !fs.existsSync(arquivo) || fs.statSync(arquivo).isDirectory()) {
      res.writeHead(404); return res.end();
    }
    res.writeHead(200, { 'Content-Type': TIPOS[path.extname(arquivo)] || 'application/octet-stream' });
    fs.createReadStream(arquivo).pipe(res);
  }).listen(PORTA_SITE, '127.0.0.1');
}

let id = 1;
function conversa(ws) {
  const pendentes = new Map();
  ws.addEventListener('message', (e) => {
    const m = JSON.parse(e.data);
    if (m.id && pendentes.has(m.id)) { pendentes.get(m.id)(m); pendentes.delete(m.id); }
  });
  return (method, params = {}, sessionId) => new Promise((res) => {
    const i = id++; pendentes.set(i, res);
    ws.send(JSON.stringify(sessionId ? { id: i, method, params, sessionId } : { id: i, method, params }));
  });
}

(async () => {
  const servidor = servir();
  const perfil = fs.mkdtempSync(path.join(os.tmpdir(), 'largura-'));
  const chrome = spawn(CHROME, [
    '--remote-debugging-port=' + PORTA_CDP, '--user-data-dir=' + perfil, '--headless=new',
    '--no-first-run', '--no-default-browser-check', '--no-sandbox', 'about:blank',
  ], { stdio: 'ignore' });

  let v = null;
  for (let i = 0; i < 80 && !v; i++) {
    try { v = await (await fetch(`http://127.0.0.1:${PORTA_CDP}/json/version`)).json(); }
    catch { await dormir(250); }
  }
  if (!v) { console.log('o Chrome nao subiu'); process.exit(1); }
  const ws = new WebSocket(v.webSocketDebuggerUrl);
  await new Promise((r) => ws.addEventListener('open', r));
  const cdp = conversa(ws);

  let falhas = 0;
  for (const [nome, largura, altura, celular] of [['celular', 390, 844, true], ['computador', 1280, 860, false]]) {
    const { targetId } = (await cdp('Target.createTarget', { url: 'about:blank' })).result;
    const { sessionId } = (await cdp('Target.attachToTarget', { targetId, flatten: true })).result;
    await cdp('Page.enable', {}, sessionId);
    await cdp('Emulation.setDeviceMetricsOverride',
      { width: largura, height: altura, deviceScaleFactor: 1, mobile: celular }, sessionId);
    const js = async (e) => (await cdp('Runtime.evaluate',
      { expression: e, returnByValue: true, awaitPromise: true }, sessionId)).result.result.value;

    await cdp('Page.navigate', { url: `http://127.0.0.1:${PORTA_SITE}/index.html` }, sessionId);
    await dormir(2500);
    for (const quando of ['ao abrir', 'rolada ate o fim']) {
      if (quando !== 'ao abrir') {
        await js('window.scrollTo(0, document.documentElement.scrollHeight)');
        await dormir(2200);                       // o voo da nave leva 1,3 s
      }
      // O QUE SE MEDE E O QUE O VISITANTE SENTE, e isso muda com o aparelho.
      //   celular:    a area util cresce alem da tela (`innerWidth` > largura)
      //   computador: aparece a barra de rolagem horizontal -- conteudo mais
      //               largo que a tela E a rolagem lateral nao escondida.
      // `scrollTo` nao serve de sonda: ele rola por codigo mesmo com a rolagem
      // escondida, e acusaria 578 px numa pagina em que nenhum visitante via
      // barra nenhuma. O overflow do <body> vale para a janela quando o do
      // <html> e `visible` -- e a regra do CSS, e e ela que se reproduz aqui.
      const m = JSON.parse(await js(`(() => {
        const h = getComputedStyle(document.documentElement).overflowX;
        const efetivo = h === 'visible' ? getComputedStyle(document.body).overflowX : h;
        const escondida = efetivo === 'hidden' || efetivo === 'clip';
        const sobra = document.documentElement.scrollWidth - document.documentElement.clientWidth;
        return JSON.stringify({ area: innerWidth, barra: !escondida && sobra > 0, sobra });
      })()`));
      const ok = m.area <= largura && !m.barra;
      console.log(`  ${ok ? 'ok   ' : 'FALHA'} ${nome} ${largura} px, ${quando}: area ${m.area} px, barra lateral ${m.barra ? 'SIM' : 'nao'}`);
      if (!ok) falhas++;
    }
  }

  console.log(falhas ? `\nLARGURA REPROVADA: ${falhas} falha(s)` : '\nA HOME CABE NA TELA');
  chrome.kill(); servidor.close();
  try { fs.rmSync(perfil, { recursive: true, force: true }); } catch {}
  process.exit(falhas ? 1 : 0);
})();
