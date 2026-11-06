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

## ADR-039 — Backup automático do Android desativado
**Estado:** aceite. O manifesto principal declara `android:allowBackup="false"`. O sistema deixa de copiar a base SQLite e as preferências para a conta Google; a recuperação passa a depender apenas dos backups JSON criados pelo utilizador.
Regras:
- A app não usa o backup do sistema como funcionalidade: não há restauro automático ao reinstalar nem cópia para a nuvem sem ação do utilizador.
- A decisão não cifra a base nem os ficheiros; apenas impede a cópia automática pelo Android. Um backup guardado pelo seletor continua legível no destino escolhido (ADR-038).
- Em Android 12+, alguns fabricantes podem manter a migração direta entre telefones durante a configuração; a app não controla essa cópia do sistema e a documentação de privacidade explica a exceção.
Motivo: manter coerente a promessa de que os dados financeiros ficam no dispositivo, sem depender de uma opção do sistema que o utilizador não vê. Custo aceite: perder o restauro automático do Android; a app já oferece backup próprio e importação noutro telefone. Testes: inspeção do manifesto fundido no APK e documentação em `docs/PRIVACY.md` e `docs/BACKUP.md`.

## ADR-040 — CSV guardado pelo seletor do sistema
**Estado:** aceite. A página de relatórios mantém **Exportar CSV** para a pasta `exports` e acrescenta **Guardar CSV em…**, que grava o mesmo relatório pelo seletor do sistema.
Regras:
- O ficheiro continua a ser criado primeiro na pasta `exports`, com UTF-8, BOM, `;` e CRLF; a gravação externa usa exatamente `ReportCsv.encode`, sem recodificar, para não perder o BOM.
- No Android é usado o mesmo `ACTION_CREATE_DOCUMENT` do backup, através do componente partilhado `saveFileWithSystemPicker`; não há novas permissões nem acesso a pastas.
- Cancelar o seletor mantém a cópia em `exports` e a interface informa que nada foi guardado fora. Falhas mostram mensagem genérica e preservam a cópia local.
- A aplicação não faz upload; se o destino for um serviço de nuvem, a transferência é feita por esse serviço (ADR-038).
Motivo: em Android 11+ a pasta `Android/data` fica oculta, pelo que o CSV era inacessível sem `adb pull`. Reutilizar o seletor resolve a limitação sem introduzir rede. Custo aceite: mais um botão e uma dependência já existente (`file_picker`). Testes: `test/widget/reports_flow_test.dart` cobre gravação no destino escolhido e cancelamento com cópia local.

## ADR-041 — Pesquisa livre em movimentos feita na base de dados
**Estado:** aceite. A lista de movimentos passa a ter pesquisa textual no topo, combinável com os filtros existentes. O texto é procurado na descrição, nas notas, no nome da categoria, no nome da conta e no nome da conta de destino das transferências.
Regras:
- A pesquisa é executada em SQL (`LIKE … ESCAPE '\'`), não em memória, para funcionar com o mesmo filtro de período/conta/tipo/categoria e com listas grandes.
- Os caracteres `%` e `_` e a própria barra invertida são escapados antes de entrarem no padrão, pelo que são tratados como texto literal e não como curingas.
- A pesquisa é aplicada no repositório (`watchMovements`), pelo que a exportação e qualquer contagem usam a mesma regra; fechar o campo limpa o texto e repõe a lista.
- Os filtros guardados no controlador preservam a pesquisa ao mudar período, conta, tipo ou categoria; limpar os filtros limpa também a pesquisa.
- O estado vazio distingue “sem movimentos” de “sem resultados para a pesquisa”.
Motivo: encontrar um movimento por descrição, nota, categoria ou conta é a operação mais frequente depois de listar; fazê-la na base evita carregar tudo e duplicar regras de filtragem. Custo aceite: `LIKE` sem índice de texto é linear no número de movimentos, suficiente para uso pessoal. Testes: `test/unit/repositories/transaction_repository_test.dart` cobre os cinco campos, curingas literais e combinação com filtros.

