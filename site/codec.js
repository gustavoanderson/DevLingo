/* O RETRATO DO CODEC, e ele e de DOIS lugares.
 *
 * Este arquivo saiu de dentro de `site/index.html` em 22/09/2026, sem uma
 * linha alterada, quando o Gustavo pediu o mesmo retrato na janela do jogo:
 * "tem que ser igual a da home do site, estilo metal gear, talvez reaproveitar
 * aquela mesmo".
 *
 * REAPROVEITAR, e nao copiar. Este repositorio ja pagou por duas
 * implementacoes da mesma regra: `normalize()` vive em Dart e em Python e
 * precisou de `tools/normalize_cases.json` so para nao divergirem em silencio;
 * a geometria dos cenarios sai de um gerador unico pelo mesmo motivo. Um
 * mascote desenhado em dois lugares divergiria igual -- e ali a divergencia
 * seria na CARA do personagem, que e justamente o que a regra "traco de
 * identidade se copia, nao se inventa" existe para proteger.
 *
 * Ele nao precisou ser parametrizado: ja procura `getElementById('retrato')` e
 * ja devolve um objeto inerte quando nao acha. Quem quiser o retrato poe um
 * canvas com esse id; quem nao quiser nao carrega nada.
 *
 * A API e `Fala.abrir(v, arredondamento, exato)`, e ela nasceu da cena 3D que
 * este desenho substituiu -- por isso `Voz` e `Estudio` continuam funcionando
 * sem saber que o desenho mudou.
 */
/* ------------------------------------------------- o retrato do codec
 *
 * Substitui a cabeca em 3D, e a razao nao foi so peso: no notebook do Gustavo
 * ela renderizou ERRADA -- cabeca preta, o `>_` do peito vazio, o pelo sumido.
 * Aqui desenhava certo. Mascote que depende do driver de video de cada
 * maquina para ter a propria cara nao serve, e a alternativa dele e melhor
 * que insistir: canvas 2D nao depende de GPU nenhuma.
 *
 * O molde e a tela de codec do Metal Gear Solid 1, pedido dele. E vale
 * registrar a correcao que ele mesmo fez: aquilo NAO e pixel art. Sao
 * retratos em baixa resolucao, com sombreado suave, que sao AMPLIADOS -- e a
 * ampliacao e que produz o pixel grande. Entao aqui se desenha normalmente,
 * com anti-serrilhado, num canvas de 128x96, e o CSS amplia com
 * `image-rendering: pixelated`. Desenhar direto em quadradinhos daria outra
 * coisa: daria Atari, e nao PlayStation.
 *
 * E "tem movimento, pouco, mas tem", que foi a outra frase dele. O codec
 * nunca fica parado: pisca, balanca um pixel, a boca acompanha a fala, o
 * visor varre. Tudo a 12 quadros por segundo, que e baixo DE PROPOSITO --
 * a animacao do codec e engasgada mesmo, e 12 qps num canvas de 12 mil pixels
 * nao custa nada. Comparar com o que saiu daqui: a cena 3D travava a thread
 * principal por 12,7 segundos ao montar.
 *
 * A API e a mesma da cena 3D -- `abrir(v, arredondamento, exato)` -- para que
 * `Voz` e `Estudio` continuem funcionando sem saber que o desenho mudou.
 */
