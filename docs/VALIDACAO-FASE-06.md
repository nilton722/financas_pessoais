# Validação da Fase 06 — lançamento

Relatório dos comandos, testes e verificações executados em 30/10/2026 para a
fase de validação e preparação do build Android. Só entram aqui resultados
observados; nada foi declarado como aprovado sem execução.

**Conclusão:** os testes críticos passam, a migração e o restauro preservam os
dados e os fluxos principais funcionam offline. A aplicação está pronta para
validação local. A distribuição pública continua condicionada à criação de uma
chave de release própria (ver [Assinatura](#assinatura-e-build-android)); o APK
gerado nesta fase usa a chave de debug e não deve ser distribuído.

## Ambiente

| Item | Valor |
|---|---|
| Flutter / Dart | 3.47.5 stable / 3.13.3 |
| Sistema de build | Windows 11 |
| Emulador | `sdk_gphone16k_x86_64`, Android 17 (API 37), 1080×2400 |
| Pacote | `ao.gb.financas_pessoais` 1.0.0 (versionCode 1) |
| Esquema SQLite | v4, 13 tabelas (12 de dados + `schema_migrations`) |
| APK validado | `build/app/outputs/flutter-apk/app-release.apk` |

## Comandos e resultados

Executados na raiz do projeto, depois de todas as alterações da fase:

| Comando | Resultado |
|---|---|
| `dart format --set-exit-if-changed .` | `Formatted 130 files (0 changed)`, saída 0 |
| `flutter analyze` | `No issues found!` (5,2 s) |
| `flutter test` | `+188: All tests passed!` (~35 s) |
| `flutter build apk --release` | saída 0; APK de 64 693 167 bytes (61,7 MiB) |
| `apksigner verify --print-certs` | assinado por `CN=Android Debug` |

O JDK do Android Studio não está no `PATH` desta máquina; `apksigner` correu
com `JAVA_HOME="C:/Program Files/Android/Android Studio/jbr"`. O `build`
também usou esse JDK.

## Testes novos e reforçados

### Integração ponta a ponta

`test/integration/release_flow_test.dart` — um único teste,
*jornada completa offline e restauro preservam a integridade*, com ficheiros
reais numa pasta temporária:

1. primeira abertura sem contas;
2. criação de duas contas (Carteira com 10 000 e Poupança com 0);
3. rendimento de 50 000, despesa de 12 000 e transferência de 5 000 entre as
   contas próprias;
4. orçamento de 20 000 em Alimentação, com `12 000 de 20 000 · 60%`;
5. compromisso de 8 000 pago na totalidade, sem pendentes;
6. painel com 40 000 (a transferência não altera o consolidado) e previsão a
   30 dias com o mesmo saldo;
7. backup pela interface, despesa posterior de 7 000 criada pelo repositório,
   restauro pela interface e confirmação do ficheiro `pre-restore-…json`;
8. depois de fechar e reabrir: consolidado 40 000, Carteira 35 000, Poupança
   5 000, 4 movimentos (a despesa posterior desapareceu), orçamento gasto
   12 000, compromisso pago 8 000 / pendente 0 e previsão sem saldo negativo.

O teste cobre o requisito de backup restaurável e de não dupla contagem entre
compromisso, pagamento e movimento.

### Migração com dados

`test/unit/database/migration_test.dart`:

- **v1 → v4** (já existente): preserva dados e aplica v2–v4; reabrir não
  duplica registos.
- **v3 → v4** (novo): base criada em v4, reduzida a v3 (índices da fase 03
  removidos, `user_version=3`, registos de migração acima de 3 apagados) e
  reaberta. Semeou conta com 10 000, despesa de 2 500, compromisso de 3 000
  pago 1 000, orçamento de 4 000, meta ligada à conta com alvo 5 000 e dívida
  de 2 000 com pagamento de 500.

  Resultado: `user_version=4`, versões `[1, 2, 3, 4]`, contagens inalteradas
  (1 conta, 3 movimentos, 1 pagamento de compromisso, 1 pagamento de dívida,
  1 orçamento, 1 meta, 1 dívida), saldo 6 000, item pago 1 000 / pendente
  2 000, dívida paga 500 / pendente 1 500, progresso da meta 6 000, orçamento
  4 000 / gasto 4 000 e os três índices da v4 presentes.

Não foi testada uma migração v2 → v4 isolada; a v2 é exercitada no percurso
v1 → v4. O esquema é aditivo e nunca apaga a base para atualizar.

### Casos-limite financeiros

| Cenário | Teste | Resultado |
|---|---|---|
| Saldo negativo | `saldo real pode ficar negativo sem perder o sinal` | conta com 1 000 e despesa de 3 000 dá −2 000 no saldo por conta e no consolidado |
| Montante máximo | `aceita o montante máximo e mantém aritmética inteira` | 999 999 999 999 guardado sem perda e somado a 1 |
| Formatação do máximo | `formatters/money_formatter_test.dart` | `999 999 999 999 FCFA` |
| Correção retroativa | `edição retroativa recalcula o saldo`, `correção retroativa recalcula saldo e histórico` | relatórios e previsão refletem a nova data |
| Categoria arquivada | `rejeita conta arquivada em novos movimentos`, `conta arquivada fica fora do saldo por omissão` | histórico mantido, novas utilizações recusadas |
| Compromisso cancelado | `compromisso cancelado fica de fora da previsão` | pagamentos já feitos preservados; pendente fora da projeção |
| Recorrências idempotentes | testes de repositório e de widget | sincronizar duas vezes não duplica ocorrências |

### Moeda e aritmética

- Todos os montantes continuam inteiros em FCFA/XOF; não há `double` em
  cálculos monetários nem casas decimais na entrada.
- O saldo consolidado soma apenas contas na moeda de referência; contas noutra
  moeda ficam de fora e as transferências entre moedas diferentes são
  recusadas. Não há conversão nem agregação de moedas distintas.

## Validação offline (modo avião)

O APK de release foi instalado no emulador e validado com
`airplane_mode_on=1`, Wi-Fi e dados móveis desligados. `ping 8.8.8.8` devolveu
`Network is unreachable` durante os testes. A rede foi reposta no fim
(`airplane_mode_on=0` e ping a 8.8.8.8 com resposta).

Observações na app, sem rede:

- a base existente abriu com os dados anteriores (4 000 FCFA no painel e
  4 movimentos listados);
- criação de um rendimento de 800 e edição para 900, ambos offline: painel
  recalculou para 4 900 FCFA sem erros;
- a previsão a 30 dias recalculou offline: saldo inicial 4 900, dois
  compromissos conhecidos no horizonte (−60 000 em 30/10/2026 e −20 000 em
  15/11/2026), mínimo de −75 100 em 15/11/2026;
- o ecrã de previsão mostrou pressupostos, qualidade dos dados e limitações,
  incluindo «Histórico insuficiente: 0 meses com despesas e 0 despesas», e o
  rodapé com data de corte 30/10/2026, algoritmo `forecast-1` e horizonte de
  30 dias.

Os ecrãs `fase06_09.png` a `fase06_12.png` (capturas do emulador) registam o
estado offline, a edição e o detalhe da previsão.

## Segurança, privacidade e dados

Revisão estática do código, manifesto e APK de release:

- **Segredos:** não há chaves, palavras-passe nem tokens no repositório nem no
  APK. `android/key.properties` não existe; só o exemplo com marcadores.
  `.gitignore` exclui `key.properties`, `*.jks` e `*.keystore`.
- **Rede:** a app não usa HTTP nem qualquer cliente de rede. O APK de release
  declara apenas a permissão interna
  `ao.gb.financas_pessoais.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`,
  gerada pelo Android; **não** tem `INTERNET` nem permissões de armazenamento.
  `INTERNET` existe só nos manifestos de debug/profile para ferramentas.
- **SQL:** consultas parametrizadas; os únicos identificadores SQL literais
  são nomes fixos de tabelas/colunas do backup, entre aspas duplas. Operações
  compostas correm em transações SQLite e `PRAGMA foreign_keys = ON`.
- **Logs:** não registam montantes, descrições, contas nem outros dados
  financeiros pessoais; erros são apresentados como mensagens genéricas com
  ação de recuperação.
- **Ficheiros:** backups e CSV ficam na pasta privada da aplicação no Android
  e só são escritos por ação do utilizador. O backup não é cifrado; o checksum
  deteta corrupção acidental, não adulteração — está documentado e não é
  apresentado como segurança.
- **Operações destrutivas:** eliminar movimento, arquivar conta/categoria,
  cancelar compromisso e restaurar backup pedem confirmação; o restauro cria
  primeiro um backup `pre-restore` e corre numa transação.

## Acessibilidade e estados

- Rótulos semânticos revistos e cobertos por testes de widget no painel, nos
  relatórios e no gráfico da previsão; ícones e cartões têm descrição.
- Estados vazios e de erro existem nas listas, no painel, na previsão e no
  restauro; falhas de backup explicam o motivo e não alteram a base.
- Não foi feita uma auditoria manual com TalkBack num dispositivo físico. É uma
  verificação em falta, registada nos defeitos conhecidos.

## Dependências e documentação

- `cupertino_icons` foi removido por não ser usado; `cupertino_ui` continua
  apenas como dependência transitiva de `go_router`. Nenhuma dependência nova
  foi adicionada nesta fase.
- Documentação de lançamento:
  [MANUAL.md](MANUAL.md) (instalação, uso, backup/restauro, privacidade,
  limitações, atualização e assinatura), [BACKUP.md](BACKUP.md),
  [PRIVACY.md](PRIVACY.md), [DATABASE.md](DATABASE.md),
  [DECISIONS.md](DECISIONS.md) (ADR-031) e [README.md](../README.md).

## Assinatura e build Android

- `android/app/build.gradle.kts` lê `android/key.properties` quando existe e
  assina o release com essa chave; sem o ficheiro, usa a chave de debug
  **apenas para validação local**.
- `android/key.properties.example` contém marcadores, sem valores reais.
- O APK validado está assinado por `CN=Android Debug`
  (SHA-256 `27959f09…adbffb9`), versão 1.0.0, rótulo «Finanças Pessoais».
- Nada foi publicado. O APK não foi gerado para distribuição: para publicar é
  preciso criar o keystore, preencher `key.properties`, repetir os testes e
  gerar um novo APK.
- Instalar um APK com assinatura diferente obriga a desinstalar e perde a base
  privada; exportar o backup antes.

## Defeitos e lacunas conhecidos

1. O APK desta validação está assinado com a chave de debug; não é
   distribuível.
2. Não há PIN nem biometria e a base não está cifrada em repouso. Quem
   desbloquear o telefone consegue abrir a app.
3. O backup não é cifrado nem autenticado; o checksum só deteta corrupção.
4. O restauro substitui toda a base; não funde backups. Ficheiros de backup
   guardados na pasta da app perdem-se ao desinstalar.
5. Sem sincronização, importação bancária, CSV de entrada ou login remoto.
6. O consolidado só soma contas na moeda de referência; não há conversão de
   moedas.
7. A previsão usa a mediana das despesas dos três meses civis completos e só
   ativa o histórico com 3 meses e 6 despesas; abaixo disso usa apenas
   compromissos conhecidos e não antecipa despesas não registadas. Não modela
   sazonalidade nem cenários.
8. Depois de materializadas, as ocorrências de recorrência não permitem mudar
   tipo, frequência ou início; só valor, descrição, conta, categoria e fim.
9. Validação feita em emulador x86_64 (API 37), sem dispositivo físico nem
   medição de desempenho com grandes volumes; a migração v2 → v4 isolada não
   tem teste próprio.
10. Acessibilidade verificada por semântica e testes de widget, sem auditoria
    TalkBack em dispositivo.

Nenhum destes pontos afeta a integridade dos dados nos fluxos testados; o
primeiro é o único bloqueio à distribuição.

## Plano futuro

### Sincronização

Não faz parte desta versão (ADR-003). Se for considerada, exige uma decisão
nova e um desenho próprio: consentimento explícito, autenticação, cifra em
trânsito e em repouso, IDs UUID (já usados), registo de alterações e
tombstones para eliminações, política de conflitos, operações idempotentes e
migrações de esquema. Nenhum backend será introduzido sem essa decisão.

### Avaliação estatística

O motor atual (`forecast-1`) é determinístico e explicável, com mediana
histórica e compromissos conhecidos. A evolução prevista no ADR-012 é comparar
esta base com média sazonal e suavização exponencial, usando backtesting
temporal rolling-origin sem fuga de dados, e medir MAE/WAPE com tratamento
explícito de valores reais zero. Só adotar um modelo se melhorar de forma
consistente com dados suficientes; um serviço externo exigiria nova decisão e
consentimento.

## Aceitação

| Critério | Estado |
|---|---|
| Testes críticos passam ou falhas de integridade bloqueiam o pronto | cumprido: 188 testes verdes, análise limpa |
| Migração/restauro não perdem dados | cumprido: v1→v4 e v3→v4 com dados; restauro com `pre-restore` |
| Fluxos principais funcionam offline | cumprido no emulador em modo avião |
| Previsões explicáveis | data de corte, horizonte, pressupostos, qualidade e limitações visíveis |
| Comandos e resultados documentados | este relatório, com resultados reais |

A fase fica concluída para validação local; a assinatura de release é o passo
seguinte antes de qualquer distribuição.
