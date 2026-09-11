# Servidor MCP do DevLingo

Expõe os **portões de qualidade** do projeto como ferramentas que um agente pode chamar.

Não é demonstração: são as mesmas regras que reprovam no CI, disponíveis para quem escreve conteúdo **antes** de ele virar arquivo.

---

## As quatro ferramentas

| Ferramenta | Responde |
|---|---|
| `validar_licao(licao)` | esta lição passa nas 10 regras do validador? |
| `impressao_digital(resposta, trilha)` | esta resposta já é cobrada, e por qual questão? |
| `conferir_teclado(resposta)` | dá para digitar isso num teclado de celular? |
| `topicos_da_trilha(trilha)` | que tópicos existem, e com quantas questões? |

**Todas são somente leitura.** Nenhuma grava, publica ou apaga.

Isso é desenho, não descuido. A regra, que o próprio curso de Agentes ensina: *um limite só vale quando não depende do modelo julgar bem.* Com `validar_licao` exposta e nenhuma ferramenta de escrita, **publicar é impossível para o agente** — não importa o que ele decida, nem o que tenha lido num texto que processou.

---

## Por que MCP, e não um script

O teste que a lição 03 do curso propõe: *quantos consumidores diferentes precisam disto, e eles alcançam onde a capacidade mora?*

| Consumidor | Onde roda | Alcança as regras? |
|---|---|---|
| Uma sessão local | esta máquina | sim |
| Rotina de madrugada | nuvem | **não** |
| Agente revisor em CI | nuvem | **não** |

Três consumidores, dois deles longe das regras. É o motivo de forçamento **geográfico** — e sem ele, este servidor seria teatro, que é o que a mesma lição alerta.

---

## Rodar

```bash
pip install mcp
python3 mcp/servidor.py
```

O transporte padrão é **stdio**: o servidor conversa pela entrada e saída padrão, e quem o inicia é o cliente.

### Conectar num cliente

A configuração abaixo vale para clientes que leem `mcpServers` (Claude Desktop, Claude Code e outros). Ajuste o caminho:

```json
{
  "mcpServers": {
    "devlingo": {
      "command": "python3",
      "args": ["D:/repositorio/DevLingo/mcp/servidor.py"]
    }
  }
}
```

O diretório de trabalho **não importa**: o servidor resolve os caminhos a partir da própria localização.

---

## Testes

```bash
python3 mcp/test_ferramentas.py
```

São 20 conferências, e elas rodam contra o **banco real**, não contra dados de mentira — o que estas ferramentas fazem é responder perguntas sobre o banco, e um banco falso provaria que a função roda, não que ela responde certo.

Cada teste confere o pressuposto antes de afirmar o resultado, e falha dizendo *"o banco mudou"* em vez de *"a ferramenta quebrou"*.

### Três deles existem por causa de um defeito real

A primeira versão de `impressao_digital` comparava a resposta procurada contra **qualquer posição** da chave da impressão digital. E a chave é `(linguagem, família, tópico, resposta)` — então:

```
impressao_digital("java", "java")  ->  ja_cobrada: True   # errado
```

O termo casava com o campo da **linguagem**. O mesmo acontecia com `"escrita"` (família) e `"igualdade"` (tópico).

**Falso positivo numa ferramenta de agente é pior que numa de gente:** ele obedece sem desconfiar, e sairia trocando uma resposta que estava correta. Os três casos viraram teste, e foram verificados reintroduzindo o defeito.

---

## O que este servidor não faz

- **Não implementa regra nenhuma.** Toda a lógica vem de `tools/validate_questions.py`, importado. Duas implementações da mesma regra divergem em silêncio, e este repositório já pagou esse preço duas vezes
- **Não escreve.** Ver acima
- **Não confere se o conteúdo é VERDADE.** As 10 regras checam estrutura. Uma lição perfeitamente formada dizendo que *"em Python o ponto e vírgula é obrigatório"* passa em todas as dez — e é por isso que o agente revisor, previsto em `docs/IDEIAS.md`, não é opcional
