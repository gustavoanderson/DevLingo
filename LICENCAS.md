# Licenças do DevLingo

Este é o documento canônico. O `LICENSE` na raiz existe porque o GitHub lê aquele arquivo, mas ele cobre **só o código**.

O projeto tem três regimes, porque as três coisas têm naturezas diferentes: código quer ser reusado, conteúdo didático custou meses para ser escrito, e um mascote é identidade — não material.

---

## O mapa

| O que | Onde | Licença |
|---|---|---|
| **Código-fonte** | `app/lib/`, `app/test/`, `tools/`, `app/android/`, `app/ios/`, configuração | **MIT** |
| **Documentação de engenharia** | `README.md`, `CLAUDE.md`, `docs/*.md` | **MIT** |
| **Conteúdo didático** | `app/assets/content/**` — questões, aulas, dicas e explicações | **CC BY-NC-ND 4.0** |
| **Mascote, arte e identidade** | `app/assets/mascot/`, `assets/cenarios/`, `app/assets/som/`, `docs/imagens/`, ícones do app | **Todos os direitos reservados** |
| **Nome DevLingo e nome Tr∅nikAt** | — | **Todos os direitos reservados** |

Copyright © 2026 Gustavo Anderson.

---

## 1. Código — MIT

Faça o que quiser: use, copie, modifique, distribua, venda. Só mantenha o aviso de copyright.

**A documentação de engenharia entra aqui de propósito.** O `CLAUDE.md` tem mais de 1.500 linhas registrando decisões, erros e medições — se ele for útil a alguém, que seja útil sem pedir licença. Ele é o registro de como o projeto foi construído, não o produto.

---

## 2. Conteúdo didático — CC BY-NC-ND 4.0

As 404 questões, as aulas, as dicas e as explicações em `app/assets/content/`.

Licença completa: **https://creativecommons.org/licenses/by-nc-nd/4.0/legalcode.pt**
Resumo legível: https://creativecommons.org/licenses/by-nc-nd/4.0/deed.pt-br

**O que você PODE:**

- Copiar e redistribuir o material, em qualquer meio ou formato
- Usar para estudar, ensinar em sala de aula, ou citar

**Sob três condições:**

| | |
|---|---|
| **BY** — Atribuição | Dê crédito, com link para este repositório, e indique se houve mudanças |
| **NC** — Não Comercial | Não use para fins comerciais |
| **ND** — Sem Derivações | Se você remixar, transformar ou criar a partir do material, **não pode distribuir** o resultado |

### O que o ND significa na prática, sem rodeio

**Traduzir é criar uma obra derivada.** Republicar o banco de questões em inglês, alemão ou qualquer idioma **não é permitido** sem autorização por escrito. O mesmo vale para reescrever uma questão, adaptar o formato, ou gerar conteúdo novo a partir deste.

Isso é deliberado. As questões não são um texto qualquer: elas passaram por regras de gabarito distribuído, impressão digital, sincronia entre aula e tópico, e restrição de teclado — e uma adaptação malfeita destrói tudo isso mantendo o nome do projeto associado.

**Uso pessoal não é distribuição.** Estudar, imprimir para si, exportar em PDF as questões que você respondeu, anotar em cima: tudo permitido, e nada disso é redistribuir.

---

## 3. Mascote, arte e identidade — reservados

**Tr∅nikAt** — o gato branco bípede com visor verde — e toda a arte derivada dele não estão sob Creative Commons e **não podem ser usados, copiados, modificados ou redistribuídos** sem autorização por escrito.

Cobre: o mascote em `app/assets/mascot/`, as três faixas de cenário em `assets/cenarios/`, os efeitos sonoros em `app/assets/som/`, os ícones do app, o retrato, e a cena da tela de entrada.

Os geradores (`tools/gerar_faixas.py`, `tools/gerar_sons.py`) continuam **MIT como código** — a restrição é sobre o desenho e o som que eles emitem, não sobre o programa.

Cobre também os **nomes** DevLingo e Tr∅nikAt, a paleta aplicada à identidade, e o logotipo com aberração cromática.

**Por que separado do conteúdo:** mascote e nome são marca. Um curso mal traduzido carregando o Tr∅nikAt no cabeçalho seria lido como sendo daqui — e CC BY-NC-ND permitiria exatamente isso, já que redistribuir sem modificar é permitido por ela.

---

## Contribuições

**Não são aceitas contribuições de conteúdo.** Pull request que acrescente, altere ou traduza questões, aulas, dicas ou explicações será fechado sem análise — não por falta de educação, mas porque o ND torna isso juridicamente confuso, e a coerência entre as trilhas depende de uma cabeça só.

**Erro de conteúdo é muito bem-vindo por issue.** Uma questão com gabarito errado, uma explicação que ensina errado, um acento onde não devia: abra uma issue e ela será corrigida com crédito no commit.

Para o **código**, que é MIT, pull request é bem-vindo normalmente.

---

## Quer usar de outro jeito?

Traduzir, usar comercialmente, adaptar o formato, ou usar o Tr∅nikAt: é só pedir. A licença restritiva existe para que o pedido aconteça, não para impedir que exista resposta.

**gustavoanderson.me@gmail.com**

---

## Sobre as dependências

O app usa bibliotecas de terceiros declaradas em `app/pubspec.yaml`, cada uma com a licença própria. Elas **não** são cobertas por este documento.

O app ainda **não** tem uma tela que liste essas licenças. O Flutter oferece `showLicensePage` pronto para isso, e ela deve entrar antes de qualquer publicação em loja — algumas licenças de dependência exigem que o aviso chegue ao usuário final.
