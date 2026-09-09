import 'dart:convert';
import 'dart:io';

import 'package:devlingo/ui/texto_rico.dart';
import 'package:flutter_test/flutter_test.dart';

/// O texto que o aluno realmente enxerga, sem os marcadores.
String _visivel(List<TrechoDeTexto> trechos) =>
    trechos.map((t) => t.texto).join();

List<TrechoDeTexto> _termos(List<TrechoDeTexto> t) =>
    t.where((x) => x.estilo == EstiloDoTrecho.termo).toList();

void main() {
  group('marcacao do autor', () {
    test('crase vira termo, e a crase some do texto visivel', () {
      final t = analisarTexto('Use o `for` para repetir.');
      expect(_visivel(t), 'Use o for para repetir.');
      expect(_termos(t).single.texto, 'for');
    });

    test('asteriscos viram negrito, e somem do texto visivel', () {
      // Sete trechos assim ja existiam no banco antes deste analisador, e
      // apareciam CRUS na tela: o aluno lia "as **chaves**" com asteriscos.
      final t = analisarTexto('o bloco usa **chaves**, nao recuo');
      expect(_visivel(t), 'o bloco usa chaves, nao recuo');
      expect(
        t.singleWhere((x) => x.estilo == EstiloDoTrecho.negrito).texto,
        'chaves',
      );
    });

    test('marcador sem par fica como texto, e nao come o resto', () {
      // Preferir mostrar o asterisco a engolir metade do paragrafo. Quem
      // reprova marcador desbalanceado e o validador, antes de chegar aqui.
      const cru = 'isto tem um * solto e uma ` sozinha';
      expect(_visivel(analisarTexto(cru)), cru);
    });

    test('marcador vazio nao delimita nada', () {
      expect(_visivel(analisarTexto('a `` b **** c')), 'a `` b **** c');
    });
  });

  group('lexico automatico', () {
    test('destaca funcao e tipo em python', () {
      final t = analisarTexto(
        'A funcao print mostra na tela, e int e um numero inteiro.',
        linguagem: 'python',
      );
      expect(_termos(t).map((x) => x.texto), ['print', 'int']);
    });

    test('destaca console.log inteiro, com o ponto junto', () {
      // Sem juntar, o ponto ficaria em cor de texto no meio do termo, e o
      // nome apareceria partido em dois.
      final t = analisarTexto(
        'O console.log escreve no terminal.',
        linguagem: 'javascript',
      );
      expect(_termos(t).single.texto, 'console.log');
    });

    test('nao destaca pedaco de palavra maior', () {
      final t = analisarTexto(
        'imprimir e printar nao sao print, e inteiro nao e int',
        linguagem: 'python',
      );
      expect(_termos(t).map((x) => x.texto), ['print', 'int']);
    });

    test('linguagem sem lexico mantem a marcacao do autor', () {
      // O banco preve nove linguagens sem tokenizador nenhum. Elas nao podem
      // perder o negrito e as crases so por isso.
      final t = analisarTexto('o **SELECT** e o `FROM`', linguagem: 'sql');
      expect(_visivel(t), 'o SELECT e o FROM');
      expect(_termos(t).single.texto, 'FROM');
    });
  });

  group('as palavras que TAMBEM sao portugues', () {
    // Medido no banco antes de escrever o lexico: `as` apareceu 6 vezes e as 6
    // eram artigo; `for` apareceu 4 vezes e 2 eram o verbo. Destacar essas
    // ensinaria errado justo onde o aluno esta aprendendo.
    test('"as" nunca e destacado sozinho', () {
      final t = analisarTexto(
        'ela dispensa as chaves e devolve o resultado',
        linguagem: 'python',
      );
      expect(_termos(t), isEmpty);
    });

    test('"for" do verbo nao e destacado', () {
      final t = analisarTexto(
        'Se for verdadeira, o bloco roda.',
        linguagem: 'javascript',
      );
      expect(_termos(t), isEmpty);
    });

    test('mas o autor consegue marcar o comando com crase', () {
      final t = analisarTexto(
        'O `for` roda enquanto for verdadeiro.',
        linguagem: 'python',
      );
      expect(_termos(t).single.texto, 'for');
      expect(_visivel(t), 'O for roda enquanto for verdadeiro.');
    });

    test('"do" tambem fica de fora', () {
      final t = analisarTexto(
        'o valor do total muda a cada volta',
        linguagem: 'javascript',
      );
      expect(_termos(t), isEmpty);
    });
  });

  group('lexico do curso de frameworks', () {
    test('os nomes das seis tecnologias sao destacados', () {
      final t = analisarTexto(
        'Next usa React, Nuxt usa Vue, e Astro aceita Svelte tambem',
        linguagem: 'frameworks',
      );
      expect(
        _termos(t).map((x) => x.texto),
        containsAll(['Next', 'React', 'Nuxt', 'Vue', 'Astro', 'Svelte']),
      );
    });

    // Mesma familia dos testes de `as`, `for` e `do` acima, e a razao e a
    // mesma: a lista saiu de MEDIR as 70 passagens do curso, e estas sao as
    // palavras que aparecem como portugues corrente. Destaca-las faria o
    // paragrafo piscar, exatamente como `cache` no lexico de backend.
    //
    // Os numeros medidos, fora de crase e negrito: tela 22, componente 22,
    // estado 14, navegador 13, servidor 10, rota 7, diretiva 2, ilha 1.
    test('as palavras portuguesas medidas nao viram termo', () {
      final t = analisarTexto(
        'o componente redesenha a tela quando o estado muda, '
        'e o navegador pede a rota ao servidor',
        linguagem: 'frameworks',
      );
      expect(_termos(t), isEmpty);
    });

    test('mas o autor consegue marca-las com crase quando forem o conceito', () {
      final t = analisarTexto(
        'a `hidratacao` liga o codigo ao HTML que ja esta na tela',
        linguagem: 'frameworks',
      );
      expect(_termos(t).map((x) => x.texto), ['hidratacao', 'HTML']);
    });

    // O casador anda por caracteres de nome, e hifen nao e um deles: uma
    // entrada com hifen seria partida antes de ser comparada, e nunca casaria.
    // Diretivas do Vue (`v-if`) e marcacoes do Astro (`client:visible`)
    // dependem da crase do autor, e este teste impede que alguem as acrescente
    // ao lexico achando que resolveu.
    test('entrada com hifen nunca casaria, entao nao ha nenhuma', () {
      final comHifen = termosDe('frameworks').where((t) => t.contains('-'));
      expect(comHifen, isEmpty);
    });

    test('v-if depende da crase, e o lexico nao parte a diretiva ao meio', () {
      final t = analisarTexto(
        'o `v-if` mostra ou nao mostra o elemento',
        linguagem: 'frameworks',
      );
      expect(_termos(t).single.texto, 'v-if');
    });
  });

  group('a invariante', () {
    // A mesma regra do realce de sintaxe: um analisador que come um caractere
    // e pior que nenhum, porque o texto passa a mentir e ninguem ve a olho nu.
    test('nada se perde em nenhum texto do banco', () {
      final pasta = Directory('assets/content');
      var textos = 0;

      for (final arquivo in pasta
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))) {
        final dados =
            json.decode(arquivo.readAsStringSync()) as Map<String, dynamic>;
        final linguagem = dados['language'] as String;

        final campos = <String>[];
        for (final q in (dados['questions'] as List).cast<Map>()) {
          campos.addAll([
            q['prompt'] as String,
            q['hint'] as String,
            q['explanation'] as String,
          ]);
        }
        final aula = dados['aula'] as Map<String, dynamic>?;
        for (final s in (aula?['secoes'] as List? ?? []).cast<Map>()) {
          campos.add(s['texto'] as String);
        }

        for (final texto in campos) {
          textos++;
          final trechos = analisarTexto(texto, linguagem: linguagem);
          final semMarcadores = texto
              .replaceAll('**', '')
              .replaceAll('`', '');
          expect(
            _visivel(trechos),
            semMarcadores,
            reason: 'texto alterado em ${arquivo.path}',
          );
        }
      }

      expect(textos, greaterThan(300), reason: 'a varredura tem que ver tudo');
    });

    test('trechos vizinhos de mesmo estilo sao fundidos', () {
      // Sem isto um paragrafo comum viraria dezenas de trechos identicos, e
      // cada um vira um TextSpan na tela.
      final t = analisarTexto(
        'texto comum sem termo nenhum aqui',
        linguagem: 'python',
      );
      expect(t, hasLength(1));
    });

    test('nenhum trecho vazio sobra', () {
      final t = analisarTexto('`print` e `len`', linguagem: 'python');
      expect(t.any((x) => x.texto.isEmpty), isFalse);
    });
  });
}
