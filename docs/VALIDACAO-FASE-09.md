# Validação da Fase 09 — backup cifrado com frase-passe

Data: 2026-11-03. Ambiente: Windows 11, Flutter 3.47.5 (stable) / Dart 3.13.3,
emulador Android `emulator-5554` (API 37, 1080×2400), pacote
`ao.gb.financas_pessoais` 1.0.0+1, dependência `cryptography 2.9.0` (Dart puro).

Objetivo da fase: permitir criar backups cifrados com AES-256-GCM e frase-passe
derivada por PBKDF2-HMAC-SHA256 (210 000 iterações), sem guardar a frase,
mantendo a leitura e o restauro dos backups simples anteriores (ADR-045).

## Verificações de código

| Comando | Resultado observado |
|---|---|
| `dart format --set-exit-if-changed lib test` | 176 ficheiros, 0 alterados (1,3 s) |
| `flutter analyze` | `No issues found!` |
| `flutter test` | 280 testes, todos passados (~65 s) |
| `flutter build apk --release` | `app-release.apk` com 71 348 824 bytes |

Nota de transparência: a primeira execução completa falhou num teste —
`test/integration/release_flow_test.dart` criava o backup sem passar pelo novo
diálogo de proteção. O teste foi atualizado para escolher «Sem cifra» e
confirmar, tal como os testes de widget; a execução seguinte passou por
completo. Numa execução intermédia, o processo de testes ficou bloqueado num
teste de widget de importação (sem falha reportada); a repetição completa
correu normalmente e o teste isolado passa em ~3 s, pelo que se tratou de
contenção de recursos do anfitrião e não de um defeito do código.

Testes novos ou alterados nesta fase:

- `test/unit/backup/backup_crypto_test.dart` (7): ida e volta com acentos,
  sal/nonce aleatórios, frase curta recusada, frase errada, adulteração de
  ciphertext/MAC/cabeçalho, envelopes e versões inválidas, deteção do formato.
- `test/unit/backup/backup_service_test.dart` (+2): criação cifrada com
  restauro noutra base, recusa sem frase ou com frase errada, cópia
  `pre-restore` criada; importação externa cifrada.
- `test/widget/backup_flow_test.dart` (+2 e ajustes): escolha do formato,
  validação de tamanho e confirmação da frase, cadeado na lista, frase errada
  mantém o diálogo, desbloqueio e restauro; os testes existentes passam a
  escolher «Sem cifra» antes de confirmar.
- `test/integration/release_flow_test.dart`: passa pelo diálogo de criação.
- `test/widget/reports_flow_test.dart`: a afirmação do texto de privacidade
  acompanha a redação nova («não são cifradas» + «cifrados com frase-passe»).

## Release offline

`aapt2 dump badging` no APK de release mostra apenas:
`USE_BIOMETRIC`, `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`,
`USE_FINGERPRINT`, `VIBRATE` e
`ao.gb.financas_pessoais.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`.
**Não há permissão `INTERNET`**: a cifra é feita no dispositivo pela
biblioteca `cryptography`, sem rede.

`apksigner verify --print-certs`: assinante `C=US, O=Android, CN=Android Debug`,
SHA-256 `27959f0902c686e15edbeb642c6bc6a6e7c5d34f7472148d2f50092c4adbffb9`.
A assinatura de produção continua pendente (Fase de lançamento), como antes.

## Validação no emulador (APK de release instalado)

Fluxo percorrido por toques reais, com capturas de ecrã:

1. **Definições → Privacidade** mostra a redação nova: a base e as exportações
   não são cifradas, os backups podem ser cifrados com frase-passe em cada
   criação e as cópias automáticas de restauro ficam legíveis.
2. **Backup e restauração** descreve as duas proteções e indica que a base
   local não é cifrada.
3. **Criar backup agora** abre o diálogo com «Cifrado» pré-selecionado, campos
   de frase-passe e confirmação, aviso de que não há recuperação. Com a frase
   `FraseDeTeste09` o backup foi criado em poucos segundos (PBKDF2 210 000
   iterações aceitável no emulador).
4. A lista passou de 13 para **14 ficheiros**; o novo
   `backup-20261103-091905-606.json` mostra cadeado e
   «Cifrado · frase-passe necessária · 29.5 KB»; os backups simples anteriores
   continuam listados e legíveis.
5. Abrir o backup cifrado pede a frase-passe. Com frase errada o diálogo
   mantém-se com «Frase-passe incorreta ou ficheiro alterado.»; com a frase
   certa mostra a pré-visualização com **Proteção: Cifrado (AES-256-GCM)**,
   «Integridade verificada», versão `app 1.0.0 · esquema v4` e o conteúdo por
   tabela (57 registos).
6. Leitura direta do ficheiro na pasta da aplicação
   (`/sdcard/Android/data/ao.gb.financas_pessoais/files/backups/…`) confirma o
   envelope: `format: financas_pessoais_backup_encrypted`, `formatVersion: 1`,
   `cipher: AES-256-GCM`, `kdf: PBKDF2-HMAC-SHA256`, `iterations: 210000`,
   `salt`, `nonce`, `ciphertext` e `mac` em base64. Uma procura por
   `Carteira`, `"tables"` ou nomes de movimentos no ficheiro devolve **zero**
   ocorrências: não há metadados do utilizador fora do ciphertext.
7. `logcat` da sessão não regista falhas da aplicação. (Existe um SIGABRT de
   um serviço de sistema `android.hardwar` às 09:11, alheio ao processo da
   app.)

## Limitações e defeitos conhecidos

- A base SQLite em uso e as exportações CSV continuam sem cifra; só os backups
  criados no modo cifrado protegem o conteúdo fora do dispositivo.
- As cópias automáticas `pre-restore-…json` continuam simples, pelo nível de
  proteção da pasta privada da aplicação; estão documentadas como tal.
- Esquecer a frase-passe não tem recuperação dentro da aplicação.
- O APK de release continua assinado com a chave de depuração; a assinatura de
  produção, o build iOS e a validação em dispositivo físico ficam para a fase
  de lançamento.
- Os lembretes da Fase 08 não foram revalidados nesta fase; o comportamento
  descrito em `VALIDACAO-FASE-08.md` mantém-se, incluindo a entrega de
  notificações sujeita à janela de alarmes inexatos do sistema.
