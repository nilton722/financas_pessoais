# Registo de decisões arquiteturais (ADR)

## ADR-001 — Flutter/Dart
**Estado:** aceite. Flutter/Dart será a plataforma mobile principal, Android primeiro e arquitetura preparada para iOS. Não usar React web como interface principal nesta versão.

## ADR-002 — SQLite local
**Estado:** aceite. SQLite é a fonte de verdade local, permitindo operação offline e sem custos de servidor. Não há sincronização ou recuperação remota nesta versão.

## ADR-003 — Sincronização futura, não agora
**Estado:** aceite. Usar IDs UUID e camadas de repositório para facilitar evolução, sem criar API/backend nem campos de conflito prematuros. Sincronização futura exige novo desenho de conflitos, autenticação, segurança e consentimento.

## ADR-004 — Montantes inteiros
**Estado:** aceite. Guardar FCFA/XOF como inteiros; nunca usar `double` em cálculos monetários.

## ADR-005 — Datas
**Estado:** aceite. Datas financeiras `YYYY-MM-DD`; timestamps técnicos ISO-8601 UTC. Apresentação `DD/MM/YYYY`; `Africa/Bissau` inicial e configurável.

## ADR-006 — Previsão local
**Estado:** aceite. Começar com regras Dart transparentes e compromissos conhecidos. Sem Python, ML ou IA externa na primeira versão. Mostrar limitações e não garantir resultados.

## ADR-007 — Compromissos versus movimentos
**Estado:** aceite. Planeamentos ficam separados das transações realizadas; pagamento associa-se ao compromisso para evitar dupla contagem.

## ADR-008 — Transferências neutras
**Estado:** aceite. Transferências próprias alteram duas contas, mas não são rendimento/despesa. Operação atómica.

## ADR-009 — Migrações e backup
**Estado:** aceite. Migrações incrementais e versionadas; backup versionado, validado e restaurável. Nunca apagar a base para atualizar.

## ADR-010 — Privacidade
**Estado:** aceite. Sem telemetria, anúncios ou envio de dados por defeito. Cualquier sincronização futura requer decisão explícita, consentimento e segurança apropriada.

## ADR-011 — Testes
**Estado:** aceite. Testes unitários de domínio, SQLite/repositórios, migrações, widgets e integração dos fluxos críticos. Reportar resultados reais.

## ADR-012 — Modelos estatísticos futuros
**Estado:** aceite. Evoluir só após baseline, dados suficientes e backtesting temporal sem leakage. Comparar MAE/WAPE com baseline e não afirmar superioridade sem evidência.

## ADR-013 — Drift como biblioteca SQLite
**Estado:** aceite na Fase 01. `drift` 2.35.3 com `drift_dev`/`build_runner`.
Motivo: schema tipado, migrações versionadas com testes, foreign keys e transações integradas, e `NativeDatabase.memory()` para testes rápidos do SQL real. Também corre em desktop, o que permite validar a app fora de um emulador. Alternativa `sqflite` 2.4.5 rejeitada: SQL manual, migrações sem tipagem e testes em desktop exigiriam `sqflite_common_ffi`.
Consequência: passo obrigatório de codegen (`dart run build_runner build`) ao alterar tabelas; `lib/core/database/app_database.g.dart` é gerado e não editado à mão. `sqlite3_flutter_libs` está EOL e não é usado; `sqlite3` 3.x resolve a biblioteca nativa por native assets.

## ADR-014 — Riverpod para estado
**Estado:** aceite na Fase 01. `flutter_riverpod` 3.4.3 sem codegen.
Motivo: providers pequenos e testáveis, injeção trivial da base em testes (`ProviderScope` overrides) e ausência de mais uma camada de geração de código. Bloc rejeitado por boilerplate desproporcionado para uma app individual.

## ADR-015 — Entrega faseada do esquema SQLite
**Estado:** aceite na Fase 01. A migração v1 cria `accounts`, `categories`, `transactions`, `app_settings` e `schema_migrations`. As restantes tabelas da SPEC entram em v2–v4 conforme `docs/DATABASE.md`.
Motivo: respeitar o âmbito por fase sem divergir da especificação, exercitando migrações incrementais reais em vez de criar estruturas inúteis durante várias fases.

