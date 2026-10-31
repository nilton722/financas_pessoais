# Validação da Fase 07 — bloqueio ao abrir

Relatório dos comandos, testes e verificações executados em 31/10/2026 para o
bloqueio opcional com as credenciais do telefone. Só entram aqui resultados
observados; nada foi declarado como aprovado sem execução.

**Conclusão:** o bloqueio funciona no emulador com PIN do sistema — pedido
automático ao abrir, cancelamento mantém a app bloqueada, 60 segundos em
segundo plano rebloqueiam, a remoção das credenciais permite abrir sem deixar o
utilizador preso e a preferência viaja no backup. O APK de release mantém-se
offline, sem `INTERNET` nem permissões de armazenamento. A base SQLite e os
backups continuam sem cifra: o bloqueio é uma barreira de interface, como
descrito no ADR-037.

## Ambiente

| Item | Valor |
|---|---|
| Flutter / Dart | 3.47.5 stable / 3.13.3 |
| Sistema de build | Windows 11 |
| Emulador | `emulator-5554`, Android 17 (API 37), 1080×2400 |
| Pacote | `ao.gb.financas_pessoais` 1.0.0 (versionCode 1) |
| APK validado | `build/app/outputs/flutter-apk/app-release.apk`, 68 713 609 bytes (65,5 MB) |

## Comandos e resultados

Executados na raiz do projeto, depois de todas as alterações da fase:

| Comando | Resultado |
|---|---|
| `dart format --set-exit-if-changed lib test` | `Formatted 159 files (0 changed)`, saída 0 |
| `flutter analyze` | `No issues found!` (8,2 s) |
| `flutter test` | `+229: All tests passed!` (~54 s) |
| `flutter build apk --release` | saída 0 em 2114,8 s; APK de 68 713 609 bytes |
| `apksigner verify --print-certs` | assinado por `CN=Android Debug`, SHA-256 `27959f09…adbffb9` |

`dart format --set-exit-if-changed .` falha nesta máquina com
`PathNotFoundException` ao listar
`build/file_selector_android/.transforms/…/bundleLibRuntimeToDirDebug_global-synthetics/dev/flutter/packages/file_selector_android`
— nomes de ficheiros gerados pelo Gradle que excedem o limite de caminho do
Windows. Não é código-fonte; por isso a verificação de release passou a ser
feita sobre `lib` e `test`, onde está todo o Dart do projeto. Em Linux/macOS o
comando com `.` continua a poder ser usado.

O JDK do Android Studio não está no `PATH`; `apksigner` correu com
`JAVA_HOME="C:/Program Files/Android/Android Studio/jbr"`.

## Testes novos

| Ficheiro | Cobertura |
|---|---|
| `test/unit/security/app_lock_controller_test.dart` | 8 testes: preferência desligada; bloqueio no arranque com sucesso; cancelar mantém bloqueado; dispositivo sem suporte abre; rebloqueio aos 61 s; 30 s não rebloqueiam; ligar durante a sessão só se aplica na abertura seguinte; desligar desbloqueia |
| `test/unit/settings/app_settings_repository_test.dart` | `lock_on_open` começa desligada, persiste ligada/desligada e mantém quatro configurações |
| `test/widget/app_lock_test.dart` | 8 testes: abertura direta sem preferência; ecrã opaco com `AbsorbPointer`; cancelamento mostra aviso e a nova tentativa volta a pedir; dispositivo sem credenciais mostra «Abrir sem bloqueio»; rebloqueio via ciclo de vida com limiar injetado; layout 411×891; interruptor liga/desliga e persiste; interruptor desativado sem credenciais |

O conjunto completo ficou em 229 testes. O `local_auth` foi exercitado com um
`FakeDeviceAuthService` nos testes; o plugin nativo só foi validado no
emulador, como se descreve abaixo.

## Validação manual no emulador

PIN temporário `1234` definido com
`adb shell locksettings set-pin 1234`. No fim, o PIN foi removido
(`locksettings clear --old 1234`) e o interruptor ficou desligado.

