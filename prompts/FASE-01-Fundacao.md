# Fase 01 — Fundação Flutter, arquitetura e SQLite

Leia `CLAUDE.md`, `docs/SPEC.md` e `docs/DECISIONS.md`.

## Objetivo
Preparar a base executável da app Flutter, arquitetura modular e SQLite versionado. Não implementar todos os módulos de negócio ainda.

## Tarefas
1. Inspecionar versões de Flutter/Dart, estado do repositório e ferramentas; não sobrescrever projeto existente.
2. Criar o esqueleto Flutter se necessário.
3. Escolher uma biblioteca SQLite (avaliar Drift ou sqflite) e uma solução de estado (por exemplo Riverpod ou Bloc); justificar compatibilidade, migrações e testes.
4. Criar estrutura `lib/app`, `lib/core`, `lib/features` e pastas de testes conforme a especificação.
5. Configurar português, XOF/FCFA, formato `DD/MM/YYYY` e `Africa/Bissau` inicial configurável.
6. Implementar serviço de base, foreign keys, transações e `schema_migrations`.
7. Criar migrações para as tabelas definidas na SPEC, ou documentar exatamente quais serão criadas nesta fase e em que fase as restantes serão adicionadas. Não divergir silenciosamente.
8. Usar UUID, montantes inteiros e datas financeiras `YYYY-MM-DD`.
9. Inserir apenas categorias padrão e configurações iniciais; não criar movimentos financeiros fictícios.
10. Testar abertura, foreign keys, migrações e inicialização repetida.
11. Documentar instalação e execução.

## Não fazer
Não adicionar Laravel/PHP/MySQL/Python/API/backend/login remoto/sincronização cloud. Não apagar a base como forma de migração.

## Aceitação
App inicia no emulador/dispositivo; esquema esperado existe; inicialização repetida não duplica seeds/migrações; `dart format`, `flutter analyze` e `flutter test` executados e resultados reportados.
