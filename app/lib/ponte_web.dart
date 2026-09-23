/// A PONTE ENTRE O CEREBRO DO JOGO E O NAVEGADOR.
///
/// Este arquivo existe por causa de uma pergunta do Gustavo em 21/09/2026:
/// *"nao tem como fazer uma interface mais leve mas que mantenha a mesma
/// personalidade do app?"*
///
/// A resposta obvia seria compilar o app Flutter para web. Medido: o navegador
/// baixaria de 1,5 a 2,5 MB de motor grafico ANTES de desenhar o primeiro
/// pixel, e o texto deixaria de ser texto (nao seleciona, leitor de tela nao
/// le, busca nao indexa). Para alguem que ja teve o Chrome travado quatro
/// vezes por este projeto, isso e o risco principal.
///
/// A outra saida obvia seria escrever tudo em JavaScript. Mas isso duplicaria
/// o CEREBRO do jogo -- a correcao de resposta, as regras de tentativa, o
/// realce de sintaxe. Duas implementacoes da mesma regra divergem em silencio,
/// e este repositorio tem a cicatriz: o `normalize()` existe em Dart e em
/// Python, e existe um arquivo de casos compartilhado so para impedir que eles
/// se separem.
///
/// ESTE ARQUIVO E A TERCEIRA SAIDA: a interface e escrita a mao em HTML e CSS,
/// e o cerebro vem daqui, compilado. Medido em 21/09/2026: **44 KB** de
/// JavaScript para normalize, tokenizar, SessaoQuestao e os modelos inteiros.
///
/// E ela so e possivel por causa de uma disciplina que veio de outro lugar:
/// `normalize.dart`, `sessao_questao.dart` e `realce.dart` ficaram livres de
/// Flutter para serem testaveis sem montar tela. Isso os tornou PORTAVEIS sem
/// ninguem ter planejado.
///
/// COMO GERAR:
///     cd app && dart compile js lib/ponte_web.dart -o ../jogo/cerebro.js -O2
///
/// O `cerebro.js` NAO e versionado, e isso e deliberado: `dart compile js` nao
/// garante saida byte a byte entre versoes do SDK, entao a regra de "arquivo
/// gerado tem de bater com o gerador" seria fragil aqui -- a mesma razao pela
/// qual `gerar_falas.py` compara impressao em vez de bytes do WAV. Quem gera e
/// o fluxo de publicacao.
///
/// TUDO ATRAVESSA A PONTE COMO JSON, de proposito. Tipar interop a fundo
/// amarraria os modelos do jogo a uma segunda declaracao, em JS -- que e
/// exatamente a duplicacao que este arquivo existe para evitar.
library;

import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'answer/normalize.dart';
import 'answer/sessao_questao.dart';
import 'auth/autenticacao.dart';
import 'data/dossie.dart';
import 'data/partida.dart';
import 'models/lesson.dart';
import 'models/question.dart';
import 'ui/realce.dart';

/// A questao em jogo. Uma por vez: a tela do exercicio mostra uma.
SessaoQuestao? _sessao;

/// O estado que a interface precisa para desenhar, e NADA alem disso.
///
/// A tela nao recebe a `SessaoQuestao`: recebe o retrato dela. Assim a regra de
/// quando revelar, quando eliminar e quando abrir a dica continua vivendo num
/// lugar so, coberta pelos testes que ja existem.
String _estado() {
  final s = _sessao;
  if (s == null) return jsonEncode({'erro': 'nenhuma questao aberta'});
  final q = s.questao;
  return jsonEncode({
    'id': q.id,
    'topico': q.topic,
    'enunciado': q.prompt,
    'tipo': q.answerType.name,
    'ehEscrita': s.ehEscrita,
    'codigo': q.code == null
        ? null
        : {'linguagem': q.code!.language, 'conteudo': q.code!.content},
    'alternativas': s.alternativas
        .map((o) => {
              'id': o.id,
              'texto': o.text,
              'eliminada': s.estaEliminada(o),
              'selecionada': s.selecionada?.id == o.id,
              // O `why` so viaja depois de a questao terminar. Antes disso ele
              // entregaria o gabarito a quem abrisse as ferramentas do
              // navegador -- o equivalente, aqui, a mostra-lo na tela.
              'porque': s.terminou ? o.why : null,
              'correta': s.terminou ? o.correct : null,
            })
        .toList(),
    'fase': s.fase.name,
    'terminou': s.terminou,
    'tentativas': s.tentativas,
    'recado': s.recado,
    'dicaAberta': s.dicaAberta,
    'dica': s.dicaAberta ? q.hint : null,
    'explicacao': s.explicacao,
    'respostaRevelada': s.respostaRevelada,
    'esqueleto': s.esqueleto,
    // O molde do formato aparece ANTES da primeira tentativa, e so quando
    // ajuda: ver `valeMostrarMolde`. Numa palavra unica ele entregaria o
    // tamanho de graca.
    'molde': (q.accepted != null && q.accepted!.isNotEmpty &&
            valeMostrarMolde(q.accepted!.first))
        ? esqueletoDe(q.accepted!.first)
        : null,
  });
}