## ADR-016 — Eliminação lógica de movimentos
**Estado:** aceite na Fase 01. `transactions.deleted_at TEXT NULL` faz parte da v1. Registos com `deleted_at` preenchido ficam fora de saldos, orçamentos e relatórios e não são apagados fisicamente.
Motivo: a Fase 02 exige que eliminação lógica recalcule saldos; introduzir a coluna agora evita um `ALTER TABLE` imediato e fixa a política desde o início.

## ADR-017 — go_router com ShellRoute
**Estado:** aceite na Fase 02; atualizado na Fase 03 com o quinto separador. `go_router` 18.1.1 com `ShellRoute` e `NavigationBar` (Painel, Movimentos, Contas, Categorias, Planeamento); formulários são rotas próprias (`/accounts/new`, `/movements/:id/edit`, `/categories/…`, `/planning/commitments/:id/pay`, `/planning/budgets/new`, …).
Motivo: separadores persistentes com uma única árvore de navegação, URLs testáveis e `push`/`pop` previsíveis nos formulários. `MaterialApp.home` (Fase 01) deixou de servir assim que existiram rotas reais; a dependência entrou apenas quando passou a ser usada. O planeamento é uma área única com cinco entradas (compromissos, orçamentos, recorrências, metas e dívidas) para não sobrecarregar a barra inferior.

## ADR-018 — Saldos calculados, nunca armazenados
**Estado:** aceite na Fase 02. O saldo de uma conta é sempre saldo inicial + movimentos não eliminados até à data de referência, agregados em SQL e somados no domínio (`AccountBalance`, `consolidatedBalance`).
Motivo: eliminar ou editar um movimento recalcula tudo sem migração de dados nem risco de saldo divergente do histórico. Transferências entre contas próprias anulam-se por construção. Custo aceite: agregação em cada leitura, coberta pelos índices de `transactions` e adequada à escala de uma app individual. Se o volume crescer, a otimização será materializar saldos com verificação de consistência, nunca passar a ser a fonte de verdade.
Consequência técnica: os repositórios expõem `watch*` (streams) e `read*` (leitura pontual); o Drift reentrega o último resultado em cache ao re-subserver a mesma consulta, pelo que leituras pontuais após escrita usam `read*`, não `stream.first`.

## ADR-019 — Compromissos pagos por alocação explícita
**Estado:** aceite na Fase 03. Pagar um compromisso cria um movimento real (`expense`/`income`) e uma linha em `planned_item_payments`, na mesma transação SQLite. `UNIQUE(transaction_id)` impede que o mesmo movimento conte em dois compromissos; a soma das alocações nunca excede o valor do compromisso. O estado e o valor pago são derivados do total alocado a movimentos não eliminados, não de uma coluna mutável.
Motivo: cumprir "pagamento não duplica caixa" e "parciais não excedem o valor" sem depender de sincronização posterior. Pagamentos parciais são explícitos e auditáveis; cancelar o compromisso remove-o da previsão mas preserva os movimentos já pagos. O compromisso nunca altera saldo — só o movimento criado no pagamento o faz (ADR-007).

## ADR-020 — Recorrências ancoradas no início e ocorrências idempotentes
**Estado:** aceite na Fase 03. Regras semanal/mensal/anual calculam datas a partir de `start_date`, com ajuste ao último dia em meses curtos (31 Jan → 28/29 Fev → 31 Mar). `syncRecurrences` materializa compromissos até um horizonte (90 dias na UI) e `UNIQUE(rule_id, occurrence_date)` garante idempotência mesmo com execuções repetidas.
Motivo: evita saltos de dia e duplicação de ocorrências. A sincronização corre ao abrir o planeamento e no botão de atualização; falhas mostram `AppFailure` sem bloquear a lista. Depois de existirem ocorrências, alterar tipo, frequência ou início é rejeitado — evita reinterpretar ocorrências já materializadas; valor, descrição, conta, categoria e fim continuam editáveis.

## ADR-021 — Integridade entre movimentos e alocações
**Estado:** aceite na Fase 03. Editar ou eliminar um movimento alocado atualiza a alocação correspondente e o estado do compromisso/dívida na mesma transação: o novo total não pode ficar abaixo do já pago nem acima do valor; eliminar remove a alocação e reabre o compromisso/dívida; ocorrências de recorrência voltam a `planned`. Sem pagamentos, cancelar um compromisso preserva a previsão (nada é apagado).
Motivo: sem isto, saldos e estados divergiriam e a app poderia mostrar dívida paga com movimento eliminado, ou permitir pagar duas vezes o mesmo valor. As validações vivem no repositório porque dependem de agregações entre tabelas.

