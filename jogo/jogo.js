/* A INTERFACE. Ela DESENHA, e nao decide.
 *
 * Toda pergunta de regra -- esta certo? elimina? revela? abre a dica? que cor
 * tem este token? -- e respondida por `cerebro.js`, compilado de
 * `app/lib/ponte_web.dart`. Este arquivo pinta o retrato que vem de volta.
 *
 * A divisao e o ponto do desenho todo, e ela tem um teste de fumaca proprio:
 * se alguem escrever aqui um `if (resposta === correta)`, a regra passa a
 * existir em dois lugares -- e o CLAUDE.md registra o que acontece depois.
 * Foi assim que o `normalize()` precisou de um arquivo de casos compartilhado
 * entre Dart e Python.
 */
'use strict';

const $ = (id) => document.getElementById(id);

/* A licao de exemplo vem do BANCO DE VERDADE, nao de um arquivo de mentira.
   Provar com dado real e o que distingue esta pagina de uma maquete. */
const LICAO = '../app/assets/content/python/python-beg-03.json';

let questoes = [];
let indice = 0;
let estado = null;

/* ------------------------------------------------------------------ desenho */

function pintarCodigo(codigo) {
  const ide = $('ide');
  if (!codigo) { ide.hidden = true; return; }
  ide.hidden = false;
  $('ide-nome').textContent = codigo.linguagem;

  const alvo = $('codigo');
  alvo.textContent = '';
  codigo.conteudo.split('\n').forEach((linha, i) => {
    const div = document.createElement('div');
    div.className = 'ln';

    const num = document.createElement('span');
    num.className = 'num';
    num.textContent = String(i + 1);
    div.appendChild(num);

    const src = document.createElement('span');
    src.className = 'src';
    // O REALCE VEM DO CEREBRO. A invariante que o teste do app cobre --
    // a concatenacao dos trechos e identica a linha original -- continua valendo
    // aqui, porque e o mesmo tokenizador.
    JSON.parse(devlingo.tokenizar(linha, codigo.linguagem)).forEach((t) => {
      const s = document.createElement('span');
      s.className = 't-' + t.tipo;
      s.textContent = t.texto;
      src.appendChild(s);
    });
    div.appendChild(src);
    alvo.appendChild(div);
  });
}

function pintarAlternativas(e) {
  const caixa = $('alternativas');
  caixa.textContent = '';
  caixa.hidden = e.ehEscrita;
  if (e.ehEscrita) return;

  e.alternativas.forEach((a) => {
    const b = document.createElement('button');
    b.className = 'alt' + (a.eliminada ? ' eliminada' : '')
      + (e.terminou && a.correta ? ' certa' : '');
    b.setAttribute('aria-pressed', a.selecionada ? 'true' : 'false');
    b.disabled = a.eliminada || e.terminou;

    const rot = document.createElement('span');
    rot.className = 'rotulo';
    // O rotulo e o que o cerebro devolveu, na ordem EMBARALHADA que ele
    // escolheu. Os ids a-e do JSON sao etiquetas de autoria, nunca posicao de
    // tela -- e quem embaralha e a SessaoQuestao, nao esta pagina.
    rot.textContent = a.id;
    b.appendChild(rot);

    const txt = document.createElement('span');
    txt.textContent = a.texto;
    b.appendChild(txt);

    b.addEventListener('click', () => aplicar(devlingo.selecionar(a.id)));
    caixa.appendChild(b);
  });
}

function pintarEscrita(e) {
  const campo = $('campo');
  const molde = $('molde');
  campo.hidden = !e.ehEscrita;
  campo.disabled = e.terminou;
  if (!e.ehEscrita) { molde.hidden = true; return; }

  /* O MOLDE APARECE ANTES DA PRIMEIRA TENTATIVA, e so quando ajuda.
     Quem decide se ajuda e `valeMostrarMolde`, no cerebro: numa palavra unica
     ele entregaria o tamanho de graca. */
  if (e.molde && !e.terminou) {
    molde.hidden = false;
    molde.textContent = 'formato esperado: ';
    const b = document.createElement('b');
    b.textContent = e.molde;
    molde.appendChild(b);
  } else {
    molde.hidden = true;
  }
}

