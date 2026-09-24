// A busca do Tr∅nikAt na borda: pergunta -> id da ficha (ou recusa).
//
// E a ENTRADA do porteiro (estudio/porteiro.py) e mais nada: sem modelo
// gerador, sem juiz. O texto e a voz de cada ficha ja estao no site, gravados
// por hospedagem/gerar_falas.py. Por isso este Worker nunca ve uma resposta --
// ele so conhece as perguntas-exemplo -- e nao tem o que vazar.
import FICHAS from "./fichas.json";
import { gerar, conferirSaida, gerarProgramacao, conferirProgramacao,
         gerarTutor, conferirTutor } from "./porteiro.js";

const MODELO = "@cf/google/embeddinggemma-300m";
// O id da placa de desvio. Vive em estudio/fichas.md como qualquer outra ficha
// -- e por isso compete na mesma busca, com a mesma nota -- mas o que acontece
// quando ela vence e outra coisa inteira.
const FICHA_PROGRAMACAO = "programacao";
// A TERCEIRA PLACA. Quando ela vence, o Worker nao reescreve ficha nenhuma:
// ele analisa o dossie de progresso que o CLIENTE mandou junto da pergunta.
//
// O Worker nao alcanca o SQLite do aparelho nem o Firestore, e dar credencial
// de banco a ele seria abrir uma porta grande para resolver uma leitura. Quem
// ja tem o dado e o app; ele manda o resumo.
const FICHA_PROGRESSO = "meu-progresso";
// O dossie e pequeno de proposito: contagens e nomes de licao, nada de
// identificador, e-mail ou resposta dada. E um teto existe porque tudo que
// entra num prompt e superficie de injecao.
const LIMITE_DO_DOSSIE = 900;

/* QUANDO O JUIZ REPROVA, A CULPA PODE SER DA FICHA -- e ate hoje ninguem
 * perguntava de quem era.
 *
 * O CLAUDE.md descreve a falha de desenho em uma frase: "o juiz confere se a
 * resposta e fiel a ficha, e ninguem confere se a ficha responde a pergunta".
 * Foi assim que um "Hello World" virou a ficha de licenca recitada.
 *
 * Mas o sinal existe e estava sendo jogado fora. Quando o juiz diz "ausente",
 * ele esta dizendo exatamente "esta resposta nao sai desta ficha". Falta
 * separar as duas causas possiveis, e a NOTA da busca separa:
 *
 *   medido em 21/09/2026, com o Worker no ar
 *   ---------------------------------------------------------------
 *   DevLingo na ficha certa .......... 0,988  0,956  0,941  0,994
 *   o mais baixo legitimo ............ 0,759  ("e de graca?" -> preco)
 *   ---------------------------------------------------------------
 *   programacao na ficha ERRADA ...... 0,736  ("api rest" -> como-roda)
 *                                      0,704  ("ponteiro" -> proximos-passos)
 *
 * Acima do limiar, a ficha responde e quem errou foi o modelo: recitar a ficha
 * gravada e o certo. Foi o que aconteceu com "quais linguagens tem?", que tirou
 * 0,994 e mesmo assim foi reprovada.
 *
 * Abaixo, a ficha nao tem nada a ver com a pergunta, e recitar e o pior dos
 * mundos -- o visitante pergunta sobre ponteiro e ouve falar dos proximos
 * passos do app. Ali vale uma SEGUNDA CHANCE pela faixa de programacao.
 *
 * A FOLGA E DE 23 MILESIMOS (0,736 contra 0,759), e e o numero a vigiar: e o
 * mesmo tipo de margem estreita que o CLAUDE.md ja manda vigiar no piso. Ao
 * mexer nas fichas, remeca esta linha.
 */
