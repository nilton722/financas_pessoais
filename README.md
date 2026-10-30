# Finanças Pessoais

Aplicação mobile de finanças pessoais para uso individual: Flutter/Dart, SQLite
local, offline-first. Sem backend, sem login remoto, sem telemetria.

**Estado:** Fase 03 (planeamento) concluída — compromissos futuros com
pagamentos totais/parciais, recorrências idempotentes, orçamentos mensais por
categoria, metas de poupança e dívidas, sobre as contas, categorias e
movimentos da Fase 02. Tudo offline, sem backend nem telemetria.

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
dart format .
flutter analyze
flutter test
```

## Estrutura

```text
lib/
  app/            aplicação, router (go_router), shell com navegação inferior
  core/           base de dados, migrações, seeds, formatters, erros, utils, widgets
  features/
    dashboard/    painel com saldo consolidado e totais do mês
    accounts/     contas e saldos por conta
    categories/   categorias de rendimento e despesa
    transactions/ movimentos, transferências e filtros
    planning/     compromissos, recorrências, orçamentos, metas e dívidas
    settings/     configuração local
test/
  support/        fixtures de base de dados, domínio e widgets
  unit/           domínio, formatters, base de dados e repositórios
  widget/         arranque, navegação e fluxos de criação/validação
docs/             SPEC, decisões (ADR) e modelo de dados
```

Camadas: widgets não contêm SQL nem regras financeiras; acesso a dados passa
por repositórios em `features/*/data` e providers Riverpod em `features/*/presentation`.

Navegação: `go_router` com `ShellRoute` e barra inferior com cinco separadores
(Painel, Movimentos, Contas, Categorias, Planeamento). Formulários abrem em
rotas próprias (`/accounts/new`, `/movements/:id/edit`,
`/planning/commitments/:id/pay`, …) — ver ADR-017. O separador Planeamento
agrupa cinco áreas: compromissos, orçamentos, recorrências, metas de poupança e
dívidas.

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
  metas e dívidas. Nenhuma base é recriada para atualizar.

Detalhe do esquema, seeds e plano de migrações: [docs/DATABASE.md](docs/DATABASE.md).

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
- Painel com saldo consolidado e rendimentos/despesas do mês corrente.
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
- Backup/restauro versionado: previsto para a Fase 05; ainda não implementado.

## Fases

| Fase | Âmbito | Estado |
|---|---|---|
| 01 | Fundação Flutter + esquema SQLite v1 | concluída |
| 02 | Contas, categorias, movimentos | concluída |
| 03 | Planeamento, orçamentos, recorrências, metas, dívidas | concluída |
| 04 | Previsão local | por iniciar |
| 05 | Dashboard, relatórios, backup, privacidade | por iniciar |
| 06 | Validação e preparação Android | por iniciar |
