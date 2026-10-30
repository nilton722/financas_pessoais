# Design system e apresentação de dados

Documento de referência para a linguagem visual da aplicação e para as regras
de formatação de montantes, datas e percentagens. A fonte de verdade continua a
ser o código em `lib/app/theme` e `lib/core`; este documento explica as decisões
e evita que cada ecrã invente o seu próprio estilo ou formato.

Decisão registada em [ADR-032](DECISIONS.md#adr-032--design-system-com-tokens-e-política-de-apresentação-de-dados).

## Princípios

1. **Identidade teal, fundo areia.** O teal mantém-se como cor de marca; o fundo
   claro é areia quente (`#F7F3EB`) e os cartões são um branco quente
   (`#FFFDF8`), com contorno subtil em vez de sombra. O modo escuro usa
   superfícies verde-carregadas coerentes com o mesmo matiz.
2. **Legibilidade antes de decoração.** Cartões sem elevação, contornos de 1 px,
   espaçamento consistente e hierarquia tipográfica clara. A cor nunca é o
   único indicador de um estado: é sempre acompanhada de texto, ícone, sinal ou
   etiqueta.
3. **Números tratados como números.** Montantes inteiros em FCFA/XOF, algarismos
   tabulares, alinhamento à direita e separador de milhares português.
4. **Uma regra, um lugar.** Tokens, tema, formatters e componentes partilhados
   vivem em `lib/app/theme` e `lib/core`. Os ecrãs compõem; não redefinem cores,
   raios, espaçamentos ou formatos.
5. **Sem dependências novas.** O design system usa apenas Flutter/Material 3 e
   `intl`, já presente no projeto.

## Tokens

### Espaçamento (`AppSpacing`)

Escala de 4 pt, usada em `EdgeInsets`, `SizedBox` e `gap`:

| Token | Valor | Uso típico |
|---|---|---|
| `xxs` | 2 | separação mínima entre linhas relacionadas |
| `xs` | 4 | etiquetas e ícones inline |
| `sm` | 8 | linhas de lista, chips |
| `md` | 12 | conteúdo interno de cartões pequenos |
| `lg` | 16 | margem de página, padding de cartão |
| `xl` | 24 | separação entre secções |
| `xxl` | 32 | blocos de destaque |
| `xxxl` | 48 | estados vazios e respiro excecional |

Atalhos: `AppSpacing.page` (16 em todos os lados), `pageHorizontal` (16
horizontal), `card`, `cardHorizontal` e `listBottom` (96, para o conteúdo não
ficar sob o FAB/barras).

### Raios (`AppRadii`)

| Token | Valor | Uso |
|---|---|---|
| `sm` | 8 | chips, badges de texto, tooltips |
| `md` | 12 | campos, botões, menus, itens de lista |
| `lg` | 16 | cartões, diálogos, FAB |
| `xl` | 24 | contentores de ícone e blocos de destaque |
| `pill` | 999 | badges de estado |

Atalhos: `card` (lg), `control` (md), `small` (sm), `badge` (pill).

## Cor

### Marca e superfícies

- Semente Material 3: `#00695C` (teal).
- Claro: fundo `#F7F3EB`, cartão `#FFFDF8`, texto `#1A1C1A`, contorno
  `#D3CDC1`.
- Escuro: fundo `#0C1210`, cartão `#111815`, texto `#E2E5E1`, contorno
  `#3A4742`.
- O tema define `cardTheme`, `appBarTheme`, `listTileTheme`,
  `inputDecorationTheme`, botões com altura mínima de 48, `navigationBarTheme`,
  chips, `segmentedButtonTheme`, snackbar, diálogo, menu, progresso e tooltip.
  Os ecrãs herdam estes estilos; não os repetem localmente.

### Cores com significado financeiro (`FinanceColors`)

Extensão de tema com valores próprios, porque as cores tonais do Material não
distinguem rendimento, transferência e aviso com contraste suficiente nos dois
modos:

| Papel | Claro | Escuro |
|---|---|---|
| Rendimento (`income`) | `#1B6E45` | `#7DD8A6` |
| Transferência (`transfer`) | `#175E8C` | `#8CCBF5` |
| Aviso (`warning`) | `#8A5A00` | `#F2C66D` |
| Saldo positivo (`positive`) | `#0F5C4A` | `#80D8C4` |

Cada papel tem também um contentor e uma cor `on*` para badges e superfícies.
Despesa usa `colorScheme.error`, porque erro e despesa partilham a mesma
urgência visual. O saldo positivo é distinto do verde de rendimento: um saldo
não é um rendimento.

## Tipografia

Base Material 2021, com ajustes:

- `headlineMedium`/`headlineSmall`: w700, `letter-spacing` negativo, altura
  1,2–1,25 — títulos de destaque e saldo principal.
- `titleLarge`: w700; `titleMedium`: w600; `titleSmall`: w600 — cabeçalhos de
  cartão e títulos de lista.
- `bodyLarge`/`bodyMedium`: altura 1,45 para leitura confortável.
- `bodySmall`: altura 1,4 e `onSurfaceVariant` — texto secundário.
- `labelLarge`/`labelMedium`/`labelSmall`: w600 e `letter-spacing` ligeiro —
  botões, chips e etiquetas.

Não se usam tamanhos de letra avulsos nos ecrãs; qualquer exceção deve usar um
estilo do tema com `copyWith` apenas para peso ou cor.

## Componentes partilhados

### `MoneyText`

Montante com algarismos tabulares, alinhamento à direita por omissão e cor
semântica opcional (`MoneyTone.neutral/income/expense/transfer/projection/warning`).

- `compact: false` (omissão): valor exato com agrupamento e `FCFA`.
- `compact: true`: resumo abreviado (`1,25 M FCFA`), mas a semântica de
  acessibilidade anuncia sempre o valor exato.
- `signed: true`: entradas positivas mostram `+`; negativas mantêm `-`.
- `maxLines: 1` com `ellipsis`: evita rebentar linhas em listas.

### `SectionCard`

Cartão com cabeçalho opcional (ícone, título, subtítulo, ação) e divisor
opcional. É o contentor padrão de secções, resumos, formulários e listas
agrupadas. Padding por omissão `AppSpacing.lg`; listas usam `padding: zero` e
divisores entre linhas.

### `AppDataRow`

Linha rótulo/valor com o valor à direita, usado em resumos de pagamento,
detalhes de backup e cartões de orçamento/metas. `emphasize` aplica a cor de
erro quando o valor representa falta ou excesso.

### `StatusBadge`

Etiqueta em pílula com `StatusTone`
(`neutral/positive/warning/danger/info`), construída com os contentores do
esquema tonal. Usada para estados de compromissos, dívidas, metas,
recorrências, categorias e contagens.

### `EmptyState`

Ícone em contentor arredondado, título, mensagem e ação opcional. Substitui
listas vazias e explica o próximo passo em vez de mostrar apenas “sem dados”.

### `LabeledDropdown`

Seleção controlada com etiqueta flutuante e mensagem de erro. Quando não há
valor, mostra a indicação `Selecionar` (personalizável por `hint`) em vez de um
campo vazio, para que a ação pendente fique sempre explícita.

## Política de apresentação de dados

### Montantes

- Inteiros FCFA/XOF, nunca `double`; formatação com `MoneyFormatter`.
- **Valor exato** em listas, formulários, detalhes, relatórios e exportações:
  `12 500 FCFA`, com agrupamento de milhares e sem casas decimais.
- **Resumo compacto** apenas em cartões de resumo do painel e indicadores
  equivalentes: a partir de 1 000 000 passa a `1,25 M FCFA` e a partir de
  1 000 000 000 a `1,25 mil M FCFA`. Abaixo do limiar continua exato.
- O valor exato permanece disponível na semântica de acessibilidade e nos
  ecrãs de detalhe. O compacto nunca é a única forma de consultar o montante.
- Entradas e saídas usam sinal explícito quando o contexto é uma variação
  (`+12 500 FCFA`); saldos negativos mantêm `-`.
- Algarismos tabulares e alinhamento à direita permitem comparar colunas sem
  “dançar” entre linhas.

### Percentagens

`PercentFormatter.format` recebe o valor já em percentagem (0–100), usa vírgula
decimal, no máximo uma casa e arredonda 100% ou mais para inteiro. Valores não
finitos apresentam `0%`. A percentagem é acompanhada pelo estado textual
(ex.: “Restam”, “Excedido em”) e por uma barra de progresso.

### Datas

- Armazenamento financeiro `YYYY-MM-DD`; timestamps técnicos ISO-8601 UTC.
- Apresentação `DD/MM/YYYY` através de `FinancialDate.toDisplay`.
- Listas de movimentos agrupam por dia com o cabeçalho do dia e o total do dia;
  a data completa continua na semântica de cada item.

### Texto e pluralização

- `PluralFormatter.count(valor, singular, plural)` para todas as contagens
  visíveis: `1 meta`, `3 metas`, `1 milhão`, `3 milhões`.
- Rótulos e mensagens em português de Portugal; valores e datas com formatos
  `pt_PT`.
- Estados e resumos usam frases curtas com separador `·` em vez de parênteses
  técnicos como `meta(s)`.

### Transferências e planeamento

- Transferências entre contas próprias aparecem com cor e rótulo próprios e
  ficam fora de rendimento, despesa e resultado.
- Compromissos, orçamentos, metas e dívidas mostram o estado textual e o valor
  pendente; valores pagos não são apresentados como despesa nova.
- A previsão usa a cor de projeção (primária), distinta do saldo real, e mostra
  data de corte, pressupostos e limitações.

## Layout

- Página: padding horizontal de 16, topo de 8 e fundo de 32 nas listas; listas
  com FAB usam `AppSpacing.listBottom`.
- Cartões de lista: `Card` com `clipBehavior: Clip.antiAlias`, conteúdo em
  `Column`, divisor de 1 px entre linhas.
- Formulários: campos preenchidos com raio 12, sem `OutlineInputBorder`
  localizado; botão principal a 48 de altura; erros em `AppFailure` com padding
  de página.
- Ícones de lista vivem num contentor `AppRadii.xl` com cor de contentor
  semântica (rendimento/despesa/transferência/neutro).
- Ação destrutiva ou secundária vive num menu de overflow com tooltip e chave
  estável; a ação principal é explícita.

## Acessibilidade

- Contraste verificado nos dois modos para as cores semânticas e para o texto
  sobre contentores.
- Alvos táteis principais com pelo menos 48×48.
- `MoneyText` compacto anuncia o valor exato; ícones e estados têm etiquetas
  textuais; listas expõem descrições completas.
- A cor nunca é o único indicador: há sempre texto, ícone, sinal ou posição.
- O texto respeita o escalamento do sistema; listas usam `maxLines` e
  `ellipsis` em vez de alturas fixas.

## Onde está implementado

```text
lib/app/theme/
  app_tokens.dart       espaçamento e raios
  finance_colors.dart   cores semânticas (ThemeExtension)
  app_theme.dart        tema Material 3 claro/escuro
lib/core/formatters/
  money_formatter.dart  exato, assinado e compacto
  percent_formatter.dart
  plural_formatter.dart
lib/core/widgets/
  money_text.dart
  section_card.dart
  app_data_row.dart
  status_badge.dart
  empty_state.dart
```

## Manutenção

- Alterar um token ou uma cor significa alterar o ficheiro em `lib/app/theme`,
  não os ecrãs.
- Um novo formato de dados deve entrar num formatter e ser coberto por teste
  unitário.
- Um novo componente partilhado deve ser usado pelo menos em dois ecrãs antes de
  ser promovido a `lib/core/widgets`.
- Testes relevantes: `test/unit/formatters`, `test/widget` (painel, movimentos,
  planeamento, relatórios, definições) e `test/integration`.
