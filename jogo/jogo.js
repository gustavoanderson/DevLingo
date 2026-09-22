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

/* As trilhas vem do cerebro, montadas a partir do indice CRU que
   `tools/construir_jogo.py` gera. Ordem, nomes, descricoes e a regra de
   esconder a licao 00 sao do app -- esta pagina so as recebe prontas. */
let trilhas = [];

let trilhaAtual = null;
let licaoAtual = null;
let metaDaLicao = null;       // language, level, lessonId, lessonTitle

/* A CONTA E O PROGRESSO.
   `partidas` e o historico da pessoa, como veio da nuvem mais o que foi jogado
   agora. `respondidas` e a contagem por licao, e quem conta e o CEREBRO -- a
   mesma conta que o app faz, testada contra ela em progresso_test.dart. */
let usuario = null;
let partidas = [];
let respondidas = {};
let progressoFalhou = false;
let gravouEsta = false;       // a partida desta questao ja foi registrada?
const pendentes = [];         // partidas que ainda nao chegaram a nuvem
let enviando = false;
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

  // A partida e gravada QUANDO A QUESTAO TERMINA, e nao no Continuar -- a mesma
  // regra do app. Se a pessoa fechar a aba entre uma coisa e outra, o que ja
  // foi respondido nao se perde.
  if (e.terminou && !gravouEsta) {
    gravouEsta = true;
    registrar();
  }
}

/* Registra a partida desta questao. O FORMATO vem do cerebro -- `partida.dart`,
   o mesmo que o app grava --, e esta pagina nao sabe o nome de campo nenhum.
   Isso e o que garante o cross-play: o celular enfia o documento da nuvem
   DIRETO no SQLite, e um campo com outro nome quebraria la, em silencio. */
function registrar() {
  if (!usuario || !metaDaLicao) return;
  const evento = JSON.parse(devlingo.evento(usuario.uid, JSON.stringify(metaDaLicao), Date.now()));
  if (!evento) return;
  partidas.push(evento);
  respondidas = JSON.parse(devlingo.respondidas(JSON.stringify(partidas)));
  pendentes.push(evento);
  enviarPendentes();
}

/* Envia o que falta, UM de cada vez e em ordem. Se a rede cair, para e tenta
   de novo na proxima partida -- o id e derivado do conteudo, entao reenviar e
   inofensivo.
   A trava `enviando` existe porque duas chamadas simultaneas tirariam da fila
   a mesma partida duas vezes, e a segunda retiraria uma que ainda nao subiu. */
async function enviarPendentes() {
  if (enviando) return;
  enviando = true;
  try {
    while (pendentes.length) {
      await Nuvem.gravarPartida(pendentes[0]);
      pendentes.shift();
    }
  } catch (err) {
    console.error('partida nao subiu, tento de novo na proxima:', err);
  } finally {
    enviando = false;
  }
}

/* ------------------------------------------------------------------- acoes */

function abrir(i) {
  indice = i;
  gravouEsta = false;
  $('campo').value = '';
  $('miolo').scrollTop = 0;
  aplicar(devlingo.abrir(JSON.stringify(questoes[i])));
}

