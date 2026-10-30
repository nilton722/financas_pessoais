# Fase 06 — Validação e preparação para lançamento

## Objetivo
Validar integridade financeira, modo offline, previsões, migrações e backups; preparar build Android.

## Tarefas
1. Executar `dart format --set-exit-if-changed .`, `flutter analyze` e `flutter test`; corrigir problemas e reportar resultados reais.
2. Testar integração: primeira abertura, conta, rendimento/despesa, transferência, orçamento, compromisso/pagamento, previsão, backup e restauração.
3. Testar migração de esquema anterior com dados de exemplo e confirmar ausência de perda.
4. Testar modo avião: consultar, criar/editar dados e calcular previsões.
5. Validar saldo negativo, montantes grandes, movimentos retroativos, categorias arquivadas, compromissos cancelados e recorrências idempotentes.
6. Rever segredos, consultas parametrizadas, logs, permissões e ausência de tráfego de rede inesperado.
7. Rever acessibilidade, estados vazios/erro e confirmação de operações destrutivas.
8. Confirmar uso de inteiros e não consolidação de moedas diferentes.
9. Rever dependências e remover as não usadas.
10. Documentar instalação, uso, backup/restauração, privacidade, limitações e atualização.
11. Preparar build Android de release apenas após testes; não publicar automaticamente nem embutir credenciais reais.
12. Documentar defeitos conhecidos e plano futuro para sincronização e avaliação estatística.

## Aceitação
Testes críticos passam ou falhas que afetam integridade bloqueiam a declaração de pronto; migração/restauração não perdem dados; fluxos principais funcionam offline; previsões são explicáveis; comandos e resultados documentados.