## ADR-042 — Lixeira com restauro e eliminação definitiva
**Estado:** aceite. A eliminação de movimentos deixa de ser definitiva na lista: passa a mover para a **Lixeira**, acessível pelo topo de Movimentos. Na lixeira é possível restaurar ou eliminar definitivamente, com confirmação.
Regras:
- Mover para a lixeira mantém a eliminação lógica existente (`deleted_at`), pelo que os saldos deixam de contar o movimento imediatamente, tal como antes.
- As linhas de afetação (`planned_item_payments`, `debt_payments`) deixam de ser apagadas no soft delete e são preservadas. Restaurar volta a ligar o movimento ao compromisso ou à dívida e recalcula o estado; eliminar definitivamente remove as afetações e atualiza os agregados.
- O restauro recusa movimentos ligados a compromissos ou dívidas cancelados e recusa valores que fariam o total pago exceder o montante do compromisso ou da dívida. A recusa não altera nada e é explicada na interface.
- A eliminação definitiva só existe na lixeira e volta a validar que o movimento já está eliminado; a lixeira ordena pelo momento da eliminação, mais recente primeiro.
- Um movimento na lixeira não entra em saldos, relatórios, orçamentos, previsão nem exportações.
Motivo: o toque acidental e a correção de um lançamento são erros comuns e a eliminação imediata perdia histórico e ligações a compromissos. A lixeira dá uma segunda oportunidade sem introduzir um segundo modelo de dados. Custo aceite: mais um ecrã e dois passos para eliminar de vez. Testes: `test/unit/repositories/transaction_repository_test.dart` (listar, restaurar, eliminar definitivamente e recusar ativo), `test/unit/repositories/allocation_integrity_test.dart` (religação de pagamentos e conflito de limite) e `test/widget/movements_flow_test.dart` (fluxo pesquisa → lixeira → restauro).

## ADR-043 — Alteração estrutural de recorrências reconstrói apenas o futuro
**Estado:** aceite. Depois de uma recorrência ter ocorrências materializadas, o tipo, a frequência, o início e o fim voltam a ser editáveis. Guardar uma alteração estrutural pede confirmação e reconstrói apenas as ocorrências futuras sem pagamentos.
Regras:
- São reconstruídas as ocorrências com data posterior a hoje que ainda não têm pagamento nem estão parciais; as ocorrências passadas, pagas ou canceladas mantêm-se intactas.
- Se existir alguma ocorrência futura com pagamentos, a alteração estrutural é recusada com uma mensagem que indica o que fazer; não são apagados pagamentos.
- As ocorrências futuras são removidas na ordem correta (ocorrência antes do compromisso referido) e o `nextOccurrenceDate` é recalculado a partir do primeiro dia da nova agenda que ainda não esteja materializado.
- Alterações não estruturais (valor, descrição, conta e categoria) continuam a propagar-se a todas as ocorrências pendentes, sem confirmação e sem reconstrução.
- A interface mostra a confirmação “Reconstruir ocorrências futuras?” e explica o alcance da operação antes de guardar.
Motivo: bloquear a estrutura depois da primeira ocorrência obrigava a criar uma regra nova e a perder a continuidade quando o utilizador se enganava na frequência ou no início. Reconstruir só o futuro mantém o histórico e os pagamentos. Custo aceite: uma confirmação adicional e a recusa quando há pagamentos futuros. Testes: `test/unit/repositories/planning_repository_test.dart` (reconstrução semanal, propagação de valores e bloqueio com pagamento futuro) e `test/widget/planning_flow_test.dart` (diálogo de confirmação e frequência atualizada).

