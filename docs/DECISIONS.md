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
Motivo: cumprir "PIN/biometria só com APIs seguras" sem prometer uma proteção que a versão não oferece, e documentar as limitações de proteção local exigidas na Fase 05.