const CONFIANCA_FICHA = 0.75;
// A OUTRA placa de desvio, e ela aponta para a saida. Perguntas de fora --
// dolar, clima, futebol, receita -- passavam raspando pelo piso e caiam na
// ficha mais parecida por ASSUNTO: "qual a cotacao do dolar hoje?" sem acento
// tirava 0,705 e virava a ficha de PRECO do app.
//
// Subir o piso resolveria isso e custaria resposta legitima (49 de 53 passam
// em 0,70). Dar um ENDERECO ao que nao e daqui custa uma ficha: o classificador
// aprende "nenhuma das anteriores" como aprende qualquer outra coisa, por
// exemplo. Quando ela vence, o Worker responde como se nada tivesse passado.
const FICHA_FORA = "fora-de-escopo";
const LIMITE_DA_PERGUNTA = 300;
const ORIGENS = new Set([
  // O DOMINIO PROPRIO entrou em 24/09/2026. O antigo FICA: o GitHub Pages
  // redireciona `gustavoanderson.github.io/DevLingo` para ca, e durante a
  // transicao os dois respondem -- tirar o velho quebraria quem abrisse um
  // link ja divulgado.
  "https://devlingo.app.br",
  "https://www.devlingo.app.br",
  "https://gustavoanderson.github.io",
  "http://127.0.0.1:8000", "http://localhost:8000", "null",
]);

// O formato do texto muda a nota sem dar erro nenhum. A documentacao do
// Workers AI diz que prefixo nao e preciso. MEDIDO em 15/09/2026 com
// hospedagem/calibrar_borda.py, com as 52 legitimas do estudio:
//   gemma (com prefixo): 44/52 na ficha certa, igual ao PC, piso 0,70 vale
//   cru   (sem prefixo): 31/52
// Seguir a documentacao teria custado 13 respostas certas. O padrao e gemma;
// FORMATO existe so para remedir.
const FORMATOS = {
  gemma: t => `task: sentence similarity | query: ${t}`,
  cru: t => t,
};

// Vetores das perguntas-exemplo: calculados uma vez por instancia do Worker
// e reaproveitados enquanto ela viver.
let exemplos = null;

async function embed(env, textos) {
  const formatar = FORMATOS[env.FORMATO] || FORMATOS.gemma;

  // OS LOTES VAO JUNTOS, e nao um esperando o outro.
  //
  // Medido em 22/09/2026: a PRIMEIRA pergunta de cada instancia levava 5790 ms
  // contra 255-1050 ms das seguintes. A causa nao era o modelo pensando
  // devagar -- sao as 173 perguntas-exemplo, que cada instancia nova calcula
  // uma vez e guarda. Em lotes de 50 isso da 4 chamadas, e elas eram
  // SEQUENCIAIS: o tempo somava em vez de sobrepor.
  //
  // Os vetores sao exatamente os mesmos; muda so a ordem em que se espera por
  // eles. Nenhuma nota se move, o que importa num piso com 7 milesimos de
  // folga.
  //
  // Os lotes continuam de 50 -- o limite e do modelo, e nao tem a ver com isto.
  const lotes = [];
  for (let i = 0; i < textos.length; i += 50) lotes.push(textos.slice(i, i + 50));
  const partes = await Promise.all(
    lotes.map(lote => env.AI.run(MODELO, { text: lote.map(formatar) })));
  return partes.flatMap(r => r.data);
}

function cosseno(a, b) {
  let pa = 0, na = 0, nb = 0;
  for (let i = 0; i < a.length; i++) { pa += a[i] * b[i]; na += a[i] * a[i]; nb += b[i] * b[i]; }
  return pa / (Math.sqrt(na) * Math.sqrt(nb));
}

async function vetoresDosExemplos(env) {
  if (!exemplos) {
    const rotulos = FICHAS.fichas.flatMap(f => f.perguntas.map(() => f.id));
    const textos = FICHAS.fichas.flatMap(f => f.perguntas);
    exemplos = embed(env, textos).then(v => v.map((vetor, i) => [rotulos[i], vetor]))
      .catch(e => { exemplos = null; throw e; });   // falhou: a proxima tenta de novo
  }
  return exemplos;
}