## ADR-044 — Lembretes locais agendados pelo sistema, sem rede
**Estado:** aceite. A aplicação passa a poder avisar no telemóvel os vencimentos de compromissos e os orçamentos excedidos, através de notificações locais do Android/iOS. A funcionalidade vem desligada e só é ativada nas definições, onde a permissão de notificações é pedida.
Regras:
- **O que é agendado:** para cada compromisso em aberto com vencimento entre hoje e 365 dias, dois avisos — um na véspera e outro no dia do vencimento, à hora configurada (09:00 por omissão). Compromissos pagos, cancelados ou já vencidos são ignorados. Se existir algum orçamento do mês atual excedido, é agendado um único resumo no último dia do mês, com o nome das categorias e o atalho `/planning/budgets`.
- **Datas estáveis:** o identificador de cada notificação deriva de uma chave estável (`FNV-1a` de 31 bits) que combina o compromisso, a data de vencimento e o tipo de aviso. Antes de reagendar, a aplicação cancela apenas notificações pendentes e volta a criar as mesmas datas; repetir a sincronização não produz duplicados nem avisos repetidos. As notificações já entregues ficam na gaveta até serem dispensadas.
- **Quando sincroniza:** no arranque da aplicação e, com os lembretes ligados, quando a lista de compromissos pendentes ou os orçamentos do mês mudam (com debounce de 500 ms). A sincronização nunca bloqueia a interface.
- **Permissão:** é pedida apenas ao ligar o interruptor nas definições. Se for recusada, a preferência continua desligada e a interface explica onde ativar a permissão. No arranque nunca há pedidos automáticos. Se o sistema tiver as notificações desligadas, a aplicação cancela as pendentes e as definições mostram um aviso; um backup restaurado com lembretes ligados não agenda nada até a permissão existir.
- **Preferência local:** `reminders_enabled` e `reminder_time` (`HH:mm`) ficam em `app_settings`, sem migração. Uma hora inválida volta às 09:00. As chaves viajam no backup como as restantes configurações, mas a permissão é sempre do telefone que restaura.
- **Android:** alarmes inexatos (`inexactAllowWhileIdle`), pelo que não é exigida a permissão de alarmes exatos nem acesso especial; a entrega pode atrasar até ao fim da janela do sistema. Usa o canal “Lembretes” com importância alta, categoria de lembrete e visibilidade privada no ecrã de bloqueio. Declara `POST_NOTIFICATIONS` (pedida em execução) e `RECEIVE_BOOT_COMPLETED`; os recetores do plugin voltam a agendar após reinício, atualização da aplicação e arranque rápido. O plugin exige desugaring do Java (`desugar_jdk_libs`).
- **iOS:** o delegado `UNUserNotificationCenter` é ligado no arranque e a permissão é pedida só ao ativar; as pré-visualizações no ecrã de bloqueio dependem das definições do sistema.
- **Privacidade:** não há rede, servidor, conta nem telemetria. O título e o corpo são calculados no dispositivo e incluem descrição, montante e conta; quem alterar as pré-visualizações do sistema pode ver esse conteúdo no ecrã de bloqueio.
Motivo: os avisos dentro da aplicação só são vistos quando a app está aberta, o que não serve para pagar a tempo. Notificações locais resolvem o problema sem enviar dados para fora nem exigir um serviço de push. Custo aceite: a entrega é gerida pelo sistema (pode atrasar com o telefone em poupança de energia), o utilizador tem de autorizar notificações e um pedido futuro de sincronização real terá de reconciliar a preferência com a permissão de cada dispositivo. Testes: `test/unit/planning/reminder_planner_test.dart` (véspera, dia, rendimento, horários passados, horizonte, resumo de orçamentos e estabilidade dos IDs), `test/unit/planning/reminder_coordinator_test.dart` (suporte, permissão, ativação, cancelamento e hora), `test/unit/settings/app_settings_repository_test.dart` (predefinições e hora inválida) e `test/widget/reminders_flow_test.dart` (interruptor, recusa de permissão, plataforma sem suporte e aviso de permissão restaurada). Validação em emulador: alarmes `RTC_WAKEUP` do `ScheduledNotificationReceiver` criados para os vencimentos, cancelados ao desligar e repostos ao ligar; pedido de permissão apresentado ao ativar.