## ADR-022 — Orçamentos calculados em SQL
**Estado:** aceite na Fase 03. O orçamento guarda apenas o limite mensal por categoria; o gasto é `SUM(amount)` de movimentos `expense` não eliminados no intervalo `[period_start, +1 month)`. Transferências e rendimentos ficam de fora. `UNIQUE(category_id, period_type, period_start)` transforma "criar" em upsert do limite.
Motivo: um valor de gasto guardado dessincronizaria ao editar/eliminar movimentos. O cálculo reutiliza os índices de `transactions` e a mesma política de eliminação lógica. O mês corrente é o único apresentado na Fase 03, com navegação para meses anteriores/seguintes.

## ADR-023 — Metas de poupança medidas pelo saldo real
**Estado:** aceite na Fase 03. Uma meta tem alvo, data opcional e conta associada opcional; o progresso é o saldo atual dessa conta (calculado por `AccountRepository`), nunca um valor introduzido nem uma despesa.
Motivo: evita dupla contagem e mantém uma única regra de saldo (ADR-018). Sem conta associada, o progresso é zero e a meta funciona como objetivo abstrato. Arquivar apenas oculta a meta; conta e movimentos ficam intactos.

## ADR-024 — Dívidas liquidadas por pagamentos reais
**Estado:** aceite na Fase 03. O pendente de uma dívida é o valor original menos os pagamentos cujo movimento não está eliminado. Cada liquidação cria exatamente um movimento (`expense` para dívida a pagar, `income` para dívida a receber) e uma linha em `debt_payments` (`UNIQUE(transaction_id)`), nunca excedendo o pendente. Dívida cancelada ou liquidada não aceita novos pagamentos.
Motivo: o caixa só muda com dinheiro real; o estado deriva dos pagamentos, pelo que eliminar um movimento reabre a dívida de forma consistente. O cancelamento mantém os movimentos já feitos e apenas retira a dívida da lista de pendentes.

## ADR-025 — Alertas locais apenas dentro da app
**Estado:** aceite na Fase 03. O planeamento mostra alertas derivados dos streams: compromissos vencidos ou a vencer em 7 dias, dívidas vencidas e orçamentos excedidos. Não há plugin de notificações do sistema, nem agendamento em background.
Motivo: cumprir "alertas locais opcionais" sem novas dependências nem pedidos de permissão, mantendo tudo offline e privado. Os alertas desaparecem assim que o estado muda, porque usam os mesmos providers das listas.

## ADR-026 — Motor de previsão determinístico sem snapshots
**Estado:** aceite na Fase 04. A previsão é calculada em Dart puro (`ForecastEngine`) sobre um `ForecastRequest`: data de corte, saldo consolidado real, compromissos em aberto e despesas históricas. O horizonte predefinido é 30 dias, com 7 e 90 dias disponíveis. Não há Python, ML, rede nem aleatoriedade; a versão do algoritmo é `forecast-1`.
Regras:
- Data de corte = dia atual; saldo de partida = saldo consolidado das contas ativas na moeda configurada (ADR-018).
- Compromissos entram pelo valor em falta (`amount − pago`); pagos e cancelados ficam de fora. Vencidos entram no dia de corte, não no passado.
- Pagamentos já realizados alteram o saldo de partida e não são deduzidos outra vez.
- Ocorrências recorrentes são materializadas até ao horizonte máximo através de `syncRecurrences`, que é idempotente (ADR-020); o motor não as recria nem as projeta em paralelo.
- Transferências não entram: não alteram o saldo consolidado (ADR-008).
- O dia 0 aplica apenas compromissos confirmados; os dias seguintes aplicam compromissos e estimativas. Os montantes diários são repartidos pro rata pelo mês, com arredondamento inteiro cumulativo.
- `ForecastBundle` inclui data de corte, instante de geração, parâmetros e os três resultados. O resultado é reproduzível sem guardar snapshots; a persistência de uma fotografia fica para quando existir um caso de uso concreto (comparação histórica ou exportação).

