/* Prova o STANDBY do Tr∅nikAt cortando a rede DE VERDADE.
 *
 * `Network.emulateNetworkConditions { offline: true }` desliga a rede do
 * navegador inteiro: o `fetch` rejeita e `navigator.onLine` vira false, como
 * aconteceria no elevador. Um dublê do `fetch` provaria so que o `catch` roda.
 *
 * Tres coisas que quero ver, e a terceira e a que me preocupa:
 *   1. o standby aparece, com o gato cinza e a frase
 *   2. o campo desliga, e diz por que
 *   3. a REDE VOLTANDO tira ele do standby sozinho -- sem isso, quem perdeu o
 *      sinal no elevador olharia um gato cinza para sempre
 */
const { spawn } = require('child_process');
const fs = require('fs');

const CHROME = 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const PERFIL = 'D:/dev/chrome-standby-' + Date.now();
const PORTA = 9420;
const ALVO = process.argv[2];
const SAIDA = process.argv[3];
const dormir = (ms) => new Promise((r) => setTimeout(r, ms));

let id = 1;
function conversa(ws) {
  const p = new Map(); const eventos = [];
  ws.addEventListener('message', (e) => {
    const m = JSON.parse(e.data);
    if (m.id && p.has(m.id)) { p.get(m.id)(m); p.delete(m.id); } else if (m.method) eventos.push(m);
  });
  const enviar = (method, params = {}, sessionId) => new Promise((res) => {
    const i = id++; p.set(i, res);
    ws.send(JSON.stringify(sessionId ? { id: i, method, params, sessionId } : { id: i, method, params }));
  });
  return [enviar, eventos];
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
  const [cdp] = conversa(ws);
  const { targetId } = await cdp('Target.createTarget', { url: 'about:blank' }).then((r) => r.result);
  const { sessionId } = await cdp('Target.attachToTarget', { targetId, flatten: true }).then((r) => r.result);
  for (const d of ['Page', 'Runtime', 'Network']) await cdp(d + '.enable', {}, sessionId);
  const js = async (e) => (await cdp('Runtime.evaluate',
    { expression: e, returnByValue: true, awaitPromise: true }, sessionId)).result.result.value;

  await cdp('Page.navigate', { url: ALVO }, sessionId);
  await dormir(3000);
  await js(`document.getElementById('btn-tronikat').click()`);
  await dormir(400);

  console.log('\n=== com rede ===');
  conferir(await js(`document.getElementById('tronikat-standby').hidden`), 'standby fica escondido');
  conferir(await js(`!document.getElementById('tronikat-campo').disabled`), 'da para digitar');

  console.log('\n=== rede cortada (Network.emulateNetworkConditions) ===');
  await cdp('Network.emulateNetworkConditions',
    { offline: true, latency: 0, downloadThroughput: 0, uploadThroughput: 0 }, sessionId);
  await dormir(700);

  conferir(await js(`navigator.onLine === false`), 'o navegador se declara offline');
  conferir(await js(`!document.getElementById('tronikat-standby').hidden`), 'o standby APARECE');
  // MEDE VISIBILIDADE, e nao o atributo `hidden` de um elemento especifico.
  // A primeira versao perguntava se a propria conversa estava `hidden`, e ela
  // reprovou quando o retrato do codec entrou: quem passou a ser escondido foi
  // o bloco que envolve os dois. O comportamento continuava certo -- a
  // assercao e que media o mecanismo em vez do efeito.
  conferir(!(await js(`document.getElementById('tronikat-conversa').checkVisibility()`)),
    'a conversa sai de cena');
  conferir(!(await js(`document.getElementById('retrato').checkVisibility()`)),
    'e o retrato colorido tambem -- quem fala agora e o standby');
  conferir(await js(`document.getElementById('tronikat-campo').disabled`), 'o campo desliga');
  conferir(await js(`document.getElementById('tronikat-enviar').disabled`), 'o botao enviar desliga');
  conferir(await js(`document.getElementById('btn-tronikat').classList.contains('offline')`),
    'o botao flutuante despinta');

  const cinza = await js(`getComputedStyle(document.querySelector('.standby-arte')).filter`);
  conferir(/grayscale\(1\)/.test(cinza), 'o mascote perde a cor', cinza);

  const titulo = await js(`document.querySelector('.standby-titulo').textContent`);
  conferir(titulo === 'CONNECTION LOST', 'a frase que ele pediu', titulo);
  const recado = await js(`document.querySelector('.standby-recado').textContent`);
  conferir(/[Aa]guardando conex/.test(recado), 'diz que esta aguardando', recado);
  const nota = await js(`document.querySelector('.standby-nota').textContent`);
  conferir(/jogo continua/.test(nota), 'avisa que o JOGO nao caiu junto', nota);

  // O chuvisco tem que ter tamanho: um elemento so de pintura com altura zero
  // desenha nada, e nenhum teste de texto pegaria -- ja aconteceu no app.
  const r = await js(`JSON.stringify((() => { const e = document.querySelector('.ruido-visor');
    const b = e.getBoundingClientRect(); return { w: Math.round(b.width), h: Math.round(b.height),
      anim: getComputedStyle(e).animationName }; })())`);
  const cx = JSON.parse(r);
  conferir(cx.w > 10 && cx.h > 4, 'a interferencia do visor tem tamanho', cx.w + 'x' + cx.h);
  conferir(cx.anim === 'chuvisco', 'e ela esta animada', cx.anim);

  const tiro = await cdp('Page.captureScreenshot', { format: 'png' }, sessionId);
  fs.writeFileSync(SAIDA, Buffer.from(tiro.result.data, 'base64'));
  console.log('   print: %s', SAIDA);

  console.log('\n=== rede de volta ===');
  await cdp('Network.emulateNetworkConditions',
    { offline: false, latency: 0, downloadThroughput: -1, uploadThroughput: -1 }, sessionId);
  await dormir(900);
  conferir(await js(`document.getElementById('tronikat-standby').hidden`),
    'ele SAI do standby sozinho quando a rede volta');
  conferir(await js(`!document.getElementById('tronikat-campo').disabled`), 'e da para digitar de novo');

  console.log('\n   %s', falhas ? 'REPROVADO: ' + falhas + ' falha(s)' : 'STANDBY APROVADO');
  ws.close(); chrome.kill(); await dormir(400);
  try { fs.rmSync(PERFIL, { recursive: true, force: true }); } catch {}
  process.exit(falhas ? 1 : 0);
})().catch((e) => { console.error('falhou:', e); process.exit(1); });
