# Validação da Fase 08 — lembretes locais

Relatório dos comandos, testes e verificações executados em 1 e 2/11/2026 para
os lembretes de vencimentos e limites de orçamento. Só entram aqui resultados
observados; nada foi declarado como aprovado sem execução.

**Conclusão:** os lembretes são agendados no próprio aparelho, sem rede, e o
release mantém-se offline. O pedido de notificações surge apenas quando o
utilizador liga a opção, o desligar cancela os avisos pendentes e o reagendar
após reiniciar funciona no emulador. A entrega efetiva de uma notificação não
foi observada ponta a ponta: os alarmes são inexatos (janela de até cerca de
uma hora) e o emulador tinha o release instalado, sem root para adiantar o
relógio. Essa limitação está registada abaixo e nos documentos de utilizador.

## Ambiente

| Item | Valor |
|---|---|
| Flutter / Dart | 3.47.5 stable / 3.13.3 |
| Sistema de build | Windows 11 |
| Emulador | `emulator-5554`, Android 17 (API 37), 1080×2400 |
| Pacote | `ao.gb.financas_pessoais` 1.0.0 (versionCode 1) |
| APK de release | `build/app/outputs/flutter-apk/app-release.apk`, 71 103 280 bytes (67,8 MB) |
| APK de debug | `build/app/outputs/flutter-apk/app-debug.apk`, 229 602 660 bytes |

## Comandos e resultados

Executados na raiz do projeto depois de todas as alterações da fase:

| Comando | Resultado |
|---|---|
| `dart format --set-exit-if-changed lib test` | `Formatted 159 files (0 changed)`, saída 0 |
| `flutter analyze` | `No issues found!` |
| `flutter test` | `+269: All tests passed!` (~68 s) |
| `flutter build apk --release` | saída 0; APK de 71 103 280 bytes |
| `flutter build apk --debug` | saída 0; APK de 229 602 660 bytes |
| `apksigner verify --print-certs` | assinado por `CN=Android Debug`, SHA-256 `27959f09…adbffb9` |
| `aapt2 dump permissions` | ver lista abaixo |

O release foi assinado com a chave de debug porque `android/key.properties`
continua ausente nesta máquina. É válido para validação local, não para
distribuição; a assinatura definitiva pertence à fase de lançamento.

Permissões efetivas do APK de release (manifesto fundido com os plugins):

```
USE_BIOMETRIC
POST_NOTIFICATIONS
RECEIVE_BOOT_COMPLETED
USE_FINGERPRINT          (legado, equivalente a USE_BIOMETRIC)
VIBRATE                  (notificações)
DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION  (interna do AndroidX)
```

Não existe `INTERNET` nem qualquer permissão de armazenamento, localização,
contactos, câmara ou microfone.

O `dart format --set-exit-if-changed .` continua a falhar nesta máquina por
nomes de ficheiros gerados pelo Gradle acima do limite de caminho do Windows;
por isso a verificação corre sobre `lib` e `test`, onde está todo o Dart do
projeto.

## Testes novos

| Ficheiro | Cobertura |
|---|---|
| `test/unit/planning/reminder_planner_test.dart` | 11 testes: aviso na véspera e no dia, receitas, horas já passadas, horizonte de 365 dias, resumo de orçamento no singular/plural e IDs estáveis |
| `test/unit/planning/reminder_coordinator_test.dart` | 7 testes: plataforma sem suporte, permissão recusada, ativar persiste e agenda dois avisos, desativar cancela, permissão desligada no sistema cancela, mudar a hora reagenda, sincronizações repetidas mantêm os IDs |
| `test/unit/settings/app_settings_repository_test.dart` | 3 testes de lembretes: desligados por omissão às 09:00, gravar/ler `enabled`, `hour` e `minute` mantendo as restantes configurações, e valor inválido `25:99` a recair em 09:00 |
| `test/widget/reminders_flow_test.dart` | 4 testes: ativar pelo interruptor persiste e confirma, permissão recusada mostra aviso, plataforma sem suporte desativa a opção, permissão desligada no sistema mostra aviso no arranque |

O conjunto completo ficou em 269 testes. O plugin nativo de notificações só foi
exercitado no emulador, como se descreve abaixo; os testes usam um
`FakeNotificationGateway`.

## Validação manual no emulador

| Cenário | Ação | Resultado observado |
|---|---|---|
| Ativar lembretes | Interruptor em Definições | Diálogo real de permissão de notificações do Android; após «Permitir», interruptor ligado e «Ativos às 09:00» |
| Agendamento | Ativar com compromissos futuros | 28 alarmes `RTC_WAKEUP` pendentes para `ScheduledNotificationReceiver` |
| Desativar | Desligar o interruptor | 0 alarmes pendentes; histórico mostra apenas `alarm_cancelled` |
| Reativar | Voltar a ligar | 28 alarmes novamente |
| Arranque do release | Instalar o APK de release e abrir | Reagenda os 28 alarmes; ecrã de Definições mostra lembretes ligados às 09:00 |
| Ícone da notificação | Build de release com resource shrink | `drawable/ic_stat_notify` mantido através de `res/raw/keep.xml` (ID `0x7f080060`) |

Os alarmes são inexatos (`inexactAllowWhileIdle`), com janela de disparo de até
cerca de uma hora, e não pedem a permissão de alarmes exatos. O emulador tinha
o release instalado, sem root, pelo que não foi possível adiantar o relógio do
sistema para observar a entrega. A existência dos alarmes, o cancelamento e o
reagendamento foram confirmados com `dumpsys alarm`.

## Limitações conhecidas

- A entrega visual de uma notificação não foi observada ponta a ponta; só o
  agendamento, o cancelamento e o reagendamento foram verificados.
- O sistema pode atrasar o aviso até cerca de uma hora e pode cancelá-lo se o
  utilizador forçar a paragem da aplicação ou restringir a bateria.
- A notificação mostra descrição, montante e conta; as pré-visualizações no
  ecrã de bloqueio dependem das definições do sistema.
- A base e os backups continuam sem cifra; esta fase não altera o modelo de
  proteção descrito no ADR-037.