## ADR-027 — Estimativas por mediana mensal com limiar de qualidade
**Estado:** aceite na Fase 04. As estimativas históricas usam apenas despesas não eliminadas dos últimos três meses civis completos. O histórico é considerado suficiente com pelo menos 3 meses com despesas e 6 movimentos de despesa; caso contrário, a previsão usa só compromissos conhecidos e explica a limitação.
Método:
- Cada categoria é estimada pela mediana dos totais mensais da janela, incluindo meses sem despesas dessa categoria como zero; a categoria só é estimada se aparecer em pelo menos 2 meses e a mediana for positiva.
- Categorias com compromissos conhecidos dentro do horizonte ficam fora das estimativas, para não duplicar o mesmo gasto.
- Rendimentos e transferências ficam de fora; as estimativas representam apenas despesa variável.
- O resultado indica meses e movimentos observados, categorias estimadas, total mensal estimado, pressupostos e limitações; o motor nunca apresenta estas regras como "IA".
Motivo: uma mediana resiste a valores extremos e não exige parâmetros estatísticos opacos. O limiar evita inventar padrões com poucos dados, cumprindo "não inventar histórico". Cenários base/prudente/otimista não foram introduzidos porque exigiriam pressupostos adicionais explícitos e ainda não há dados para os justificar; a evolução para modelos estatísticos segue o ADR-012, com backtesting temporal.

## ADR-028 — Backup JSON versionado com validação e restauro atómico
**Estado:** aceite na Fase 05. O backup é um documento JSON UTF-8 legível (`format: financas_pessoais_backup`, `formatVersion: 1`, `schemaVersion: 4`, `appVersion`), não uma cópia binária do ficheiro SQLite. Inclui as 12 tabelas de dados do utilizador, as configurações (`app_settings`), contagens por tabela e um checksum FNV-1a de 32 bits. `schema_migrations` fica de fora: descreve a migração da base, não o conteúdo.
Regras:
- A validação verifica JSON, formato, versão do formato, versão **exata** do esquema, tipos de cada coluna, contagens e checksum; qualquer falha produz `AppFailure` sem alterar a base.
- O restauro relê e revalida o ficheiro imediatamente antes de substituir; uma alteração externa entre a listagem e o toque é apanhada.
- Antes de substituir, é sempre escrita uma cópia `pre-restore-…json` da base atual; essa cópia é um backup normal e serve para desfazer.
- A substituição corre numa única transação SQLite: `DELETE` pela ordem inversa das dependências, `INSERT` pela ordem pai → filho, verificação das contagens e `PRAGMA foreign_key_check`. Qualquer erro faz rollback e mantém a base atual; nunca fica uma base parcial.
- Backups de outra versão do esquema são recusados em vez de interpretados à força; migrar o documento será um passo explícito quando existir uma versão nova.
Motivo: IDs, relações e montantes preservam-se sem depender de detalhes binários do SQLite, e o ciclo completo é testável em memória. O checksum deteta corrupção acidental, não é uma assinatura criptográfica (ADR-030). Não foi introduzida dependência nova.

## ADR-029 — Relatórios agregados na leitura e exportação CSV local
**Estado:** aceite na Fase 05. O relatório é calculado em Dart a partir de `TransactionRepository.readMovements` no intervalo escolhido — este mês, mês anterior, últimos três meses ou intervalo personalizado — sem tabela de agregados. Rendimentos e despesas somam por categoria e por conta; transferências ficam fora do rendimento, da despesa e do resultado, mas aparecem como entradas/saídas nas contas envolvidas. Os grupos são ordenados por volume decrescente.
A exportação CSV é gerada em memória e escrita na pasta `exports` apenas por ação do utilizador: UTF-8 com BOM, separador `;`, fim de linha CRLF, datas `DD/MM/YYYY`, montantes inteiros FCFA, rótulos portugueses e aspas duplicadas nos campos. Movimentos eliminados ficam de fora. O ficheiro nunca é transmitido; PDF fica para uma fase futura (SPEC §3).
Motivo: uma única política de agregação evita divergência entre o ecrã e o ficheiro exportado. O formato com `;` e BOM abre corretamente em folhas de cálculo em português sem importação manual. As consultas reutilizam os índices da lista de movimentos.