$('btn-verificar').addEventListener('click', () => {
  if (estado && estado.terminou) {
    // Fim da licao volta para a trilha: e la que se escolhe a proxima, e e la
    // que o progresso vai aparecer quando o login chegar.
    if (indice + 1 < questoes.length) abrir(indice + 1);
    else location.hash = '#/' + trilhaAtual.chave;
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

/* ---------------------------------------------------------------- vistas */

function mostrar(id) {
  $('carregando').hidden = true;
  for (const v of document.querySelectorAll('.vista')) v.hidden = v.id !== id;
  window.scrollTo(0, 0);
}

function cartao(href, titulo, sub, lado, extraTopo) {
  const a = document.createElement('a');
  a.className = 'cartao';
  a.href = href;
  const t = document.createElement('span');
  t.className = 'titulo-cartao';
  if (extraTopo) {
    const n = document.createElement('span');
    n.className = 'num-licao';
    n.textContent = extraTopo;
    t.appendChild(n);
    t.appendChild(document.createElement('br'));
  }
  t.appendChild(document.createTextNode(titulo));
  a.appendChild(t);
  if (lado) {
    const s2 = document.createElement('span');
    s2.className = 'lado';
    s2.textContent = lado;
    a.appendChild(s2);
  }
  if (sub) {
    const d = document.createElement('span');
    d.className = 'sub';
    d.textContent = sub;
    a.appendChild(d);
  }
  return a;
}

/* Acrescenta ao cartao a linha de metadados e a barra -- o que o
   `_CartaoDaTrilha` do app desenha e a web nao desenhava.

   A COR DA FAIXA E O ESTADO, e as classes saem daqui em vez de do CSS porque
   so quem tem os numeros sabe qual e. */
function comProgresso(a, meta, feitas, total) {
  const m = document.createElement('span');
  m.className = 'meta-trilha';
  m.textContent = meta;
  a.appendChild(m);

  if (feitas > 0) a.classList.add(total > 0 && feitas >= total ? 'concluida' : 'comecada');

  const barra = document.createElement('span');
  barra.className = 'progresso-trilha';
  const i = document.createElement('i');
  i.style.width = (total > 0 ? Math.round((feitas / total) * 100) : 0) + '%';
  barra.appendChild(i);
  a.appendChild(barra);
  return a;
}

function pintarEscolha() {
  const lista = $('lista-trilhas');
  lista.textContent = '';
  for (const t of trilhas) {
    const feitas = t.licoes.reduce((n, l) => n + (respondidas[l.id] || 0), 0);
    const total = t.licoes.reduce((n, l) => n + l.questoes, 0);
    const n = t.licoes.length;

    // UMA REGRA SO, e ela e a do app.
    //
    // Antes esta linha alternava entre "2 de 50" e "5 licoes" conforme houvesse
    // progresso -- duas metricas na mesma coluna, e foi isso que o Gustavo leu
    // como desorganizado. O `_CartaoDaTrilha` sempre escreve a linha inteira.
    //
    // Eu tinha escrito aqui que "0 de 50" quebraria a regra do convite. Ela
    // vale na tela de ESTATISTICAS, onde o zero e o unico retorno e se le como
    // resultado ruim. Aqui a barra vazia ja diz "nao comecou" sem cobrar nada,
    // e o numero passa a ser o que e: quanto falta.
    const meta = n + (n === 1 ? ' lição · ' : ' lições · ') +
      feitas + ' de ' + total + ' questões';
    lista.appendChild(comProgresso(
      cartao('#/' + t.chave, t.nome, t.descricao, null), meta, feitas, total));
  }
  document.title = 'DevLingo';
  mostrar('vista-escolha');
}

function pintarTrilha(t) {
  $('nome-trilha').textContent = t.nome;
  $('descricao-trilha').textContent = t.descricao;
  const lista = $('lista-licoes');
  lista.textContent = '';
  for (const l of t.licoes) {
    const n = respondidas[l.id] || 0;
    // Sem progresso carregado, nao se afirma zero: "0 de 10" seria progresso
    // perdido para quem olha. O CLAUDE.md registra o susto que isso ja deu
    // no app, com o Gustavo cogitando refazer licoes que ja tinha feito.
    const lado = progressoFalhou ? l.questoes + ' questões' : n + ' de ' + l.questoes;
    const c = cartao('#/' + t.chave + '/' + l.id, l.titulo, null, lado,
      'Lição ' + String(l.numero).padStart(2, '0') + ' · ' + l.nivel);
    // Licao concluida = todas as questoes respondidas, independente de quantas
    // tentativas cada uma custou. A mesma regra do app.
    if (!progressoFalhou && n >= l.questoes) c.classList.add('concluida');
    lista.appendChild(c);
  }
  document.title = t.nome + ' — DevLingo';
  mostrar('vista-trilha');
}

async function abrirLicao(t, l, q) {
  // A mesma licao ja aberta nao e rebaixada: trocar so a questao nao pode
  // perder o que se jogou nela.
  if (licaoAtual !== l) {
    const dados = await (await fetch(l.arquivo)).json();
    questoes = dados.questions;
    licaoAtual = l;
    metaDaLicao = { language: dados.language, level: dados.level,
      lessonId: dados.lessonId, lessonTitle: dados.lessonTitle };
  }
  $('sair').href = '#/' + t.chave;
  document.title = l.titulo + ' — DevLingo';
  mostrar('vista-exercicio');
  const n = Number(q);
  abrir(Number.isInteger(n) && n >= 0 && n < questoes.length ? n : 0);
}

/* O ROTEADOR, pelo `#` do endereco:

     #/                         escolha de trilha
     #/python                   a trilha
     #/python/python-beg-03     a licao, da primeira questao
     #/python/python-beg-03/4   a licao, direto na questao 4

   Pelo `#` e nao por caminho de verdade porque o site e estatico: `/python`
   pediria ao servidor um arquivo que nao existe. E o botao voltar do
   navegador passa a funcionar de graca. */
async function rotear() {
  // Sem conta, nenhuma vista abre: e a decisao do Gustavo, "exige login,
  // exatamente como no app".
  if (!usuario) return mostrar('vista-entrada');
  const [chave, idLicao, q] = location.hash.replace(/^#\/?/, '').split('/');
  const t = trilhas.find((x) => x.chave === chave);
  if (!t) return pintarEscolha();
  trilhaAtual = t;
  const l = t.licoes.find((x) => x.id === idLicao);
  if (!l) return pintarTrilha(t);
  try {
    await abrirLicao(t, l, q);
  } catch (e) {
    falhar('Não consegui abrir a lição (' + e.message + ').');
  }
}

function falhar(texto) {
  for (const v of document.querySelectorAll('.vista')) v.hidden = true;
  $('carregando').hidden = true;
  const f = $('falha');
  f.hidden = false;
  f.textContent = texto;
}

/* ---------------------------------------------------------------- entrada */

/* Os textos seguem os do app, com UMA diferenca deliberada: o app promete
   "depois o DevLingo funciona offline", e no navegador isso seria mentira --
   o Gustavo decidiu em 21/09 que ele nao funciona. A validacao e as mensagens
   de erro NAO estao aqui: vem do cerebro, de `autenticacao.dart`. */
const MODOS = {
  entrar: { titulo: 'Entrar', botao: 'Entrar',
    explica: 'Sua conta guarda o progresso, e ele é o mesmo aqui e no app.' },
  criar: { titulo: 'Criar conta', botao: 'Criar conta',
    explica: 'Só e-mail e senha. O e-mail serve para você recuperar o acesso se esquecer a senha.' },
  recuperar: { titulo: 'Esqueci minha senha', botao: 'Enviar link',
    explica: 'Informe o e-mail da conta e enviamos um link para criar uma senha nova.' },
};
let modo = 'entrar';

function trocarModo(m) {
  modo = m;
  $('titulo-entrada').textContent = MODOS[m].titulo;
  $('explica-entrada').textContent = MODOS[m].explica;
  $('btn-entrar').textContent = MODOS[m].botao;
  $('bloco-senha').hidden = m === 'recuperar';
  $('senha').autocomplete = m === 'criar' ? 'new-password' : 'current-password';
  $('ir-criar').hidden = m === 'criar';
  $('ir-entrar').hidden = m === 'entrar';
  $('ir-recuperar').hidden = m === 'recuperar';
  $('erro-entrada').hidden = true;
}

function avisar(id, texto) {
  const el = $(id);
  el.textContent = texto;
  el.hidden = !texto;
}

function prepararEntrada() {
  $('dica-senha').textContent = 'Mínimo de ' + devlingo.minimoDaSenha + ' caracteres.';
  trocarModo('entrar');
  for (const [id, m] of [['ir-criar', 'criar'], ['ir-entrar', 'entrar'], ['ir-recuperar', 'recuperar']]) {
    $(id).addEventListener('click', (ev) => { ev.preventDefault(); trocarModo(m); });
  }
  $('form-entrada').addEventListener('submit', async (ev) => {
    ev.preventDefault();
    const email = $('email').value.trim();
    const senha = $('senha').value;
    avisar('aviso-entrada', '');

    // O que da para checar sem rede e checado sem rede, e a REGRA e a do app.
    const problema = devlingo.validar(modo, email, senha);
    if (problema) return avisar('erro-entrada', problema);
    avisar('erro-entrada', '');

    const botao = $('btn-entrar');
    botao.disabled = true;
    try {
      if (modo === 'entrar') await Nuvem.entrar(email, senha);
      else if (modo === 'criar') await Nuvem.cadastrar(email, senha);
      else {
        await Nuvem.recuperarSenha(email);
        trocarModo('entrar');
        avisar('aviso-entrada', AVISO_RECUPERACAO);
      }
    } catch (err) {
      const codigo = (err && err.code) || '';
      // A RECUPERACAO NUNCA REVELA SE A CONTA EXISTE. Responder "nao achamos
      // esse e-mail" entregaria a lista de quem tem conta. O app conta com a
      // protecao contra enumeracao do Firebase; aqui a regra vale mesmo se ela
      // estiver desligada no console.
      if (modo === 'recuperar' && /user-not-found/.test(codigo)) {
        trocarModo('entrar');
        avisar('aviso-entrada', AVISO_RECUPERACAO);
      } else {
        avisar('erro-entrada', devlingo.mensagem(codigo));
      }
    } finally {
      botao.disabled = false;
    }
  });

  $('sair-conta').addEventListener('click', async (ev) => {
    ev.preventDefault();
    await Nuvem.sair();
    location.hash = '#/';
  });
}

const AVISO_RECUPERACAO =
  'Se houver conta com esse e-mail, o link de nova senha já está a caminho. '
  + 'Confira também o spam.';

async function carregarProgresso() {
  try {
    partidas = await Nuvem.baixarPartidas(usuario.uid);
    respondidas = JSON.parse(devlingo.respondidas(JSON.stringify(partidas)));
    progressoFalhou = false;
  } catch (err) {
    console.error('nao consegui baixar o progresso:', err);
    partidas = [];
    respondidas = {};
    progressoFalhou = true;
  }
}

/* -------------------------------------------------------------- a abertura */

(async () => {
  try {
    const indiceCru = await (await fetch('conteudo.json')).text();
    trilhas = JSON.parse(devlingo.trilhas(indiceCru));
  } catch (e) {
    return falhar('Não consegui carregar o conteúdo (' + e.message + '). '
      + 'Rode `python tools/construir_jogo.py` e sirva a pasta do repositório '
      + 'por um servidor -- aberta como arquivo, a página não lê nada.');
  }
  prepararEntrada();
  window.addEventListener('hashchange', rotear);
  try {
    await Nuvem.aoMudarUsuario(async (u) => {
      usuario = u;
      if (!u) {
        partidas = [];
        respondidas = {};
        return mostrar('vista-entrada');
      }
      $('quem').textContent = u.email;
      $('carregando').hidden = false;
      await carregarProgresso();
      rotear();
    });
  } catch (e) {
    falhar('Não consegui falar com o servidor de contas (' + e.message + ').');
  }
})();
