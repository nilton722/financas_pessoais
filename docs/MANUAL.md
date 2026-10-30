# Manual de instalação e uso

Aplicação Android offline de finanças pessoais. Não tem backend, login remoto,
anúncios, analytics nem telemetria.

## Instalação

### Desenvolvimento

Requisitos: Flutter 3.47.5 (stable), Dart 3.13.3, JDK 17 ou superior.

```bash
flutter pub get
dart run build_runner build
flutter run
```

### APK de release

```bash
flutter test
flutter build apk --release
```

O ficheiro fica em `build/app/outputs/flutter-apk/app-release.apk` e instala-se
com `adb install -r app-release.apk` ou por transferência para o telefone
(permitir instalação de origens desconhecidas apenas para este ficheiro).

Sem `android/key.properties`, o build usa a chave de **debug**: serve para
validação local, não para distribuição. Para assinar a sério, ver
[Assinatura de release](#assinatura-de-release).

## Primeiros passos

1. Abra a app. O painel arranca sem contas e mostra saldo real, previsão e
   resumo de planeamento.
2. Em **Contas**, crie a primeira conta (dinheiro, banco, carteira móvel,
   poupança ou outro) com saldo inicial e data de abertura.
3. Em **Categorias**, use as predefinidas ou crie as suas. Arquivar uma
   categoria mantém o histórico e impede novas utilizações.
4. Registe rendimentos e despesas em **Movimentos**.

As categorias e as configurações iniciais (`XOF`, `pt_PT`, `Africa/Bissau`) são
semeadas uma única vez. Montantes são sempre inteiros de FCFA/XOF.

## Uso diário

- **Movimentos** — rendimento, despesa ou transferência, com conta, categoria,
  data, montante, descrição e notas. Filtre por período, conta, tipo ou
  categoria; edite ou elimine (eliminação lógica, com confirmação).
- **Transferências** — escolha conta de origem e destino. Movem dinheiro entre
  contas próprias: não são rendimento nem despesa e não alteram o saldo
  consolidado. Só são permitidas entre contas com a mesma moeda.
- **Planeamento** — cinco áreas:
  - *Compromissos*: rendimento/despesa futura com vencimento. Pagar total ou
    parcialmente cria exatamente um movimento real; cancelar mantém os
    pagamentos já feitos.
  - *Orçamentos*: limite mensal por categoria de despesa, comparado com gastos
    reais (transferências excluídas).
  - *Recorrências*: regras semanais, mensais ou anuais; geram ocorrências
    planeadas uma única vez e podem ser pausadas.
  - *Metas de poupança*: alvo e progresso lido do saldo real da conta
    associada; uma meta não é uma despesa.
  - *Dívidas*: a pagar ou a receber; o pendente deriva dos pagamentos reais.
- **Previsão** — abra pelo cartão do painel. Horizonte de 7, 30 ou 90 dias,
  com saldo projetado, menor saldo, compromissos conhecidos, pressupostos,
  qualidade dos dados e limitações. É uma estimativa, não uma garantia.
- **Relatórios** — por período, categoria ou conta, com rendimentos, despesas,
  resultado e transferências à parte. A exportação CSV é sempre iniciada pelo
  utilizador.
- **Definições** — privacidade, caminhos de dados/backups/exportações, versão e
  acesso aos backups.

## Backup e restauração

- **Criar backup**: Definições → Backups → *Criar backup*. É gerado um JSON
  versionado com as 12 tabelas de dados, configurações, contagens e checksum.
- **Restaurar**: toque no ficheiro, confirme a pré-visualização e a advertência.
  Antes de substituir, a app cria um backup de segurança `pre-restore-…json` da
  base atual. O restauro corre numa única transação; se algo falhar, a base
  atual fica intacta.
- **Onde ficam os ficheiros**: no Android, em
  `Android/data/ao.gb.financas_pessoais/files/backups` (e `exports` para CSV).
  No desktop, na pasta de documentos da aplicação. Os caminhos exatos aparecem
  em Definições.
- Copie periodicamente o backup para fora do telefone. O ficheiro de backup
  não é cifrado nem assinado: o checksum deteta corrupção acidental, não
  adulteração. Proteja o acesso ao telefone e às cópias.

Detalhe do formato, validação e recuperação: [BACKUP.md](BACKUP.md).

## Privacidade

- Tudo é local: base SQLite privada da app, backups e exportações no
  armazenamento da app.
- A versão de release **não pede a permissão `INTERNET`**; `INTERNET` existe
  apenas nos manifestos de debug/profile para ferramentas de desenvolvimento.
- Não há analytics, publicidade, telemetria nem envio de dados financeiros.
- Não há PIN nem biomeria: quem desbloquear o telefone consegue abrir a app. Os
  dados não estão cifrados em repouso. Use bloqueio do dispositivo e backups
  guardados em local seguro.
- Logs não incluem dados financeiros pessoais.

Detalhe: [PRIVACY.md](PRIVACY.md).

## Limitações conhecidas

- Uso individual, uma moeda de referência (XOF). Contas noutra moeda não entram
  no saldo consolidado nem nas transferências.
- Sem sincronização entre dispositivos, sem importação bancária, sem CSV de
  entrada e sem login remoto.
- A previsão usa apenas movimentos reais, compromissos conhecidos e histórico
  suficiente; não antecipa despesas não registadas e não é uma garantia.
- As recorrências materializam compromissos planeados, não movimentos
  realizados; o caixa só muda quando o compromisso é pago.
- O restauro substitui toda a base. Não há fusão de backups.
- Não é possível abrir uma base criada por uma versão mais recente do esquema.

## Atualização

1. Faça um backup antes de atualizar.
2. Instale o novo APK sobre o anterior, com a mesma assinatura.
3. A base existente é migrada de forma incremental (v1→v4) sem ser recriada.
   As migrações são aditivas e preservam os dados; a versão do esquema fica em
   `PRAGMA user_version` e em `schema_migrations`.
4. Abrir uma base mais recente com uma app antiga não é suportado.

Se a assinatura mudar (por exemplo, de debug para release), o Android recusa a
atualização. Desinstalar apaga a base privada da app: exporte o backup e
restaure-o depois de instalar a versão assinada.

## Assinatura de release

1. Crie um keystore (guarde-o e às palavras-passe em local seguro, fora do
   repositório):

   ```bash
   keytool -genkey -v -keystore android/financas-release.jks \
     -keyalg RSA -keysize 2048 -validity 10000 -alias financas-release
   ```

2. Copie `android/key.properties.example` para `android/key.properties` e
   preencha os valores. `storeFile` é relativo a `android/app`.
3. Confirme que `android/key.properties`, `*.jks` e `*.keystore` estão
   ignorados pelo Git.
4. Gere o APK:

   ```bash
   flutter build apk --release
   apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
   ```

Nunca embuta credenciais no código, no APK ou no repositório.

## Resolução de problemas

- **A app não abre a base**: aparece uma mensagem com *Tentar novamente*. Não
  apague dados manualmente; consulte os caminhos em Definições e restaure um
  backup válido.
- **Backup inválido**: a app indica o motivo (JSON inválido, esquema
  incompatível, contagens ou relações inconsistentes) e não permite restaurar.
- **Saldo inesperado**: confirme a data de referência, contas arquivadas,
  moeda da conta, movimentos eliminados e pagamentos de compromissos/dívidas.
- **Previsão vazia**: sem compromissos e sem histórico suficiente, a projeção
  reflete apenas o saldo atual. Isso é esperado.