## ADR-030 — Sem PIN/biometria; bloquear a interface não cifra a base
**Estado:** aceite na Fase 05. Esta versão não implementa PIN nem biometria. As definições explicam que a base SQLite e os ficheiros de backup/exportação não são cifrados e ficam legíveis num dispositivo desbloqueado ou com root; um eventual bloqueio de interface seria apenas uma barreira visual, não cifragem. Não é criada criptografia própria.
A aplicação não pede permissões de armazenamento: usa a pasta externa específica da aplicação no Android (ou documentos no desktop) e só escreve quando o utilizador cria um backup ou exporta um relatório. O checksum do backup não é apresentado como segurança. Se PIN/biometria forem introduzidos, usarão APIs seguras da plataforma para bloquear o acesso, mantendo explícita a limitação da base não cifrada.
**Nota (Fase 07):** o ADR-037 introduz um bloqueio opcional ao abrir, delegado nas credenciais do sistema. A base SQLite e os ficheiros de backup/exportação continuam sem cifra, pelo que a limitação central deste ADR permanece.
Motivo: cumprir "PIN/biometria só com APIs seguras" sem prometer uma proteção que a versão não oferece, e documentar as limitações de proteção local exigidas na Fase 05.

## ADR-031 — Build de release assinado fora do repositório
**Estado:** aceite na Fase 06. O Gradle lê `android/key.properties` (ignorado pelo Git, com `android/key.properties.example` sem valores reais) e, quando o ficheiro existe, assina o release com essa chave. Sem o ficheiro, o release usa a chave de debug apenas para validação local; esse APK não deve ser distribuído. Nenhuma credencial é embutida no código, no APK ou no repositório. O rótulo Android passa a "Finanças Pessoais" e o manifesto de release continua sem a permissão `INTERNET`.
Regras:
- `key.properties`, `*.jks` e `*.keystore` ficam fora do controlo de versões.
- O build de release só é gerado depois de formatação, análise e testes verdes.
- Instalar um APK com assinatura diferente da anterior obriga a desinstalar e perde a base privada; o manual exige backup antes da atualização.
Motivo: preparar a distribuição Android sem publicar automaticamente nem expor segredos, mantendo um caminho reproduzível para validar o build localmente.

## ADR-032 — Design system com tokens e política de apresentação de dados
**Estado:** aceite. A aplicação passa a ter uma linguagem visual única em `lib/app/theme` — tokens de espaçamento e raios, tema Material 3 claro/escuro com identidade teal e superfícies areia, e a extensão `FinanceColors` para rendimento, transferência, aviso e saldo positivo. Os ecrãs compõem componentes partilhados (`MoneyText`, `SectionCard`, `AppDataRow`, `StatusBadge`, `EmptyState`) e não redefinem cores, raios, espaçamentos ou formatos. Referência completa: [DESIGN.md](DESIGN.md).
Regras de apresentação:
- Montantes exatos com agrupamento e `FCFA` em listas, formulários, detalhes, relatórios e exportações; notação compacta (`1,25 M FCFA`) apenas em cartões de resumo, com o valor exato preservado na semântica e nos detalhes.
- Algarismos tabulares e alinhamento à direita; sinal explícito em variações e saldos negativos.
- Percentagens em `pt_PT`, no máximo uma casa decimal, acompanhadas de estado textual e barra de progresso; contagens sempre pluralizadas.
- Datas apresentadas `DD/MM/YYYY`; listas de movimentos agrupadas por dia com total diário.
- Transferências, planeamento e previsão mantêm cores e rótulos próprios; a cor nunca é o único indicador de estado.
Motivo: os ecrãs tinham estilos e formatos locais divergentes, o que tornava a comparação de valores difícil e a manutenção repetitiva. Centralizar tokens, componentes e formatters garante consistência, contraste nos dois modos e uma única regra testável para montantes, percentagens e datas. A alteração é apenas de apresentação: não muda o esquema SQLite, as regras financeiras nem a privacidade offline. Custo aceite: um novo ecrã deve reutilizar os componentes existentes em vez de criar o seu próprio estilo.