String _abrir(String questaoJson) {
  final mapa = jsonDecode(questaoJson) as Map<String, dynamic>;
  _sessao = SessaoQuestao(Question.fromJson(mapa));
  return _estado();
}

String _selecionar(String idOpcao) {
  final s = _sessao;
  if (s != null) {
    for (final o in s.alternativas) {
      if (o.id == idOpcao) {
        s.selecionar(o);
        break;
      }
    }
  }
  return _estado();
}

String _verificar() {
  _sessao?.verificar();
  return _estado();
}

String _verificarEscrita(String texto) {
  _sessao?.verificarEscrita(texto);
  return _estado();
}

String _dica() {
  _sessao?.abrirDica();
  return _estado();
}

/// O realce de sintaxe, linha a linha -- que e como o bloco desenha.
///
/// A invariante e a mesma do app e e o que o teste cobre: a concatenacao dos
/// trechos tem de ser identica a linha original. Realce que come um caractere e
/// pior que nenhum, porque o codigo passa a mentir sobre si mesmo.
String _tokenizar(String linha, String linguagem) => jsonEncode(
    tokenizar(linha, linguagem)
        .map((t) => {'texto': t.texto, 'tipo': t.tipo.name})
        .toList());

/// AS TRILHAS, montadas com as regras do app -- nenhuma delas mora no JS.
///
/// O navegador nao consegue listar pastas, entao `tools/construir_jogo.py`
/// gera um indice CRU: uma linha por arquivo de licao, com o que esta escrito
/// nele e nada mais. Tudo que e REGRA acontece aqui:
///
///   - a ordem das trilhas e `ordemDasTrilhas` -- Java antes de Selenium,
///     Frameworks depois de JavaScript, pela dependencia entre elas
///   - o nome de tela e a descricao vem de `nomeBonito` e `descricaoDaLinguagem`
///   - a licao 00 e a de referencia do formato, e NINGUEM a joga
///   - o rotulo do nivel e `Level.rotulo`
///
/// O `Lesson` construido sem questoes existe so para reusar `numero` e
/// `ehLicaoDeReferencia` do modelo, em vez de reescrever "a licao cujo id
/// termina em 00" uma segunda vez.
String _trilhas(String indiceJson) {
  final porTrilha = <String, List<Lesson>>{};
  final arquivos = <String, String>{};
  final contagem = <String, int>{};
  for (final item in jsonDecode(indiceJson) as List<dynamic>) {
    final m = item as Map<String, dynamic>;
    final licao = Lesson(
      schemaVersion: 1,
      language: m['language'] as String,
      level: Level.fromJson(m['level'] as String),
      lessonId: m['lessonId'] as String,
      lessonTitle: m['lessonTitle'] as String,
      questions: const [],
    );
    if (licao.ehLicaoDeReferencia) continue;
    porTrilha.putIfAbsent(licao.language, () => []).add(licao);
    arquivos[licao.lessonId] = m['arquivo'] as String;
    contagem[licao.lessonId] = m['questoes'] as int;
  }

  final chaves = porTrilha.keys.toList()
    ..sort((a, b) => posicaoDaTrilha(a).compareTo(posicaoDaTrilha(b)));

  return jsonEncode([
    for (final chave in chaves)
      {
        'chave': chave,
        'nome': nomeBonito(chave),
        'descricao': descricaoDaLinguagem[chave] ?? '',
        'licoes': [
          for (final l in porTrilha[chave]!
            ..sort((a, b) => a.level.index != b.level.index
                ? a.level.index.compareTo(b.level.index)
                : a.numero.compareTo(b.numero)))
            {
              'id': l.lessonId,
              'arquivo': arquivos[l.lessonId],
              'titulo': l.lessonTitle,
              'numero': l.numero,
              'nivel': l.level.rotulo,
              'questoes': contagem[l.lessonId],
            },
        ],
      },
  ]);
}

/// A PARTIDA desta questao, pronta para ir ao Firestore.
///
/// O formato vem de `partida.dart` -- o MESMO que o app Android grava e le.
/// Nao ha formato de partida escrito em JavaScript em lugar nenhum, e e isso
/// que garante o cross-play: o celular enfia o documento da nuvem DIRETO no
/// SQLite, e um campo com outro nome ou outro tipo quebraria a sincronizacao
/// no aparelho, em silencio. Ver o teste "o contrato da partida com o
/// navegador" em progresso_test.dart.
///
/// Devolve `null` se a questao ainda nao terminou.
String _evento(String uid, String licaoJson, int instante) {
  final s = _sessao;
  if (s == null) return 'null';
  final m = jsonDecode(licaoJson) as Map<String, dynamic>;
  final licao = Lesson(
    schemaVersion: 1,
    language: m['language'] as String,
    level: Level.fromJson(m['level'] as String),
    lessonId: m['lessonId'] as String,
    lessonTitle: (m['lessonTitle'] ?? '') as String,
    questions: const [],
  );
  return jsonEncode(eventoDaPartida(
      uid: uid, licao: licao, questao: s.questao, sessao: s,
      instante: instante));
}

