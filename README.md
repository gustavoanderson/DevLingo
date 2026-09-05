# DevLingo

App Android para aprender linguagens de programação, no formato Duolingo.

O usuário escolhe uma linguagem, entra em uma trilha de iniciante, intermediário ou avançado, e progride resolvendo exercícios de múltipla escolha e de escrita de código. O progresso é salvo a cada questão respondida.

Mascote: **Tr∅nikAt**, um gato branco ciberneticamente modificado, com visor no estilo scouter.

---

## Estado atual

O projeto está em construção. O que já existe:

- [x] Identidade visual e mascote (paleta, logo, ciclo de caminhada)
- [x] Modelagem do banco de questões (esquema formal)
- [x] Validador de conteúdo rodando em CI
- [x] Layout da tela de exercício
- [x] Cenários animados de fundo (dia, tarde, noite)
- [ ] Banco de questões: 1 lição de Python, 1 de JavaScript, faltam 8
- [ ] Aplicativo Flutter

---

## Stack

| Camada | Escolha | Por quê |
|---|---|---|
| App | Flutter (Dart) | Android primeiro, com porta aberta para iOS depois |
| Autenticação | Firebase Auth | Recuperação de senha por e-mail já vem pronta |
| Progresso | Firestore + cache local | Offline-first: grava local, sincroniza depois |
| Conteúdo | JSON versionado neste repositório | Funciona offline, custo zero de leitura, revisável em pull request |
| Validação | Python + jsonschema | Roda em CI e não depende do Flutter instalado |

---

## Estrutura

```
CLAUDE.md         contexto do projeto para sessões de Claude Code
content/          banco de questões, uma pasta por linguagem
  python/
    python-beg-00.json      lição de referência (formato)
    python-beg-01.json      primeiros passos
  javascript/
    javascript-beg-01.json  primeiros passos
tools/
  question.schema.json      contrato do formato de uma questão
  validate_questions.py     validador do banco
assets/
  mascot/                   arte do Tr∅nikAt
  cenarios/                 faixas de fundo (dia, tarde, noite)
docs/
  paleta.md                 cores e tipografia
  mockup-tela-exercicio.html  referência visual da tela
.github/workflows/
  validate-content.yml      roda o validador a cada push
```

---

## Como o banco de questões funciona

Uma questão separa **o que ela mostra** do **como ela é respondida**:

- `code` é opcional. Quando presente, o app renderiza o trecho em uma IDE simulada.
- `answerType` define a interação: `multipleChoice` (5 alternativas, 1 correta), `fillBlank` (preencher lacuna) ou `freeWrite` (escrever a linha).

Essa separação permite qualquer combinação sem criar tipos novos: teórica pura, teórica com código, lacuna com código, escrita livre.

Todas as questões têm `hint` e `explanation` obrigatórias. A dica ajuda quem travou; a explicação aparece depois da resposta e é onde o aprendizado de fato acontece.

O formato completo está descrito em `tools/question.schema.json`.

---

## Rodando o validador

```bash
pip install jsonschema
python3 tools/validate_questions.py content/
```

Saída `0` significa banco aprovado. Saída `1` significa banco reprovado, com a lista de defeitos encontrados.

O validador checa o que o esquema formal não consegue expressar sozinho:

- exatamente uma alternativa correta por questão de múltipla escolha
- alternativas com texto repetido
- `id` de questão duplicado entre lições diferentes, que quebraria o progresso salvo
- `highlightLine` apontando para uma linha que não existe no trecho de código
- questão de lacuna sem o marcador de lacuna no código
- dica que entrega a resposta literalmente
- respostas aceitas que colapsam na mesma coisa depois da normalização

**Limitação conhecida:** a regra que detecta dica entregando a resposta só considera respostas com quatro caracteres ou mais. Abaixo disso o falso positivo seria constante, e validador que grita à toa é validador que as pessoas aprendem a ignorar.

---

## Convenções

**Identificadores são imutáveis.** O progresso do usuário aponta para o `id` de cada questão. Renumerar uma questão publicada quebra o progresso de quem já a respondeu. Para aposentar uma questão, remova-a; nunca reaproveite o identificador.

**Credenciais nunca são versionadas.** Os arquivos do Firebase estão no `.gitignore`. Se algum deles aparecer em um `git status`, algo está errado.
