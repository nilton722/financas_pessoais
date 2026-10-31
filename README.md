# Nô Dinheru

Aplicação mobile de finanças pessoais para uso individual: Flutter/Dart, SQLite
local, offline-first. Sem backend, sem login remoto, sem telemetria.

Identidade oficial: **Nô Dinheru — O teu dinheiro, sob controlo.** O ícone
oficial, o logótipo, a paleta e o splash vivem em `assets/branding/` e nas
configurações nativas; os ícones Android/iOS são gerados a partir da arte
aprovada sem dependências adicionais.

**Estado:** Fase 07 (bloqueio ao abrir) concluída — bloqueio opcional com as
credenciais do telefone validado no emulador. As Fases 01–07 estão concluídas.
Tudo offline, sem backend nem telemetria.

Manual de instalação e uso: [docs/MANUAL.md](docs/MANUAL.md).
Relatório de validação desta fase e defeitos conhecidos:
[docs/VALIDACAO-FASE-07.md](docs/VALIDACAO-FASE-07.md); anterior:
[docs/VALIDACAO-FASE-06.md](docs/VALIDACAO-FASE-06.md).
Design system, marca, tokens e política de apresentação de dados:
[docs/DESIGN.md](docs/DESIGN.md) (ADR-032, ADR-033 e ADR-034).

## Requisitos

| Ferramenta | Versão usada |
|---|---|
| Flutter | 3.47.5 (stable) |
| Dart | 3.13.3 |
| Android | SDK platform 37, build-tools 36 (opcional para desenvolvimento) |
| JDK | 25 (o JDK do Android Studio serve) |

## Instalação

```bash
flutter pub get
dart run build_runner build
flutter run
```

O `build_runner` gera `lib/core/database/app_database.g.dart` a partir das
tabelas Drift em `lib/core/database/tables/`. Executar novamente sempre que as
tabelas mudarem.

## Comandos de verificação

```bash
dart format lib test
flutter analyze
flutter test
```

Validação de release: `dart format --set-exit-if-changed lib test`,
`flutter analyze`, `flutter test` e `flutter build apk --release` — resultados e
data em [docs/VALIDACAO-FASE-07.md](docs/VALIDACAO-FASE-07.md).

O `dart format .` inclui `build/`, cujos nomes de ficheiros gerados pelo Gradle
excedem o limite de caminho do Windows e fazem o comando falhar; use `lib test`
ou um sistema com caminhos longos.

## Estrutura

```text
lib/
  app/            aplicação, router (go_router), shell, splash e bloqueio
  core/           base de dados, migrações, seeds, formatters, ficheiros, backup, segurança, erros, utils, widgets
  features/
    dashboard/    painel com saldo real/projetado, orçamento, compromissos e metas
    accounts/     contas e saldos por conta
    categories/   categorias de rendimento e despesa
    transactions/ movimentos, transferências e filtros
    planning/     compromissos, recorrências, orçamentos, metas e dívidas
    forecast/     previsão local: motor, repositório, providers e ecrã
    reports/      relatórios por período/categoria/conta e exportação CSV
    settings/     definições, privacidade, backups e restauro
test/
  support/        fixtures de base de dados, domínio e widgets
  unit/           domínio, formatters, base de dados, repositórios, backup e relatórios
  widget/         arranque, navegação e fluxos de criação/validação
  integration/    jornada completa: lançamento, previsão, backup e restauro
docs/             SPEC, decisões (ADR), modelo de dados, backup, privacidade,
                  design system, manual de uso e validação de release
```

Camadas: widgets não contêm SQL nem regras financeiras; acesso a dados passa
por repositórios em `features/*/data` e providers Riverpod em `features/*/presentation`.

Navegação: `go_router` com `ShellRoute` e barra inferior com cinco separadores
(Painel, Movimentos, Contas, Categorias, Plano). Formulários abrem em
rotas próprias (`/accounts/new`, `/movements/:id/edit`,
`/planning/commitments/:id/pay`, …) — ver ADR-017. O separador Plano agrupa
cinco áreas: compromissos, orçamentos, recorrências, metas de poupança e
dívidas. A previsão abre em `/forecast`, a partir do cartão do painel; não ocupa
um separador próprio. **Relatórios** (`/reports`) e **Definições**
(`/settings`, com `/settings/backups`) abrem pelos ícones do painel ou pela
entrada “Privacidade e backup”, sem ocupar separadores.

## Base de dados

- SQLite local, ficheiro `financas_pessoais.sqlite` na pasta de dados da app.
- `PRAGMA foreign_keys = ON` em cada abertura.
- Montantes em inteiros FCFA/XOF; datas financeiras `YYYY-MM-DD`; timestamps
  ISO-8601 UTC.
- Categorias de sistema e configurações iniciais são semeadas de forma
  idempotente (ver `lib/core/database/seeds/default_seeds.dart`).
- Saldos não são colunas: são calculados a partir do saldo inicial e dos
  movimentos não eliminados até à data de referência (ADR-018).
- O esquema está em **v4**. As migrações v2–v4 (Fase 03) são aditivas e
  preservam os dados existentes: compromissos e recorrências, orçamentos,
  metas e dívidas. Nenhuma base é recriada para atualizar. As Fases 04 e 05 não
  alteram o esquema: a previsão e os relatórios leem as tabelas existentes.

