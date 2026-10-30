# Instruções do agente — Finanças Pessoais

## Objetivo
Aplicação mobile de finanças pessoais para uso individual, Flutter/Dart, SQLite local, offline-first. A previsão inicial usa regras transparentes executadas no dispositivo. Sincronização futura é apenas uma possibilidade, não deve ser implementada agora.

## Regras obrigatórias
1. Ler `docs/SPEC.md` e `docs/DECISIONS.md` antes de alterar código.
2. Executar somente a fase solicitada; não avançar sem autorização.
3. Inspecionar o repositório, propor plano e indicar ficheiros afetados antes de codificar.
4. Não introduzir Laravel, PHP, MySQL, Python, FastAPI, backend, login remoto ou serviços cloud na versão inicial.
5. Separar apresentação, domínio e dados. Widgets não devem conter SQL nem regras financeiras.
6. SQLite é a fonte local de verdade. Usar migrações incrementais e versionadas; nunca apagar/recriar a base para atualizar.
7. Montantes são inteiros em FCFA/XOF; nunca usar `double` em cálculos monetários.
8. Datas financeiras usam `YYYY-MM-DD`; timestamps técnicos usam ISO-8601 UTC. Mostrar datas como `DD/MM/YYYY`; configuração inicial `Africa/Bissau`, configurável.
9. Transferências entre contas próprias não são rendimento nem despesa. Compromissos futuros não são movimentos realizados.
10. Evitar dupla contagem entre compromisso, recorrência e movimento efetivamente pago.
11. Previsões são estimativas, não garantias. Mostrar data de corte, horizonte, pressupostos, qualidade dos dados e limitações.
12. Não inventar histórico. Se os dados forem insuficientes, indicar isso e usar apenas compromissos conhecidos.
13. Sem transmissão de dados financeiros, analytics, anúncios ou telemetria por defeito.
14. Implementar exportação e backup restaurável; testar restauração e ficheiros inválidos.
15. Usar consultas parametrizadas, transações SQLite para operações compostas e logs sem dados financeiros pessoais.
16. Testar regras financeiras, repositórios, migrações, widgets e fluxos críticos.
17. Não adicionar dependências sem justificação e confirmação de compatibilidade.
18. Não afirmar que testes passaram sem os executar.
19. Atualizar documentação se uma decisão mudar.

## Processo por fase
Ler o prompt da fase, inspecionar o estado, apresentar plano, implementar apenas o âmbito, executar `dart format`, `flutter analyze` e testes relevantes, depois reportar alterações, comandos, resultados reais e limitações.