## ADR-033 — Identidade visual Nô Dinheru e ícones gerados sem dependências
**Estado:** aceite. A aplicação passa a apresentar-se como **Nô Dinheru**, com o slogan “O teu dinheiro, sob controlo.”, ícone de moeda esmeralda com aro dourado, letra N branca e moeda dourada sobreposta. A paleta oficial (`#087F5B`, `#104B3C`, `#E8C66A`, `#F5F8F5`, `#182923`, `#E47768`) substitui as superfícies areia e o teal anterior; `FinanceColors` foi harmonizada mantendo o contraste semântico nos dois modos. Referência completa: [DESIGN.md](DESIGN.md).
Regras:
- Os recursos mestres ficam em `assets/branding/`; Android recebe ícones legacy por densidade, ícone adaptativo (foreground + cor de fundo) e splash; iOS recebe `AppIcon.appiconset` em todos os tamanhos.
- Os ícones são gerados a partir do mestre com ferramentas locais; não é adicionada a dependência `flutter_launcher_icons` nem qualquer pacote novo.
- `applicationId`/bundle identifier mantêm-se (`ao.gb.financas_pessoais`); apenas o nome visível passa a “Nô Dinheru”. O rótulo “Finanças Pessoais” do ADR-031 fica substituído.
- O logótipo completo é usado no arranque pré-Android 12 e na secção **Sobre** das definições; no Android 12+ o splash do sistema mostra apenas o ícone. O ícone isolado fica reservado ao launcher e a contextos compactos.
- A alteração é apenas de apresentação: não modifica lógica financeira, esquema SQLite, backups, exportações, privacidade offline nem dados existentes.
Motivo: consolidar a marca antes do lançamento, garantir legibilidade em tamanhos pequenos e manter o projeto livre de dependências gráficas adicionais. Custo aceite: qualquer alteração futura ao mestre obriga a regenerar os tamanhos Android/iOS.

**Nota:** o ADR-032 descreve a estrutura do design system; a sua paleta teal/areia é substituída por este ADR.


## ADR-034 — Ícone oficial aprovado e splash ligado à inicialização
**Estado:** aceite. A arte aprovada da marca passa a ser o ícone fornecido pela equipa — quadrado esmeralda arredondado, “N” branco, aro/mancha dourada e pilha de moedas — e substitui a arte gerada referida no ADR-033. Os ícones Android (legacy e adaptativo), o `AppIcon.appiconset` iOS, o ícone `foreground`, os logótipos de Sobre e o lockup do splash foram regenerados a partir dessa arte com ferramentas locais. Não foi adicionada qualquer dependência (`flutter_launcher_icons` continua ausente) e `applicationId`/bundle identifier mantêm-se.
O arranque passa a ter duas camadas contínuas:
- **Nativo:** fundo `#087F5B`; pré-Android 12 mostra o lockup completo (quadrado branco, ícone, nome, slogan e “Finanças pessoais • Guiné-Bissau”); Android 12+ mostra apenas o ícone, por limitação do sistema. No iOS, a `LaunchScreen` usa o mesmo fundo e o mesmo lockup.
- **Flutter:** `SplashPage` reproduz a composição com animações discretas (fade-in e escala do ícone; nome, slogan e identificação por fases) e `SplashGate` mantém-na por cima da aplicação até `appStartupProvider` terminar — abrir a base SQLite com as migrações e carregar as definições — e a animação de entrada completar; depois desvanece em 320 ms. Não é usado nenhum temporizador para atrasar artificialmente a abertura. Falhas de inicialização não prendem o utilizador: o splash sai e o painel mostra a falha recuperável já existente.
- O splash usa `BrandColors` fixas para ser igual em modo claro e escuro; com animações desativadas no sistema apresenta a composição estática. O conteúdo adapta-se ao lado mais curto do ecrã e pode rolar em alturas reduzidas.
- A alteração é apenas de apresentação: não muda o esquema SQLite, os cálculos financeiros, a navegação, os backups, a privacidade offline nem os dados existentes.
Motivo: usar a arte oficial sem a alterar, manter uma abertura profissional e contínua em Android/iOS e garantir que a aplicação só é revelada depois de a base local estar pronta. Custo aceite: alterações futuras à arte obrigam a regenerar todos os tamanhos e o lockup nativo; no Android 12+ o sistema nunca mostra a composição completa no splash nativo.