/// Quantas questoes distintas foram respondidas em cada licao -- a mesma conta
/// que o app faz, testada contra ela.
String _respondidas(String eventosJson) => jsonEncode(
    respondidasPorLicaoNoHistorico((jsonDecode(eventosJson) as List<dynamic>)
        .cast<Map<String, Object?>>()));

/// O DOSSIE de progresso, para o Tr∅nikAt dar um conselho.
///
/// A MESMA funcao que o app usa -- e nao ha versao escrita em JavaScript em
/// lugar nenhum. O navegador ja tem as duas pecas nas maos: `trilhas` saiu de
/// [_trilhas], e `respondidas` de [_respondidas].
///
/// Devolve texto vazio para quem nao respondeu nada, e ai o cliente nao manda
/// o campo: a placa `meu-progresso` responde mandando entrar na conta.
String _dossie(String trilhasJson, String respondidasJson) => montarDossie(
      (jsonDecode(trilhasJson) as List<dynamic>).cast<Map<String, Object?>>(),
      (jsonDecode(respondidasJson) as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v as int)),
    );

/// A validacao da tela de entrada -- a MESMA do app.
///
/// Recuperar senha so exige e-mail; entrar e criar conta exigem os dois, com o
/// minimo de [minimoDaSenha]. O que da para checar sem rede e checado sem
/// rede: e-mail malformado nem chega a chamar o Firebase.
///
/// Devolve a mensagem em portugues, ou texto vazio se estiver tudo certo.
String _validar(String modo, String email, String senha) {
  final falha = modo == 'recuperar'
      ? validarEmail(email.trim())
      : validarCredenciais(email.trim(), senha);
  return falha == null ? '' : ErroDeAutenticacao(falha).mensagem;
}

/// A mensagem para um codigo de erro do Firebase, com o prefixo `auth/` do SDK
/// de JavaScript ja tratado em [falhaDoCodigo].
///
/// UMA mensagem muda no navegador, e por um motivo de verdade: a do app diz
/// *"precisa de internet so para entrar; depois disso ele funciona offline"*.
/// No navegador isso seria mentira -- o Gustavo decidiu em 21/09/2026 que ele
/// NAO funciona offline. Prometer o que nao existe e pior que nao prometer.
String _mensagem(String codigo) {
  final falha = falhaDoCodigo(codigo);
  if (falha == FalhaDeAutenticacao.semRede) {
    return 'Sem conexão agora. O DevLingo no navegador precisa de internet '
        'para entrar e para guardar o seu progresso.';
  }
  return ErroDeAutenticacao(falha).mensagem;
}

void main() {
  // Uma unica propriedade global, `devlingo`, com as funcoes dentro. Espalhar
  // nomes soltos no `window` e como o site poluiria o espaco de qualquer outro
  // script que um dia divida a pagina.
  final api = JSObject();
  api['abrir'] = ((JSString j) => _abrir(j.toDart).toJS).toJS;
  api['selecionar'] = ((JSString id) => _selecionar(id.toDart).toJS).toJS;
  api['verificar'] = ((() => _verificar().toJS).toJS);
  api['escrita'] = ((JSString t) => _verificarEscrita(t.toDart).toJS).toJS;
  api['dica'] = ((() => _dica().toJS).toJS);
  api['estado'] = ((() => _estado().toJS).toJS);
  api['tokenizar'] =
      ((JSString l, JSString g) => _tokenizar(l.toDart, g.toDart).toJS).toJS;
  api['trilhas'] = ((JSString j) => _trilhas(j.toDart).toJS).toJS;
  api['validar'] = ((JSString modo, JSString email, JSString senha) =>
      _validar(modo.toDart, email.toDart, senha.toDart).toJS).toJS;
  api['mensagem'] = ((JSString c) => _mensagem(c.toDart).toJS).toJS;
  api['minimoDaSenha'] = minimoDaSenha.toJS;
  api['evento'] = ((JSString uid, JSString licao, JSNumber quando) =>
      _evento(uid.toDart, licao.toDart, quando.toDartInt).toJS).toJS;
  api['respondidas'] =
      ((JSString eventos) => _respondidas(eventos.toDart).toJS).toJS;
  api['dossie'] = ((JSString t, JSString r) =>
      _dossie(t.toDart, r.toDart).toJS).toJS;
  globalContext['devlingo'] = api;
}