| Cenário | Ação | Resultado observado |
|---|---|---|
| Interruptor disponível | Definições com PIN definido | Cartão «Bloqueio» ativo, interruptor desligado e descrição «Usa o PIN, padrão, palavra-passe ou biometria do telefone.» |
| Ligar o bloqueio | Toque no interruptor | Fica ligado; a preferência é gravada (confirmada no backup, ver abaixo) |
| Abrir com bloqueio | `am force-stop` e nova abertura | Splash, ecrã «Nô Dinheru está bloqueada» e pedido automático do sistema (`BiometricPrompt`) com «Desbloquear a Nô Dinheru» |
| Cancelar | `KEYCODE_BACK` no pedido do sistema | Mantém o ecrã de bloqueio, mostra «Desbloqueio cancelado. Tente novamente.» e não repete o pedido sozinho |
| Desbloquear | PIN 1234 + Enter | Painel com saldo real 4 000 FCFA e os movimentos anteriores intactos |
| Segundo plano curto | Home, 5 s, voltar à app | Não rebloqueia; painel permanece visível |
| Segundo plano longo | Home, 65 s, voltar à app | Rebloqueia e volta a pedir o PIN; cancelar mantém o ecrã de bloqueio |
| Credenciais removidas | `locksettings clear` e nova tentativa | Ecrã explica «O bloqueio do telefone não está configurado neste dispositivo.» e oferece «Abrir sem bloqueio»; abrir funciona |
| Interruptor sem credenciais | Definições sem PIN | Interruptor continua marcado mas desativado, com «Configure um PIN, padrão ou biometria no telefone para usar esta opção.» |
| Preferência no backup | Criar backup com o bloqueio ligado | `settings.lock_on_open` = `"true"`, `app_settings` com 4 registos e `lock_on_open` na tabela |
| Restauro | Restaurar esse backup | 33 registos repostos, cópia `pre-restore-20261031-032647-900.json` criada, saldo 4 000 FCFA; a nova abertura volta a pedir o PIN |
| Desligar o bloqueio | Interruptor desligado e nova abertura | Abre diretamente no painel, sem pedido do sistema |

Capturas do emulador (`.qoder/screenshots`):

- `fase07_01_prompt.png` — pedido do sistema ao abrir;
- `fase07_02_cancelado.png` — ecrã de bloqueio após cancelar;
- `fase07_03_rebloqueio.png` — rebloqueio após 65 s em segundo plano;
- `fase07_04_sem_credenciais.png` — situação sem credenciais e «Abrir sem bloqueio»;
- `fase07_05_definicoes.png` — cartão «Bloqueio» nas definições;
- `fase07_06_restauro.png` — confirmação do restauro do backup.

## Permissões e privacidade

Inspeção do APK de release com `aapt2 dump badging`:

- permissões declaradas: `android.permission.USE_BIOMETRIC`,
  `android.permission.USE_FINGERPRINT` (declarada pelo `local_auth_android` por
  compatibilidade com Android 8) e a permissão interna
  `ao.gb.financas_pessoais.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`;
- **sem** `INTERNET` e **sem** permissões de armazenamento;
- nenhuma permissão exige pedido em tempo de execução.

O `logcat` durante os fluxos não mostrou erros Flutter nem mensagens com
montantes, descrições, contas ou outros dados financeiros; os avisos
registados vieram de serviços do emulador (UWB, NFC, GMS). A app não recebe
nem guarda PIN, padrão, palavra-passe ou dados biométricos: apenas o resultado
devolvido pelo sistema. O ecrã de bloqueio usa `ExcludeSemantics` e
`AbsorbPointer`, pelo que os dados por baixo não são lidos nem tocados.

## Lacunas desta validação

1. Validado num emulador x86_64 (API 37) com PIN do sistema, sem sensor
   biométrico físico e sem iPhone/Face ID. O caminho biométrico usa a mesma API
   do sistema e não tem tratamento próprio na app.
2. O ecrã de bloqueio e o pedido do sistema não foram auditados com TalkBack
   num dispositivo físico; a semântica foi verificada por testes de widget.
3. O bloqueio não cifra a base SQLite, os backups nem as exportações. Quem
   tiver acesso aos ficheiros (dispositivo desbloqueado ou com root) continua a
   poder lê-los — limitação já registada no ADR-030 e no ADR-037.
4. `dart format .` não corre nesta máquina enquanto existirem os caminhos longos
   gerados pelo Gradle; a verificação foi feita sobre `lib` e `test`.
5. O APK desta validação está assinado com a chave de debug; não é
   distribuível. A assinatura de release continua pendente (ADR-031).

## Aceitação

| Critério | Estado |
|---|---|
| Testes críticos passam | cumprido: 229 testes verdes, análise limpa |
| Bloqueio pede credenciais do sistema ao abrir | cumprido no emulador com PIN |
| Cancelar e falhar mantêm a app bloqueada | cumprido, com aviso e nova tentativa manual |
| Rebloqueio após 60 s em segundo plano; regressos curtos mantêm a sessão | cumprido: 65 s rebloqueia, 5 s não |
| Remover credenciais não deixa o utilizador preso | cumprido: «Abrir sem bloqueio» e interruptor desativado |
| Preferência persiste e viaja no backup | cumprido: `lock_on_open` no JSON e reaplicada no restauro |
| Release offline e sem permissões de armazenamento | cumprido: sem `INTERNET`; apenas `USE_BIOMETRIC`/`USE_FINGERPRINT` |
| Comandos e resultados documentados | este relatório, com resultados reais |

A fase fica concluída para validação local. A assinatura de release continua a
ser o passo seguinte antes de qualquer distribuição.