## ADR-035 — Barra inferior adaptativa com etiquetas de linha única
**Estado:** aceite. A barra de navegação deixa de usar `NavigationBar` diretamente e passa a usar `AppNavigationBar` (`lib/app/shell/app_navigation_bar.dart`). O `NavigationBar` do Material 3 não limita a etiqueta a uma linha: em ecrãs estreitos, ou com texto ampliado, “Movimentos” quebrava em duas linhas e desalinhava os destinos. Na nova barra cada etiqueta é renderizada numa única linha com `FittedBox(scaleDown)`, encolhendo apenas o necessário para caber na largura do destino.
Regras:
- A barra mantém o aspeto do `navigationBarTheme` (altura 72, fundo, indicador arredondado, cores e pesos das etiquetas e ícones) e adapta a largura do indicador à largura de cada destino.
- Cada destino expõe `Semantics(button, selected, label, onTap)` para leitores de ecrã; o toque continua a cobrir toda a área do destino.
- O encolhimento da etiqueta é a última linha de defesa: em larguras normais o texto mantém o tamanho do tema; em 320 dp com texto a 130% continua legível numa linha, sem quebras nem truncagem.
- Navegação, rotas e lógica financeira não mudam; apenas o widget de apresentação da barra. Testes: `test/widget/app_navigation_bar_test.dart` cobre 320×568 com texto a 130% e o toque nos destinos.
Motivo: os cinco destinos são fixos e os seus nomes não podem ser abreviados sem perder clareza; quebrar a etiqueta desalinha a barra e esconde conteúdo. Custo aceite: a barra deixa de herdar automaticamente futuras alterações internas do `NavigationBar` do Flutter, pelo que deve ser mantida em paralelo com o `navigationBarTheme`.

## ADR-036 — Sem permissões de armazenamento; importação por seletor de ficheiros
**Estado:** aceite. A aplicação mantém-se sem permissões de armazenamento no manifesto de release. No Android, a base privada, os backups e as exportações continuam na pasta específica da aplicação (`Android/data/ao.gb.financas_pessoais`, via `getExternalStorageDirectory`), que não exige autorização; a partir do Android 11 essa pasta fica oculta nos gestores de ficheiros e na transferência USB (MTP).
Para recuperar dados de outro dispositivo, a página de backup passa a ter **Importar de um ficheiro**, que usa `file_selector` 1.1.0 (plugin oficial Flutter) para abrir o seletor de documentos do sistema — Storage Access Framework no Android. O utilizador autoriza apenas o ficheiro escolhido; a aplicação não recebe acesso a pastas nem declara permissões. O conteúdo passa por `BackupSnapshot.decode` e por `BackupService.restoreExternal`, que reutiliza a mesma cópia `pre-restore-…json` e a mesma transação atómica do restauro local. O ficheiro importado não é copiado para a pasta `backups`; é restaurado diretamente.
Regras:
- Não são declaradas `READ_EXTERNAL_STORAGE`, `WRITE_EXTERNAL_STORAGE`, `MANAGE_EXTERNAL_STORAGE` nem permissões equivalentes no Android, nem se pede acesso global a ficheiros.
- O manifesto de release continua sem `INTERNET`; `file_selector` apenas abre seletores nativos e não faz chamadas de rede.
- A validação do ficheiro importado é a mesma do restauro local (formato, versão, esquema, tipos, contagens e checksum) e qualquer falha não altera a base.
- Os textos de Definições e Backup explicam que a pasta `Android/data` está oculta em Android 11+ e que a retirada de ficheiros exige `adb pull`.
Motivo: pedir armazenamento amplo seria desproporcionado para uma app offline que só precisa dos próprios ficheiros, e o SAF é a autorização mínima suportada. A importação resolve a limitação prática de a pasta `Android/data` estar oculta em Android 11+, permitindo recuperar um backup copiado para Downloads. Custo aceite: retirar backups e exportações do dispositivo em Android 11+ exige depuração USB (`adb`); não há partilha integrada. Testes: `test/unit/backup/backup_service_test.dart` (importação válida e inválida) e `test/widget/backup_flow_test.dart` (fluxo completo com seletor simulado).

