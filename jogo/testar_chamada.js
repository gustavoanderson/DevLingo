/* Prova a CHAMADA: o balao de tres pontinhos que anuncia a IA.
 *
 * Quatro coisas, e as tres ultimas sao as que um teste de texto nao pegaria:
 *   1. ela aparece sozinha, sem ninguem tocar em nada
 *   2. ela se MOVE -- animacao com nome, nao so um elemento parado
 *   3. o botao pulsa junto
 *   4. ela some depois do primeiro toque, e some quando cai a rede
 */
const { spawn } = require('child_process');
const fs = require('fs');

const CHROME = 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const PERFIL = 'D:/dev/chrome-chamada-' + Date.now();
const PORTA = 9422;
const ALVO = process.argv[2];
const SAIDA = process.argv[3];
const dormir = (ms) => new Promise((r) => setTimeout(r, ms));

let id = 1;
function conversa(ws) {
  const p = new Map();
  ws.addEventListener('message', (e) => {
    const m = JSON.parse(e.data);
    if (m.id && p.has(m.id)) { p.get(m.id)(m); p.delete(m.id); }
  });
  return (method, params = {}, sessionId) => new Promise((res) => {
    const i = id++; p.set(i, res);
    ws.send(JSON.stringify(sessionId ? { id: i, method, params, sessionId } : { id: i, method, params }));
  });
}

let falhas = 0;
const conferir = (ok, nome, det = '') => {
  console.log('   %s %s%s', ok ? 'ok   ' : 'FALHA', nome, det ? '  (' + det + ')' : '');
  if (!ok) falhas++;
};

(async () => {
  fs.mkdirSync(PERFIL, { recursive: true });
  const chrome = spawn(CHROME, [
    '--remote-debugging-port=' + PORTA, '--user-data-dir=' + PERFIL,
    '--no-first-run', '--no-default-browser-check', '--headless=new',
    '--use-gl=angle', '--use-angle=d3d11', '--window-size=1280,860', 'about:blank',
  ], { stdio: 'ignore' });

  let v = null;
  for (let i = 0; i < 60 && !v; i++) {
    try { v = await (await fetch('http://127.0.0.1:' + PORTA + '/json/version')).json(); }
    catch { await dormir(250); }
  }
  const ws = new WebSocket(v.webSocketDebuggerUrl);
  await new Promise((r) => ws.addEventListener('open', r));
  const cdp = conversa(ws);
  const { targetId } = await cdp('Target.createTarget', { url: 'about:blank' }).then((r) => r.result);
  const { sessionId } = await cdp('Target.attachToTarget', { targetId, flatten: true }).then((r) => r.result);
  for (const d of ['Page', 'Runtime', 'Network']) await cdp(d + '.enable', {}, sessionId);
  const js = async (e) => (await cdp('Runtime.evaluate',
    { expression: e, returnByValue: true, awaitPromise: true }, sessionId)).result.result.value;

  await cdp('Page.navigate', { url: ALVO }, sessionId);
  await dormir(2500);

  console.log('\n=== ao chegar, sem tocar em nada ===');
  conferir(await js(`!document.getElementById('tronikat-chamada').hidden`),
    'a chamada aparece sozinha');
  conferir(await js(`document.querySelectorAll('#tronikat-chamada i').length === 3`),
    'sao TRES pontinhos');

  // Tamanho, porque elemento que so pinta pode resolver para zero sem nada
  // no texto denunciar -- ja aconteceu no app, na barra de desfechos.
  const cx = JSON.parse(await js(`JSON.stringify((() => {
    const b = document.getElementById('tronikat-chamada').getBoundingClientRect();
    const p = document.querySelector('#tronikat-chamada i').getBoundingClientRect();
    return { w: Math.round(b.width), h: Math.round(b.height), pw: Math.round(p.width) };
  })())`));
  conferir(cx.w > 40 && cx.h > 20, 'o balao tem tamanho', cx.w + 'x' + cx.h);
  conferir(cx.pw >= 5, 'e os pontinhos tambem', cx.pw + 'px');

  console.log('\n=== "em destaque": ela se move e o botao brilha ===');
  const an = await js(`getComputedStyle(document.querySelector('#tronikat-chamada i')).animationName`);
  conferir(an === 'pontinho', 'os pontinhos estao animados', an);
  const anb = await js(`getComputedStyle(document.getElementById('tronikat-chamada')).animationName`);
  conferir(/boia/.test(anb), 'o balao boia', anb);
  const pulso = await js(`getComputedStyle(document.getElementById('btn-tronikat')).animationName`);
  conferir(pulso === 'pulso', 'o botao pulsa', pulso);

  // O ATRASO ESCALONADO e o que faz ler como "digitando" em vez de tres luzes
  // piscando juntas. Sem ele o efeito existe e comunica outra coisa.
  const atrasos = await js(`[...document.querySelectorAll('#tronikat-chamada i')]
    .map(e => getComputedStyle(e).animationDelay).join(',')`);
  conferir(new Set(atrasos.split(',')).size === 3, 'os tres pontinhos saltam em tempos diferentes', atrasos);

  const tiro = await cdp('Page.captureScreenshot', { format: 'png' }, sessionId);
  fs.writeFileSync(SAIDA, Buffer.from(tiro.result.data, 'base64'));
  console.log('   print: %s', SAIDA);

  console.log('\n=== sem rede a chamada se cala ===');
  await cdp('Network.emulateNetworkConditions',
    { offline: true, latency: 0, downloadThroughput: 0, uploadThroughput: 0 }, sessionId);
  await dormir(600);
  conferir(await js(`document.getElementById('tronikat-chamada').hidden`),
    'tres pontinhos saltitando nao convivem com "connection lost"');
  await cdp('Network.emulateNetworkConditions',
    { offline: false, latency: 0, downloadThroughput: -1, uploadThroughput: -1 }, sessionId);
  await dormir(600);
  conferir(await js(`!document.getElementById('tronikat-chamada').hidden`),
    'e volta quando a rede volta');

  console.log('\n=== depois do primeiro toque ela nao insiste ===');
  await js(`document.getElementById('btn-tronikat').click()`);
  await dormir(300);
  conferir(await js(`document.getElementById('tronikat-chamada').hidden`), 'some ao abrir');
  conferir(await js(`!document.getElementById('btn-tronikat').classList.contains('chamando')`),
    'e o botao para de pulsar');
  await js(`document.getElementById('tronikat-fechar').click()`);
  await dormir(300);
  conferir(await js(`document.getElementById('tronikat-chamada').hidden`),
    'NAO volta ao fechar -- aviso que nao para de avisar vira ruido');

  console.log('\n   %s', falhas ? 'REPROVADO: ' + falhas + ' falha(s)' : 'CHAMADA APROVADA');
  ws.close(); chrome.kill(); await dormir(400);
  try { fs.rmSync(PERFIL, { recursive: true, force: true }); } catch {}
  process.exit(falhas ? 1 : 0);
})().catch((e) => { console.error('falhou:', e); process.exit(1); });