Detalhe do esquema, seeds e plano de migrações: [docs/DATABASE.md](docs/DATABASE.md).
Design system e regras de exibição: [docs/DESIGN.md](docs/DESIGN.md).
Backup, exportação e recuperação: [docs/BACKUP.md](docs/BACKUP.md).
Privacidade e limitações de proteção local: [docs/PRIVACY.md](docs/PRIVACY.md).
Instalação, uso e assinatura de release: [docs/MANUAL.md](docs/MANUAL.md).

## Notas de ambiente (Windows)

- `flutter build windows` exige **Developer Mode** ativo (symlinks de plugins).
- O emulador Android requer `cmdline-tools` no SDK; sem ele `flutter emulators`
  não lista o AVD, mas `emulator -avd <nome>` continua a funcionar.
- Se o Flutter não detetar o JDK: `flutter config --jdk-dir "<caminho-do-jdk>"`.

## O que já funciona

- Contas de dinheiro, banco, carteira móvel, poupança e outro, com saldo
  inicial, data de abertura e arquivo reversível.
- Categorias predefinidas e personalizadas; arquivar mantém os movimentos
  históricos e impede novas utilizações.
- Rendimentos e despesas com conta, categoria, data, montante inteiro,
  descrição e notas.
- Transferências entre contas próprias: um registo lógico e uma operação
  atómica, sem alterar rendimentos, despesas ou saldo consolidado.
- Saldo por conta e consolidado, calculados a partir dos movimentos reais.
- Lista de movimentos com filtros de período, conta, tipo e categoria, edição
  e eliminação lógica.
- Painel com saldo real consolidado e saldo projetado distinguidos visualmente
  (cartão verde “Saldo real consolidado” e cartão “Projetado” com data de
  corte), rendimentos/despesas do mês, resumo de orçamentos, compromissos
  pendentes e metas, com etiquetas de acessibilidade.
- Relatórios por período (este mês, mês anterior, últimos três meses ou
  intervalo), agrupados por categoria ou conta, com resumo de rendimentos,
  despesas e resultado; transferências aparecem à parte sem alterar os totais.
- Exportação CSV local, iniciada pelo utilizador, em UTF-8 com BOM, `;` e datas
  `DD/MM/YYYY`; o caminho do ficheiro pode ser copiado — ver ADR-029.
- Backup JSON versionado (formato v1, esquema v4) com as 12 tabelas de dados,
  configurações, contagens e checksum; pré-visualização e confirmação antes de
  restaurar.
- Importação de backup por seletor de ficheiros do sistema (Storage Access
  Framework), sem permissões de armazenamento; o ficheiro escolhido é validado
  e restaurado com a mesma transação atómica e cópia `pre-restore` — ADR-036.
- Restauro atómico: valida o ficheiro, cria uma cópia `pre-restore-…json` da
  base atual e substitui tudo numa única transação SQLite com verificação de
  contagens e chaves estrangeiras; um erro não deixa base parcial — ADR-028.
- Definições com privacidade, bloqueio ao abrir, caminhos dos
  dados/backups/exportações e versão; a app não pede permissões de
  armazenamento e backup, exportação e importação são sempre iniciados pelo
  utilizador — ver [docs/PRIVACY.md](docs/PRIVACY.md).
- Bloqueio opcional ao abrir com PIN, padrão, palavra-passe ou biometria do
  telefone, delegado no sistema; volta a pedir após 60 segundos em segundo
  plano. É uma barreira de interface e não cifra a base — ADR-037.
- Compromissos futuros de rendimento/despesa com vencimento, conta e categoria
  opcionais; pagamento total ou parcial cria exatamente um movimento real e
  nunca duplica o caixa. Cancelar remove a previsão e mantém pagamentos.
- Recorrências semanais, mensais e anuais ancoradas na data de início, com
  ocorrências idempotentes e pausa reversível.
- Orçamentos mensais por categoria, com gasto, restante e percentagem
  calculados a partir de despesas reais (transferências excluídas).
- Metas de poupança com alvo, data opcional e progresso lido do saldo real da
  conta associada — metas não são despesas.
- Dívidas a pagar e a receber, com pendente derivado de pagamentos reais e
  liquidação por movimento `expense`/`income`.
- Alertas locais dentro da app para compromissos a vencer/vencidos, dívidas
  vencidas e orçamentos excedidos.
- Previsão local determinística a 7, 30 e 90 dias: saldo de partida a partir dos
  movimentos reais, compromissos em aberto (líquidos do já pago) e ocorrências
  recorrentes materializadas uma única vez; despesas históricas só entram com
  histórico suficiente, por mediana mensal e excluindo categorias com
  compromissos conhecidos. Mostra saldo projetado, menor saldo, próximos
  compromissos, pressupostos, qualidade dos dados e limitações — ver ADR-026 e
  ADR-027.
- Interface com design system unificado: tema teal claro/escuro sobre fundo
  areia, cartões sem sombra, estados vazios, etiquetas de estado e montantes com
  algarismos tabulares; valores exatos nas listas e resumo compacto apenas no
  painel — ver [docs/DESIGN.md](docs/DESIGN.md).

## Fases

| Fase | Âmbito | Estado |
|---|---|---|
| 01 | Fundação Flutter + esquema SQLite v1 | concluída |
| 02 | Contas, categorias, movimentos | concluída |
| 03 | Planeamento, orçamentos, recorrências, metas, dívidas | concluída |
| 04 | Previsão local | concluída |
| 05 | Dashboard, relatórios, backup, privacidade | concluída |
| 06 | Validação e preparação Android | concluída |
| 07 | Bloqueio ao abrir com as credenciais do telefone | concluída |