## ADR-045 — Backup cifrado com frase-passe, base em claro
**Estado:** aceite. A criação de backup passa a oferecer dois formatos: **cifrado com frase-passe** (predefinido) e **sem cifra**. O conteúdo é o mesmo documento JSON simples, mas no modo cifrado é envolvido num envelope autenticado com AES-256-GCM. A base SQLite em uso e as exportações CSV continuam sem cifra.
Regras:
- **Escolha por criação:** o diálogo de criação pergunta a proteção antes de escrever. Cada backup ficheiro é cifrado ou simples de forma independente; não há preferência persistente nem migração de ficheiros antigos.
- **Chave:** deriva da frase-passe escolhida pelo utilizador com PBKDF2-HMAC-SHA256, 210 000 iterações e 256 bits, com sal aleatório de 16 bytes por ficheiro. A frase-passe nunca é guardada nem enviada, não existe recuperação e o esquecimento obriga a usar outro backup ou a cópia `pre-restore`.
- **Cifra:** AES-256-GCM com nonce aleatório de 12 bytes e MAC de 16 bytes. O cabeçalho (`format`, `formatVersion`, `cipher`, `kdf`, `iterations`, `salt`, `nonce`) é autenticado como dados associados (AAD), pelo que alterar o cabeçalho invalida a decifragem. O envelope não expõe nomes de contas, montantes nem qualquer metadado do utilizador.
- **Formato:** `format: financas_pessoais_backup_encrypted`, `formatVersion: 1`, campos em base64. O documento interior mantém `financas_pessoais_backup` v1 e o esquema v4, pelo que a validação, a pré-visualização, as contagens e o checksum continuam a correr depois de decifrar.
- **Compatibilidade:** backups simples anteriores continuam a listar e a restaurar. A lista deteta o envelope sem o decifrar e mostra um cadeado; abrir, importar ou restaurar um backup cifrado pede a frase-passe e valida-a antes de mostrar a pré-visualização. Cancelar não altera dados.
- **Limites de parâmetros:** a decifragem aceita entre 100 000 e 1 000 000 iterações e rejeita versões futuras, cifras ou KDF desconhecidos e comprimentos de sal, nonce ou MAC errados, para evitar ficheiros malformados e custo excessivo. Uma frase errada, um MAC inválido ou um cabeçalho alterado devolvem a mesma mensagem.
- **Cópias automáticas:** o restauro continua a criar `pre-restore-…json` em claro antes de substituir, com a mesma proteção da base privada da aplicação. É esse ficheiro que permite voltar atrás; quem precisar de o guardar fora deve criar um backup cifrado.
- **Privacidade:** a cifra é feita no dispositivo pela biblioteca `cryptography` (Dart puro), sem rede. O fornecedor escolhido no seletor do sistema continua a ver nome, tamanho e datas do ficheiro, mas não o conteúdo. GCM garante integridade e autenticidade com a chave derivada, não identifica o autor; um atacante com o ficheiro pode tentar frases-passe offline.
Motivo: um backup guardado no Drive, OneDrive ou cartão SD ficava legível para quem tivesse acesso ao ficheiro, o que contradizia a promessa de dados financeiros privados. Cifrar só os backups resolve o risco sem alterar o motor Drift, as migrações nem o desempenho da app, e mantém a recuperação possível noutro telefone apenas com a frase-passe. Custo aceite: uma frase-passe a memorizar, sem recuperação, e a possibilidade de restauro mais lento (PBKDF2) — aceitável numa operação explícita do utilizador. Testes: `test/unit/backup/backup_crypto_test.dart` (ida e volta com acentos, sal/nonce aleatórios, frase curta, frase errada, adulteração de ciphertext/MAC/cabeçalho, envelopes e versões inválidas, deteção do formato), `test/unit/backup/backup_service_test.dart` (criação cifrada, restauro noutra base, frase em falta/errada e importação externa) e `test/widget/backup_flow_test.dart` (escolha do formato, validação da frase e confirmação, desbloqueio, pré-visualização, restauro e estado do cadeado).