const Fala = (function () {
  const c = document.getElementById('retrato');
  if (!c) return { abrir: () => {} };
  const L = 128, A = 96;                 // resolucao interna, ampliada pelo CSS
  c.width = L; c.height = A;
  const g = c.getContext('2d');
  const parado = matchMedia('(prefers-reduced-motion: reduce)').matches;

  // Cores canonicas, copiadas de `tronikat.svg` e nao escolhidas aqui: o
  // CLAUDE.md registra que inventar cor do personagem ja custou um retrato
  // inteiro refeito (o episodio do olho ambar).
  //
  // O metal e ESCURO de proposito. Na primeira versao deste retrato ele saiu
  // quase branco e o gato virou um gato branco comum -- exatamente o defeito
  // que aquele arquivo ja descreve ("o aco comecando em #DCDEEC"). Com o pelo
  // em #F4F2FA, o aco precisa cair para a casa dos #8x para a divisa aparecer.
  const PELO = '#F4F2FA', PELO_SOMBRA = '#C9C3E0';
  const METAL = '#7E8498', METAL_LUZ = '#A9AFC1', METAL_SOMBRA = '#575C6B';
  const ESCURO = '#17092E', CIANO = '#00E5FF', VISOR = '#39FF14';
  const ROSA = '#FF7ABF', ROSA_FORTE = '#FF2D95', MOLETOM = '#321E63';

  // A elipse da cabeca numa fonte so. As orelhas LEEM estes numeros para
  // achar onde a superficie esta; enquanto eles viviam soltos, a base da
  // orelha era um palpite -- e palpite foi o que deixou a orelha descolada.
  const CX = 64, CY = 45, RX = 25, RY = 22;

  let abertura = 0, alvo = 0, arredonda = 0, alvoArred = 0, preciso = false;

  const elipse = (x, y, rx, ry, cor) => {
    g.fillStyle = cor; g.beginPath(); g.ellipse(x, y, rx, ry, 0, 0, 7); g.fill();
  };

  /* Uma orelha.
     A BASE NAO E UMA RETA. Enquanto era, a orelha ficava descolada da cabeca,
     e o Gustavo apontou com um "como sempre" merecido -- o CLAUDE.md ja
     registra duas correcoes de orelha neste projeto.

     A causa, medida: a base reta ficava em y=30, mas a cabeca e curva. No
     meio da base a superficie esta em y=26,8; no canto de fora, em y=33,1.
     O canto externo flutuava 3,2 px ACIMA da cabeca. Desenhar a orelha antes
     da cabeca escondia a emenda do meio, e deixava justamente a ponta de fora
     aparecendo solta.

     Agora os dois cantos sao pontos SOBRE a elipse da cabeca, dados por
     angulo, e afundados 7% em direcao ao centro. Assim eles acompanham a
     curva em qualquer tamanho de cabeca, e a cabeca desenhada por cima cobre
     a base inteira -- a orelha nasce dela em vez de pousar nela.

     O angulo do apice continua saindo de seno e cosseno: o CLAUDE.md mede
     8,1 graus da vertical na arte canonica e registra que desenhar a olho ja
     saiu a 36 -- "ficou parecendo outro bicho". */
  function orelha(ang1, ang2, alt, inclina, corFora, corDentro) {
    const AFUNDA = .93;
    const naCabeca = (a) => {
      const r = a * Math.PI / 180;
      return [CX + Math.sin(r) * RX * AFUNDA, CY - Math.cos(r) * RY * AFUNDA];
    };
    const [x1, y1] = naCabeca(ang1), [x2, y2] = naCabeca(ang2);
    const mx = (x1 + x2) / 2, my = (y1 + y2) / 2;      // meio da base, na curva
    const t = inclina * Math.PI / 180;
    const ax = mx + Math.sin(t) * alt, ay = my - Math.cos(t) * alt;
    g.fillStyle = corFora;
    g.beginPath();
    g.moveTo(x1, y1); g.lineTo(ax, ay); g.lineTo(x2, y2);
    g.closePath(); g.fill();
    // Rosa por dentro: esta na arte canonica, e e o que impede a orelha de
    // ler como um triangulo chapado.
    g.fillStyle = corDentro;
    g.beginPath();
    g.moveTo(x1 + (mx - x1) * .40, y1 + (my - y1) * .40);
    g.lineTo(mx + (ax - mx) * .62, my + (ay - my) * .62);
    g.lineTo(x2 + (mx - x2) * .40, y2 + (my - y2) * .40);
    g.closePath(); g.fill();
  }

  function desenhar(t) {
    // --- fundo da transmissao ---
    // Degrade VERTICAL, e nao radial. O radial da primeira versao tinha 58 de
    // raio num canvas de 96 de altura, entao ele se fechava em elipse e lia
    // como um CHAO embaixo do gato -- um cenario que nao existe. Visto no
    // print, nao deduzido.
    const ceu = g.createLinearGradient(0, 0, 0, A);
    ceu.addColorStop(0, '#0B0520'); ceu.addColorStop(1, '#040109');
    g.fillStyle = ceu; g.fillRect(0, 0, L, A);
    g.fillStyle = 'rgba(57,255,20,.05)'; g.fillRect(0, 14, L, 58);  // brilho de tubo

    const bx = parado ? 0 : Math.round(Math.sin(t * .62));
    const by = parado ? 0 : Math.round(Math.sin(t * 1.05));
    // O busto inteiro sobe 5 px. Sem isso o painel `>_` do peito encostava
    // na borda de baixo e saia cortado ao meio -- visto no print. Subir o
    // conjunto custa uma linha; remexer trinta coordenadas custaria erros.
    g.save(); g.translate(bx, by - 5);

    // --- ombros e moletom, SANGRANDO pelas bordas ---
    // O CLAUDE.md registra por que: enquadramento que cabe inteiro no quadro
    // le como bonequinho, e nao como close. Entao os ombros saem da tela.
    g.fillStyle = MOLETOM;
    g.beginPath();
    g.moveTo(-14, A + 6); g.lineTo(-14, 88);
    g.quadraticCurveTo(20, 79, 42, 77);      // ombro tem quina; o moletom suaviza
    g.lineTo(86, 77);
    g.quadraticCurveTo(108, 79, 142, 88);
    g.lineTo(142, A + 6); g.closePath(); g.fill();

    // pescoco: ALARGA para baixo, senao vira balde -- outra ja registrada la
    g.fillStyle = PELO_SOMBRA;
    g.beginPath();
    g.moveTo(57, 62); g.lineTo(71, 62); g.lineTo(76, 79); g.lineTo(52, 79);
    g.closePath(); g.fill();

    // --- painel `>_` no peito ---
    g.fillStyle = '#0A2607'; g.fillRect(53, 84, 24, 12);
    g.strokeStyle = VISOR; g.lineWidth = 1; g.strokeRect(53.5, 84.5, 23, 11);
    g.fillStyle = VISOR; g.font = '8px ui-monospace, monospace';
    g.fillText('>_', 57, 93);

    // --- orelhas, antes da cabeca para nascerem atras dela ---
    // Uma treme de vez em quando. E o tipo de movimento que o codec tem:
    // pouco, e sem avisar.
    const treme = !parado && (t % 7.3) > 7.05 ? 2.5 : 0;
    // O tremor entra na INCLINACAO, e nao na posicao: a orelha gira em torno
    // da propria base, que continua presa na cabeca. Mexer a base faria ela
    // descolar de novo, uma vez a cada sete segundos.
    // Os angulos dizem ONDE na cabeca a orelha nasce. Na primeira versao com
    // base curva eles eram -36..-13 e 13..38: perto demais do topo central, e
    // a orelha saiu um espeto fino com ombro de cabeca sobrando dos lados.
    // Orelha de gato nasce no canto de cima, e a base e quase tao larga
    // quanto a orelha e alta.
    orelha(-58, -20, 16, -8.1 - treme, PELO, ROSA);           // esquerda: pelo
    orelha(20, 60, 17, 9.9 + treme, METAL, METAL_SOMBRA);     // direita: metal
    // A direita NAO e o espelho da esquerda: e um pouco maior e mais
    // inclinada nas duas artes canonicas. Copiado, nao inventado.

    // --- cabeca: ~12% mais larga que alta, como a referencia (rx52/ry46) ---
    elipse(CX, CY, RX, RY, PELO);

    // metade metalica: recorte no meio, e nao uma segunda elipse por cima,
    // senao a emenda vira um degrau visivel depois da ampliacao
    g.save();
    g.beginPath(); g.rect(64, 0, L - 64, A); g.clip();
    elipse(CX, CY, RX, RY, METAL);
    g.save();
    g.beginPath(); g.ellipse(CX, CY, RX, RY, 0, 0, 7); g.clip();
    // Volume por tons CHAPADOS, nunca gradiente: e a regra que o CLAUDE.md
    // tirou de um gradiente que o flutter_svg simplesmente nao aplicou.
    g.fillStyle = METAL_LUZ;    g.fillRect(64, 27, 9, 40);
    g.fillStyle = METAL_SOMBRA; g.fillRect(82, 32, 8, 30);
    g.restore(); g.restore();

    // --- a costura ciano da divisa ---
    g.strokeStyle = CIANO; g.lineWidth = 1;
    g.beginPath(); g.moveTo(64, 24); g.lineTo(64, 67); g.stroke();

    // --- bigodes: saem das BOCHECHAS para fora, sem atravessar o rosto ---
    // Finos e curtos. Na primeira versao eram retas longas e grossas, e o
    // gato ficou com cara de antena.
    g.strokeStyle = 'rgba(242,240,255,.55)'; g.lineWidth = .7;
    for (const [x0, y0, x1, y1] of [
      [45, 51, 33, 48], [45, 54, 32, 55], [83, 51, 95, 48], [83, 54, 96, 55]]) {
      g.beginPath(); g.moveTo(x0, y0); g.lineTo(x1, y1); g.stroke();
    }

    // --- olho, no lado do PELO, que e a esquerda ---
    // Preto, redondo, com um brilho branco em cima. Foi aqui que eu ja
    // inventei um olho ambar de pupila em fenda, e o Gustavo pegou na hora:
    // "um gato de olho ambar e outro gato".
    const piscando = !parado && (t % 4.9) > 4.76;
    if (piscando) {
      g.strokeStyle = ESCURO; g.lineWidth = 2;
      g.beginPath(); g.moveTo(48, 44); g.lineTo(58, 44); g.stroke();
    } else {
      elipse(53, 43, 5, 5.8, ESCURO);
      elipse(54.6, 40.8, 1.7, 1.7, '#FFFFFF');
    }

    // --- visor, no lado do METAL ---
    g.fillStyle = '#23283A'; g.fillRect(69, 37, 20, 11);
    g.fillStyle = VISOR;     g.fillRect(70, 38, 18, 9);
    // A varredura do visor: uma linha clara que desce. E o unico movimento
    // que o personagem tem enquanto esta calado.
    if (!parado) {
      const linha = 38 + Math.floor((t * 9) % 12);
      if (linha < 47) { g.fillStyle = 'rgba(255,255,255,.5)'; g.fillRect(70, linha, 18, 1); }
    }
    g.fillStyle = 'rgba(0,0,0,.28)'; g.fillRect(70, 38, 18, 2);

    // --- focinho rosa ---
    g.fillStyle = ROSA_FORTE;
    g.beginPath(); g.moveTo(61, 53); g.lineTo(67, 53); g.lineTo(64, 56.5);
    g.closePath(); g.fill();

    // --- boca: e ela que carrega a fala ---
    // "o" e "u" fecham os cantos e projetam o labio: menos largura, mais
    // altura. Mesma regra da cena 3D que saiu daqui.
    const a = Math.max(0, abertura);
    const larg = 11 * (1 - arredonda * .34), alt = 1.3 + a * 7;
    elipse(64, 60 + alt * .3, larg / 2, alt / 2 + .6, ESCURO);
    if (a > .3) elipse(64, 61 + alt * .34, larg / 3.6, alt / 3.8, '#8E2A5E');

    g.restore();

    // --- interferencia: uma fatia deslocada, um quadro a cada tanto ---
    // E o que faz a imagem parecer TRANSMITIDA, e nao desenhada.
    if (!parado && Math.random() < .03) {
      const y = Math.floor(Math.random() * (A - 12)), h = 3 + Math.floor(Math.random() * 6);
      g.putImageData(g.getImageData(0, y, L, h), Math.random() < .5 ? -2 : 2, y);
    }
  }

  // 12 quadros por segundo. Baixo DE PROPOSITO -- a animacao do codec e
  // engasgada mesmo -- e barato por consequencia: 12 mil pixels, 12 vezes por
  // segundo. Compare com o que saiu daqui: a cena 3D travava a thread
  // principal por 12,7 segundos so para montar.
  let ultimo = 0;
  (function quadro(agora) {
    requestAnimationFrame(quadro);
    if (agora - ultimo < 83) return;
    ultimo = agora;
    abertura += (alvo - abertura) * (preciso ? .7 : .45);
    arredonda += (alvoArred - arredonda) * .5;
    desenhar(agora / 1000);
  })(0);

  return {
    abrir: (v, arred = 0, exato = false) => { alvo = v; alvoArred = arred; preciso = exato; },
  };
})();
