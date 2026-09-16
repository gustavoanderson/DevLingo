// A busca do Tr∅nikAt na borda: pergunta -> id da ficha (ou recusa).
//
// E a ENTRADA do porteiro (estudio/porteiro.py) e mais nada: sem modelo
// gerador, sem juiz. O texto e a voz de cada ficha ja estao no site, gravados
// por hospedagem/gerar_falas.py. Por isso este Worker nunca ve uma resposta --
// ele so conhece as perguntas-exemplo -- e nao tem o que vazar.
import FICHAS from "./fichas.json";
import { gerar, conferirSaida } from "./porteiro.js";

const MODELO = "@cf/google/embeddinggemma-300m";
const LIMITE_DA_PERGUNTA = 300;
const ORIGENS = new Set([
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
  const saida = [];
  for (let i = 0; i < textos.length; i += 50) {          // lotes pequenos
    const r = await env.AI.run(MODELO, { text: textos.slice(i, i + 50).map(formatar) });
    saida.push(...r.data);
  }
  return saida;
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
    if (request.method !== "POST" || url.pathname !== "/perguntar") {
      return json(request, 404, { erro: "caminho desconhecido" });
    }

    let pergunta;
    try { pergunta = (await request.json()).pergunta; }
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
      const passou = melhor[1] >= FICHAS.piso;
      const resposta = {
        ficha: passou ? melhor[0] : null,
        caminho: passou ? "ficha" : "barrada-na-entrada",
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
          const ficha = FICHAS.fichas.find(f => f.id === melhor[0]);
          const gerado = await gerar(env, ficha, pergunta.trim());
          const { motivos } = await conferirSaida(env, gerado, ficha);
          if (motivos.length === 0) {
            resposta.texto = gerado;
            resposta.caminho = "gerada";
          } else {
            // Reprovada: cai para a ficha literal, que tem audio gravado.
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