## ADR-037 — Bloqueio ao abrir com as credenciais do dispositivo
**Estado:** aceite na Fase 07. A aplicação passa a poder exigir o desbloqueio do telefone antes de revelar os dados, através do plugin oficial `local_auth` 3.0.2. A preferência `lock_on_open` é guardada na tabela de configurações (`app_settings`, sem migração), vem desligada por omissão e só se aplica na abertura seguinte. O bloqueio usa o PIN, padrão, palavra-passe ou biometria geridos pelo sistema (`biometricOnly: false`), nunca um PIN próprio da app.
Regras:
- O `AppLockGate` envolve o conteúdo do router e, quando bloqueado, apresenta um ecrã opaco com a marca, `AbsorbPointer` e `ExcludeSemantics` sobre a aplicação; nenhum dado financeiro fica visível ou acessível. O pedido de desbloqueio é automático depois de o splash terminar e pode ser repetido no botão.
- O estado vive em memória: abrir a app bloqueia sempre que a preferência está ativa; regressar de segundo plano bloqueia após 60 segundos (constante de produto). Regressos mais curtos, como o seletor de ficheiros, mantêm a sessão.
- Cancelar ou falhar a autenticação mantém o ecrã de bloqueio. Se o dispositivo deixar de ter credenciais configuradas, o ecrã explica a situação e permite abrir sem bloqueio, para não deixar o utilizador preso fora da própria app; o interruptor fica desativado.
- A verificação é feita pelo sistema; a app recebe apenas o resultado e não guarda PIN nem dados biométricos. O plugin não abre rede nem ficheiros.
- Android: `MainActivity` passa a `FlutterFragmentActivity`, o manifesto declara `USE_BIOMETRIC` (permissão normal, sem pedido em execução) e os temas nativos herdam de `Theme.AppCompat` com `androidx.appcompat`. iOS: `NSFaceIDUsageDescription`. O release continua sem `INTERNET` e sem permissões de armazenamento.
- O bloqueio é apenas de interface: a base SQLite, os backups e as exportações continuam sem cifra (ADR-030). Um backup restaurado com `lock_on_open` ativo passa a pedir o desbloqueio no dispositivo atual, com as credenciais locais.
Motivo: dar uma proteção proporcional para uso individual num telefone partilhado ou emprestado, sem criar criptografia própria nem prometer proteção contra acesso aos ficheiros. Custo aceite: nova dependência nativa, migração dos temas para AppCompat e mais um passo ao abrir. Testes: `test/unit/security/app_lock_controller_test.dart`, `test/unit/settings/app_settings_repository_test.dart` e `test/widget/app_lock_test.dart`.

## ADR-038 — Backup fora do dispositivo por seletor de gravação do sistema
**Estado:** aceite. A página de backup passa a ter **Guardar backup em…**, que cria um backup novo e abre o seletor de gravação do sistema com o nome preenchido. O destino pode ser Downloads, cartão SD, Google Drive, OneDrive ou qualquer fornecedor instalado; a aplicação não escolhe nem conhece o destino final. No Android é usado o Storage Access Framework (`ACTION_CREATE_DOCUMENT`), pelo que a app escreve apenas no ficheiro autorizado e continua sem permissões de armazenamento e sem `INTERNET` no release.
Regras:
- O plugin `file_selector` usado para importar não implementa `getSaveLocation` no Android; a gravação usa `file_picker` 13.3.0, que também escreve os bytes no desktop. A importação continua em `file_selector`; não há dois seletores para a mesma operação.
- O ficheiro é o mesmo JSON versionado do backup local e é validado pelo mesmo `BackupSnapshot.decode`; a gravação não altera a base.
- É mantida uma cópia na pasta local `backups`. Se o utilizador cancelar o seletor, a cópia local permanece e a interface informa que nada foi guardado fora.
- A aplicação não faz upload nem sincronização. Se o destino for um serviço de nuvem, a transferência é feita por esse serviço, com a conta e as regras do utilizador; os documentos de privacidade explicam esta diferença.
- O backup continua sem cifra e sem assinatura; o checksum deteta apenas corrupção acidental. Guardar no Drive não acrescenta cifragem.
Motivo: resolver o cenário real de perda ou troca de telefone sem introduzir rede na aplicação, OAuth, backend ou uma nova promessa de privacidade. O seletor do sistema é a autorização mínima e funciona com qualquer fornecedor, incluindo dispositivos sem Google Play Services. Custo aceite: nova dependência (`file_picker`); a retenção e a sincronização do destino não são controladas pela app. Testes: `test/widget/backup_flow_test.dart` cobre gravação no destino escolhido e cancelamento com cópia local.