function pintarRetorno(e) {
  const painel = $('retorno');
  const temRecado = e.recado || e.explicacao || e.dica;
  painel.hidden = !temRecado;
  if (!temRecado) return;

  painel.dataset.fase = e.fase;
  /* OS TITULOS SAO OS DO APP, palavra por palavra. "ERRADO" nao existe em
     lugar nenhum: a cor sinaliza que algo nao deu certo, e a escrita continua
     do lado do aluno. Ver tela_exercicio.dart. */
  const titulo = e.fase === 'acertou' ? 'CERTO'
    : e.fase === 'revelado' ? 'VAMOS JUNTOS'
    : e.dicaAberta && !e.recado ? 'DICA'
    : 'AINDA NÃO';
  $('retorno-titulo').textContent = titulo;

  const corpo = $('retorno-corpo');
  corpo.textContent = '';
  const linhas = [];
  if (e.explicacao) linhas.push(e.explicacao);
  else if (e.recado) linhas.push(e.recado);
  if (e.respostaRevelada) linhas.push('A resposta é ' + e.respostaRevelada + '.');
  if (e.dica && !e.terminou) linhas.push(e.dica);
  linhas.forEach((t, i) => {
    if (i) corpo.appendChild(document.createElement('br'));
    corpo.appendChild(document.createTextNode(t));
  });
}

function aplicar(json) {
  estado = JSON.parse(json);
  const e = estado;

  $('topico').textContent = e.topico;
  $('enunciado').textContent = e.enunciado;
  pintarCodigo(e.codigo);
  pintarAlternativas(e);
  pintarEscrita(e);
  pintarRetorno(e);

  $('btn-dica').disabled = e.terminou || e.dicaAberta;
  const principal = $('btn-verificar');
  principal.textContent = e.terminou ? 'Continuar' : 'Verificar';
  principal.disabled = !e.terminou && !e.ehEscrita && !e.alternativas.some((a) => a.selecionada);

  const feitas = indice + (e.terminou ? 1 : 0);
  const pct = Math.round((feitas / questoes.length) * 100);
  $('barra').style.width = pct + '%';
  $('barra').parentElement.setAttribute('aria-valuenow', String(pct));
  $('contador').textContent = (indice + 1) + ' de ' + questoes.length;
}

/* ------------------------------------------------------------------- acoes */

function abrir(i) {
  indice = i;
  $('campo').value = '';
  $('miolo').scrollTop = 0;
  aplicar(devlingo.abrir(JSON.stringify(questoes[i])));
}

$('btn-verificar').addEventListener('click', () => {
  if (estado && estado.terminou) {
    if (indice + 1 < questoes.length) abrir(indice + 1);
    return;
  }
  aplicar(estado && estado.ehEscrita
    ? devlingo.escrita($('campo').value)
    : devlingo.verificar());
});

$('btn-dica').addEventListener('click', () => aplicar(devlingo.dica()));

$('campo').addEventListener('keydown', (ev) => {
  if (ev.key === 'Enter') { ev.preventDefault(); $('btn-verificar').click(); }
});

/* A area de transferencia nao da retorno visivel nenhum; sem aviso a pessoa
   toca de novo achando que falhou. O visto volta sozinho em 2 s. */
$('copiar').addEventListener('click', async (ev) => {
  const texto = estado && estado.codigo ? estado.codigo.conteudo : '';
  try { await navigator.clipboard.writeText(texto); } catch { return; }
  const b = ev.currentTarget;
  b.textContent = 'copiado ✓';
  setTimeout(() => { b.textContent = 'copiar'; }, 2000);
});

/* -------------------------------------------------------------- a abertura */

(async () => {
  try {
    const licao = await (await fetch(LICAO)).json();
    questoes = licao.questions;
    /* `?q=N` abre uma questao especifica. Existe para a medicao poder apontar
       para uma questao COM bloco de codigo -- a primeira da licao nao tem, e
       medir o realce sem codigo na tela nao prova nada. Depois serve de link
       direto para uma questao. */
    const pedida = Number(new URLSearchParams(location.search).get('q'));
    abrir(Number.isInteger(pedida) && pedida >= 0 && pedida < questoes.length ? pedida : 0);
  } catch (e) {
    $('enunciado').textContent =
      'Não consegui abrir a lição (' + e.message + '). '
      + 'Esta página precisa ser servida por um servidor, não aberta como arquivo.';
  }
})();