function cabecalhos(request) {
  const h = { "Content-Type": "application/json; charset=utf-8" };
  const origem = request.headers.get("Origin");
  if (ORIGENS.has(origem)) { h["Access-Control-Allow-Origin"] = origem; h["Vary"] = "Origin"; }
  return h;
}

const json = (request, codigo, corpo) =>
  new Response(JSON.stringify(corpo), { status: codigo, headers: cabecalhos(request) });

export default {
  /* O AGENDADOR, e ele e SEGURO, nao a defesa principal.
   *
   * Quem resolve a partida a frio e o site, que manda aquecer quando o
   * visitante toca no campo -- ali o custo so existe quando alguem vai mesmo
   * perguntar. Este gatilho cobre o que aquilo nao cobre: o primeiro visitante
   * que digita rapido demais, e a propria Oracle, que RECICLA instancia
   * Always Free ociosa (esta anotado em hospedagem/ORACLE.md). Trafego de 15
   * em 15 minutos mantem a maquina com sinal de vida.
   *
   * 15 MINUTOS SAI DA MEDICAO, nao do gosto: e o maior intervalo em que eu
   * PROVEI que a voz nao esfria. Qualquer numero maior seria extrapolacao.
   */
  async scheduled(evento, env, ctx) {
    /* SAO DUAS COISAS QUE ESFRIAM, e em ritmos MUITO diferentes.
     *
     * A BUSCA (o embedding do Workers AI) esfria em MINUTOS. Medido em
     * 21/09/2026, com pausas crescentes antes de cada chamada:
     *
     *     0 s -> 247 ms       120 s -> 522 ms
     *    30 s -> 156 ms       180 s -> 598 ms
     *    60 s -> 189 ms       300 s -> 4388 ms
     *
     * E ela era TODA a variacao do tempo de resposta: a geracao de texto ficou
     * entre 323 e 716 ms nas doze medicoes, enquanto a busca foi de 196 ms a
     * 4923 ms. Eu passei a sessao inteira chamando isso de "o Worker pensando"
     * -- e o modelo que pensa nunca foi o lento.
     *
     * A VOZ, no Oracle, so esfria depois de HORAS (ver o comentario do
     * /aquecer). Aquece-la de 3 em 3 minutos seria castigar uma maquina de um
     * oitavo de OCPU a troco de nada.
     *
     * Dai os dois gatilhos. Custo da busca: ~10 tokens por aquecimento, 480 por
     * dia, menos de 30 neurons contra o teto gratuito de 10.000 -- conferido na
     * tabela de precos oficial antes de escrever.
     */
    const cron = evento && evento.cron;

    // A busca, sempre: e o gatilho de 3 minutos que domina.
    ctx.waitUntil(
      embed(env, ["aquecendo a busca"])
        .catch((e) => console.error("aquecimento da busca falhou:", e && (e.message || String(e)))),
    );

    // A voz, so no gatilho lento.
    if (cron === "*/15 * * * *" && env.VOZ_ORIGEM) {
      ctx.waitUntil(
        fetch(env.VOZ_ORIGEM.replace(/\/$/, "") + "/aquecer", {
          method: "POST",
          headers: { "Content-Type": "application/json", "X-Voz-Chave": env.VOZ_CHAVE || "" },
          body: "{}",
        }).catch((e) => console.error("aquecimento da voz falhou:", e && (e.message || String(e)))),
      );
    }
  },

  async fetch(request, env) {
    const url = new URL(request.url);
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: {
        ...cabecalhos(request),
        "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type",
      } });
    }
    if (request.method === "GET" && url.pathname === "/saude") {
      return json(request, 200, { ok: true, modo: "borda", formato: env.FORMATO || "gemma" });
    }
    // A PONTE ATE A VOZ.
    //
    // O navegador NAO busca em HTTP puro -- conteudo misto --, mas um Worker
    // busca. Entao a voz do Tr∅nikAt pode morar numa maquina sem dominio e sem
    // certificado, e quem fala HTTPS com o site e este Worker aqui, que ja
    // tinha CORS montado para o proprio /perguntar.
    //
    // Isso apagou tres coisas do roteiro de hospedagem: comprar dominio,
    // emitir certificado e instalar tunel. O preco e uma porta aberta na
    // maquina, defendida pela chave que vai no cabecalho abaixo.
    /* AQUECER A VOZ, e o motivo e medido.
     *
     * 21/09/2026: depois de ~3 dias parada, a primeira sintese custou 7,0 s
     * contra 1,6 s quente. O processo nao tinha reiniciado, e 15 minutos de
     * ociosidade NAO esfriam (0,72-0,76x o tempo real em cinco medicoes) --
     * entao o custo e de ociosidade longa.
     *
     * Isso bate exatamente no visitante que mais importa: o site e portfolio,
     * quem avalia abre o link, faz UMA pergunta e sai. Ele nunca chega quente.
     *
     * A maquina responde em /aquecer PASSANDO AO LARGO DO CACHE -- sem isso o
     * aquecimento devolveria audio guardado sem tocar no modelo, e falharia
     * justamente quando fosse preciso.
     */
    if (request.method === "POST" && url.pathname === "/aquecer") {
      if (!env.VOZ_ORIGEM) return json(request, 503, { erro: "voz nao configurada" });
      try {
        const r = await fetch(env.VOZ_ORIGEM.replace(/\/$/, "") + "/aquecer", {
          method: "POST",
          headers: { "Content-Type": "application/json", "X-Voz-Chave": env.VOZ_CHAVE || "" },
          body: "{}",
        });
        return json(request, r.status, await r.json());
      } catch (e) {
        console.error("aquecer falhou:", e && (e.message || String(e)));
        // Falhar aqui nao custa nada ao visitante: ele so nao ganha o
        // adiantamento. A pergunta dele segue pelo caminho de sempre.
        return json(request, 503, { erro: "voz indisponivel" });
      }
    }

    if (request.method === "POST" && url.pathname === "/falar") {
      if (!env.VOZ_ORIGEM) {
        // Ainda nao ha maquina no ar. O site ja trata isto como "sem voz" e
        // mostra so o texto: voz e conveniencia, nao requisito.
        return json(request, 503, { erro: "voz nao configurada" });
      }
      let texto;
      try { texto = (await request.json()).texto; }
      catch { return json(request, 400, { erro: "corpo precisa ser JSON com o campo 'texto'" }); }
      if (typeof texto !== "string" || !texto.trim()) {
        return json(request, 400, { erro: "texto vazio" });
      }
      // O limite vive nos DOIS lados de proposito. Sem ele aqui, este Worker
      // seria um relay aberto para gastar a CPU da maquina de la -- e ela tem
      // dois nucleos gratuitos.
      if (texto.length > 700) return json(request, 413, { erro: "texto grande demais" });
      try {
        const r = await fetch(env.VOZ_ORIGEM.replace(/\/$/, "") + "/falar", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "X-Voz-Chave": env.VOZ_CHAVE || "",
          },
          body: JSON.stringify({ texto: texto.trim() }),
        });
        return json(request, r.status, await r.json());
      } catch (e) {
        // O LOG NAO E OPCIONAL AQUI. Sem ele, este ramo devolve "voz
        // indisponivel" para causas completamente diferentes -- maquina
        // desligada, porta fora da lista permitida pela Cloudflare, chave
        // errada -- e nao ha como distinguir de fora. Custou uma rodada de
        // depuracao em 17/09/2026 justamente por estar mudo.
        // Aparece em `npx wrangler tail`, e nao na resposta ao visitante.
        console.error("falar falhou:", e && (e.message || String(e)));
        // Maquina desligada, reiniciando ou sem rede: o site fica mudo e
        // segue inteiro. Mesma degradacao que a geracao ja tinha.
        return json(request, 503, { erro: "voz indisponivel" });
      }
    }

    if (request.method !== "POST" || url.pathname !== "/perguntar") {
      return json(request, 404, { erro: "caminho desconhecido" });
    }

    let pergunta, dossie = "";
    try {
      const corpo = await request.json();
      pergunta = corpo.pergunta;
      // OPCIONAL, e continua opcional de proposito: o site publico nao tem
      // login, entao ele nunca manda isto. A placa de progresso sabe lidar com
      // a ausencia -- ela diz para entrar no app, em vez de fingir que sabe.
      if (typeof corpo.progresso === "string") {
        dossie = corpo.progresso.slice(0, LIMITE_DO_DOSSIE);
      }
    }
    catch { return json(request, 400, { erro: "corpo precisa ser JSON com o campo 'pergunta'" }); }
    if (typeof pergunta !== "string" || !pergunta.trim()) {
      return json(request, 400, { erro: "pergunta vazia" });
    }
    if (pergunta.length > LIMITE_DA_PERGUNTA) {
      return json(request, 413, { erro: `pergunta com mais de ${LIMITE_DA_PERGUNTA} caracteres` });
    }

    try {
      const t0 = Date.now();
      const base = await vetoresDosExemplos(env);
      const [vetor] = await embed(env, [pergunta.trim()]);
      let melhor = ["", -1];
      for (const [id, v] of base) { const n = cosseno(vetor, v); if (n > melhor[1]) melhor = [id, n]; }
      /* O PADRAO E DEV, E ISSO FOI INVERTIDO EM 17/09/2026.
       *
       * Antes: so respondia o que a busca RECONHECIA; abaixo do piso,
       * desconversava. O Gustavo perguntou o que sao dependencias (0,694),
       * herancas entre classes (0,700, e caiu na ficha TRILHAS) e o que sao
       * aninhamentos (0,681). Tres perguntas de programacao seguidas, e ele
       * resumiu: "ele nao e inteligente?".
       *
       * E a resposta e que o modelo e -- ele respondeu console.log e array
       * corretamente. Burro era o PORTEIRO na frente dele: uma busca por
       * semelhanca contra uma lista escrita a mao, que nao entende a pergunta,
       * so mede se ela parece com os exemplos. "Dependencias" nao parece com
       * "Hello World".
       *
       * E acrescentar exemplos era enxugar gelo: programacao tem milhares de
       * conceitos. Entao o padrao inverteu. Hoje:
       *
       *   melhor = fora-de-escopo  -> desconversa
       *   melhor >= piso           -> aquela ficha (inclui `programacao`)
       *   nada reconhecido         -> FAIXA DE PROGRAMACAO, e nao recusa
       *
       * O ultimo ramo e o que mudou. Quem decide no caso ambiguo passa a ser o
       * MODELO, que ao menos entende a pergunta -- e as instrucoes dele mandam
       * dizer que so fala de programacao e do DevLingo quando o assunto for
       * outro. O porteiro continua guardando o que importa: nada do que ele
       * diz SOBRE O APP sai de fora das fichas, porque ficha nenhuma chega
       * naquele caminho. */
      const foraDeEscopo = melhor[0] === FICHA_FORA;
      const alvo = foraDeEscopo ? null
        : (melhor[1] >= FICHAS.piso ? melhor[0] : FICHA_PROGRAMACAO);
      const passou = alvo !== null;
      const resposta = {
        ficha: alvo,
        caminho: passou ? (melhor[1] >= FICHAS.piso ? "ficha" : "dev-por-padrao")
          : "barrada-por-assunto",
        nota: Math.round(melhor[1] * 1000) / 1000,
        ms: Date.now() - t0,
      };

      // FASE 1: passando o piso, o Tr∅nikAt REESCREVE a ficha com a voz dele,
      // e o juiz confere antes de a fala sair. Falhar aqui NAO quebra nada: sem
      // o campo `texto`, o site toca o audio gravado, que e o que ele ja fazia.
      // Por isso a geracao inteira mora dentro de um try -- ela e melhoria, nao
      // requisito, e o teto de neurons do plano gratuito e duro.
      if (passou && env.GERAR !== "nao") {
        try {
          const ficha = FICHAS.fichas.find(f => f.id === alvo);
          // A FAIXA DE PROGRAMACAO desvia aqui, e so aqui. A ficha
          // `programacao` nao e uma resposta: e uma placa dizendo "esta
          // pergunta nao se responde com ficha nenhuma". Ver porteiro.js.
          // A FAIXA DO TUTOR so vale com dossie. Sem ele a placa cai no
          // caminho normal e recita a propria ficha, que diz para entrar na
          // conta -- degradacao igual a de todas as outras faixas.
          const ehTutor = alvo === FICHA_PROGRESSO && dossie !== "";
          const ehProgramacao = alvo === FICHA_PROGRAMACAO;
          // `reconhecida` diz se a BUSCA achou que isto e programacao, ou se
          // a pergunta caiu aqui por nao ter casado com nada. Quando a peneira
          // ja fez o trabalho, o modelo nao precisa da frase de recusa -- e ela
          // era justamente o que fazia ele recusar nomes que nao conhece.
          const reconhecida = melhor[0] === FICHA_PROGRAMACAO
            && melhor[1] >= FICHAS.piso;
          const gerado = ehTutor
            ? await gerarTutor(env, pergunta.trim(), dossie)
            : ehProgramacao
              ? await gerarProgramacao(env, pergunta.trim(), reconhecida)
              : await gerar(env, ficha, pergunta.trim());
          // Sem ficha nao ha o que o juiz confira: ele responde "esta frase
          // esta na ficha?", e aqui a pergunta nao existe. Ficam as defesas
          // contra injecao, que nunca dependeram de ficha.
          // O juiz NAO serve ao tutor: ele pergunta "esta frase esta na
          // ficha?", e aqui nao ha ficha. O que se confere e outra coisa --
          // que nenhum NUMERO da resposta tenha sido inventado.
          const { motivos } = ehTutor
            ? conferirTutor(gerado, dossie)
            : ehProgramacao
              ? conferirProgramacao(gerado)
              : await conferirSaida(env, gerado, ficha);
          if (motivos.length === 0) {
            resposta.texto = gerado;
            resposta.caminho = "gerada";
          } else if (!ehProgramacao && !ehTutor && melhor[1] < CONFIANCA_FICHA) {
            // A FICHA E QUE NAO SERVIA. Segunda chance pela faixa de
            // programacao, que nao depende de ficha nenhuma. Custa uma chamada
            // a mais, e so acontece aqui -- reprovacao com nota baixa e rara.
            // Segunda chance por ficha fraca: aqui a busca NAO reconheceu, e
            // a frase de recusa continua sendo a peneira.
            const segundo = await gerarProgramacao(env, pergunta.trim(), false);
            const r2 = conferirProgramacao(segundo);
            resposta.motivos = motivos;
            resposta.gerado = gerado;
            if (r2.motivos.length === 0) {
              resposta.texto = segundo;
              resposta.caminho = "dev-apos-ficha-fraca";
            } else {
              // As duas portas fecharam: recita a ficha, que ao menos e
              // verdadeira sobre o DevLingo.
              resposta.caminho = "ficha-literal";
              resposta.motivos = motivos.concat(r2.motivos.map(m => "2a: " + m));
            }
          } else {
            // Reprovada com nota ALTA: a ficha responde a pergunta e quem
            // errou foi o modelo. Recitar a ficha gravada e o certo.
            resposta.caminho = "ficha-literal";
            resposta.motivos = motivos;
            // O que o modelo escreveu, MESMO descartado: sem isto, depurar uma
            // recusa exige adivinhar o que ele disse. Espelha o campo `gerado`
            // do estudio/porteiro.py.
            resposta.gerado = gerado;
          }
          resposta.ms_total = Date.now() - t0;
        } catch (e) {
          resposta.caminho = "ficha-literal";
          resposta.motivos = [`geracao indisponivel: ${e.message || e}`];
        }
      }

      return json(request, 200, resposta);
    } catch (e) {
      // Sem a busca, o site cai para as respostas prontas: falha aqui nao pode
      // virar tela quebrada la.
      return json(request, 503, { erro: "busca indisponivel" });
    }
  },
};
