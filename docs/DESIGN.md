# Design system e apresentação de dados

Documento de referência para a linguagem visual da aplicação e para as regras
de formatação de montantes, datas e percentagens. A fonte de verdade continua a
ser o código em `lib/app/theme` e `lib/core`; este documento explica as decisões
e evita que cada ecrã invente o seu próprio estilo ou formato.

Decisão registada em [ADR-032](DECISIONS.md#adr-032--design-system-com-tokens-e-política-de-apresentação-de-dados).

## Princípios

1. **Identidade esmeralda, dourado e fundo verde-claro.** A marca Nô Dinheru usa
   o verde `#087F5B`, o verde escuro `#104B3C`, o dourado `#E8C66A` e o coral
   `#E47768`; o fundo claro é `#F5F8F5`, os cartões são brancos e o texto é
   `#182923`. O modo escuro usa superfícies verde-carregadas coerentes com o
   mesmo matiz.
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

## Marca

- Nome apresentado: **Nô Dinheru**. Slogan: **O teu dinheiro, sob controlo.**
- Paleta oficial: verde `#087F5B`, verde escuro `#104B3C`, dourado `#E8C66A`,
  fundo claro `#F5F8F5`, texto `#182923`, coral `#E47768`.
- Recursos em `assets/branding/`:
  - `no_dinheru_icon.png` — ícone oficial 1024×1024: quadrado esmeralda
    arredondado, “N” branco estilizado, aro/mancha dourada e pilha de moedas
    douradas. É a arte aprovada da marca e não deve ser redesenhada.
  - `no_dinheru_icon_foreground.png` — camada de foreground para ícone
    adaptativo, com a arte dentro da zona segura.
  - `no_dinheru_logo.png` / `no_dinheru_logo_dark.png` — logótipo vertical
    (ícone + nome + slogan), para fundos claros e escuros.
- O logótipo completo e o splash partilham a mesma composição: fundo
  `#087F5B`, ícone dentro de um quadrado branco arredondado, nome branco,
  slogan e “Finanças pessoais • Guiné-Bissau”. A secção **Sobre** das
  definições mostra o logótipo vertical; o launcher usa o ícone isolado.
- No Android 12+ o splash do sistema mostra apenas o ícone, por limitação da
  plataforma; a composição completa aparece imediatamente a seguir, no splash
  Flutter. Em versões anteriores o lockup completo é desenhado nativamente.
  Não se recorta, estica nem altera a paleta do emblema.
- Os ícones Android (legacy e adaptativo) e iOS são ficheiros estáticos gerados
  a partir do ícone oficial, sem `flutter_launcher_icons`.

### Splash

- `lib/app/splash/splash_page.dart` desenha a composição e as animações
  discretas: fundo imediato, ícone com fade-in e escala (0→0,55), nome
  (0,28→0,70), slogan (0,48→0,86) e identificação (0,62→1). Com animações
  desativadas no sistema, a composição aparece estática.
- `lib/app/splash/splash_gate.dart` mantém o splash por cima da aplicação até
  `appStartupProvider` concluir — abrir a base SQLite com as migrações e
  carregar as definições — e até a animação de entrada terminar; depois
  desvanece-o em 320 ms. Não existe temporizador fixo a atrasar a abertura.
- O splash usa cores fixas da marca (`BrandColors`), não o esquema claro/escuro,
  para manter a mesma abertura em qualquer configuração do sistema.
- O tamanho do ícone, os textos e os espaçamentos derivam do lado mais curto do
  ecrã, com limites para telemóveis pequenos e grandes; o conteúdo pode rolar em
  orientações muito baixas.

## Cor

### Marca e superfícies

- Semente Material 3: `#087F5B` (verde principal).
- Claro: fundo `#F5F8F5`, cartão `#FFFFFF`, texto `#182923`, contorno
  `#D3DDD6`; dourado em `secondary` e coral escurecido em `error` para
  contraste de texto.
- Escuro: fundo `#0B1512`, cartão `#0F1A16`, texto `#E3EAE6`, contorno
  `#34463C`; verde-menta `#6FDDB8` como primário.
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
| Rendimento (`income`) | `#0F6B4F` | `#7CDDB5` |
| Transferência (`transfer`) | `#225F6D` | `#8CCBE0` |
| Aviso (`warning`) | `#8A5A00` | `#F2C66D` |
| Saldo positivo (`positive`) | `#0B5C46` | `#80D8C4` |

Cada papel tem também um contentor e uma cor `on*` para badges e superfícies.
Despesa usa `colorScheme.error`, porque erro e despesa partilham a mesma
urgência visual. O erro claro é um coral escurecido (`#B3372B`) para manter
contraste de texto; o coral oficial `#E47768` fica reservado a superfícies,
ícones e estados em modo escuro. A transferência usa um azul-petróleo de apoio,
distinto do verde de rendimento. O saldo positivo é distinto do verde de
rendimento: um saldo não é um rendimento.

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

### `AppNavigationBar`

Barra de navegação inferior com os cinco destinos fixos (`Painel`,
`Movimentos`, `Contas`, `Categorias`, `Plano`). Segue o `navigationBarTheme`
(altura, fundo, indicador, ícones e etiquetas) e substitui o `NavigationBar`
do Material 3 por um problema concreto: o componente do SDK deixa a etiqueta
quebrar em duas linhas quando o destino é estreito, desalinhando a barra em
ecrãs pequenos ou com texto ampliado.

- Cada etiqueta ocupa **uma única linha** e usa `FittedBox(scaleDown)`: só
  encolhe quando não cabe na largura do destino, mantendo o texto completo e
  legível em vez de o cortar ou quebrar.
- A largura do indicador acompanha a largura do destino (máx. 64), para não
  transbordar em ecrãs de 320 dp.
- Cada destino anuncia `Semantics(button, selected, label, onTap)`; o toque
  cobre toda a área do destino.
- Validado em 320 dp com texto a 130% e no tamanho normal do emulador.

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
  brand_colors.dart     cores fixas da marca (splash)
  finance_colors.dart   cores semânticas (ThemeExtension)
  app_theme.dart        tema Material 3 claro/escuro
lib/app/
  app_startup.dart      inicialização real (SQLite + definições)
  splash/
    splash_gate.dart    espera pela inicialização e desvanece o splash
    splash_page.dart    composição e animações do splash
  shell/
    app_shell.dart          shell com os cinco destinos
    app_navigation_bar.dart barra inferior adaptativa
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
assets/branding/
  no_dinheru_icon.png             ícone oficial 1024
  no_dinheru_icon_foreground.png  foreground adaptativo
  no_dinheru_logo.png             logótipo para fundo claro
  no_dinheru_logo_dark.png        logótipo para fundo escuro
android/app/src/main/res/          ícones legacy, adaptativo e splash nativo
ios/Runner/Assets.xcassets/        AppIcon.appiconset e LaunchImage
```

## Manutenção

- Alterar um token ou uma cor significa alterar o ficheiro em `lib/app/theme`,
  não os ecrãs.
- Um novo formato de dados deve entrar num formatter e ser coberto por teste
  unitário.
- Um novo componente partilhado deve ser usado pelo menos em dois ecrãs antes de
  ser promovido a `lib/core/widgets`.
- O ícone oficial só muda por decisão de marca. Nesse caso, regenerar o
  foreground adaptativo, os mipmaps legacy, o `AppIcon.appiconset`, o lockup do
  splash (`launch_logo` e `LaunchImage`) e os logótipos de Sobre a partir da
  mesma arte, sem depender de `flutter_launcher_icons`.
- O splash não deve introduzir atrasos arbitrários: novas tarefas de arranque
  entram em `appStartupProvider`, e o splash sai quando esse future termina.
- Testes relevantes: `test/unit/formatters`, `test/widget` (painel, movimentos,
  planeamento, relatórios, definições, splash) e `test/integration`.
